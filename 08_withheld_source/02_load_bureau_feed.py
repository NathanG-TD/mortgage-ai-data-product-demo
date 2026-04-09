"""
02_load_bureau_feed.py
Load the generated Credit Bureau Feed CSV into
MortgagePlatform_Staging.STG_Credit_Bureau_Feed.

Uses teradatasql directly (not copy_to_sql) to avoid pandas converting
Python None to float NaN in object columns, which causes teradatasql
batch type-mismatch errors (Error 502). Same approach as loaders 01/02.

Run this during Act 2 of the demo (Scenario 2: New Source Onboarding).

Prerequisites:
  - 01_generate_bureau_feed.py must have been run first
  - STG_Credit_Bureau_Feed table must exist (00_create_bureau_staging_table.sql)

Usage:
  python 08_withheld_source/02_load_bureau_feed.py
"""
import os
import sys
import csv
import json
from dotenv import load_dotenv
import teradatasql

BUREAU_COLUMNS = [
    "BUREAU_RECORD_ID", "CUSTOMER_ID", "BUREAU_ENQUIRY_DATE",
    "BUREAU_PROVIDER_CODE", "CRED_SCORE_CURR", "CRED_SCORE_PREV",
    "CRED_SCORE_CHG", "CRED_SCORE_BAND", "FILE_AGE_MONTHS",
    "ENQ_3M", "ENQ_6M", "ENQ_12M", "ENQ_MORTGAGE_3M",
    "TOTAL_ACCOUNTS", "OPEN_ACCOUNTS", "CREDIT_LIMIT_TOTAL",
    "CREDIT_BALANCE_TOTAL", "CREDIT_UTIL_RATIO", "MORTGAGE_BALANCE_TOTAL",
    "NUM_DEFAULTS", "DEFAULT_AMT_TOTAL", "NUM_JUDGEMENTS",
    "JUDGEMENT_AMT_TOTAL", "BANKRUPTCY_FLAG", "BANKRUPTCY_DATE",
    "PART_IX_FLAG", "SERIOUS_CREDIT_IMPAIRMENT", "REPMT_HIST_SCORE",
    "DEROG_MARKS", "CREDIT_ACTIVE_SINCE", "BUREAU_REFRESH_DATE",
    "DATA_SUPPLIER_CODE",
]

INT_COLUMNS = {
    "CRED_SCORE_CURR", "CRED_SCORE_PREV", "CRED_SCORE_CHG",
    "FILE_AGE_MONTHS", "ENQ_3M", "ENQ_6M", "ENQ_12M", "ENQ_MORTGAGE_3M",
    "TOTAL_ACCOUNTS", "OPEN_ACCOUNTS", "NUM_DEFAULTS", "NUM_JUDGEMENTS",
    "REPMT_HIST_SCORE", "DEROG_MARKS",
}

FLOAT_COLUMNS = {
    "CREDIT_LIMIT_TOTAL", "CREDIT_BALANCE_TOTAL", "CREDIT_UTIL_RATIO",
    "MORTGAGE_BALANCE_TOTAL", "DEFAULT_AMT_TOTAL", "JUDGEMENT_AMT_TOTAL",
}


def parse_str(v):
    s = v.strip() if isinstance(v, str) else ""
    return s or None

def parse_int(v):
    s = v.strip() if isinstance(v, str) else ""
    if not s: return None
    try: return int(s)
    except (ValueError, TypeError): return None

def parse_float(v):
    s = v.strip() if isinstance(v, str) else ""
    if not s: return None
    try: return float(s)
    except (ValueError, TypeError): return None


def normalise_row(row_dict):
    """Convert one CSV row dict to a tuple of native Python types."""
    result = []
    for col in BUREAU_COLUMNS:
        val = row_dict.get(col, "")
        if col in INT_COLUMNS:
            result.append(parse_int(val))
        elif col in FLOAT_COLUMNS:
            result.append(parse_float(val))
        else:
            result.append(parse_str(val))
    return tuple(result)


def load():
    load_dotenv()
    host     = os.environ["TD_HOST"]
    user     = os.environ["TD_USER"]
    password = os.environ["TD_PASSWORD"]
    logmech  = os.environ.get("TD_LOGMECH", "TD2")

    csv_path = os.path.join(os.path.dirname(__file__), "bureau_feed.csv")
    if not os.path.exists(csv_path):
        print(f"ERROR: Bureau feed not found at {csv_path}")
        print("Run 01_generate_bureau_feed.py first.")
        sys.exit(1)

    print(f"Reading {csv_path} ...")
    rows = []
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(normalise_row(row))
    print(f"  Rows read: {len(rows):,}")

    cols    = ", ".join(BUREAU_COLUMNS)
    holders = ", ".join(["?"] * len(BUREAU_COLUMNS))
    sql     = (f"INSERT INTO MortgagePlatform_Staging.STG_Credit_Bureau_Feed"
               f" ({cols}) VALUES ({holders})")

    con_params = json.dumps({
        "host": host, "user": user, "password": password, "logmech": logmech
    })
    print(f"Connecting to {host} ...")
    batch_size = 5000
    with teradatasql.connect(con_params) as con:
        with con.cursor() as cur:
            for start in range(0, len(rows), batch_size):
                cur.executemany(sql, rows[start:start + batch_size])
            con.commit()
    print(f"  Done. {len(rows):,} rows loaded.")


if __name__ == "__main__":
    load()
