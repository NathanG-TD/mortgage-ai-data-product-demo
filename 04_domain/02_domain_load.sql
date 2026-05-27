-- =============================================================================
-- 02_domain_load.sql
-- MortgagePlatform_Domain -- Initial data load from staging
--
-- Execution order: run AFTER 01_domain_ddl.sql and 03_domain_views.sql
--
-- Load sequence (dependency order):
--   Section 1 : Keymaps (no dependencies)
--   Section 2 : LoanApplication_H  (needs LoanApplication_Keymap + Customer_Keymap)
--   Section 3 : Loan_H             (needs Loan_Keymap + LoanApplication_Keymap
--                                    + Customer_Keymap + Property_Keymap)
--   Section 4 : Customer_H + 6 child entities
--   Section 5 : Property_H + 4 child entities + PropertyValuation_H
--   Section 6 : LoanPerformance_H  (needs Loan_Keymap)
--   Section 7 : LoanEvent_H        (derived from LoanPerformance_H)
--   Section 8 : Payment_H          (derived from LoanPerformance_H + Loan_H)
--   Section 9 : LoanStatement_H    (derived from Payment_H + Loan_Current)
--
-- Transformation conventions:
--   YYYYMM CHAR(6) to DATE : CAST(SUBSTR(col,1,4)||'-'||SUBSTR(col,5,2)||'-01'
--                                 AS DATE FORMAT 'YYYY-MM-DD')
--   CHAR Y/N to BYTEINT    : CASE WHEN col = 'Y' THEN 1 ELSE 0 END
--   CHAR columns to VARCHAR : TRIM(col)
--   Flood risk expansion   : CASE WHEN TRIM(col) = 'Overland F'
--                                 THEN 'Overland Flow' ELSE TRIM(col) END
-- =============================================================================


-- =============================================================================
-- SECTION 1: KEYMAPS
-- One row per unique natural key. IDENTITY fires here only.
-- Two-step pattern: INSERT to keymap WHERE NOT EXISTS, then JOIN on INSERT to _H.
-- =============================================================================

-- 1.1 LoanApplication_Keymap
INSERT INTO MortgagePlatform_Domain.LoanApplication_Keymap
    (loan_application_id, source_system)
SELECT DISTINCT
    TRIM(LOAN_SEQUENCE_NUMBER),
    'STG_Freddie_Origination'
FROM MortgagePlatform_Staging.STG_Freddie_Origination s
WHERE NOT EXISTS (
    SELECT 1 FROM MortgagePlatform_Domain.LoanApplication_Keymap k
    WHERE k.loan_application_id = TRIM(s.LOAN_SEQUENCE_NUMBER)
);

-- 1.2 Loan_Keymap
INSERT INTO MortgagePlatform_Domain.Loan_Keymap
    (loan_id, source_system)
SELECT DISTINCT
    TRIM(LOAN_SEQUENCE_NUMBER),
    'STG_Freddie_Origination'
FROM MortgagePlatform_Staging.STG_Freddie_Origination s
WHERE NOT EXISTS (
    SELECT 1 FROM MortgagePlatform_Domain.Loan_Keymap k
    WHERE k.loan_id = TRIM(s.LOAN_SEQUENCE_NUMBER)
);

-- 1.3 Customer_Keymap
INSERT INTO MortgagePlatform_Domain.Customer_Keymap
    (customer_id, source_system)
SELECT DISTINCT
    TRIM(CUSTOMER_ID),
    'STG_Borrower_Profile'
FROM MortgagePlatform_Staging.STG_Borrower_Profile s
WHERE NOT EXISTS (
    SELECT 1 FROM MortgagePlatform_Domain.Customer_Keymap k
    WHERE k.customer_id = TRIM(s.CUSTOMER_ID)
);

-- 1.4 Property_Keymap
INSERT INTO MortgagePlatform_Domain.Property_Keymap
    (property_id, source_system)
SELECT DISTINCT
    TRIM(PROPERTY_ID),
    'STG_Property_Valuation'
FROM MortgagePlatform_Staging.STG_Property_Valuation s
WHERE NOT EXISTS (
    SELECT 1 FROM MortgagePlatform_Domain.Property_Keymap k
    WHERE k.property_id = TRIM(s.PROPERTY_ID)
);


-- =============================================================================
-- SECTION 2: BIAN MORTGAGE LOAN APPLICATION
-- =============================================================================

