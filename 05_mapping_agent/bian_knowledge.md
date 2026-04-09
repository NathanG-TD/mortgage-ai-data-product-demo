---
name: bian_knowledge
description: >
  Domain knowledge reference for the BIAN Mortgage Mapping Agent.
  Covers the 8 BIAN Service Domains in scope, their Business Objects,
  key attributes, vocabulary heuristics, and the KS query guide.
  This document is NOT procedural -- it describes what the BIAN domain
  model IS, not how the agent should behave (that is in SKILL.md).
---

# BIAN Mortgage Knowledge Reference

---

## 1. What is the Knowledge Source?

The Knowledge Source (KS) for this mapping skill is the MortgagePlatform
AI-Native Data Product itself. The product is self-documenting: its Semantic
and Memory modules hold the structured metadata that the mapping agent reads
to understand the target domain model.

**KS databases:**

| Role | Database | Key tables |
|------|----------|-----------|
| Entity catalogue | MortgagePlatform_Semantic | entity_metadata, column_metadata, table_relationship |
| Business glossary | MortgagePlatform_Memory | Business_Glossary, Design_Decision |
| Physical schema | MortgagePlatform_Domain | All _H, _R, _Keymap tables |

**Critical property of this KS:**
Unlike fsDM, the same entity can only appear in one BIAN Service Domain.
The mapping target is always a specific Entity/Table, not a Service Domain.
The Service Domain is the discovery path -- it does not determine where data
physically lives, but it narrows the candidate entity list efficiently.

---

## 2. The 8 BIAN Service Domains in Scope

### 2.1 Mortgage Loan Application

**Purpose:** Captures the loan application attributes at origination -- the
borrower's financial position and intent at the time of applying.

**Key Business Objects:**
- Application Details: channel, purpose, LVR, CLTV, DTI
- Borrower Profile (at application): credit score, borrower count, income indicators
- Program & Scheme: first-home buyer, HARP, super-conforming, MI coverage
- Decision: approval status, seller/originator

**Primary entity:** `LoanApplication_H`
**Natural key:** `loan_application_id` = LOAN_SEQUENCE_NUMBER

**Vocabulary triggers (source column names containing these terms map HERE):**
```
application, app, origination, orig, channel, broker, retail, correspondent,
loan_purpose, purpose, purchase, refinance, refi, cash_out, occupancy,
ltv, cltv, combined_ltv, dti, debt_income, debt_to_income,
credit_score, fico, score_at_origination, first_home, first_time, homebuyer,
mi_pct, mortgage_insurance, mi_percentage, number_of_borrowers, borrower_count,
program, harp, super_conforming, seller, originator, approval, approved
```

**Attribute vocabulary map (source term → domain column):**

| Source concept | Domain column |
|----------------|--------------|
| origination channel / broker flag | channel_cd |
| loan purpose / purchase vs refi | loan_purpose_cd |
| occupancy / owner-occupied / investment | occupancy_status_cd |
| loan amount at application / face value | requested_amount |
| LTV / loan-to-value at origination | orig_ltv |
| CLTV / combined LTV / all liens | orig_cltv |
| DTI / debt-to-income | orig_dti |
| credit score / FICO at origination | credit_score_at_application |
| number of borrowers / co-borrower | number_of_borrowers |
| first home / first-time buyer | first_time_homebuyer_flag |
| number of units / property units | number_of_units |
| MI percentage / mortgage insurance | mi_percentage |
| HARP / affordable refinance | harp_indicator |
| super-conforming / jumbo threshold | super_conforming_flag |
| relief refinance / predecessor loan | pre_relief_refinance_lsn |
| seller / originating institution | seller_name |


### 2.2 Mortgage Loan

**Purpose:** The funded mortgage facility -- the central entity. Holds origination
terms and current loan lifecycle status. Monthly performance is in LoanPerformance_H.

