"""
04_generate_property_valuation.py
Generate synthetic Property Valuation (Collateral) records and load into
MortgagePlatform_Staging.STG_Property_Valuation.

Reads LOAN_SEQUENCE_NUMBER, ORIG_UPB, and ORIG_LTV from STG_Freddie_Origination
to derive internally consistent origination valuations.

Prerequisites:
  - STG_Freddie_Origination must be loaded first
  - STG_Borrower_Profile must be loaded first (to pull CUSTOMER_ID)
  - STG_Property_Valuation table must exist

Usage:
  python 04_generate_property_valuation.py [--seed N]
"""
import os
import random
import argparse
import pandas as pd
import numpy as np
from datetime import date
from faker import Faker
from dotenv import load_dotenv
import teradataml as tdml

fake = Faker("en_AU")

PROPERTY_TYPES = [("SF", "Single Family House"), ("TH", "Townhouse"), ("AP", "Apartment/Unit"), ("RU", "Rural")]
PROPERTY_TYPE_WEIGHTS = [0.50, 0.20, 0.25, 0.05]

STREET_TYPES = ["St", "Rd", "Ave", "Dr", "Pl", "Ct", "Blvd", "Cres", "Way", "Cl"]
VALUATION_METHODS = ["Full", "Kerbside", "Desktop", "AVM"]
VALUATION_METHOD_WEIGHTS = [0.60, 0.15, 0.15, 0.10]
VALUERS = ["Herron Todd White", "CBRE Valuations", "JLL Valuations", "Knight Frank", "Opteon"]
FLOOD_RISKS = [None, None, None, None, "Low", "Low", "Medium", "High", "Overland Flow"]
FIRE_RISKS = [None, None, None, None, None, "Low", "Medium", "High", "Extreme"]
AU_STATES = ["NSW", "VIC", "QLD", "WA", "SA", "TAS", "ACT", "NT"]
AU_STATE_WEIGHTS = [0.32, 0.26, 0.20, 0.11, 0.07, 0.02, 0.02, 0.01]


def connect():
    load_dotenv()
    host = os.environ["TD_HOST"]
    user = os.environ["TD_USER"]
    password = os.environ["TD_PASSWORD"]
    logmech = os.environ.get("TD_LOGMECH", "TD2")
    tdml.create_context(host=host, username=user, password=password, logmech=logmech)
    print(f"Connected to {host}")


def fetch_loan_data() -> pd.DataFrame:
    print("Fetching loan and customer data ...")
    df = tdml.DataFrame.from_query("""
        SELECT
            o.LOAN_SEQUENCE_NUMBER,
            o.ORIG_UPB,
            o.ORIG_LTV,
            b.CUSTOMER_ID
        FROM MortgagePlatform_Staging.STG_Freddie_Origination o
        JOIN MortgagePlatform_Staging.STG_Borrower_Profile b
          ON o.LOAN_SEQUENCE_NUMBER = b.LOAN_SEQUENCE_NUMBER
    """).to_pandas()
    print(f"  Found {len(df):,} loans with customer records")
    return df


