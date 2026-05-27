-- =============================================================================
-- 03_observability_documentation.sql
-- MortgagePlatform_Observability - Memory Documentation
--
-- Run after: 02_observability_registration.sql
-- Populates:
--   1. Design_Decision  - DD-OBS-001, DD-OBS-002, DD-OBS-003, DD-OBS-004
--   2. Query_Cookbook   - QC-OBS-001, QC-OBS-002, QC-OBS-003
--   3. Business_Glossary - 5 Observability terms
--   4. Change_Log       - initial release entry v1.0.0
-- =============================================================================


-- =============================================================================
-- 1. DESIGN DECISIONS
-- =============================================================================

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description,
 context, alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_by, decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-OBS-001', 1,
 '7-year retention for all Observability tables',
 'All Observability tables (change_event, data_quality_metric, data_lineage, lineage_run, agent_outcome) retain data for 7 years. Partition range 2025-2035.',
 'AUSTRAC AML/CTF Act 2006 requires transaction records for 7 years. AASB9/IFRS9 expected credit loss calculation requires auditable data lineage for the same period. Agent outcome records are retained to the same standard for consistency.',
 'Standard 90-day rolling window for operational data - insufficient for regulatory audit. Per-table retention policies - adds operational complexity without material benefit for this product.',
 '7-year uniform retention across all tables eliminates per-table policy complexity. Partition range 2025-2035 (10 years) provides headroom beyond the minimum. Teradata partition elimination keeps query performance unaffected by historical data.',
 'Higher storage cost than event-window retention. All partitions must be provisioned at table creation. Archival strategy deferred to Phase 3.',
 'ACCEPTED', 'OPERATIONAL', 'OBSERVABILITY', '1.0.0',
 'Data Architecture Team', CURRENT_DATE,
 CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description,
 context, alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_by, decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-OBS-002', 1,
 'Single agent_outcome table for both mapping and analytics agents',
 'A single agent_outcome table covers both MAPPING_AGENT and ANALYTICS_AGENT with agent-type-specific nullable columns.',
 'Two active agents exist: the source mapping agent (produces column mappings with confidence scores) and the analytics agent (produces SQL from natural language). A design choice was required between one shared table or separate per-agent tables.',
 'Separate tables per agent type (mapping_agent_outcome, analytics_agent_outcome) - cleaner schema but requires agents to know which table to write to and complicates aggregate reporting across agents.',
 'Single table chosen. Agents are similar in purpose (both produce outcomes from user requests) and the type-specific nullable columns are few (4 columns each). Agent_type column plus is_active partition-level filtering gives equivalent query performance to separate tables.',
 'Nullable columns (columns_mapped, sql_generated, etc.) must be filtered by agent_type in queries. New agent types require column additions rather than new tables.',
 'ACCEPTED', 'SCHEMA', 'OBSERVABILITY', '1.0.0',
 'Data Architecture Team', CURRENT_DATE,
 CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description,
 context, alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_by, decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-OBS-003', 1,
 'lineage_run Primary Index on lineage_id for AMP co-location with data_lineage',
 'lineage_run uses lineage_id as its Primary Index rather than the surrogate lineage_run_id, despite lineage_run_id being the unique key.',
 'The lineage_run_latest view requires a correlated MAX(run_dts) subquery per lineage flow. With PI on lineage_id, all runs for the same flow are on the same AMP as the data_lineage definition row - making the correlated subquery a local AMP operation.',
 'PI on lineage_run_id (default surrogate approach) - even distribution but the MAX(run_dts) subquery becomes a cross-AMP operation. Composite PI on (lineage_id, run_dts) - redundant since the partition already provides run_dts ordering.',
 'PI on lineage_id chosen. The performance benefit on lineage_run_latest is material for agent queries checking pipeline health. The PI produces non-unique rows per AMP but the partition (run_dts monthly) provides row-level ordering within each AMP bucket.',
 'lineage_run_id is not a PI column so PI-based row lookups by run ID require a full-partition scan. Accepted: direct lookup by lineage_run_id is not an expected access pattern.',
 'ACCEPTED', 'ARCHITECTURE', 'OBSERVABILITY', '1.0.0',
 'Data Architecture Team', CURRENT_DATE,
 CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description,
 context, alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_by, decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-OBS-004', 1,
 'Quality monitoring scoped to Domain tables only',
 'data_quality_metric covers the 7 core Domain transactional tables only: Loan_H, LoanApplication_H, LoanPerformance_H, Customer_H, Property_H, Payment_H, LoanStatement_H.',
 'Staging tables also contain data that could be quality-monitored. Staging data is the raw source feed and is transient - it is replaced on each load. Domain tables are the authoritative, persistent source for regulatory reporting.',
 'Monitor both Staging and Domain tables - doubles metric volume without proportional regulatory value since staging data is transient. Monitor reference tables - reference data is pre-seeded and static; quality rules are not applicable.',
 'Domain-only scope aligns Observability with its primary purpose: providing evidence for regulatory calculations (AASB9/IFRS9, AML/CTF) that run against Domain tables. Staging quality issues are captured indirectly via lineage_run rejection counts.',
 'Staging data quality issues (bad source feeds) are not directly surfaced in v_quality_failures. Monitoring scope can be expanded in a future version by adding Staging rows to data_quality_metric.',
 'ACCEPTED', 'ARCHITECTURE', 'OBSERVABILITY', '1.0.0',
 'Data Architecture Team', CURRENT_DATE,
 CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));


