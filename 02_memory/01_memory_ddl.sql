-- =============================================================================
-- 01_memory_ddl.sql
-- MortgagePlatform_Memory — Runtime and Design Memory DDL
--
-- Deploy order: this script first, then 02_memory_documentation.sql
-- Product name: MortgagePlatform
-- =============================================================================

-- ---------------------------------------------------------------------------
-- RUNTIME MEMORY — agent session, interaction, learning tables
-- ---------------------------------------------------------------------------

CREATE MULTISET TABLE MortgagePlatform_Memory.agent_session,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    session_key             BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    session_id              VARCHAR(100) NOT NULL,
    agent_key               VARCHAR(100) NOT NULL,
    user_key                VARCHAR(100),
    session_start_dts       TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    session_end_dts         TIMESTAMP(6) WITH TIME ZONE,
    session_status          VARCHAR(20),
    session_goal            VARCHAR(500),
    session_context_json    JSON,
    scope_level             VARCHAR(20) NOT NULL,
    scope_identifier        VARCHAR(100) NOT NULL,
    created_dt              TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
)
PRIMARY INDEX (session_key);

COMMENT ON TABLE MortgagePlatform_Memory.agent_session IS
'Agent session state — tracks active and historical sessions for continuity across interactions';
COMMENT ON COLUMN MortgagePlatform_Memory.agent_session.session_id IS
'Natural session identifier — business key used to resume or reference a session';
COMMENT ON COLUMN MortgagePlatform_Memory.agent_session.scope_level IS
'Privacy scope: USER (private to one user), ORGANIZATION (all users), AGENT (agent-specific)';
COMMENT ON COLUMN MortgagePlatform_Memory.agent_session.session_context_json IS
'Flexible session context JSON — agent retrieves and processes externally; not queried via SQL';
COMMENT ON COLUMN MortgagePlatform_Memory.agent_session.session_status IS
'Session lifecycle status: ACTIVE, COMPLETED, ABANDONED';


CREATE MULTISET TABLE MortgagePlatform_Memory.agent_interaction,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    interaction_key         BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    session_key             BIGINT NOT NULL,
    interaction_seq         INTEGER NOT NULL,
    interaction_type        VARCHAR(50),
    interaction_dts         TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    user_input              VARCHAR(4000),
    agent_response          VARCHAR(4000),
    action_taken            VARCHAR(500),
    referenced_tables       VARCHAR(1000),
    sql_executed            VARCHAR(4000),
    query_result_count      INTEGER,
    execution_time_ms       INTEGER,
    outcome_status          VARCHAR(20),
    user_feedback           VARCHAR(20),
    scope_level             VARCHAR(20) NOT NULL,
    scope_identifier        VARCHAR(100) NOT NULL,
    created_dt              TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
)
PRIMARY INDEX (interaction_key);

COMMENT ON TABLE MortgagePlatform_Memory.agent_interaction IS
'Agent interaction log — records SQL, tables accessed, and outcomes for learning; stores table names not record keys';
COMMENT ON COLUMN MortgagePlatform_Memory.agent_interaction.interaction_type IS
'Type of interaction: QUERY, ACTION, DECISION, EXPLANATION, MAPPING';
COMMENT ON COLUMN MortgagePlatform_Memory.agent_interaction.referenced_tables IS
'Comma-separated database.table names involved — TABLE LEVEL only, never individual record keys or IDs';
COMMENT ON COLUMN MortgagePlatform_Memory.agent_interaction.query_result_count IS
'Aggregate row count returned — never store individual keys or result data';
COMMENT ON COLUMN MortgagePlatform_Memory.agent_interaction.outcome_status IS
'Outcome: SUCCESS, PARTIAL, FAILED';
COMMENT ON COLUMN MortgagePlatform_Memory.agent_interaction.user_feedback IS
'User-provided quality signal: POSITIVE, NEUTRAL, NEGATIVE';


