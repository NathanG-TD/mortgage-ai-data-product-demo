-- =============================================================================
-- 00_create_staging_tables.sql
-- MortgagePlatform — Staging Layer DDL
--
-- Creates raw staging tables in MortgagePlatform_Staging.
-- These tables mirror source file layouts exactly — no transformation applied.
-- Column comments provide the semantic bridge that the mapping agent reads.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- STG_Freddie_Origination
-- Source: Loan Origination System (Freddie Mac origination file)
-- -----------------------------------------------------------------------------
CREATE MULTISET TABLE MortgagePlatform_Staging.STG_Freddie_Origination,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    CREDIT_SCORE                    INTEGER,
    FIRST_PAYMENT_DATE              CHAR(6),
    FIRST_TIME_HOMEBUYER_FLAG       CHAR(1),
    MATURITY_DATE                   CHAR(6),
    MSA                             CHAR(5),
    MI_PERCENTAGE                   INTEGER,
    NUMBER_OF_UNITS                 INTEGER,
    OCCUPANCY_STATUS                CHAR(1),
    ORIG_CLTV                       INTEGER,
    ORIG_DTI                        INTEGER,
    ORIG_UPB                        DECIMAL(15,2),
    ORIG_LTV                        INTEGER,
    ORIG_INTEREST_RATE              DECIMAL(6,3),
    CHANNEL                         CHAR(1),
    PPM_FLAG                        CHAR(1),
    AMORTIZATION_TYPE               CHAR(5),
    PROPERTY_STATE                  CHAR(2),
    PROPERTY_TYPE                   CHAR(2),
    POSTAL_CODE                     CHAR(5),
    LOAN_SEQUENCE_NUMBER            CHAR(12)    NOT NULL,
    LOAN_PURPOSE                    CHAR(1),
    ORIG_LOAN_TERM                  INTEGER,
    NUMBER_OF_BORROWERS             INTEGER,
    SELLER_NAME                     VARCHAR(60),
    SERVICER_NAME                   VARCHAR(60),
    SUPER_CONFORMING_FLAG           CHAR(1),
    PRE_RELIEF_REFINANCE_LSN        CHAR(12),
    -- Columns 28-32: added in post-2018 Freddie Mac dataset format
    PROGRAM_INDICATOR               CHAR(1),
    HARP_INDICATOR                  CHAR(1),
    PROPERTY_VALUATION_METHOD       CHAR(1),
    INTEREST_ONLY_INDICATOR         CHAR(1),
    MI_CANCELLATION_INDICATOR       CHAR(1),
    stg_load_timestamp              TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
)
PRIMARY INDEX (LOAN_SEQUENCE_NUMBER);

COMMENT ON TABLE MortgagePlatform_Staging.STG_Freddie_Origination IS
    'Staging: Freddie Mac Single Family Origination file. One record per loan at origination. Source system: Loan Origination System (LOS). Maps to domain entities: Loan, Borrower, Property, LoanProduct.';

COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.LOAN_SEQUENCE_NUMBER IS 'Primary key. Unique loan identifier assigned by Freddie Mac. Format: FddQqNNNNNN. Used as join key across all source files.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.CREDIT_SCORE IS 'FICO credit score of the representative borrower at origination. Range 300–850. For multi-borrower loans, reflects the lower borrower score per Freddie Mac guidelines.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.ORIG_UPB IS 'Original Unpaid Principal Balance — the face amount of the loan at origination in USD.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.ORIG_LTV IS 'Original Loan-to-Value ratio. Loan amount divided by appraised property value at origination. Range 1–105.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.ORIG_CLTV IS 'Original Combined Loan-to-Value ratio. All mortgage liens at origination divided by property value. CLTV >= LTV when subordinate liens exist.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.ORIG_DTI IS 'Original Debt-to-Income ratio. Monthly debt obligations divided by gross monthly income at origination. Key affordability metric.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.ORIG_INTEREST_RATE IS 'Original note interest rate as a percentage (e.g. 6.500 = 6.5%). For ARMs, this is the initial rate.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.AMORTIZATION_TYPE IS 'Amortisation type. FRM=Fixed Rate Mortgage, ARM=Adjustable Rate Mortgage.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.OCCUPANCY_STATUS IS 'Property occupancy at origination. P=Primary Residence, S=Second Home, I=Investment Property.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.LOAN_PURPOSE IS 'Purpose of the loan. P=Purchase, C=Cash-out Refinance, N=No Cash-out Refinance.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.CHANNEL IS 'Origination channel. R=Retail (direct), B=Broker, C=Correspondent.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.PROPERTY_TYPE IS 'Property type code. SF=Single Family, CO=Condominium, PU=PUD, MH=Manufactured Home.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.FIRST_TIME_HOMEBUYER_FLAG IS 'Y if borrower is a first-time homebuyer (no ownership interest in principal residence in past 3 years), N otherwise.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.PROGRAM_INDICATOR IS 'Freddie Mac affordable lending program indicator. H=Home Possible. Null if not a designated program loan.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.HARP_INDICATOR IS 'Home Affordable Refinance Program indicator. Y=HARP loan. Null if not a HARP refinance.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.PROPERTY_VALUATION_METHOD IS 'Method used to value the property. 1=ACE (automated collateral evaluation — no appraisal), 2=Traditional appraisal, 3=ACE+ PDR.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.INTEREST_ONLY_INDICATOR IS 'Y if loan has an interest-only period, N otherwise.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Origination.MI_CANCELLATION_INDICATOR IS 'Mortgage Insurance cancellation indicator. Values vary by vintage — check Freddie Mac data dictionary for current codes.';

