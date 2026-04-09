-- =============================================================================
-- 04_domain_documentation.sql
-- MortgagePlatform_Domain  -  Memory and Semantic registration
--
-- Execution order: run AFTER 01_domain_ddl.sql and 03_domain_views.sql
-- Idempotent: safe to re-run (INSERTs only; no updates)
--
-- Contents:
--   A. Memory.Module_Registry        (1 row)
--   B. Memory.Design_Decision        (5 rows  -  DD-DOMAIN-001 to 005)
--   C. Memory.Business_Glossary      (5 rows  -  key mortgage domain terms)
--   D. Memory.Change_Log             (1 row  -  CL-DOMAIN-001)
--   E. Memory.Query_Cookbook         (3 rows  -  portfolio, delinquency, C360)
--   F. Semantic.entity_metadata      (5 rows  -  primary entities)
--   G. Semantic.column_metadata      (12 rows  -  PII + sensitive columns)
--   H. Semantic.table_relationship   (8 rows  -  key FK paths)
--   I. Semantic.data_product_map     (1 row  -  DOMAIN entry)
-- =============================================================================


-- =============================================================================
-- A. MEMORY  -  MODULE REGISTRY
-- =============================================================================

INSERT INTO MortgagePlatform_Memory.Module_Registry
(module_name, database_name, module_version, module_purpose,
 key_entities, dependencies, dependents,
 version_date, is_current, valid_from, valid_to)
VALUES
('DOMAIN', 'MortgagePlatform_Domain', '1.0.0',
 'Core business entities and source of truth for the MortgagePlatform AI-Native Data Product. Implements 8 BIAN Service Domains: Mortgage Loan Application, Mortgage Loan, Party Reference Data Management, Customer Profile, Customer Credit Rating, Collateral Asset Administration, Payment, and Customer Statement. All other modules (Semantic, Search, Prediction, Observability) reference Domain entities via foreign keys.',
 'LoanApplication_H, Loan_H, LoanPerformance_H, Customer_H, Property_H, PropertyValuation_H, LoanStatement_H, Payment_H',
 'MEMORY, SEMANTIC',
 'SEMANTIC, SEARCH, PREDICTION, OBSERVABILITY',
 CURRENT_DATE, 1, CURRENT_DATE, DATE '9999-12-31');


-- =============================================================================
-- B. MEMORY  -  DESIGN DECISIONS
-- =============================================================================

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description,
 context, alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 affects_table, decided_by, decided_date, valid_from, valid_to, is_current)
VALUES
('DD-DOMAIN-001', 1,
 'BIAN Service Domain alignment as entity model source',
 'The domain model is structured around BIAN (Banking Industry Architecture Network) Service Domain boundaries rather than a custom entity model or the Teradata fsDM. Eight mortgage-scoped BIAN Service Domains are implemented: Mortgage Loan Application, Mortgage Loan, Party Reference Data Management, Customer Profile, Customer Credit Rating, Collateral Asset Administration, Payment, and Customer Statement.',
 'A domain model framework was needed to organize 18+ entities covering the full mortgage lifecycle (origination, settlement, servicing). Three options were evaluated.',
 '1. Teradata fsDM: comprehensive but heavyweight; full deployment requires hundreds of entities and significant licensing/setup overhead not appropriate for a demo. 2. Custom model: fast to build but no alignment to industry standards; limits the BIAN mapping agent narrative. 3. BIAN (chosen): industry-standard service domain boundaries; directly enables the BIAN mapping agent skill that is a core deliverable of this demo.',
 'BIAN provides a widely-recognised financial services reference architecture. Aligning the domain model to BIAN Service Domains makes the AI-assisted mapping agent story credible to a financial services audience. The BIAN scope was constrained to 8 mortgage-relevant domains rather than the full catalogue to keep the model lean and demo-ready.',
 'All entity names, groupings and FK relationships follow BIAN Business Object conventions. The BIAN knowledge file (bian_knowledge.md) produced as a by-product of this design work becomes the Knowledge Source for the mapping agent skill. Teams extending the model must consult BIAN when adding new entities.',
 'ACCEPTED', 'ARCHITECTURE', 'DOMAIN', '1.0.0',
 'Loan_H, LoanApplication_H, Customer_H, Property_H',
 'Nathan Goodman', CURRENT_DATE, CURRENT_DATE, DATE '9999-12-31', 1);

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description,
 context, alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 affects_table, decided_by, decided_date, valid_from, valid_to, is_current)