INSERT INTO MortgagePlatform_Domain.LoanApplication_H (
    loan_application_key, loan_application_id,
    customer_key,
    channel_cd, loan_purpose_cd, occupancy_status_cd,
    requested_amount, orig_ltv, orig_cltv, orig_dti,
    credit_score_at_application, number_of_borrowers,
    first_time_homebuyer_flag, number_of_units, mi_percentage,
    program_indicator, harp_indicator, super_conforming_flag,
    pre_relief_refinance_lsn, application_status, seller_name,
    source_system, source_key,
    valid_from_dt, valid_to_dt, is_current, is_deleted
)
SELECT
    lak.loan_application_key,
    TRIM(o.LOAN_SEQUENCE_NUMBER),
    ck.customer_key,
    TRIM(o.CHANNEL),
    TRIM(o.LOAN_PURPOSE),
    TRIM(o.OCCUPANCY_STATUS),
    o.ORIG_UPB,
    o.ORIG_LTV,
    o.ORIG_CLTV,
    o.ORIG_DTI,
    o.CREDIT_SCORE,
    o.NUMBER_OF_BORROWERS,
    CASE WHEN o.FIRST_TIME_HOMEBUYER_FLAG = 'Y' THEN 1 ELSE 0 END,
    o.NUMBER_OF_UNITS,
    o.MI_PERCENTAGE,
    TRIM(o.PROGRAM_INDICATOR),
    CASE WHEN o.HARP_INDICATOR = 'Y' THEN 1 ELSE 0 END,
    CASE WHEN o.SUPER_CONFORMING_FLAG = 'Y' THEN 1 ELSE 0 END,
    TRIM(o.PRE_RELIEF_REFINANCE_LSN),
    'APPROVED',
    TRIM(o.SELLER_NAME),
    'STG_Freddie_Origination',
    TRIM(o.LOAN_SEQUENCE_NUMBER),
    -- valid_from: one month before first payment (proxy for application date)
    CAST(SUBSTR(o.FIRST_PAYMENT_DATE,1,4)||'-'||SUBSTR(o.FIRST_PAYMENT_DATE,5,2)||'-01'
         AS DATE FORMAT 'YYYY-MM-DD') - INTERVAL '1' MONTH,
    DATE '9999-12-31',
    1, 0
FROM MortgagePlatform_Staging.STG_Freddie_Origination          o
JOIN MortgagePlatform_Domain.LoanApplication_Keymap           lak ON lak.loan_application_id = TRIM(o.LOAN_SEQUENCE_NUMBER)
LEFT JOIN MortgagePlatform_Staging.STG_Borrower_Profile        bp  ON TRIM(bp.LOAN_SEQUENCE_NUMBER) = TRIM(o.LOAN_SEQUENCE_NUMBER)
LEFT JOIN MortgagePlatform_Domain.Customer_Keymap              ck  ON ck.customer_id = TRIM(bp.CUSTOMER_ID);


-- =============================================================================
-- SECTION 3: BIAN MORTGAGE LOAN
-- =============================================================================

INSERT INTO MortgagePlatform_Domain.Loan_H (
    loan_key, loan_id,
    loan_application_key, customer_key, property_key,
    orig_upb, orig_interest_rate, orig_loan_term_months,
    amortization_type_cd, maturity_dt, first_payment_dt,
    interest_only_indicator, ppm_flag,
    number_of_units, property_type_cd,
    property_state, property_postal_code,
    servicer_name, loan_status,
    zero_balance_code_cd, zero_balance_effective_dt,
    source_system, source_key,
    valid_from_dt, valid_to_dt, is_current, is_deleted
)
SELECT
    lk.loan_key,
    TRIM(o.LOAN_SEQUENCE_NUMBER),
    lak.loan_application_key,
    ck.customer_key,
    pk.property_key,
    o.ORIG_UPB,
    o.ORIG_INTEREST_RATE,
    o.ORIG_LOAN_TERM,
    TRIM(o.AMORTIZATION_TYPE),
    CAST(SUBSTR(o.MATURITY_DATE,1,4)||'-'||SUBSTR(o.MATURITY_DATE,5,2)||'-01'
         AS DATE FORMAT 'YYYY-MM-DD'),
    CAST(SUBSTR(o.FIRST_PAYMENT_DATE,1,4)||'-'||SUBSTR(o.FIRST_PAYMENT_DATE,5,2)||'-01'
         AS DATE FORMAT 'YYYY-MM-DD'),
    CASE WHEN o.INTEREST_ONLY_INDICATOR = 'Y' THEN 1 ELSE 0 END,
    CASE WHEN o.PPM_FLAG = 'Y' THEN 1 ELSE 0 END,
    o.NUMBER_OF_UNITS,
    TRIM(o.PROPERTY_TYPE),
    TRIM(pv.STATE),
    TRIM(pv.POSTCODE),
    TRIM(o.SERVICER_NAME),
    'ACTIVE',
    NULL,
    NULL,
    'STG_Freddie_Origination',
    TRIM(o.LOAN_SEQUENCE_NUMBER),
    CAST(SUBSTR(o.FIRST_PAYMENT_DATE,1,4)||'-'||SUBSTR(o.FIRST_PAYMENT_DATE,5,2)||'-01'
         AS DATE FORMAT 'YYYY-MM-DD'),
    DATE '9999-12-31',
    1, 0
