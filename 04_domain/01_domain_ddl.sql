-- =============================================================================
-- 01_domain_ddl.sql
-- MortgagePlatform_Domain — Entity DDL
--
-- BIAN Service Domain alignment:
--   Section 1: Reference Tables (shared across domains)
--   Section 2: BIAN — Mortgage Loan Application
--   Section 3: BIAN — Mortgage Loan
--   Sections 4-9: Party, Customer, Collateral, Payment, Statement (future)
--
-- Keymap pattern: surrogate IDENTITY lives in {Entity}_Keymap only.
--   History tables hold {entity}_key BIGINT NOT NULL, populated via keymap join.
--   All cross-entity FKs reference the keymap surrogate, never _H rows directly.
--
-- Temporal strategies:
--   Type 2 SCD (_H)      : LoanApplication, Loan
--   Append-only snapshot : LoanPerformance (one row per loan per month)
--   Append-only event    : LoanEvent, LoanModification
--   Reference (_R)       : LoanPurpose, OriginationChannel, AmortizationType,
--                          OccupancyStatus, DelinquencyStatus, ZeroBalanceCode
-- =============================================================================


-- =============================================================================
-- SECTION 1: REFERENCE TABLES
-- =============================================================================

CREATE TABLE MortgagePlatform_Domain.LoanPurpose_R (
    loan_purpose_key  BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    loan_purpose_cd   CHAR(1)       CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    loan_purpose_nm   VARCHAR(60)   CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    loan_purpose_desc VARCHAR(200)  CHARACTER SET LATIN NOT CASESPECIFIC,
    sort_order        SMALLINT,
    is_active         BYTEINT NOT NULL DEFAULT 1
) UNIQUE PRIMARY INDEX (loan_purpose_cd);

COMMENT ON TABLE  MortgagePlatform_Domain.LoanPurpose_R IS 'Reference: loan purpose codes. Source: Freddie Mac LOAN_PURPOSE. P=Purchase, C=Cash-out Refinance, N=No Cash-out Refinance, U=Unknown.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPurpose_R.loan_purpose_key  IS 'Surrogate key - system-generated identity';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPurpose_R.loan_purpose_cd   IS 'Code value stored in transactional tables - single character per Freddie Mac spec';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPurpose_R.loan_purpose_nm   IS 'Short human-readable name for display and reporting';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPurpose_R.loan_purpose_desc IS 'Full business description of the loan purpose category';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPurpose_R.sort_order        IS 'Display sort order for UI and reports';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPurpose_R.is_active         IS '1=active code in use; 0=deprecated, retain for historical decode only';

INSERT INTO MortgagePlatform_Domain.LoanPurpose_R (loan_purpose_cd, loan_purpose_nm, loan_purpose_desc, sort_order, is_active) VALUES ('P', 'Purchase',              'New property purchase - first mortgage on the security', 1, 1);
INSERT INTO MortgagePlatform_Domain.LoanPurpose_R (loan_purpose_cd, loan_purpose_nm, loan_purpose_desc, sort_order, is_active) VALUES ('C', 'Cash-out Refinance',    'Refinance with net cash proceeds to the borrower', 2, 1);
INSERT INTO MortgagePlatform_Domain.LoanPurpose_R (loan_purpose_cd, loan_purpose_nm, loan_purpose_desc, sort_order, is_active) VALUES ('N', 'No Cash-out Refinance', 'Refinance with no net cash to borrower; rate/term change only', 3, 1);
INSERT INTO MortgagePlatform_Domain.LoanPurpose_R (loan_purpose_cd, loan_purpose_nm, loan_purpose_desc, sort_order, is_active) VALUES ('U', 'Unknown',               'Loan purpose not disclosed or not available', 4, 1);


CREATE TABLE MortgagePlatform_Domain.OriginationChannel_R (
    origination_channel_key BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    channel_cd              CHAR(1)      CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    channel_nm              VARCHAR(60)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    channel_desc            VARCHAR(300) CHARACTER SET LATIN NOT CASESPECIFIC,
    sort_order              SMALLINT,
    is_active               BYTEINT NOT NULL DEFAULT 1
) UNIQUE PRIMARY INDEX (channel_cd);

COMMENT ON TABLE  MortgagePlatform_Domain.OriginationChannel_R IS 'Reference: origination channel codes. Source: Freddie Mac CHANNEL. R=Retail, B=Broker, C=Correspondent, T=TPO Not Specified.';
COMMENT ON COLUMN MortgagePlatform_Domain.OriginationChannel_R.origination_channel_key IS 'Surrogate key - system-generated identity';
COMMENT ON COLUMN MortgagePlatform_Domain.OriginationChannel_R.channel_cd              IS 'Code value: R=Retail, B=Broker, C=Correspondent, T=TPO Not Specified';
COMMENT ON COLUMN MortgagePlatform_Domain.OriginationChannel_R.channel_nm              IS 'Short name for the origination channel';
COMMENT ON COLUMN MortgagePlatform_Domain.OriginationChannel_R.channel_desc            IS 'Full description of how loans are sourced through this channel';
COMMENT ON COLUMN MortgagePlatform_Domain.OriginationChannel_R.sort_order              IS 'Display sort order';
COMMENT ON COLUMN MortgagePlatform_Domain.OriginationChannel_R.is_active               IS '1=active channel; 0=deprecated';

INSERT INTO MortgagePlatform_Domain.OriginationChannel_R (channel_cd, channel_nm, channel_desc, sort_order, is_active) VALUES ('R', 'Retail',            'Loan originated directly by the lender through its own retail network', 1, 1);
INSERT INTO MortgagePlatform_Domain.OriginationChannel_R (channel_cd, channel_nm, channel_desc, sort_order, is_active) VALUES ('B', 'Broker',            'Loan originated by a third-party broker and funded by the lender', 2, 1);
INSERT INTO MortgagePlatform_Domain.OriginationChannel_R (channel_cd, channel_nm, channel_desc, sort_order, is_active) VALUES ('C', 'Correspondent',     'Loan originated and initially funded by a correspondent lender, then sold', 3, 1);
INSERT INTO MortgagePlatform_Domain.OriginationChannel_R (channel_cd, channel_nm, channel_desc, sort_order, is_active) VALUES ('T', 'TPO Not Specified', 'Third-party origination - specific channel not disclosed', 4, 1);


CREATE TABLE MortgagePlatform_Domain.AmortizationType_R (
    amortization_type_key  BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    amortization_type_cd   VARCHAR(5)   CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    amortization_type_nm   VARCHAR(60)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    amortization_type_desc VARCHAR(300) CHARACTER SET LATIN NOT CASESPECIFIC,
    is_active              BYTEINT NOT NULL DEFAULT 1
) UNIQUE PRIMARY INDEX (amortization_type_cd);

COMMENT ON TABLE  MortgagePlatform_Domain.AmortizationType_R IS 'Reference: loan amortisation type codes. Source: Freddie Mac AMORTIZATION_TYPE. FRM=Fixed Rate, ARM=Adjustable Rate.';
COMMENT ON COLUMN MortgagePlatform_Domain.AmortizationType_R.amortization_type_key  IS 'Surrogate key - system-generated identity';
COMMENT ON COLUMN MortgagePlatform_Domain.AmortizationType_R.amortization_type_cd   IS 'Code value: FRM=Fixed Rate Mortgage, ARM=Adjustable Rate Mortgage';
COMMENT ON COLUMN MortgagePlatform_Domain.AmortizationType_R.amortization_type_nm   IS 'Short display name';
COMMENT ON COLUMN MortgagePlatform_Domain.AmortizationType_R.amortization_type_desc IS 'Full description of amortisation behaviour';
COMMENT ON COLUMN MortgagePlatform_Domain.AmortizationType_R.is_active              IS '1=active; 0=deprecated';

INSERT INTO MortgagePlatform_Domain.AmortizationType_R (amortization_type_cd, amortization_type_nm, amortization_type_desc, is_active) VALUES ('FRM', 'Fixed Rate Mortgage',      'Interest rate is fixed for the full loan term; repayments are constant', 1);
INSERT INTO MortgagePlatform_Domain.AmortizationType_R (amortization_type_cd, amortization_type_nm, amortization_type_desc, is_active) VALUES ('ARM', 'Adjustable Rate Mortgage', 'Interest rate resets periodically based on an index; repayments may vary', 1);


CREATE TABLE MortgagePlatform_Domain.OccupancyStatus_R (
    occupancy_status_key  BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    occupancy_status_cd   CHAR(1)      CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    occupancy_status_nm   VARCHAR(60)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    occupancy_status_desc VARCHAR(300) CHARACTER SET LATIN NOT CASESPECIFIC,
    sort_order            SMALLINT,
    is_active             BYTEINT NOT NULL DEFAULT 1
) UNIQUE PRIMARY INDEX (occupancy_status_cd);

COMMENT ON TABLE  MortgagePlatform_Domain.OccupancyStatus_R IS 'Reference: property occupancy status at origination. Source: Freddie Mac OCCUPANCY_STATUS. P=Primary, S=Second Home, I=Investment.';
COMMENT ON COLUMN MortgagePlatform_Domain.OccupancyStatus_R.occupancy_status_key  IS 'Surrogate key - system-generated identity';
COMMENT ON COLUMN MortgagePlatform_Domain.OccupancyStatus_R.occupancy_status_cd   IS 'Code value: P=Primary Residence, S=Second Home, I=Investment Property';
COMMENT ON COLUMN MortgagePlatform_Domain.OccupancyStatus_R.occupancy_status_nm   IS 'Short display name';
COMMENT ON COLUMN MortgagePlatform_Domain.OccupancyStatus_R.occupancy_status_desc IS 'Full description; affects risk weighting under APRA APS112';
COMMENT ON COLUMN MortgagePlatform_Domain.OccupancyStatus_R.sort_order            IS 'Display sort order';
COMMENT ON COLUMN MortgagePlatform_Domain.OccupancyStatus_R.is_active             IS '1=active; 0=deprecated';

INSERT INTO MortgagePlatform_Domain.OccupancyStatus_R (occupancy_status_cd, occupancy_status_nm, occupancy_status_desc, sort_order, is_active) VALUES ('P', 'Primary Residence',  'Borrower occupies the property as their principal place of residence', 1, 1);
INSERT INTO MortgagePlatform_Domain.OccupancyStatus_R (occupancy_status_cd, occupancy_status_nm, occupancy_status_desc, sort_order, is_active) VALUES ('S', 'Second Home',        'Borrower occupies the property seasonally; not rented commercially', 2, 1);
INSERT INTO MortgagePlatform_Domain.OccupancyStatus_R (occupancy_status_cd, occupancy_status_nm, occupancy_status_desc, sort_order, is_active) VALUES ('I', 'Investment Property', 'Property is rented or held for investment; higher risk weight applies', 3, 1);