VALUES
('DD-DOMAIN-002', 1,
 'Keymap pattern for stable surrogate key management',
 'A separate {Entity}_Keymap table holds the IDENTITY-generated surrogate key for each entity. History tables (_H) carry the surrogate key as BIGINT NOT NULL (not IDENTITY). All cross-entity foreign key references point to the keymap surrogate, not to _H rows.',
 'The AI-Native Data Product design standard template places GENERATED ALWAYS AS IDENTITY on the _H table itself. This creates a new surrogate for every SCD Type 2 INSERT, meaning a single loan (e.g. LOAN_SEQUENCE_NUMBER = F25Q1000001) would have surrogate keys 1, 47, 203 across its history rows. Any table with a FK to loan_key (LoanPerformance_H, LoanEvent_H, Payment_H etc.) cannot resolve which surrogate to use for a stable reference.',
 '1. IDENTITY on _H (rejected): generates duplicate surrogates per entity across history versions; FK references are ambiguous. 2. UUID/GUID (rejected): not natively supported in Teradata; harder to index and join efficiently. 3. Sequence object (rejected): adds DDL complexity without solving the cross-version problem. 4. Keymap table (chosen): IDENTITY fires once per unique natural key; _H tables hold the stable value via INSERT-then-JOIN.',
 'Keymap tables enforce one surrogate per unique natural key. The two-step load pattern (1: INSERT to keymap WHERE NOT EXISTS; 2: JOIN to keymap on INSERT to _H) is explicit but predictable. All cross-entity FKs reference the keymap surrogate, which is stable across all SCD versions.',
 'Load scripts require a two-step pattern for every entity. Five keymap tables created: LoanApplication_Keymap, Loan_Keymap, Customer_Keymap, Property_Keymap (the four entities that are FK targets from other tables). Adds one table per FK-target entity but eliminates the multi-surrogate ambiguity entirely.',
 'ACCEPTED', 'ARCHITECTURE', 'DOMAIN', '1.0.0',
 'Loan_Keymap, LoanApplication_Keymap, Customer_Keymap, Property_Keymap',
 'Nathan Goodman', CURRENT_DATE, CURRENT_DATE, DATE '9999-12-31', 1);

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description,
 context, alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 affects_table, decided_by, decided_date, valid_from, valid_to, is_current)
VALUES
('DD-DOMAIN-003', 1,
 'Child entity IDENTITY exemption: keymap not required when surrogate is not a FK target',
 'IDENTITY on _H tables is acceptable for child entities whose surrogate key is never referenced as a foreign key by any other domain table. The keymap requirement applies only to entities that are FK targets.',
 'Having established the keymap pattern for FK-target entities, a question arose about child entities (CustomerContact_H, CustomerAddress_H, CustomerSegment_H, CustomerFinancial_H, CustomerInsight_H, CustomerCompliance_H, PropertyAddress_H, PropertyRisk_H, PropertyTitle_H). These tables have FK columns pointing UP to their parent keymap, but no table has a FK pointing DOWN to their own surrogate.',
 '1. Keymap for all entities (rejected): adds 9 additional keymap tables with no functional benefit; the multi-surrogate problem only exists when another table needs to reference a stable FK. 2. IDENTITY on child _H tables (chosen): the new surrogate generated on each SCD INSERT is never referenced externally, so no consistency problem arises.',
 'The keymap pattern solves a specific problem: stable FK references across SCD versions. Child entities that are not FK targets do not have that problem. Applying keymaps universally would add complexity without benefit.',
 'Child entity history tables use GENERATED ALWAYS AS IDENTITY directly on the _H table. Load scripts for child entities are single-step INSERTs (no prior keymap step required). Documentation must clearly distinguish FK-target entities (need keymap) from child entities (do not need keymap).',
 'ACCEPTED', 'ARCHITECTURE', 'DOMAIN', '1.0.0',
 'CustomerContact_H, CustomerAddress_H, PropertyRisk_H, PropertyTitle_H',
 'Nathan Goodman', CURRENT_DATE, CURRENT_DATE, DATE '9999-12-31', 1);

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description,
 context, alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 affects_table, decided_by, decided_date, valid_from, valid_to, is_current)
