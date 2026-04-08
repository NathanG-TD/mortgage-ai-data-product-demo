"""
01_load_freddie_origination.py
Load the Freddie Mac Single Family Origination file into
MortgagePlatform_Staging.STG_Freddie_Origination.

Uses teradatasql directly (not copy_to_sql) to avoid pandas converting
Python None to float NaN in object columns, which causes teradatasql
batch type-mismatch errors (Error 502).

Prerequisites:
  - MortgagePlatform_Staging database created (00_setup/create_databases.sql)
  - STG_Freddie_Origination table created (00_create_staging_tables.sql)
  - Freddie Mac origination file placed at: ../raw/freddie_origination.csv
    (pipe-delimited, no header row)

Usage:
  python 01_load_freddie_origination.py [--limit N] [--batch N]
"""
import os
import sys
import csv
import json
import argparse
from dotenv import load_dotenv
import teradatasql

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
    "PRE_RELIEF_REFINANCE_LSN", "PROGRAM_INDICATOR", "HARP_INDICATOR",
    "PROPERTY_VALUATION_METHOD", "INTEREST_ONLY_INDICATOR",
    "MI_CANCELLATION_INDICATOR",
]

INT_COLUMNS = {
    "CREDIT_SCORE", "MI_PERCENTAGE", "NUMBER_OF_UNITS",
    "ORIG_CLTV", "ORIG_DTI", "ORIG_LTV", "ORIG_LOAN_TERM", "NUMBER_OF_BORROWERS",
}
FLOAT_COLUMNS = {"ORIG_UPB", "ORIG_INTEREST_RATE"}
NULL_SENTINELS = {"", "9", "999", "9999"}
LSN_IDX = ORIGINATION_COLUMNS.index("LOAN_SEQUENCE_NUMBER")


def parse_str(v):
    s = v.strip()
    return None if s in NULL_SENTINELS else (s or None)

def parse_int(v):
    s = v.strip()
    if s in NULL_SENTINELS: return None
    try: return int(s)
    except (ValueError, TypeError): return None

def parse_float(v):
    s = v.strip()
    if s in NULL_SENTINELS: return None
    try: return float(s)
    except (ValueError, TypeError): return None

def normalise_row(raw_row):
    """Convert one CSV row to a tuple of native Python types.
    Returns None for rows that should be skipped (null LSN)."""
    row = []
    for i, col in enumerate(ORIGINATION_COLUMNS):
        val = raw_row[i] if i < len(raw_row) else ""
        if col in INT_COLUMNS:
            row.append(parse_int(val))
        elif col in FLOAT_COLUMNS:
            row.append(parse_float(val))
        else:
            row.append(parse_str(val))
    if row[LSN_IDX] is None:
        return None
    return tuple(row)


def load(host, user, password, logmech, filepath, limit=None, batch_size=5000):
    print(f"Reading {filepath} ...")
    rows = []
    with open(filepath, newline="", encoding="utf-8") as f:
        reader = csv.reader(f, delimiter="|")
        for i, raw in enumerate(reader):
            if limit and i >= limit:
                break
            row = normalise_row(raw)
            if row is not None:
                rows.append(row)

    print(f"  Rows read: {len(rows):,}")
    if not rows:
        print("  No rows to load.")
        return

    cols    = ", ".join(ORIGINATION_COLUMNS)
    holders = ", ".join(["?"] * len(ORIGINATION_COLUMNS))
    sql     = (f"INSERT INTO MortgagePlatform_Staging.STG_Freddie_Origination"
               f" ({cols}) VALUES ({holders})")

    con_params = json.dumps({
        "host": host, "user": user, "password": password, "logmech": logmech
    })
    print("Loading into MortgagePlatform_Staging.STG_Freddie_Origination ...")
    with teradatasql.connect(con_params) as con:
        with con.cursor() as cur:
            for start in range(0, len(rows), batch_size):
                batch = rows[start : start + batch_size]
                cur.executemany(sql, batch)
            con.commit()

    print(f"  Done. {len(rows):,} rows loaded.")


if __name__ == "__main__":
    load_dotenv()
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit",     type=int, default=None)
    parser.add_argument("--batch",     type=int, default=5000)
    args = parser.parse_args()

    host     = os.environ["TD_HOST"]
    user     = os.environ["TD_USER"]
    password = os.environ["TD_PASSWORD"]
    logmech  = os.environ.get("TD_LOGMECH", "TD2")
    print(f"Connecting to {host} ...")

    raw_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "raw", "freddie_origination.csv")
    )
    if not os.path.exists(raw_path):
        print(f"ERROR: file not found: {raw_path}")
        sys.exit(1)

    load(host, user, password, logmech, raw_path,
         limit=args.limit, batch_size=args.batch)
