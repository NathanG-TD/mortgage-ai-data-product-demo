-- =============================================================================
-- 01_observability_ddl.sql
-- MortgagePlatform_Observability — DDL
--
-- Deploy order: after Memory and Semantic are deployed
-- Tables:
--   1. change_event         — table-level ETL change tracking
--   2. data_quality_metric  — quality scores for Domain tables
--   3. data_lineage         — definitional lineage blueprint (source->job->target)
--   4. lineage_run          — operational execution log per flow
--   5. agent_outcome        — mapping and analytics agent outcome records
--
-- Primary Index strategy:
--   change_event, data_quality_metric, agent_outcome: PI on surrogate key
--     (even distribution; date partition handles time-range filtering)
--   data_lineage: PI on lineage_id (small table; FK target for lineage_run)
--   lineage_run: PI on lineage_id (co-locates all runs per flow with their
--     definition; makes lineage_run_latest MAX(run_dts) subquery efficient)
--
-- Partition range: 2025-01-01 to 2035-12-31 (10 years, covers 7-year
--   AML/CTF retention requirement with headroom)
--
-- Retention: 7 years all tables (AUSTRAC AML/CTF Act + AASB9/IFRS9 audit)
-- =============================================================================


-- =============================================================================
-- 1. change_event
-- =============================================================================

CREATE MULTISET TABLE MortgagePlatform_Observability.change_event,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    change_event_key    BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    event_dts           TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    database_name       VARCHAR(128) NOT NULL,
    table_name          VARCHAR(100) NOT NULL,
    operation_type      VARCHAR(20)  NOT NULL,
    records_affected    BIGINT,
    changed_by          VARCHAR(100),
    job_name            VARCHAR(200),
    session_id          VARCHAR(100),
    batch_key           VARCHAR(100),
    event_context       JSON,
    is_successful       BYTEINT NOT NULL DEFAULT 1
)
PRIMARY INDEX (change_event_key)
PARTITION BY RANGE_N(
    event_dts BETWEEN TIMESTAMP '2025-01-01 00:00:00+00:00'
              AND     TIMESTAMP '2035-12-31 23:59:59+00:00'
              EACH INTERVAL '1' MONTH
);

COMMENT ON TABLE MortgagePlatform_Observability.change_event IS
'Table-level ETL change tracking — one row per load operation against a Domain table. Tracks what changed, when, how many rows, and which process. Partitioned monthly.';
COMMENT ON COLUMN MortgagePlatform_Observability.change_event.operation_type IS
'ETL operation type: INSERT, UPDATE, DELETE, TRUNCATE, LOAD';
COMMENT ON COLUMN MortgagePlatform_Observability.change_event.batch_key IS
'Batch run identifier — correlates with lineage_run.batch_key to link change events to their declared lineage flow execution';
COMMENT ON COLUMN MortgagePlatform_Observability.change_event.event_context IS
'Flexible JSON metadata — pipeline parameters, environment tags, custom context';
COMMENT ON COLUMN MortgagePlatform_Observability.change_event.is_successful IS
'1 = load completed successfully; 0 = load failed or was rolled back';

COLLECT STATISTICS COLUMN (event_dts) ON MortgagePlatform_Observability.change_event;
COLLECT STATISTICS COLUMN (table_name) ON MortgagePlatform_Observability.change_event;
COLLECT STATISTICS COLUMN (is_successful) ON MortgagePlatform_Observability.change_event;


-- =============================================================================
-- 2. data_quality_metric
-- =============================================================================

CREATE MULTISET TABLE MortgagePlatform_Observability.data_quality_metric,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    quality_metric_key  BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    database_name       VARCHAR(128) NOT NULL,
    table_name          VARCHAR(100) NOT NULL,
    metric_name         VARCHAR(128) NOT NULL,
    metric_value        DECIMAL(10,4),
    threshold_value     DECIMAL(10,4),
    is_below_threshold  BYTEINT NOT NULL DEFAULT 0,
    measured_at         TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    quality_context     VARCHAR(1000)
)
PRIMARY INDEX (quality_metric_key)
PARTITION BY RANGE_N(
    measured_at BETWEEN TIMESTAMP '2025-01-01 00:00:00+00:00'
                AND     TIMESTAMP '2035-12-31 23:59:59+00:00'
                EACH INTERVAL '1' MONTH
);