VALUES
('DD-DOMAIN-004', 1,
 'Three temporal strategies applied based on entity mutation profile',
 'Three distinct temporal strategies are applied across the domain model based on how each entity changes over time: (1) Type 2 SCD for master and reference-like entities that change slowly; (2) Append-only snapshot for LoanPerformance_H (one immutable row per loan per month); (3) Append-only event for LoanEvent_H, LoanModification_H, Payment_H, and LoanStatement_H (discrete facts that never change).',
 'A single temporal strategy applied universally would either over-engineer simple facts (applying SCD to every payment event) or under-engineer slowly changing dimensions (append-only for borrower address changes loses history). The three source files have fundamentally different change characteristics.',
 '1. Bi-temporal SCD for all (rejected): overkill for a demo model; adds transaction_from_dt and transaction_to_dt to every table including event tables where they serve no purpose. 2. Type 2 SCD for all (rejected): LoanPerformance has 153K rows and grows monthly; creating new SCD versions for an immutable monthly snapshot adds unnecessary row duplication. 3. Three-strategy approach (chosen): matches the temporal pattern to the entity mutation profile.',
 'Type 2 SCD: is_current + valid_from_dt + valid_to_dt on Loan_H, LoanApplication_H, Customer_H and all child customer/property entities. Append-only snapshot: LoanPerformance_H has performance_key IDENTITY but no is_current flag; grain is loan_key x reporting_period_dt. Append-only event: LoanEvent_H, LoanModification_H, Payment_H, LoanStatement_H have IDENTITY keys; rows are immutable.',
 'Load engineers must apply the correct temporal pattern per entity type. LoanPerformance_H and event tables must never be updated after INSERT. SCD entities require the two-step expire-and-insert pattern on change detection.',
 'ACCEPTED', 'DATA_MODELLING', 'DOMAIN', '1.0.0',
 'LoanPerformance_H, LoanEvent_H, Payment_H, Loan_H, Customer_H',
 'Nathan Goodman', CURRENT_DATE, CURRENT_DATE, DATE '9999-12-31', 1);

INSERT INTO MortgagePlatform_Memory.Design_Decision
(decision_id, decision_version, decision_title, decision_description,
 context, alternatives_considered, rationale, consequences,
 decision_status, decision_category, source_module, module_version,
 affects_table, decided_by, decided_date, valid_from, valid_to, is_current)
VALUES
('DD-DOMAIN-005', 1,
 'flood_risk_zone VARCHAR(15) to correct source system truncation',
 'PropertyRisk_H.flood_risk_zone is defined as VARCHAR(15) rather than matching the source system VARCHAR(10). The source column FLOOD_RISK_ZONE in STG_Property_Valuation is VARCHAR(10), which truncates the canonical value Overland Flow (13 characters) to Overland F.',
 'During data profiling of STG_Property_Valuation, DISTINCT values of FLOOD_RISK_ZONE included Overland F (10 characters). The Freddie Mac data dictionary and standard Australian flood risk terminology use Overland Flow as the full category name. This is a source system defect: the column was sized too narrowly when the staging table was created.',
 '1. Match source column length VARCHAR(10) (rejected): propagates the truncation defect into the domain model; the canonical business value would be permanently incorrect. 2. VARCHAR(15) in domain (chosen): accommodates the full Overland Flow value; load script must expand the truncated staging value to the full canonical string.',
 'The domain model holds the correct canonical business value; the source defect is corrected at the ETL boundary. This is consistent with the domain model principle: the domain is the single source of truth, not a mirror of source system defects.',
 'Load script for PropertyRisk_H must include a CASE expression: WHEN FLOOD_RISK_ZONE = ''Overland F'' THEN ''Overland Flow'' ELSE FLOOD_RISK_ZONE END. The staging table column should be widened in a future refresh.',
 'ACCEPTED', 'DATA_QUALITY', 'DOMAIN', '1.0.0',
 'PropertyRisk_H',
 'Nathan Goodman', CURRENT_DATE, CURRENT_DATE, DATE '9999-12-31', 1);


-- =============================================================================
-- C. MEMORY  -  BUSINESS GLOSSARY
-- =============================================================================

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, synonyms, related_terms,
 related_table, related_column, source_module, module_version,
 is_active, valid_from, valid_to)
VALUES
('Loan-to-Value Ratio (LVR)',
 'MORTGAGE_RISK',
 'The ratio of the outstanding mortgage loan balance to the assessed value of the security property, expressed as a percentage. LVR = Loan Amount / Property Value x 100.',
 'LVR is the primary risk indicator for mortgage lending. APRA APS112 sets risk weight thresholds at LVR bands (e.g. 60%, 80%, 90%). Loans above 80% LVR typically require Lenders Mortgage Insurance (LMI). Two LVR measures are tracked at origination: ORIG_LTV (single first mortgage) and ORIG_CLTV (all liens combined). ESTIMATED_LVR in LoanPerformance_H reflects the current dynamic LVR updated monthly via AVM.',
 'LTV, Loan to Value',
 'UPB, Collateral Valuation, LMI, APRA APS112',
 'LoanApplication_H',
 'orig_ltv',
 'DOMAIN', '1.0.0', 1, CURRENT_DATE, DATE '9999-12-31');

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, synonyms, related_terms,
 related_table, related_column, source_module, module_version,
 is_active, valid_from, valid_to)