-- =============================================================================
-- 2. QUERY COOKBOOK
-- =============================================================================

INSERT INTO MortgagePlatform_Memory.Query_Cookbook
(recipe_id, recipe_title, recipe_description, use_case,
 target_module, sql_template, parameter_descriptions,
 performance_notes, complexity, source_module, module_version,
 is_active, valid_from, valid_to, created_timestamp)
VALUES
('QC-OBS-001',
 'Data quality gate - check Domain table failures before regulatory calculation',
 'Returns all Domain tables currently failing quality thresholds. Agents must run this before executing AASB9/IFRS9 expected credit loss calculations or AML risk reports to verify data integrity.',
 'Pre-calculation data quality gate, regulatory compliance, agent bootstrap check',
 'OBSERVABILITY',
 'SELECT table_name, metric_name, metric_value, threshold_value, measured_at, quality_context FROM MortgagePlatform_Observability.v_quality_failures WHERE measured_at >= CURRENT_TIMESTAMP(6) - INTERVAL {lookback_hours} HOUR ORDER BY measured_at DESC',
 '{lookback_hours} - hours to look back for recent failures (default 24). Use 1 for same-load-cycle check, 168 for weekly view.',
 'View filters on is_below_threshold = 1 with partition elimination on measured_at. Returns empty set when all tables pass - zero rows means safe to proceed.',
 'SIMPLE', 'OBSERVABILITY', '1.0.0',
 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Query_Cookbook
(recipe_id, recipe_title, recipe_description, use_case,
 target_module, sql_template, parameter_descriptions,
 performance_notes, complexity, source_module, module_version,
 is_active, valid_from, valid_to, created_timestamp)
VALUES
('QC-OBS-002',
 'Pipeline health check - current status of all declared lineage flows',
 'Joins data_lineage to the most recent lineage_run execution for each flow. Shows which pipelines ran successfully, which failed, and which have never run. Agent entry point for operational monitoring.',
 'Pipeline health monitoring, SLA check, data freshness verification, lineage audit',
 'OBSERVABILITY',
 'SELECT source_table, job_name, target_table, last_run_dts, last_run_status, last_records_written, last_records_rejected, last_error_message FROM MortgagePlatform_Semantic.lineage_run_latest ORDER BY source_table',
 'No parameters. Returns one row per declared lineage flow. last_run_dts NULL means the flow has never executed. last_run_status FAILED or PARTIAL warrants investigation before using the target table.',
 'View uses correlated MAX(run_dts) subquery co-located by PI on lineage_id - efficient single-AMP correlated lookup per flow.',
 'SIMPLE', 'OBSERVABILITY', '1.0.0',
 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Query_Cookbook
(recipe_id, recipe_title, recipe_description, use_case,
 target_module, sql_template, parameter_descriptions,
 performance_notes, complexity, source_module, module_version,
 is_active, valid_from, valid_to, created_timestamp)
VALUES
('QC-OBS-003',
 'Agent outcome quality trend - mapping confidence by source system',
 'Aggregates mapping agent outcomes by source system to show average confidence and success rate. Used to identify which source systems have the strongest or weakest domain model alignment.',
 'Agent learning, mapping quality review, source onboarding assessment, closed-loop improvement',
 'OBSERVABILITY',
 'SELECT source_system, outcome_type, COUNT(*) AS outcome_count, AVG(confidence_score) AS avg_confidence, AVG(CAST(columns_mapped AS DECIMAL(10,2)) / NULLIF(columns_mapped + columns_unmapped, 0)) AS mapping_coverage FROM MortgagePlatform_Observability.agent_outcome WHERE agent_type = ''MAPPING_AGENT'' AND outcome_dts >= CURRENT_TIMESTAMP(6) - INTERVAL {lookback_days} DAY GROUP BY source_system, outcome_type ORDER BY source_system, outcome_type',
 '{lookback_days} - days to look back (default 30). Use 7 for recent sessions, 90 for quarterly review.',
 'Partition elimination on outcome_dts. NULLIF protects against zero-denominator on mapping_coverage. Group by source_system gives one row per source per outcome type.',
 'MEDIUM', 'OBSERVABILITY', '1.0.0',
 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));


-- =============================================================================
-- 3. BUSINESS GLOSSARY
-- =============================================================================

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, related_table,
 source_module, module_version, is_active, valid_from, valid_to, created_timestamp)
