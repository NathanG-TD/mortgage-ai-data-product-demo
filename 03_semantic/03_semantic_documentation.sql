-- =============================================================================
-- 03_semantic_documentation.sql
-- MortgagePlatform_Semantic - Documentation INSERTs into Memory module
-- =============================================================================

-- Module_Registry
INSERT INTO MortgagePlatform_Memory.Module_Registry
(module_name, database_name, module_version, module_purpose, module_scope,
 key_entities, dependencies, dependents,
 version_date, is_current, valid_from, valid_to, created_timestamp)
VALUES
('SEMANTIC', 'MortgagePlatform_Semantic', '1.0.0',
 'Queryable metadata layer enabling autonomous agent discovery of all modules, entities, relationships, and join paths without human guidance. The agent reads this module to understand what exists, where it is, and how to join it - before writing any SQL against the Domain or Staging layers.',
 'All modules register into Semantic. Semantic is self-describing. data_product_map is the agent bootstrap entry point.',
 'data_product_map, entity_metadata, column_metadata, table_relationship, naming_standard',
 'MEMORY (must be deployed first)',
 'DOMAIN, OBSERVABILITY, SEARCH, PREDICTION',
 CURRENT_DATE, 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

-- Design Decisions
INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description, context,
 alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-SEMANTIC-001', 1,
 'data_product_map is the mandatory agent bootstrap entry point',
 'Every deployed module must have exactly one row in data_product_map. An agent starting a new session must query data_product_map first before any other table. This is the contract between the framework and agents.',
 'Agents need a single, predictable entry point to discover what exists in the platform. Without a bootstrap contract, agents require human guidance on which databases and tables to use.',
 'Agents discover tables via DBC.TablesV system view: rejected - DBC contains all tables on the instance, not just this product; no purpose or description metadata. Agents read a static README: rejected - not queryable, not version-controlled in the database.',
 'A structured, queryable bootstrap table is the most reliable agent entry point. agent_entry_view per module gives the agent a recommended starting view rather than forcing it to guess.',
 'Any new module deployment must include a data_product_map INSERT before the module is usable by agents. The withheld bureau feed source includes its own registration INSERT in 08_withheld_source/03_bureau_semantic_registration.sql.',
 'ACCEPTED', 'ARCHITECTURE', 'SEMANTIC', '1.0.0',
 CURRENT_DATE, CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description, context,
 alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-SEMANTIC-002', 1,
 'column_metadata covers PII, sensitive, and business-critical columns only - not all columns',
 'The column_metadata table does not catalog every column in every table. It catalogs: primary keys, foreign keys, PII-flagged columns, sensitive (regulated) columns, and columns with business rules that agents must enforce.',
 'A full column catalog for all 32-column staging tables would produce hundreds of rows with minimal additional agent value. Agents can read COMMENT ON metadata via DBC.Columns for column-level detail on non-key columns.',
 'Catalog all columns: too many rows, most providing no additional agent guidance beyond what COMMENT ON already provides. Catalog only PKs/FKs: misses PII and sensitive governance flags that are critical for the mapping agent to identify.',
 'Key columns plus governance flags gives agents the critical information (join paths, PII, regulated attributes) without bloating the metadata layer. COMMENT ON covers the rest.',
 'Mapping agents must check column_metadata for is_pii and is_sensitive flags for every column they propose mapping. Columns not in column_metadata can be assumed non-sensitive unless the agent has reason to believe otherwise.',
 'ACCEPTED', 'SCHEMA', 'SEMANTIC', '1.0.0',
 CURRENT_DATE, CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description, context,
 alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-SEMANTIC-003', 1,
 'naming_standard table captures source-specific conventions including cross-scale credit score warning',
 'The naming_standard table includes a CONVENTION entry explicitly documenting the FICO vs Equifax scale difference between STG_Freddie_Origination.CREDIT_SCORE and STG_Credit_Bureau_Feed.CRED_SCORE_CURR.',
 'This is the key tacit knowledge item in the bureau feed mapping demo. A BA unfamiliar with credit bureau data would map CRED_SCORE_CURR to the same domain attribute as CREDIT_SCORE, creating a silent data quality issue.',
 'Document only in Business_Glossary: insufficient - the naming_standard table is read as part of agent bootstrap; the Glossary is queried after discovery. Need the warning in both places.',
 'Placing the scale difference warning in naming_standard ensures the mapping agent encounters it during its initial context-building phase, before it begins proposing column mappings. This is how tacit knowledge becomes programmatic knowledge.',
 'The mapping agent must consult naming_standard before producing any credit score mapping and must flag the scale mismatch as a REVIEW-tier mapping requiring BA confirmation.',
 'ACCEPTED', 'INTEGRATION', 'SEMANTIC', '1.0.0',
 CURRENT_DATE, CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));