VALUES
('Unpaid Principal Balance (UPB)',
 'MORTGAGE_SERVICING',
 'The remaining outstanding principal amount owed on a mortgage loan at a given point in time, excluding any accrued interest or fees. UPB decreases with each principal payment and reaches zero on full repayment, prepayment, or loss event.',
 'UPB is the primary balance metric tracked throughout the mortgage lifecycle. ORIG_UPB in Loan_H is the face amount at origination. CURRENT_ACTUAL_UPB in LoanPerformance_H is the monthly snapshot. UPB movement between periods is the basis for deriving Payment_H.principal_component. A zero UPB triggers a ZERO_BALANCE_CODE entry indicating the reason for loan closure.',
 'Outstanding Balance, Loan Balance, Principal Balance',
 'LVR, Zero Balance Code, Loan Performance',
 'LoanPerformance_H',
 'current_actual_upb',
 'DOMAIN', '1.0.0', 1, CURRENT_DATE, DATE '9999-12-31');

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, synonyms, related_terms,
 related_table, related_column, source_module, module_version,
 is_active, valid_from, valid_to)
VALUES
('BIAN Service Domain',
 'ARCHITECTURE',
 'A bounded context defined by the Banking Industry Architecture Network (BIAN) that encapsulates a specific business capability within a financial institution. Each Service Domain owns its own Business Objects, processes and information. The MortgagePlatform domain model maps to 8 BIAN Service Domains relevant to the mortgage lifecycle.',
 'BIAN Service Domains are used as the organising principle for entity groupings in this domain model. The 8 domains are: Mortgage Loan Application (origination), Mortgage Loan (servicing), Party Reference Data Management (customer identity), Customer Profile (CRM), Customer Credit Rating (KYC/AML), Collateral Asset Administration (property), Payment, and Customer Statement. This alignment enables the BIAN mapping agent to match source system columns to the correct Service Domain and Business Object.',
 'Service Domain, BIAN SD',
 'Business Object, BIAN, Domain Model',
 'entity_metadata',
 'entity_description',
 'DOMAIN', '1.0.0', 1, CURRENT_DATE, DATE '9999-12-31');

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, synonyms, related_terms,
 related_table, related_column, source_module, module_version,
 is_active, valid_from, valid_to)
VALUES
('Keymap',
 'DATA_ARCHITECTURE',
 'A Keymap table is a small lookup table with one row per unique business entity. It holds the IDENTITY-generated surrogate key for that entity. History tables (_H) reference the surrogate from the Keymap rather than generating their own IDENTITY values, ensuring a single stable surrogate per real-world entity across all SCD Type 2 versions.',
 'The Keymap pattern was introduced to solve a specific problem with SCD Type 2 history tables: if IDENTITY is placed on the _H table, every new SCD version generates a new surrogate, making it impossible for child tables to maintain a stable foreign key reference to their parent entity. By placing IDENTITY in a separate Keymap table and populating _H.entity_key from a JOIN to the Keymap, each real-world entity has exactly one surrogate that never changes. Five Keymap tables exist: LoanApplication_Keymap, Loan_Keymap, Customer_Keymap, Property_Keymap. Child entities that are not FK targets do not require their own Keymap.',
 'Key Map, Surrogate Key Registry',
 'SCD Type 2, Surrogate Key, Foreign Key',
 'Loan_Keymap',
 'loan_key',
 'DOMAIN', '1.0.0', 1, CURRENT_DATE, DATE '9999-12-31');

INSERT INTO MortgagePlatform_Memory.Business_Glossary
(term, term_category, definition, business_context, synonyms, related_terms,
 related_table, related_column, source_module, module_version,
 is_active, valid_from, valid_to)
VALUES
('Delinquency Status',
 'MORTGAGE_RISK',
 'A classification of a loan''s repayment position at a given reporting date, measured in months or days past due. Codes follow the Freddie Mac convention: 0=Current, 1=30 days past due, 2=60 days past due, 3=90 days past due (non-performing threshold), 4=120 days, 5=150 days, 6=180+ days, RA=REO Acquisition.',
 'Delinquency status is the primary early-warning indicator in the mortgage portfolio. Escalation from 0 to 1 to 2 triggers increasing servicer intervention. Reaching status 3 (90+ days past due) typically triggers a non-performing loan (NPL) classification under AASB9/IFRS9, requiring Stage 3 expected credit loss provisioning. Delinquency trends across LoanPerformance_H periods drive the churn and risk prediction models. The DelinquencyStatus_R reference table includes is_performing=0 for codes 3 through RA.',
 'Arrears Status, DPD, Days Past Due',
 'LVR, Zero Balance Code, NPL, AASB9',
 'LoanPerformance_H',
 'delinquency_status_cd',
 'DOMAIN', '1.0.0', 1, CURRENT_DATE, DATE '9999-12-31');


-- =============================================================================
-- D. MEMORY  -  CHANGE LOG
-- =============================================================================

INSERT INTO MortgagePlatform_Memory.Change_Log
(change_id, version_number, change_title, change_description,
 change_type, change_category, source_module, affects_table,
 related_decision_id, deployed_date, deployed_by, deployment_status)