FROM MortgagePlatform_Staging.STG_Freddie_Origination          o
JOIN MortgagePlatform_Domain.Loan_Keymap                       lk  ON lk.loan_id               = TRIM(o.LOAN_SEQUENCE_NUMBER)
JOIN MortgagePlatform_Domain.LoanApplication_Keymap           lak  ON lak.loan_application_id  = TRIM(o.LOAN_SEQUENCE_NUMBER)
LEFT JOIN MortgagePlatform_Staging.STG_Borrower_Profile        bp  ON TRIM(bp.LOAN_SEQUENCE_NUMBER) = TRIM(o.LOAN_SEQUENCE_NUMBER)
LEFT JOIN MortgagePlatform_Domain.Customer_Keymap              ck  ON ck.customer_id            = TRIM(bp.CUSTOMER_ID)
LEFT JOIN MortgagePlatform_Staging.STG_Property_Valuation      pv  ON TRIM(pv.LOAN_SEQUENCE_NUMBER) = TRIM(o.LOAN_SEQUENCE_NUMBER)
LEFT JOIN MortgagePlatform_Domain.Property_Keymap              pk  ON pk.property_id            = TRIM(pv.PROPERTY_ID);


-- =============================================================================
-- SECTION 4: BIAN PARTY / CUSTOMER
-- =============================================================================

-- 4.1 Customer_H
INSERT INTO MortgagePlatform_Domain.Customer_H (
    customer_key, customer_id,
    loan_application_key,
    customer_title, first_name, last_name, date_of_birth, gender,
    citizenship_status, digital_banking_enrolled, digital_banking_last_login,
    relationship_start_dt, deceased_flag,
    record_source_created_dt, record_source_updated_dt,
    source_system, source_key,
    valid_from_dt, valid_to_dt, is_current, is_deleted
)
SELECT
    ck.customer_key,
    TRIM(b.CUSTOMER_ID),
    lak.loan_application_key,
    TRIM(b.CUSTOMER_TITLE),
    TRIM(b.FIRST_NAME),
    TRIM(b.LAST_NAME),
    b.DATE_OF_BIRTH,
    TRIM(b.GENDER),
    TRIM(b.CITIZENSHIP_STATUS),
    CASE WHEN b.DIGITAL_BANKING_ENROLLED = 'Y' THEN 1 ELSE 0 END,
    b.DIGITAL_BANKING_LAST_LOGIN,
    b.RELATIONSHIP_START_DATE,
    CASE WHEN b.DECEASED_FLAG = 'Y' THEN 1 ELSE 0 END,
    b.RECORD_CREATED_DATE,
    b.RECORD_LAST_UPDATED,
    'STG_Borrower_Profile',
    TRIM(b.CUSTOMER_ID),
    b.RELATIONSHIP_START_DATE,
    DATE '9999-12-31',
    1, 0
FROM MortgagePlatform_Staging.STG_Borrower_Profile             b
JOIN MortgagePlatform_Domain.Customer_Keymap                   ck  ON ck.customer_id           = TRIM(b.CUSTOMER_ID)
LEFT JOIN MortgagePlatform_Domain.LoanApplication_Keymap       lak ON lak.loan_application_id  = TRIM(b.LOAN_SEQUENCE_NUMBER);

-- 4.2 CustomerContact_H
INSERT INTO MortgagePlatform_Domain.CustomerContact_H (
    customer_key,
    email_address, mobile_number, home_phone, preferred_contact_channel,
    source_system, source_key,
    valid_from_dt, valid_to_dt, is_current, is_deleted
)
SELECT
    ck.customer_key,
    TRIM(b.EMAIL_ADDRESS),
    TRIM(b.MOBILE_NUMBER),
    TRIM(b.HOME_PHONE),
    TRIM(b.PREFERRED_CONTACT_CHANNEL),
    'STG_Borrower_Profile',
    TRIM(b.CUSTOMER_ID),
    b.RELATIONSHIP_START_DATE,
    DATE '9999-12-31',
    1, 0
