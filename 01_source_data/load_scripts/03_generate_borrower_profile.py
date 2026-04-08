"""
03_generate_borrower_profile.py
Generate synthetic Borrower Profile (CRM) records and load into
MortgagePlatform_Staging.STG_Borrower_Profile.

Reads LOAN_SEQUENCE_NUMBER values from STG_Freddie_Origination to ensure
one customer record per loan with a consistent join key.

Prerequisites:
  - STG_Freddie_Origination must be loaded first
  - STG_Borrower_Profile table must exist

Usage:
  python 03_generate_borrower_profile.py [--seed N]
"""
import os
import random
import argparse
import pandas as pd
import numpy as np
from datetime import date, timedelta
from faker import Faker
from dotenv import load_dotenv
import teradataml as tdml

fake = Faker("en_AU")

# Australian states — weighted to reflect realistic population distribution
AU_STATES = ["NSW", "VIC", "QLD", "WA", "SA", "TAS", "ACT", "NT"]
AU_STATE_WEIGHTS = [0.32, 0.26, 0.20, 0.11, 0.07, 0.02, 0.02, 0.01]

SEGMENTS = ["Mass Market", "Emerging Affluent", "Affluent", "Private Banking", "Business Owner"]
SEGMENT_WEIGHTS = [0.45, 0.30, 0.18, 0.04, 0.03]

EMPLOYMENT_STATUSES = ["Full-time", "Part-time", "Self-employed", "Contractor", "Retired"]
EMPLOYMENT_WEIGHTS = [0.55, 0.15, 0.15, 0.10, 0.05]

CITIZENSHIP = ["Citizen", "Permanent Resident", "Temporary Resident"]
CITIZENSHIP_WEIGHTS = [0.80, 0.14, 0.06]

CONTACT_CHANNELS = ["Email", "Mobile", "Post", "Branch"]
CONTACT_WEIGHTS = [0.55, 0.30, 0.08, 0.07]


def connect():
    load_dotenv()
    host = os.environ["TD_HOST"]
    user = os.environ["TD_USER"]
    password = os.environ["TD_PASSWORD"]
    logmech = os.environ.get("TD_LOGMECH", "TD2")
    tdml.create_context(host=host, username=user, password=password, logmech=logmech)
    print(f"Connected to {host}")


def fetch_loan_sequence_numbers() -> list[str]:
    print("Fetching LOAN_SEQUENCE_NUMBERs from STG_Freddie_Origination ...")
    # Use execute_sql to avoid teradataml column-casing differences across versions
    result = tdml.execute_sql(
        "SELECT LOAN_SEQUENCE_NUMBER FROM MortgagePlatform_Staging.STG_Freddie_Origination"
    )
    lsns = [row[0].strip() for row in result if row[0]]
    print(f"  Found {len(lsns):,} loans")
    return lsns


