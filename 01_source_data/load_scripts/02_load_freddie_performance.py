"""
02_load_freddie_performance.py
Load the Freddie Mac Single Family Monthly Performance file into
MortgagePlatform_Staging.STG_Freddie_Performance.

Prerequisites:
  - MortgagePlatform_Staging database created
  - STG_Freddie_Performance table created
  - Freddie Mac performance file placed at: ../raw/freddie_performance.csv
    (pipe-delimited, no header row)
  - STG_Freddie_Origination must be loaded first (join key reference)

Usage:
  python 02_load_freddie_performance.py [--limit N] [--chunksize N]

  --limit N      Load only first N rows
  --chunksize N  Rows per batch (default 50000; reduce if memory-constrained)
"""
import os
import sys
import argparse
import pandas as pd
from dotenv import load_dotenv
import teradataml as tdml

PERFORMANCE_COLUMNS = [
    "LOAN_SEQUENCE_NUMBER",
    "MONTHLY_REPORTING_PERIOD",
    "CURRENT_ACTUAL_UPB",
    "CURRENT_LOAN_DELINQUENCY_STATUS",
    "LOAN_AGE",
    "REMAINING_MONTHS_TO_MATURITY",
    "REPURCHASE_DATE",
    "MODIFICATION_FLAG",
    "ZERO_BALANCE_CODE",
    "ZERO_BALANCE_EFFECTIVE_DATE",
    "CURRENT_INTEREST_RATE",
    "CURRENT_DEFERRED_UPB",
    "DUE_DATE_LAST_PAID_INSTALL",
    "MI_RECOVERIES",
    "NET_SALES_PROCEEDS",
    "NON_MI_RECOVERIES",
    "EXPENSES",
    "LEGAL_COSTS",
    "MAINTENANCE_PRESERVATION_COSTS",
    "TAXES_AND_INSURANCE",
    "MISCELLANEOUS_EXPENSES",
    "ACTUAL_LOSS_CALCULATION",
    "MODIFICATION_COST",
    "STEP_MODIFICATION_FLAG",
    "DEFERRED_PAYMENT_PLAN",
    "ESTIMATED_LOAN_TO_VALUE",
    "ZERO_BALANCE_REMOVAL_UPB",
    "DELINQUENT_ACCRUED_INTEREST",
    "DELINQUENCY_DUE_TO_DISASTER",
    "BORROWER_ASSISTANCE_STATUS",
    "CURRENT_MONTH_MODIFICATION_COST",
    # Column 32: added in post-2019 Freddie Mac dataset format
    "REPURCHASE_MAKE_WHOLE_PROCEEDS",
]

DTYPE_MAP = {
    "LOAN_SEQUENCE_NUMBER": "str",
    "MONTHLY_REPORTING_PERIOD": "str",
    "CURRENT_ACTUAL_UPB": "float64",
    "CURRENT_LOAN_DELINQUENCY_STATUS": "str",
    "LOAN_AGE": "Int64",
    "REMAINING_MONTHS_TO_MATURITY": "Int64",
    "REPURCHASE_DATE": "str",
    "MODIFICATION_FLAG": "str",
    "ZERO_BALANCE_CODE": "str",
    "ZERO_BALANCE_EFFECTIVE_DATE": "str",
    "CURRENT_INTEREST_RATE": "float64",
    "CURRENT_DEFERRED_UPB": "float64",
    "DUE_DATE_LAST_PAID_INSTALL": "str",
    "MI_RECOVERIES": "float64",
    "NET_SALES_PROCEEDS": "float64",
    "NON_MI_RECOVERIES": "float64",
    "EXPENSES": "float64",
    "LEGAL_COSTS": "float64",
    "MAINTENANCE_PRESERVATION_COSTS": "float64",
    "TAXES_AND_INSURANCE": "float64",
    "MISCELLANEOUS_EXPENSES": "float64",
    "ACTUAL_LOSS_CALCULATION": "float64",
    "MODIFICATION_COST": "float64",
    "STEP_MODIFICATION_FLAG": "str",
    "DEFERRED_PAYMENT_PLAN": "str",
    "ESTIMATED_LOAN_TO_VALUE": "float64",
    "ZERO_BALANCE_REMOVAL_UPB": "float64",
    "DELINQUENT_ACCRUED_INTEREST": "float64",
    "DELINQUENCY_DUE_TO_DISASTER": "str",
    "BORROWER_ASSISTANCE_STATUS": "str",
    "CURRENT_MONTH_MODIFICATION_COST": "float64",
    "REPURCHASE_MAKE_WHOLE_PROCEEDS": "float64",
}


def connect():
    load_dotenv()
    host = os.environ["TD_HOST"]
    user = os.environ["TD_USER"]
    password = os.environ["TD_PASSWORD"]
    logmech = os.environ.get("TD_LOGMECH", "TD2")
    tdml.create_context(host=host, username=user, password=password, logmech=logmech)
    print(f"Connected to {host}")


def load(limit: int | None = None, chunksize: int = 50000):
    raw_path = os.path.join(os.path.dirname(__file__), "..", "raw", "freddie_performance.csv")
    raw_path = os.path.abspath(raw_path)

    if not os.path.exists(raw_path):
        print(f"ERROR: Source file not found at {raw_path}")
        print("Please download the Freddie Mac sample data and place it as:")
        print("  01_source_data/raw/freddie_performance.csv")
        sys.exit(1)

    total_loaded = 0
    chunk_num = 0
    rows_remaining = limit

    print(f"Reading {raw_path} in chunks of {chunksize:,} ...")
    reader = pd.read_csv(
        raw_path,
        sep="|",
        header=None,
        names=PERFORMANCE_COLUMNS,
        dtype=DTYPE_MAP,
        na_values=["", " "],
        keep_default_na=True,
        chunksize=chunksize,
        nrows=limit,
    )

    for chunk in reader:
        chunk_num += 1

        str_cols = chunk.select_dtypes(include="object").columns
        chunk[str_cols] = chunk[str_cols].apply(lambda c: c.str.strip())
        chunk[str_cols] = chunk[str_cols].where(chunk[str_cols].notna(), None)
        chunk = chunk.dropna(subset=["LOAN_SEQUENCE_NUMBER", "MONTHLY_REPORTING_PERIOD"])

        # Convert nullable Int64 columns to native Python int/None — teradatasql
        # does not accept numpy.int64 and will raise TypeError on insert
        int_cols = [c for c in chunk.columns if str(chunk[c].dtype) == "Int64"]
        for col in int_cols:
            chunk[col] = chunk[col].apply(lambda x: None if pd.isna(x) else int(x))

        # Replace float NaN with None for batch-type consistency
        float_cols = chunk.select_dtypes(include="float64").columns
        chunk[float_cols] = chunk[float_cols].where(chunk[float_cols].notna(), None)

        tdml.copy_to_sql(
            df=chunk,
            table_name="STG_Freddie_Performance",
            schema_name="MortgagePlatform_Staging",
            if_exists="append",
            index=False,
        )
        total_loaded += len(chunk)
        print(f"  Chunk {chunk_num}: {len(chunk):,} rows | Total: {total_loaded:,}")

        if rows_remaining is not None:
            rows_remaining -= len(chunk)
            if rows_remaining <= 0:
                break

    print(f"Done. {total_loaded:,} total rows loaded.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--chunksize", type=int, default=50000)
    args = parser.parse_args()

    connect()
    load(limit=args.limit, chunksize=args.chunksize)
