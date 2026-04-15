-- =============================================================================
-- 02_semantic_registration.sql
-- MortgagePlatform_Semantic — data_product_map, entity_metadata,
--                              column_metadata, table_relationship,
--                              naming_standard registrations
--
-- This file is the agent's primary discovery resource. Every staging table,
-- key column, and join path is registered here so agents can autonomously
-- map, query, and trace lineage without human guidance.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- data_product_map — one row per deployed module (agent bootstrap)
-- ---------------------------------------------------------------------------

INSERT INTO MortgagePlatform_Semantic.data_product_map
(module_name, database_name, module_purpose, primary_tables, agent_entry_view, is_active)
VALUES
('MEMORY', 'MortgagePlatform_Memory',
 'Agent state, learning, and design memory. Contains runtime session/interaction tables and all design documentation (Module_Registry, Design_Decision, Business_Glossary, Query_Cookbook). Query this module first to understand design decisions and proven query patterns.',
 'agent_session, agent_interaction, learned_strategy, Module_Registry, Design_Decision, Business_Glossary, Query_Cookbook',
 'MortgagePlatform_Memory.v_Module_Registry_Current',
 1);

INSERT INTO MortgagePlatform_Semantic.data_product_map
(module_name, database_name, module_purpose, primary_tables, agent_entry_view, is_active)
VALUES
('SEMANTIC', 'MortgagePlatform_Semantic',
 'Queryable metadata layer for autonomous agent discovery. Contains entity catalog, column metadata, join relationships, and naming standards. This module is self-describing — querying it reveals the full structure of all other modules.',
 'data_product_map, entity_metadata, column_metadata, table_relationship, naming_standard',
 'MortgagePlatform_Semantic.v_entity_catalog',
 1);

INSERT INTO MortgagePlatform_Semantic.data_product_map
(module_name, database_name, module_purpose, primary_tables, agent_entry_view, is_active)
VALUES
('STAGING', 'MortgagePlatform_Staging',
 'Raw source data staging layer. Four source systems: Loan Origination (Freddie Mac), Loan Servicing (Freddie Mac), CRM Customer Master (synthetic), Collateral Management (synthetic). Columns mirror source file layouts exactly — no transformations applied. COMMENT ON metadata on each column provides the semantic bridge for mapping agents.',
 'STG_Freddie_Origination, STG_Freddie_Performance, STG_Borrower_Profile, STG_Property_Valuation',
 NULL,
 1);

-- ---------------------------------------------------------------------------
-- entity_metadata — all staging tables
-- ---------------------------------------------------------------------------

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column,
 entity_description, entity_category, record_count_approx, is_active)
VALUES
('STAGING', 'FreddieOrigination', 'MortgagePlatform_Staging',
 'STG_Freddie_Origination', NULL,
 'LOAN_SEQUENCE_NUMBER', NULL,
 'Freddie Mac Single Family Origination file. One record per loan at origination. Source: Loan Origination System (LOS). 32 columns covering borrower credit profile, loan terms, property type, and origination channel. Key join to all other staging tables via LOAN_SEQUENCE_NUMBER.',
 'SOURCE_SYSTEM', 37500, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column,
 entity_description, entity_category, record_count_approx, is_active)
VALUES
('STAGING', 'FreddiePerformance', 'MortgagePlatform_Staging',
 'STG_Freddie_Performance', NULL,
 'LOAN_SEQUENCE_NUMBER', NULL,
 'Freddie Mac Monthly Performance file. One record per loan per reporting month (grain: loan x month). Source: Loan Servicing System. 32 columns covering delinquency status, UPB, modifications, and loss events. Primary source for churn signals (ZERO_BALANCE_CODE) and fraud indicators (MODIFICATION_FLAG patterns).',
 'SOURCE_SYSTEM', 153382, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column,
 entity_description, entity_category, record_count_approx, is_active)
