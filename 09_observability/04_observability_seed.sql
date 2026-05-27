-- =============================================================================
-- 04_observability_seed.sql
-- MortgagePlatform_Observability - Lineage Seed Data
--
-- Run after: 03_observability_documentation.sql
-- Declares all 8 structural data flows in data_lineage.
-- These are definitional rows (the blueprint) - one row per source->job->target.
-- Execution history will be added to lineage_run when ETL pipelines run.
--
-- Flow inventory:
--   1. STG_Freddie_Origination  -> load_loan_application -> LoanApplication_H
--   2. STG_Freddie_Origination  -> load_loan             -> Loan_H
--   3. STG_Freddie_Performance  -> load_loan_performance -> LoanPerformance_H
--   4. STG_Borrower_Profile     -> load_customer         -> Customer_H
--   5. STG_Property_Valuation   -> load_property         -> Property_H
--   6. LoanPerformance_H        -> derive_payment        -> Payment_H
--   7. LoanPerformance_H        -> derive_loan_statement -> LoanStatement_H
--   8. LoanPerformance_H        -> derive_loan_events    -> LoanEvent_H
-- =============================================================================

INSERT INTO MortgagePlatform_Observability.data_lineage
(source_database, source_table, source_system,
 target_database, target_table,
 job_name, transformation_type, transformation_logic,
 is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Freddie_Origination', 'Freddie Mac',
 'MortgagePlatform_Domain', 'LoanApplication_H',
 'load_loan_application', 'ETL',
 'Transforms Freddie Mac origination file into BIAN Mortgage Loan Application entity. Maps LOAN_SEQUENCE_NUMBER as natural key, resolves LoanApplication_Keymap surrogate, applies LoanPurpose_R, OriginationChannel_R, OccupancyStatus_R FK decodes.',
 1);

INSERT INTO MortgagePlatform_Observability.data_lineage
(source_database, source_table, source_system,
 target_database, target_table,
 job_name, transformation_type, transformation_logic,
 is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Freddie_Origination', 'Freddie Mac',
 'MortgagePlatform_Domain', 'Loan_H',
 'load_loan', 'ETL',
 'Transforms Freddie Mac origination file into BIAN Mortgage Loan entity. Resolves Loan_Keymap and LoanApplication_Keymap surrogates. Applies AmortizationType_R and MortgageProduct_R FK decodes. flood_risk_zone VARCHAR(15) corrects source truncation of Overland Flow value (DD-DOMAIN-005).',
 1);

INSERT INTO MortgagePlatform_Observability.data_lineage
(source_database, source_table, source_system,
 target_database, target_table,
 job_name, transformation_type, transformation_logic,
 is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Freddie_Performance', 'Freddie Mac',
 'MortgagePlatform_Domain', 'LoanPerformance_H',
 'load_loan_performance', 'ETL',
 'Transforms Freddie Mac monthly performance file into BIAN Mortgage Loan entity monthly snapshot. One row per loan per reporting month. Resolves Loan_Keymap surrogate via LOAN_SEQUENCE_NUMBER natural key join.',
 1);

INSERT INTO MortgagePlatform_Observability.data_lineage
(source_database, source_table, source_system,
 target_database, target_table,
 job_name, transformation_type, transformation_logic,
 is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Borrower_Profile', 'CRM',
 'MortgagePlatform_Domain', 'Customer_H',
 'load_customer', 'ETL',
 'Transforms synthetic CRM borrower profile into BIAN Party entity cluster. Creates Customer_Keymap surrogate on first encounter. Populates Customer_H plus child entities: CustomerContact_H, CustomerAddress_H, CustomerFinancial_H, CustomerSegment_H, CustomerCompliance_H, CustomerInsight_H.',
 1);

INSERT INTO MortgagePlatform_Observability.data_lineage
(source_database, source_table, source_system,
 target_database, target_table,
 job_name, transformation_type, transformation_logic,
 is_active)
VALUES
('MortgagePlatform_Staging', 'STG_Property_Valuation', 'Collateral Management System',
 'MortgagePlatform_Domain', 'Property_H',
 'load_property', 'ETL',
 'Transforms synthetic property valuation file into BIAN Collateral Asset entity cluster. Creates Property_Keymap surrogate on first encounter. Populates Property_H plus child entities: PropertyAddress_H, PropertyValuation_H, PropertyRisk_H, PropertyTitle_H.',
 1);

INSERT INTO MortgagePlatform_Observability.data_lineage
(source_database, source_table, source_system,
 target_database, target_table,
 job_name, transformation_type, transformation_logic,
 is_active)
VALUES
('MortgagePlatform_Domain', 'LoanPerformance_H', NULL,
 'MortgagePlatform_Domain', 'Payment_H',
 'derive_payment', 'FEATURE_ENG',
 'Derives monthly payment events from LoanPerformance_H UPB movement. principal_component = opening_upb - closing_upb. Payment types assigned: SCHEDULED (normal amortisation), DRAWDOWN (UPB increase), PREPAYMENT (UPB reduction exceeding scheduled). Append-only; one row per loan per reporting month.',
 1);

INSERT INTO MortgagePlatform_Observability.data_lineage
(source_database, source_table, source_system,
 target_database, target_table,
 job_name, transformation_type, transformation_logic,
 is_active)
VALUES
('MortgagePlatform_Domain', 'LoanPerformance_H', NULL,
 'MortgagePlatform_Domain', 'LoanStatement_H',
 'derive_loan_statement', 'FEATURE_ENG',
 'Derives monthly loan statement records from LoanPerformance_H and Payment_H. Combines opening/closing UPB, payment amounts, interest accrual, and delinquency status into customer-facing statement view. Append-only; one row per loan per statement period.',
 1);

INSERT INTO MortgagePlatform_Observability.data_lineage
(source_database, source_table, source_system,
 target_database, target_table,
 job_name, transformation_type, transformation_logic,
 is_active)
VALUES
('MortgagePlatform_Domain', 'LoanPerformance_H', NULL,
 'MortgagePlatform_Domain', 'LoanEvent_H',
 'derive_loan_events', 'FEATURE_ENG',
 'Derives discrete lifecycle events from month-on-month changes in LoanPerformance_H. Event types: DELINQUENCY_ESCALATION (DPD bucket increase), DELINQUENCY_CURE (DPD bucket decrease), ZERO_BALANCE (loan closed), MODIFICATION_STARTED (MODIFICATION_FLAG = Y), DISASTER_RELIEF_APPLIED (relief flag set), INTEREST_RATE_CHANGE (rate delta detected).',
 1);