**Key Business Objects:**
- Loan Facility: UPB, rate, term, amortisation type, maturity date
- Property Details (denormalised): type, state, postcode, units
- Servicer: servicer name
- Loan Status: active/closed, zero balance reason

**Primary entities:**
- `Loan_H` -- facility master
- `LoanPerformance_H` -- monthly snapshot (grain: loan x period)
- `LoanEvent_H` -- discrete lifecycle events
- `LoanModification_H` -- restructuring events

**Natural key:** `loan_id` = LOAN_SEQUENCE_NUMBER

**Vocabulary triggers:**
```
loan, mortgage, facility, account, upb, unpaid_principal, outstanding_balance,
current_balance, principal_balance, interest_rate, note_rate, coupon,
loan_term, term_months, maturity, first_payment, settlement_date,
amortization, amortisation, fixed, variable, arm, frm, tracker,
servicer, servicing, status, active, closed, zero_balance,
delinquency, delinquent, arrears, dpd, days_past_due,
performance, monthly_report, reporting_period,
modification, forbearance, deferral, hardship, restructure,
loss, recovery, expenses, legal_costs, mi_recoveries,
ltv_current, estimated_ltv, current_ltv
```

**Attribute vocabulary map:**

| Source concept | Domain table | Domain column |
|----------------|-------------|--------------|
| original loan amount / face amount | Loan_H | orig_upb |
| original interest rate / note rate | Loan_H | orig_interest_rate |
| loan term in months | Loan_H | orig_loan_term_months |
| amortisation type / fixed vs variable | Loan_H | amortization_type_cd |
| maturity date / loan end date | Loan_H | maturity_dt |
| first payment date / settlement date | Loan_H | first_payment_dt |
| current balance / current UPB | LoanPerformance_H | current_actual_upb |
| current rate / current interest rate | LoanPerformance_H | current_interest_rate |
| estimated LTV / current LTV | LoanPerformance_H | estimated_ltv |
| delinquency status / arrears bucket | LoanPerformance_H | delinquency_status_cd |
| loan age / months since origination | LoanPerformance_H | loan_age_months |
| remaining term | LoanPerformance_H | remaining_months_to_maturity |
| zero balance reason / payoff code | LoanPerformance_H | zero_balance_code_cd |


### 2.3 Party Reference Data Management

**Purpose:** The enterprise customer identity master. Holds immutable identity
attributes and digital engagement status.

**Key Business Objects:**
- Party Identity: name, DOB, gender, citizenship
- Digital Engagement: online banking, last login
- Party Status: deceased, relationship start date

**Primary entity:** `Customer_H`
**Natural key:** `customer_id` = CUSTOMER_ID

**Vocabulary triggers:**
```
customer, party, person, individual, borrower, client,
name, first_name, given_name, last_name, surname, family_name,
dob, date_of_birth, birth_date, age,
gender, sex, salutation, title,
citizenship, nationality, residency, resident, visa,
digital, online, internet_banking, mobile_banking, app_login,
deceased, death, estate, relationship_start, customer_since
```

**Attribute vocabulary map:**

| Source concept | Domain column |
|----------------|--------------|
| customer/party identifier | customer_id (join key) |
| title / salutation (Mr, Ms) | customer_title |
| given name / first name | first_name (PII) |
| family name / surname | last_name (PII) |
| date of birth / birth date | date_of_birth (PII) |
| gender / sex | gender |
| citizenship / residency status | citizenship_status |
| digital banking enrolled | digital_banking_enrolled |
| last digital login / app activity | digital_banking_last_login |
| relationship start / customer since | relationship_start_dt |
| deceased indicator | deceased_flag |


### 2.4 Customer Profile

**Purpose:** CRM-derived segmentation, financial capacity, and analytically-derived
insights about the customer. Changes over time; versioned as Type 2 SCD.

**Key Business Objects:**
- CRM Segment: wealth tier, relationship manager assignment, branch
- Financial Profile: income, employment, tenure
- Analytically-Derived Insights: churn risk, NPS

