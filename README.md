# Mortgage AI-Native Data Product — Demo Environment

A fully reproducible demo showcasing Teradata's **AI-Native Data Product design standards** applied to a mortgage lending domain. Built for a financial services audience — specifically Business Analysts who currently perform manual source-to-target data mapping.

## Demo Story

**Sarah** is a Business Analyst in the Mortgage Data Office at a large bank. When a new source system extract arrives, she spends 2–3 days manually reading data dictionaries, cross-referencing column names against the enterprise data dictionary, and filling in the mapping spreadsheet — relying on tacit knowledge from colleagues who "know" that `orig_cltv` means Combined LTV.

This demo shows how the AI-Native Data Product framework enables an agent to:
1. Discover the existing enterprise mortgage domain model via the Memory and Semantic modules
2. Auto-map a new source file's columns to target attributes — with confidence scores and business justifications
3. Populate the standard mapping spreadsheet that Sarah's existing pipeline already consumes
4. Answer lineage and impact analysis questions in natural language
5. Support ad-hoc analytics questions against the enriched domain model

## Source Datasets

### Active Sources (loaded into initial domain model)

| # | File | Simulates | Key Entities | Source |
|---|------|-----------|--------------|--------|
| 1 | Freddie Mac Origination | Loan Origination System (LOS) | Loan, Borrower, Property | Public — Freddie Mac |
| 2 | Freddie Mac Monthly Performance | Loan Servicing System | Loan Performance, Repayment Event | Public — Freddie Mac |
| 3 | Synthetic Borrower Profile | CRM / Customer Master | Customer, Contact, Segment | Synthetic |
| 4 | Synthetic Property Valuation | Valuation / Collateral System | Property, Valuation | Synthetic |

### Withheld Source (added during demo — Act 2)

| # | File | Simulates | Key Entities | Why Withheld |
|---|------|-----------|--------------|--------------|
| 5 | Synthetic Credit Bureau Feed | External Bureau (e.g. Equifax API) | Enriches Customer + Loan | Demonstrates mapping a new source into a *mature* domain model |

The bureau feed is deliberately chosen because it enriches **existing** entities (Customer, Loan) rather than introducing new ones — this is the realistic "new source, mature model" scenario that large banks face constantly.

## Quick Start

### 1. Create your logon file

Create `logon.txt` in the repo root (it is gitignored — never commit it):

```
.LOGON your-vantage-host/your-username,your-password;
```

All BTEQ commands below pipe this file first so the SQL scripts themselves
stay credential-free and portable.

### 2. Read the environment guide

```bash
cat 00_setup/environment.md
```

### 3. Create databases

```bash
cat logon.txt 00_setup/create_databases.sql | bteq
```

### 4. Download and place Freddie Mac data

See `01_source_data/data_dictionary/freddie_mac_origination.md` for download
instructions. Place files as:
- `01_source_data/raw/freddie_origination.csv`
- `01_source_data/raw/freddie_performance.csv`

### 5. Create staging tables

```bash
cat logon.txt 01_source_data/load_scripts/00_create_staging_tables.sql | bteq
```

### 6. Install Python dependencies and load/generate source data

```bash
pip install -r 01_source_data/load_scripts/requirements.txt
python 01_source_data/load_scripts/01_load_freddie_origination.py
python 01_source_data/load_scripts/02_load_freddie_performance.py
python 01_source_data/load_scripts/03_generate_borrower_profile.py
python 01_source_data/load_scripts/04_generate_property_valuation.py
```

### 7. Deploy Memory and Semantic

```bash
cat logon.txt 02_memory/01_memory_ddl.sql | bteq
cat logon.txt 02_memory/02_memory_documentation.sql | bteq
cat logon.txt 03_semantic/01_semantic_ddl.sql | bteq
cat logon.txt 03_semantic/02_semantic_registration.sql | bteq
cat logon.txt 03_semantic/03_semantic_documentation.sql | bteq
```

### 8. Deploy Domain

```bash
cat logon.txt 04_domain/01_domain_ddl.sql | bteq
cat logon.txt 04_domain/02_domain_load.sql | bteq
cat logon.txt 04_domain/03_domain_views.sql | bteq
cat logon.txt 04_domain/04_domain_documentation.sql | bteq
```

### 9. Deploy Observability

```bash
cat logon.txt 09_observability/01_observability_ddl.sql | bteq
cat logon.txt 09_observability/02_observability_registration.sql | bteq
cat logon.txt 09_observability/03_observability_documentation.sql | bteq
cat logon.txt 09_observability/04_observability_seed.sql | bteq
```

## Naming Convention

Product name: **`MortgagePlatform`**

| Module | Database |
|--------|----------|
| Memory | `MortgagePlatform_Memory` |
| Semantic | `MortgagePlatform_Semantic` |
| Domain | `MortgagePlatform_Domain` |
| Staging | `MortgagePlatform_Staging` |
| Observability | `MortgagePlatform_Observability` |

## License & Data Attribution

- Freddie Mac Single Family Loan Performance data is used under Freddie Mac's public data licence. See: https://www.freddiemac.com/research/datasets/sf-loanlevel-dataset
- Synthetic data files (Borrower Profile, Property Valuation, Credit Bureau Feed) are generated programmatically and contain no real personal information.