VALUES
('STAGING', 'BorrowerProfile', 'MortgagePlatform_Staging',
 'STG_Borrower_Profile', NULL,
 'CUSTOMER_ID', NULL,
 'CRM Customer Master record. One record per customer (synthetic, Australian context). Source: Customer Relationship Management system. 40 columns covering identity, contact details, segmentation, compliance (KYC/AML), and analytically-derived scores (churn risk, NPS). Contains PII and regulated attributes.',
 'SOURCE_SYSTEM', 37500, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column,
 entity_description, entity_category, record_count_approx, is_active)
VALUES
('STAGING', 'PropertyValuation', 'MortgagePlatform_Staging',
 'STG_Property_Valuation', NULL,
 'PROPERTY_ID', NULL,
 'Collateral Management System property and valuation records. One record per property (synthetic, Australian context). Source: Valuation/Collateral Management system. 40 columns covering physical attributes, legal title, origination valuation, AVM refresh, and environmental risk (flood, fire). Contains both origination and current valuations for LVR monitoring.',
 'SOURCE_SYSTEM', 37500, 1);

-- Memory module entities
INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column,
 entity_description, entity_category, record_count_approx, is_active)
VALUES
('MEMORY', 'AgentSession', 'MortgagePlatform_Memory',
 'agent_session', 'v_active_sessions',
 'session_id', 'session_key',
 'Agent session state — tracks active and historical sessions for continuity across interactions',
 'MEMORY', 0, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column,
 entity_description, entity_category, record_count_approx, is_active)
VALUES
('MEMORY', 'BusinessGlossary', 'MortgagePlatform_Memory',
 'Business_Glossary', NULL,
 'term', 'glossary_key',
 'Mortgage domain business term definitions — reduces tacit knowledge dependency; covers LTV, CLTV, DTI, Zero Balance Codes, AML, and credit score scale differences',
 'MEMORY', 0, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column,
 entity_description, entity_category, record_count_approx, is_active)
VALUES
('MEMORY', 'QueryCookbook', 'MortgagePlatform_Memory',
 'Query_Cookbook', NULL,
 'recipe_id', 'recipe_key',
 'Proven SQL query patterns for mortgage data — churn detection, cross-source joins, delinquency analysis',
 'MEMORY', 0, 1);

-- ---------------------------------------------------------------------------
-- column_metadata — key columns per staging table
-- ---------------------------------------------------------------------------

-- STG_Freddie_Origination key columns
INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Freddie_Origination',
 'LOAN_SEQUENCE_NUMBER',
 'Primary key. Unique loan identifier assigned by Freddie Mac. Format: FddQqNNNNNN. Join key to STG_Freddie_Performance and STG_Borrower_Profile.',
 'CHAR(12)', 0, 0, 1,
 'F25Q10000021|F25Q10000045|F25Q10000052',
 'Must not be null. Format: F followed by 2-digit year, Q, quarter number, 6-digit sequence.', 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Freddie_Origination',
 'ORIG_UPB',
 'Original Unpaid Principal Balance — the face amount of the loan at origination in USD. Primary loan size metric.',
 'DECIMAL(15,2)', 0, 0, 1,
 '143000.00|76000.00|189000.00|333000.00',
 'Must be > 0. Currency: USD (Freddie Mac data). Convert to AUD for Australian domain model.', 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Freddie_Origination',
 'ORIG_LTV',
 'Original Loan-to-Value ratio (percentage). Loan amount divided by appraised property value at origination. Australian equivalent term: LVR.',
 'INTEGER', 0, 0, 0,
 '61|70|72|80|95',
 'Range: 1-105. Loans with ORIG_LTV > 80 typically require LMI in Australia.', 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Freddie_Origination',
 'ORIG_CLTV',
 'Original Combined Loan-to-Value ratio (percentage). Sum of all mortgage liens at origination divided by property value. CLTV >= LTV when subordinate liens exist.',
 'INTEGER', 0, 0, 0,
 '61|70|72|80|95',
 'Range: 1-105. CLTV is the conservative risk measure when second mortgages exist.', 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Freddie_Origination',
 'CREDIT_SCORE',
 'Borrower FICO credit score at origination. Range 300-850. IMPORTANT: This uses the FICO scale — NOT the Equifax 0-1200 scale used in STG_Credit_Bureau_Feed.CRED_SCORE_CURR. Do not merge these columns in the domain model without scale conversion.',
 'INTEGER', 0, 0, 0,
 '666|718|745|756|797',
 'Range: 300-850 (FICO scale). Null if not available. Average in this dataset: ~756.', 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Freddie_Origination',
 'ORIG_DTI',
 'Original Debt-to-Income ratio (percentage). Monthly debt obligations divided by gross monthly income. Key affordability and churn risk predictor.',
 'INTEGER', 0, 0, 0,
 '22|33|34|42',
 'Range: 1-65. High DTI (>45) at origination correlates with mortgage stress. APRA macroprudential guidance targets DTI < 6x annual income.', 1);

