# Data Dictionary — Freddie Mac Single Family Monthly Performance

**Source System:** Loan Servicing System  
**File:** `freddie_performance.csv`  
**Delimiter:** Pipe (`|`)  
**Header Row:** None — columns are positional (order below is authoritative)  
**Encoding:** UTF-8  
**Grain:** One row per loan per reporting month  
**Download:** https://www.freddiemac.com/research/datasets/sf-loanlevel-dataset

## Overview

The monthly performance file contains the repayment history and servicing events
for each loan across its lifetime. This is the primary source for churn signals
(delinquency escalation, modification, prepayment) and fraud indicators
(zero balance code patterns, unusual modification sequences).

## Columns

| Position | Column Name | Type | Nullable | Description |
|----------|-------------|------|----------|-------------|
| 1 | LOAN_SEQUENCE_NUMBER | CHAR(12) | N | Foreign key to origination file. Unique loan identifier. |
| 2 | MONTHLY_REPORTING_PERIOD | CHAR(6) | N | Reporting month. Format: YYYYMM. |
| 3 | CURRENT_ACTUAL_UPB | DECIMAL(15,2) | Y | Current unpaid principal balance as of the reporting period. Zero when loan has reached zero balance. |
| 4 | CURRENT_LOAN_DELINQUENCY_STATUS | CHAR(3) | Y | Current delinquency status. 0=Current, 1=30 days, 2=60 days, 3=90 days, 4=120 days, 5=150 days, 6=180 days+, RA=REO Acquisition. |
| 5 | LOAN_AGE | INTEGER | Y | Number of months since origination. |
| 6 | REMAINING_MONTHS_TO_MATURITY | INTEGER | Y | Remaining months until scheduled maturity. |
| 7 | REPURCHASE_DATE | CHAR(6) | Y | Date the loan was repurchased by the seller. Format: YYYYMM. Null if not repurchased. |
| 8 | MODIFICATION_FLAG | CHAR(1) | Y | Indicates if loan was modified in the reporting period. Y=Modified, N=Not Modified. |
| 9 | ZERO_BALANCE_CODE | CHAR(2) | Y | Code indicating reason for zero balance. 01=Prepaid/Matured, 02=Third Party Sale, 03=Short Sale, 06=Repurchase, 09=REO Disposition, 15=Note Sale, 16=Reperforming Loan Sale. Null if UPB > 0. |
| 10 | ZERO_BALANCE_EFFECTIVE_DATE | CHAR(6) | Y | Month the loan balance reached zero. Format: YYYYMM. |
| 11 | CURRENT_INTEREST_RATE | DECIMAL(6,3) | Y | Current interest rate as of the reporting period. May differ from origination rate for ARMs or modified loans. |
| 12 | CURRENT_DEFERRED_UPB | DECIMAL(15,2) | Y | Amount of principal deferred under a loan modification or forbearance. |
| 13 | DUE_DATE_LAST_PAID_INSTALL | CHAR(6) | Y | Due date of the last paid installment. Null if no payment history. |
| 14 | MI_RECOVERIES | DECIMAL(15,2) | Y | Mortgage insurance proceeds received as of the reporting period. |
| 15 | NET_SALES_PROCEEDS | DECIMAL(15,2) | Y | Net proceeds from property sale (used for loss calculation). |
| 16 | NON_MI_RECOVERIES | DECIMAL(15,2) | Y | Recoveries not from MI (e.g. guaranty, recourse). |
| 17 | EXPENSES | DECIMAL(15,2) | Y | Total expenses incurred (legal, maintenance, etc.) on defaulted loan. |
| 18 | LEGAL_COSTS | DECIMAL(15,2) | Y | Legal fees incurred in default/foreclosure proceedings. |
| 19 | MAINTENANCE_PRESERVATION_COSTS | DECIMAL(15,2) | Y | Property maintenance and preservation costs post-default. |
| 20 | TAXES_AND_INSURANCE | DECIMAL(15,2) | Y | Property taxes and insurance paid by servicer. |
| 21 | MISCELLANEOUS_EXPENSES | DECIMAL(15,2) | Y | Other miscellaneous expenses not captured above. |
| 22 | ACTUAL_LOSS_CALCULATION | DECIMAL(15,2) | Y | Calculated net loss on the loan. |
| 23 | MODIFICATION_COST | DECIMAL(15,2) | Y | Cost of loan modification. |
| 24 | STEP_MODIFICATION_FLAG | CHAR(1) | Y | Indicates a step-rate modification. Y=Step modification, N=Not. |
| 25 | DEFERRED_PAYMENT_PLAN | CHAR(1) | Y | Indicates an active deferred payment arrangement. Y=Active, N=Not active. |
| 26 | ESTIMATED_LOAN_TO_VALUE | DECIMAL(6,3) | Y | Estimated current LTV based on updated property value model. |
| 27 | ZERO_BALANCE_REMOVAL_UPB | DECIMAL(15,2) | Y | UPB at time of zero balance removal (reperforming loans). |
| 28 | DELINQUENT_ACCRUED_INTEREST | DECIMAL(15,2) | Y | Accrued interest on delinquent balance. |
| 29 | DELINQUENCY_DUE_TO_DISASTER | CHAR(1) | Y | Delinquency attributable to declared disaster. Y=Yes, N=No. |
| 30 | BORROWER_ASSISTANCE_STATUS | CHAR(2) | Y | Current borrower assistance status code. F=Forbearance, R=Repayment plan, T=Trial period plan, null=None. |
| 31 | CURRENT_MONTH_MODIFICATION_COST | DECIMAL(15,2) | Y | Modification cost incurred in the current reporting month only. |
| 32 | REPURCHASE_MAKE_WHOLE_PROCEEDS | DECIMAL(15,2) | Y | Proceeds received under a make-whole repurchase when a servicer repurchases a loan from Freddie Mac. Null for performing loans. Added in post-2019 dataset format. |

## Key Business Rules

- Grain is **loan × month** — `(LOAN_SEQUENCE_NUMBER, MONTHLY_REPORTING_PERIOD)` is the composite key
- `ZERO_BALANCE_CODE` is the primary churn signal: code 01 = voluntary prepayment (positive churn), codes 02/03/09 = default/distressed exit
- Escalating `CURRENT_LOAN_DELINQUENCY_STATUS` across consecutive periods is the primary early-warning churn signal
- `MODIFICATION_FLAG = 'Y'` with repeated delinquency patterns is a key fraud/stress indicator
- The performance file can be very large for full dataset; sample data covers ~50k loans × their full lifetime

## Domain Model Target Entities

| Source Column(s) | Target Entity | Notes |
|-----------------|---------------|-------|
| LOAN_SEQUENCE_NUMBER | Loan (FK) | Links to origination |
| MONTHLY_REPORTING_PERIOD, CURRENT_ACTUAL_UPB, CURRENT_INTEREST_RATE | LoanPerformance | Monthly snapshot |
| CURRENT_LOAN_DELINQUENCY_STATUS, ZERO_BALANCE_CODE | LoanEvent | Status change events |
| MODIFICATION_FLAG, STEP_MODIFICATION_FLAG, DEFERRED_PAYMENT_PLAN | LoanModification | Restructuring events |
| MI_RECOVERIES, NET_SALES_PROCEEDS, ACTUAL_LOSS_CALCULATION | LoanLoss | Credit loss tracking |