def generate_record(lsn: str, idx: int) -> dict:
    rng = random.Random(hash(lsn))
    fake_local = Faker("en_AU")
    fake_local.seed_instance(hash(lsn))

    customer_id = f"CUS-{idx:08d}"
    dob = fake_local.date_of_birth(minimum_age=22, maximum_age=75)
    rel_start = fake_local.date_between(start_date=date(2000, 1, 1), end_date=date(2023, 12, 31))
    state = rng.choices(AU_STATES, AU_STATE_WEIGHTS)[0]
    segment = rng.choices(SEGMENTS, SEGMENT_WEIGHTS)[0]
    employment = rng.choices(EMPLOYMENT_STATUSES, EMPLOYMENT_WEIGHTS)[0]

    # Income generation — correlated with segment
    income_bases = {
        "Mass Market": (55_000, 30_000),
        "Emerging Affluent": (110_000, 40_000),
        "Affluent": (200_000, 80_000),
        "Private Banking": (500_000, 200_000),
        "Business Owner": (180_000, 120_000),
    }
    base, spread = income_bases[segment]
    annual_income = float(max(30_000, round(rng.gauss(base, spread / 2), -3)))

    kyc_status = rng.choices(["Verified", "Pending", "Expired"], [0.88, 0.07, 0.05])[0]
    aml_rating = rng.choices(["L", "M", "H"], [0.75, 0.22, 0.03])[0]
    churn_score = round(rng.betavariate(1.5, 5), 2)
    if churn_score < 0.30:
        churn_band = "Low"
    elif churn_score < 0.60:
        churn_band = "Medium"
    else:
        churn_band = "High"

    digital_enrolled = rng.choices(["Y", "N"], [0.78, 0.22])[0]
    last_login = None
    if digital_enrolled == "Y":
        last_login = fake_local.date_between(start_date="-180d", end_date="today")

    rm_id = None
    if segment in ("Affluent", "Private Banking"):
        rm_id = f"EMP-{rng.randint(1000, 9999)}"

    return {
        "CUSTOMER_ID": customer_id,
        "LOAN_SEQUENCE_NUMBER": lsn,
        "CUSTOMER_TITLE": rng.choice(["Mr", "Mrs", "Ms", "Dr", None, None]),
        "FIRST_NAME": fake_local.first_name(),
        "LAST_NAME": fake_local.last_name(),
        "DATE_OF_BIRTH": dob.isoformat(),
        "GENDER": rng.choices(["M", "F", "X"], [0.49, 0.49, 0.02])[0],
        "EMAIL_ADDRESS": fake_local.email(),
        "MOBILE_NUMBER": fake_local.phone_number(),
        "HOME_PHONE": fake_local.phone_number() if rng.random() < 0.4 else None,
        "ADDRESS_LINE_1": fake_local.street_address(),
        "ADDRESS_LINE_2": None,
        "SUBURB": fake_local.city(),
        "STATE": state,
        "POSTCODE": fake_local.postcode(),
        "CUSTOMER_SEGMENT": segment,
        "RELATIONSHIP_START_DATE": rel_start.isoformat(),
        "PREFERRED_CONTACT_CHANNEL": rng.choices(CONTACT_CHANNELS, CONTACT_WEIGHTS)[0],
        "DIGITAL_BANKING_ENROLLED": digital_enrolled,
        "DIGITAL_BANKING_LAST_LOGIN": last_login.isoformat() if last_login else None,
        "BRANCH_CODE": f"BR{rng.randint(100,999)}" if rng.random() < 0.5 else None,
        "RELATIONSHIP_MANAGER_ID": rm_id,
        "ANNUAL_INCOME": annual_income,
        "INCOME_VERIFIED_FLAG": rng.choices(["Y", "N"], [0.70, 0.30])[0],
        "EMPLOYMENT_STATUS": employment,
        "EMPLOYER_NAME": fake_local.company() if employment not in ("Retired", "Self-employed") else None,
        "YEARS_WITH_EMPLOYER": round(rng.uniform(0.5, 25.0), 1) if employment != "Retired" else None,
        "CITIZENSHIP_STATUS": rng.choices(CITIZENSHIP, CITIZENSHIP_WEIGHTS)[0],
        "KYC_STATUS": kyc_status,
        "KYC_VERIFICATION_DATE": fake_local.date_between(start_date="-3y", end_date="today").isoformat() if kyc_status == "Verified" else None,
        "AML_RISK_RATING": aml_rating,
        "LAST_CONTACT_DATE": fake_local.date_between(start_date="-365d", end_date="today").isoformat(),
        "NPS_SCORE": rng.randint(-100, 100),
        "CHURN_RISK_SCORE": churn_score,
        "CHURN_RISK_BAND": churn_band,
        "MARKETING_OPT_IN": rng.choices(["Y", "N"], [0.65, 0.35])[0],
        "DECEASED_FLAG": rng.choices(["Y", "N"], [0.001, 0.999])[0],
        "RECORD_CREATED_DATE": rel_start.isoformat(),
        "RECORD_LAST_UPDATED": fake_local.date_between(start_date=rel_start, end_date="today").isoformat(),
    }


def generate_and_load(seed: int = 42):
    load_dotenv()
    host     = os.environ["TD_HOST"]
    user     = os.environ["TD_USER"]
    password = os.environ["TD_PASSWORD"]
    logmech  = os.environ.get("TD_LOGMECH", "TD2")

    random.seed(seed)
    lsns = fetch_loan_sequence_numbers()

    print(f"Generating {len(lsns):,} borrower profile records ...")
    records = [generate_record(lsn, i + 1) for i, lsn in enumerate(lsns)]
    print(f"  Generated {len(records):,} records")

    # Build ordered column list and tuple rows — bypasses pandas to avoid
    # None→NaN coercion that causes teradatasql batch type-mismatch errors
    columns = list(records[0].keys())
    rows = [tuple(r[c] for c in columns) for r in records]

    cols    = ", ".join(columns)
    holders = ", ".join(["?"] * len(columns))
    sql     = (f"INSERT INTO MortgagePlatform_Staging.STG_Borrower_Profile"
               f" ({cols}) VALUES ({holders})")

    import json, teradatasql
    con_params = json.dumps({"host": host, "user": user, "password": password, "logmech": logmech})

    print("Loading into MortgagePlatform_Staging.STG_Borrower_Profile ...")
    batch_size = 5000
    with teradatasql.connect(con_params) as con:
        with con.cursor() as cur:
            for start in range(0, len(rows), batch_size):
                cur.executemany(sql, rows[start:start + batch_size])
            con.commit()
    print(f"  Done. {len(rows):,} rows loaded.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=42, help="Random seed for reproducibility")
    args = parser.parse_args()

    connect()
    generate_and_load(seed=args.seed)