-- -----------------------------------------------------------------------------
-- STG_Freddie_Performance
-- Source: Loan Servicing System (Freddie Mac monthly performance file)
-- -----------------------------------------------------------------------------
CREATE MULTISET TABLE MortgagePlatform_Staging.STG_Freddie_Performance,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    LOAN_SEQUENCE_NUMBER            CHAR(12)        NOT NULL,
    MONTHLY_REPORTING_PERIOD        CHAR(6)         NOT NULL,
    CURRENT_ACTUAL_UPB              DECIMAL(15,2),
    CURRENT_LOAN_DELINQUENCY_STATUS CHAR(3),
    LOAN_AGE                        INTEGER,
    REMAINING_MONTHS_TO_MATURITY    INTEGER,
    REPURCHASE_DATE                 CHAR(6),
    MODIFICATION_FLAG               CHAR(1),
    ZERO_BALANCE_CODE               CHAR(2),
    ZERO_BALANCE_EFFECTIVE_DATE     CHAR(6),
    CURRENT_INTEREST_RATE           DECIMAL(6,3),
    CURRENT_DEFERRED_UPB            DECIMAL(15,2),
    DUE_DATE_LAST_PAID_INSTALL      CHAR(6),
    MI_RECOVERIES                   DECIMAL(15,2),
    NET_SALES_PROCEEDS              DECIMAL(15,2),
    NON_MI_RECOVERIES               DECIMAL(15,2),
    EXPENSES                        DECIMAL(15,2),
    LEGAL_COSTS                     DECIMAL(15,2),
    MAINTENANCE_PRESERVATION_COSTS  DECIMAL(15,2),
    TAXES_AND_INSURANCE             DECIMAL(15,2),
    MISCELLANEOUS_EXPENSES          DECIMAL(15,2),
    ACTUAL_LOSS_CALCULATION         DECIMAL(15,2),
    MODIFICATION_COST               DECIMAL(15,2),
    STEP_MODIFICATION_FLAG          CHAR(1),
    DEFERRED_PAYMENT_PLAN           CHAR(1),
    ESTIMATED_LOAN_TO_VALUE         DECIMAL(6,3),
    ZERO_BALANCE_REMOVAL_UPB        DECIMAL(15,2),
    DELINQUENT_ACCRUED_INTEREST     DECIMAL(15,2),
    DELINQUENCY_DUE_TO_DISASTER     CHAR(1),
    BORROWER_ASSISTANCE_STATUS      CHAR(2),
    CURRENT_MONTH_MODIFICATION_COST DECIMAL(15,2),
    stg_load_timestamp              TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
)
PRIMARY INDEX (LOAN_SEQUENCE_NUMBER, MONTHLY_REPORTING_PERIOD);

COMMENT ON TABLE MortgagePlatform_Staging.STG_Freddie_Performance IS
    'Staging: Freddie Mac Monthly Performance file. One record per loan per reporting month. Source system: Loan Servicing System. Maps to domain entities: LoanPerformance, LoanEvent, LoanModification. Key source for churn signals (delinquency escalation, zero balance codes) and fraud indicators.';

COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Performance.LOAN_SEQUENCE_NUMBER IS 'Foreign key to STG_Freddie_Origination. Part of composite primary key.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Performance.MONTHLY_REPORTING_PERIOD IS 'Reporting month in YYYYMM format. Part of composite primary key.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Performance.CURRENT_LOAN_DELINQUENCY_STATUS IS 'Delinquency status code. 0=Current, 1–6=Months past due (30/60/90/120/150/180+), RA=REO Acquisition. Escalating values signal churn risk.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Performance.ZERO_BALANCE_CODE IS 'Reason for loan reaching zero balance. 01=Prepaid/Matured (voluntary churn), 02=Third Party Sale, 03=Short Sale, 09=REO Disposition (distressed exit). Null when loan is active.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Performance.MODIFICATION_FLAG IS 'Y if loan was modified in this reporting period. Repeated modifications with ongoing delinquency can indicate fraud.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Performance.CURRENT_ACTUAL_UPB IS 'Current unpaid principal balance. Zero when ZERO_BALANCE_CODE is populated.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Performance.ESTIMATED_LOAN_TO_VALUE IS 'Current estimated LTV using updated property value model. Higher than origination LTV may indicate negative equity.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Freddie_Performance.BORROWER_ASSISTANCE_STATUS IS 'Active borrower assistance type. F=Forbearance, R=Repayment plan, T=Trial period modification plan.';