CREATE TABLE MortgagePlatform_Domain.DelinquencyStatus_R (
    delinquency_status_key BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    delinquency_status_cd  VARCHAR(3)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    delinquency_status_nm  VARCHAR(60) CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    days_past_due_min      SMALLINT,
    days_past_due_max      SMALLINT,
    is_performing          BYTEINT NOT NULL DEFAULT 1,
    sort_order             SMALLINT,
    is_active              BYTEINT NOT NULL DEFAULT 1
) UNIQUE PRIMARY INDEX (delinquency_status_cd);

COMMENT ON TABLE  MortgagePlatform_Domain.DelinquencyStatus_R IS 'Reference: delinquency status codes. Source: Freddie Mac CURRENT_LOAN_DELINQUENCY_STATUS. 0=Current, 1-6=months past due, RA=REO Acquisition.';
COMMENT ON COLUMN MortgagePlatform_Domain.DelinquencyStatus_R.delinquency_status_key IS 'Surrogate key - system-generated identity';
COMMENT ON COLUMN MortgagePlatform_Domain.DelinquencyStatus_R.delinquency_status_cd  IS 'Code: 0=Current, 1=30dpd, 2=60dpd, 3=90dpd, 4=120dpd, 5=150dpd, 6=180dpd+, RA=REO Acquisition';
COMMENT ON COLUMN MortgagePlatform_Domain.DelinquencyStatus_R.delinquency_status_nm  IS 'Short display name for reporting';
COMMENT ON COLUMN MortgagePlatform_Domain.DelinquencyStatus_R.days_past_due_min      IS 'Minimum days past due for this bucket (null for code 0 and RA)';
COMMENT ON COLUMN MortgagePlatform_Domain.DelinquencyStatus_R.days_past_due_max      IS 'Maximum days past due for this bucket (null for code 6+ and RA)';
COMMENT ON COLUMN MortgagePlatform_Domain.DelinquencyStatus_R.is_performing          IS '1=performing (0-60dpd); 0=non-performing (90dpd+ or REO); used in portfolio risk reports';
COMMENT ON COLUMN MortgagePlatform_Domain.DelinquencyStatus_R.sort_order             IS 'Severity sort order - lower is better';
COMMENT ON COLUMN MortgagePlatform_Domain.DelinquencyStatus_R.is_active              IS '1=active code; 0=deprecated';

INSERT INTO MortgagePlatform_Domain.DelinquencyStatus_R (delinquency_status_cd, delinquency_status_nm, days_past_due_min, days_past_due_max, is_performing, sort_order, is_active) VALUES ('0',  'Current',           0,    0,   1, 1, 1);
INSERT INTO MortgagePlatform_Domain.DelinquencyStatus_R (delinquency_status_cd, delinquency_status_nm, days_past_due_min, days_past_due_max, is_performing, sort_order, is_active) VALUES ('1',  '30 Days Past Due',  1,   59,   1, 2, 1);
INSERT INTO MortgagePlatform_Domain.DelinquencyStatus_R (delinquency_status_cd, delinquency_status_nm, days_past_due_min, days_past_due_max, is_performing, sort_order, is_active) VALUES ('2',  '60 Days Past Due',  60,  89,   1, 3, 1);
INSERT INTO MortgagePlatform_Domain.DelinquencyStatus_R (delinquency_status_cd, delinquency_status_nm, days_past_due_min, days_past_due_max, is_performing, sort_order, is_active) VALUES ('3',  '90 Days Past Due',  90, 119,   0, 4, 1);
INSERT INTO MortgagePlatform_Domain.DelinquencyStatus_R (delinquency_status_cd, delinquency_status_nm, days_past_due_min, days_past_due_max, is_performing, sort_order, is_active) VALUES ('4',  '120 Days Past Due', 120, 149,  0, 5, 1);
INSERT INTO MortgagePlatform_Domain.DelinquencyStatus_R (delinquency_status_cd, delinquency_status_nm, days_past_due_min, days_past_due_max, is_performing, sort_order, is_active) VALUES ('5',  '150 Days Past Due', 150, 179,  0, 6, 1);
INSERT INTO MortgagePlatform_Domain.DelinquencyStatus_R (delinquency_status_cd, delinquency_status_nm, days_past_due_min, days_past_due_max, is_performing, sort_order, is_active) VALUES ('6',  '180+ Days Past Due',180, NULL, 0, 7, 1);
INSERT INTO MortgagePlatform_Domain.DelinquencyStatus_R (delinquency_status_cd, delinquency_status_nm, days_past_due_min, days_past_due_max, is_performing, sort_order, is_active) VALUES ('RA', 'REO Acquisition',  NULL, NULL, 0, 8, 1);


CREATE TABLE MortgagePlatform_Domain.ZeroBalanceCode_R (
    zero_balance_code_key  BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    zero_balance_code_cd   CHAR(2)      CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    zero_balance_code_nm   VARCHAR(60)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    zero_balance_code_desc VARCHAR(300) CHARACTER SET LATIN NOT CASESPECIFIC,
    is_voluntary           BYTEINT NOT NULL DEFAULT 0,
    is_distressed          BYTEINT NOT NULL DEFAULT 0,
    sort_order             SMALLINT,
    is_active              BYTEINT NOT NULL DEFAULT 1
) UNIQUE PRIMARY INDEX (zero_balance_code_cd);

COMMENT ON TABLE  MortgagePlatform_Domain.ZeroBalanceCode_R IS 'Reference: zero balance codes from Freddie Mac performance file. Indicates reason a loan reached zero UPB. Key churn signal: 01=voluntary payoff, 02/03/09=distressed exit.';
COMMENT ON COLUMN MortgagePlatform_Domain.ZeroBalanceCode_R.zero_balance_code_key  IS 'Surrogate key - system-generated identity';
COMMENT ON COLUMN MortgagePlatform_Domain.ZeroBalanceCode_R.zero_balance_code_cd   IS 'Two-character Freddie Mac zero balance code';
COMMENT ON COLUMN MortgagePlatform_Domain.ZeroBalanceCode_R.zero_balance_code_nm   IS 'Short name for the zero balance reason';
COMMENT ON COLUMN MortgagePlatform_Domain.ZeroBalanceCode_R.zero_balance_code_desc IS 'Full description of the event that caused the loan balance to reach zero';
COMMENT ON COLUMN MortgagePlatform_Domain.ZeroBalanceCode_R.is_voluntary           IS '1=borrower-initiated payoff (positive outcome); 0=servicer or court-driven';
COMMENT ON COLUMN MortgagePlatform_Domain.ZeroBalanceCode_R.is_distressed          IS '1=default or forced exit; 0=normal loan lifecycle event';
COMMENT ON COLUMN MortgagePlatform_Domain.ZeroBalanceCode_R.sort_order             IS 'Display sort order';
COMMENT ON COLUMN MortgagePlatform_Domain.ZeroBalanceCode_R.is_active              IS '1=active code; 0=deprecated';

INSERT INTO MortgagePlatform_Domain.ZeroBalanceCode_R (zero_balance_code_cd, zero_balance_code_nm, zero_balance_code_desc, is_voluntary, is_distressed, sort_order, is_active) VALUES ('01', 'Prepaid / Matured',       'Loan fully repaid by borrower ahead of or at scheduled maturity', 1, 0, 1, 1);
INSERT INTO MortgagePlatform_Domain.ZeroBalanceCode_R (zero_balance_code_cd, zero_balance_code_nm, zero_balance_code_desc, is_voluntary, is_distressed, sort_order, is_active) VALUES ('02', 'Third Party Sale',        'Property sold to third party at foreclosure auction', 0, 1, 2, 1);
INSERT INTO MortgagePlatform_Domain.ZeroBalanceCode_R (zero_balance_code_cd, zero_balance_code_nm, zero_balance_code_desc, is_voluntary, is_distressed, sort_order, is_active) VALUES ('03', 'Short Sale',              'Property sold for less than outstanding balance with lender approval', 0, 1, 3, 1);
INSERT INTO MortgagePlatform_Domain.ZeroBalanceCode_R (zero_balance_code_cd, zero_balance_code_nm, zero_balance_code_desc, is_voluntary, is_distressed, sort_order, is_active) VALUES ('06', 'Repurchase',              'Loan repurchased by the seller from Freddie Mac', 0, 0, 4, 1);
INSERT INTO MortgagePlatform_Domain.ZeroBalanceCode_R (zero_balance_code_cd, zero_balance_code_nm, zero_balance_code_desc, is_voluntary, is_distressed, sort_order, is_active) VALUES ('09', 'REO Disposition',         'Real estate owned property sold by servicer following foreclosure', 0, 1, 5, 1);
INSERT INTO MortgagePlatform_Domain.ZeroBalanceCode_R (zero_balance_code_cd, zero_balance_code_nm, zero_balance_code_desc, is_voluntary, is_distressed, sort_order, is_active) VALUES ('15', 'Note Sale',               'Loan sold as a non-performing note to a third party', 0, 1, 6, 1);
INSERT INTO MortgagePlatform_Domain.ZeroBalanceCode_R (zero_balance_code_cd, zero_balance_code_nm, zero_balance_code_desc, is_voluntary, is_distressed, sort_order, is_active) VALUES ('16', 'Reperforming Loan Sale',  'Previously delinquent loan sold as reperforming to an investor', 0, 0, 7, 1);


-- =============================================================================
-- SECTION 2: BIAN — MORTGAGE LOAN APPLICATION
-- =============================================================================

-- ---------------------------------------------------------------------------
-- LoanApplication_Keymap
-- One row per unique loan application. IDENTITY lives here only.
-- ---------------------------------------------------------------------------
CREATE TABLE MortgagePlatform_Domain.LoanApplication_Keymap (
    loan_application_key BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    loan_application_id  VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    source_system        VARCHAR(50)  CHARACTER SET LATIN NOT CASESPECIFIC,
    created_dt           TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
) UNIQUE PRIMARY INDEX (loan_application_id);

COMMENT ON TABLE  MortgagePlatform_Domain.LoanApplication_Keymap IS 'Keymap: one row per unique loan application. Surrogate key (IDENTITY) generated here and referenced by LoanApplication_H and cross-domain FKs. Natural key is LOAN_SEQUENCE_NUMBER.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_Keymap.loan_application_key IS 'Surrogate key - generated once, stable across all SCD versions in LoanApplication_H';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_Keymap.loan_application_id  IS 'Natural key - LOAN_SEQUENCE_NUMBER from origination source. Format: FddQqNNNNNN.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_Keymap.source_system        IS 'Source system that originated this natural key';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_Keymap.created_dt           IS 'Timestamp the natural key was first registered in the keymap';