-- STG_Freddie_Performance key columns
INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Freddie_Performance',
 'CURRENT_LOAN_DELINQUENCY_STATUS',
 'Current delinquency status as of the reporting month. 0=Current, 1=30 days past due, 2=60 days, 3=90 days, 4=120 days, 5=150 days, 6=180+ days, RA=REO Acquisition. Escalating values are the primary churn early-warning signal.',
 'CHAR(3)', 0, 0, 0,
 '0|1|2|3|6|RA',
 'Values: 0-6 (months past due) or RA. Null indicates no data for that period.', 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Freddie_Performance',
 'ZERO_BALANCE_CODE',
 'Reason a loan reached zero balance. 01=Prepaid/Matured (voluntary churn), 02=Third Party Sale, 03=Short Sale, 09=REO Disposition (foreclosure). Null when loan is still active. This is the definitive churn classification.',
 'CHAR(2)', 0, 0, 0,
 '01|02|03|09',
 'Null = loan still active. 01 = voluntary churn. 02/03/09 = distressed exit. Never co-occurs with non-zero CURRENT_ACTUAL_UPB.', 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Freddie_Performance',
 'MODIFICATION_FLAG',
 'Y if the loan was modified in this reporting period. Repeated modifications combined with ongoing delinquency is a fraud/hardship indicator.',
 'CHAR(1)', 0, 0, 0,
 'Y|N',
 'Values: Y or N. Multiple Y values across consecutive periods with non-zero delinquency status warrants investigation.', 1);

-- STG_Borrower_Profile key columns
INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Borrower_Profile',
 'CUSTOMER_ID',
 'Bank-assigned master customer identifier. Format: CUS-XXXXXXXX. Enterprise customer key — all product systems reference this. Join to STG_Property_Valuation.CUSTOMER_ID.',
 'VARCHAR(20)', 0, 0, 1,
 'CUS-00000001|CUS-00000002',
 'Must not be null. Format: CUS- prefix followed by 8 digits.', 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Borrower_Profile',
 'FIRST_NAME',
 'Customer first (given) name. PII — subject to privacy controls.',
 'VARCHAR(50)', 1, 0, 1, NULL, NULL, 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Borrower_Profile',
 'LAST_NAME',
 'Customer last (family) name. PII — subject to privacy controls.',
 'VARCHAR(50)', 1, 0, 1, NULL, NULL, 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Borrower_Profile',
 'DATE_OF_BIRTH',
 'Customer date of birth. PII — used for identity verification and age-based eligibility rules.',
 'DATE', 1, 0, 1, NULL, NULL, 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Borrower_Profile',
 'AML_RISK_RATING',
 'Anti-Money Laundering risk rating. L=Low, M=Medium, H=High. REGULATED ATTRIBUTE — access requires elevated privileges and audit trail. Subject to AML/CTF Act 2006 (Australia).',
 'CHAR(1)', 0, 1, 1,
 'L|M|H',
 'Values: L, M, H only. H-rated records require mandatory review and audit logging.', 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Borrower_Profile',
 'CHURN_RISK_SCORE',
 'Model-generated churn propensity score. Range 0.00-1.00. Higher = higher churn probability. Analytically-derived — loaded back from analytics platform, not a raw CRM field.',
 'DECIMAL(5,2)', 0, 0, 0,
 '0.12|0.35|0.67|0.89',
 'Range: 0.00-1.00. High risk band: > 0.60. Derived field — do not overwrite with source system data.', 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Borrower_Profile',
 'CUSTOMER_SEGMENT',
 'CRM marketing segment classification. Drives relationship management and product eligibility rules.',
 'VARCHAR(30)', 0, 0, 0,
 'Mass Market|Emerging Affluent|Affluent|Private Banking|Business Owner',
 'Permitted values: Mass Market, Emerging Affluent, Affluent, Private Banking, Business Owner.', 1);

