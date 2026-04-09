"""
01_generate_bureau_feed.py
Generate synthetic Credit Bureau Feed records for the withheld demo source.

Reads CUSTOMER_ID values from STG_Borrower_Profile to ensure consistent
join keys. Introduces deliberate semantic complexity:
  - Equifax 0–1200 score scale (vs FICO 300–850 in origination file)
  - Abbreviated/cryptic column names matching real bureau extract conventions
  - Correlated fraud and churn signals on ~5% of customers
  - Regulated attributes (bankruptcy, Part IX) on ~1% of customers

Output: 08_withheld_source/bureau_feed.csv (gitignored)

Prerequisites:
  - STG_Borrower_Profile must be loaded

Usage:
  python 08_withheld_source/01_generate_bureau_feed.py [--seed N]
"""
import os
import sys
import random
import argparse
import pandas as pd
from datetime import date, timedelta
from faker import Faker
from dotenv import load_dotenv
import teradataml as tdml

fake = Faker("en_AU")

BUREAU_PROVIDERS = ["EQX", "ILL", "EXP"]
BUREAU_WEIGHTS = [0.60, 0.25, 0.15]

SCORE_BANDS = {
    (833, 1200): "EX",
    (726, 832): "VG",
    (622, 725): "GD",
    (510, 621): "AV",
    (0, 509): "BW",
}


def score_to_band(score: int) -> str:
    for (lo, hi), band in SCORE_BANDS.items():
        if lo <= score <= hi:
            return band
    return "BW"


def connect():
    load_dotenv()
    host = os.environ["TD_HOST"]
    user = os.environ["TD_USER"]
    password = os.environ["TD_PASSWORD"]
    logmech = os.environ.get("TD_LOGMECH", "TD2")
    tdml.create_context(host=host, username=user, password=password, logmech=logmech)
    print(f"Connected to {host}")


def fetch_customers() -> list[str]:
    print("Fetching CUSTOMER_IDs from STG_Borrower_Profile ...")
    result = tdml.execute_sql(
        "SELECT CUSTOMER_ID FROM MortgagePlatform_Staging.STG_Borrower_Profile"
    )
    ids = [row[0].strip() for row in result if row[0]]
    print(f"  Found {len(ids):,} customers")
    return ids


