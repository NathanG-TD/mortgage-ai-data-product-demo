-- =============================================================================
-- 02_semantic_registration.sql
-- MortgagePlatform_Semantic - data_product_map, entity_metadata,
--                              column_metadata, table_relationship,
--                              naming_standard registrations
--
-- This file is the agent's primary discovery resource. Every staging table,
-- key column, and join path is registered here so agents can autonomously
-- map, query, and trace lineage without human guidance.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- data_product_map - one row per deployed module (agent bootstrap)
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
 'Queryable metadata layer for autonomous agent discovery. Contains entity catalog, column metadata, join relationships, and naming standards. This module is self-describing - querying it reveals the full structure of all other modules.',
 'data_product_map, entity_metadata, column_metadata, table_relationship, naming_standard',
 'MortgagePlatform_Semantic.v_entity_catalog',
 1);

INSERT INTO MortgagePlatform_Semantic.data_product_map
(module_name, database_name, module_purpose, primary_tables, agent_entry_view, is_active)
VALUES
('STAGING', 'MortgagePlatform_Staging',
 'Raw source data staging layer. Four source systems: Loan Origination (Freddie Mac), Loan Servicing (Freddie Mac), CRM Customer Master (synthetic), Collateral Management (synthetic). Columns mirror source file layouts exactly - no transformations applied. COMMENT ON metadata on each column provides the semantic bridge for mapping agents.',
 'STG_Freddie_Origination, STG_Freddie_Performance, STG_Borrower_Profile, STG_Property_Valuation',
 NULL,
 1);

-- ---------------------------------------------------------------------------
-- entity_metadata - all staging tables
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
 'Agent session state - tracks active and historical sessions for continuity across interactions',
 'MEMORY', 0, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column,
 entity_description, entity_category, record_count_approx, is_active)
VALUES
('MEMORY', 'BusinessGlossary', 'MortgagePlatform_Memory',
 'Business_Glossary', NULL,
 'term', 'glossary_key',
 'Mortgage domain business term definitions - reduces tacit knowledge dependency; covers LTV, CLTV, DTI, Zero Balance Codes, AML, and credit score scale differences',
 'MEMORY', 0, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name,
 natural_key_column, surrogate_key_column,
 entity_description, entity_category, record_count_approx, is_active)
VALUES
('MEMORY', 'QueryCookbook', 'MortgagePlatform_Memory',
 'Query_Cookbook', NULL,
 'recipe_id', 'recipe_key',
 'Proven SQL query patterns for mortgage data - churn detection, cross-source joins, delinquency analysis',
 'MEMORY', 0, 1);

-- ---------------------------------------------------------------------------
-- column_metadata - key columns per staging table
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
 'Original Unpaid Principal Balance - the face amount of the loan at origination in USD. Primary loan size metric.',
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
 'Borrower FICO credit score at origination. Range 300-850. IMPORTANT: This uses the FICO scale - NOT the Equifax 0-1200 scale used in STG_Credit_Bureau_Feed.CRED_SCORE_CURR. Do not merge these columns in the domain model without scale conversion.',
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
 'Bank-assigned master customer identifier. Format: CUS-XXXXXXXX. Enterprise customer key - all product systems reference this. Join to STG_Property_Valuation.CUSTOMER_ID.',
 'VARCHAR(20)', 0, 0, 1,
 'CUS-00000001|CUS-00000002',
 'Must not be null. Format: CUS- prefix followed by 8 digits.', 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Borrower_Profile',
 'FIRST_NAME',
 'Customer first (given) name. PII - subject to privacy controls.',
 'VARCHAR(50)', 1, 0, 1, NULL, NULL, 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Borrower_Profile',
 'LAST_NAME',
 'Customer last (family) name. PII - subject to privacy controls.',
 'VARCHAR(50)', 1, 0, 1, NULL, NULL, 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Borrower_Profile',
 'DATE_OF_BIRTH',
 'Customer date of birth. PII - used for identity verification and age-based eligibility rules.',
 'DATE', 1, 0, 1, NULL, NULL, 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Borrower_Profile',
 'AML_RISK_RATING',
 'Anti-Money Laundering risk rating. L=Low, M=Medium, H=High. REGULATED ATTRIBUTE - access requires elevated privileges and audit trail. Subject to AML/CTF Act 2006 (Australia).',
 'CHAR(1)', 0, 1, 1,
 'L|M|H',
 'Values: L, M, H only. H-rated records require mandatory review and audit logging.', 1);