CREATE MULTISET TABLE MortgagePlatform_Memory.learned_strategy,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    strategy_key            BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    strategy_name           VARCHAR(100) NOT NULL,
    strategy_description    VARCHAR(1000),
    strategy_category       VARCHAR(50),
    applies_to_scenario     VARCHAR(500),
    strategy_pattern        VARCHAR(4000),
    strategy_metadata_json  JSON,
    discovered_dts          TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    discovered_by_agent     VARCHAR(100),
    times_used              INTEGER DEFAULT 0,
    success_rate            DECIMAL(5,4),
    scope_level             VARCHAR(20) NOT NULL,
    scope_identifier        VARCHAR(100) NOT NULL,
    is_active               BYTEINT NOT NULL DEFAULT 1,
    is_validated            BYTEINT NOT NULL DEFAULT 0,
    validation_dts          TIMESTAMP(6) WITH TIME ZONE,
    created_dt              TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6),
    updated_dt              TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
)
PRIMARY INDEX (strategy_key);

COMMENT ON TABLE MortgagePlatform_Memory.learned_strategy IS
'Agent-learned strategies — successful patterns discovered through experience; shared at ORGANIZATION scope';
COMMENT ON COLUMN MortgagePlatform_Memory.learned_strategy.strategy_category IS
'Category: QUERY_OPTIMIZATION, MAPPING_PATTERN, FEATURE_SELECTION, ERROR_HANDLING, LINEAGE_TRACE';
COMMENT ON COLUMN MortgagePlatform_Memory.learned_strategy.is_validated IS
'1 = validated by human expert or testing; 0 = discovered but pending validation';
COMMENT ON COLUMN MortgagePlatform_Memory.learned_strategy.scope_level IS
'ORGANIZATION = shared across all agents; AGENT = isolated to one agent instance';


CREATE MULTISET TABLE MortgagePlatform_Memory.user_preference,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    preference_key          BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    user_key                VARCHAR(100) NOT NULL,
    preference_category     VARCHAR(50),
    preference_name         VARCHAR(100) NOT NULL,
    preference_value        VARCHAR(1000),
    preference_value_json   JSON,
    applies_to_entity       VARCHAR(100),
    learned_from_interactions INTEGER,
    confidence              DECIMAL(5,4),
    last_used_dts           TIMESTAMP(6) WITH TIME ZONE,
    scope_level             VARCHAR(20) DEFAULT 'USER',
    is_active               BYTEINT NOT NULL DEFAULT 1,
    created_dt              TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6),
    updated_dt              TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
)
PRIMARY INDEX (preference_key);

COMMENT ON TABLE MortgagePlatform_Memory.user_preference IS
'User preferences learned from interactions — stores user_key only, never PII; enables personalised agent behaviour';
COMMENT ON COLUMN MortgagePlatform_Memory.user_preference.preference_category IS
'Category: REPORT_FORMAT, DATA_FILTER, AGGREGATION_LEVEL, MAPPING_STYLE, OUTPUT_FORMAT';
COMMENT ON COLUMN MortgagePlatform_Memory.user_preference.user_key IS
'Anonymous user identifier — never store PII; link to identity system outside this product';


CREATE MULTISET TABLE MortgagePlatform_Memory.discovered_pattern,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    pattern_key             BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    pattern_name            VARCHAR(100) NOT NULL,
    pattern_description     VARCHAR(1000),
    pattern_type            VARCHAR(50),
    pattern_definition_json JSON,
    sample_size             INTEGER,
    occurrences             INTEGER,
    confidence_score        DECIMAL(5,4),
    statistical_significance DECIMAL(5,4),
    discovered_dts          TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    discovered_by_agent     VARCHAR(100),
    involved_tables         VARCHAR(1000),
    scope_level             VARCHAR(20) NOT NULL,
    scope_identifier        VARCHAR(100) NOT NULL,
    is_active               BYTEINT NOT NULL DEFAULT 1,
    is_validated            BYTEINT NOT NULL DEFAULT 0,
    created_dt              TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
)
PRIMARY INDEX (pattern_key);

