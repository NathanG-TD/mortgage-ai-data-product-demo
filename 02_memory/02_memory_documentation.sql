-- =============================================================================
-- 02_memory_documentation.sql
-- MortgagePlatform_Memory - Documentation INSERTs
--
-- Populates all six design memory tables for the Memory and Staging modules.
-- Run after 01_memory_ddl.sql.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Module_Registry - one row per deployed module
-- ---------------------------------------------------------------------------

INSERT INTO MortgagePlatform_Memory.Module_Registry
(module_name, database_name, module_version, module_purpose, module_scope,
 key_entities, dependencies, dependents,
 version_date, is_current, valid_from, valid_to, created_timestamp)
VALUES
('MEMORY', 'MortgagePlatform_Memory', '1.0.0',
 'Agent state, learning, and design memory for the MortgagePlatform mortgage data product. Captures runtime agent sessions, interactions, learned strategies, and discovered patterns. Hosts all design documentation tables (Module_Registry, Design_Decision, Business_Glossary, Query_Cookbook, Implementation_Note, Change_Log) shared across all modules.',
 'All runtime memory scoped to USER and ORGANIZATION levels. Design memory is product-wide.',
 'agent_session, agent_interaction, learned_strategy, discovered_pattern, Design_Decision, Business_Glossary',
 'None - Memory is always deployed first',
 'SEMANTIC, DOMAIN, OBSERVABILITY',
 CURRENT_DATE, 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Module_Registry
(module_name, database_name, module_version, module_purpose, module_scope,
 key_entities, dependencies, dependents,
 version_date, is_current, valid_from, valid_to, created_timestamp)
VALUES
('STAGING', 'MortgagePlatform_Staging', '1.0.0',
 'Raw source data staging layer. Receives pipe-delimited extracts from four source systems: Freddie Mac Loan Origination System (LOS), Freddie Mac Loan Servicing System, CRM Customer Master, and Collateral Management System. No transformations applied - columns mirror source file layouts exactly.',
 'Staging tables are the source-of-truth for raw data before domain modelling. All downstream modules derive from these tables.',
 'STG_Freddie_Origination, STG_Freddie_Performance, STG_Borrower_Profile, STG_Property_Valuation',
 'None - Staging receives from external source systems',
 'DOMAIN',
 CURRENT_DATE, 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

-- ---------------------------------------------------------------------------
-- Design_Decision - minimum 3 per module; ID format DD-{MODULE}-{NNN}
-- ---------------------------------------------------------------------------

-- MEMORY module decisions
INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description, context,
 alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-MEMORY-001', 1,
 'Two privacy scope levels: USER and ORGANIZATION',
 'The Memory module uses two scope levels - USER (private to one user) and ORGANIZATION (shared across all agents and users). TEAM scope was considered but not implemented.',
 'MortgagePlatform is a single-team product. Business Analysts share learned strategies and query patterns, but personal session history must remain private.',
 'Three-level (USER, TEAM, ORGANIZATION): adds complexity without clear benefit for a single-team product. Four-level (add AGENT): unnecessary for current agent architecture.',
 'Two levels match the actual privacy boundaries in this product. Simpler to reason about and govern. Can be extended to three or four levels when multi-team usage begins.',
 'All runtime tables require scope_level and scope_identifier columns. Queries for shared content use WHERE scope_level = ''ORGANIZATION''. User-specific queries use WHERE scope_level = ''USER'' AND scope_identifier = :user_key.',
 'ACCEPTED', 'ARCHITECTURE', 'MEMORY', '1.0.0',
 CURRENT_DATE, CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description, context,
 alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-MEMORY-002', 1,
 'Runtime memory stores table names and counts only - never instance data',
 'The agent_interaction table stores referenced_tables (comma-separated table names) and query_result_count (aggregate count). It never stores individual record keys, customer IDs, loan numbers, or query result sets.',
 'Mortgage data contains sensitive customer financial information. Storing record-level data in the memory module would create a shadow copy of PII outside the governed Domain layer.',
 'Store full result sets in agent_interaction for richer context: rejected - creates uncontrolled PII sprawl. Store record keys only: rejected - still links to PII and provides no additional analytical value.',
 'Table-level metadata is sufficient for learning and continuity. An agent can reconstruct context from table names and counts without needing individual records. This principle eliminates all PII risk from the memory layer.',
 'Agents must re-query the Domain layer to retrieve actual data. Interaction logs cannot be used to reconstruct individual customer records. Compliance risk from the memory module is eliminated.',
 'ACCEPTED', 'SECURITY', 'MEMORY', '1.0.0',
 CURRENT_DATE, CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description, context,
 alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-MEMORY-003', 1,
 'All six design memory tables mandatory regardless of product complexity',
 'Module_Registry, Design_Decision, Business_Glossary, Query_Cookbook, Implementation_Note, and Change_Log are all created and populated regardless of how simple or complex the product is.',
 'Early-stage products often defer documentation tables, leading to knowledge debt. The MortgagePlatform demo must model best practices for a large-bank audience.',
 'Create documentation tables on demand as needed: rejected - creates inconsistent agent discovery behaviour. Create only Module_Registry and Business_Glossary for MVP: rejected - agents need Query_Cookbook to demonstrate NL query capability.',
 'Mandatory documentation tables ensure the agent always has a consistent set of tables to query. The Query_Cookbook is particularly important for the BA demo - it demonstrates how tacit SQL knowledge is made explicit and queryable.',
 'Every module deployment must include documentation INSERT statements. This adds ~30 minutes of design time per module but eliminates the documentation debt that typically accumulates.',
 'ACCEPTED', 'ARCHITECTURE', 'MEMORY', '1.0.0',
 CURRENT_DATE, CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));