**Primary entities:**
- `CustomerSegment_H` -- CRM classification and RM
- `CustomerFinancial_H` -- income and employment
- `CustomerInsight_H` -- model scores and survey results

**Vocabulary triggers:**
```
segment, tier, wealth, affluent, mass_market, private_banking, business_owner,
relationship_manager, rm, branch_code, branch,
income, salary, wages, annual_income, gross_income, declared_income,
employment, employer, job, occupation, full_time, part_time, self_employed, retired,
churn, propensity, risk_score, churn_score, attrition,
nps, net_promoter, satisfaction, survey,
marketing, opt_in, contact_channel, preferred_channel,
last_contact, last_interaction
```

**Attribute vocabulary map:**

| Source concept | Domain table | Domain column |
|----------------|-------------|--------------|
| customer segment / CRM tier | CustomerSegment_H | segment_cd |
| relationship manager ID | CustomerSegment_H | relationship_manager_id |
| home branch / branch code | CustomerSegment_H | branch_code |
| last contact date | CustomerSegment_H | last_contact_dt |
| marketing opt-in | CustomerSegment_H | marketing_opt_in |
| annual income / declared income | CustomerFinancial_H | annual_income (SENSITIVE) |
| income verified flag | CustomerFinancial_H | income_verified_flag |
| employment status | CustomerFinancial_H | employment_status_cd |
| employer name | CustomerFinancial_H | employer_name |
| years with employer / tenure | CustomerFinancial_H | years_with_employer |
| churn risk score / propensity | CustomerInsight_H | churn_risk_score (SENSITIVE) |
| churn band / risk band | CustomerInsight_H | churn_risk_band |
| NPS score / net promoter | CustomerInsight_H | nps_score |


### 2.5 Customer Credit Rating

**Purpose:** KYC verification and AML risk rating. Regulated attributes governed by
the AML/CTF Act and APRA CPS 234. Changes as verification is renewed or rating reassessed.

**Key Business Objects:**
- KYC Verification: status (Verified/Pending/Expired/Failed), verification date
- AML Risk Rating: L/M/H rating, Enhanced Due Diligence flag

**Primary entity:** `CustomerCompliance_H`

**Vocabulary triggers:**
```
kyc, know_your_customer, identity_verification, id_check,
kyc_status, kyc_date, verification_date, verification_status,
aml, anti_money_laundering, money_laundering, ml_risk,
aml_risk, risk_rating, cdd, edd, enhanced_due_diligence,
pep, politically_exposed, sanctions, fatf,
compliance, regulatory, regulated,
credit_impairment, default, judgement, judgment, bankruptcy, insolvency,
part_ix, debt_agreement, serious_impairment,
bureau_score, credit_score_current, score_band,
enquiries, credit_enquiry, num_defaults, default_amount
```

**IMPORTANT — Bureau Feed Mapping:**
The credit bureau feed (Act 2 withheld source) enriches CustomerCompliance_H
and CustomerInsight_H. Key mappings:

| Bureau column | Domain table | Domain column | Note |
|---------------|-------------|--------------|------|
| CRED_SCORE_CURR | CustomerInsight_H | churn_risk_score | SCALE MISMATCH: Equifax 0-1200 vs FICO 300-850 |
| CRED_SCORE_BAND | CustomerCompliance_H | (new attribute) | Score band classification |
| NUM_DEFAULTS | CustomerCompliance_H | (new attribute) | Credit default count |
| BANKRUPTCY_FLAG | CustomerCompliance_H | (new attribute) | Bankruptcy indicator |
| PART_IX_FLAG | CustomerCompliance_H | (new attribute) | Part IX debt agreement |
| SERIOUS_CREDIT_IMPAIRMENT | CustomerCompliance_H | (new attribute) | Composite impairment flag |
| ENQ_3M, ENQ_12M | CustomerInsight_H | (new attribute) | Enquiry activity |
| REPMT_HIST_SCORE | CustomerInsight_H | (new attribute) | Repayment history score |
| CREDIT_UTIL_RATIO | CustomerInsight_H | (new attribute) | Credit utilisation |