COMMENT ON TABLE MortgagePlatform_Memory.discovered_pattern IS
'Patterns discovered through data analysis — statistical summary only, never individual record details';
COMMENT ON COLUMN MortgagePlatform_Memory.discovered_pattern.pattern_type IS
'Type: CORRELATION, TEMPORAL, TABLE_RELATIONSHIP, ANOMALY, MAPPING_HEURISTIC';
COMMENT ON COLUMN MortgagePlatform_Memory.discovered_pattern.involved_tables IS
'Comma-separated database.table names — TABLE LEVEL only; query: WHERE involved_tables LIKE ''%STG_%''';

-- ---------------------------------------------------------------------------
-- DESIGN MEMORY — documentation tables (mandatory for all products)
-- ---------------------------------------------------------------------------

CREATE MULTISET TABLE MortgagePlatform_Memory.Module_Registry,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    module_registry_key     BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    module_name             VARCHAR(50) NOT NULL,
    database_name           VARCHAR(100) NOT NULL,
    module_version          VARCHAR(20) NOT NULL,
    module_purpose          CLOB NOT NULL,
    module_scope            CLOB,
    key_entities            VARCHAR(500),
    dependencies            VARCHAR(500),
    dependents              VARCHAR(500),
    data_owner              VARCHAR(100),
    technical_owner         VARCHAR(100),
    version_date            DATE NOT NULL,
    is_current              BYTEINT NOT NULL DEFAULT 1,
    valid_from              DATE NOT NULL,
    valid_to                DATE DEFAULT DATE '9999-12-31',
    created_timestamp       TIMESTAMP(6) WITH TIME ZONE,
    updated_timestamp       TIMESTAMP(6) WITH TIME ZONE
)
PRIMARY INDEX (module_registry_key);

COMMENT ON TABLE MortgagePlatform_Memory.Module_Registry IS
'Version registry for all deployed modules — backbone for point-in-time documentation generation';
COMMENT ON COLUMN MortgagePlatform_Memory.Module_Registry.is_current IS
'1 = current version of this module; 0 = superseded; only one is_current=1 row per module_name';


CREATE MULTISET TABLE MortgagePlatform_Memory.Design_Decision,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    decision_key            BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    decision_id             VARCHAR(50) NOT NULL,
    decision_version        INTEGER NOT NULL DEFAULT 1,
    decision_title          VARCHAR(200) NOT NULL,
    decision_description    CLOB,
    context                 CLOB,
    alternatives_considered CLOB,
    rationale               CLOB,
    consequences            CLOB,
    decision_status         VARCHAR(20) NOT NULL,
    decision_category       VARCHAR(50) NOT NULL,
    source_module           VARCHAR(50) NOT NULL,
    module_version          VARCHAR(20),
    affects_table           VARCHAR(200),
    decided_by              VARCHAR(100),
    decided_date            DATE,
    superseded_by           VARCHAR(50),
    valid_from              DATE NOT NULL,
    valid_to                DATE DEFAULT DATE '9999-12-31',
    is_current              BYTEINT NOT NULL DEFAULT 1,
    created_timestamp       TIMESTAMP(6) WITH TIME ZONE,
    updated_timestamp       TIMESTAMP(6) WITH TIME ZONE
)
PRIMARY INDEX (decision_key);

COMMENT ON TABLE MortgagePlatform_Memory.Design_Decision IS
'Architecture Decision Records — why design choices were made; version chain tracks superseded decisions';
COMMENT ON COLUMN MortgagePlatform_Memory.Design_Decision.decision_id IS
'ID format: DD-{MODULE}-{NNN} e.g. DD-MEMORY-001, DD-SEMANTIC-001, DD-STAGING-001';
COMMENT ON COLUMN MortgagePlatform_Memory.Design_Decision.decision_status IS
'Lifecycle: PROPOSED, ACCEPTED, SUPERSEDED, DEPRECATED';
COMMENT ON COLUMN MortgagePlatform_Memory.Design_Decision.decision_category IS
'Category: ARCHITECTURE, SCHEMA, NAMING, PERFORMANCE, SECURITY, INTEGRATION, OPERATIONAL';