-- STAGING module decisions
INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description, context,
 alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-STAGING-001', 1,
 'Staging tables mirror source file layouts exactly - no transformation at load time',
 'STG_Freddie_Origination, STG_Freddie_Performance, STG_Borrower_Profile, and STG_Property_Valuation have column definitions that exactly match the source file structure. No renaming, recasting, or business logic is applied during the load.',
 'The demo use case is data mapping: showing an agent read a source column definition and propose a mapping to a domain target. If the staging table has already renamed columns, the mapping exercise loses its authenticity.',
 'Apply light transformations at staging (e.g. rename ORIG_CLTV to combined_ltv): rejected - defeats the purpose of the mapping demo. Load directly to domain without a staging layer: rejected - staging is required for the agent to show lineage from raw source.',
 'Authentic staging column names (ORIG_CLTV, CRED_SCORE_CURR, ENQ_3M) create a realistic mapping challenge for the agent and BA audience. The gap between source naming and domain naming is the core of the demo story.',
 'All transformation logic lives in domain load scripts, not staging loaders. COMMENT ON metadata on staging columns carries the semantic bridge that the mapping agent reads.',
 'ACCEPTED', 'ARCHITECTURE', 'STAGING', '1.0.0',
 CURRENT_DATE, CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description, context,
 alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-STAGING-002', 1,
 'Freddie Mac data used as-is; synthetic files generated to simulate Australian bank context',
 'The two Freddie Mac files (Origination, Performance) are loaded without modification. The Borrower Profile and Property Valuation files are synthetically generated to reflect Australian bank conventions (AUD, Australian state codes, 4-digit postcodes, APRA regulatory references).',
 'No Australian mortgage dataset exists at sufficient scale with the right combination of origination, servicing, customer, and collateral data. Freddie Mac provides the most realistic loan-level dataset publicly available.',
 'Use entirely synthetic data: rejected - loses the realistic origination metrics (FICO scores, LTV distributions, delinquency codes) that make the demo credible to a bank audience. Use only Freddie Mac data: rejected - does not provide customer CRM or collateral attributes needed for domain model breadth.',
 'Hybrid approach gives the best of both: authentic loan-level metrics from a real dataset, Australian customer and property context for the BA audience, and a four-source architecture that mirrors a real bank data landscape.',
 'Freddie Mac data uses USD and US conventions. Mapping agent must note currency and geographic context differences when mapping to Australian bank domain model. Explicitly documented in staging COMMENT ON metadata.',
 'ACCEPTED', 'INTEGRATION', 'STAGING', '1.0.0',
 CURRENT_DATE, CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description, context,
 alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-STAGING-003', 1,
 'Credit bureau feed withheld as a separate demo source for Act 2 onboarding scenario',
 'STG_Credit_Bureau_Feed is pre-defined in 08_withheld_source/ but deliberately not loaded during initial setup. It is introduced during the demo to show a new source being onboarded into a mature domain model.',
 'The core BA use case is mapping new source data into an existing enterprise model. Showing this live - with the agent discovering existing entities, proposing mappings, and flagging the FICO vs Equifax scale difference - requires the domain model to already be mature when the bureau feed arrives.',
 'Include bureau feed in initial load: rejected - eliminates the live onboarding narrative. Use a completely unrelated new source: rejected - the bureau feed enriching existing Customer and Loan entities is a more realistic and impactful scenario than a new entity type.',
 'The bureau feed has deliberately cryptic column names (ENQ_3M, CRED_SCORE_CURR, DEROG_MARKS) that mirror real bureau extract conventions. The FICO vs Equifax scale mismatch is a specific tacit knowledge problem that the agent must identify and flag - this is the centrepiece of the mapping demo.',
 'The 08_withheld_source/ directory must not be run during initial environment setup. Demo facilitators must follow 08_withheld_source/README.md sequence exactly.',
 'ACCEPTED', 'OPERATIONAL', 'STAGING', '1.0.0',
 CURRENT_DATE, CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));

