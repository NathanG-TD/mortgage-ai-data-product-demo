-- =============================================================================
-- 01_semantic_ddl.sql
-- MortgagePlatform_Semantic - DDL
--
-- Deploy order: after 02_memory/ scripts, before 02_semantic_registration.sql
-- =============================================================================

CREATE MULTISET TABLE MortgagePlatform_Semantic.data_product_map,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    map_key         BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    module_name     VARCHAR(50) NOT NULL,
    database_name   VARCHAR(100) NOT NULL,
    module_purpose  VARCHAR(500),
    primary_tables  VARCHAR(1000),
    agent_entry_view VARCHAR(200),
    is_active       BYTEINT NOT NULL DEFAULT 1
)
PRIMARY INDEX (map_key);

COMMENT ON TABLE MortgagePlatform_Semantic.data_product_map IS
'Agent bootstrap table - first query an agent runs to discover all deployed modules and their locations';
COMMENT ON COLUMN MortgagePlatform_Semantic.data_product_map.primary_tables IS
'Comma-separated key tables in this module - agent orientation';
COMMENT ON COLUMN MortgagePlatform_Semantic.data_product_map.agent_entry_view IS
'Recommended first view for agent exploration of this module';


CREATE MULTISET TABLE MortgagePlatform_Semantic.entity_metadata,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    entity_metadata_key     BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    module_name             VARCHAR(50) NOT NULL,
    entity_name             VARCHAR(100) NOT NULL,
    database_name           VARCHAR(100) NOT NULL,
    table_name              VARCHAR(100) NOT NULL,
    view_name               VARCHAR(100),
    natural_key_column      VARCHAR(100),
    surrogate_key_column    VARCHAR(100),
    entity_description      VARCHAR(1000),
    entity_category         VARCHAR(50),
    record_count_approx     BIGINT,
    is_active               BYTEINT NOT NULL DEFAULT 1
)
PRIMARY INDEX (entity_metadata_key);

COMMENT ON TABLE MortgagePlatform_Semantic.entity_metadata IS
'Catalog of all tables across all modules - agent entry point for entity discovery';
COMMENT ON COLUMN MortgagePlatform_Semantic.entity_metadata.module_name IS
'Module this entity belongs to: STAGING, DOMAIN, SEMANTIC, MEMORY';
COMMENT ON COLUMN MortgagePlatform_Semantic.entity_metadata.natural_key_column IS
'Business key column - identifier meaningful to the business (e.g. LOAN_SEQUENCE_NUMBER)';
COMMENT ON COLUMN MortgagePlatform_Semantic.entity_metadata.surrogate_key_column IS
'System-generated integer PK - not applicable for staging tables';
COMMENT ON COLUMN MortgagePlatform_Semantic.entity_metadata.entity_category IS
'Category: SOURCE_SYSTEM, LOAN, CUSTOMER, PROPERTY, PERFORMANCE, COMPLIANCE, MEMORY, METADATA';
COMMENT ON COLUMN MortgagePlatform_Semantic.entity_metadata.is_active IS
'1 = entity active and queryable; 0 = deprecated or not yet deployed';


CREATE MULTISET TABLE MortgagePlatform_Semantic.column_metadata,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    column_metadata_key     BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    database_name           VARCHAR(100) NOT NULL,
    table_name              VARCHAR(100) NOT NULL,
    column_name             VARCHAR(100) NOT NULL,
    business_description    VARCHAR(1000),
    data_type               VARCHAR(50),
    is_pii                  BYTEINT NOT NULL DEFAULT 0,
    is_sensitive            BYTEINT NOT NULL DEFAULT 0,
    is_required             BYTEINT NOT NULL DEFAULT 1,
    is_active               BYTEINT NOT NULL DEFAULT 1,
    sample_values           VARCHAR(500),
    validation_rule         VARCHAR(500)
)
PRIMARY INDEX (column_metadata_key);

COMMENT ON TABLE MortgagePlatform_Semantic.column_metadata IS
'Column-level metadata for key columns - agents use to understand what each column means and its governance status';
COMMENT ON COLUMN MortgagePlatform_Semantic.column_metadata.is_pii IS
'1 = personally identifiable information; apply data governance controls before use';
COMMENT ON COLUMN MortgagePlatform_Semantic.column_metadata.is_sensitive IS
'1 = sensitive data requiring elevated access (AML, credit impairment, bankruptcy) - not necessarily PII';
COMMENT ON COLUMN MortgagePlatform_Semantic.column_metadata.sample_values IS
'Pipe-separated representative values to help agents understand domain (e.g. P|C|N for LOAN_PURPOSE)';
COMMENT ON COLUMN MortgagePlatform_Semantic.column_metadata.validation_rule IS
'Business validation rule agents must enforce when using this column';


CREATE MULTISET TABLE MortgagePlatform_Semantic.table_relationship,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    relationship_key    BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    from_database       VARCHAR(100) NOT NULL,
    from_table          VARCHAR(100) NOT NULL,
    from_column         VARCHAR(100) NOT NULL,
    to_database         VARCHAR(100) NOT NULL,
    to_table            VARCHAR(100) NOT NULL,
    to_column           VARCHAR(100) NOT NULL,
    relationship_type   VARCHAR(50) NOT NULL,
    join_type           VARCHAR(20) NOT NULL DEFAULT 'LEFT',
    cardinality         VARCHAR(30),
    is_mandatory        BYTEINT NOT NULL DEFAULT 0,
    is_active           BYTEINT NOT NULL DEFAULT 1,
    relationship_desc   VARCHAR(500)
)
PRIMARY INDEX (relationship_key);