CREATE MULTISET TABLE MortgagePlatform_Memory.Business_Glossary,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    glossary_key            BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    term                    VARCHAR(200) NOT NULL,
    term_category           VARCHAR(50) NOT NULL,
    definition              CLOB NOT NULL,
    business_context        CLOB,
    synonyms                VARCHAR(500),
    related_terms           VARCHAR(500),
    related_table           VARCHAR(200),
    related_column          VARCHAR(200),
    source_module           VARCHAR(50) NOT NULL,
    module_version          VARCHAR(20),
    is_active               BYTEINT NOT NULL DEFAULT 1,
    valid_from              DATE NOT NULL,
    valid_to                DATE DEFAULT DATE '9999-12-31',
    created_timestamp       TIMESTAMP(6) WITH TIME ZONE,
    updated_timestamp       TIMESTAMP(6) WITH TIME ZONE
)
PRIMARY INDEX (glossary_key);

COMMENT ON TABLE MortgagePlatform_Memory.Business_Glossary IS
'Business term definitions — reduces ambiguity for agents and new team members interpreting column names';
COMMENT ON COLUMN MortgagePlatform_Memory.Business_Glossary.term_category IS
'Category: ENTITY, ATTRIBUTE, METRIC, BUSINESS_RULE, CLASSIFICATION, REFERENCE_CODE';
COMMENT ON COLUMN MortgagePlatform_Memory.Business_Glossary.synonyms IS
'Pipe-separated alternative names for this term that may appear in source systems';


CREATE MULTISET TABLE MortgagePlatform_Memory.Query_Cookbook,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    recipe_key              BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    recipe_id               VARCHAR(50) NOT NULL,
    recipe_title            VARCHAR(200) NOT NULL,
    recipe_description      CLOB NOT NULL,
    use_case                VARCHAR(200) NOT NULL,
    target_module           VARCHAR(50) NOT NULL,
    sql_template            CLOB NOT NULL,
    parameter_descriptions  CLOB,
    performance_notes       CLOB,
    complexity              VARCHAR(20) NOT NULL,
    source_module           VARCHAR(50) NOT NULL,
    module_version          VARCHAR(20),
    is_active               BYTEINT NOT NULL DEFAULT 1,
    valid_from              DATE NOT NULL,
    valid_to                DATE DEFAULT DATE '9999-12-31',
    created_timestamp       TIMESTAMP(6) WITH TIME ZONE,
    updated_timestamp       TIMESTAMP(6) WITH TIME ZONE
)
PRIMARY INDEX (recipe_key);

COMMENT ON TABLE MortgagePlatform_Memory.Query_Cookbook IS
'Proven query patterns for the mortgage domain — agents use as starting points; ID format QC-{MODULE}-{NNN}';
COMMENT ON COLUMN MortgagePlatform_Memory.Query_Cookbook.complexity IS
'Complexity level: SIMPLE, MODERATE, COMPLEX, ADVANCED';
COMMENT ON COLUMN MortgagePlatform_Memory.Query_Cookbook.sql_template IS
'SQL with {placeholder} tokens for runtime substitution — not executed directly';


CREATE MULTISET TABLE MortgagePlatform_Memory.Implementation_Note,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    note_key                BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    note_id                 VARCHAR(50) NOT NULL,
    note_title              VARCHAR(200) NOT NULL,
    note_content            CLOB NOT NULL,
    note_category           VARCHAR(50) NOT NULL,
    severity                VARCHAR(20),
    affects_table           VARCHAR(200),
    resolution_status       VARCHAR(20),
    resolution_notes        CLOB,
    source_module           VARCHAR(50) NOT NULL,
    module_version          VARCHAR(20),
    is_active               BYTEINT NOT NULL DEFAULT 1,
    valid_from              DATE NOT NULL,
    valid_to                DATE DEFAULT DATE '9999-12-31',
    created_timestamp       TIMESTAMP(6) WITH TIME ZONE,
    updated_timestamp       TIMESTAMP(6) WITH TIME ZONE
)
PRIMARY INDEX (note_key);