-- ---------------------------------------------------------------------------
-- Business_Glossary - mortgage domain terminology
-- ---------------------------------------------------------------------------

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, synonyms, related_terms,
 related_table, related_column, source_module,
 is_active, valid_from, valid_to, created_timestamp)
VALUES
('LTV', 'METRIC',
 'Loan-to-Value ratio - the loan amount divided by the appraised property value, expressed as a percentage. A 75% LTV means the loan is 75% of the property value.',
 'LTV is the primary collateral risk metric in mortgage lending. Loans with LTV > 80% typically require Lenders Mortgage Insurance (LMI) in Australia. At origination, LTV is calculated against the formal valuation. Current LTV is estimated using AVM refreshes and current outstanding balance.',
 'Loan-to-Value|LVR (Loan-to-Value Ratio - Australian term)',
 'CLTV, LMI, LVR, Collateral, Valuation',
 'MortgagePlatform_Staging.STG_Freddie_Origination', 'ORIG_LTV',
 'STAGING', 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, synonyms, related_terms,
 related_table, related_column, source_module,
 is_active, valid_from, valid_to, created_timestamp)
VALUES
('CLTV', 'METRIC',
 'Combined Loan-to-Value ratio - the sum of all mortgage liens against a property divided by the property value. CLTV equals LTV when there is only one mortgage. CLTV > LTV when subordinate (second) liens exist.',
 'CLTV is the more conservative risk measure when a borrower has both a first and second mortgage. For risk-weighted asset calculations under APRA guidelines, CLTV is used when assessing the full encumbrance on a property. In Freddie Mac data, CLTV is stored in ORIG_CLTV.',
 'Combined LTV|ORIG_CLTV',
 'LTV, LVR, Subordinate Lien, Encumbrance',
 'MortgagePlatform_Staging.STG_Freddie_Origination', 'ORIG_CLTV',
 'STAGING', 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, synonyms, related_terms,
 related_table, related_column, source_module,
 is_active, valid_from, valid_to, created_timestamp)
VALUES
('DTI', 'METRIC',
 'Debt-to-Income ratio - monthly debt obligations (including the proposed mortgage payment) divided by gross monthly income, expressed as a percentage. A 35% DTI means 35 cents of every dollar of income services debt.',
 'DTI is the primary affordability metric at origination. Australian lenders typically cap DTI at 6-8x annual income under APRA macroprudential guidance. High DTI (>45%) at origination is a significant predictor of mortgage stress and churn. Stored as ORIG_DTI in the Freddie Mac origination file.',
 'Debt-to-Income|ORIG_DTI|Serviceability Ratio',
 'ORIG_DTI, Affordability, Mortgage Stress, Churn Risk',
 'MortgagePlatform_Staging.STG_Freddie_Origination', 'ORIG_DTI',
 'STAGING', 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, synonyms, related_terms,
 related_table, related_column, source_module,
 is_active, valid_from, valid_to, created_timestamp)