VALUES
('Data Lineage',
 'GOVERNANCE',
 'The documented chain of custody for data from its source system through all transformations to its current state in the Domain module. Required for AASB9/IFRS9 expected credit loss audit and AML/CTF transaction trace.',
 'Regulatory compliance and audit. In this product, lineage is split into definitional (data_lineage table - the blueprint) and operational (lineage_run table - the execution history).',
 'data_lineage, lineage_run, lineage_graph, lineage_run_latest',
 'OBSERVABILITY', '1.0.0', 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, related_table,
 source_module, module_version, is_active, valid_from, valid_to, created_timestamp)
VALUES
('Data Quality Gate',
 'GOVERNANCE',
 'A pre-calculation check that verifies Domain table quality scores are above defined thresholds before running regulatory calculations. Agents must query v_quality_failures and confirm zero rows before using data for AASB9/IFRS9 or AML calculations.',
 'Agent workflow and regulatory compliance. A failed quality gate means the agent must surface the quality issue to the user before proceeding with the calculation.',
 'data_quality_metric, v_quality_failures',
 'OBSERVABILITY', '1.0.0', 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, related_table,
 source_module, module_version, is_active, valid_from, valid_to, created_timestamp)
VALUES
('ETL_INPUT / ETL_OUTPUT',
 'DATA_PATTERN',
 'Edge relationship labels in the lineage_graph view. ETL_INPUT represents a source table feeding into a transformation job. ETL_OUTPUT represents a transformation job writing to a target table. Together they form a two-hop path: source -> job -> target.',
 'Used when interpreting lineage_graph results for data catalogue integration or graph visualisation. Both edges share the same Lineage_ID, which links back to the data_lineage definition row.',
 'lineage_graph, data_lineage',
 'OBSERVABILITY', '1.0.0', 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, related_table,
 source_module, module_version, is_active, valid_from, valid_to, created_timestamp)
VALUES
('Confidence Score',
 'AI_CONCEPT',
 'A decimal value from 0.0000 to 1.0000 representing the mapping or analytics agent''s certainty in its output. For the mapping agent: the proportion of columns confidently mapped to domain targets. For the analytics agent: the model''s confidence that the generated SQL correctly answers the question.',
 'Agent quality monitoring. Low confidence scores (below 0.70) should trigger human review. Score trends by source system inform which source feeds need domain model enhancement.',
 'agent_outcome',
 'OBSERVABILITY', '1.0.0', 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, related_table,
 source_module, module_version, is_active, valid_from, valid_to, created_timestamp)
VALUES
('Closed-Loop Learning',
 'AI_CONCEPT',
 'The pattern by which agent outcome records feed back into the Memory module to improve future agent behaviour. Mapping outcomes update naming conventions and entity descriptions. Analytics outcomes update query cookbook recipes. Requires periodic review of v_agent_outcomes_recent.',
 'AI-native data product design principle. MortgagePlatform implements this pattern via agent_outcome -> Business_Glossary and agent_outcome -> Query_Cookbook update workflows.',
 'agent_outcome, v_agent_outcomes_recent',
 'OBSERVABILITY', '1.0.0', 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));


-- =============================================================================
-- 4. CHANGE LOG
-- =============================================================================

INSERT INTO MortgagePlatform_Memory.Change_Log
(change_id, version_number, change_title, change_description,
 change_type, change_category, affects_table,
 migration_steps, rollback_steps,
 source_module, deployed_date, deployed_by, deployment_status,
 related_decision_id, created_timestamp)
VALUES
('CL-OBS-001', '1.0.0',
 'Initial release - Observability module deployed (Phase 2b)',
 'First deployment of MortgagePlatform_Observability. Tables: change_event, data_quality_metric, data_lineage (definitional), lineage_run (operational), agent_outcome. Views: v_quality_failures, v_recent_changes, v_agent_outcomes_recent (in Observability); lineage_graph, lineage_run_latest (in Semantic). 8 lineage flows declared in data_lineage seed data (see 04_observability_seed.sql). Quality monitoring configured for 7 core Domain tables.',
 'INITIAL_RELEASE', 'MODULE_DEPLOYMENT',
 'change_event, data_quality_metric, data_lineage, lineage_run, agent_outcome',
 'New module - no migration required. Run 04_observability_seed.sql after this file.',
 NULL,
 'OBSERVABILITY', CURRENT_DATE, 'Data Architecture Team', 'DEPLOYED',
 NULL, CURRENT_TIMESTAMP(6));