VALUES
('CL-DOMAIN-001', '1.0.0',
 'Domain module initial release',
 'Created complete MortgagePlatform_Domain schema aligned to 8 BIAN Service Domains. Includes: 14 reference tables with seed data (70 reference rows total), 5 keymap tables, 18 history/snapshot/event tables, and 20 views (_Current, _Enriched, _Latest). All COMMENT ON TABLE and COMMENT ON COLUMN applied. Keymap pattern implemented for FK-target entities. Three temporal strategies applied: Type 2 SCD for master entities, append-only snapshot for LoanPerformance_H, append-only event for LoanEvent_H/Payment_H/LoanStatement_H. Source: Freddie Mac origination (37,500 loans), Freddie Mac performance (153,382 monthly rows), synthetic Borrower Profile (37,500 customers), synthetic Property Valuation (37,500 properties).',
 'INITIAL_RELEASE', 'SCHEMA', 'DOMAIN',
 'Loan_H, LoanApplication_H, Customer_H, Property_H, LoanPerformance_H',
 'DD-DOMAIN-001',
 CURRENT_DATE, 'Nathan Goodman', 'DEPLOYED');


-- =============================================================================
-- E. MEMORY  -  QUERY COOKBOOK
-- =============================================================================

INSERT INTO MortgagePlatform_Memory.Query_Cookbook
(recipe_id, recipe_title, recipe_description, use_case, target_module,
 sql_template, parameter_descriptions, performance_notes, complexity,
 source_module, module_version, is_active, valid_from, valid_to)
VALUES
('QC-DOMAIN-001',
 'Current portfolio position  -  loan with latest performance and property',
 'Returns one row per active loan with its current UPB, delinquency status, latest estimated LVR, and key property details. This is the primary portfolio monitoring query and the starting point for most risk reporting.',
 'Portfolio risk monitoring, delinquency dashboard, capital reporting',
 'Domain',
 'SELECT
    l.loan_id,
    l.orig_upb,
    l.orig_interest_rate,
    l.orig_loan_term_months,
    l.loan_status,
    p.current_actual_upb,
    p.delinquency_status_cd,
    ds.delinquency_status_nm,
    ds.is_performing,
    p.estimated_ltv,
    p.reporting_period_dt          AS latest_performance_period,
    pr.latest_valuation_amount,
    pr.address_suburb              AS property_suburb,
    pr.address_state               AS property_state
FROM MortgagePlatform_Domain.Loan_Current          l
JOIN MortgagePlatform_Domain.LoanPerformance_Latest p  ON p.loan_key = l.loan_key
LEFT JOIN MortgagePlatform_Domain.DelinquencyStatus_R ds ON ds.delinquency_status_cd = p.delinquency_status_cd
LEFT JOIN MortgagePlatform_Domain.Property_Enriched   pr ON pr.loan_key = l.loan_key
ORDER BY l.loan_id;',
 'No parameters required. Loan_Current filters is_current=1 and is_deleted=0. LoanPerformance_Latest returns only the most recent period per loan.',
 'PI on loan_key in both Loan_H and LoanPerformance_H ensures AMP co-location; the JOIN is efficient. Property_Enriched joins 5 tables internally; filter to specific loan_key values if running for a portfolio subset. Expected row count: ~37,500 (one per active loan).',
 'MEDIUM',
 'DOMAIN', '1.0.0', 1, CURRENT_DATE, DATE '9999-12-31');

INSERT INTO MortgagePlatform_Memory.Query_Cookbook
(recipe_id, recipe_title, recipe_description, use_case, target_module,
 sql_template, parameter_descriptions, performance_notes, complexity,
 source_module, module_version, is_active, valid_from, valid_to)
VALUES
('QC-DOMAIN-002',
 'Delinquency trend  -  monthly escalation and cure rates by cohort',
 'Tracks delinquency status transitions month-over-month for a loan cohort. Joins consecutive LoanPerformance_H periods to identify escalations (status worsening) and cures (status improving). Foundation for churn prediction feature engineering.',
 'Early arrears detection, churn modelling, servicer performance reporting',
 'Domain',
 'SELECT
    curr.loan_key,
    curr.reporting_period_dt       AS current_period,
    prev.reporting_period_dt       AS prior_period,
    prev.delinquency_status_cd     AS prior_status,
    curr.delinquency_status_cd     AS current_status,
    CASE
        WHEN CAST(curr.delinquency_status_cd AS INTEGER) >
             CAST(prev.delinquency_status_cd AS INTEGER)
        THEN ''ESCALATION''
        WHEN CAST(curr.delinquency_status_cd AS INTEGER) <
             CAST(prev.delinquency_status_cd AS INTEGER)
        THEN ''CURE''
        ELSE ''UNCHANGED''
    END AS status_movement,
    curr.current_actual_upb,
    curr.estimated_ltv
FROM MortgagePlatform_Domain.LoanPerformance_H curr
JOIN MortgagePlatform_Domain.LoanPerformance_H prev
    ON prev.loan_key = curr.loan_key
    AND prev.reporting_period_dt = ADD_MONTHS(curr.reporting_period_dt, -1)
WHERE curr.delinquency_status_cd <> ''RA''
  AND prev.delinquency_status_cd <> ''RA''
ORDER BY curr.loan_key, curr.reporting_period_dt;',
 'Adjust the ADD_MONTHS offset to compare different lag periods. Add WHERE curr.reporting_period_dt = <target_period> to restrict to a single month. Replace <target_period> with a DATE literal e.g. DATE '2025-06-01'.',
 'Self-join on LoanPerformance_H uses the loan_key PI for AMP co-location  -  both sides of the join resolve to the same AMP. Performance is good for monthly reporting. For full history scans across all 9 periods, expect ~153K x 2 row reads.',
 'MEDIUM',
 'DOMAIN', '1.0.0', 1, CURRENT_DATE, DATE '9999-12-31');