-- STG_Property_Valuation key columns
INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Property_Valuation',
 'PROPERTY_ID',
 'Bank-assigned unique property identifier. Format: PROP-XXXXXXXX. Primary key. Join to STG_Borrower_Profile via CUSTOMER_ID.',
 'VARCHAR(20)', 0, 0, 1,
 'PROP-00000001|PROP-00000002',
 'Must not be null. Format: PROP- prefix followed by 8 digits.', 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Property_Valuation',
 'ORIG_VALUATION_AMOUNT',
 'Formal valuation amount at loan origination (AUD). Basis for original LVR calculation. Should reconcile with STG_Freddie_Origination.ORIG_UPB / (ORIG_LTV/100) within rounding tolerance.',
 'DECIMAL(15,2)', 0, 0, 1,
 '450000.00|680000.00|1200000.00',
 'Must be > 0 when PROPERTY_STATUS = Active.', 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Property_Valuation',
 'CURRENT_VALUATION_AMOUNT',
 'Most recent AVM or formal valuation (AUD). Used with current UPB to calculate estimated LVR for portfolio risk monitoring. Critical for APRA risk-weighted asset calculations.',
 'DECIMAL(15,2)', 0, 0, 0,
 '480000.00|720000.00|1150000.00',
 'Null if no AVM refresh has occurred. Should be compared to ORIG_VALUATION_AMOUNT to assess property value drift.', 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Property_Valuation',
 'FLOOD_RISK_ZONE',
 'Flood risk classification from council/government flood mapping. Used in APRA risk-weighted asset calculations and insurance requirements.',
 'VARCHAR(10)', 0, 0, 0,
 'Low|Medium|High|Overland Flow',
 'Permitted values: Low, Medium, High, Overland Flow. Null if not assessed.', 1);

-- ---------------------------------------------------------------------------
-- table_relationship — all join paths between staging tables
-- ---------------------------------------------------------------------------

-- STG_Freddie_Performance → STG_Freddie_Origination
INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES
('MortgagePlatform_Staging', 'STG_Freddie_Performance', 'LOAN_SEQUENCE_NUMBER',
 'MortgagePlatform_Staging', 'STG_Freddie_Origination', 'LOAN_SEQUENCE_NUMBER',
 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 1, 1,
 'Each performance month record belongs to one origination record. One loan has many monthly performance records.');

-- STG_Borrower_Profile → STG_Freddie_Origination
INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES
('MortgagePlatform_Staging', 'STG_Borrower_Profile', 'LOAN_SEQUENCE_NUMBER',
 'MortgagePlatform_Staging', 'STG_Freddie_Origination', 'LOAN_SEQUENCE_NUMBER',
 'FOREIGN_KEY', 'LEFT', 'ONE_TO_ONE', 1, 1,
 'Each borrower profile links to one origination record (1:1 in this demo dataset). In production, one customer may hold multiple loans.');

