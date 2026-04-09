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