INSERT INTO MortgagePlatform_Memory.Query_Cookbook
(recipe_id, recipe_title, recipe_description, use_case, target_module,
 sql_template, parameter_descriptions, performance_notes, complexity,
 source_module, module_version, is_active, valid_from, valid_to)
VALUES
('QC-DOMAIN-003',
 'Customer 360  -  full customer profile with loan, property and compliance',
 'Returns a single wide row per customer combining identity, CRM segment, financial profile, compliance status, churn risk, and their current loan and property position. Supports customer service, RM briefings, and regulatory compliance reporting.',
 'Customer 360, relationship management, regulatory reporting, KYC remediation',
 'Domain',
 'SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.date_of_birth,
    c.citizenship_status,
    c.digital_banking_enrolled,
    ce.segment_name,
    ce.kyc_status,
    ce.kyc_is_compliant,
    ce.aml_risk_rating,
    ce.aml_edd_required,
    cf.annual_income,
    cf.employment_status_cd,
    cf.income_verified_flag,
    ci.churn_risk_score,
    ci.churn_risk_band,
    ci.nps_score,
    l.loan_id,
    l.orig_upb,
    l.loan_status,
    perf.current_actual_upb,
    perf.delinquency_status_cd,
    pr.latest_valuation_amount,
    pr.address_suburb              AS property_suburb
FROM MortgagePlatform_Domain.Customer_Current       c
JOIN MortgagePlatform_Domain.Customer_Enriched      ce  ON ce.customer_key = c.customer_key
LEFT JOIN MortgagePlatform_Domain.CustomerFinancial_Current  cf  ON cf.customer_key = c.customer_key
LEFT JOIN MortgagePlatform_Domain.CustomerInsight_Current    ci  ON ci.customer_key = c.customer_key
LEFT JOIN MortgagePlatform_Domain.Loan_Current               l   ON l.customer_key  = c.customer_key
LEFT JOIN MortgagePlatform_Domain.LoanPerformance_Latest     perf ON perf.loan_key  = l.loan_key
LEFT JOIN MortgagePlatform_Domain.Property_Enriched          pr  ON pr.loan_key     = l.loan_key
WHERE c.deceased_flag = 0
ORDER BY c.customer_id;',
 'Add WHERE c.customer_id = :customer_id for single-customer lookup. Add WHERE ce.kyc_is_compliant = 0 for KYC remediation lists. Add WHERE ce.aml_edd_required = 1 for EDD review lists.',
 'Customer_Current and Customer_Enriched both filter is_current=1; the join is lightweight. CustomerFinancial and CustomerInsight are PI on customer_key matching Customer_H. Loan join uses customer_key which is not the PI of Loan_H (PI is loan_key)  -  consider adding a secondary index on customer_key in Loan_H if this query runs frequently at scale.',
 'COMPLEX',
 'DOMAIN', '1.0.0', 1, CURRENT_DATE, DATE '9999-12-31');


-- =============================================================================
-- F. SEMANTIC  -  ENTITY METADATA (primary entities)
-- =============================================================================

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column, entity_description,
 entity_category, record_count_approx, is_active)
VALUES
('DOMAIN', 'LoanApplication', 'MortgagePlatform_Domain', 'LoanApplication_H', 'LoanApplication_Current',
 'loan_application_id', 'loan_application_key',
 'BIAN: Mortgage Loan Application. Captures loan application attributes at origination including channel, purpose, LTV, DTI, credit score, and program indicators. All records are approved/funded applications. Source: STG_Freddie_Origination.',
 'MASTER', 37500, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column, entity_description,
 entity_category, record_count_approx, is_active)
