"""
01_load_freddie_origination.py
Load the Freddie Mac Single Family Origination file into
MortgagePlatform_Staging.STG_Freddie_Origination.

Prerequisites:
  - MortgagePlatform_Staging database created (00_setup/create_databases.sql)
  - STG_Freddie_Origination table created (00_create_staging_tables.sql)
  - Freddie Mac origination file placed at: ../raw/freddie_origination.csv
    (pipe-delimited, no header row)

Usage:
  python 01_load_freddie_origination.py [--limit N]
"""
import os
import sys
import argparse
import pandas as pd
from dotenv import load_dotenv
import teradataml as tdml

# ---------------------------------------------------------------------------
# Column definitions — positional, matching Freddie Mac file layout exactly
# ---------------------------------------------------------------------------
ORIGINATION_COLUMNS = [
    "CREDIT_SCORE", "FIRST_PAYMENT_DATE", "FIRST_TIME_HOMEBUYER_FLAG",
    "MATURITY_DATE", "MSA", "MI_PERCENTAGE", "NUMBER_OF_UNITS",
    "OCCUPANCY_STATUS", "ORIG_CLTV", "ORIG_DTI", "ORIG_UPB", "ORIG_LTV",
    "ORIG_INTEREST_RATE", "CHANNEL", "PPM_FLAG", "AMORTIZATION_TYPE",
    "PROPERTY_STATE", "PROPERTY_TYPE", "POSTAL_CODE", "LOAN_SEQUENCE_NUMBER",
    "LOAN_PURPOSE", "ORIG_LOAN_TERM", "NUMBER_OF_BORROWERS",
    "SELLER_NAME", "SERVICER_NAME", "SUPER_CONFORMING_FLAG",
    "PRE_RELIEF_REFINANCE_LSN",
    "PROGRAM_INDICATOR", "HARP_INDICATOR", "PROPERTY_VALUATION_METHOD",
    "INTEREST_ONLY_INDICATOR", "MI_CANCELLATION_INDICATOR",
]

INT_COLUMNS = {
    "CREDIT_SCORE", "MI_PERCENTAGE", "NUMBER_OF_UNITS",
    "ORIG_CLTV", "ORIG_DTI", "ORIG_LTV",
    "ORIG_LOAN_TERM", "NUMBER_OF_BORROWERS",
}

FLOAT_COLUMNS = {"ORIG_UPB", "ORIG_INTEREST_RATE"}

# Exact string values treated as NULL
NULL_SENTINELS = {"", " ", "9", "999", "9999"}


def parse_str(raw):
    v = raw.strip() if isinstance(raw, str) else ""
    return None if v in NULL_SENTINELS else (v if v else None)


def parse_int(raw):
    v = raw.strip() if isinstance(raw, str) else ""
    if v in NULL_SENTINELS:
        return None
    try:
        return int(v)
    except (ValueError, TypeError):
        return None


def parse_float(raw):
    v = raw.strip() if isinstance(raw, str) else ""
    if v in NULL_SENTINELS:
        return None
    try:
        return float(v)
    except (ValueError, TypeError):
        return None


def normalise(df):
    """Convert all columns to native Python str/int/float/None only."""
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


def load(limit=None):
    raw_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "raw", "freddie_origination.csv")
    )
    if not os.path.exists(raw_path):
        print(f"ERROR: Source file not found at {raw_path}")
        sys.exit(1)

    print(f"Reading {raw_path} ...")
    df = pd.read_csv(
        raw_path,
        sep="|",
        header=None,
        names=ORIGINATION_COLUMNS,
        dtype=str,              # everything comes in as plain Python str
        keep_default_na=False,  # no automatic NaN conversion
        nrows=limit,
    )
    print(f"  Rows read: {len(df):,}")

    df = normalise(df)

    df = df[df["LOAN_SEQUENCE_NUMBER"].notna()]
    print(f"  Rows after null-key drop: {len(df):,}")

    print("Loading into MortgagePlatform_Staging.STG_Freddie_Origination ...")
    tdml.copy_to_sql(
        df=df,
        table_name="STG_Freddie_Origination",
        schema_name="MortgagePlatform_Staging",
        if_exists="append",
        index=False,
    )
    print(f"  Done. {len(df):,} rows loaded.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()
    connect()
    load(limit=args.limit)