FROM MortgagePlatform_Staging.STG_Borrower_Profile             b
JOIN MortgagePlatform_Domain.Customer_Keymap                   ck ON ck.customer_id = TRIM(b.CUSTOMER_ID);

-- 4.3 CustomerAddress_H
INSERT INTO MortgagePlatform_Domain.CustomerAddress_H (
    customer_key,
    address_line_1, address_line_2, suburb, state, postcode, address_type,
    source_system, source_key,
    valid_from_dt, valid_to_dt, is_current, is_deleted
)
SELECT
    ck.customer_key,
    TRIM(b.ADDRESS_LINE_1),
    TRIM(b.ADDRESS_LINE_2),
    TRIM(b.SUBURB),
    TRIM(b.STATE),
    TRIM(b.POSTCODE),
    'RESIDENTIAL',
    'STG_Borrower_Profile',
    TRIM(b.CUSTOMER_ID),
    b.RELATIONSHIP_START_DATE,
    DATE '9999-12-31',
    1, 0
FROM MortgagePlatform_Staging.STG_Borrower_Profile             b
JOIN MortgagePlatform_Domain.Customer_Keymap                   ck ON ck.customer_id = TRIM(b.CUSTOMER_ID);

-- 4.4 CustomerSegment_H
INSERT INTO MortgagePlatform_Domain.CustomerSegment_H (
    customer_key,
    segment_cd, branch_code, relationship_manager_id,
    last_contact_dt, marketing_opt_in,
    source_system, source_key,
    valid_from_dt, valid_to_dt, is_current, is_deleted
)
SELECT
    ck.customer_key,
    TRIM(b.CUSTOMER_SEGMENT),
    TRIM(b.BRANCH_CODE),
    TRIM(b.RELATIONSHIP_MANAGER_ID),
    b.LAST_CONTACT_DATE,
    CASE WHEN b.MARKETING_OPT_IN = 'Y' THEN 1 ELSE 0 END,
    'STG_Borrower_Profile',
    TRIM(b.CUSTOMER_ID),
    b.RELATIONSHIP_START_DATE,
    DATE '9999-12-31',
    1, 0
FROM MortgagePlatform_Staging.STG_Borrower_Profile             b
JOIN MortgagePlatform_Domain.Customer_Keymap                   ck ON ck.customer_id = TRIM(b.CUSTOMER_ID);

-- 4.5 CustomerFinancial_H
INSERT INTO MortgagePlatform_Domain.CustomerFinancial_H (
    customer_key,
    annual_income, income_verified_flag,
    employment_status_cd, employer_name, years_with_employer,
    source_system, source_key,
    valid_from_dt, valid_to_dt, is_current, is_deleted
)
SELECT
    ck.customer_key,
    b.ANNUAL_INCOME,
    CASE WHEN b.INCOME_VERIFIED_FLAG = 'Y' THEN 1 ELSE 0 END,
    TRIM(b.EMPLOYMENT_STATUS),
    TRIM(b.EMPLOYER_NAME),
    b.YEARS_WITH_EMPLOYER,
    'STG_Borrower_Profile',
    TRIM(b.CUSTOMER_ID),
    b.RELATIONSHIP_START_DATE,
    DATE '9999-12-31',
    1, 0
FROM MortgagePlatform_Staging.STG_Borrower_Profile             b
JOIN MortgagePlatform_Domain.Customer_Keymap                   ck ON ck.customer_id = TRIM(b.CUSTOMER_ID);

-- 4.6 CustomerInsight_H
INSERT INTO MortgagePlatform_Domain.CustomerInsight_H (
    customer_key,
    churn_risk_score, churn_risk_band, nps_score,
    source_system, source_key,
    valid_from_dt, valid_to_dt, is_current, is_deleted
)
SELECT
    ck.customer_key,
    b.CHURN_RISK_SCORE,
    TRIM(b.CHURN_RISK_BAND),
    b.NPS_SCORE,
    'STG_Borrower_Profile',
    TRIM(b.CUSTOMER_ID),
    b.RELATIONSHIP_START_DATE,
    DATE '9999-12-31',
    1, 0
FROM MortgagePlatform_Staging.STG_Borrower_Profile             b
JOIN MortgagePlatform_Domain.Customer_Keymap                   ck ON ck.customer_id = TRIM(b.CUSTOMER_ID);

