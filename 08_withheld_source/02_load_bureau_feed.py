"""
02_load_bureau_feed.py
Load the generated Credit Bureau Feed CSV into
MortgagePlatform_Staging.STG_Credit_Bureau_Feed.

Run this during Act 2 of the demo (Scenario 2: New Source Onboarding).

Prerequisites:
  - 01_generate_bureau_feed.py must have been run first
  - STG_Credit_Bureau_Feed table must exist (00_create_bureau_staging_table.sql)

Usage:
  python 08_withheld_source/02_load_bureau_feed.py
"""
import os
import sys
import pandas as pd
from dotenv import load_dotenv
import teradataml as tdml


def connect():
    load_dotenv()
    host = os.environ["TD_HOST"]
    user = os.environ["TD_USER"]
    password = os.environ["TD_PASSWORD"]
    logmech = os.environ.get("TD_LOGMECH", "TD2")
    tdml.create_context(host=host, username=user, password=password, logmech=logmech)
    print(f"Connected to {host}")


def load():
    csv_path = os.path.join(os.path.dirname(__file__), "bureau_feed.csv")

    if not os.path.exists(csv_path):
        print(f"ERROR: Bureau feed not found at {csv_path}")
        print("Run 01_generate_bureau_feed.py first.")
        sys.exit(1)

    print(f"Reading {csv_path} ...")
    df = pd.read_csv(csv_path, dtype=str)

    # Cast numeric columns
    int_cols = ["CRED_SCORE_CURR", "CRED_SCORE_PREV", "CRED_SCORE_CHG",
                "FILE_AGE_MONTHS", "ENQ_3M", "ENQ_6M", "ENQ_12M", "ENQ_MORTGAGE_3M",
                "TOTAL_ACCOUNTS", "OPEN_ACCOUNTS", "NUM_DEFAULTS", "NUM_JUDGEMENTS",
                "REPMT_HIST_SCORE", "DEROG_MARKS"]
    float_cols = ["CREDIT_LIMIT_TOTAL", "CREDIT_BALANCE_TOTAL", "CREDIT_UTIL_RATIO",
                  "MORTGAGE_BALANCE_TOTAL", "DEFAULT_AMT_TOTAL", "JUDGEMENT_AMT_TOTAL"]
    date_cols = ["BUREAU_ENQUIRY_DATE", "BANKRUPTCY_DATE", "CREDIT_ACTIVE_SINCE", "BUREAU_REFRESH_DATE"]

    for col in int_cols:
        df[col] = pd.to_numeric(df[col], errors="coerce").astype("Int64")
    for col in float_cols:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    for col in date_cols:
        df[col] = pd.to_datetime(df[col], errors="coerce").dt.date

    # Convert nullable Int64 columns to native Python int/None — teradatasql
    # does not accept numpy.int64 and will raise TypeError on insert
    for col in int_cols:
        df[col] = df[col].apply(lambda x: None if pd.isna(x) else int(x))

    print(f"  Rows: {len(df):,}")

    print("Loading into MortgagePlatform_Staging.STG_Credit_Bureau_Feed ...")
    tdml.copy_to_sql(
        df=df,
        table_name="STG_Credit_Bureau_Feed",
        schema_name="MortgagePlatform_Staging",
        if_exists="append",
        index=False,
    )
    print(f"  Done. {len(df):,} rows loaded.")


if __name__ == "__main__":
    connect()
    load()