COMMENT ON TABLE MortgagePlatform_Observability.data_quality_metric IS
'Quality scores for Domain tables — one row per table per rule per evaluation. Agents check v_quality_failures before using data for regulatory calculations. Partitioned monthly.';
COMMENT ON COLUMN MortgagePlatform_Observability.data_quality_metric.metric_name IS
'Quality rule identifier — e.g. COMPLETENESS_loan_id, VALIDITY_credit_score, NULL_RATE_customer_key';
COMMENT ON COLUMN MortgagePlatform_Observability.data_quality_metric.metric_value IS
'Measured value of the quality metric — e.g. 0.9980 for 99.80% completeness';
COMMENT ON COLUMN MortgagePlatform_Observability.data_quality_metric.threshold_value IS
'Minimum acceptable value — rows with metric_value below this set is_below_threshold = 1';
COMMENT ON COLUMN MortgagePlatform_Observability.data_quality_metric.is_below_threshold IS
'1 = metric failed threshold and requires attention; 0 = metric passed';
COMMENT ON COLUMN MortgagePlatform_Observability.data_quality_metric.quality_context IS
'Human-readable context — sample failing values, rule description, recommended action';

COLLECT STATISTICS COLUMN (measured_at) ON MortgagePlatform_Observability.data_quality_metric;
COLLECT STATISTICS COLUMN (table_name, is_below_threshold) ON MortgagePlatform_Observability.data_quality_metric;


-- =============================================================================
-- 3. data_lineage (Definitional — OpenLineage aligned)
-- =============================================================================

CREATE MULTISET TABLE MortgagePlatform_Observability.data_lineage,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    lineage_id              INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
    source_database         VARCHAR(128),
    source_table            VARCHAR(100),
    source_system           VARCHAR(100),
    target_database         VARCHAR(128),
    target_table            VARCHAR(100) NOT NULL,
    job_name                VARCHAR(200),
    transformation_type     VARCHAR(50),
    transformation_logic    VARCHAR(4000),
    openlineage_job_name    VARCHAR(200),
    openlineage_namespace   VARCHAR(200),
    is_active               BYTEINT NOT NULL DEFAULT 1,
    registered_dts          TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6),
    retired_dts             TIMESTAMP(6) WITH TIME ZONE,
    created_at              TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
)
PRIMARY INDEX (lineage_id);

COMMENT ON TABLE MortgagePlatform_Observability.data_lineage IS
'Definitional lineage blueprint — one row per declared source-to-target flow. Changes only when pipeline design changes. Execution history is in lineage_run. Consumed by lineage_graph view.';
COMMENT ON COLUMN MortgagePlatform_Observability.data_lineage.lineage_id IS
'Surrogate key for lineage definition — FK target for lineage_run.lineage_id';
COMMENT ON COLUMN MortgagePlatform_Observability.data_lineage.source_system IS
'External source system name — e.g. Freddie Mac, CRM. NULL if source is an internal Teradata table.';
COMMENT ON COLUMN MortgagePlatform_Observability.data_lineage.transformation_type IS
'Transformation type: ETL, FEATURE_ENG, AGGREGATION, JOIN, EMBEDDING_GEN, FILTER';
COMMENT ON COLUMN MortgagePlatform_Observability.data_lineage.transformation_logic IS
'SQL, algorithm, or prose description of the transformation applied in this flow';
COMMENT ON COLUMN MortgagePlatform_Observability.data_lineage.is_active IS
'1 = live flow in current pipeline design; 0 = retired flow preserved for historical reference';
COMMENT ON COLUMN MortgagePlatform_Observability.data_lineage.retired_dts IS
'Timestamp when this flow was retired — NULL while active, set when is_active transitions to 0';