-- STG_Property_Valuation → STG_Borrower_Profile
INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES
('MortgagePlatform_Staging', 'STG_Property_Valuation', 'CUSTOMER_ID',
 'MortgagePlatform_Staging', 'STG_Borrower_Profile', 'CUSTOMER_ID',
 'FOREIGN_KEY', 'LEFT', 'ONE_TO_ONE', 1, 1,
 'Each property record links to one customer via CUSTOMER_ID. One customer has one property in this demo dataset.');

-- STG_Property_Valuation → STG_Freddie_Origination (via LOAN_SEQUENCE_NUMBER)
INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES
('MortgagePlatform_Staging', 'STG_Property_Valuation', 'LOAN_SEQUENCE_NUMBER',
 'MortgagePlatform_Staging', 'STG_Freddie_Origination', 'LOAN_SEQUENCE_NUMBER',
 'FOREIGN_KEY', 'LEFT', 'ONE_TO_ONE', 1, 1,
 'Direct join from property to origination for valuation cross-checks (ORIG_UPB vs ORIG_VALUATION_AMOUNT reconciliation).');

-- ---------------------------------------------------------------------------
-- naming_standard — abbreviations and conventions agents need
-- ---------------------------------------------------------------------------

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'ORIG_', 'Origination — value at the time the loan was originated', 'ORIG_UPB, ORIG_LTV, ORIG_CLTV, ORIG_DTI', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'UPB', 'Unpaid Principal Balance — the outstanding loan amount', 'ORIG_UPB, CURRENT_ACTUAL_UPB, ZERO_BALANCE_REMOVAL_UPB', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'LTV', 'Loan-to-Value ratio — loan amount divided by property value (US term). Australian equivalent: LVR (Loan-to-Value Ratio)', 'ORIG_LTV, ESTIMATED_LOAN_TO_VALUE', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'CLTV', 'Combined Loan-to-Value — all liens divided by property value; CLTV >= LTV', 'ORIG_CLTV', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'DTI', 'Debt-to-Income ratio — monthly debt divided by monthly gross income', 'ORIG_DTI', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'MI', 'Mortgage Insurance — insurance protecting the lender against borrower default; required when LTV > 80%', 'MI_PERCENTAGE, MI_RECOVERIES', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'FRM', 'Fixed Rate Mortgage — interest rate fixed for the life of the loan', 'AMORTIZATION_TYPE = FRM', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'ARM', 'Adjustable Rate Mortgage — interest rate resets periodically', 'AMORTIZATION_TYPE = ARM', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'STG_', 'Staging table prefix — indicates raw source data with no transformations applied', 'STG_Freddie_Origination, STG_Borrower_Profile', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('CONVENTION', 'YYYYMM date format', 'Date columns in the Freddie Mac files are stored as 6-character YYYYMM strings, not DATE type', 'MONTHLY_REPORTING_PERIOD = ''202503'', FIRST_PAYMENT_DATE = ''202503''', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('CONVENTION', 'FICO scale vs Equifax scale',
 'Two credit scoring scales exist in this product. FICO (300-850) in STG_Freddie_Origination.CREDIT_SCORE. Equifax (0-1200) in STG_Credit_Bureau_Feed.CRED_SCORE_CURR. These are NOT directly comparable — always check the source table before joining or comparing credit scores.',
 'CREDIT_SCORE=756 (FICO) is NOT the same risk as CRED_SCORE_CURR=756 (Equifax)', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('CONVENTION', 'Currency convention',
 'Freddie Mac origination and performance data uses USD. Synthetic borrower profile and property valuation data uses AUD. Do not compare or aggregate USD and AUD amounts without currency conversion.',
 'ORIG_UPB is USD; ORIG_VALUATION_AMOUNT is AUD', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'AML', 'Anti-Money Laundering — regulatory framework requiring banks to detect and report suspicious transactions', 'AML_RISK_RATING, AML/CTF Act 2006', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'KYC', 'Know Your Customer — identity verification process required before onboarding a customer', 'KYC_STATUS, KYC_VERIFICATION_DATE', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'REO', 'Real Estate Owned — property acquired by a lender through foreclosure', 'ZERO_BALANCE_CODE=09 (REO Disposition), CURRENT_LOAN_DELINQUENCY_STATUS=RA (REO Acquisition)', 1);

-- =============================================================================
-- TABLE RELATIONSHIP — missing Customer_H → Customer_Keymap relationship
-- This omission caused Customer_H to appear as an isolated entity in the
-- table_relationship completeness check. Fixed per AI-Native standard v2.6.
-- =============================================================================

INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality,
 is_mandatory, is_active, relationship_desc)
VALUES
('MortgagePlatform_Domain', 'Customer_H', 'customer_key',
 'MortgagePlatform_Domain', 'Customer_Keymap', 'customer_key',
 'FOREIGN_KEY', 'INNER', 'MANY_TO_ONE',
 1, 1, 'Customer history rows to stable customer surrogate key - PI join co-locates all versions on same AMP');

-- =============================================================================
-- TABLE RELATIONSHIP — Staging to Domain cross-module semantic relationships
-- Zero cross-module relationships existed prior to this change. These five
-- SEMANTIC relationships enable agents to trace lineage from Domain entities
-- back to their source staging rows. relationship_type = 'SEMANTIC' (not
-- FOREIGN_KEY) because there is no physical FK constraint across databases;
-- the join is via shared natural keys.
-- =============================================================================

INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality,
 is_mandatory, is_active, relationship_desc)