-- 4.7 CustomerCompliance_H
INSERT INTO MortgagePlatform_Domain.CustomerCompliance_H (
    customer_key,
    kyc_status_cd, kyc_verification_dt, aml_risk_rating_cd,
    source_system, source_key,
    valid_from_dt, valid_to_dt, is_current, is_deleted
)
SELECT
    ck.customer_key,
    TRIM(b.KYC_STATUS),
    b.KYC_VERIFICATION_DATE,
    TRIM(b.AML_RISK_RATING),
    'STG_Borrower_Profile',
    TRIM(b.CUSTOMER_ID),
    b.RELATIONSHIP_START_DATE,
    DATE '9999-12-31',
    1, 0
FROM MortgagePlatform_Staging.STG_Borrower_Profile             b
JOIN MortgagePlatform_Domain.Customer_Keymap                   ck ON ck.customer_id = TRIM(b.CUSTOMER_ID);


-- =============================================================================
-- SECTION 5: BIAN COLLATERAL ASSET ADMINISTRATION
-- =============================================================================

-- 5.1 Property_H
INSERT INTO MortgagePlatform_Domain.Property_H (
    property_key, property_id,
    loan_key, customer_key,
    property_type_cd, property_status_cd,
    bedrooms, bathrooms, car_spaces,
    land_area_sqm, floor_area_sqm, year_built,
    zoning_code, council_area,
    source_system, source_key,
    valid_from_dt, valid_to_dt, is_current, is_deleted
)
SELECT
    pk.property_key,
    TRIM(pv.PROPERTY_ID),
    lk.loan_key,
    ck.customer_key,
    TRIM(pv.PROPERTY_TYPE_CODE),
    TRIM(pv.PROPERTY_STATUS),
    pv.BEDROOMS,
    pv.BATHROOMS,
    pv.CAR_SPACES,
    pv.LAND_AREA_SQM,
    pv.FLOOR_AREA_SQM,
    pv.YEAR_BUILT,
    TRIM(pv.ZONING_CODE),
    TRIM(pv.COUNCIL_AREA),
    'STG_Property_Valuation',
    TRIM(pv.PROPERTY_ID),
    pv.ORIG_VALUATION_DATE,
    DATE '9999-12-31',
    1, 0
FROM MortgagePlatform_Staging.STG_Property_Valuation           pv
JOIN MortgagePlatform_Domain.Property_Keymap                   pk  ON pk.property_id  = TRIM(pv.PROPERTY_ID)
LEFT JOIN MortgagePlatform_Domain.Loan_Keymap                  lk  ON lk.loan_id      = TRIM(pv.LOAN_SEQUENCE_NUMBER)
LEFT JOIN MortgagePlatform_Domain.Customer_Keymap              ck  ON ck.customer_id  = TRIM(pv.CUSTOMER_ID);

-- 5.2 PropertyAddress_H
INSERT INTO MortgagePlatform_Domain.PropertyAddress_H (
    property_key,
    street_number, street_name, street_type, unit_number,
    suburb, state, postcode,
    source_system, source_key,
    valid_from_dt, valid_to_dt, is_current, is_deleted
)
SELECT
    pk.property_key,
    TRIM(pv.STREET_NUMBER),
    TRIM(pv.STREET_NAME),
    TRIM(pv.STREET_TYPE),
    TRIM(pv.UNIT_NUMBER),
    TRIM(pv.SUBURB),
    TRIM(pv.STATE),
    TRIM(pv.POSTCODE),
    'STG_Property_Valuation',
    TRIM(pv.PROPERTY_ID),
    pv.ORIG_VALUATION_DATE,
    DATE '9999-12-31',
    1, 0
FROM MortgagePlatform_Staging.STG_Property_Valuation           pv
JOIN MortgagePlatform_Domain.Property_Keymap                   pk ON pk.property_id = TRIM(pv.PROPERTY_ID);

-- 5.3 PropertyValuation_H - two rows per property (ORIGINAL + CURRENT_AVM)
-- Row 1: original formal valuation at origination
INSERT INTO MortgagePlatform_Domain.PropertyValuation_H (
    property_key, valuation_type, valuation_dt,
    valuation_amount, valuation_method_cd, valuer_name, estimated_lvr
)
SELECT
    pk.property_key,
    'ORIGINAL',
    pv.ORIG_VALUATION_DATE,
    pv.ORIG_VALUATION_AMOUNT,
    TRIM(pv.ORIG_VALUATION_METHOD),
    TRIM(pv.ORIG_VALUER_NAME),
    -- Estimated LVR at origination from Freddie Mac data
    CAST(o.ORIG_LTV AS DECIMAL(6,3))