COMMENT ON TABLE MortgagePlatform_Memory.Implementation_Note IS
'Operational knowledge — workarounds, known issues, deployment tips; ID format IN-{MODULE}-{NNN}';
COMMENT ON COLUMN MortgagePlatform_Memory.Implementation_Note.note_category IS
'Category: DEPLOYMENT, WORKAROUND, KNOWN_ISSUE, PERFORMANCE_TIP, OPERATIONAL, SECURITY';
COMMENT ON COLUMN MortgagePlatform_Memory.Implementation_Note.resolution_status IS
'Status: OPEN, IN_PROGRESS, RESOLVED, WONT_FIX';


CREATE MULTISET TABLE MortgagePlatform_Memory.Change_Log,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    change_key              BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    change_id               VARCHAR(50) NOT NULL,
    version_number          VARCHAR(20) NOT NULL,
    change_title            VARCHAR(200) NOT NULL,
    change_description      CLOB NOT NULL,
    change_type             VARCHAR(30) NOT NULL,
    change_category         VARCHAR(50) NOT NULL,
    source_module           VARCHAR(50) NOT NULL,
    affects_table           VARCHAR(200),
    migration_steps         CLOB,
    rollback_steps          CLOB,
    related_decision_id     VARCHAR(50),
    deployed_date           DATE,
    deployed_by             VARCHAR(100),
    deployment_status       VARCHAR(20) NOT NULL,
    created_timestamp       TIMESTAMP(6) WITH TIME ZONE
)
PRIMARY INDEX (change_key);

COMMENT ON TABLE MortgagePlatform_Memory.Change_Log IS
'Versioned change history — each row is a point-in-time event; ID format CL-{MODULE}-{NNN}';
COMMENT ON COLUMN MortgagePlatform_Memory.Change_Log.change_type IS
'Type: INITIAL_RELEASE, SCHEMA_CHANGE, FEATURE_ADDITION, BUG_FIX, PERFORMANCE, DEPRECATION';
COMMENT ON COLUMN MortgagePlatform_Memory.Change_Log.change_category IS
'Impact category: BREAKING, NON_BREAKING, ADDITIVE, DEPRECATION';
COMMENT ON COLUMN MortgagePlatform_Memory.Change_Log.deployment_status IS
'Status: PLANNED, DEPLOYED, ROLLED_BACK';

-- ---------------------------------------------------------------------------
-- VIEWS
-- ---------------------------------------------------------------------------

REPLACE VIEW MortgagePlatform_Memory.v_interactions_summary AS
SELECT
    ai.session_key, ai.interaction_seq, ai.interaction_type,
    ai.user_input, ai.action_taken, ai.sql_executed,
    ai.query_result_count, ai.execution_time_ms,
    ai.outcome_status, ai.user_feedback,
    ai.referenced_tables, ai.scope_level, ai.interaction_dts
FROM MortgagePlatform_Memory.agent_interaction ai;

COMMENT ON VIEW MortgagePlatform_Memory.v_interactions_summary IS
'Agent interaction summary — filter by referenced_tables LIKE ''%table_name%'' to find interactions involving a table';

REPLACE VIEW MortgagePlatform_Memory.v_active_sessions AS
SELECT * FROM MortgagePlatform_Memory.agent_session
WHERE session_status = 'ACTIVE';

COMMENT ON VIEW MortgagePlatform_Memory.v_active_sessions IS
'Currently active agent sessions — used to resume in-progress work';

REPLACE VIEW MortgagePlatform_Memory.v_Current_Decisions AS
SELECT * FROM MortgagePlatform_Memory.Design_Decision
WHERE is_current = 1
  AND decision_status <> 'DEPRECATED'
ORDER BY source_module, decision_id;

COMMENT ON VIEW MortgagePlatform_Memory.v_Current_Decisions IS
'All current non-deprecated architectural decisions for the MortgagePlatform data product';

REPLACE VIEW MortgagePlatform_Memory.v_Module_Registry_Current AS
SELECT * FROM MortgagePlatform_Memory.Module_Registry
WHERE is_current = 1
ORDER BY module_name;

COMMENT ON VIEW MortgagePlatform_Memory.v_Module_Registry_Current IS
'Current version of each deployed module — reference for documentation generation and agent bootstrap';
