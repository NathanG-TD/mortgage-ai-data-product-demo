# Environment Setup

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| Teradata Vantage | 17.20+ | VantageCloud Lake or on-prem |
| Python | 3.10+ | For data generation and loading |
| `teradataml` | 20.0+ | `pip install teradataml` |
| `pandas` | 2.0+ | |
| `faker` | 24.0+ | For synthetic data generation |
| BTEQ or `tdconnect` | Any | For SQL script execution |

## Teradata Connection

All Python scripts read connection parameters from environment variables:

```bash
export TD_HOST=your-vantage-host
export TD_USER=your-username
export TD_PASSWORD=your-password
export TD_LOGMECH=TD2          # or LDAP, TDNEGO as appropriate
```

Alternatively, create a `.env` file in the repo root (it is gitignored):

```
TD_HOST=your-vantage-host
TD_USER=your-username
TD_PASSWORD=your-password
TD_LOGMECH=TD2
```

## Databases Required

The setup script creates these databases (all owned by the user running the scripts):

| Database | Purpose |
|----------|---------|
| `MortgagePlatform_Staging` | Raw source data — staging area |
| `MortgagePlatform_Memory` | Agent memory, documentation, ADRs |
| `MortgagePlatform_Semantic` | Discovery metadata, data product map |
| `MortgagePlatform_Domain` | Core business entities |

## Freddie Mac Data Download

The Origination and Monthly Performance files require a **free registration** at Freddie Mac:

1. Go to: https://www.freddiemac.com/research/datasets/sf-loanlevel-dataset
2. Register for access (free, usually approved same day)
3. Download **Sample Data** (not the full dataset — sample is ~50k loans, sufficient for demo)
4. Place the unzipped files in `01_source_data/raw/`:
   - `sample_orig_YYYY.txt` → rename to `freddie_origination.csv`
   - `sample_svcg_YYYY.txt` → rename to `freddie_performance.csv`

> **Note:** The Freddie Mac files are pipe-delimited (`|`) with no header row.
> The load scripts handle this automatically using the column order documented in
> `01_source_data/data_dictionary/freddie_mac_origination.md`.

## Synthetic Data

The borrower profile and property valuation files are **generated programmatically**
— no download required. Run the generator scripts after loading the Freddie Mac data,
as they use `LOAN_SEQUENCE_NUMBER` as a join key to ensure referential consistency.

```bash
python 01_source_data/load_scripts/03_generate_borrower_profile.py
python 01_source_data/load_scripts/04_generate_property_valuation.py
```

## Teardown

To fully reset the environment:

```bash
bteq < 00_setup/teardown.sql
```

This drops all four databases. It is safe to re-run `create_databases.sql` and the
module scripts after teardown to rebuild from scratch.