COLLECT STATISTICS COLUMN (lineage_id) ON MortgagePlatform_Observability.data_lineage;
COLLECT STATISTICS COLUMN (is_active) ON MortgagePlatform_Observability.data_lineage;


-- =============================================================================
-- 4. lineage_run (Operational — Execution Log)
-- =============================================================================

CREATE MULTISET TABLE MortgagePlatform_Observability.lineage_run,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    lineage_run_id      INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
    lineage_id          INTEGER NOT NULL,
    run_dts             TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    run_status          VARCHAR(20) NOT NULL,
    run_duration_ms     INTEGER,
    records_read        INTEGER,
    records_written     INTEGER,
    records_rejected    INTEGER,
    batch_key           VARCHAR(100),
    job_name            VARCHAR(200),
    openlineage_run_id  VARCHAR(200),
    error_message       VARCHAR(2000),
    created_at          TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
)
PRIMARY INDEX (lineage_id)
PARTITION BY RANGE_N(
    run_dts BETWEEN TIMESTAMP '2025-01-01 00:00:00+00:00'
            AND     TIMESTAMP '2035-12-31 23:59:59+00:00'
            EACH INTERVAL '1' MONTH
);

COMMENT ON TABLE MortgagePlatform_Observability.lineage_run IS
'Operational execution log — one row per run of a declared lineage flow. PI on lineage_id co-locates executions with their flow definition for efficient lineage_run_latest queries. Event-scale volume.';
COMMENT ON COLUMN MortgagePlatform_Observability.lineage_run.lineage_id IS
'FK to data_lineage.lineage_id — PI column; co-locates all executions for a flow on the same AMP as its definition';
COMMENT ON COLUMN MortgagePlatform_Observability.lineage_run.run_status IS
'Execution status: SUCCESS (completed), FAILED (aborted), PARTIAL (completed with rejected rows), RUNNING (in progress)';
COMMENT ON COLUMN MortgagePlatform_Observability.lineage_run.records_rejected IS
'Rows rejected during transformation — validation failures, type mismatches, constraint violations';
COMMENT ON COLUMN MortgagePlatform_Observability.lineage_run.job_name IS
'Denormalised from data_lineage — enables fast filtering without joining to the definition table';
COMMENT ON COLUMN MortgagePlatform_Observability.lineage_run.error_message IS
'First 2000 characters of error message for FAILED or PARTIAL runs — for diagnostic triage';

COLLECT STATISTICS COLUMN (lineage_id) ON MortgagePlatform_Observability.lineage_run;
COLLECT STATISTICS COLUMN (run_dts) ON MortgagePlatform_Observability.lineage_run;
COLLECT STATISTICS COLUMN (run_status) ON MortgagePlatform_Observability.lineage_run;


-- =============================================================================
-- 5. agent_outcome
-- =============================================================================

CREATE MULTISET TABLE MortgagePlatform_Observability.agent_outcome,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    outcome_key         BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    agent_type          VARCHAR(30)  NOT NULL,
    session_key         INTEGER,
    outcome_type        VARCHAR(30)  NOT NULL,
    outcome_dts         TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    confidence_score    DECIMAL(5,4),
    user_feedback       VARCHAR(20),
    -- Mapping agent specific
    source_system       VARCHAR(100),
    columns_mapped      INTEGER,
    columns_unmapped    INTEGER,
    -- Analytics agent specific
    sql_generated       VARCHAR(4000),
    rows_returned       INTEGER,
    -- Flexible context
    outcome_context     JSON
)
PRIMARY INDEX (outcome_key)
PARTITION BY RANGE_N(
    outcome_dts BETWEEN TIMESTAMP '2025-01-01 00:00:00+00:00'
                AND     TIMESTAMP '2035-12-31 23:59:59+00:00'
                EACH INTERVAL '1' MONTH
);