INSERT INTO MortgagePlatform_Semantic.column_metadata
(database_name, table_name, column_name, business_description, data_type,
 is_pii, is_sensitive, is_required, sample_values, validation_rule, is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Borrower_Profile',
 'CHURN_RISK_SCORE',
 'Model-generated churn propensity score. Range 0.00-1.00. Higher = higher churn probability. Analytically-derived - loaded back from analytics platform, not a raw CRM field.',
 'DECIMAL(5,2)', 0, 0, 0,
 '0.12|0.35|0.67|0.89',
 'Range: 0.00-1.00. High risk band: > 0.60. Derived field - do not overwrite with source system data.', 1);

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
-- table_relationship - all join paths between staging tables
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
-- naming_standard - abbreviations and conventions agents need
-- ---------------------------------------------------------------------------

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'ORIG_', 'Origination - value at the time the loan was originated', 'ORIG_UPB, ORIG_LTV, ORIG_CLTV, ORIG_DTI', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'UPB', 'Unpaid Principal Balance - the outstanding loan amount', 'ORIG_UPB, CURRENT_ACTUAL_UPB, ZERO_BALANCE_REMOVAL_UPB', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'LTV', 'Loan-to-Value ratio - loan amount divided by property value (US term). Australian equivalent: LVR (Loan-to-Value Ratio)', 'ORIG_LTV, ESTIMATED_LOAN_TO_VALUE', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'CLTV', 'Combined Loan-to-Value - all liens divided by property value; CLTV >= LTV', 'ORIG_CLTV', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'DTI', 'Debt-to-Income ratio - monthly debt divided by monthly gross income', 'ORIG_DTI', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'MI', 'Mortgage Insurance - insurance protecting the lender against borrower default; required when LTV > 80%', 'MI_PERCENTAGE, MI_RECOVERIES', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'FRM', 'Fixed Rate Mortgage - interest rate fixed for the life of the loan', 'AMORTIZATION_TYPE = FRM', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'ARM', 'Adjustable Rate Mortgage - interest rate resets periodically', 'AMORTIZATION_TYPE = ARM', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'STG_', 'Staging table prefix - indicates raw source data with no transformations applied', 'STG_Freddie_Origination, STG_Borrower_Profile', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('CONVENTION', 'YYYYMM date format', 'Date columns in the Freddie Mac files are stored as 6-character YYYYMM strings, not DATE type', 'MONTHLY_REPORTING_PERIOD = ''202503'', FIRST_PAYMENT_DATE = ''202503''', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('CONVENTION', 'FICO scale vs Equifax scale',
 'Two credit scoring scales exist in this product. FICO (300-850) in STG_Freddie_Origination.CREDIT_SCORE. Equifax (0-1200) in STG_Credit_Bureau_Feed.CRED_SCORE_CURR. These are NOT directly comparable - always check the source table before joining or comparing credit scores.',
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
('ABBREVIATION', 'AML', 'Anti-Money Laundering - regulatory framework requiring banks to detect and report suspicious transactions', 'AML_RISK_RATING, AML/CTF Act 2006', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'KYC', 'Know Your Customer - identity verification process required before onboarding a customer', 'KYC_STATUS, KYC_VERIFICATION_DATE', 1);

INSERT INTO MortgagePlatform_Semantic.naming_standard
(standard_type, pattern, meaning, example, is_active)
VALUES
('ABBREVIATION', 'REO', 'Real Estate Owned - property acquired by a lender through foreclosure', 'ZERO_BALANCE_CODE=09 (REO Disposition), CURRENT_LOAN_DELINQUENCY_STATUS=RA (REO Acquisition)', 1);

-- =============================================================================
-- TABLE RELATIONSHIP - missing Customer_H → Customer_Keymap relationship
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
-- TABLE RELATIONSHIP - Staging to Domain cross-module semantic relationships
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

-- =============================================================================
-- ENTITY METADATA - child entities, keymaps, and reference tables
-- Added to align with AI-Native Data Product Design Standard v2.6
-- which requires entity_metadata coverage for all tables in all modules.
-- =============================================================================

-- Keymaps
INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'CustomerKeymap', 'MortgagePlatform_Domain', 'Customer_Keymap', NULL, 'customer_id', 'customer_key', 'Surrogate key allocation table for Customer entity. One row per unique customer. Generates the stable customer_key referenced as FK by Customer_H and all child customer entities, Loan_H, LoanApplication_H, Property_H, and LoanStatement_H.', 'CUSTOMER', 37500, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'LoanApplicationKeymap', 'MortgagePlatform_Domain', 'LoanApplication_Keymap', NULL, 'loan_application_id', 'loan_application_key', 'Surrogate key allocation table for LoanApplication entity. One row per unique loan application. Natural key is loan_application_id (Freddie Mac LOAN_SEQUENCE_NUMBER). Generates the stable loan_application_key referenced by LoanApplication_H and Loan_H.', 'LOAN', 37500, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'LoanKeymap', 'MortgagePlatform_Domain', 'Loan_Keymap', NULL, 'loan_id', 'loan_key', 'Surrogate key allocation table for Loan entity. One row per unique funded loan. Natural key is loan_id (Freddie Mac LOAN_SEQUENCE_NUMBER). Generates the stable loan_key referenced by Loan_H, LoanPerformance_H, LoanEvent_H, LoanModification_H, Payment_H, LoanStatement_H, and Property_H.', 'LOAN', 37500, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata
(module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'PropertyKeymap', 'MortgagePlatform_Domain', 'Property_Keymap', NULL, 'property_id', 'property_key', 'Surrogate key allocation table for Property entity. One row per unique security property. Natural key is property_id from the Collateral Management System. Generates the stable property_key referenced by Property_H, PropertyAddress_H, PropertyValuation_H, PropertyRisk_H, PropertyTitle_H, and Loan_H.', 'PROPERTY', 37500, 1);

-- Reference tables
INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'LoanPurpose', 'MortgagePlatform_Domain', 'LoanPurpose_R', NULL, 'loan_purpose_cd', NULL, 'Reference: loan purpose codes. 4 rows: P=Purchase, C=Cash-out Refinance, N=No Cash-out Refinance, U=Unknown. Source: Freddie Mac LOAN_PURPOSE. FK target for LoanApplication_H.loan_purpose_cd.', 'REFERENCE', 4, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'OriginationChannel', 'MortgagePlatform_Domain', 'OriginationChannel_R', NULL, 'channel_cd', NULL, 'Reference: origination channel codes. 4 rows: R=Retail, B=Broker, C=Correspondent, T=TPO Not Specified. Source: Freddie Mac CHANNEL. FK target for LoanApplication_H.channel_cd.', 'REFERENCE', 4, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'AmortizationType', 'MortgagePlatform_Domain', 'AmortizationType_R', NULL, 'amortization_type_cd', NULL, 'Reference: amortisation type codes. 2 rows: FRM=Fixed Rate Mortgage, ARM=Adjustable Rate Mortgage. Source: Freddie Mac AMORTIZATION_TYPE. FK target for Loan_H.amortization_type_cd and MortgageProduct_R.amortization_type_cd.', 'REFERENCE', 2, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'OccupancyStatus', 'MortgagePlatform_Domain', 'OccupancyStatus_R', NULL, 'occupancy_status_cd', NULL, 'Reference: property occupancy status at origination. 3 rows: P=Primary Residence, S=Second Home, I=Investment Property. Source: Freddie Mac OCCUPANCY_STATUS. FK target for LoanApplication_H.occupancy_status_cd.', 'REFERENCE', 3, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'DelinquencyStatus', 'MortgagePlatform_Domain', 'DelinquencyStatus_R', NULL, 'delinquency_status_cd', NULL, 'Reference: delinquency status codes. 8 rows: 0=Current, 1-6=months past due, RA=REO Acquisition. Source: Freddie Mac CURRENT_LOAN_DELINQUENCY_STATUS. is_performing flag for portfolio risk reports. FK target for LoanPerformance_H and Payment_H.', 'REFERENCE', 8, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'ZeroBalanceCode', 'MortgagePlatform_Domain', 'ZeroBalanceCode_R', NULL, 'zero_balance_code_cd', NULL, 'Reference: zero balance codes from Freddie Mac performance file. 7 rows indicating why a loan reached zero UPB. is_voluntary and is_distressed flags identify loan exit type. FK target for Loan_H and LoanPerformance_H.', 'REFERENCE', 7, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'MortgageProduct', 'MortgagePlatform_Domain', 'MortgageProduct_R', NULL, 'product_cd', NULL, 'Reference: BIAN Product Directory - mortgage product catalogue. 6 rows covering fixed-rate products at standard terms (15yr, 20yr, 25yr, 30yr), one catch-all for non-standard terms, and one ARM product. FK target for Loan_H.', 'REFERENCE', 6, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'CustomerSegmentRef', 'MortgagePlatform_Domain', 'CustomerSegment_R', NULL, 'segment_cd', NULL, 'Reference: CRM customer segment classifications. 5 rows: Mass Market, Emerging Affluent, Affluent, Private Banking, Business Owner. wealth_tier_order enables ascending wealth sort. FK target for CustomerSegment_H.segment_cd.', 'REFERENCE', 5, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'EmploymentStatus', 'MortgagePlatform_Domain', 'EmploymentStatus_R', NULL, 'employment_status_cd', NULL, 'Reference: borrower employment status codes. 6 rows: Full-time, Part-time, Contractor, Self-employed, Retired, Unemployed. is_income_stable flag for serviceability assessment. FK target for CustomerFinancial_H.employment_status_cd.', 'REFERENCE', 6, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'KYCStatus', 'MortgagePlatform_Domain', 'KYCStatus_R', NULL, 'kyc_status_cd', NULL, 'Reference: Know Your Customer verification status codes. 4 rows: Verified, Pending, Expired, Failed. is_compliant and requires_action flags drive compliance workflows under AML/CTF Act. FK target for CustomerCompliance_H.kyc_status_cd.', 'REFERENCE', 4, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'AMLRiskRating', 'MortgagePlatform_Domain', 'AMLRiskRating_R', NULL, 'aml_risk_rating_cd', NULL, 'Reference: Anti-Money Laundering risk rating codes. 3 rows: L=Low, M=Medium, H=High. enhanced_due_diligence flag for EDD requirement under AML/CTF Act. FK target for CustomerCompliance_H.aml_risk_rating_cd.', 'REFERENCE', 3, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'PropertyType', 'MortgagePlatform_Domain', 'PropertyType_R', NULL, 'property_type_cd', NULL, 'Reference: security property type codes. 5 rows: SF=Single Family House, TH=Townhouse, AP=Apartment/Unit, RU=Rural, VA=Vacant Land. is_strata_eligible flag. FK target for Property_H.property_type_cd.', 'REFERENCE', 5, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'ValuationMethod', 'MortgagePlatform_Domain', 'ValuationMethod_R', NULL, 'valuation_method_cd', NULL, 'Reference: property valuation method codes. 4 rows: Full, Kerbside, Desktop, AVM. is_physical_inspection and apra_acceptable flags for APRA APS112 LVR policy compliance. FK target for PropertyValuation_H.valuation_method_cd.', 'REFERENCE', 4, 1);

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'PropertyStatus', 'MortgagePlatform_Domain', 'PropertyStatus_R', NULL, 'property_status_cd', NULL, 'Reference: collateral property status codes. 4 rows: Active, Released, Substituted, Sold. is_active_security flag indicates whether property is still encumbered. FK target for Property_H.property_status_cd.', 'REFERENCE', 4, 1);