def generate_record(customer_id: str, idx: int) -> dict:
    rng = random.Random(hash(customer_id + "_bureau"))
    fake_local = Faker("en_AU")
    fake_local.seed_instance(hash(customer_id + "_bureau"))

    # Flag ~5% as stressed/fraud signal customers
    is_stressed = rng.random() < 0.05
    # Flag ~1% as seriously impaired
    is_impaired = rng.random() < 0.01

    # Credit score — Equifax 0–1200 scale
    if is_impaired:
        score_curr = rng.randint(0, 400)
    elif is_stressed:
        score_curr = rng.randint(300, 620)
    else:
        score_curr = rng.randint(500, 1050)

    score_prev = max(0, score_curr + rng.randint(-120, 80))
    score_chg = score_curr - score_prev

    enquiry_date = fake_local.date_between(start_date="-90d", end_date="today")
    refresh_date = enquiry_date

    # Enquiry counts — stressed customers have more
    enq_3m = rng.randint(5, 15) if is_stressed else rng.randint(0, 3)
    enq_6m = enq_3m + rng.randint(0, 5)
    enq_12m = enq_6m + rng.randint(0, 8)
    enq_mortgage_3m = rng.randint(0, 3) if not is_stressed else rng.randint(1, 5)

    total_accounts = rng.randint(3, 20)
    open_accounts = rng.randint(1, total_accounts)
    credit_limit = round(rng.uniform(5_000, 80_000), -2)
    credit_balance = round(credit_limit * rng.uniform(0.1, 0.95 if is_stressed else 0.6), -2)
    credit_util = round(credit_balance / credit_limit, 4) if credit_limit > 0 else 0

    mortgage_balance = round(rng.uniform(200_000, 900_000), -3)

    num_defaults = rng.randint(1, 4) if is_impaired else (1 if is_stressed and rng.random() < 0.3 else 0)
    default_amt = round(rng.uniform(500, 15_000) * num_defaults, 2) if num_defaults > 0 else 0

    num_judgements = rng.randint(1, 2) if is_impaired and rng.random() < 0.4 else 0
    judgement_amt = round(rng.uniform(1_000, 25_000), 2) if num_judgements > 0 else 0

    bankruptcy = "Y" if is_impaired and rng.random() < 0.2 else "N"
    bankruptcy_date = fake_local.date_between(start_date="-10y", end_date="-1y").isoformat() if bankruptcy == "Y" else None
    part_ix = "Y" if (not bankruptcy == "Y") and is_impaired and rng.random() < 0.15 else "N"

    serious_impairment = "Y" if (num_defaults > 0 or num_judgements > 0 or bankruptcy == "Y") else "N"

    repmt_hist = rng.randint(0, 40) if is_impaired else (rng.randint(30, 70) if is_stressed else rng.randint(60, 100))
    derog_marks = num_defaults + num_judgements + (1 if bankruptcy == "Y" else 0)

    file_age = rng.randint(24, 360)
    credit_active_since = (date.today() - timedelta(days=file_age * 30)).isoformat()

    bureau_id = f"BUR-{enquiry_date.strftime('%Y%m%d')}-{idx:010d}"

    return {
        "BUREAU_RECORD_ID": bureau_id,
        "CUSTOMER_ID": customer_id,
        "BUREAU_ENQUIRY_DATE": enquiry_date.isoformat(),
        "BUREAU_PROVIDER_CODE": rng.choices(BUREAU_PROVIDERS, BUREAU_WEIGHTS)[0],
        "CRED_SCORE_CURR": score_curr,
        "CRED_SCORE_PREV": score_prev,
        "CRED_SCORE_CHG": score_chg,
        "CRED_SCORE_BAND": score_to_band(score_curr),
        "FILE_AGE_MONTHS": file_age,
        "ENQ_3M": enq_3m,
        "ENQ_6M": enq_6m,
        "ENQ_12M": enq_12m,
        "ENQ_MORTGAGE_3M": enq_mortgage_3m,
        "TOTAL_ACCOUNTS": total_accounts,
        "OPEN_ACCOUNTS": open_accounts,
        "CREDIT_LIMIT_TOTAL": credit_limit,
        "CREDIT_BALANCE_TOTAL": credit_balance,
        "CREDIT_UTIL_RATIO": credit_util,
        "MORTGAGE_BALANCE_TOTAL": mortgage_balance,
        "NUM_DEFAULTS": num_defaults,
        "DEFAULT_AMT_TOTAL": default_amt,
        "NUM_JUDGEMENTS": num_judgements,
        "JUDGEMENT_AMT_TOTAL": judgement_amt,
        "BANKRUPTCY_FLAG": bankruptcy,
        "BANKRUPTCY_DATE": bankruptcy_date,
        "PART_IX_FLAG": part_ix,
        "SERIOUS_CREDIT_IMPAIRMENT": serious_impairment,
        "REPMT_HIST_SCORE": repmt_hist,
        "DEROG_MARKS": derog_marks,
        "CREDIT_ACTIVE_SINCE": credit_active_since,
        "BUREAU_REFRESH_DATE": refresh_date.isoformat(),
        "DATA_SUPPLIER_CODE": f"EQX-ANZ-{rng.randint(1,3):03d}",
    }


def generate(seed: int = 42):
    random.seed(seed)

    load_dotenv()
    host = os.environ.get("TD_HOST")
    if host:
        connect()
        customer_ids = fetch_customers()
    else:
        print("No TD_HOST set — generating 1000 sample records with synthetic IDs")
        customer_ids = [f"CUS-{i:08d}" for i in range(1, 1001)]

    print(f"Generating {len(customer_ids):,} bureau records ...")
    records = [generate_record(cid, i + 1) for i, cid in enumerate(customer_ids)]
    df = pd.DataFrame(records)

    out_path = os.path.join(os.path.dirname(__file__), "bureau_feed.csv")
    df.to_csv(out_path, index=False)
    print(f"  Written to {out_path} ({len(df):,} rows)")

    # Summary of fraud/stress signals
    stressed = df[df["CRED_SCORE_CURR"] < 510]
    impaired = df[df["SERIOUS_CREDIT_IMPAIRMENT"] == "Y"]
    print(f"\n  Signal summary:")
    print(f"    Below-average credit score (<510): {len(stressed):,} ({len(stressed)/len(df)*100:.1f}%)")
    print(f"    Seriously impaired:                {len(impaired):,} ({len(impaired)/len(df)*100:.1f}%)")
    print(f"    Bankruptcies:                      {(df['BANKRUPTCY_FLAG']=='Y').sum():,}")
    print(f"    Score drop > 50 pts:               {(df['CRED_SCORE_CHG'] < -50).sum():,}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    generate(seed=args.seed)