COMMENT ON TABLE MortgagePlatform_Observability.agent_outcome IS
'Agent outcome records for mapping and analytics agents. Single table covering both agent types with nullable type-specific columns. Partitioned monthly for 7-year retention.';
COMMENT ON COLUMN MortgagePlatform_Observability.agent_outcome.agent_type IS
'Agent identifier: MAPPING_AGENT or ANALYTICS_AGENT';
COMMENT ON COLUMN MortgagePlatform_Observability.agent_outcome.session_key IS
'Reference to MortgagePlatform_Memory.agent_session.session_key — no physical FK across databases';
COMMENT ON COLUMN MortgagePlatform_Observability.agent_outcome.outcome_type IS
'MAPPING_AGENT: MAPPING_COMPLETE, MAPPING_PARTIAL, MAPPING_FAILED. ANALYTICS_AGENT: QUERY_ANSWERED, QUERY_FAILED, QUERY_CLARIFIED';
COMMENT ON COLUMN MortgagePlatform_Observability.agent_outcome.confidence_score IS
'Model confidence 0.0000-1.0000 — mapping agent: column-level confidence; analytics agent: query confidence';
COMMENT ON COLUMN MortgagePlatform_Observability.agent_outcome.user_feedback IS
'User quality signal: POSITIVE, NEUTRAL, NEGATIVE. NULL if no feedback provided.';
COMMENT ON COLUMN MortgagePlatform_Observability.agent_outcome.source_system IS
'MAPPING_AGENT: source system being mapped (e.g. Freddie Mac, CRM, Bureau Feed). NULL for analytics agent.';
COMMENT ON COLUMN MortgagePlatform_Observability.agent_outcome.columns_mapped IS
'MAPPING_AGENT: count of source columns successfully mapped to domain targets';
COMMENT ON COLUMN MortgagePlatform_Observability.agent_outcome.columns_unmapped IS
'MAPPING_AGENT: count of source columns with no confident domain mapping found';
COMMENT ON COLUMN MortgagePlatform_Observability.agent_outcome.sql_generated IS
'ANALYTICS_AGENT: SQL query generated in response to the natural language request';
COMMENT ON COLUMN MortgagePlatform_Observability.agent_outcome.rows_returned IS
'ANALYTICS_AGENT: aggregate row count returned — never individual keys or result data';
COMMENT ON COLUMN MortgagePlatform_Observability.agent_outcome.outcome_context IS
'Flexible JSON context — unmapped column names, clarification requests, model reasoning';

COLLECT STATISTICS COLUMN (outcome_dts) ON MortgagePlatform_Observability.agent_outcome;
COLLECT STATISTICS COLUMN (agent_type, outcome_type) ON MortgagePlatform_Observability.agent_outcome;
COLLECT STATISTICS COLUMN (user_feedback) ON MortgagePlatform_Observability.agent_outcome;


-- =============================================================================
-- VIEWS — Observability database
-- =============================================================================

REPLACE VIEW MortgagePlatform_Observability.v_quality_failures AS
SELECT database_name, table_name, metric_name,
       metric_value, threshold_value,
       measured_at, quality_context
FROM MortgagePlatform_Observability.data_quality_metric
WHERE is_below_threshold = 1;

COMMENT ON VIEW MortgagePlatform_Observability.v_quality_failures IS
'Domain tables currently failing quality thresholds — agents check this before using data for AASB9/IFRS9 or AML calculations';

REPLACE VIEW MortgagePlatform_Observability.v_recent_changes AS
SELECT database_name, table_name, operation_type,
       records_affected, changed_by, job_name, batch_key, event_dts
FROM MortgagePlatform_Observability.change_event
WHERE event_dts >= CURRENT_TIMESTAMP(6) - INTERVAL '7' DAY
  AND is_successful = 1;