-- Customer child entities + relationships
INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'CustomerContact', 'MortgagePlatform_Domain', 'CustomerContact_H', NULL, 'customer_key', 'customer_contact_key', 'BIAN: Party Reference Data Management - customer contact details. Type 2 SCD child of Customer_H. Captures email, mobile, home phone, and preferred contact channel. PI on customer_key co-locates with parent.', 'CUSTOMER', 37500, 1);
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'CustomerContact_H', 'customer_key', 'MortgagePlatform_Domain', 'Customer_Keymap', 'customer_key', 'FOREIGN_KEY', 'INNER', 'MANY_TO_ONE', 1, 1, 'Customer contact records to stable customer surrogate - PI join co-locates with parent Customer_H');

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'CustomerAddress', 'MortgagePlatform_Domain', 'CustomerAddress_H', NULL, 'customer_key', 'customer_address_key', 'BIAN: Party Reference Data Management - customer residential address. Type 2 SCD child of Customer_H. SCD versioning tracks address changes over time for mail communications and fraud detection.', 'CUSTOMER', 37500, 1);
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'CustomerAddress_H', 'customer_key', 'MortgagePlatform_Domain', 'Customer_Keymap', 'customer_key', 'FOREIGN_KEY', 'INNER', 'MANY_TO_ONE', 1, 1, 'Customer address records to stable customer surrogate - PI join co-locates with parent Customer_H');

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'CustomerSegment', 'MortgagePlatform_Domain', 'CustomerSegment_H', NULL, 'customer_key', 'customer_segment_key', 'BIAN: Customer Profile - CRM segment, branch code, relationship manager assignment, and marketing opt-in. Type 2 SCD child of Customer_H. Captures segment transitions over time.', 'CUSTOMER', 37500, 1);
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'CustomerSegment_H', 'customer_key', 'MortgagePlatform_Domain', 'Customer_Keymap', 'customer_key', 'FOREIGN_KEY', 'INNER', 'MANY_TO_ONE', 1, 1, 'Customer segment records to stable customer surrogate - PI join co-locates with parent Customer_H');

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'CustomerFinancial', 'MortgagePlatform_Domain', 'CustomerFinancial_H', NULL, 'customer_key', 'customer_financial_key', 'BIAN: Customer Profile - income, employment status, employer name, and years with employer. Type 2 SCD child of Customer_H. Annual income range 30K-786K AUD in dataset.', 'CUSTOMER', 37500, 1);
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'CustomerFinancial_H', 'customer_key', 'MortgagePlatform_Domain', 'Customer_Keymap', 'customer_key', 'FOREIGN_KEY', 'INNER', 'MANY_TO_ONE', 1, 1, 'Customer financial profile records to stable customer surrogate - PI join co-locates with parent Customer_H');