Attribute vocabulary map (CustomerCompliance_H):

| Source concept | Domain column |
|----------------|--------------|
| KYC status | kyc_status_cd (SENSITIVE) |
| KYC verification date | kyc_verification_dt |
| AML risk rating | aml_risk_rating_cd (SENSITIVE/REGULATED) |


### 2.6 Collateral Asset Administration

**Purpose:** The security property held against the mortgage loan. Covers physical
characteristics, valuations over time, natural hazard risks, and legal title.

**Key Business Objects:**
- Property: type, status, characteristics (bedrooms, bathrooms, land area)
- Address: street address, suburb, state, postcode
- Valuation Event: ORIGINAL (at origination) and CURRENT_AVM (periodic refresh)
- Risk: flood zone, fire zone, environmental constraints
- Title: title reference, lot/plan number, strata/heritage status

**Primary entities:**
- `Property_H` -- core property record
- `PropertyAddress_H` -- physical address
- `PropertyValuation_H` -- append-only valuation events
- `PropertyRisk_H` -- natural hazard risk
- `PropertyTitle_H` -- legal title details

**Natural key:** `property_id` = PROPERTY_ID

**Vocabulary triggers:**
```
property, collateral, security, dwelling, house, unit, apartment, townhouse,
valuation, appraisal, assessed_value, property_value, market_value, avm,
automated_valuation, kerbside, desktop,
suburb, postcode, street, address, state, council, lga, zoning,
bedrooms, bathrooms, car_spaces, land_area, floor_area, sqm,
year_built, heritage, strata, torrens, freehold,
flood, fire, bushfire, environmental, constraint, risk_zone,
title, title_reference, lot, plan, deposited_plan,
estimated_lvr, current_ltv, lvr
```

**Attribute vocabulary map:**

| Source concept | Domain table | Domain column |
|----------------|-------------|--------------|
| property ID / security ID | Property_H | property_id (join key) |
| property type / dwelling type | Property_H | property_type_cd |
| collateral status / security status | Property_H | property_status_cd |
| number of bedrooms | Property_H | bedrooms |
| number of bathrooms | Property_H | bathrooms |
| car spaces / garage | Property_H | car_spaces |
| land area / lot size | Property_H | land_area_sqm |
| floor area / internal area | Property_H | floor_area_sqm |
| year built / construction year | Property_H | year_built |
| zoning / land use classification | Property_H | zoning_code |
| council / LGA | Property_H | council_area |
| street number | PropertyAddress_H | street_number |
| street name | PropertyAddress_H | street_name |
| suburb / locality | PropertyAddress_H | suburb |
| state | PropertyAddress_H | state |
| postcode | PropertyAddress_H | postcode |
| valuation date / appraisal date | PropertyValuation_H | valuation_dt |
| valuation amount / assessed value | PropertyValuation_H | valuation_amount |
| valuation method / appraisal type | PropertyValuation_H | valuation_method_cd |
| valuer / appraisal firm | PropertyValuation_H | valuer_name |
| current LVR / estimated LTV | PropertyValuation_H | estimated_lvr |
| flood risk / flood zone | PropertyRisk_H | flood_risk_zone |
| fire risk / bushfire zone | PropertyRisk_H | fire_risk_zone |
| environmental constraint | PropertyRisk_H | environmental_constraint |
| title reference / certificate of title | PropertyTitle_H | title_reference |
| lot number | PropertyTitle_H | lot_number |
| plan / deposited plan | PropertyTitle_H | plan_number |
| strata / community title | PropertyTitle_H | strata_flag |
| heritage listed | PropertyTitle_H | heritage_listed |


### 2.7 Payment