FROM MortgagePlatform_Staging.STG_Property_Valuation           pv
JOIN MortgagePlatform_Domain.Property_Keymap                   pk ON pk.property_id = TRIM(pv.PROPERTY_ID)
LEFT JOIN MortgagePlatform_Staging.STG_Freddie_Origination     o  ON TRIM(o.LOAN_SEQUENCE_NUMBER) = TRIM(pv.LOAN_SEQUENCE_NUMBER)
WHERE pv.ORIG_VALUATION_DATE IS NOT NULL
  AND pv.ORIG_VALUATION_AMOUNT IS NOT NULL;

-- Row 2: most recent AVM refresh (only where current valuation exists)
INSERT INTO MortgagePlatform_Domain.PropertyValuation_H (
    property_key, valuation_type, valuation_dt,
    valuation_amount, valuation_method_cd, valuer_name, estimated_lvr
)
SELECT
    pk.property_key,
    'CURRENT_AVM',
    pv.CURRENT_VALUATION_DATE,
    pv.CURRENT_VALUATION_AMOUNT,
    TRIM(pv.CURRENT_VALUATION_METHOD),
    NULL,
    pv.ESTIMATED_LVR
FROM MortgagePlatform_Staging.STG_Property_Valuation           pv
JOIN MortgagePlatform_Domain.Property_Keymap                   pk ON pk.property_id = TRIM(pv.PROPERTY_ID)
WHERE pv.CURRENT_VALUATION_DATE IS NOT NULL
  AND pv.CURRENT_VALUATION_AMOUNT IS NOT NULL;

-- 5.4 PropertyRisk_H
INSERT INTO MortgagePlatform_Domain.PropertyRisk_H (
    property_key,
    flood_risk_zone, fire_risk_zone, environmental_constraint,
    source_system, source_key,
    valid_from_dt, valid_to_dt, is_current, is_deleted
)
SELECT
    pk.property_key,
    CASE WHEN TRIM(pv.FLOOD_RISK_ZONE) = 'Overland F' THEN 'Overland Flow'
         ELSE TRIM(pv.FLOOD_RISK_ZONE) END,
    TRIM(pv.FIRE_RISK_ZONE),
    CASE WHEN pv.ENVIRONMENTAL_CONSTRAINT = 'Y' THEN 1 ELSE 0 END,
    'STG_Property_Valuation',
    TRIM(pv.PROPERTY_ID),
    pv.ORIG_VALUATION_DATE,
    DATE '9999-12-31',
    1, 0
FROM MortgagePlatform_Staging.STG_Property_Valuation           pv
JOIN MortgagePlatform_Domain.Property_Keymap                   pk ON pk.property_id = TRIM(pv.PROPERTY_ID);

-- 5.5 PropertyTitle_H
INSERT INTO MortgagePlatform_Domain.PropertyTitle_H (
    property_key,
    title_reference, lot_number, plan_number, strata_flag, heritage_listed,
    source_system, source_key,
    valid_from_dt, valid_to_dt, is_current, is_deleted
)
SELECT
    pk.property_key,
    TRIM(pv.TITLE_REFERENCE),
    TRIM(pv.LOT_NUMBER),
    TRIM(pv.PLAN_NUMBER),
    CASE WHEN pv.STRATA_FLAG = 'Y' THEN 1 ELSE 0 END,
    CASE WHEN pv.HERITAGE_LISTED = 'Y' THEN 1 ELSE 0 END,
    'STG_Property_Valuation',
    TRIM(pv.PROPERTY_ID),
    pv.ORIG_VALUATION_DATE,
    DATE '9999-12-31',
    1, 0
FROM MortgagePlatform_Staging.STG_Property_Valuation           pv
JOIN MortgagePlatform_Domain.Property_Keymap                   pk ON pk.property_id = TRIM(pv.PROPERTY_ID);


-- =============================================================================
-- SECTION 6: BIAN MORTGAGE LOAN (SERVICING) -- LoanPerformance_H
-- 153,382 rows; one immutable row per loan per reporting month.
-- =============================================================================