-- Property child entities + relationships
INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'PropertyAddress', 'MortgagePlatform_Domain', 'PropertyAddress_H', NULL, 'property_key', 'property_address_key', 'BIAN: Collateral Asset Administration - security property physical address. Type 2 SCD child of Property_H. SCD versioning supports address corrections and subdivision events.', 'PROPERTY', 37500, 1);
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'PropertyAddress_H', 'property_key', 'MortgagePlatform_Domain', 'Property_Keymap', 'property_key', 'FOREIGN_KEY', 'INNER', 'MANY_TO_ONE', 1, 1, 'Property address records to stable property surrogate - PI join co-locates with parent Property_H');

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'PropertyValuation', 'MortgagePlatform_Domain', 'PropertyValuation_H', 'PropertyValuation_Latest', 'property_key', 'property_valuation_key', 'BIAN: Collateral Asset Administration - append-only valuation event log. Two types: ORIGINAL and CURRENT_AVM. Valuation range 33K-10.9M AUD. Use PropertyValuation_Latest view for current market value.', 'PROPERTY', 75000, 1);
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'PropertyValuation_H', 'property_key', 'MortgagePlatform_Domain', 'Property_Keymap', 'property_key', 'FOREIGN_KEY', 'INNER', 'MANY_TO_ONE', 1, 1, 'Property valuation events to stable property surrogate - PI co-locates all valuations per property on same AMP');

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'PropertyRisk', 'MortgagePlatform_Domain', 'PropertyRisk_H', NULL, 'property_key', 'property_risk_key', 'BIAN: Collateral Asset Administration - natural hazard and environmental risk attributes. Type 2 SCD child of Property_H. Critical for APRA risk-weighted asset calculation and LMI pricing.', 'PROPERTY', 37500, 1);
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'PropertyRisk_H', 'property_key', 'MortgagePlatform_Domain', 'Property_Keymap', 'property_key', 'FOREIGN_KEY', 'INNER', 'MANY_TO_ONE', 1, 1, 'Property risk assessment records to stable property surrogate - PI join co-locates with parent Property_H');

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'PropertyTitle', 'MortgagePlatform_Domain', 'PropertyTitle_H', NULL, 'property_key', 'property_title_key', 'BIAN: Collateral Asset Administration - legal title details. Type 2 SCD child of Property_H. Captures title reference, lot and plan numbers, strata flag, and heritage listing.', 'PROPERTY', 37500, 1);
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'PropertyTitle_H', 'property_key', 'MortgagePlatform_Domain', 'Property_Keymap', 'property_key', 'FOREIGN_KEY', 'INNER', 'MANY_TO_ONE', 1, 1, 'Property title records to stable property surrogate - PI join co-locates with parent Property_H');