VALUES
('Zero Balance Code', 'REFERENCE_CODE',
 'A code in the monthly performance file indicating why a loan reached a zero balance. Key codes: 01=Prepaid or Matured (voluntary), 02=Third Party Sale (distressed), 03=Short Sale (distressed), 06=Repurchase, 09=REO Disposition (foreclosure).',
 'Zero balance codes are the definitive churn classification signal. Code 01 represents voluntary churn (customer refinanced or sold). Codes 02, 03, and 09 represent distressed exits with credit loss. The distinction between voluntary and distressed churn drives different retention and loss mitigation strategies.',
 'ZERO_BALANCE_CODE|ZBC|Loan Exit Code',
 'Churn, Prepayment, Foreclosure, REO, Short Sale, Delinquency',
 'MortgagePlatform_Staging.STG_Freddie_Performance', 'ZERO_BALANCE_CODE',
 'STAGING', 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, synonyms, related_terms,
 related_table, related_column, source_module,
 is_active, valid_from, valid_to, created_timestamp)
VALUES
('Derogatory Mark', 'BUSINESS_RULE',
 'A negative entry on a credit bureau file indicating a credit impairment event. Includes: recorded defaults, court judgements, bankruptcy filings, and Part IX debt agreements. In the bureau feed, DEROG_MARKS counts total derogatory marks on file.',
 'Derogatory marks are the most significant fraud and credit risk signal in the bureau feed. A customer with derogatory marks who also has recent high enquiry counts (ENQ_3M > 5) is flagged as a potential fraud or hardship case requiring mandatory review under APRA guidelines. SERIOUS_CREDIT_IMPAIRMENT=Y is set whenever any derogatory mark exists.',
 'DEROG_MARKS|Adverse Credit Event|Negative Listing',
 'SERIOUS_CREDIT_IMPAIRMENT, NUM_DEFAULTS, BANKRUPTCY_FLAG, PART_IX_FLAG, AML_RISK_RATING',
 'MortgagePlatform_Staging.STG_Credit_Bureau_Feed', 'DEROG_MARKS',
 'STAGING', 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, synonyms, related_terms,
 related_table, related_column, source_module,
 is_active, valid_from, valid_to, created_timestamp)
VALUES
('AML Risk Rating', 'CLASSIFICATION',
 'Anti-Money Laundering risk rating assigned to a customer by the bank compliance function. Values: L=Low, M=Medium, H=High. Determined through KYC screening, transaction pattern analysis, and PEP/sanctions list checking.',
 'AML risk rating is a regulated attribute under the Anti-Money Laundering and Counter-Terrorism Financing Act 2006 (Australia). Access to H-rated customer records requires elevated system privileges and audit trail. Any domain model column holding AML data must be flagged is_sensitive=1 in the Semantic layer.',
 'AML_RISK_RATING|AML Rating|Risk Rating',
 'KYC_STATUS, Compliance, Regulated Attribute, PEP, Sanctions',
 'MortgagePlatform_Staging.STG_Borrower_Profile', 'AML_RISK_RATING',
 'STAGING', 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, synonyms, related_terms,
 related_table, related_column, source_module,
 is_active, valid_from, valid_to, created_timestamp)