-- ---------------------------------------------------------------------------
-- LoanApplication_H  (Type 2 SCD)
-- BIAN Service Domain: Mortgage Loan Application
-- ---------------------------------------------------------------------------
CREATE TABLE MortgagePlatform_Domain.LoanApplication_H (
    loan_application_key        BIGINT NOT NULL,
    loan_application_id         VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,

    -- FK to Party - populated when Customer domain is deployed
    customer_key                BIGINT,

    -- BIAN: Application Details
    channel_cd                  CHAR(1)       CHARACTER SET LATIN NOT CASESPECIFIC,
    loan_purpose_cd             CHAR(1)       CHARACTER SET LATIN NOT CASESPECIFIC,
    occupancy_status_cd         CHAR(1)       CHARACTER SET LATIN NOT CASESPECIFIC,
    requested_amount            DECIMAL(15,2),
    orig_ltv                    SMALLINT,
    orig_cltv                   SMALLINT,
    orig_dti                    SMALLINT,
    credit_score_at_application SMALLINT,
    number_of_borrowers         SMALLINT,
    first_time_homebuyer_flag   BYTEINT NOT NULL DEFAULT 0,
    number_of_units             SMALLINT,
    mi_percentage               SMALLINT,

    -- BIAN: Program and Scheme
    program_indicator           CHAR(1)  CHARACTER SET LATIN NOT CASESPECIFIC,
    harp_indicator              BYTEINT NOT NULL DEFAULT 0,
    super_conforming_flag       BYTEINT NOT NULL DEFAULT 0,
    pre_relief_refinance_lsn    CHAR(12) CHARACTER SET LATIN NOT CASESPECIFIC,

    -- BIAN: Decision
    application_status          VARCHAR(20) CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL DEFAULT 'APPROVED',
    seller_name                 VARCHAR(60) CHARACTER SET LATIN NOT CASESPECIFIC,

    -- Source tracking
    source_system               VARCHAR(50)  CHARACTER SET LATIN NOT CASESPECIFIC,
    source_key                  VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC,

    -- Temporal (Type 2 SCD)
    valid_from_dt               DATE NOT NULL,
    valid_to_dt                 DATE NOT NULL DEFAULT DATE '9999-12-31',
    is_current                  BYTEINT NOT NULL DEFAULT 1,
    is_deleted                  BYTEINT NOT NULL DEFAULT 0,

    -- Audit
    created_dt                  TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6),
    updated_dt                  TIMESTAMP(6) WITH TIME ZONE
) PRIMARY INDEX (loan_application_key);

COMMENT ON TABLE  MortgagePlatform_Domain.LoanApplication_H IS 'BIAN: Mortgage Loan Application. Type 2 SCD capturing application attributes at origination. All records in this dataset are approved/funded applications. Use LoanApplication_Current view for current records. Source: STG_Freddie_Origination.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.loan_application_key        IS 'Surrogate key from LoanApplication_Keymap - stable across all SCD versions for the same application';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.loan_application_id         IS 'Natural key - LOAN_SEQUENCE_NUMBER; same value across all history versions';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.customer_key                IS 'FK to Customer_Keymap.customer_key - populated when Party domain is deployed; null until then';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.channel_cd                  IS 'Origination channel - FK to OriginationChannel_R. R=Retail, B=Broker, C=Correspondent, T=TPO';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.loan_purpose_cd             IS 'Loan purpose - FK to LoanPurpose_R. P=Purchase, C=Cash-out Refi, N=No Cash-out Refi';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.occupancy_status_cd         IS 'Intended occupancy - FK to OccupancyStatus_R. P=Primary, S=Second Home, I=Investment';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.requested_amount            IS 'Original unpaid principal balance - face amount at origination in AUD. Range 17K-1.64M in dataset.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.orig_ltv                    IS 'Original Loan-to-Value ratio (%). Loan amount divided by appraised property value. Range 5-134 in dataset.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.orig_cltv                   IS 'Combined LTV (%) - sum of all mortgage liens divided by property value. >= orig_ltv when subordinate liens exist.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.orig_dti                    IS 'Debt-to-Income ratio (%) at origination - monthly debt obligations divided by gross monthly income.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.credit_score_at_application IS 'Borrower FICO credit score at origination (scale 300-850). For multi-borrower loans: representative score per Freddie Mac guidelines.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.number_of_borrowers         IS 'Number of borrowers on the loan. 1=single, 2+=co-borrowers present.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.first_time_homebuyer_flag   IS '1=first-time homebuyer; 0=not first-time. Mapped from Freddie Mac Y/N/9 (9 treated as 0).';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.number_of_units             IS 'Dwelling units in the mortgaged property. 1=single family, 2/3/4=multi-unit.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.mi_percentage               IS 'Mortgage Insurance coverage percentage. 0 if no MI. Range 1-55.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.program_indicator           IS 'Affordable lending program. H=Home Possible. Null=standard loan.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.harp_indicator              IS '1=HARP (Home Affordable Refinance Program) loan; 0=standard.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.super_conforming_flag       IS '1=super-conforming mortgage (above standard conforming limit); 0=standard conforming.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.pre_relief_refinance_lsn    IS 'LOAN_SEQUENCE_NUMBER of the prior loan if this is a Relief Refinance. Null otherwise.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.application_status          IS 'Decision outcome. APPROVED for all records in this dataset (funded loans only).';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.seller_name                 IS 'Name of the entity that sold the loan to Freddie Mac.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.valid_from_dt               IS 'Date this version became effective - set to FIRST_PAYMENT_DATE minus one month (proxy for settlement date).';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.valid_to_dt                 IS 'Date this version was superseded; 9999-12-31 = currently active version.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.is_current                  IS '1=current active version; use LoanApplication_Current view to filter.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.is_deleted                  IS '1=soft-deleted; always filter WHERE is_deleted = 0 for active records.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.source_system               IS 'Source system that provided this record version.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.source_key                  IS 'Natural key as it appeared in the source system.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.created_dt                  IS 'Timestamp this row was inserted into the domain table.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanApplication_H.updated_dt                  IS 'Timestamp this row was last modified (e.g. soft-delete or correction).';


REPLACE VIEW MortgagePlatform_Domain.LoanApplication_Current AS
SELECT * FROM MortgagePlatform_Domain.LoanApplication_H
WHERE is_current = 1 AND is_deleted = 0;
COMMENT ON VIEW MortgagePlatform_Domain.LoanApplication_Current IS 'Current active loan applications - is_current=1 and is_deleted=0. Use for standard reporting and joins.';

REPLACE VIEW MortgagePlatform_Domain.LoanApplication_Enriched AS
SELECT
    a.*,
    ch.channel_nm          AS channel_name,
    lp.loan_purpose_nm     AS loan_purpose_name,
    os.occupancy_status_nm AS occupancy_status_name
FROM MortgagePlatform_Domain.LoanApplication_Current a
LEFT JOIN MortgagePlatform_Domain.OriginationChannel_R ch ON ch.channel_cd         = a.channel_cd
LEFT JOIN MortgagePlatform_Domain.LoanPurpose_R        lp ON lp.loan_purpose_cd    = a.loan_purpose_cd
LEFT JOIN MortgagePlatform_Domain.OccupancyStatus_R    os ON os.occupancy_status_cd = a.occupancy_status_cd;
COMMENT ON VIEW MortgagePlatform_Domain.LoanApplication_Enriched IS 'Enriched loan application view - current records with decoded channel, loan purpose and occupancy status.';


-- =============================================================================
-- SECTION 3: BIAN — MORTGAGE LOAN
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Loan_Keymap
-- ---------------------------------------------------------------------------
CREATE TABLE MortgagePlatform_Domain.Loan_Keymap (
    loan_key      BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    loan_id       VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    source_system VARCHAR(50)  CHARACTER SET LATIN NOT CASESPECIFIC,
    created_dt    TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
) UNIQUE PRIMARY INDEX (loan_id);

COMMENT ON TABLE  MortgagePlatform_Domain.Loan_Keymap IS 'Keymap: one row per unique funded mortgage loan. Surrogate key (IDENTITY) generated here and referenced by Loan_H, LoanPerformance_H, LoanEvent_H, LoanModification_H, and all cross-domain FKs. Natural key is LOAN_SEQUENCE_NUMBER.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_Keymap.loan_key      IS 'Surrogate key - generated once per loan, stable across all SCD versions and all child tables';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_Keymap.loan_id       IS 'Natural key - LOAN_SEQUENCE_NUMBER. Format: FddQqNNNNNN where dd=vintage year, Q=quarter.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_Keymap.source_system IS 'Source system that originated this loan record';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_Keymap.created_dt    IS 'Timestamp the loan natural key was first registered in the keymap';


-- ---------------------------------------------------------------------------
-- Loan_H  (Type 2 SCD)
-- BIAN Service Domain: Mortgage Loan
-- ---------------------------------------------------------------------------
CREATE TABLE MortgagePlatform_Domain.Loan_H (
    loan_key                  BIGINT NOT NULL,
    loan_id                   VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,

    -- Cross-domain FKs (populated progressively as domains are deployed)
    loan_application_key      BIGINT,
    customer_key              BIGINT,
    property_key              BIGINT,

    -- BIAN: Loan Facility
    orig_upb                  DECIMAL(15,2) NOT NULL,
    orig_interest_rate        DECIMAL(6,3),
    orig_loan_term_months     SMALLINT,
    amortization_type_cd      VARCHAR(5) CHARACTER SET LATIN NOT CASESPECIFIC,
    maturity_dt               DATE,
    first_payment_dt          DATE,
    interest_only_indicator   BYTEINT NOT NULL DEFAULT 0,
    ppm_flag                  BYTEINT NOT NULL DEFAULT 0,

    -- BIAN: Property (denormalised for direct loan-level queries)
    number_of_units           SMALLINT,
    property_type_cd          CHAR(2) CHARACTER SET LATIN NOT CASESPECIFIC,
    property_state            CHAR(3) CHARACTER SET LATIN NOT CASESPECIFIC,
    property_postal_code      CHAR(5) CHARACTER SET LATIN NOT CASESPECIFIC,

    -- BIAN: Servicer
    servicer_name             VARCHAR(60) CHARACTER SET LATIN NOT CASESPECIFIC,

    -- BIAN: Loan Status
    loan_status               VARCHAR(20) CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL DEFAULT 'ACTIVE',
    zero_balance_code_cd      CHAR(2) CHARACTER SET LATIN NOT CASESPECIFIC,
    zero_balance_effective_dt DATE,

    -- Source tracking
    source_system             VARCHAR(50)  CHARACTER SET LATIN NOT CASESPECIFIC,
    source_key                VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC,

    -- Temporal (Type 2 SCD)
    valid_from_dt             DATE NOT NULL,
    valid_to_dt               DATE NOT NULL DEFAULT DATE '9999-12-31',
    is_current                BYTEINT NOT NULL DEFAULT 1,
    is_deleted                BYTEINT NOT NULL DEFAULT 0,

    -- Audit
    created_dt                TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6),
    updated_dt                TIMESTAMP(6) WITH TIME ZONE
) PRIMARY INDEX (loan_key);

