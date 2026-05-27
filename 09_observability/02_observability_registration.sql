-- =============================================================================
-- 02_observability_registration.sql
-- MortgagePlatform_Observability - Semantic Registration & Seed Data
--
-- Run after: 01_observability_ddl.sql
-- Updates:
--   1. data_product_map           - add OBSERVABILITY entry (now deployed)
--   2. entity_metadata            - 5 Observability entities
--   3. table_relationship         - lineage_run -> data_lineage FK
--   4. column_metadata            - sensitive columns (sql_generated, context)
--   5. Module_Registry            - OBSERVABILITY PLANNED -> DEPLOYED
-- =============================================================================


-- =============================================================================
-- 1. data_product_map - add Observability (deployed modules only)
-- =============================================================================

INSERT INTO MortgagePlatform_Semantic.data_product_map
(module_name, database_name, module_purpose, primary_tables,
 agent_entry_view, is_active)
VALUES
('OBSERVABILITY', 'MortgagePlatform_Observability',
 'Event tracking, data quality monitoring, and lineage for all mortgage platform modules - regulatory audit trail for AASB9/IFRS9 and AML/CTF compliance.',
 'change_event, data_quality_metric, data_lineage, lineage_run, agent_outcome',
 'v_quality_failures',
 1);


-- =============================================================================
-- 2. entity_metadata - 5 Observability tables
-- =============================================================================

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column, entity_description,
 entity_category, record_count_approx, is_active)
VALUES
('OBSERVABILITY', 'ChangeEvent', 'MortgagePlatform_Observability',
 'change_event', 'v_recent_changes',
 'event_dts', 'change_event_key',
 'Table-level ETL change events for Domain tables. Append-only. Agents check v_recent_changes for data freshness before regulatory calculations.',
 'OBSERVABILITY', 0, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column, entity_description,
 entity_category, record_count_approx, is_active)
VALUES
('OBSERVABILITY', 'DataQualityMetric', 'MortgagePlatform_Observability',
 'data_quality_metric', 'v_quality_failures',
 'measured_at', 'quality_metric_key',
 'Quality scores for Domain tables. One row per table per rule per evaluation. Use v_quality_failures to check current failures before running AASB9/IFRS9 or AML calculations.',
 'OBSERVABILITY', 0, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column, entity_description,
 entity_category, record_count_approx, is_active)
VALUES
('OBSERVABILITY', 'DataLineage', 'MortgagePlatform_Observability',
 'data_lineage', 'lineage_graph',
 'lineage_id', 'lineage_id',
 'Definitional lineage blueprint - one row per declared source-to-target flow. Stable; use lineage_graph view in Semantic for graph visualisation. Execution history is in lineage_run.',
 'OBSERVABILITY', 8, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column, entity_description,
 entity_category, record_count_approx, is_active)
VALUES
('OBSERVABILITY', 'LineageRun', 'MortgagePlatform_Observability',
 'lineage_run', 'lineage_run_latest',
 'lineage_run_id', 'lineage_run_id',
 'Operational execution log - one row per ETL run per declared flow. Event-scale volume. Use lineage_run_latest view in Semantic for current pipeline health status.',
 'OBSERVABILITY', 0, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column, entity_description,
 entity_category, record_count_approx, is_active)
VALUES
('OBSERVABILITY', 'AgentOutcome', 'MortgagePlatform_Observability',
 'agent_outcome', 'v_agent_outcomes_recent',
 'outcome_dts', 'outcome_key',
 'Outcome records for mapping agent and analytics agent. Single table covering both agent types. Use v_agent_outcomes_recent for last 30 days. Feeds Memory closed-loop learning.',
 'OBSERVABILITY', 0, 1);


-- =============================================================================
-- 3. table_relationship - lineage_run FK + cross-module context references
-- =============================================================================

-- Physical FK within Observability
INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column, to_database, to_table, to_column,
 relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES
('MortgagePlatform_Observability', 'lineage_run', 'lineage_id',
 'MortgagePlatform_Observability', 'data_lineage', 'lineage_id',
 'FOREIGN_KEY', 'INNER', 'MANY_TO_ONE',
 1, 1,
 'Each execution record links to its declared flow definition - PI co-location makes MAX(run_dts) in lineage_run_latest a single-AMP operation');

-- Semantic references: change_event and data_quality_metric monitor Domain tables
INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column, to_database, to_table, to_column,
 relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES
('MortgagePlatform_Observability', 'change_event', 'table_name',
 'MortgagePlatform_Semantic', 'entity_metadata', 'table_name',
 'SEMANTIC', 'LEFT', 'MANY_TO_ONE',
 0, 1,
 'Change events reference Domain tables by table_name - join to entity_metadata for entity context');

INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column, to_database, to_table, to_column,
 relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES
('MortgagePlatform_Observability', 'data_quality_metric', 'table_name',
 'MortgagePlatform_Semantic', 'entity_metadata', 'table_name',
 'SEMANTIC', 'LEFT', 'MANY_TO_ONE',
 0, 1,
 'Quality metrics reference Domain tables by table_name - join to entity_metadata for entity context');


-- =============================================================================
-- 4. column_metadata - sensitive columns in agent_outcome
-- sql_generated and outcome_context may contain user query intent or
-- partial data values; flagged is_sensitive for governance visibility.
-- =============================================================================

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description,
 is_pii, is_sensitive, is_required, is_active)
VALUES
('MortgagePlatform_Observability', 'agent_outcome', 'sql_generated',
 'ANALYTICS_AGENT: SQL generated from natural language request. Sensitive - may contain customer identifiers or business logic embedded by the user.',
 0, 1, 0, 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description,
 is_pii, is_sensitive, is_required, is_active)
VALUES
('MortgagePlatform_Observability', 'agent_outcome', 'outcome_context',
 'Flexible JSON context for both agent types. Sensitive - may capture unmapped column names, clarification values, or partial data from source systems.',
 0, 1, 0, 1);


-- =============================================================================
-- 5. Module_Registry - OBSERVABILITY PLANNED -> DEPLOYED (temporal update)
-- =============================================================================

-- Close the PLANNED row
UPDATE MortgagePlatform_Memory.Module_Registry
SET    is_current = 0,
       valid_to   = CURRENT_DATE,
       updated_timestamp = CURRENT_TIMESTAMP(6)
WHERE  module_name = 'OBSERVABILITY'
  AND  is_current  = 1;

-- Insert new DEPLOYED row
INSERT INTO MortgagePlatform_Memory.Module_Registry
(module_name, database_name, deployment_status, module_version, module_purpose,
 module_scope, dependencies, dependents, version_date, is_current,
 valid_from, valid_to, created_timestamp)
VALUES
('OBSERVABILITY', 'MortgagePlatform_Observability', 'DEPLOYED', '1.0.0',
 'Event tracking, data quality monitoring, and lineage for all mortgage platform modules - regulatory audit trail for AASB9/IFRS9 and AML/CTF compliance.',
 'Deployed Phase 2b. Quality monitoring scope: 7 Domain tables. Lineage: 8 declared flows. Agent outcome tracking: mapping agent and analytics agent. Retention: 7 years (AUSTRAC AML/CTF + AASB9/IFRS9).',
 'DOMAIN, SEMANTIC', 'PREDICTION',
 CURRENT_DATE, 1, CURRENT_DATE, DATE '9999-12-31',
 CURRENT_TIMESTAMP(6));