VALUES
('Equifax Scale vs FICO Scale', 'BUSINESS_RULE',
 'Two different credit scoring scales used in this data product. FICO scale (range 300-850) is used in Freddie Mac origination data (CREDIT_SCORE column). Equifax scale (range 0-1200) is used in the credit bureau feed (CRED_SCORE_CURR column). These scales are NOT directly comparable.',
 'This scale difference is a critical tacit knowledge item that manual BAs often miss when mapping bureau data to existing domain models. A CRED_SCORE_CURR of 622 (Equifax Good) is not the same as a CREDIT_SCORE of 622 (FICO Fair). Mapping agents must flag this semantic mismatch and recommend separate domain attributes rather than merging into one credit_score column.',
 'Credit Score Scale|Scoring Model Difference',
 'CREDIT_SCORE, CRED_SCORE_CURR, CRED_SCORE_BAND, bureau_credit_score',
 'MortgagePlatform_Staging.STG_Credit_Bureau_Feed', 'CRED_SCORE_CURR',
 'STAGING', 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

-- ---------------------------------------------------------------------------
-- Query_Cookbook - proven query patterns for this domain
-- ---------------------------------------------------------------------------

INSERT INTO MortgagePlatform_Memory.Query_Cookbook
(recipe_id, recipe_title, recipe_description, use_case, target_module,
 sql_template, parameter_descriptions, performance_notes, complexity,
 source_module, is_active, valid_from, valid_to, created_timestamp)
VALUES
('QC-STAGING-001',
 'Find all staging tables and their source systems',
 'Lists all staging tables registered in the Semantic layer with their source system descriptions and row counts. Used by the mapping agent as the first step in discovering what source data is available.',
 'Agent bootstrap - source data discovery',
 'SEMANTIC',
 'SELECT em.entity_name, em.database_name, em.table_name, em.entity_description, em.record_count_approx
FROM MortgagePlatform_Semantic.entity_metadata em
WHERE em.module_name = ''STAGING''
  AND em.is_active = 1
ORDER BY em.entity_name;',
 'No parameters required - returns all staging entities',
 'entity_metadata is small (< 100 rows); no performance concerns',
 'SIMPLE', 'STAGING',
 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Query_Cookbook
(recipe_id, recipe_title, recipe_description, use_case, target_module,
 sql_template, parameter_descriptions, performance_notes, complexity,
 source_module, is_active, valid_from, valid_to, created_timestamp)
VALUES
('QC-STAGING-002',
 'Identify loans with escalating delinquency - churn early warning',
 'Finds loans that have moved from current (status 0) to delinquent (status 1 or higher) within the performance data. This is the primary churn early-warning signal for the mortgage portfolio.',
 'Churn risk identification - portfolio monitoring',
 'STAGING',
 'SELECT
    p.LOAN_SEQUENCE_NUMBER,
    MIN(CASE WHEN p.CURRENT_LOAN_DELINQUENCY_STATUS = ''0'' THEN p.MONTHLY_REPORTING_PERIOD END) AS last_current_period,
    MAX(p.CURRENT_LOAN_DELINQUENCY_STATUS) AS worst_delinquency_status,
    COUNT(*) AS total_performance_months
FROM MortgagePlatform_Staging.STG_Freddie_Performance p
WHERE p.ZERO_BALANCE_CODE IS NULL
GROUP BY p.LOAN_SEQUENCE_NUMBER
HAVING MAX(p.CURRENT_LOAN_DELINQUENCY_STATUS) > ''0''
ORDER BY worst_delinquency_status DESC;',
 'No parameters - returns all active delinquent loans. Add HAVING COUNT(*) > {min_months} to filter by loan age.',
 'STG_Freddie_Performance has 153k rows. Add PI on LOAN_SEQUENCE_NUMBER for large scans if needed.',
 'MODERATE', 'STAGING',
 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Query_Cookbook
(recipe_id, recipe_title, recipe_description, use_case, target_module,
 sql_template, parameter_descriptions, performance_notes, complexity,
 source_module, is_active, valid_from, valid_to, created_timestamp)
VALUES
('QC-STAGING-003',
 'Cross-source customer risk profile - join all four staging sources',
 'Joins all four active staging tables to produce a combined customer risk profile including loan metrics, current performance status, customer segment, and property valuation. Starting point for the domain model entity design.',
 'Domain model design - understanding cross-source join paths',
 'STAGING',
 'SELECT
    b.CUSTOMER_ID,
    b.CUSTOMER_SEGMENT,
    b.CHURN_RISK_BAND,
    o.LOAN_SEQUENCE_NUMBER,
    o.ORIG_UPB,
    o.ORIG_LTV,
    o.CREDIT_SCORE,
    p.CURRENT_LOAN_DELINQUENCY_STATUS,
    p.ESTIMATED_LOAN_TO_VALUE  AS current_ltv,
    pv.CURRENT_VALUATION_AMOUNT,
    pv.FLOOD_RISK_ZONE
FROM MortgagePlatform_Staging.STG_Borrower_Profile b
JOIN MortgagePlatform_Staging.STG_Freddie_Origination o
    ON o.LOAN_SEQUENCE_NUMBER = b.LOAN_SEQUENCE_NUMBER
LEFT JOIN MortgagePlatform_Staging.STG_Freddie_Performance p
    ON p.LOAN_SEQUENCE_NUMBER = o.LOAN_SEQUENCE_NUMBER
    AND p.MONTHLY_REPORTING_PERIOD = (
        SELECT MAX(p2.MONTHLY_REPORTING_PERIOD)
        FROM MortgagePlatform_Staging.STG_Freddie_Performance p2
        WHERE p2.LOAN_SEQUENCE_NUMBER = o.LOAN_SEQUENCE_NUMBER
    )
LEFT JOIN MortgagePlatform_Staging.STG_Property_Valuation pv
    ON pv.CUSTOMER_ID = b.CUSTOMER_ID
SAMPLE 100;',
 'No parameters - returns 100 sample rows. Remove SAMPLE 100 for full result.',
 'The correlated subquery for latest performance period is expensive at scale. For production use, materialise latest_performance as a derived table first.',
 'COMPLEX', 'STAGING',
 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

-- ---------------------------------------------------------------------------
-- Change_Log - initial release entries
-- ---------------------------------------------------------------------------

INSERT INTO MortgagePlatform_Memory.Change_Log
(change_id, version_number, change_title, change_description,
 change_type, change_category, source_module,
 deployed_date, deployed_by, deployment_status, created_timestamp)
VALUES
('CL-MEMORY-001', '1.0.0',
 'Initial release of MortgagePlatform_Memory module',
 'Created all 11 Memory module tables: 5 runtime memory tables (agent_session, agent_interaction, learned_strategy, user_preference, discovered_pattern) and 6 design memory tables (Module_Registry, Design_Decision, Business_Glossary, Query_Cookbook, Implementation_Note, Change_Log). Created 4 standard views. Populated documentation for MEMORY and STAGING modules.',
 'INITIAL_RELEASE', 'ADDITIVE', 'MEMORY',
 CURRENT_DATE, 'MortgagePlatform Setup', 'DEPLOYED', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Change_Log
(change_id, version_number, change_title, change_description,
 change_type, change_category, source_module,
 deployed_date, deployed_by, deployment_status, created_timestamp)
VALUES
('CL-STAGING-001', '1.0.0',
 'Initial release of MortgagePlatform_Staging module',
 'Created 4 staging tables: STG_Freddie_Origination (37,500 rows, 32 columns), STG_Freddie_Performance (153,382 rows, 32 columns), STG_Borrower_Profile (37,500 rows, synthetic), STG_Property_Valuation (37,500 rows, synthetic). All tables have COMMENT ON metadata. Zero referential integrity orphans across all join paths.',
 'INITIAL_RELEASE', 'ADDITIVE', 'STAGING',
 CURRENT_DATE, 'MortgagePlatform Setup', 'DEPLOYED', CURRENT_TIMESTAMP(6));

-- ---------------------------------------------------------------------------
-- Implementation_Note - known operational issues
-- ---------------------------------------------------------------------------

INSERT INTO MortgagePlatform_Memory.Implementation_Note
(note_id, note_title, note_content, note_category, severity,
 affects_table, resolution_status,
 source_module, is_active, valid_from, valid_to, created_timestamp)
VALUES
('IN-STAGING-001',
 'Freddie Mac file format varies by vintage year - verify column count before loading',
 'The Freddie Mac origination file grew from 27 columns (pre-2018) to 32 columns (2018+ format). The performance file grew from 31 to 32 columns. The load scripts in 01_source_data/load_scripts/ are calibrated for the 32-column 2025 format. If loading an older vintage, verify the column count matches before running. Use: python3 -c "import csv; f=open(''file.csv''); r=csv.reader(f,delimiter=''|''); print(len(next(r)))"',
 'KNOWN_ISSUE', 'LOW',
 'MortgagePlatform_Staging.STG_Freddie_Origination', 'RESOLVED',
 'STAGING', 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Implementation_Note
(note_id, note_title, note_content, note_category, severity,
 affects_table, resolution_status,
 source_module, is_active, valid_from, valid_to, created_timestamp)
VALUES
('IN-STAGING-002',
 'teradatasql returns float NaN for NULL numeric columns - use null-safe coercers',
 'When querying staging tables via the teradatasql Python driver, NULL values in INTEGER and DECIMAL columns are returned as float(''nan''), not Python None. float(''nan'') is truthy so standard if-checks pass and int(nan) raises ValueError. Always use _is_null() / safe_int() / safe_float() helper functions (defined in 04_generate_property_valuation.py) when consuming numeric columns from teradatasql query results.',
 'WORKAROUND', 'MEDIUM',
 'All MortgagePlatform_Staging tables', 'RESOLVED',
 'STAGING', 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

-- =============================================================================
-- MODULE REGISTRY - PLANNED modules (Search, Prediction, Observability)
-- Added to align with AI-Native Data Product Design Standard v1.7
-- which requires a Module_Registry row for every module considered during
-- design, not just those deployed.
-- =============================================================================

INSERT INTO MortgagePlatform_Memory.Module_Registry
(module_name, database_name, deployment_status, module_version, module_purpose,
 module_scope, dependencies, dependents, version_date, is_current, valid_from, valid_to,
 created_timestamp)
VALUES
('SEARCH', 'MortgagePlatform_Search', 'PLANNED', 'N/A',
 'Vector embeddings and semantic similarity search for mortgage domain entities - enables agents to find similar loans, properties, and customers via embedding-based retrieval and RAG patterns.',
 'Deferred to Phase 3. Depends on Domain module being stable and populated. Primary use cases: similar-property discovery for collateral risk analysis, RAG-based customer query answering. Target: post-initial-demo release.',
 'DOMAIN, SEMANTIC', 'None',
 CURRENT_DATE, 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Module_Registry
(module_name, database_name, deployment_status, module_version, module_purpose,
 module_scope, dependencies, dependents, version_date, is_current, valid_from, valid_to,
 created_timestamp)
VALUES
('PREDICTION', 'MortgagePlatform_Prediction', 'PLANNED', 'N/A',
 'Feature store and ML prediction storage for mortgage risk and customer analytics - pre-computed features for churn risk, default probability, and portfolio segmentation models.',
 'Deferred to Phase 3. Depends on Domain and Observability modules. Primary use cases: default risk scoring, customer churn prediction, LVR-based risk-weighted asset calculation. Requires model development outside this demo scope.',
 'DOMAIN, SEMANTIC, OBSERVABILITY', 'None',
 CURRENT_DATE, 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Module_Registry
(module_name, database_name, deployment_status, module_version, module_purpose,
 module_scope, dependencies, dependents, version_date, is_current, valid_from, valid_to,
 created_timestamp)
VALUES
('OBSERVABILITY', 'MortgagePlatform_Observability', 'PLANNED', 'N/A',
 'Event tracking, data quality monitoring, and lineage for all mortgage platform modules - captures change events, quality scores, and source-to-target lineage for regulatory and operational audit.',
 'Deferred to Phase 2b. Depends on Domain module. Priority use cases: AASB9/IFRS9 data lineage for expected credit loss calculation, AML transaction monitoring audit trail, data quality scoring for bureau feed onboarding. Target: required before production go-live.',
 'DOMAIN, SEMANTIC', 'PREDICTION',
 CURRENT_DATE, 1, CURRENT_DATE, DATE '9999-12-31', CURRENT_TIMESTAMP(6));

-- =============================================================================
-- DESIGN DECISIONS - scope and deferral decisions
-- Added to align with AI-Native Data Product Design Standard v1.7
-- DD-SCOPE-001: database layout choice (mandatory at first deployment)
-- DD-SCOPE-002/003/004: one per deferred module (mandatory per new standard)
-- DD-MEMORY-004: Memory standalone entities documented as intentional
-- =============================================================================

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description,
 context, alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_by, decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-SCOPE-001', 1,
 'Database layout: separate database per module',
 'Each module is deployed in its own Teradata database following the {ProductName}_{Module} naming pattern: MortgagePlatform_Domain, MortgagePlatform_Semantic, MortgagePlatform_Memory, MortgagePlatform_Staging.',
 'Two layout options exist in the AI-Native Data Product standard: (1) separate database per module, (2) single database with module-prefixed tables. The choice affects access control granularity, deployment independence, and operational complexity.',
 'Single database with module prefixes - simpler to manage, fewer database objects, no cross-database joins.',
 'Separate databases chosen. Enables independent access control per module via GRANT DATABASE, supports incremental deployment of modules in phases, and clearly communicates module boundaries to the team. Aligns with the enterprise default recommendation in the design standard.',
 'Cross-database joins required when agents query across modules. Each new module requires a new database provisioned. Deployment scripts must create databases before tables.',
 'ACCEPTED', 'ARCHITECTURE', 'SCOPE', '1.0.0',
 'Data Architecture Team', CURRENT_DATE,
 CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description,
 context, alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_by, decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-SCOPE-002', 1,
 'Observability module deferred to Phase 2b',
 'The Observability module (MortgagePlatform_Observability) is not deployed in the initial release. It is scoped for Phase 2b, after the core Domain model is validated with real data.',
 'Observability provides change event capture, data quality scoring, and source-to-target lineage. For a demo environment these are valuable but not blocking. In production, AASB9/IFRS9 expected credit loss calculation requires auditable data lineage, and AML/CTF obligations require a change audit trail - making Observability mandatory before go-live.',
 'Deploy Observability in Phase 1 alongside Domain - adds significant deployment complexity and scope to the initial build. Defer indefinitely - not appropriate given regulatory requirements.',
 'Deferred to Phase 2b. The Domain model must be stable before Observability tables are meaningful. Phase 2b trigger: first integration with production data sources or commencement of UAT with compliance team.',
 'No automated data quality scoring in initial release. Lineage from staging to domain is manual (documented in 06_lineage/lineage_queries.sql). Change audit trail not available until Observability is deployed.',
 'ACCEPTED', 'ARCHITECTURE', 'SCOPE', '1.0.0',
 'Data Architecture Team', CURRENT_DATE,
 CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description,
 context, alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_by, decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-SCOPE-003', 1,
 'Search module deferred to Phase 3',
 'The Search module (MortgagePlatform_Search) is not deployed in the initial release. It is scoped for Phase 3, after the Domain model is stable and an embedding strategy is agreed.',
 'Search enables vector-based similarity queries on mortgage entities - similar property discovery, semantic loan matching, and RAG-based natural language query answering. These require an agreed embedding model and vector index strategy.',
 'Deploy Search in Phase 2 - premature without a validated embedding model and without production data volumes to justify the infrastructure. Defer indefinitely - not appropriate as it is a core AI-native differentiator.',
 'Deferred to Phase 3. The primary demo value is in the domain model, agent discovery, and source mapping capabilities. Search adds the semantic layer. Phase 3 trigger: production data onboarding complete and embedding model selected.',
 'No semantic similarity search in initial release. Agents must use SQL-based filtering rather than natural language similarity queries. No RAG capability against mortgage domain knowledge.',
 'ACCEPTED', 'ARCHITECTURE', 'SCOPE', '1.0.0',
 'Data Architecture Team', CURRENT_DATE,
 CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description,
 context, alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_by, decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-SCOPE-004', 1,
 'Prediction module deferred to Phase 3',
 'The Prediction module (MortgagePlatform_Prediction) is not deployed in the initial release. It is scoped for Phase 3, after Observability is available and model development is underway.',
 'Prediction provides a feature store and ML prediction storage for mortgage risk models - default probability, churn risk, and LVR-based risk-weighted asset calculations. It depends on Observability for feature drift monitoring.',
 'Deploy Prediction in Phase 2 - premature without validated features and without Observability providing the quality layer. Defer indefinitely - not appropriate as risk modelling is a core use case.',
 'Deferred to Phase 3, sequenced after Observability. Phase 3 trigger: Observability deployed and at least one model in development requiring a structured feature store.',
 'No pre-computed risk features in initial release. Agents must derive features on-the-fly from Domain tables. No model prediction storage available in the demo period.',
 'ACCEPTED', 'ARCHITECTURE', 'SCOPE', '1.0.0',
 'Data Architecture Team', CURRENT_DATE,
 CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description,
 context, alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 decided_by, decided_date, valid_from, valid_to, is_current, created_timestamp)
VALUES
('DD-MEMORY-004', 1,
 'Memory design memory tables are intentionally standalone in table_relationship',
 'agent_session, Business_Glossary, and Query_Cookbook are registered in entity_metadata but have no entries in table_relationship. This is intentional - not an omission.',
 'The table_relationship completeness check flags entities with no registered relationships. These three Memory tables trigger that check. The standard requires either adding relationships or documenting the standalone status.',
 'Register FK-style or SEMANTIC relationships to other Memory tables - adds noise without agent navigation value since these tables are content stores not transactional entities.',
 'Memory design memory tables use VARCHAR columns to reference other tables by name, not surrogate key FKs. There are no JOIN paths an agent would be expected to traverse. Each is a self-contained knowledge store queried independently.',
 'These three tables will always appear in the isolation check. Agents running the check should exclude Memory design memory tables from isolation reports.',
 'ACCEPTED', 'ARCHITECTURE', 'MEMORY', '1.0.0',
 'Data Architecture Team', CURRENT_DATE,
 CURRENT_DATE, DATE '9999-12-31', 1, CURRENT_TIMESTAMP(6));