COMMENT ON TABLE  MortgagePlatform_Domain.Loan_H IS 'BIAN: Mortgage Loan - the funded mortgage facility. Central entity of the domain model; all other tables reference loan_key. Type 2 SCD; use Loan_Current view for current records. Source: STG_Freddie_Origination (initial load) + STG_Freddie_Performance (status updates).';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.loan_key                  IS 'Surrogate key from Loan_Keymap - stable across all SCD versions for the same loan';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.loan_id                   IS 'Natural key - LOAN_SEQUENCE_NUMBER from Freddie Mac; same across all history versions';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.loan_application_key      IS 'FK to LoanApplication_Keymap - links loan to its originating application';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.customer_key              IS 'FK to Customer_Keymap - populated when Party domain is deployed; null until then';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.property_key              IS 'FK to Property_Keymap - populated when Collateral domain is deployed; null until then';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.orig_upb                  IS 'Original unpaid principal balance - face amount at origination in AUD. Range 17K-1.64M in dataset.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.orig_interest_rate        IS 'Original note interest rate (%). Range 3.250-8.875% in dataset. Fixed for FRM; initial rate for ARM.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.orig_loan_term_months     IS 'Original loan term in months. 360=30yr, 180=15yr. Range 96-360 in dataset.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.amortization_type_cd      IS 'Amortisation type - FK to AmortizationType_R. FRM=Fixed Rate, ARM=Adjustable Rate.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.maturity_dt               IS 'Scheduled maturity date - first day of the maturity month. Derived from MATURITY_DATE YYYYMM.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.first_payment_dt          IS 'Date of first scheduled payment - first day of FIRST_PAYMENT_DATE month. Proxy for settlement date.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.interest_only_indicator   IS '1=interest-only period applies; 0=fully amortising from inception.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.ppm_flag                  IS '1=prepayment penalty mortgage; 0=no prepayment penalty.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.number_of_units           IS 'Dwelling units in the property. 1=single family, 2/3/4=multi-unit. Denormalised for direct loan queries.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.property_type_cd          IS 'Property type at origination. SF=Single Family, CO=Condominium, PU=PUD, MH=Manufactured Home.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.property_state            IS 'Australian state of the mortgaged property. NSW, VIC, QLD, SA, WA, TAS, ACT, NT.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.property_postal_code      IS 'Postcode of the property. Australian 4-digit postcode (adapted from Freddie Mac 3-digit prefix).';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.servicer_name             IS 'Name of the entity currently servicing the loan.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.loan_status               IS 'Lifecycle status: ACTIVE=performing or delinquent, CLOSED=zero balance reached, TRANSFERRED=servicer change.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.zero_balance_code_cd      IS 'FK to ZeroBalanceCode_R - reason loan reached zero balance. Null while loan_status=ACTIVE.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.zero_balance_effective_dt IS 'Date the loan balance reached zero. Null while loan_status=ACTIVE.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.valid_from_dt             IS 'Date this version became effective - first_payment_dt for initial version.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.valid_to_dt               IS 'Date this version was superseded; 9999-12-31 = currently active version.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.is_current                IS '1=current active version; use Loan_Current view to filter.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.is_deleted                IS '1=soft-deleted; always filter WHERE is_deleted = 0 for active records.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.source_system             IS 'Source system that provided this record version.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.source_key                IS 'Natural key as it appeared in the source system.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.created_dt                IS 'Timestamp this row was inserted.';
COMMENT ON COLUMN MortgagePlatform_Domain.Loan_H.updated_dt                IS 'Timestamp this row was last modified.';


REPLACE VIEW MortgagePlatform_Domain.Loan_Current AS
SELECT * FROM MortgagePlatform_Domain.Loan_H
WHERE is_current = 1 AND is_deleted = 0;
COMMENT ON VIEW MortgagePlatform_Domain.Loan_Current IS 'Current active loans - is_current=1 and is_deleted=0. Use for standard reporting and joins.';

REPLACE VIEW MortgagePlatform_Domain.Loan_Enriched AS
SELECT
    l.*,
    at2.amortization_type_nm AS amortization_type_name,
    zb.zero_balance_code_nm  AS zero_balance_reason
FROM MortgagePlatform_Domain.Loan_Current l
LEFT JOIN MortgagePlatform_Domain.AmortizationType_R at2 ON at2.amortization_type_cd = l.amortization_type_cd
LEFT JOIN MortgagePlatform_Domain.ZeroBalanceCode_R  zb  ON zb.zero_balance_code_cd  = l.zero_balance_code_cd;
COMMENT ON VIEW MortgagePlatform_Domain.Loan_Enriched IS 'Enriched loan view - current loans with decoded amortisation type and zero balance reason.';


-- ---------------------------------------------------------------------------
-- LoanPerformance_H  (append-only monthly snapshot)
-- BIAN Service Domain: Mortgage Loan (servicing perspective)
-- Grain: loan_key x reporting_period_dt
-- ---------------------------------------------------------------------------
CREATE TABLE MortgagePlatform_Domain.LoanPerformance_H (
    performance_key                   BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    loan_key                          BIGINT NOT NULL,
    reporting_period_dt               DATE NOT NULL,

    -- BIAN: Outstanding Balance
    current_actual_upb                DECIMAL(15,2),
    current_interest_rate             DECIMAL(6,3),
    estimated_ltv                     DECIMAL(6,3),
    current_deferred_upb              DECIMAL(15,2),
    delinquent_accrued_interest       DECIMAL(15,2),

    -- BIAN: Delinquency
    delinquency_status_cd             VARCHAR(3) CHARACTER SET LATIN NOT CASESPECIFIC,
    delinquency_due_to_disaster       BYTEINT NOT NULL DEFAULT 0,
    borrower_assistance_status_cd     CHAR(2)  CHARACTER SET LATIN NOT CASESPECIFIC,

    -- BIAN: Loan Age
    loan_age_months                   SMALLINT,
    remaining_months_to_maturity      SMALLINT,

    -- BIAN: Modification Status
    modification_flag                 BYTEINT NOT NULL DEFAULT 0,
    step_modification_flag            BYTEINT NOT NULL DEFAULT 0,
    deferred_payment_plan             BYTEINT NOT NULL DEFAULT 0,
    modification_cost                 DECIMAL(15,2),
    current_month_modification_cost   DECIMAL(15,2),

    -- BIAN: Loss Accounting
    mi_recoveries                     DECIMAL(15,2),
    net_sales_proceeds                DECIMAL(15,2),
    non_mi_recoveries                 DECIMAL(15,2),
    expenses                          DECIMAL(15,2),
    legal_costs                       DECIMAL(15,2),
    maintenance_preservation_costs    DECIMAL(15,2),
    taxes_and_insurance               DECIMAL(15,2),
    miscellaneous_expenses            DECIMAL(15,2),
    actual_loss_calculation           DECIMAL(15,2),
    repurchase_make_whole_proceeds    DECIMAL(15,2),

    -- Zero balance fields
    zero_balance_code_cd              CHAR(2) CHARACTER SET LATIN NOT CASESPECIFIC,
    zero_balance_effective_dt         DATE,
    zero_balance_removal_upb          DECIMAL(15,2),
    repurchase_dt                     DATE,

    -- Audit
    loaded_dt                         TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
) PRIMARY INDEX (loan_key);

COMMENT ON TABLE  MortgagePlatform_Domain.LoanPerformance_H IS 'BIAN: Mortgage Loan (servicing) - append-only monthly snapshot. One row per loan per reporting month; immutable once inserted. Source: STG_Freddie_Performance. Dataset covers Jan-Sep 2025, 153,382 rows across 37,500 loans.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.performance_key                   IS 'Surrogate key - IDENTITY safe here (append-only; no SCD versioning on snapshots)';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.loan_key                          IS 'FK to Loan_Keymap.loan_key - primary access path; PI on this column co-locates all periods per loan on same AMP';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.reporting_period_dt               IS 'First day of the monthly reporting period. Derived from MONTHLY_REPORTING_PERIOD YYYYMM.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.current_actual_upb                IS 'Unpaid principal balance at end of reporting period. Zero when loan has reached zero balance.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.current_interest_rate             IS 'Interest rate in effect for this period. Differs from orig_interest_rate for ARMs or modified loans.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.estimated_ltv                     IS 'Current estimated LTV based on AVM property value. Used for dynamic risk-weighted asset calculation.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.current_deferred_upb              IS 'Principal deferred under a modification or forbearance arrangement.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.delinquent_accrued_interest       IS 'Accrued interest on the delinquent balance.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.delinquency_status_cd             IS 'FK to DelinquencyStatus_R - monthly delinquency bucket. 0=Current, 1-6=months past due, RA=REO.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.delinquency_due_to_disaster       IS '1=delinquency attributable to a declared natural disaster; 0=standard delinquency.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.borrower_assistance_status_cd     IS 'Active assistance: F=Forbearance, R=Repayment plan, T=Trial period plan, null=None.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.loan_age_months                   IS 'Months since origination as at this reporting period.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.remaining_months_to_maturity      IS 'Remaining months to scheduled maturity as at this reporting period.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.modification_flag                 IS '1=loan was modified during this reporting period; 0=no modification.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.step_modification_flag            IS '1=step-rate modification in effect; 0=standard.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.deferred_payment_plan             IS '1=active deferred payment arrangement; 0=none.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.modification_cost                 IS 'Cumulative cost of all loan modifications as at this period.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.current_month_modification_cost   IS 'Modification cost incurred in this reporting month only.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.mi_recoveries                     IS 'Cumulative mortgage insurance proceeds received.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.net_sales_proceeds                IS 'Net proceeds from property sale - used for loss calculation on defaulted loans.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.non_mi_recoveries                 IS 'Recoveries not from MI - guaranty proceeds, recourse claims.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.expenses                          IS 'Total expenses on defaulted loan (legal + maintenance + taxes + misc).';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.legal_costs                       IS 'Legal and foreclosure fees incurred.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.maintenance_preservation_costs    IS 'Property maintenance and preservation costs post-default.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.taxes_and_insurance               IS 'Property taxes and insurance paid by servicer on behalf of borrower.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.miscellaneous_expenses            IS 'Other expenses not captured in specific cost columns.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.actual_loss_calculation           IS 'Calculated net loss: UPB minus recoveries plus expenses. Key input for AASB9/IFRS9 expected credit loss.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.repurchase_make_whole_proceeds    IS 'Proceeds under a make-whole repurchase when servicer repurchases loan from Freddie Mac.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.zero_balance_code_cd              IS 'FK to ZeroBalanceCode_R - populated in period the loan reached zero balance; null otherwise.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.zero_balance_effective_dt         IS 'Date the loan balance reached zero. Derived from ZERO_BALANCE_EFFECTIVE_DATE YYYYMM.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.zero_balance_removal_upb          IS 'UPB at time of zero balance removal for reperforming loans (code 16).';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.repurchase_dt                     IS 'Date loan was repurchased by seller. Derived from REPURCHASE_DATE YYYYMM.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanPerformance_H.loaded_dt                         IS 'Timestamp this snapshot row was loaded into the domain table.';


