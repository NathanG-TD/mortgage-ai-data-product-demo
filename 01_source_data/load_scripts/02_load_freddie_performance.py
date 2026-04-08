"""
02_load_freddie_performance.py
Load the Freddie Mac Single Family Monthly Performance file into
MortgagePlatform_Staging.STG_Freddie_Performance.

Uses teradatasql directly (not copy_to_sql) — see origination loader
for explanation of why.

Usage:
  python 02_load_freddie_performance.py [--limit N] [--batch N]
"""
import os
import sys
import csv
import json
import argparse
from dotenv import load_dotenv
import teradatasql

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

INT_COLUMNS   = {"LOAN_AGE", "REMAINING_MONTHS_TO_MATURITY"}
FLOAT_COLUMNS = {
    "CURRENT_ACTUAL_UPB", "CURRENT_INTEREST_RATE", "CURRENT_DEFERRED_UPB",
    "MI_RECOVERIES", "NET_SALES_PROCEEDS", "NON_MI_RECOVERIES", "EXPENSES",
    "LEGAL_COSTS", "MAINTENANCE_PRESERVATION_COSTS", "TAXES_AND_INSURANCE",
    "MISCELLANEOUS_EXPENSES", "ACTUAL_LOSS_CALCULATION", "MODIFICATION_COST",
    "ESTIMATED_LOAN_TO_VALUE", "ZERO_BALANCE_REMOVAL_UPB",
    "DELINQUENT_ACCRUED_INTEREST", "CURRENT_MONTH_MODIFICATION_COST",
    "REPURCHASE_MAKE_WHOLE_PROCEEDS",
}

LSN_IDX = PERFORMANCE_COLUMNS.index("LOAN_SEQUENCE_NUMBER")
MRP_IDX = PERFORMANCE_COLUMNS.index("MONTHLY_REPORTING_PERIOD")


def parse_str(v):
    s = v.strip()
    return s or None

def parse_int(v):
    s = v.strip()
    if not s: return None
    try: return int(s)
    except (ValueError, TypeError): return None

def parse_float(v):
    s = v.strip()
    if not s: return None
    try: return float(s)
    except (ValueError, TypeError): return None

def normalise_row(raw_row):
    row = []
    for i, col in enumerate(PERFORMANCE_COLUMNS):
        val = raw_row[i] if i < len(raw_row) else ""
        if col in INT_COLUMNS:
            row.append(parse_int(val))
        elif col in FLOAT_COLUMNS:
            row.append(parse_float(val))
        else:
            row.append(parse_str(val))
    if row[LSN_IDX] is None or row[MRP_IDX] is None:
        return None
    return tuple(row)


def load(host, user, password, logmech, filepath, limit=None, batch_size=5000):
    cols    = ", ".join(PERFORMANCE_COLUMNS)
    holders = ", ".join(["?"] * len(PERFORMANCE_COLUMNS))
    sql     = (f"INSERT INTO MortgagePlatform_Staging.STG_Freddie_Performance"
               f" ({cols}) VALUES ({holders})")

    con_params = json.dumps({
        "host": host, "user": user, "password": password, "logmech": logmech
    })
    print(f"Reading {filepath} ...")
    total = 0

    with teradatasql.connect(con_params) as con:
        with con.cursor() as cur:
            batch = []
            with open(filepath, newline="", encoding="utf-8") as f:
                reader = csv.reader(f, delimiter="|")
                for i, raw in enumerate(reader):
                    if limit and i >= limit:
                        break
                    row = normalise_row(raw)
                    if row is None:
                        continue
                    batch.append(row)
                    if len(batch) >= batch_size:
                        cur.executemany(sql, batch)
                        total += len(batch)
                        print(f"  Inserted {total:,} rows ...")
                        batch = []
            if batch:
                cur.executemany(sql, batch)
                total += len(batch)
            con.commit()

    print(f"Done. {total:,} total rows loaded.")


if __name__ == "__main__":
    load_dotenv()
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--batch", type=int, default=5000)
    args = parser.parse_args()

    host     = os.environ["TD_HOST"]
    user     = os.environ["TD_USER"]
    password = os.environ["TD_PASSWORD"]
    logmech  = os.environ.get("TD_LOGMECH", "TD2")
    print(f"Connecting to {host} ...")

    raw_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "raw", "freddie_performance.csv")
    )
    if not os.path.exists(raw_path):
        print(f"ERROR: file not found: {raw_path}")
        sys.exit(1)

    load(host, user, password, logmech, raw_path,
         limit=args.limit, batch_size=args.batch)