**Purpose:** Monthly payment events derived from UPB movement in LoanPerformance_H.
Captures principal and interest components of each scheduled repayment.

**Primary entity:** `Payment_H`

**Vocabulary triggers:**
```
payment, repayment, instalment, installment, scheduled_payment,
principal_payment, interest_payment, principal_paid, interest_charged,
opening_balance, closing_balance, opening_upb, closing_upb,
drawdown, settlement_payment, disbursement
```

**Attribute vocabulary map:**

| Source concept | Domain column |
|----------------|--------------|
| payment period / reporting month | payment_period_dt |
| payment type / event type | payment_type_cd |
| opening balance / prior UPB | opening_upb |
| closing balance / current UPB | closing_upb |
| principal reduction | principal_component |
| interest charged / interest accrued | interest_component |
| total payment / total repayment | total_payment |


### 2.8 Customer Statement

**Purpose:** Monthly account statement sent to the borrower. Summarises the
payment activity and balance position for the period.

**Primary entity:** `LoanStatement_H`

**Vocabulary triggers:**
```
statement, account_statement, monthly_statement, loan_statement,
statement_date, statement_period, statement_balance,
interest_charged, principal_paid, total_paid,
opening_balance, closing_balance
```

---

## 3. Cross-Domain Concepts

Several concepts span multiple Service Domains. Use these rules to disambiguate:

| Concept | Rule |
|---------|------|
| Credit score | FICO 300-850 at origination → LoanApplication_H.credit_score_at_application; Equifax 0-1200 from bureau → CustomerInsight_H (new attribute); SCALE MISMATCH must be flagged |
| LTV | At origination from loan → LoanApplication_H.orig_ltv; Monthly dynamic → LoanPerformance_H.estimated_ltv; From property → PropertyValuation_H.estimated_lvr |
| Property type | At origination (Freddie Mac codes) → Loan_H.property_type_cd; Physical property record → Property_H.property_type_cd |
| State / address | Borrower residential address → CustomerAddress_H.state; Property/collateral address → PropertyAddress_H.state |
| Customer ID | Always a join key → Customer_Keymap.customer_id |
| Loan sequence number | Always a join key → both LoanApplication_Keymap and Loan_Keymap |

---

## 4. Governance Vocabulary — Automatic GOVERNANCE_FLAG Triggers

Apply GOVERNANCE_FLAG = Y when source column name or description contains:

| Trigger terms | Governance category |
|---------------|-------------------|
| aml, anti_money_laundering, money_laundering, ml_risk | AML/CTF Act |
| kyc, know_your_customer, identity_verification | KYC/AML/CTF Act |
| pep, politically_exposed, sanctions | AML/CTF Act |
| bankruptcy, bankrupt, insolvency, insolvent, part_ix, part_9 | Privacy + Credit Reporting |
| default, defaulted, judgement, judgment | Privacy + Credit Reporting |
| serious_credit_impairment, credit_impairment | Privacy + Credit Reporting |
| credit_score, fico, credit_rating, bureau_score | Privacy Act + responsible lending |
| annual_income, declared_income, gross_income | Responsible Lending |
| tax_file, tfn, ssn, social_security | Privacy Act + tax legislation |
| deceased, death, estate | Privacy Act |

---

## 5. Scale and Encoding Mismatch Reference

Always flag these mismatches as transformation notes in the mapping output:

| Concept | Source scale | Domain scale | Transform required |
|---------|-------------|-------------|-------------------|
| Credit score (Freddie Mac) | FICO 300-850 | 300-850 in LoanApplication_H | Direct — same scale |
| Credit score (bureau) | Equifax 0-1200 | 300-850 in LoanApplication_H | SCALE MISMATCH — store separately, do not overwrite |
| Y/N flags in staging | CHAR(1) Y/N/null | BYTEINT 1/0 in domain | Y→1, N/null→0 |
| YYYYMM dates | CHAR(6) | DATE (first of month) | CAST conversion — already applied in domain |
| Flood risk truncation | VARCHAR(10) staging | VARCHAR(15) domain | Overland F → Overland Flow |