-- -----------------------------------------------------------------------------
-- STG_Borrower_Profile
-- Source: CRM / Customer Master System (synthetic)
-- -----------------------------------------------------------------------------
CREATE MULTISET TABLE MortgagePlatform_Staging.STG_Borrower_Profile,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    CUSTOMER_ID                     VARCHAR(20)     NOT NULL,
    LOAN_SEQUENCE_NUMBER            CHAR(12)        NOT NULL,
    TITLE                           VARCHAR(10),
    FIRST_NAME                      VARCHAR(50)     NOT NULL,
    LAST_NAME                       VARCHAR(50)     NOT NULL,
    DATE_OF_BIRTH                   DATE,
    GENDER                          CHAR(1),
    EMAIL_ADDRESS                   VARCHAR(100),
    MOBILE_NUMBER                   VARCHAR(20),
    HOME_PHONE                      VARCHAR(20),
    ADDRESS_LINE_1                  VARCHAR(100),
    ADDRESS_LINE_2                  VARCHAR(100),
    SUBURB                          VARCHAR(60),
    STATE                           CHAR(3),
    POSTCODE                        CHAR(4),
    CUSTOMER_SEGMENT                VARCHAR(30),
    RELATIONSHIP_START_DATE         DATE,
    PREFERRED_CONTACT_CHANNEL       VARCHAR(20),
    DIGITAL_BANKING_ENROLLED        CHAR(1),
    DIGITAL_BANKING_LAST_LOGIN      DATE,
    BRANCH_CODE                     CHAR(6),
    RELATIONSHIP_MANAGER_ID         VARCHAR(20),
    ANNUAL_INCOME                   DECIMAL(15,2),
    INCOME_VERIFIED_FLAG            CHAR(1),
    EMPLOYMENT_STATUS               VARCHAR(30),
    EMPLOYER_NAME                   VARCHAR(100),
    YEARS_WITH_EMPLOYER             DECIMAL(4,1),
    CITIZENSHIP_STATUS              VARCHAR(30),
    KYC_STATUS                      VARCHAR(20),
    KYC_VERIFICATION_DATE           DATE,
    AML_RISK_RATING                 CHAR(1),
    LAST_CONTACT_DATE               DATE,
    NPS_SCORE                       INTEGER,
    CHURN_RISK_SCORE                DECIMAL(5,2),
    CHURN_RISK_BAND                 VARCHAR(10),
    MARKETING_OPT_IN                CHAR(1),
    DECEASED_FLAG                   CHAR(1),
    RECORD_CREATED_DATE             DATE,
    RECORD_LAST_UPDATED             DATE,
    stg_load_timestamp              TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
)
PRIMARY INDEX (CUSTOMER_ID);

COMMENT ON TABLE MortgagePlatform_Staging.STG_Borrower_Profile IS
    'Staging: CRM Customer Master record. One record per customer. Source system: Customer Relationship Management (CRM). Maps to domain entities: Customer, CustomerContact, CustomerAddress, CustomerCompliance, CustomerInsight. Synthetic data generated to align with Freddie Mac loan population.';

COMMENT ON COLUMN MortgagePlatform_Staging.STG_Borrower_Profile.CUSTOMER_ID IS 'Bank-assigned master customer identifier. Format: CUS-XXXXXXXX. Primary key. This is the enterprise customer key — all product systems should reference this.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Borrower_Profile.LOAN_SEQUENCE_NUMBER IS 'Foreign key to STG_Freddie_Origination. Join key between CRM and LOS.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Borrower_Profile.CUSTOMER_SEGMENT IS 'CRM marketing segment. Values: Mass Market, Emerging Affluent, Affluent, Private Banking, Business Owner.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Borrower_Profile.AML_RISK_RATING IS 'Anti-Money Laundering risk rating assigned by compliance. L=Low, M=Medium, H=High. Regulated attribute — access controls required.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Borrower_Profile.KYC_STATUS IS 'Know Your Customer identity verification status. Verified=Passed all checks, Pending=In progress, Expired=Reverification required, Failed=Failed verification.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Borrower_Profile.CHURN_RISK_SCORE IS 'Model-generated churn propensity score loaded back from analytics platform. Range 0.00 (no risk) to 1.00 (certain churn). Not a raw CRM field.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Borrower_Profile.NPS_SCORE IS 'Net Promoter Score from most recent customer survey. Range -100 to 100. Promoters >= 9, Detractors <= 6.';