INSERT INTO MortgagePlatform_Domain.LoanPerformance_H (
    loan_key, reporting_period_dt,
    current_actual_upb, current_interest_rate, estimated_ltv,
    current_deferred_upb, delinquent_accrued_interest,
    delinquency_status_cd, delinquency_due_to_disaster,
    borrower_assistance_status_cd,
    loan_age_months, remaining_months_to_maturity,
    modification_flag, step_modification_flag, deferred_payment_plan,
    modification_cost, current_month_modification_cost,
    mi_recoveries, net_sales_proceeds, non_mi_recoveries,
    expenses, legal_costs, maintenance_preservation_costs,
    taxes_and_insurance, miscellaneous_expenses,
    actual_loss_calculation, repurchase_make_whole_proceeds,
    zero_balance_code_cd, zero_balance_effective_dt,
    zero_balance_removal_upb, repurchase_dt
)
SELECT
    lk.loan_key,
    CAST(SUBSTR(p.MONTHLY_REPORTING_PERIOD,1,4)||'-'||SUBSTR(p.MONTHLY_REPORTING_PERIOD,5,2)||'-01'
         AS DATE FORMAT 'YYYY-MM-DD'),
    p.CURRENT_ACTUAL_UPB,
    p.CURRENT_INTEREST_RATE,
    p.ESTIMATED_LOAN_TO_VALUE,
    p.CURRENT_DEFERRED_UPB,
    p.DELINQUENT_ACCRUED_INTEREST,
    TRIM(p.CURRENT_LOAN_DELINQUENCY_STATUS),
    CASE WHEN p.DELINQUENCY_DUE_TO_DISASTER = 'Y' THEN 1 ELSE 0 END,
    TRIM(p.BORROWER_ASSISTANCE_STATUS),
    p.LOAN_AGE,
    p.REMAINING_MONTHS_TO_MATURITY,
    CASE WHEN p.MODIFICATION_FLAG = 'Y' THEN 1 ELSE 0 END,
    CASE WHEN p.STEP_MODIFICATION_FLAG = 'Y' THEN 1 ELSE 0 END,
    CASE WHEN p.DEFERRED_PAYMENT_PLAN = 'Y' THEN 1 ELSE 0 END,
    p.MODIFICATION_COST,
    p.CURRENT_MONTH_MODIFICATION_COST,
    p.MI_RECOVERIES,
    p.NET_SALES_PROCEEDS,
    p.NON_MI_RECOVERIES,
    p.EXPENSES,
    p.LEGAL_COSTS,
    p.MAINTENANCE_PRESERVATION_COSTS,
    p.TAXES_AND_INSURANCE,
    p.MISCELLANEOUS_EXPENSES,
    p.ACTUAL_LOSS_CALCULATION,
    p.REPURCHASE_MAKE_WHOLE_PROCEEDS,
    TRIM(p.ZERO_BALANCE_CODE),
    CASE WHEN p.ZERO_BALANCE_EFFECTIVE_DATE IS NOT NULL
         THEN CAST(SUBSTR(p.ZERO_BALANCE_EFFECTIVE_DATE,1,4)||'-'||SUBSTR(p.ZERO_BALANCE_EFFECTIVE_DATE,5,2)||'-01'
                   AS DATE FORMAT 'YYYY-MM-DD') END,
    p.ZERO_BALANCE_REMOVAL_UPB,
    CASE WHEN p.REPURCHASE_DATE IS NOT NULL
         THEN CAST(SUBSTR(p.REPURCHASE_DATE,1,4)||'-'||SUBSTR(p.REPURCHASE_DATE,5,2)||'-01'
                   AS DATE FORMAT 'YYYY-MM-DD') END
FROM MortgagePlatform_Staging.STG_Freddie_Performance          p
JOIN MortgagePlatform_Domain.Loan_Keymap                       lk ON lk.loan_id = TRIM(p.LOAN_SEQUENCE_NUMBER);


-- =============================================================================
-- SECTION 7: LOAN EVENTS (derived from LoanPerformance month-on-month changes)
-- =============================================================================

-- 7a Delinquency escalations (status worsening)
INSERT INTO MortgagePlatform_Domain.LoanEvent_H (
    loan_key, event_type_cd, event_dt, reporting_period_dt,
    prior_value, new_value, event_description
)
SELECT
    curr.loan_key,
    'DELINQUENCY_ESCALATION',
    curr.reporting_period_dt,
    curr.reporting_period_dt,
    prev.delinquency_status_cd,
    curr.delinquency_status_cd,
    'Delinquency escalated from status ' || TRIM(prev.delinquency_status_cd) ||
    ' to ' || TRIM(curr.delinquency_status_cd)
FROM MortgagePlatform_Domain.LoanPerformance_H                 curr
JOIN MortgagePlatform_Domain.LoanPerformance_H                 prev
    ON  prev.loan_key            = curr.loan_key
    AND prev.reporting_period_dt = ADD_MONTHS(curr.reporting_period_dt, -1)
WHERE curr.delinquency_status_cd NOT IN ('0', 'RA')
  AND prev.delinquency_status_cd NOT IN ('RA')
  AND CAST(curr.delinquency_status_cd AS INTEGER) > CAST(prev.delinquency_status_cd AS INTEGER);