-- Loan child entities + relationships
INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'LoanEvent', 'MortgagePlatform_Domain', 'LoanEvent_H', NULL, 'loan_key', 'event_key', 'Append-only event log for discrete loan lifecycle events derived from LoanPerformance_H. Event types: DELINQUENCY_ESCALATION, DELINQUENCY_CURE, ZERO_BALANCE, MODIFICATION_STARTED, DISASTER_RELIEF_APPLIED, INTEREST_RATE_CHANGE. Immutable once inserted.', 'LOAN', 50000, 1);
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'LoanEvent_H', 'loan_key', 'MortgagePlatform_Domain', 'Loan_Keymap', 'loan_key', 'FOREIGN_KEY', 'INNER', 'MANY_TO_ONE', 1, 1, 'Loan lifecycle events to stable loan surrogate - PI co-locates all events per loan on same AMP');

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'LoanModification', 'MortgagePlatform_Domain', 'LoanModification_H', NULL, 'loan_key', 'modification_key', 'Append-only loan modification event log. One row per modification event. No modifications in current Jan-Sep 2025 dataset; scaffolded for Act 2 bureau feed onboarding scenario.', 'LOAN', 0, 1);
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'LoanModification_H', 'loan_key', 'MortgagePlatform_Domain', 'Loan_Keymap', 'loan_key', 'FOREIGN_KEY', 'INNER', 'MANY_TO_ONE', 1, 1, 'Loan modification events to stable loan surrogate - PI join co-locates with parent Loan_H');

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'Payment', 'MortgagePlatform_Domain', 'Payment_H', NULL, 'loan_key', 'payment_key', 'BIAN: Payment - append-only monthly payment event log. One row per loan per reporting month. Derived from LoanPerformance_H UPB movement. Payment types: SCHEDULED, DRAWDOWN, PREPAYMENT. Immutable once inserted.', 'LOAN', 153382, 1);
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'Payment_H', 'loan_key', 'MortgagePlatform_Domain', 'Loan_Keymap', 'loan_key', 'FOREIGN_KEY', 'INNER', 'MANY_TO_ONE', 1, 1, 'Monthly payment events to stable loan surrogate - PI co-locates all payment periods per loan on same AMP');