VALUES
('DOMAIN', 'Loan', 'MortgagePlatform_Domain', 'Loan_H', 'Loan_Current',
 'loan_id', 'loan_key',
 'BIAN: Mortgage Loan. The funded mortgage facility  -  central entity of the domain model. Holds origination terms (UPB, rate, term, amortisation type) and current loan status. All other tables reference loan_key. Source: STG_Freddie_Origination + STG_Freddie_Performance.',
 'MASTER', 37500, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column, entity_description,
 entity_category, record_count_approx, is_active)
VALUES
('DOMAIN', 'LoanPerformance', 'MortgagePlatform_Domain', 'LoanPerformance_H', 'LoanPerformance_Latest',
 'loan_id + reporting_period_dt', 'performance_key',
 'BIAN: Mortgage Loan (servicing). Append-only monthly snapshot of loan performance. One immutable row per loan per reporting month. Contains UPB, delinquency status, interest rate, estimated LTV, modification flags, and loss accounting fields. Grain: loan_key x reporting_period_dt. Source: STG_Freddie_Performance. 153,382 rows covering Jan-Sep 2025.',
 'SNAPSHOT', 153382, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column, entity_description,
 entity_category, record_count_approx, is_active)
VALUES
('DOMAIN', 'Customer', 'MortgagePlatform_Domain', 'Customer_H', 'Customer_Current',
 'customer_id', 'customer_key',
 'BIAN: Party Reference Data Management. Enterprise customer identity record. Holds name, DOB, gender, citizenship, digital banking status and relationship dates. Parent entity for CustomerContact_H, CustomerAddress_H, CustomerSegment_H, CustomerFinancial_H, CustomerInsight_H, CustomerCompliance_H. Source: STG_Borrower_Profile. 37,500 customers.',
 'MASTER', 37500, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column, entity_description,
 entity_category, record_count_approx, is_active)
VALUES
('DOMAIN', 'Property', 'MortgagePlatform_Domain', 'Property_H', 'Property_Current',
 'property_id', 'property_key',
 'BIAN: Collateral Asset Administration. Security property record. Holds property type, status, physical characteristics (bedrooms, bathrooms, land area) and zoning. Parent entity for PropertyAddress_H, PropertyValuation_H, PropertyRisk_H, PropertyTitle_H. Source: STG_Property_Valuation. 37,500 properties. Valuation range 33K-10.9M AUD.',
 'MASTER', 37500, 1);


-- =============================================================================
-- G. SEMANTIC  -  COLUMN METADATA (PII and sensitive columns)
-- =============================================================================

-- PII columns
INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, is_active, sample_values, validation_rule)
VALUES ('MortgagePlatform_Domain', 'Customer_H', 'first_name',
 'Customer given name(s). Personally Identifiable Information  -  access restricted to authorised roles.',
 'VARCHAR(50)', 1, 0, 1, 1, NULL, 'NOT NULL');

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, is_active, sample_values, validation_rule)
VALUES ('MortgagePlatform_Domain', 'Customer_H', 'last_name',
 'Customer family name. Personally Identifiable Information  -  access restricted.',
 'VARCHAR(50)', 1, 0, 1, 1, NULL, 'NOT NULL');

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, is_active, sample_values, validation_rule)
VALUES ('MortgagePlatform_Domain', 'Customer_H', 'date_of_birth',
 'Customer date of birth. PII  -  used for age verification, estate management, and APRA regulatory reporting. Range 1950-2004 in dataset.',
 'DATE', 1, 0, 1, 1, NULL, 'NOT NULL; must be in past');

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, is_active, sample_values, validation_rule)
VALUES ('MortgagePlatform_Domain', 'CustomerContact_H', 'email_address',
 'Customer primary email address. PII  -  subject to Australian Privacy Act; must not be used for unsolicited communications without marketing_opt_in=1.',
 'VARCHAR(100)', 1, 0, 0, 1, NULL, 'Must match email format if not null');

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, is_active, sample_values, validation_rule)
VALUES ('MortgagePlatform_Domain', 'CustomerContact_H', 'mobile_number',
 'Customer mobile phone number. PII  -  Australian format +61 4XX XXX XXX.',
 'VARCHAR(20)', 1, 0, 0, 1, NULL, NULL);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, is_active, sample_values, validation_rule)
VALUES ('MortgagePlatform_Domain', 'CustomerAddress_H', 'address_line_1',
 'Customer primary residential address. PII  -  full street address.',
 'VARCHAR(100)', 1, 0, 1, 1, NULL, 'NOT NULL');

