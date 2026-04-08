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

## Module Build Order

Following the AI-Native Data Product standard, modules are built and deployed in this sequence:

```
Phase 1:  02_memory/     →  03_semantic/
Phase 2:  04_domain/
Phase 3:  (future) Search, Prediction, Observability
```

Memory and Semantic are always deployed first — Memory hosts the documentation tables every module writes to; Semantic hosts the discovery metadata every module registers into.

## Repository Structure

```
mortgage-ai-data-product-demo/
├── README.md                          ← You are here
├── .gitignore
│
├── 00_setup/
│   ├── environment.md                 ← Prerequisites and connection setup
│   ├── create_databases.sql           ← Create all module databases
│   └── teardown.sql                   ← Full clean teardown (idempotent)
│
├── 01_source_data/
│   ├── raw/                           ← CSVs placed here (gitignored if large)
│   ├── data_dictionary/               ← Column-level descriptions for each source
│   │   ├── freddie_mac_origination.md
│   │   ├── freddie_mac_performance.md
│   │   ├── borrower_profile.md
│   │   ├── property_valuation.md
│   │   └── credit_bureau_feed.md      ← Withheld source (documented for agent)
│   └── load_scripts/
│       ├── 00_create_staging_tables.sql
│       ├── 01_load_freddie_origination.py
│       ├── 02_load_freddie_performance.py
│       ├── 03_generate_borrower_profile.py
│       ├── 04_generate_property_valuation.py
│       └── requirements.txt
│
├── 02_memory/
│   ├── 01_memory_ddl.sql              ← MortgagePlatform_Memory database + tables
│   └── 02_memory_documentation.sql   ← Module registration + ADRs + glossary
│
├── 03_semantic/
│   ├── 01_semantic_ddl.sql            ← MortgagePlatform_Semantic database + tables
│   ├── 02_semantic_registration.sql   ← data_product_map entries for all sources
│   └── 03_semantic_documentation.sql
│
├── 04_domain/
│   ├── 01_domain_ddl.sql              ← MortgagePlatform_Domain entities
│   ├── 02_domain_comments.sql         ← COMMENT ON TABLE / COLUMN
│   ├── 03_domain_views.sql            ← _Current and _Enriched views
│   └── 04_domain_documentation.sql
│
├── 05_mapping_agent/
│   ├── mapping_prompt.md              ← System prompt for the mapping agent
│   ├── mapping_output_template.xlsx   ← Standard mapping spreadsheet template
│   └── sample_outputs/                ← Example agent-generated mappings
│
├── 06_lineage/
│   └── lineage_queries.sql            ← Lineage and impact analysis queries
│
├── 07_demo_scenarios/
│   ├── scenario_1_initial_state.md    ← Walk-through: mature domain model
│   ├── scenario_2_bureau_onboarding.md ← Walk-through: new source mapping
│   └── scenario_3_adhoc_analytics.md  ← Walk-through: NL analytics questions
│
└── 08_withheld_source/
    ├── README.md                      ← Instructions: when/how to introduce
    ├── 01_generate_bureau_feed.py     ← Synthetic data generator
    ├── 02_load_bureau_feed.py         ← Loader into staging
    ├── 03_bureau_semantic_registration.sql
    └── 04_bureau_mapping_walkthrough.md
```

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

### 5. Install Python dependencies and load/generate source data

```bash
cd 01_source_data/load_scripts
pip install -r requirements.txt
python 01_load_freddie_origination.py
python 02_load_freddie_performance.py
python 03_generate_borrower_profile.py
python 04_generate_property_valuation.py
cd ../..
```

### 6. Create staging tables

```bash
cat logon.txt 01_source_data/load_scripts/00_create_staging_tables.sql | bteq
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
cat logon.txt 04_domain/02_domain_comments.sql | bteq
cat logon.txt 04_domain/03_domain_views.sql | bteq
cat logon.txt 04_domain/04_domain_documentation.sql | bteq
```

## Naming Convention

Product name: **`MortgagePlatform`**

| Module | Database |
|--------|----------|
| Memory | `MortgagePlatform_Memory` |
| Semantic | `MortgagePlatform_Semantic` |
| Domain | `MortgagePlatform_Domain` |
| Staging | `MortgagePlatform_Staging` |

## License & Data Attribution

- Freddie Mac Single Family Loan Performance data is used under Freddie Mac's public data licence. See: https://www.freddiemac.com/research/datasets/sf-loanlevel-dataset
- Synthetic data files (Borrower Profile, Property Valuation, Credit Bureau Feed) are generated programmatically and contain no real personal information.