INSERT INTO MortgagePlatform_Semantic.entity_metadata (module_name, entity_name, database_name, table_name, view_name, natural_key_column, surrogate_key_column, entity_description, entity_category, record_count_approx, is_active)
VALUES ('DOMAIN', 'LoanStatement', 'MortgagePlatform_Domain', 'LoanStatement_H', 'LoanStatement_Latest', 'loan_key', 'statement_key', 'BIAN: Customer Statement - append-only monthly loan statement record. Derived from LoanPerformance_H and Payment_H. Key regulatory lineage chain: LoanStatement_H -> Payment_H -> LoanPerformance_H -> Loan_H -> LoanApplication_H.', 'LOAN', 153382, 1);
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'LoanStatement_H', 'loan_key', 'MortgagePlatform_Domain', 'Loan_Keymap', 'loan_key', 'FOREIGN_KEY', 'INNER', 'MANY_TO_ONE', 1, 1, 'Monthly loan statements to stable loan surrogate - PI co-locates all statement periods per loan on same AMP');
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'LoanStatement_H', 'customer_key', 'MortgagePlatform_Domain', 'Customer_Keymap', 'customer_key', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Monthly loan statements to the borrower customer - enables statement-to-customer navigation for regulatory lineage queries');

-- =============================================================================
-- TABLE RELATIONSHIP - reference table lookups (17 relationships)
-- These link transactional tables to their reference decode tables.
-- All use LEFT join and is_mandatory=0 since code columns are nullable.
-- Agents use _Enriched views for decoded output; these relationships
-- enable v_relationship_paths multi-hop navigation when needed.
-- =============================================================================

INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'LoanApplication_H', 'loan_purpose_cd', 'MortgagePlatform_Domain', 'LoanPurpose_R', 'loan_purpose_cd', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Loan application to loan purpose decode - P=Purchase, C=Cash-out Refi, N=No Cash-out Refi, U=Unknown');
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'LoanApplication_H', 'channel_cd', 'MortgagePlatform_Domain', 'OriginationChannel_R', 'channel_cd', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Loan application to origination channel decode - R=Retail, B=Broker, C=Correspondent, T=TPO');
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'LoanApplication_H', 'occupancy_status_cd', 'MortgagePlatform_Domain', 'OccupancyStatus_R', 'occupancy_status_cd', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Loan application to occupancy status decode - P=Primary, S=Second Home, I=Investment');
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'Loan_H', 'amortization_type_cd', 'MortgagePlatform_Domain', 'AmortizationType_R', 'amortization_type_cd', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Loan to amortisation type decode - FRM=Fixed Rate Mortgage, ARM=Adjustable Rate Mortgage');
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'Loan_H', 'zero_balance_code_cd', 'MortgagePlatform_Domain', 'ZeroBalanceCode_R', 'zero_balance_code_cd', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Loan to zero balance reason decode - only populated when loan_status=CLOSED');
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'LoanPerformance_H', 'delinquency_status_cd', 'MortgagePlatform_Domain', 'DelinquencyStatus_R', 'delinquency_status_cd', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Monthly performance snapshot to delinquency status decode - 0=Current, 1-6=months past due, RA=REO');
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'LoanPerformance_H', 'zero_balance_code_cd', 'MortgagePlatform_Domain', 'ZeroBalanceCode_R', 'zero_balance_code_cd', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Monthly performance snapshot to zero balance reason decode - populated in period loan reached zero UPB');
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'Payment_H', 'delinquency_status_cd', 'MortgagePlatform_Domain', 'DelinquencyStatus_R', 'delinquency_status_cd', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Payment event to delinquency status decode - links payment behaviour to delinquency classification for AASB9 lineage');
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'CustomerSegment_H', 'segment_cd', 'MortgagePlatform_Domain', 'CustomerSegment_R', 'segment_cd', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Customer segment record to segment definition decode - Mass Market, Affluent, Private Banking etc');
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'CustomerFinancial_H', 'employment_status_cd', 'MortgagePlatform_Domain', 'EmploymentStatus_R', 'employment_status_cd', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Customer financial profile to employment status decode - informs income verification requirements');
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'CustomerCompliance_H', 'kyc_status_cd', 'MortgagePlatform_Domain', 'KYCStatus_R', 'kyc_status_cd', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Customer compliance to KYC status decode - Verified/Pending/Expired/Failed; is_compliant flag drives AML/CTF obligations');
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'CustomerCompliance_H', 'aml_risk_rating_cd', 'MortgagePlatform_Domain', 'AMLRiskRating_R', 'aml_risk_rating_cd', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Customer compliance to AML risk rating decode - L/M/H; H requires Enhanced Due Diligence under AML/CTF Act');
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'Property_H', 'property_type_cd', 'MortgagePlatform_Domain', 'PropertyType_R', 'property_type_cd', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Property to property type decode - SF/TH/AP/RU/VA; is_strata_eligible flag for title and LMI assessment');
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'Property_H', 'property_status_cd', 'MortgagePlatform_Domain', 'PropertyStatus_R', 'property_status_cd', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Property to collateral status decode - Active/Released/Substituted/Sold; is_active_security flag for encumbrance status');
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'PropertyValuation_H', 'valuation_method_cd', 'MortgagePlatform_Domain', 'ValuationMethod_R', 'valuation_method_cd', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Valuation event to valuation method decode - Full/Kerbside/Desktop/AVM; apra_acceptable flag for LVR policy compliance');
INSERT INTO MortgagePlatform_Semantic.table_relationship (from_database, from_table, from_column, to_database, to_table, to_column, relationship_type, join_type, cardinality, is_mandatory, is_active, relationship_desc)
VALUES ('MortgagePlatform_Domain', 'MortgageProduct_R', 'amortization_type_cd', 'MortgagePlatform_Domain', 'AmortizationType_R', 'amortization_type_cd', 'FOREIGN_KEY', 'LEFT', 'MANY_TO_ONE', 0, 1, 'Mortgage product to amortisation type decode - FRM or ARM; defines the repayment structure of the product');