REPLACE VIEW MortgagePlatform_Domain.LoanPerformance_Latest AS
SELECT p.*
FROM MortgagePlatform_Domain.LoanPerformance_H p
INNER JOIN (
    SELECT loan_key, MAX(reporting_period_dt) AS max_period
    FROM MortgagePlatform_Domain.LoanPerformance_H
    GROUP BY loan_key
) m ON m.loan_key = p.loan_key AND m.max_period = p.reporting_period_dt;
COMMENT ON VIEW MortgagePlatform_Domain.LoanPerformance_Latest IS 'Most recent monthly performance snapshot per loan - current servicing position. Use for portfolio risk reports and current delinquency dashboards.';


-- ---------------------------------------------------------------------------
-- LoanEvent_H  (append-only event log)
-- ---------------------------------------------------------------------------
CREATE TABLE MortgagePlatform_Domain.LoanEvent_H (
    event_key           BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    loan_key            BIGINT NOT NULL,
    event_type_cd       VARCHAR(40)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    event_dt            DATE NOT NULL,
    reporting_period_dt DATE,
    prior_value         VARCHAR(50)  CHARACTER SET LATIN NOT CASESPECIFIC,
    new_value           VARCHAR(50)  CHARACTER SET LATIN NOT CASESPECIFIC,
    event_description   VARCHAR(500) CHARACTER SET LATIN NOT CASESPECIFIC,
    created_dt          TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
) PRIMARY INDEX (loan_key);

COMMENT ON TABLE  MortgagePlatform_Domain.LoanEvent_H IS 'Append-only event log for discrete loan lifecycle events derived from month-on-month changes in LoanPerformance_H. Immutable once inserted. Supports event-based analytics and data lineage tracing.';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanEvent_H.event_key           IS 'Surrogate key - IDENTITY, unique per event row';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanEvent_H.loan_key            IS 'FK to Loan_Keymap.loan_key - all events for a loan are co-located on the same AMP';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanEvent_H.event_type_cd       IS 'Event type: DELINQUENCY_ESCALATION, DELINQUENCY_CURE, ZERO_BALANCE, MODIFICATION_STARTED, DISASTER_RELIEF_APPLIED, INTEREST_RATE_CHANGE';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanEvent_H.event_dt            IS 'Date the event occurred - first day of the reporting period in which the change was detected';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanEvent_H.reporting_period_dt IS 'Reporting period in which this event was first detected';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanEvent_H.prior_value         IS 'State before the event - e.g. prior delinquency status code or prior interest rate';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanEvent_H.new_value           IS 'State after the event - e.g. new delinquency status code or new interest rate';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanEvent_H.event_description   IS 'Human-readable summary of the event for audit and customer service use';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanEvent_H.created_dt          IS 'Timestamp this event row was inserted';


-- ---------------------------------------------------------------------------
-- LoanModification_H  (append-only event)
-- ---------------------------------------------------------------------------
CREATE TABLE MortgagePlatform_Domain.LoanModification_H (
    modification_key                BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    loan_key                        BIGINT NOT NULL,
    modification_dt                 DATE NOT NULL,
    step_modification               BYTEINT NOT NULL DEFAULT 0,
    deferred_payment_plan           BYTEINT NOT NULL DEFAULT 0,
    borrower_assistance_status_cd   CHAR(2) CHARACTER SET LATIN NOT CASESPECIFIC,
    modification_cost               DECIMAL(15,2),
    current_month_modification_cost DECIMAL(15,2),
    modification_status             VARCHAR(20) CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL DEFAULT 'ACTIVE',
    created_dt                      TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
) PRIMARY INDEX (loan_key);

COMMENT ON TABLE  MortgagePlatform_Domain.LoanModification_H IS 'Append-only: one row per loan modification event. Source: Freddie Mac MODIFICATION_FLAG=Y in performance file. No modifications in current dataset (Jan-Sep 2025); table scaffolded for completeness and bureau feed onboarding (Act 2).';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanModification_H.modification_key                IS 'Surrogate key - IDENTITY, unique per modification event';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanModification_H.loan_key                        IS 'FK to Loan_Keymap.loan_key';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanModification_H.modification_dt                 IS 'Date modification was effective - first day of the reporting period';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanModification_H.step_modification               IS '1=step-rate modification (rate increases in steps over time); 0=standard modification';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanModification_H.deferred_payment_plan           IS '1=principal deferral included in modification terms; 0=none';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanModification_H.borrower_assistance_status_cd   IS 'Assistance type: F=Forbearance, R=Repayment plan, T=Trial period';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanModification_H.modification_cost               IS 'Total cost of this modification event';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanModification_H.current_month_modification_cost IS 'Modification cost allocated to this specific reporting month';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanModification_H.modification_status             IS 'Status: ACTIVE=in effect, COMPLETED=terms met, CANCELLED=rolled back';
COMMENT ON COLUMN MortgagePlatform_Domain.LoanModification_H.created_dt                      IS 'Timestamp this modification record was inserted';

-- =============================================================================
-- SECTION 4: BIAN — PARTY REFERENCE DATA MANAGEMENT
--            BIAN — CUSTOMER PROFILE
--            BIAN — CUSTOMER CREDIT RATING
--
-- Source: MortgagePlatform_Staging.STG_Borrower_Profile (37,500 rows)
--
-- Keymap pattern:
--   Customer_Keymap  — IDENTITY here; all child entities use IDENTITY on _H
--   (CustomerContact, CustomerAddress, CustomerSegment, CustomerFinancial,
--    CustomerCompliance, CustomerInsight are child entities; nothing else
--    FK-references their surrogate keys, so IDENTITY on _H is safe)
--
-- BIAN alignment:
--   Party Reference Data Management  : Customer_H, CustomerContact_H, CustomerAddress_H
--   Customer Profile                 : CustomerSegment_H, CustomerFinancial_H, CustomerInsight_H
--   Customer Credit Rating           : CustomerCompliance_H
-- =============================================================================


-- =============================================================================
-- SECTION 4A: REFERENCE TABLES — Customer
-- =============================================================================

CREATE TABLE MortgagePlatform_Domain.CustomerSegment_R (
    customer_segment_key        BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    segment_cd                  VARCHAR(30)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    segment_nm                  VARCHAR(60)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    segment_desc                VARCHAR(300) CHARACTER SET LATIN NOT CASESPECIFIC,
    wealth_tier_order           SMALLINT,
    relationship_manager_flag   BYTEINT NOT NULL DEFAULT 0,
    sort_order                  SMALLINT,
    is_active                   BYTEINT NOT NULL DEFAULT 1
) UNIQUE PRIMARY INDEX (segment_cd);

COMMENT ON TABLE  MortgagePlatform_Domain.CustomerSegment_R IS 'Reference: CRM customer segment classification. Source: Borrower Profile CUSTOMER_SEGMENT. Used for portfolio segmentation and RM assignment rules.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_R.customer_segment_key      IS 'Surrogate key - system-generated identity';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_R.segment_cd                IS 'Segment code - full-name string matching the source system value (e.g. Mass Market, Affluent)';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_R.segment_nm                IS 'Short display name for reports and dashboards';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_R.segment_desc              IS 'Business description of the customer segment and its qualifying criteria';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_R.wealth_tier_order         IS 'Wealth tier ranking: 1=lowest (Mass Market), 5=highest (Private Banking). Used for ascending wealth sort.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_R.relationship_manager_flag IS '1=a dedicated relationship manager is assigned at this segment tier; 0=self-service or branch only';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_R.sort_order                IS 'Display sort order';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_R.is_active                 IS '1=active segment in use; 0=deprecated';

INSERT INTO MortgagePlatform_Domain.CustomerSegment_R (segment_cd, segment_nm, segment_desc, wealth_tier_order, relationship_manager_flag, sort_order, is_active) VALUES ('Mass Market',      'Mass Market',      'Retail banking customers with standard product holdings and self-service engagement model', 1, 0, 1, 1);
INSERT INTO MortgagePlatform_Domain.CustomerSegment_R (segment_cd, segment_nm, segment_desc, wealth_tier_order, relationship_manager_flag, sort_order, is_active) VALUES ('Emerging Affluent','Emerging Affluent','Customers with growing wealth and income; transitioning to full Affluent tier', 2, 0, 2, 1);
INSERT INTO MortgagePlatform_Domain.CustomerSegment_R (segment_cd, segment_nm, segment_desc, wealth_tier_order, relationship_manager_flag, sort_order, is_active) VALUES ('Affluent',         'Affluent',         'High income or high net worth customers eligible for premium products and RM service', 3, 1, 3, 1);
INSERT INTO MortgagePlatform_Domain.CustomerSegment_R (segment_cd, segment_nm, segment_desc, wealth_tier_order, relationship_manager_flag, sort_order, is_active) VALUES ('Private Banking',  'Private Banking',  'Ultra-high net worth customers receiving bespoke wealth management and private banking services', 4, 1, 4, 1);
INSERT INTO MortgagePlatform_Domain.CustomerSegment_R (segment_cd, segment_nm, segment_desc, wealth_tier_order, relationship_manager_flag, sort_order, is_active) VALUES ('Business Owner',   'Business Owner',   'Small to medium business owners; may have both personal and business banking relationships', 3, 1, 5, 1);


CREATE TABLE MortgagePlatform_Domain.EmploymentStatus_R (
    employment_status_key  BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    employment_status_cd   VARCHAR(30)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    employment_status_nm   VARCHAR(60)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    employment_status_desc VARCHAR(200) CHARACTER SET LATIN NOT CASESPECIFIC,
    is_income_stable       BYTEINT NOT NULL DEFAULT 1,
    sort_order             SMALLINT,
    is_active              BYTEINT NOT NULL DEFAULT 1
) UNIQUE PRIMARY INDEX (employment_status_cd);

COMMENT ON TABLE  MortgagePlatform_Domain.EmploymentStatus_R IS 'Reference: borrower employment status. Source: Borrower Profile EMPLOYMENT_STATUS. Informs income verification requirements and serviceability assessment.';
COMMENT ON COLUMN MortgagePlatform_Domain.EmploymentStatus_R.employment_status_key  IS 'Surrogate key - system-generated identity';
COMMENT ON COLUMN MortgagePlatform_Domain.EmploymentStatus_R.employment_status_cd   IS 'Employment status code - full-name string matching source system value';
COMMENT ON COLUMN MortgagePlatform_Domain.EmploymentStatus_R.employment_status_nm   IS 'Short display name';
COMMENT ON COLUMN MortgagePlatform_Domain.EmploymentStatus_R.employment_status_desc IS 'Business description of this employment status category';
COMMENT ON COLUMN MortgagePlatform_Domain.EmploymentStatus_R.is_income_stable       IS '1=income is regular and verifiable via payslip; 0=variable or irregular income requiring additional assessment';
COMMENT ON COLUMN MortgagePlatform_Domain.EmploymentStatus_R.sort_order             IS 'Display sort order';
COMMENT ON COLUMN MortgagePlatform_Domain.EmploymentStatus_R.is_active              IS '1=active code; 0=deprecated';

