"""
02_load_freddie_performance.py
Load the Freddie Mac Single Family Monthly Performance file into
MortgagePlatform_Staging.STG_Freddie_Performance.

Usage:
  python 02_load_freddie_performance.py [--limit N] [--chunksize N]
"""
import os
import sys
import argparse
import pandas as pd
from dotenv import load_dotenv
import teradataml as tdml

PERFORMANCE_COLUMNS = [
    "LOAN_SEQUENCE_NUMBER", "MONTHLY_REPORTING_PERIOD", "CURRENT_ACTUAL_UPB",
    "CURRENT_LOAN_DELINQUENCY_STATUS", "LOAN_AGE", "REMAINING_MONTHS_TO_MATURITY",
    "REPURCHASE_DATE", "MODIFICATION_FLAG", "ZERO_BALANCE_CODE",
    "ZERO_BALANCE_EFFECTIVE_DATE", "CURRENT_INTEREST_RATE", "CURRENT_DEFERRED_UPB",
    "DUE_DATE_LAST_PAID_INSTALL", "MI_RECOVERIES", "NET_SALES_PROCEEDS",
    "NON_MI_RECOVERIES", "EXPENSES", "LEGAL_COSTS",
    "MAINTENANCE_PRESERVATION_COSTS", "TAXES_AND_INSURANCE",
    "MISCELLANEOUS_EXPENSES", "ACTUAL_LOSS_CALCULATION", "MODIFICATION_COST",
    "STEP_MODIFICATION_FLAG", "DEFERRED_PAYMENT_PLAN", "ESTIMATED_LOAN_TO_VALUE",
    "ZERO_BALANCE_REMOVAL_UPB", "DELINQUENT_ACCRUED_INTEREST",
    "DELINQUENCY_DUE_TO_DISASTER", "BORROWER_ASSISTANCE_STATUS",
    "CURRENT_MONTH_MODIFICATION_COST", "REPURCHASE_MAKE_WHOLE_PROCEEDS",
]

INT_COLUMNS = {"LOAN_AGE", "REMAINING_MONTHS_TO_MATURITY"}

FLOAT_COLUMNS = {
    "CURRENT_ACTUAL_UPB", "CURRENT_INTEREST_RATE", "CURRENT_DEFERRED_UPB",
    "MI_RECOVERIES", "NET_SALES_PROCEEDS", "NON_MI_RECOVERIES", "EXPENSES",
    "LEGAL_COSTS", "MAINTENANCE_PRESERVATION_COSTS", "TAXES_AND_INSURANCE",
    "MISCELLANEOUS_EXPENSES", "ACTUAL_LOSS_CALCULATION", "MODIFICATION_COST",
    "ESTIMATED_LOAN_TO_VALUE", "ZERO_BALANCE_REMOVAL_UPB",
    "DELINQUENT_ACCRUED_INTEREST", "CURRENT_MONTH_MODIFICATION_COST",
    "REPURCHASE_MAKE_WHOLE_PROCEEDS",
}

NULL_SENTINELS = {"", " "}


def parse_str(raw):
    v = raw.strip() if isinstance(raw, str) else ""
    return None if not v else v


def parse_int(raw):
    v = raw.strip() if isinstance(raw, str) else ""
    if not v:
        return None
    try:
        return int(v)
    except (ValueError, TypeError):
        return None


def parse_float(raw):
    v = raw.strip() if isinstance(raw, str) else ""
    if not v:
        return None
    try:
        return float(v)
    except (ValueError, TypeError):
        return None


def normalise(df):
    for col in df.columns:
        if col in INT_COLUMNS:
            df[col] = [parse_int(x) for x in df[col]]
        elif col in FLOAT_COLUMNS:
            df[col] = [parse_float(x) for x in df[col]]
        else:
            df[col] = [parse_str(x) for x in df[col]]
    return df


def connect():
    load_dotenv()
    host = os.environ["TD_HOST"]
    user = os.environ["TD_USER"]
    password = os.environ["TD_PASSWORD"]
    logmech = os.environ.get("TD_LOGMECH", "TD2")
    tdml.create_context(host=host, username=user, password=password, logmech=logmech)
    print(f"Connected to {host}")


def load(limit=None, chunksize=50000):
    raw_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "raw", "freddie_performance.csv")
    )
    if not os.path.exists(raw_path):
        print(f"ERROR: Source file not found at {raw_path}")
        sys.exit(1)

    total_loaded = 0
    chunk_num = 0
    print(f"Reading {raw_path} in chunks of {chunksize:,} ...")

    for chunk in pd.read_csv(
        raw_path,
        sep="|",
        header=None,
        names=PERFORMANCE_COLUMNS,
        dtype=str,
        keep_default_na=False,
        chunksize=chunksize,
        nrows=limit,
    ):
        chunk_num += 1
        chunk = normalise(chunk)
        chunk = chunk[chunk["LOAN_SEQUENCE_NUMBER"].notna()]
        chunk = chunk[chunk["MONTHLY_REPORTING_PERIOD"].notna()]

        tdml.copy_to_sql(
            df=chunk,
            table_name="STG_Freddie_Performance",
            schema_name="MortgagePlatform_Staging",
            if_exists="append",
            index=False,
        )
        total_loaded += len(chunk)
        print(f"  Chunk {chunk_num}: {len(chunk):,} rows | Total: {total_loaded:,}")

    print(f"Done. {total_loaded:,} total rows loaded.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--chunksize", type=int, default=50000)
    args = parser.parse_args()
    connect()
    load(limit=args.limit, chunksize=args.chunksize)