-- -----------------------------------------------------------------------------
-- STG_Property_Valuation
-- Source: Collateral Management System (synthetic)
-- -----------------------------------------------------------------------------
CREATE MULTISET TABLE MortgagePlatform_Staging.STG_Property_Valuation,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    PROPERTY_ID                     VARCHAR(20)     NOT NULL,
    LOAN_SEQUENCE_NUMBER            CHAR(12)        NOT NULL,
    CUSTOMER_ID                     VARCHAR(20)     NOT NULL,
    STREET_NUMBER                   VARCHAR(10),
    STREET_NAME                     VARCHAR(80),
    STREET_TYPE                     VARCHAR(20),
    UNIT_NUMBER                     VARCHAR(20),
    SUBURB                          VARCHAR(60),
    STATE                           CHAR(3),
    POSTCODE                        CHAR(4),
    PROPERTY_TYPE_CODE              CHAR(2),
    PROPERTY_TYPE_DESC              VARCHAR(40),
    LAND_AREA_SQM                   DECIMAL(10,2),
    FLOOR_AREA_SQM                  DECIMAL(10,2),
    BEDROOMS                        INTEGER,
    BATHROOMS                       DECIMAL(3,1),
    CAR_SPACES                      INTEGER,
    YEAR_BUILT                      INTEGER,
    ZONING_CODE                     VARCHAR(20),
    COUNCIL_AREA                    VARCHAR(60),
    TITLE_REFERENCE                 VARCHAR(40),
    LOT_NUMBER                      VARCHAR(20),
    PLAN_NUMBER                     VARCHAR(20),
    STRATA_FLAG                     CHAR(1),
    HERITAGE_LISTED                 CHAR(1),
    ORIG_VALUATION_DATE             DATE,
    ORIG_VALUATION_AMOUNT           DECIMAL(15,2),
    ORIG_VALUATION_METHOD           VARCHAR(20),
    ORIG_VALUER_NAME                VARCHAR(80),
    CURRENT_VALUATION_DATE          DATE,
    CURRENT_VALUATION_AMOUNT        DECIMAL(15,2),
    CURRENT_VALUATION_METHOD        VARCHAR(20),
    ESTIMATED_LVR                   DECIMAL(6,3),
    FLOOD_RISK_ZONE                 VARCHAR(10),
    FIRE_RISK_ZONE                  VARCHAR(10),
    ENVIRONMENTAL_CONSTRAINT        CHAR(1),
    PROPERTY_STATUS                 VARCHAR(20),
    RECORD_CREATED_DATE             DATE,
    RECORD_LAST_UPDATED             DATE,
    stg_load_timestamp              TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
)
PRIMARY INDEX (PROPERTY_ID);

COMMENT ON TABLE MortgagePlatform_Staging.STG_Property_Valuation IS
    'Staging: Collateral Management System property and valuation records. One record per property. Source system: Valuation/Collateral Management. Maps to domain entities: Property, PropertyValuation, PropertyRisk. Synthetic data generated with Australian property attributes.';

COMMENT ON COLUMN MortgagePlatform_Staging.STG_Property_Valuation.PROPERTY_ID IS 'Bank-assigned unique property identifier. Format: PROP-XXXXXXXX. Primary key in collateral system.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Property_Valuation.ORIG_VALUATION_AMOUNT IS 'Formal valuation amount at loan origination in AUD. Should reconcile with ORIG_UPB/ORIG_LTV from STG_Freddie_Origination within rounding tolerance.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Property_Valuation.CURRENT_VALUATION_AMOUNT IS 'Most recent valuation — typically an AVM refresh. Used to calculate ESTIMATED_LVR. Critical for portfolio risk assessment.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Property_Valuation.ESTIMATED_LVR IS 'Derived field: CURRENT_VALUATION_AMOUNT divided into current UPB from servicing system. High LVR (>80%) indicates negative or near-negative equity risk.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Property_Valuation.FLOOD_RISK_ZONE IS 'Flood risk classification from council/government flood mapping. Low, Medium, High, Overland Flow. Used in APRA risk-weighted asset calculations.';
COMMENT ON COLUMN MortgagePlatform_Staging.STG_Property_Valuation.FIRE_RISK_ZONE IS 'Bushfire risk classification. Low, Medium, High, Extreme. Extreme-rated properties may attract higher insurance requirements.';