INSERT INTO MortgagePlatform_Domain.EmploymentStatus_R (employment_status_cd, employment_status_nm, employment_status_desc, is_income_stable, sort_order, is_active) VALUES ('Full-time',    'Full-time',    'Permanently employed full-time; income verified via payslip or PAYG summary', 1, 1, 1);
INSERT INTO MortgagePlatform_Domain.EmploymentStatus_R (employment_status_cd, employment_status_nm, employment_status_desc, is_income_stable, sort_order, is_active) VALUES ('Part-time',    'Part-time',    'Permanently employed part-time; income verified via payslip; hours may vary', 1, 2, 1);
INSERT INTO MortgagePlatform_Domain.EmploymentStatus_R (employment_status_cd, employment_status_nm, employment_status_desc, is_income_stable, sort_order, is_active) VALUES ('Contractor',   'Contractor',   'Fixed-term or ongoing contract; income verified via contract and tax returns', 0, 3, 1);
INSERT INTO MortgagePlatform_Domain.EmploymentStatus_R (employment_status_cd, employment_status_nm, employment_status_desc, is_income_stable, sort_order, is_active) VALUES ('Self-employed','Self-employed','Business owner or sole trader; income verified via two years tax returns and financials', 0, 4, 1);
INSERT INTO MortgagePlatform_Domain.EmploymentStatus_R (employment_status_cd, employment_status_nm, employment_status_desc, is_income_stable, sort_order, is_active) VALUES ('Retired',      'Retired',      'No active employment; income from superannuation, pension or investments', 1, 5, 1);
INSERT INTO MortgagePlatform_Domain.EmploymentStatus_R (employment_status_cd, employment_status_nm, employment_status_desc, is_income_stable, sort_order, is_active) VALUES ('Unemployed',   'Unemployed',   'Not currently employed; not present in current dataset but included for completeness', 0, 6, 1);


CREATE TABLE MortgagePlatform_Domain.KYCStatus_R (
    kyc_status_key  BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    kyc_status_cd   VARCHAR(20)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    kyc_status_nm   VARCHAR(60)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    kyc_status_desc VARCHAR(300) CHARACTER SET LATIN NOT CASESPECIFIC,
    is_compliant    BYTEINT NOT NULL DEFAULT 0,
    requires_action BYTEINT NOT NULL DEFAULT 0,
    sort_order      SMALLINT,
    is_active       BYTEINT NOT NULL DEFAULT 1
) UNIQUE PRIMARY INDEX (kyc_status_cd);

COMMENT ON TABLE  MortgagePlatform_Domain.KYCStatus_R IS 'Reference: Know Your Customer verification status. Source: Borrower Profile KYC_STATUS. Expired and Pending require remediation under AML/CTF Act obligations.';
COMMENT ON COLUMN MortgagePlatform_Domain.KYCStatus_R.kyc_status_key  IS 'Surrogate key - system-generated identity';
COMMENT ON COLUMN MortgagePlatform_Domain.KYCStatus_R.kyc_status_cd   IS 'KYC status code matching source system value: Verified, Pending, Expired, Failed';
COMMENT ON COLUMN MortgagePlatform_Domain.KYCStatus_R.kyc_status_nm   IS 'Short display name';
COMMENT ON COLUMN MortgagePlatform_Domain.KYCStatus_R.kyc_status_desc IS 'Description of what this KYC status means and its regulatory implications';
COMMENT ON COLUMN MortgagePlatform_Domain.KYCStatus_R.is_compliant    IS '1=customer is KYC-compliant and can transact normally; 0=remediation or restriction may apply';
COMMENT ON COLUMN MortgagePlatform_Domain.KYCStatus_R.requires_action IS '1=compliance team action required to resolve; 0=no action needed';
COMMENT ON COLUMN MortgagePlatform_Domain.KYCStatus_R.sort_order      IS 'Display sort order';
COMMENT ON COLUMN MortgagePlatform_Domain.KYCStatus_R.is_active       IS '1=active status code; 0=deprecated';

INSERT INTO MortgagePlatform_Domain.KYCStatus_R (kyc_status_cd, kyc_status_nm, kyc_status_desc, is_compliant, requires_action, sort_order, is_active) VALUES ('Verified', 'Verified', 'Customer identity verified against acceptable documents; AML/CTF obligations met', 1, 0, 1, 1);
INSERT INTO MortgagePlatform_Domain.KYCStatus_R (kyc_status_cd, kyc_status_nm, kyc_status_desc, is_compliant, requires_action, sort_order, is_active) VALUES ('Pending',  'Pending',  'KYC documents submitted but verification not yet complete; restricted transacting may apply', 0, 1, 2, 1);
INSERT INTO MortgagePlatform_Domain.KYCStatus_R (kyc_status_cd, kyc_status_nm, kyc_status_desc, is_compliant, requires_action, sort_order, is_active) VALUES ('Expired',  'Expired',  'KYC verification has lapsed; re-verification required under periodic review obligations', 0, 1, 3, 1);
INSERT INTO MortgagePlatform_Domain.KYCStatus_R (kyc_status_cd, kyc_status_nm, kyc_status_desc, is_compliant, requires_action, sort_order, is_active) VALUES ('Failed',   'Failed',   'KYC verification failed; customer identity could not be confirmed; escalation required', 0, 1, 4, 1);


CREATE TABLE MortgagePlatform_Domain.AMLRiskRating_R (
    aml_risk_rating_key    BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    aml_risk_rating_cd     CHAR(1)      CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    aml_risk_rating_nm     VARCHAR(20)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    aml_risk_rating_desc   VARCHAR(300) CHARACTER SET LATIN NOT CASESPECIFIC,
    enhanced_due_diligence BYTEINT NOT NULL DEFAULT 0,
    sort_order             SMALLINT,
    is_active              BYTEINT NOT NULL DEFAULT 1
) UNIQUE PRIMARY INDEX (aml_risk_rating_cd);

COMMENT ON TABLE  MortgagePlatform_Domain.AMLRiskRating_R IS 'Reference: Anti-Money Laundering risk rating. Source: Borrower Profile AML_RISK_RATING. L=Low, M=Medium, H=High. Regulated field under AML/CTF Act; H rating requires Enhanced Due Diligence.';
COMMENT ON COLUMN MortgagePlatform_Domain.AMLRiskRating_R.aml_risk_rating_key    IS 'Surrogate key - system-generated identity';
COMMENT ON COLUMN MortgagePlatform_Domain.AMLRiskRating_R.aml_risk_rating_cd     IS 'Single-character code: L=Low, M=Medium, H=High';
COMMENT ON COLUMN MortgagePlatform_Domain.AMLRiskRating_R.aml_risk_rating_nm     IS 'Short display name';
COMMENT ON COLUMN MortgagePlatform_Domain.AMLRiskRating_R.aml_risk_rating_desc   IS 'Description of risk level and required customer due diligence actions';
COMMENT ON COLUMN MortgagePlatform_Domain.AMLRiskRating_R.enhanced_due_diligence IS '1=Enhanced Due Diligence required under AML/CTF Act obligations; 0=standard CDD sufficient';
COMMENT ON COLUMN MortgagePlatform_Domain.AMLRiskRating_R.sort_order             IS 'Display sort order - 1=lowest risk';
COMMENT ON COLUMN MortgagePlatform_Domain.AMLRiskRating_R.is_active              IS '1=active rating in use; 0=deprecated';

INSERT INTO MortgagePlatform_Domain.AMLRiskRating_R (aml_risk_rating_cd, aml_risk_rating_nm, aml_risk_rating_desc, enhanced_due_diligence, sort_order, is_active) VALUES ('L', 'Low',    'Standard risk customer; no unusual transaction patterns or adverse intelligence; standard CDD applies', 0, 1, 1);
INSERT INTO MortgagePlatform_Domain.AMLRiskRating_R (aml_risk_rating_cd, aml_risk_rating_nm, aml_risk_rating_desc, enhanced_due_diligence, sort_order, is_active) VALUES ('M', 'Medium', 'Moderate risk; some elevated indicators (e.g. complex income structure, offshore connections); heightened monitoring', 0, 2, 1);
INSERT INTO MortgagePlatform_Domain.AMLRiskRating_R (aml_risk_rating_cd, aml_risk_rating_nm, aml_risk_rating_desc, enhanced_due_diligence, sort_order, is_active) VALUES ('H', 'High',   'High risk customer; Enhanced Due Diligence required; senior approval needed for onboarding or continuation', 1, 3, 1);


-- =============================================================================
-- SECTION 4B: BIAN — PARTY REFERENCE DATA MANAGEMENT
-- =============================================================================

CREATE TABLE MortgagePlatform_Domain.Customer_Keymap (
    customer_key  BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    customer_id   VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    source_system VARCHAR(50)  CHARACTER SET LATIN NOT CASESPECIFIC,
    created_dt    TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6)
) UNIQUE PRIMARY INDEX (customer_id);

COMMENT ON TABLE  MortgagePlatform_Domain.Customer_Keymap IS 'Keymap: one row per unique customer. Surrogate key (IDENTITY) generated here and referenced by Customer_H, LoanApplication_H.customer_key, and Loan_H.customer_key. Natural key is CUSTOMER_ID from Borrower Profile.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_Keymap.customer_key  IS 'Surrogate key - generated once per customer, stable across all SCD versions and all referencing tables';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_Keymap.customer_id   IS 'Natural key - CUSTOMER_ID from CRM system. Format: CUS-XXXXXXXX.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_Keymap.source_system IS 'Source system that originated this customer record';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_Keymap.created_dt    IS 'Timestamp the customer natural key was first registered in the keymap';


CREATE TABLE MortgagePlatform_Domain.Customer_H (
    customer_key              BIGINT NOT NULL,
    customer_id               VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,

    -- FK to Loan Application (populated when linked in load process)
    loan_application_key      BIGINT,

    -- BIAN: Party Identity
    customer_title            VARCHAR(10)  CHARACTER SET LATIN NOT CASESPECIFIC,
    first_name                VARCHAR(50)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    last_name                 VARCHAR(50)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    date_of_birth             DATE NOT NULL,
    gender                    CHAR(1)      CHARACTER SET LATIN NOT CASESPECIFIC,
    citizenship_status        VARCHAR(30)  CHARACTER SET LATIN NOT CASESPECIFIC,

    -- BIAN: Digital Engagement
    digital_banking_enrolled  BYTEINT NOT NULL DEFAULT 0,
    digital_banking_last_login DATE,

    -- BIAN: Relationship
    relationship_start_dt     DATE,
    deceased_flag             BYTEINT NOT NULL DEFAULT 0,

    -- Source record dates (from CRM)
    record_source_created_dt  DATE,
    record_source_updated_dt  DATE,

    -- Source tracking
    source_system             VARCHAR(50)  CHARACTER SET LATIN NOT CASESPECIFIC,
    source_key                VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC,

    -- Temporal (Type 2 SCD)
    valid_from_dt             DATE NOT NULL,
    valid_to_dt               DATE NOT NULL DEFAULT DATE '9999-12-31',
    is_current                BYTEINT NOT NULL DEFAULT 1,
    is_deleted                BYTEINT NOT NULL DEFAULT 0,

    -- Audit
    created_dt                TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6),
    updated_dt                TIMESTAMP(6) WITH TIME ZONE
) PRIMARY INDEX (customer_key);

