# Withheld Source — Credit Bureau Feed

> ⚠️ **Do not load this source during initial environment setup.**
> It is introduced in Act 2 of the demo only.

## Demo Facilitation Guide

### When to Introduce

This source is revealed during **Scenario 2: New Source Onboarding**. By this point
in the demo, the audience has seen the mature four-source domain model and understands
the existing entity structure. The bureau feed lands as a realistic "a new extract
has arrived from our bureau provider" moment.

### Setup Before the Demo

Before running the demo, pre-generate the bureau feed data and have it ready to load,
but **do not load it**:

```bash
python 08_withheld_source/01_generate_bureau_feed.py
```

This creates the CSV at `08_withheld_source/bureau_feed.csv` (gitignored).

Also pre-create the staging table so the load is instant during the demo:

```bash
cat logon.txt 08_withheld_source/00_create_bureau_staging_table.sql | bteq
```

### During the Demo — Act 2 Sequence

1. Show the agent reading the existing domain model via the Memory/Semantic modules
2. Present the bureau feed CSV — unfamiliar columns, no documentation context
3. Show the agent reading the data dictionary (`data_dictionary/credit_bureau_feed.md`)
4. The agent maps columns to existing domain entities with confidence tiers
5. Load the bureau feed into staging:
   ```bash
   python 08_withheld_source/02_load_bureau_feed.py
   ```
6. Register the new source in the Semantic layer:
   ```bash
   cat logon.txt 08_withheld_source/03_bureau_semantic_registration.sql | bteq
   ```
7. Show the enriched domain model — new attributes now visible on Customer and Loan

### Why This Source Works for the Demo

- **Enriches existing entities** (Customer, Loan) — not a new entity type. This is the
  realistic "mature model, new source" scenario the audience faces every day.
- **Column naming is deliberately obscure** (e.g. `CRED_SCORE_CURR`, `ENQ_3M`, `DEROG_MARKS`)
  — a realistic bureau extract naming convention that makes manual mapping painful.
- **Scale difference**: the US FICO scale (300–850) in the origination file vs the
  Equifax scale (0–1200) in the bureau feed is a real semantic discrepancy the agent
  must identify and flag — this is exactly the kind of tacit knowledge a BA would
  normally need a colleague to point out.
- **Regulated attributes**: `SERIOUS_CREDIT_IMPAIRMENT`, `BANKRUPTCY_FLAG` — the agent
  should flag these as requiring data governance review, demonstrating that the
  framework supports compliance-aware mapping.