-- Sensitive (not PII but regulated or confidential)
INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, is_active, sample_values, validation_rule)
VALUES ('MortgagePlatform_Domain', 'CustomerCompliance_H', 'aml_risk_rating_cd',
 'AML risk rating: L=Low, M=Medium, H=High. SENSITIVE  -  regulated attribute under AML/CTF Act. H rating requires Enhanced Due Diligence. Access restricted to compliance team.',
 'CHAR(1)', 0, 1, 1, 1, 'L, M, H', 'Values: L, M, H only');

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, is_active, sample_values, validation_rule)
VALUES ('MortgagePlatform_Domain', 'CustomerCompliance_H', 'kyc_status_cd',
 'KYC verification status. SENSITIVE  -  regulated attribute. Expired/Pending/Failed statuses may require transaction restriction.',
 'VARCHAR(20)', 0, 1, 1, 1, 'Verified, Pending, Expired, Failed', 'FK to KYCStatus_R');

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, is_active, sample_values, validation_rule)
VALUES ('MortgagePlatform_Domain', 'CustomerFinancial_H', 'annual_income',
 'Declared annual gross income in AUD. SENSITIVE  -  financial information; access restricted to credit and relationship management roles. Range 30K-786K in dataset.',
 'DECIMAL(15,2)', 0, 1, 0, 1, NULL, 'Must be > 0 if present');

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, is_active, sample_values, validation_rule)
VALUES ('MortgagePlatform_Domain', 'LoanApplication_H', 'credit_score_at_application',
 'Borrower FICO credit score at origination (scale 300-850). SENSITIVE  -  credit information; access restricted. For multi-borrower loans: representative score per Freddie Mac guidelines. Range 300-832 in dataset.',
 'SMALLINT', 0, 1, 0, 1, NULL, 'Range 300-850 if present');

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, is_active, sample_values, validation_rule)
VALUES ('MortgagePlatform_Domain', 'LoanApplication_H', 'orig_dti',
 'Debt-to-Income ratio at origination (%). SENSITIVE  -  financial assessment data. Key serviceability metric; high DTI is a credit risk indicator.',
 'SMALLINT', 0, 1, 0, 1, NULL, 'Range 0-100 if present');

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, is_active, sample_values, validation_rule)
VALUES ('MortgagePlatform_Domain', 'CustomerInsight_H', 'churn_risk_score',
 'Model-generated churn propensity score (0.00-1.00). SENSITIVE  -  analytically-derived risk indicator; access restricted to analytics and RM teams.',
 'DECIMAL(5,2)', 0, 1, 0, 1, NULL, 'Range 0.00-1.00 if present');


-- =============================================================================
-- H. SEMANTIC  -  TABLE RELATIONSHIPS (key FK paths)
-- =============================================================================

INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'Loan_H', 'loan_application_key',
        'MortgagePlatform_Domain', 'LoanApplication_Keymap', 'loan_application_key',
        'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1,
        'Each funded loan traces back to the originating application');

INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'Loan_H', 'customer_key',
        'MortgagePlatform_Domain', 'Customer_Keymap', 'customer_key',
        'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1,
        'Each loan is held by a customer (borrower)');

INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'Loan_H', 'property_key',
        'MortgagePlatform_Domain', 'Property_Keymap', 'property_key',
        'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1,
        'Each loan is secured against a property');

INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'LoanPerformance_H', 'loan_key',
        'MortgagePlatform_Domain', 'Loan_Keymap', 'loan_key',
        'FOREIGN_KEY', 'INNER', 'MANY_TO_ONE', 1, 1,
        'Each monthly performance snapshot belongs to a specific loan');

INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'LoanApplication_H', 'customer_key',
        'MortgagePlatform_Domain', 'Customer_Keymap', 'customer_key',
        'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1,
        'Each loan application is submitted by a customer');

INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'Property_H', 'loan_key',
        'MortgagePlatform_Domain', 'Loan_Keymap', 'loan_key',
        'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1,
        'Each security property is registered against a mortgage loan');

INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'Property_H', 'customer_key',
        'MortgagePlatform_Domain', 'Customer_Keymap', 'customer_key',
        'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1,
        'Each security property is owned by / associated with a customer');

INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'LoanStatement_H', 'loan_key',
        'MortgagePlatform_Domain', 'Loan_Keymap', 'loan_key',
        'FOREIGN_KEY', 'INNER', 'MANY_TO_ONE', 1, 1,
        'Each loan statement is issued for a specific loan  -  primary lineage link for the regulatory reporting demo');


-- =============================================================================
-- I. SEMANTIC  -  DATA PRODUCT MAP
-- =============================================================================

INSERT INTO MortgagePlatform_Semantic.data_product_map
(module_name, database_name, module_purpose, primary_tables,
 agent_entry_view, is_active)
VALUES
('DOMAIN', 'MortgagePlatform_Domain',
 'Core business entities  -  source of truth for the MortgagePlatform AI-Native Data Product. Implements 8 BIAN Service Domains covering the full mortgage lifecycle from origination through servicing.',
 'Loan_H, LoanApplication_H, LoanPerformance_H, Customer_H, Property_H, PropertyValuation_H, LoanStatement_H, Payment_H',
 'Loan_Current',
 1);