---

## 6. KS Query Guide — How to Read the Knowledge Source

### 6.1 List all domain entities
```sql
SELECT entity_name, table_name, entity_description, entity_category, record_count_approx
FROM MortgagePlatform_Semantic.entity_metadata
WHERE module_name = 'DOMAIN'
ORDER BY entity_name;
```

### 6.2 Get columns for a target entity (with PII/sensitive flags)
```sql
SELECT c.column_name, c.business_description, c.data_type,
       c.is_pii, c.is_sensitive, c.validation_rule
FROM MortgagePlatform_Semantic.column_metadata c
WHERE c.database_name = 'MortgagePlatform_Domain'
  AND c.table_name = '<Entity_H>';
```

### 6.3 Get physical column list for a target table
```sql
SELECT ColumnName, ColumnType, ColumnLength, Nullable,
       CommentString
FROM DBC.ColumnsV
WHERE DatabaseName = 'MortgagePlatform_Domain'
  AND TableName = '<Entity_H>'
ORDER BY ColumnId;
```

### 6.4 Get FK relationships for an entity
```sql
SELECT from_table, from_column, to_table, to_column,
       cardinality, relationship_desc
FROM MortgagePlatform_Semantic.table_relationship
WHERE from_database = 'MortgagePlatform_Domain'
  AND (from_table = '<Entity_H>' OR to_table = '<Entity_H>')
ORDER BY from_table;
```

### 6.5 Look up a business term
```sql
SELECT term, definition, business_context, related_table, related_column
FROM MortgagePlatform_Memory.Business_Glossary
WHERE is_active = 1
ORDER BY term;
```

### 6.6 Get reference table values for a coded column
```sql
-- Example: get all delinquency status codes
SELECT delinquency_status_cd, delinquency_status_nm, days_past_due_min,
       days_past_due_max, is_performing
FROM MortgagePlatform_Domain.DelinquencyStatus_R
ORDER BY sort_order;
```

---

## 7. Scoring Heuristics for Mortgage Context

### 7.1 Name similarity scoring
Score 1.0 if source column name contains any vocabulary trigger for a domain entity.
Score 0.8 if the source column description contains the trigger.
Score 0.6 if the source table name (not column) contains the trigger.
Score 0.3 for partial/abbreviated match (e.g. CRED_SCORE matches credit_score).

### 7.2 Data type compatibility scoring
Score 1.0 for exact type match (both DECIMAL for amounts).
Score 0.8 for compatible type (CHAR vs VARCHAR for codes).
Score 0.5 for implicit cast possible (INTEGER → SMALLINT).
Score 0.0 for incompatible (string to date without transform).

### 7.3 Value range/pattern scoring
Score 1.0 if value range falls within the domain column's documented range.
Score 0.5 if value pattern matches but range is different (scale mismatch).
Score 0.0 if value pattern is clearly incompatible.

### 7.4 Overall confidence tier
- AUTO (>=85%): all three layers score >0.7; no scale mismatch; direct map
- REVIEW (50-84%): semantic match is clear but name is abbreviated or transformed
- FLAG (<50%): ambiguous target, scale mismatch present, or no clear target

### 7.5 IS_NEW_ATTRIBUTE determination
Mark IS_NEW_ATTRIBUTE = Y when:
- No column in the target entity matches the source concept even after vocabulary expansion
- The concept belongs to the right Service Domain but the attribute does not yet exist
- Example: CRED_SCORE_CHG maps to CustomerInsight but credit_score_movement column does not yet exist

### 7.6 IS_ENRICHMENT determination
Mark IS_ENRICHMENT = Y when:
- The source data adds to an existing entity rather than creating new entity rows
- The bureau feed always enriches existing Customer entities
- Contrast with a truly new source system that introduces new Loan or Property rows