-- 7b Delinquency cures (status improving)
INSERT INTO MortgagePlatform_Domain.LoanEvent_H (
    loan_key, event_type_cd, event_dt, reporting_period_dt,
    prior_value, new_value, event_description
)
SELECT
    curr.loan_key,
    'DELINQUENCY_CURE',
    curr.reporting_period_dt,
    curr.reporting_period_dt,
    prev.delinquency_status_cd,
    curr.delinquency_status_cd,
    'Delinquency cured from status ' || TRIM(prev.delinquency_status_cd) ||
    ' to ' || TRIM(curr.delinquency_status_cd)
FROM MortgagePlatform_Domain.LoanPerformance_H                 curr
JOIN MortgagePlatform_Domain.LoanPerformance_H                 prev
    ON  prev.loan_key            = curr.loan_key
    AND prev.reporting_period_dt = ADD_MONTHS(curr.reporting_period_dt, -1)
WHERE curr.delinquency_status_cd NOT IN ('RA')
  AND prev.delinquency_status_cd NOT IN ('RA', '0')
  AND CAST(curr.delinquency_status_cd AS INTEGER) < CAST(prev.delinquency_status_cd AS INTEGER);

-- 7c Zero balance events (loan reached zero UPB)
INSERT INTO MortgagePlatform_Domain.LoanEvent_H (
    loan_key, event_type_cd, event_dt, reporting_period_dt,
    prior_value, new_value, event_description
)
SELECT
    p.loan_key,
    'ZERO_BALANCE',
    p.reporting_period_dt,
    p.reporting_period_dt,
    NULL,
    TRIM(p.zero_balance_code_cd),
    'Loan reached zero balance: ' || TRIM(p.zero_balance_code_cd)
FROM MortgagePlatform_Domain.LoanPerformance_H                 p
WHERE p.zero_balance_code_cd IS NOT NULL;


-- =============================================================================
-- SECTION 8: BIAN PAYMENT (derived from LoanPerformance UPB movement)
-- =============================================================================

INSERT INTO MortgagePlatform_Domain.Payment_H (
    loan_key, payment_period_dt, payment_type_cd,
    opening_upb, closing_upb,
    principal_component, interest_component, total_payment,
    delinquency_status_cd, source_system
)
SELECT
    loan_key, reporting_period_dt, 'SCHEDULED',
    opening_upb,
    current_actual_upb,
    CAST(GREATEST(opening_upb - current_actual_upb, 0.00) AS DECIMAL(15,2)),
    CAST(opening_upb * current_interest_rate / 100.0 / 12.0 AS DECIMAL(15,2)),
    CAST(GREATEST(opening_upb - current_actual_upb, 0.00) AS DECIMAL(15,2)) +
    CAST(opening_upb * current_interest_rate / 100.0 / 12.0 AS DECIMAL(15,2)),
    delinquency_status_cd,
    'LoanPerformance_H'
FROM (
    SELECT
        p.loan_key, p.reporting_period_dt,
        p.current_actual_upb, p.current_interest_rate,
        p.delinquency_status_cd,
        COALESCE(
            LAG(p.current_actual_upb) OVER (PARTITION BY p.loan_key ORDER BY p.reporting_period_dt),
            l.orig_upb
        ) AS opening_upb
    FROM MortgagePlatform_Domain.LoanPerformance_H             p
    JOIN MortgagePlatform_Domain.Loan_Current                  l  ON l.loan_key = p.loan_key
    WHERE p.current_actual_upb IS NOT NULL
      AND p.current_interest_rate IS NOT NULL
) dt
WHERE opening_upb IS NOT NULL;


-- =============================================================================
-- SECTION 9: BIAN CUSTOMER STATEMENT (derived from Payment_H + Loan_Current)
-- =============================================================================

INSERT INTO MortgagePlatform_Domain.LoanStatement_H (
    loan_key, customer_key,
    statement_period_dt, statement_dt,
    opening_balance, closing_balance,
    interest_charged, principal_paid, total_paid,
    delinquency_status_cd, source_system
)
SELECT
    p.loan_key,
    l.customer_key,
    p.payment_period_dt,
    p.payment_period_dt + 10,
    p.opening_upb,
    p.closing_upb,
    p.interest_component,
    p.principal_component,
    p.total_payment,
    p.delinquency_status_cd,
    'Payment_H'
FROM MortgagePlatform_Domain.Payment_H                         p
JOIN MortgagePlatform_Domain.Loan_Current                      l ON l.loan_key = p.loan_key;
