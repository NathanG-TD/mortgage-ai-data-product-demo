"""
01_load_freddie_origination.py
Load the Freddie Mac Single Family Origination file into
MortgagePlatform_Staging.STG_Freddie_Origination.

Prerequisites:
  - MortgagePlatform_Staging database created (00_setup/create_databases.sql)
  - STG_Freddie_Origination table created (00_create_staging_tables.sql)
  - Freddie Mac origination file placed at: ../raw/freddie_origination.csv
    (pipe-delimited, no header row — see data_dictionary/freddie_mac_origination.md)

Usage:
  python 01_load_freddie_origination.py [--limit N]

  --limit N   Load only the first N rows (useful for quick testing)
"""
import os
import sys
import argparse
import math
import pandas as pd
from dotenv import load_dotenv
import teradataml as tdml


def to_python(x):
    """Convert any pandas/numpy scalar to a native Python type or None.

    teradatasql infers batch parameter types from the first non-null value it
    sees per column. Any numpy type, pd.NA, pd.NaT, or float NaN that leaks
    through causes a batch type-mismatch error (Error 502). This function
    ensures every cell is a plain Python str/int/float or None before the
    DataFrame is handed to copy_to_sql.
    """
    if x is None or x is pd.NA or x is pd.NaT:
        return None
    if isinstance(x, float) and math.isnan(x):
        return None
    # Convert numpy scalars (int64, float64, bool_, etc.) to Python native
    if hasattr(x, "item"):
        return x.item()
    return x

# ---------------------------------------------------------------------------
# Column definitions — positional, matching Freddie Mac file layout exactly
# ---------------------------------------------------------------------------
ORIGINATION_COLUMNS = [
    "CREDIT_SCORE",
    "FIRST_PAYMENT_DATE",
    "FIRST_TIME_HOMEBUYER_FLAG",
    "MATURITY_DATE",
    "MSA",
    "MI_PERCENTAGE",
    "NUMBER_OF_UNITS",
    "OCCUPANCY_STATUS",
    "ORIG_CLTV",
    "ORIG_DTI",
    "ORIG_UPB",
    "ORIG_LTV",
    "ORIG_INTEREST_RATE",
    "CHANNEL",
    "PPM_FLAG",
    "AMORTIZATION_TYPE",
    "PROPERTY_STATE",
    "PROPERTY_TYPE",
    "POSTAL_CODE",
    "LOAN_SEQUENCE_NUMBER",
    "LOAN_PURPOSE",
    "ORIG_LOAN_TERM",
    "NUMBER_OF_BORROWERS",
    "SELLER_NAME",
    "SERVICER_NAME",
    "SUPER_CONFORMING_FLAG",
    "PRE_RELIEF_REFINANCE_LSN",
    # Columns 28-32: added in post-2018 Freddie Mac dataset format
    "PROGRAM_INDICATOR",
    "HARP_INDICATOR",
    "PROPERTY_VALUATION_METHOD",
    "INTEREST_ONLY_INDICATOR",
    "MI_CANCELLATION_INDICATOR",
]

DTYPE_MAP = {
    "CREDIT_SCORE": "Int64",
    "FIRST_PAYMENT_DATE": "str",
    "FIRST_TIME_HOMEBUYER_FLAG": "str",
    "MATURITY_DATE": "str",
    "MSA": "str",
    "MI_PERCENTAGE": "Int64",
    "NUMBER_OF_UNITS": "Int64",
    "OCCUPANCY_STATUS": "str",
    "ORIG_CLTV": "Int64",
    "ORIG_DTI": "Int64",
    "ORIG_UPB": "float64",
    "ORIG_LTV": "Int64",
    "ORIG_INTEREST_RATE": "float64",
    "CHANNEL": "str",
    "PPM_FLAG": "str",
    "AMORTIZATION_TYPE": "str",
    "PROPERTY_STATE": "str",
    "PROPERTY_TYPE": "str",
    "POSTAL_CODE": "str",
    "LOAN_SEQUENCE_NUMBER": "str",
    "LOAN_PURPOSE": "str",
    "ORIG_LOAN_TERM": "Int64",
    "NUMBER_OF_BORROWERS": "Int64",
    "SELLER_NAME": "str",
    "SERVICER_NAME": "str",
    "SUPER_CONFORMING_FLAG": "str",
    "PRE_RELIEF_REFINANCE_LSN": "str",
    "PROGRAM_INDICATOR": "str",
    "HARP_INDICATOR": "str",
    "PROPERTY_VALUATION_METHOD": "str",
    "INTEREST_ONLY_INDICATOR": "str",
    "MI_CANCELLATION_INDICATOR": "str",
}


def connect():
    load_dotenv()
    host = os.environ["TD_HOST"]
    user = os.environ["TD_USER"]
    password = os.environ["TD_PASSWORD"]
    logmech = os.environ.get("TD_LOGMECH", "TD2")
    tdml.create_context(host=host, username=user, password=password, logmech=logmech)
    print(f"Connected to {host}")


def load(limit: int | None = None):
    raw_path = os.path.join(os.path.dirname(__file__), "..", "raw", "freddie_origination.csv")
    raw_path = os.path.abspath(raw_path)

    if not os.path.exists(raw_path):
        print(f"ERROR: Source file not found at {raw_path}")
        print("Please download the Freddie Mac sample data and place it as:")
        print("  01_source_data/raw/freddie_origination.csv")
        print("See: 01_source_data/data_dictionary/freddie_mac_origination.md")
        sys.exit(1)

    print(f"Reading {raw_path} ...")
    df = pd.read_csv(
        raw_path,
        sep="|",
        header=None,
        names=ORIGINATION_COLUMNS,
        dtype=DTYPE_MAP,
        na_values=["", " ", "9", "999", "9999"],
        keep_default_na=True,
        nrows=limit,
    )
    print(f"  Rows read: {len(df):,}")

    # Normalise all cells to native Python types or None.
    # Step 1: astype(object) breaks out of pandas special dtypes (StringDtype,
    #   Int64, Float64) so that None/NaN values are plain float('nan') in
    #   object columns — not pd.NA which materialises as float when iterated.
    # Step 2: to_python converts every remaining float nan to Python None and
    #   unwraps any residual numpy scalars.
    df = df.astype(object)
    for col in df.columns:
        df[col] = df[col].apply(to_python)

    # Remove rows with no loan sequence number (should not occur, but defensive)
    df = df.dropna(subset=["LOAN_SEQUENCE_NUMBER"])
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
    parser.add_argument("--limit", type=int, default=None, help="Load only first N rows")
    args = parser.parse_args()

    connect()
    load(limit=args.limit)