COMMENT ON VIEW MortgagePlatform_Observability.v_recent_changes IS
'Successful change events from the last 7 days — quick view of recent Domain table loads';

REPLACE VIEW MortgagePlatform_Observability.v_agent_outcomes_recent AS
SELECT agent_type, outcome_type, confidence_score, user_feedback,
       source_system, columns_mapped, columns_unmapped,
       sql_generated, rows_returned, outcome_dts
FROM MortgagePlatform_Observability.agent_outcome
WHERE outcome_dts >= CURRENT_TIMESTAMP(6) - INTERVAL '30' DAY;

COMMENT ON VIEW MortgagePlatform_Observability.v_agent_outcomes_recent IS
'Agent outcomes from the last 30 days — review mapping quality and analytics query patterns';


-- =============================================================================
-- VIEWS — Semantic database (agent discovery and graph visualisation)
-- Deploy these to MortgagePlatform_Semantic, not MortgagePlatform_Observability
-- =============================================================================

-- lineage_graph: graph-ready edge list — source->job and job->target edges
-- Each data_lineage row becomes two edges in the UNION ALL.
-- CAST() is required on all literals and job_name in UNION ALL legs to prevent
-- Teradata type-width truncation (e.g. 'ETL_INPUT' 9 chars would truncate
-- 'ETL_OUTPUT' to 'ETL_OUTPU' without CAST; '' becomes VARCHAR(0)).
-- TESTED ✅
REPLACE VIEW MortgagePlatform_Semantic.lineage_graph AS
LOCKING ROW FOR ACCESS
    SELECT
         COALESCE(dl.source_database, '') || '.' || dl.source_table  AS Src_Object_Name_FQ
        ,COALESCE(dl.source_database, '')                            AS Src_Container_Name
        ,dl.source_table                                             AS Src_Object_Name
        ,CAST(CASE WHEN Src_Obj.TableKind IS NOT NULL
              THEN CASE Src_Obj.TableKind
                       WHEN 'T' THEN 'Table'  WHEN 'O' THEN 'No PI Table'
                       WHEN 'V' THEN 'View'   WHEN 'M' THEN 'Macro'
                       WHEN 'P' THEN 'Procedure' WHEN 'I' THEN 'Join Index'
                       ELSE 'Other: ' || Src_Obj.TableKind
                   END
              ELSE 'Unknown' END AS VARCHAR(30))                     AS Src_Kind
        ,COALESCE(dl.source_database, '') || '.' || dl.source_table
         || '0A'xc || ' [' || Src_Kind || ']'                       AS Src_Display_Name
        ,CAST('ETL_INPUT' AS VARCHAR(12))                            AS Edge_Relationship
        ,dl.transformation_type                                      AS Transformation_Type
        ,dl.transformation_logic                                     AS Transformation_Logic
        ,dl.lineage_id                                               AS Lineage_ID
        ,CAST(dl.job_name AS VARCHAR(200))                           AS Tgt_Object_Name_FQ
        ,CAST('' AS VARCHAR(128))                                    AS Tgt_Container_Name
        ,dl.job_name                                                 AS Tgt_Object_Name
        ,CAST('Job' AS VARCHAR(30))                                  AS Tgt_Kind
        ,dl.job_name || '0A'xc || ' [' || Tgt_Kind || ']'            AS Tgt_Display_Name
    FROM MortgagePlatform_Observability.data_lineage AS dl
    LEFT OUTER JOIN DBC.TablesV AS Src_Obj
      ON  Src_Obj.DatabaseName = dl.source_database
      AND Src_Obj.TableName    = dl.source_table
    WHERE dl.is_active = 1

    UNION ALL

    SELECT
         CAST(dl.job_name AS VARCHAR(200))                           AS Src_Object_Name_FQ
        ,CAST('' AS VARCHAR(128))                                    AS Src_Container_Name
        ,dl.job_name                                                 AS Src_Object_Name
        ,CAST('Job' AS VARCHAR(30))                                  AS Src_Kind
        ,dl.job_name || '0A'xc || ' [' || Src_Kind || ']'            AS Src_Display_Name
        ,CAST('ETL_OUTPUT' AS VARCHAR(12))                           AS Edge_Relationship
        ,dl.transformation_type                                      AS Transformation_Type
        ,dl.transformation_logic                                     AS Transformation_Logic
        ,dl.lineage_id                                               AS Lineage_ID
        ,COALESCE(dl.target_database, '') || '.' || dl.target_table  AS Tgt_Object_Name_FQ
        ,COALESCE(dl.target_database, '')                            AS Tgt_Container_Name
        ,dl.target_table                                             AS Tgt_Object_Name
        ,CAST(CASE WHEN Tgt_Obj.TableKind IS NOT NULL
              THEN CASE Tgt_Obj.TableKind
                       WHEN 'T' THEN 'Table'  WHEN 'O' THEN 'No PI Table'
                       WHEN 'V' THEN 'View'   WHEN 'M' THEN 'Macro'
                       WHEN 'P' THEN 'Procedure' WHEN 'I' THEN 'Join Index'
                       ELSE 'Other: ' || Tgt_Obj.TableKind
                   END
              ELSE 'Unknown' END AS VARCHAR(30))                     AS Tgt_Kind
        ,COALESCE(dl.target_database, '') || '.' || dl.target_table
         || '0A'xc || ' [' || Tgt_Kind || ']'                       AS Tgt_Display_Name
    FROM MortgagePlatform_Observability.data_lineage AS dl
    LEFT OUTER JOIN DBC.TablesV AS Tgt_Obj
      ON  Tgt_Obj.DatabaseName = dl.target_database
      AND Tgt_Obj.TableName    = dl.target_table
    WHERE dl.is_active = 1;