COMMENT ON TABLE  MortgagePlatform_Domain.Customer_H IS 'BIAN: Party Reference Data Management - core customer identity record. Type 2 SCD. The enterprise master for customer identity; all child customer entities reference customer_key. Source: STG_Borrower_Profile. 37,500 customers, one per loan in this dataset.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.customer_key              IS 'Surrogate key from Customer_Keymap - stable across all SCD versions';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.customer_id               IS 'Natural key - CUSTOMER_ID from CRM. Format: CUS-XXXXXXXX. Same across all history versions.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.loan_application_key      IS 'FK to LoanApplication_Keymap - links customer to their loan application; nullable for customers without a current application';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.customer_title            IS 'Salutation: Mr, Mrs, Ms, Dr, Prof. Renamed from TITLE (reserved word in Teradata).';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.first_name                IS 'Customer given name(s).';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.last_name                 IS 'Customer family name.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.date_of_birth             IS 'Customer date of birth. Range 1950-2004 in dataset. Used for age-based eligibility and regulatory reporting.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.gender                    IS 'Gender: M=Male, F=Female, X=Non-binary or Not Stated. Source CHAR(1) with trailing space - trim on load.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.citizenship_status        IS 'Australian citizenship or residency status. Values: Citizen, Permanent Resident, Temporary Resident, Non-Resident.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.digital_banking_enrolled  IS '1=customer is enrolled in digital banking; 0=not enrolled.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.digital_banking_last_login IS 'Date of most recent digital banking login. Null if never logged in or not enrolled.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.relationship_start_dt     IS 'Date the customer first became a customer of the bank (RELATIONSHIP_START_DATE in source).';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.deceased_flag             IS '1=customer is recorded as deceased; 0=active. Deceased customers require special handling for estate management.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.record_source_created_dt  IS 'Date the CRM record was originally created in the source system (RECORD_CREATED_DATE).';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.record_source_updated_dt  IS 'Date the CRM record was most recently updated in the source system (RECORD_LAST_UPDATED).';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.valid_from_dt             IS 'Date this version became effective.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.valid_to_dt               IS 'Date this version was superseded; 9999-12-31 = currently active version.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.is_current                IS '1=current active version; use Customer_Current view to filter.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.is_deleted                IS '1=soft-deleted; always filter WHERE is_deleted = 0 for active records.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.source_system             IS 'Source system that provided this record version.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.source_key                IS 'Natural key as it appeared in the source system.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.created_dt                IS 'Timestamp this row was inserted into the domain table.';
COMMENT ON COLUMN MortgagePlatform_Domain.Customer_H.updated_dt                IS 'Timestamp this row was last modified.';


CREATE TABLE MortgagePlatform_Domain.CustomerContact_H (
    customer_contact_key      BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    customer_key              BIGINT NOT NULL,

    -- BIAN: Contact Details
    email_address             VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC,
    mobile_number             VARCHAR(20)  CHARACTER SET LATIN NOT CASESPECIFIC,
    home_phone                VARCHAR(20)  CHARACTER SET LATIN NOT CASESPECIFIC,
    preferred_contact_channel VARCHAR(20)  CHARACTER SET LATIN NOT CASESPECIFIC,

    -- Source tracking
    source_system             VARCHAR(50)  CHARACTER SET LATIN NOT CASESPECIFIC,
    source_key                VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC,

    -- Temporal (Type 2 SCD)
    valid_from_dt             DATE NOT NULL,
    valid_to_dt               DATE NOT NULL DEFAULT DATE '9999-12-31',
    is_current                BYTEINT NOT NULL DEFAULT 1,
    is_deleted                BYTEINT NOT NULL DEFAULT 0,

    -- Audit
    created_dt                TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6),
    updated_dt                TIMESTAMP(6) WITH TIME ZONE
) PRIMARY INDEX (customer_key);

COMMENT ON TABLE  MortgagePlatform_Domain.CustomerContact_H IS 'BIAN: Party Reference Data Management - customer contact details. Type 2 SCD child of Customer_H; captures all communication channel details. Source: STG_Borrower_Profile. PI on customer_key for efficient join to parent.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerContact_H.customer_contact_key      IS 'Surrogate key - IDENTITY safe here (child entity; no other table FK-references this key)';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerContact_H.customer_key              IS 'FK to Customer_Keymap.customer_key - PI column; co-locates contact record with parent customer';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerContact_H.email_address             IS 'Primary email address for digital communications.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerContact_H.mobile_number             IS 'Mobile phone number. Australian format: +61 4XX XXX XXX.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerContact_H.home_phone                IS 'Home landline number.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerContact_H.preferred_contact_channel IS 'Customer preferred communication channel. Values: Email, Mobile, Post, Branch.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerContact_H.valid_from_dt             IS 'Date this contact version became effective.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerContact_H.valid_to_dt               IS 'Date this contact version was superseded; 9999-12-31 = currently active.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerContact_H.is_current                IS '1=current active version.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerContact_H.is_deleted                IS '1=soft-deleted.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerContact_H.source_system             IS 'Source system that provided this record version.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerContact_H.source_key                IS 'Natural key as it appeared in the source system.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerContact_H.created_dt                IS 'Timestamp this row was inserted.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerContact_H.updated_dt                IS 'Timestamp this row was last modified.';


CREATE TABLE MortgagePlatform_Domain.CustomerAddress_H (
    customer_address_key  BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    customer_key          BIGINT NOT NULL,

    -- BIAN: Address
    address_line_1        VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    address_line_2        VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC,
    suburb                VARCHAR(60)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    state                 CHAR(3)      CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    postcode              CHAR(4)      CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL,
    address_type          VARCHAR(20)  CHARACTER SET LATIN NOT CASESPECIFIC NOT NULL DEFAULT 'RESIDENTIAL',

    -- Source tracking
    source_system         VARCHAR(50)  CHARACTER SET LATIN NOT CASESPECIFIC,
    source_key            VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC,

    -- Temporal (Type 2 SCD)
    valid_from_dt         DATE NOT NULL,
    valid_to_dt           DATE NOT NULL DEFAULT DATE '9999-12-31',
    is_current            BYTEINT NOT NULL DEFAULT 1,
    is_deleted            BYTEINT NOT NULL DEFAULT 0,

    -- Audit
    created_dt            TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6),
    updated_dt            TIMESTAMP(6) WITH TIME ZONE
) PRIMARY INDEX (customer_key);

COMMENT ON TABLE  MortgagePlatform_Domain.CustomerAddress_H IS 'BIAN: Party Reference Data Management - customer residential address. Type 2 SCD child of Customer_H. SCD versioning captures address changes over time (important for mail communications and fraud detection). Source: STG_Borrower_Profile.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerAddress_H.customer_address_key IS 'Surrogate key - IDENTITY safe here (child entity; no other table FK-references this key)';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerAddress_H.customer_key         IS 'FK to Customer_Keymap.customer_key - PI column';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerAddress_H.address_line_1       IS 'Primary street address line including street number and name.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerAddress_H.address_line_2       IS 'Unit or apartment number; null for standalone properties.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerAddress_H.suburb               IS 'Suburb or town name.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerAddress_H.state                IS 'Australian state abbreviation: NSW, VIC, QLD, SA, WA, TAS, ACT, NT. 8 distinct values in dataset.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerAddress_H.postcode             IS 'Australian 4-digit postcode.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerAddress_H.address_type         IS 'Address classification: RESIDENTIAL (default), POSTAL, BUSINESS.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerAddress_H.valid_from_dt        IS 'Date this address version became effective.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerAddress_H.valid_to_dt          IS 'Date this address was superseded; 9999-12-31 = currently active address.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerAddress_H.is_current           IS '1=current active version.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerAddress_H.is_deleted           IS '1=soft-deleted.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerAddress_H.source_system        IS 'Source system that provided this record version.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerAddress_H.source_key           IS 'Natural key as it appeared in the source system.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerAddress_H.created_dt           IS 'Timestamp this row was inserted.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerAddress_H.updated_dt           IS 'Timestamp this row was last modified.';


-- =============================================================================
-- SECTION 4C: BIAN — CUSTOMER PROFILE
-- =============================================================================

CREATE TABLE MortgagePlatform_Domain.CustomerSegment_H (
    customer_segment_key    BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    customer_key            BIGINT NOT NULL,

    -- BIAN: Customer Segment / CRM
    segment_cd              VARCHAR(30) CHARACTER SET LATIN NOT CASESPECIFIC,
    branch_code             CHAR(6)     CHARACTER SET LATIN NOT CASESPECIFIC,
    relationship_manager_id VARCHAR(20) CHARACTER SET LATIN NOT CASESPECIFIC,
    last_contact_dt         DATE,
    marketing_opt_in        BYTEINT NOT NULL DEFAULT 0,

    -- Source tracking
    source_system           VARCHAR(50)  CHARACTER SET LATIN NOT CASESPECIFIC,
    source_key              VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC,

    -- Temporal (Type 2 SCD)
    valid_from_dt           DATE NOT NULL,
    valid_to_dt             DATE NOT NULL DEFAULT DATE '9999-12-31',
    is_current              BYTEINT NOT NULL DEFAULT 1,
    is_deleted              BYTEINT NOT NULL DEFAULT 0,

    -- Audit
    created_dt              TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6),
    updated_dt              TIMESTAMP(6) WITH TIME ZONE
) PRIMARY INDEX (customer_key);

COMMENT ON TABLE  MortgagePlatform_Domain.CustomerSegment_H IS 'BIAN: Customer Profile - CRM segment, relationship management, and engagement attributes. Type 2 SCD; captures segment transitions over time (e.g. Mass Market to Emerging Affluent). Source: STG_Borrower_Profile.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_H.customer_segment_key    IS 'Surrogate key - IDENTITY safe here (child entity)';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_H.customer_key            IS 'FK to Customer_Keymap.customer_key - PI column';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_H.segment_cd              IS 'FK to CustomerSegment_R.segment_cd - customer segment classification (Mass Market, Affluent, etc.)';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_H.branch_code             IS 'Home branch code for branch-aligned customers. 6-character branch identifier.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_H.relationship_manager_id IS 'Employee ID of assigned relationship manager. Populated for Affluent, Private Banking, Business Owner segments.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_H.last_contact_dt         IS 'Date of most recent contact by the bank across any channel.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_H.marketing_opt_in        IS '1=customer has opted in to marketing communications; 0=opted out. Governed by Australian Privacy Act.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_H.valid_from_dt           IS 'Date this segment version became effective.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_H.valid_to_dt             IS 'Date this segment version was superseded; 9999-12-31 = currently active.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_H.is_current              IS '1=current active version.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_H.is_deleted              IS '1=soft-deleted.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_H.source_system           IS 'Source system that provided this record version.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_H.source_key              IS 'Natural key as it appeared in the source system.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_H.created_dt              IS 'Timestamp this row was inserted.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerSegment_H.updated_dt              IS 'Timestamp this row was last modified.';