COMMENT ON TABLE MortgagePlatform_Semantic.table_relationship IS
'Join relationships between all tables - drives multi-hop path discovery in v_relationship_paths';
COMMENT ON COLUMN MortgagePlatform_Semantic.table_relationship.relationship_type IS
'FOREIGN_KEY = enforced FK; SEMANTIC = logical join; DERIVED = computed relationship';
COMMENT ON COLUMN MortgagePlatform_Semantic.table_relationship.join_type IS
'Recommended join type: LEFT, INNER, FULL';
COMMENT ON COLUMN MortgagePlatform_Semantic.table_relationship.cardinality IS
'ONE_TO_ONE, ONE_TO_MANY, MANY_TO_ONE, MANY_TO_MANY';
COMMENT ON COLUMN MortgagePlatform_Semantic.table_relationship.is_mandatory IS
'1 = relationship always exists (INNER JOIN safe); 0 = optional (use LEFT JOIN)';


CREATE MULTISET TABLE MortgagePlatform_Semantic.naming_standard,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    naming_standard_key     BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    standard_type           VARCHAR(50) NOT NULL,
    pattern                 VARCHAR(200) NOT NULL,
    meaning                 VARCHAR(500) NOT NULL,
    example                 VARCHAR(200),
    is_active               BYTEINT NOT NULL DEFAULT 1
)
PRIMARY INDEX (naming_standard_key);

COMMENT ON TABLE MortgagePlatform_Semantic.naming_standard IS
'Naming conventions and abbreviations - agents consult to interpret column and table names correctly';
COMMENT ON COLUMN MortgagePlatform_Semantic.naming_standard.standard_type IS
'SUFFIX, PREFIX, ABBREVIATION, CONVENTION - classification of naming pattern';

-- ---------------------------------------------------------------------------
-- VIEWS
-- ---------------------------------------------------------------------------

-- Multi-hop relationship path discovery - TESTED ✅ DO NOT MODIFY
REPLACE VIEW MortgagePlatform_Semantic.v_relationship_paths AS
WITH RECURSIVE path_cte (
    source_table, target_table, hop_count,
    path_tables, path_joins, visited_tables
) AS (
    SELECT
        from_table      AS source_table,
        to_table        AS target_table,
        1               AS hop_count,
        from_table || ' -> ' || to_table AS path_tables,
        from_table || '.' || from_column || ' = ' || to_table || '.' || to_column AS path_joins,
        '|' || from_table || '|' || to_table || '|' AS visited_tables
    FROM MortgagePlatform_Semantic.table_relationship
    WHERE is_active = 1

    UNION ALL

    SELECT
        p.source_table,
        r.to_table,
        p.hop_count + 1,
        p.path_tables || ' -> ' || r.to_table,
        p.path_joins  || ' AND ' || r.from_table || '.' || r.from_column
                      || ' = '   || r.to_table   || '.' || r.to_column,
        p.visited_tables || r.to_table || '|'
    FROM path_cte p
    JOIN MortgagePlatform_Semantic.table_relationship r
        ON  r.from_table = p.target_table
        AND r.is_active  = 1
        AND p.visited_tables NOT LIKE '%|' || r.to_table || '|%'
    WHERE p.hop_count < 5
)
SELECT source_table, target_table, hop_count, path_tables, path_joins
FROM path_cte;

COMMENT ON VIEW MortgagePlatform_Semantic.v_relationship_paths IS
'Multi-hop join path discovery - find all paths between any two tables up to 5 hops; agents generate JOIN chains from path_joins column';

REPLACE VIEW MortgagePlatform_Semantic.v_entity_catalog AS
SELECT module_name, entity_name, database_name, table_name, view_name,
       natural_key_column, surrogate_key_column, entity_description
FROM MortgagePlatform_Semantic.entity_metadata
WHERE is_active = 1;

COMMENT ON VIEW MortgagePlatform_Semantic.v_entity_catalog IS
'All active entities across all modules - agent overview of what tables exist and where';

REPLACE VIEW MortgagePlatform_Semantic.v_pii_columns AS
SELECT database_name, table_name, column_name, business_description
FROM MortgagePlatform_Semantic.column_metadata
WHERE is_pii = 1 AND is_active = 1;

COMMENT ON VIEW MortgagePlatform_Semantic.v_pii_columns IS
'All PII columns across the data product - governance and access control reference for agents and compliance';

REPLACE VIEW MortgagePlatform_Semantic.v_sensitive_columns AS
SELECT database_name, table_name, column_name, business_description, is_pii
FROM MortgagePlatform_Semantic.column_metadata
WHERE is_sensitive = 1 AND is_active = 1;

COMMENT ON VIEW MortgagePlatform_Semantic.v_sensitive_columns IS
'All sensitive columns (PII and regulated non-PII such as AML, bankruptcy) - agents must flag these in mapping outputs';