-- Change_Log
INSERT INTO MortgagePlatform_Memory.Change_Log
(change_id, version_number, change_title, change_description,
 change_type, change_category, source_module,
 deployed_date, deployed_by, deployment_status, created_timestamp)
VALUES
('CL-SEMANTIC-001', '1.0.0',
 'Initial release of MortgagePlatform_Semantic module',
 'Created 5 Semantic tables (data_product_map, entity_metadata, column_metadata, table_relationship, naming_standard) and 4 views (v_relationship_paths, v_entity_catalog, v_pii_columns, v_sensitive_columns). Registered 3 modules in data_product_map (MEMORY, SEMANTIC, STAGING). Registered 7 entities, 20 key columns, 4 staging join relationships, 15 naming standards.',
 'INITIAL_RELEASE', 'ADDITIVE', 'SEMANTIC',
 CURRENT_DATE, 'MortgagePlatform Setup', 'DEPLOYED', CURRENT_TIMESTAMP(6));

-- Business Glossary additions for Semantic module
INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, synonyms, related_terms,
 related_table, related_column, source_module,
 is_active, valid_from, valid_to, created_timestamp)
VALUES
('data_product_map', 'ENTITY',
 'The agent bootstrap table in MortgagePlatform_Semantic. An agent must query this table first to discover all deployed modules, their databases, primary tables, and recommended entry views.',
 'This is the single entry point that enables agent autonomy - without it, agents require human guidance on what tables exist. The pattern: (1) SELECT * FROM data_product_map WHERE is_active=1; (2) use agent_entry_view to start exploring each module.',
 'Bootstrap table|Agent entry point|Module registry',
 'entity_metadata, v_entity_catalog, Module_Registry',
 'MortgagePlatform_Semantic.data_product_map', 'agent_entry_view',
 'SEMANTIC', 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

-- Query Cookbook addition for Semantic
INSERT INTO MortgagePlatform_Memory.Query_Cookbook
(recipe_id, recipe_title, recipe_description, use_case, target_module,
 sql_template, parameter_descriptions, performance_notes, complexity,
 source_module, is_active, valid_from, valid_to, created_timestamp)
VALUES
('QC-SEMANTIC-001',
 'Agent bootstrap sequence - full platform discovery in 4 steps',
 'The complete agent startup query sequence. Run these four queries at the start of any agent session to fully understand the MortgagePlatform data product before writing any domain queries.',
 'Agent session initialisation - always run first',
 'SEMANTIC',
 '-- Step 1: Discover all modules
SELECT module_name, database_name, primary_tables, agent_entry_view
FROM MortgagePlatform_Semantic.data_product_map WHERE is_active = 1;

-- Step 2: Discover all entities
SELECT module_name, entity_name, table_name, natural_key_column, entity_description
FROM MortgagePlatform_Semantic.v_entity_catalog;

-- Step 3: Check for PII and sensitive columns before querying
SELECT table_name, column_name, business_description, is_pii, is_sensitive
FROM MortgagePlatform_Semantic.column_metadata WHERE is_active = 1
ORDER BY table_name, is_sensitive DESC, is_pii DESC;

-- Step 4: Review naming standards and conventions
SELECT standard_type, pattern, meaning FROM MortgagePlatform_Semantic.naming_standard
WHERE is_active = 1 ORDER BY standard_type;',
 'No parameters - run as-is at session start',
 'All Semantic tables are small (< 500 rows). All four queries complete in under 1 second.',
 'SIMPLE', 'SEMANTIC',
 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

-- =============================================================================
-- QUERY COOKBOOK - new mandatory entries per AI-Native Data Product Standard v1.7
-- QC-SEMANTIC-002: ERD generation recipe (mandatory for all data products)
-- QC-XMODULE-001: Domain-to-Staging lineage (cross-module recipe)
-- =============================================================================

INSERT INTO MortgagePlatform_Memory.Query_Cookbook
(recipe_id, recipe_title, recipe_description, use_case,
 target_module, sql_template, parameter_descriptions,
 performance_notes, complexity, source_module, module_version,
 is_active, valid_from, valid_to, created_timestamp)
VALUES
('QC-SEMANTIC-002',
 'Generate entity-relationship diagram from table_relationship',
 'Queries the Semantic table_relationship table to produce a complete entity-relationship listing for the MortgagePlatform data product. Output can be formatted as Mermaid erDiagram syntax or as a plain relationship listing. Use this recipe to verify the current data model without relying on a static diagram that may have drifted.',
 'Data model documentation, agent onboarding, design review, relationship completeness verification',
 'SEMANTIC',
 'SELECT r.from_table, r.from_column, r.relationship_type, r.cardinality, r.to_table, r.to_column, r.join_type, r.is_mandatory, r.relationship_desc FROM MortgagePlatform_Semantic.table_relationship r WHERE r.is_active = 1 ORDER BY r.from_table, r.to_table;',
 'No parameters required. For Mermaid output, map each row to: {from_table} {cardinality_symbol} {to_table} : "{relationship_desc}". Symbols: ONE_TO_ONE=||--||, ONE_TO_MANY=||--o{, MANY_TO_ONE=}o--||, MANY_TO_MANY=}o--o{',
 'Lightweight query on a small metadata table - no performance concerns.',
 'SIMPLE', 'SEMANTIC', '1.0.0',
 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Query_Cookbook
(recipe_id, recipe_title, recipe_description, use_case,
 target_module, sql_template, parameter_descriptions,
 performance_notes, complexity, source_module, module_version,
 is_active, valid_from, valid_to, created_timestamp)
VALUES
('QC-XMODULE-001',
 'Loan origination lineage: Domain back to Staging source row',
 'Traces a funded loan in the Domain module back to its originating row in the Staging module. Joins Loan_H to STG_Freddie_Origination via the natural key LOAN_SEQUENCE_NUMBER. Useful for data quality investigations, regulatory lineage queries, and source-to-target validation.',
 'Data lineage tracing, regulatory audit (AASB9/IFRS9), source-to-target validation, data quality investigation',
 'CROSS',
 'SELECT l.loan_id AS domain_loan_id, l.orig_upb AS domain_orig_upb, l.orig_interest_rate, l.first_payment_dt, l.loan_status, s.LOAN_SEQUENCE_NUMBER AS staging_loan_seq, s.ORIGINAL_UPB AS staging_orig_upb, s.ORIGINAL_INTEREST_RATE AS staging_interest_rate, s.FIRST_PAYMENT_DATE AS staging_first_payment_date FROM MortgagePlatform_Domain.Loan_H l JOIN MortgagePlatform_Staging.STG_Freddie_Origination s ON s.LOAN_SEQUENCE_NUMBER = l.loan_id WHERE l.is_current = 1 AND l.is_deleted = 0 AND l.loan_id = {loan_sequence_number}',
 '{loan_sequence_number} - the LOAN_SEQUENCE_NUMBER value to trace (e.g. F05Q1000001). Remove the WHERE l.loan_id filter to return all loans for a full lineage audit.',
 'PI on both tables aligns on loan natural key - join is efficient with no AMP redistribution.',
 'SIMPLE', 'DOMAIN', '1.0.0',
 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));