CREATE TABLE MortgagePlatform_Domain.CustomerFinancial_H (
    customer_financial_key  BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    customer_key            BIGINT NOT NULL,

    -- BIAN: Customer Financial Profile
    annual_income           DECIMAL(15,2),
    income_verified_flag    BYTEINT NOT NULL DEFAULT 0,
    employment_status_cd    VARCHAR(30) CHARACTER SET LATIN NOT CASESPECIFIC,
    employer_name           VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC,
    years_with_employer     DECIMAL(4,1),

    -- Source tracking
    source_system           VARCHAR(50)  CHARACTER SET LATIN NOT CASESPECIFIC,
    source_key              VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC,

    -- Temporal (Type 2 SCD)
    valid_from_dt           DATE NOT NULL,
    valid_to_dt             DATE NOT NULL DEFAULT DATE '9999-12-31',
    is_current              BYTEINT NOT NULL DEFAULT 1,
    is_deleted              BYTEINT NOT NULL DEFAULT 0,

    -- Audit
    created_dt              TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6),
    updated_dt              TIMESTAMP(6) WITH TIME ZONE
) PRIMARY INDEX (customer_key);

COMMENT ON TABLE  MortgagePlatform_Domain.CustomerFinancial_H IS 'BIAN: Customer Profile - income, employment, and financial capacity attributes. Type 2 SCD; captures changes in employment status and income over time. Source: STG_Borrower_Profile. Annual income range 30K-786K AUD in dataset.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerFinancial_H.customer_financial_key IS 'Surrogate key - IDENTITY safe here (child entity)';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerFinancial_H.customer_key           IS 'FK to Customer_Keymap.customer_key - PI column';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerFinancial_H.annual_income          IS 'Declared annual gross income in AUD at time of last review. Range 30K-786K in dataset.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerFinancial_H.income_verified_flag   IS '1=income has been formally verified via payslip or tax return; 0=self-declared only.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerFinancial_H.employment_status_cd   IS 'FK to EmploymentStatus_R - employment status at time of last review.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerFinancial_H.employer_name          IS 'Name of employer at time of last review. Null for self-employed, retired, or unemployed.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerFinancial_H.years_with_employer    IS 'Tenure with current employer in years (e.g. 2.5 = two and a half years).';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerFinancial_H.valid_from_dt          IS 'Date this financial profile version became effective.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerFinancial_H.valid_to_dt            IS 'Date this version was superseded; 9999-12-31 = currently active.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerFinancial_H.is_current             IS '1=current active version.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerFinancial_H.is_deleted             IS '1=soft-deleted.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerFinancial_H.source_system          IS 'Source system that provided this record version.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerFinancial_H.source_key             IS 'Natural key as it appeared in the source system.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerFinancial_H.created_dt             IS 'Timestamp this row was inserted.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerFinancial_H.updated_dt             IS 'Timestamp this row was last modified.';


CREATE TABLE MortgagePlatform_Domain.CustomerInsight_H (
    customer_insight_key  BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    customer_key          BIGINT NOT NULL,

    -- BIAN: Customer Profile (analytically-derived attributes)
    churn_risk_score      DECIMAL(5,2),
    churn_risk_band       VARCHAR(10)  CHARACTER SET LATIN NOT CASESPECIFIC,
    nps_score             SMALLINT,

    -- Source tracking
    source_system         VARCHAR(50)  CHARACTER SET LATIN NOT CASESPECIFIC,
    source_key            VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC,

    -- Temporal (Type 2 SCD)
    valid_from_dt         DATE NOT NULL,
    valid_to_dt           DATE NOT NULL DEFAULT DATE '9999-12-31',
    is_current            BYTEINT NOT NULL DEFAULT 1,
    is_deleted            BYTEINT NOT NULL DEFAULT 0,

    -- Audit
    created_dt            TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6),
    updated_dt            TIMESTAMP(6) WITH TIME ZONE
) PRIMARY INDEX (customer_key);

COMMENT ON TABLE  MortgagePlatform_Domain.CustomerInsight_H IS 'BIAN: Customer Profile (analytically-derived) - model scores and survey-based metrics. Type 2 SCD; versioned as models are refreshed. These are model outputs loaded back into the domain, not raw CRM fields. Source: STG_Borrower_Profile.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerInsight_H.customer_insight_key IS 'Surrogate key - IDENTITY safe here (child entity)';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerInsight_H.customer_key         IS 'FK to Customer_Keymap.customer_key - PI column';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerInsight_H.churn_risk_score     IS 'Model-generated churn propensity score. Range 0.00-1.00; higher = higher churn probability. Source: CHURN_RISK_SCORE.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerInsight_H.churn_risk_band      IS 'Banded churn risk label derived from score. Low (<0.30), Medium (0.30-0.60), High (>0.60).';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerInsight_H.nps_score            IS 'Net Promoter Score from most recent customer survey. Range -100 to 100; higher = more likely to recommend.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerInsight_H.valid_from_dt        IS 'Date this insight version became effective (model refresh date).';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerInsight_H.valid_to_dt          IS 'Date this version was superseded; 9999-12-31 = currently active.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerInsight_H.is_current           IS '1=current active version.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerInsight_H.is_deleted           IS '1=soft-deleted.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerInsight_H.source_system        IS 'Source system that provided this record version.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerInsight_H.source_key           IS 'Natural key as it appeared in the source system.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerInsight_H.created_dt           IS 'Timestamp this row was inserted.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerInsight_H.updated_dt           IS 'Timestamp this row was last modified.';


-- =============================================================================
-- SECTION 4D: BIAN — CUSTOMER CREDIT RATING
-- =============================================================================

CREATE TABLE MortgagePlatform_Domain.CustomerCompliance_H (
    customer_compliance_key  BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    customer_key             BIGINT NOT NULL,

    -- BIAN: Customer Credit Rating / Compliance
    kyc_status_cd            VARCHAR(20) CHARACTER SET LATIN NOT CASESPECIFIC,
    kyc_verification_dt      DATE,
    aml_risk_rating_cd       CHAR(1)     CHARACTER SET LATIN NOT CASESPECIFIC,

    -- Source tracking
    source_system            VARCHAR(50)  CHARACTER SET LATIN NOT CASESPECIFIC,
    source_key               VARCHAR(100) CHARACTER SET LATIN NOT CASESPECIFIC,

    -- Temporal (Type 2 SCD)
    valid_from_dt            DATE NOT NULL,
    valid_to_dt              DATE NOT NULL DEFAULT DATE '9999-12-31',
    is_current               BYTEINT NOT NULL DEFAULT 1,
    is_deleted               BYTEINT NOT NULL DEFAULT 0,

    -- Audit
    created_dt               TIMESTAMP(6) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP(6),
    updated_dt               TIMESTAMP(6) WITH TIME ZONE
) PRIMARY INDEX (customer_key);

COMMENT ON TABLE  MortgagePlatform_Domain.CustomerCompliance_H IS 'BIAN: Customer Credit Rating - KYC verification status and AML risk rating. Type 2 SCD; versioned when KYC is renewed or AML rating is reassessed. Regulated attributes under AML/CTF Act and APRA CPS 234. Source: STG_Borrower_Profile.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerCompliance_H.customer_compliance_key IS 'Surrogate key - IDENTITY safe here (child entity)';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerCompliance_H.customer_key            IS 'FK to Customer_Keymap.customer_key - PI column';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerCompliance_H.kyc_status_cd           IS 'FK to KYCStatus_R - current KYC verification status. Verified=compliant; Pending/Expired/Failed require action.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerCompliance_H.kyc_verification_dt     IS 'Date KYC verification was last completed or renewed.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerCompliance_H.aml_risk_rating_cd      IS 'FK to AMLRiskRating_R - AML risk rating: L=Low, M=Medium, H=High. H requires Enhanced Due Diligence.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerCompliance_H.valid_from_dt           IS 'Date this compliance version became effective.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerCompliance_H.valid_to_dt             IS 'Date this version was superseded; 9999-12-31 = currently active.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerCompliance_H.is_current              IS '1=current active version.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerCompliance_H.is_deleted              IS '1=soft-deleted.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerCompliance_H.source_system           IS 'Source system that provided this record version.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerCompliance_H.source_key              IS 'Natural key as it appeared in the source system.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerCompliance_H.created_dt              IS 'Timestamp this row was inserted.';
COMMENT ON COLUMN MortgagePlatform_Domain.CustomerCompliance_H.updated_dt              IS 'Timestamp this row was last modified.';


-- =============================================================================
-- SECTION 4E: VIEWS — Customer
-- =============================================================================

REPLACE VIEW MortgagePlatform_Domain.Customer_Current AS
SELECT * FROM MortgagePlatform_Domain.Customer_H
WHERE is_current = 1 AND is_deleted = 0;
COMMENT ON VIEW MortgagePlatform_Domain.Customer_Current IS 'Current active customer records - is_current=1 and is_deleted=0. Use for standard reporting and joins.';

REPLACE VIEW MortgagePlatform_Domain.Customer_Enriched AS
SELECT
    c.*,
    csh.segment_cd              AS segment_cd,
    seg.segment_nm              AS segment_name,
    seg.wealth_tier_order       AS segment_wealth_tier,
    cc.kyc_status_cd            AS kyc_status,
    ks.is_compliant             AS kyc_is_compliant,
    cc.aml_risk_rating_cd       AS aml_risk_rating,
    ar.aml_risk_rating_nm       AS aml_risk_rating_name,
    ar.enhanced_due_diligence   AS aml_edd_required
FROM MortgagePlatform_Domain.Customer_Current c
LEFT JOIN MortgagePlatform_Domain.CustomerSegment_H    csh ON csh.customer_key     = c.customer_key AND csh.is_current = 1 AND csh.is_deleted = 0
LEFT JOIN MortgagePlatform_Domain.CustomerSegment_R    seg ON seg.segment_cd        = csh.segment_cd
LEFT JOIN MortgagePlatform_Domain.CustomerCompliance_H cc  ON cc.customer_key       = c.customer_key AND cc.is_current = 1 AND cc.is_deleted = 0
LEFT JOIN MortgagePlatform_Domain.KYCStatus_R          ks  ON ks.kyc_status_cd      = cc.kyc_status_cd
LEFT JOIN MortgagePlatform_Domain.AMLRiskRating_R      ar  ON ar.aml_risk_rating_cd = cc.aml_risk_rating_cd;
COMMENT ON VIEW MortgagePlatform_Domain.Customer_Enriched IS 'Enriched customer view - current customers with decoded segment, KYC compliance status and AML risk rating. Suitable for compliance dashboards and customer analytics.';
