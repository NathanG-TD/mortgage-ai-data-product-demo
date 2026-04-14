-- =============================================================================
-- 00_create_bureau_staging_table.sql
-- Create staging table for the withheld Credit Bureau Feed source.
--
-- Run this BEFORE the demo (during environment setup) so that the load
-- during Act 2 is instant. Do NOT load data until Scenario 2.
-- =============================================================================

CREATE MULTISET TABLE MortgagePlatform_Staging.STG_Credit_Bureau_Feed,
     NO BEFORE JOURNAL, NO AFTER JOURNAL, CHECKSUM = DEFAULT
(
    BUREAU_RECORD_ID            VARCHAR(30)     NOT NULL,
    CUSTOMER_ID                 VARCHAR(20)     NOT NULL,
    BUREAU_ENQUIRY_DATE         DATE            NOT NULL,
    BUREAU_PROVIDER_CODE        CHAR(3),
    CRED_SCORE_CURR             INTEGER,
    CRED_SCORE_PREV             INTEGER,
    CRED_SCORE_CHG              INTEGER,
    CRED_SCORE_BAND             CHAR(2),
    FILE_AGE_MONTHS             INTEGER,
    ENQ_3M                      INTEGER,
    ENQ_6M                      INTEGER,
    ENQ_12M                     INTEGER,
    ENQ_MORTGAGE_3M             INTEGER,
    TOTAL_ACCOUNTS              INTEGER,
    OPEN_ACCOUNTS               INTEGER,
    CREDIT_LIMIT_TOTAL          DECIMAL(15,2),
    CREDIT_BALANCE_TOTAL        DECIMAL(15,2),
    CREDIT_UTIL_RATIO           DECIMAL(5,4),
    MORTGAGE_BALANCE_TOTAL      DECIMAL(15,2),
    NUM_DEFAULTS                INTEGER,
    DEFAULT_AMT_TOTAL           DECIMAL(15,2),
    NUM_JUDGEMENTS              INTEGER,
    JUDGEMENT_AMT_TOTAL         DECIMAL(15,2),
    BANKRUPTCY_FLAG             CHAR(1),
    BANKRUPTCY_DATE             DATE,
    PART_IX_FLAG                CHAR(1),
    SERIOUS_CREDIT_IMPAIRMENT   CHAR(1),
    REPMT_HIST_SCORE            INTEGER,
    DEROG_MARKS                 INTEGER,
    CREDIT_ACTIVE_SINCE         DATE,
    BUREAU_REFRESH_DATE         DATE,
    DATA_SUPPLIER_CODE          VARCHAR(10)
)
PRIMARY INDEX (CUSTOMER_ID, BUREAU_ENQUIRY_DATE);

COMMENT ON TABLE MortgagePlatform_Staging.STG_Credit_Bureau_Feed IS
    'Staging: External Credit Bureau API extract. One record per customer per bureau refresh date. Source system: Equifax/Illion bureau feed.';

--COMMENT ON COLUMN MortgagePlatform_Staging.STG_Credit_Bureau_Feed.CRED_SCORE_CURR IS 'Current credit score on Equifax 0-1200 scale. IMPORTANT: This is NOT comparable to CREDIT_SCORE in STG_Freddie_Origination which uses the FICO 300-850 scale. Bands: Excellent 833+, Very Good 726-832, Good 622-725, Average 510-621, Below Average <510.';
--COMMENT ON COLUMN MortgagePlatform_Staging.STG_Credit_Bureau_Feed.CRED_SCORE_CHG IS 'Change in credit score since last bureau refresh. Negative values indicate credit deterioration. Drop > 50 points in one period is a significant fraud/stress signal.';
--COMMENT ON COLUMN MortgagePlatform_Staging.STG_Credit_Bureau_Feed.ENQ_3M IS 'Number of credit enquiries in the past 3 months across all credit types. High values (>5) combined with derogatory marks indicate financial stress or potential fraud.';
--COMMENT ON COLUMN MortgagePlatform_Staging.STG_Credit_Bureau_Feed.SERIOUS_CREDIT_IMPAIRMENT IS 'Y if one or more serious credit impairments exist on file (defaults, judgements, bankruptcy). Regulated attribute — triggers mandatory review process under APRA guidelines.';
--COMMENT ON COLUMN MortgagePlatform_Staging.STG_Credit_Bureau_Feed.BANKRUPTCY_FLAG IS 'Y if bankruptcy recorded on the credit file. Regulated attribute — strict access controls and audit trail required.';
--COMMENT ON COLUMN MortgagePlatform_Staging.STG_Credit_Bureau_Feed.PART_IX_FLAG IS 'Y if a Part IX debt agreement is recorded (Australian Bankruptcy Act instrument allowing debt restructuring without formal bankruptcy). Regulated attribute.';
--COMMENT ON COLUMN MortgagePlatform_Staging.STG_Credit_Bureau_Feed.REPMT_HIST_SCORE IS 'Bureau proprietary repayment history score 0-100. Higher = more consistent repayment. NOT comparable across bureau providers.';
--COMMENT ON COLUMN MortgagePlatform_Staging.STG_Credit_Bureau_Feed.CREDIT_UTIL_RATIO IS 'Credit utilisation ratio: total balance / total limit across revolving facilities. High utilisation (>0.80) is a churn and credit stress indicator.';