VALUES
('MortgagePlatform_Staging', 'STG_Freddie_Origination', 'LOAN_SEQUENCE_NUMBER',
 'MortgagePlatform_Domain', 'LoanApplication_H', 'loan_application_id',
 'SEMANTIC', 'LEFT', 'ONE_TO_ONE',
 0, 1, 'Origination staging row is the source for loan application domain entity - join on natural key LOAN_SEQUENCE_NUMBER');

INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality,
 is_mandatory, is_active, relationship_desc)
VALUES
('MortgagePlatform_Staging', 'STG_Freddie_Origination', 'LOAN_SEQUENCE_NUMBER',
 'MortgagePlatform_Domain', 'Loan_H', 'loan_id',
 'SEMANTIC', 'LEFT', 'ONE_TO_ONE',
 0, 1, 'Origination staging row is the source for loan facility domain entity - join on natural key LOAN_SEQUENCE_NUMBER');

INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality,
 is_mandatory, is_active, relationship_desc)
VALUES
('MortgagePlatform_Staging', 'STG_Freddie_Performance', 'LOAN_SEQUENCE_NUMBER',
 'MortgagePlatform_Domain', 'LoanPerformance_H', 'loan_key',
 'SEMANTIC', 'LEFT', 'ONE_TO_MANY',
 0, 1, 'Performance staging rows are the source for monthly loan performance snapshots - join staging via Loan_Keymap to resolve loan_key');

INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality,
 is_mandatory, is_active, relationship_desc)
VALUES
('MortgagePlatform_Staging', 'STG_Borrower_Profile', 'CUSTOMER_ID',
 'MortgagePlatform_Domain', 'Customer_H', 'customer_id',
 'SEMANTIC', 'LEFT', 'ONE_TO_ONE',
 0, 1, 'Borrower profile staging row is the source for customer domain entity - join on natural key CUSTOMER_ID');

INSERT INTO MortgagePlatform_Semantic.table_relationship
(from_database, from_table, from_column,
 to_database, to_table, to_column,
 relationship_type, join_type, cardinality,
 is_mandatory, is_active, relationship_desc)
VALUES
('MortgagePlatform_Staging', 'STG_Property_Valuation', 'PROPERTY_ID',
 'MortgagePlatform_Domain', 'Property_H', 'property_id',
 'SEMANTIC', 'LEFT', 'ONE_TO_ONE',
 0, 1, 'Property valuation staging row is the source for property domain entity - join on natural key PROPERTY_ID');
