# Data Dictionary — Freddie Mac Single Family Origination

**Source System:** Loan Origination System (LOS)  
**File:** `freddie_origination.csv`  
**Delimiter:** Pipe (`|`)  
**Header Row:** None — columns are positional (order below is authoritative)  
**Encoding:** UTF-8  
**Download:** https://www.freddiemac.com/research/datasets/sf-loanlevel-dataset

## Overview

The origination file contains one record per loan, capturing the loan's characteristics
at the time of origination. This is the primary source for Loan and Borrower entity
attributes in the enterprise domain model.

## Columns

| Position | Column Name | Type | Nullable | Description |
|----------|-------------|------|----------|-------------|
| 1 | CREDIT_SCORE | INTEGER | Y | Borrower credit score at origination (FICO). Range 300–850. Null if not available or if multiple borrowers and score not disclosed. |
| 2 | FIRST_PAYMENT_DATE | CHAR(6) | Y | Date of first scheduled payment. Format: YYYYMM. |
| 3 | FIRST_TIME_HOMEBUYER_FLAG | CHAR(1) | Y | Indicates if borrower is a first-time homebuyer. Y=Yes, N=No, 9=Not Available. |
| 4 | MATURITY_DATE | CHAR(6) | Y | Month and year the loan is scheduled to mature. Format: YYYYMM. |
| 5 | MSA | CHAR(5) | Y | Metropolitan Statistical Area code for the property. Null if not in an MSA. |
| 6 | MI_PERCENTAGE | INTEGER | Y | Mortgage Insurance percentage. 0 if no MI. Range 1–55. |
| 7 | NUMBER_OF_UNITS | INTEGER | Y | Number of dwelling units in the mortgaged property. 1=Single family, 2/3/4=Multi-unit. |
| 8 | OCCUPANCY_STATUS | CHAR(1) | Y | Occupancy status at origination. P=Primary Residence, S=Second Home, I=Investment Property. |
| 9 | ORIG_CLTV | INTEGER | Y | Original Combined Loan-to-Value ratio. Calculated as sum of all mortgage liens at origination divided by property value. |
| 10 | ORIG_DTI | INTEGER | Y | Original Debt-to-Income ratio. Monthly debt obligations divided by gross monthly income at origination. |
| 11 | ORIG_UPB | DECIMAL(15,2) | Y | Original Unpaid Principal Balance — the face amount of the loan at origination. |
| 12 | ORIG_LTV | INTEGER | Y | Original Loan-to-Value ratio. Loan amount divided by appraised property value at origination. |
| 13 | ORIG_INTEREST_RATE | DECIMAL(6,3) | Y | Original interest rate on the note (percentage). |
| 14 | CHANNEL | CHAR(1) | Y | Origination channel. R=Retail, B=Broker, C=Correspondent, T=TPO Not Specified. |
| 15 | PPM_FLAG | CHAR(1) | Y | Prepayment Penalty Mortgage flag. Y=PPM, N=Not PPM. |
| 16 | AMORTIZATION_TYPE | CHAR(5) | Y | Amortisation type. FRM=Fixed Rate Mortgage, ARM=Adjustable Rate Mortgage. |
| 17 | PROPERTY_STATE | CHAR(2) | Y | Two-letter US state abbreviation of the mortgaged property. |
| 18 | PROPERTY_TYPE | CHAR(2) | Y | Property type code. SF=Single Family, CO=Condominium, PU=Planned Unit Development, MH=Manufactured Home, CP=Co-operative, LH=Leasehold. |
| 19 | POSTAL_CODE | CHAR(5) | Y | Three-digit postal code prefix of the property. Truncated to 3 digits for privacy. |
| 20 | LOAN_SEQUENCE_NUMBER | CHAR(12) | N | Unique identifier for the loan. Primary key. Format: FddQqNNNNNN (F=Freddie, dd=vintage year, Q=quarter, q=quarter number, NNNNNN=sequence). |
| 21 | LOAN_PURPOSE | CHAR(1) | Y | Purpose of the loan. P=Purchase, C=Cash-out Refinance, N=No Cash-out Refinance, U=Unknown. |
| 22 | ORIG_LOAN_TERM | INTEGER | Y | Original loan term in months (e.g. 360 = 30-year, 180 = 15-year). |
| 23 | NUMBER_OF_BORROWERS | INTEGER | Y | Number of borrowers on the loan. |
| 24 | SELLER_NAME | VARCHAR(60) | Y | Name of the entity that sold the loan to Freddie Mac. |
| 25 | SERVICER_NAME | VARCHAR(60) | Y | Name of the entity currently servicing the loan. |
| 26 | SUPER_CONFORMING_FLAG | CHAR(1) | Y | Indicates super-conforming mortgage. Y=Super Conforming, N=Not Super Conforming. |
| 27 | PRE_RELIEF_REFINANCE_LSN | CHAR(12) | Y | Loan Sequence Number of the prior loan if this is a Relief Refinance loan. Null otherwise. |
| 28 | PROGRAM_INDICATOR | CHAR(1) | Y | Freddie Mac affordable lending program indicator. H=Home Possible. Null if standard loan. |
| 29 | HARP_INDICATOR | CHAR(1) | Y | Home Affordable Refinance Program indicator. Y=HARP loan. Null if not a HARP refinance. |
| 30 | PROPERTY_VALUATION_METHOD | CHAR(1) | Y | Valuation method. 1=ACE (no appraisal), 2=Traditional appraisal, 3=ACE+ PDR. |
| 31 | INTEREST_ONLY_INDICATOR | CHAR(1) | Y | Y=Interest-only period applies, N=Fully amortising. |
| 32 | MI_CANCELLATION_INDICATOR | CHAR(1) | Y | Mortgage Insurance cancellation status indicator. See Freddie Mac data dictionary for current code values. |

## Key Business Rules

- `LOAN_SEQUENCE_NUMBER` is the primary join key across all source files
- `ORIG_CLTV` ≠ `ORIG_LTV` when there are subordinate liens; CLTV is always ≥ LTV
- `CREDIT_SCORE` reflects the representative borrower score per Freddie Mac guidelines — for multi-borrower loans this is typically the lower of the two scores
- Freddie Mac data represents US mortgages; the synthetic files adapt column semantics to an Australian bank context

## Domain Model Target Entities

| Source Column(s) | Target Entity | Target Attribute |
|-----------------|---------------|-----------------|
| LOAN_SEQUENCE_NUMBER | Loan | loan_reference_number |
| ORIG_UPB, ORIG_LTV, ORIG_CLTV, ORIG_DTI | Loan | origination attributes |
| CREDIT_SCORE | Borrower | credit_score_at_origination |
| FIRST_TIME_HOMEBUYER_FLAG, NUMBER_OF_BORROWERS | Borrower | borrower attributes |
| PROPERTY_STATE, PROPERTY_TYPE, POSTAL_CODE | Property | property attributes |
| ORIG_INTEREST_RATE, AMORTIZATION_TYPE, ORIG_LOAN_TERM | LoanProduct | product attributes |
