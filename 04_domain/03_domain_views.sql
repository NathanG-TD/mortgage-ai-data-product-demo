-- =============================================================================
-- 03_domain_views.sql
-- MortgagePlatform_Domain — Standard _Current views for child entities
--
-- Primary entity views (Loan_Current, LoanApplication_Current,
-- LoanPerformance_Latest, Customer_Current, Customer_Enriched,
-- Property_Current, Property_Enriched, LoanStatement_Latest,
-- PropertyValuation_Latest) are defined in 01_domain_ddl.sql.
--
-- This file adds _Current views for all Type 2 SCD child entities.
-- These views are required by the AI-Native Data Product design standard
-- checklist and enable agents to query current state without writing
-- is_current / is_deleted filter predicates directly.
-- =============================================================================

-- BIAN: Party Reference Data Management — child entity current views

REPLACE VIEW MortgagePlatform_Domain.CustomerContact_Current AS
SELECT * FROM MortgagePlatform_Domain.CustomerContact_H
WHERE is_current = 1 AND is_deleted = 0;
COMMENT ON VIEW MortgagePlatform_Domain.CustomerContact_Current IS
'Current active customer contact details - filters CustomerContact_H to is_current=1 and is_deleted=0.';

REPLACE VIEW MortgagePlatform_Domain.CustomerAddress_Current AS
SELECT * FROM MortgagePlatform_Domain.CustomerAddress_H
WHERE is_current = 1 AND is_deleted = 0;
COMMENT ON VIEW MortgagePlatform_Domain.CustomerAddress_Current IS
'Current active customer residential addresses - filters CustomerAddress_H to is_current=1 and is_deleted=0.';

-- BIAN: Customer Profile — child entity current views

REPLACE VIEW MortgagePlatform_Domain.CustomerSegment_Current AS
SELECT * FROM MortgagePlatform_Domain.CustomerSegment_H
WHERE is_current = 1 AND is_deleted = 0;
COMMENT ON VIEW MortgagePlatform_Domain.CustomerSegment_Current IS
'Current active customer CRM segment and RM assignments - filters CustomerSegment_H to is_current=1 and is_deleted=0.';

REPLACE VIEW MortgagePlatform_Domain.CustomerFinancial_Current AS
SELECT * FROM MortgagePlatform_Domain.CustomerFinancial_H
WHERE is_current = 1 AND is_deleted = 0;
COMMENT ON VIEW MortgagePlatform_Domain.CustomerFinancial_Current IS
'Current active customer financial profile (income, employment) - filters CustomerFinancial_H to is_current=1 and is_deleted=0.';

REPLACE VIEW MortgagePlatform_Domain.CustomerInsight_Current AS
SELECT * FROM MortgagePlatform_Domain.CustomerInsight_H
WHERE is_current = 1 AND is_deleted = 0;
COMMENT ON VIEW MortgagePlatform_Domain.CustomerInsight_Current IS
'Current active customer analytically-derived scores (churn risk, NPS) - filters CustomerInsight_H to is_current=1 and is_deleted=0.';

-- BIAN: Customer Credit Rating — child entity current view

REPLACE VIEW MortgagePlatform_Domain.CustomerCompliance_Current AS
SELECT * FROM MortgagePlatform_Domain.CustomerCompliance_H
WHERE is_current = 1 AND is_deleted = 0;
COMMENT ON VIEW MortgagePlatform_Domain.CustomerCompliance_Current IS
'Current active customer KYC and AML compliance status - filters CustomerCompliance_H to is_current=1 and is_deleted=0. Restricted view: contains regulated attributes under AML/CTF Act.';

-- BIAN: Collateral Asset Administration — child entity current views

REPLACE VIEW MortgagePlatform_Domain.PropertyAddress_Current AS
SELECT * FROM MortgagePlatform_Domain.PropertyAddress_H
WHERE is_current = 1 AND is_deleted = 0;
COMMENT ON VIEW MortgagePlatform_Domain.PropertyAddress_Current IS
'Current active security property addresses - filters PropertyAddress_H to is_current=1 and is_deleted=0.';

REPLACE VIEW MortgagePlatform_Domain.PropertyRisk_Current AS
SELECT * FROM MortgagePlatform_Domain.PropertyRisk_H
WHERE is_current = 1 AND is_deleted = 0;
COMMENT ON VIEW MortgagePlatform_Domain.PropertyRisk_Current IS
'Current active property natural hazard risk assessments (flood, fire, environmental) - filters PropertyRisk_H to is_current=1 and is_deleted=0.';

REPLACE VIEW MortgagePlatform_Domain.PropertyTitle_Current AS
SELECT * FROM MortgagePlatform_Domain.PropertyTitle_H
WHERE is_current = 1 AND is_deleted = 0;
COMMENT ON VIEW MortgagePlatform_Domain.PropertyTitle_Current IS
'Current active property legal title details (title reference, lot, plan, strata) - filters PropertyTitle_H to is_current=1 and is_deleted=0.';