def generate_record(row: dict, idx: int) -> dict:
    lsn = row["LOAN_SEQUENCE_NUMBER"]
    rng = random.Random(hash(lsn + "_prop"))
    fake_local = Faker("en_AU")
    fake_local.seed_instance(hash(lsn + "_prop"))

    property_id = f"PROP-{idx:08d}"

    # Derive origination value from Freddie Mac LTV: value = UPB / (LTV/100)
    orig_upb = float(row["ORIG_UPB"]) if row["ORIG_UPB"] else 400_000
    orig_ltv = int(row["ORIG_LTV"]) if row["ORIG_LTV"] else 80
    orig_val = round(orig_upb / (orig_ltv / 100), -3) if orig_ltv > 0 else orig_upb * 1.25

    # AVM drift: current value ± 20% from origination
    drift = rng.uniform(-0.15, 0.25)
    current_val = round(orig_val * (1 + drift), -3)

    # Current LVR: assume some principal paid down (rough)
    paydown_factor = rng.uniform(0.85, 0.98)
    current_upb_est = orig_upb * paydown_factor
    estimated_lvr = round(current_upb_est / current_val, 4) if current_val > 0 else None

    state = rng.choices(AU_STATES, AU_STATE_WEIGHTS)[0]
    prop_type_code, prop_type_desc = rng.choices(PROPERTY_TYPES, PROPERTY_TYPE_WEIGHTS)[0]

    # Land area only for non-apartments
    land_area = round(rng.uniform(200, 1200), 1) if prop_type_code in ("SF", "TH", "RU") else None
    floor_area = round(rng.uniform(60, 350), 1)

    orig_date = fake_local.date_between(start_date="-20y", end_date="-1y")
    current_val_date = fake_local.date_between(start_date=orig_date, end_date="today")

    strata = "Y" if prop_type_code == "AP" else rng.choices(["Y", "N"], [0.05, 0.95])[0]

    return {
        "PROPERTY_ID": property_id,
        "LOAN_SEQUENCE_NUMBER": lsn,
        "CUSTOMER_ID": row["CUSTOMER_ID"],
        "STREET_NUMBER": str(rng.randint(1, 250)),
        "STREET_NAME": fake_local.street_name().split()[0],
        "STREET_TYPE": rng.choice(STREET_TYPES),
        "UNIT_NUMBER": f"{rng.randint(1,50)}" if prop_type_code == "AP" and rng.random() < 0.8 else None,
        "SUBURB": fake_local.city(),
        "STATE": state,
        "POSTCODE": fake_local.postcode(),
        "PROPERTY_TYPE_CODE": prop_type_code,
        "PROPERTY_TYPE_DESC": prop_type_desc,
        "LAND_AREA_SQM": land_area,
        "FLOOR_AREA_SQM": floor_area,
        "BEDROOMS": rng.randint(1, 5),
        "BATHROOMS": rng.choice([1.0, 1.0, 2.0, 2.0, 3.0, 1.5, 2.5]),
        "CAR_SPACES": rng.choice([0, 1, 1, 2, 2, 3]),
        "YEAR_BUILT": rng.randint(1960, 2022),
        "ZONING_CODE": rng.choice(["R1", "R2", "R3", "E1", "B1"]),
        "COUNCIL_AREA": fake_local.city() + " City Council",
        "TITLE_REFERENCE": f"CT {rng.randint(1000,9999)}/{rng.randint(100,999)}",
        "LOT_NUMBER": str(rng.randint(1, 200)),
        "PLAN_NUMBER": f"DP{rng.randint(100000,999999)}",
        "STRATA_FLAG": strata,
        "HERITAGE_LISTED": rng.choices(["Y", "N"], [0.02, 0.98])[0],
        "ORIG_VALUATION_DATE": orig_date.isoformat(),
        "ORIG_VALUATION_AMOUNT": orig_val,
        "ORIG_VALUATION_METHOD": rng.choices(VALUATION_METHODS, VALUATION_METHOD_WEIGHTS)[0],
        "ORIG_VALUER_NAME": rng.choice(VALUERS),
        "CURRENT_VALUATION_DATE": current_val_date.isoformat(),
        "CURRENT_VALUATION_AMOUNT": current_val,
        "CURRENT_VALUATION_METHOD": "AVM",
        "ESTIMATED_LVR": estimated_lvr,
        "FLOOD_RISK_ZONE": rng.choice(FLOOD_RISKS),
        "FIRE_RISK_ZONE": rng.choice(FIRE_RISKS),
        "ENVIRONMENTAL_CONSTRAINT": rng.choices(["Y", "N"], [0.03, 0.97])[0],
        "PROPERTY_STATUS": rng.choices(["Active", "Released", "Substituted"], [0.92, 0.06, 0.02])[0],
        "RECORD_CREATED_DATE": orig_date.isoformat(),
        "RECORD_LAST_UPDATED": current_val_date.isoformat(),
    }


def generate_and_load(seed: int = 42):
    random.seed(seed)
    loan_df = fetch_loan_data()

    print(f"Generating {len(loan_df):,} property valuation records ...")
    records = [generate_record(row, i + 1) for i, row in enumerate(loan_df.to_dict("records"))]
    df = pd.DataFrame(records)
    print(f"  Generated {len(df):,} records")

    print("Loading into MortgagePlatform_Staging.STG_Property_Valuation ...")
    tdml.copy_to_sql(
        df=df,
        table_name="STG_Property_Valuation",
        schema_name="MortgagePlatform_Staging",
        if_exists="append",
        index=False,
    )
    print(f"  Done. {len(df):,} rows loaded.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    connect()
    generate_and_load(seed=args.seed)