COMMENT ON VIEW MortgagePlatform_Semantic.lineage_graph IS
'Graph-ready edge list — each data_lineage row becomes two edges: source-to-job (ETL_INPUT) and job-to-target (ETL_OUTPUT). Reads definitional table only; no duplicate edges from repeated executions.';


-- lineage_run_latest: each active flow joined to its most recent execution
-- TESTED ✅
REPLACE VIEW MortgagePlatform_Semantic.lineage_run_latest AS
LOCKING ROW FOR ACCESS
SELECT
     dl.lineage_id
    ,dl.source_database
    ,dl.source_table
    ,dl.job_name
    ,dl.target_database
    ,dl.target_table
    ,dl.transformation_type
    ,dl.is_active
    ,lr.lineage_run_id
    ,lr.run_dts             AS last_run_dts
    ,lr.run_status          AS last_run_status
    ,lr.run_duration_ms     AS last_run_duration_ms
    ,lr.records_read        AS last_records_read
    ,lr.records_written     AS last_records_written
    ,lr.records_rejected    AS last_records_rejected
    ,lr.error_message       AS last_error_message
FROM MortgagePlatform_Observability.data_lineage AS dl
LEFT OUTER JOIN MortgagePlatform_Observability.lineage_run AS lr
  ON  lr.lineage_id = dl.lineage_id
  AND lr.run_dts = (
        SELECT MAX(lr2.run_dts)
        FROM   MortgagePlatform_Observability.lineage_run AS lr2
        WHERE  lr2.lineage_id = dl.lineage_id
      )
WHERE dl.is_active = 1;

COMMENT ON VIEW MortgagePlatform_Semantic.lineage_run_latest IS
'Each active lineage flow joined to its most recent execution — shows last run status, duration, and record counts alongside the flow blueprint. Agent entry point for pipeline health queries.';


-- =============================================================================
-- GRANT — cross-database access for Semantic views
-- Required so that lineage_graph and lineage_run_latest in MortgagePlatform_Semantic
-- can read from MortgagePlatform_Observability tables.
-- =============================================================================

GRANT SELECT ON MortgagePlatform_Observability TO PUBLIC WITH GRANT OPTION;
