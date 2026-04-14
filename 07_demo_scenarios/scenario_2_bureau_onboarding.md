# Scenario 2 — New Source Onboarding (The Bureau Feed)

## Objective

Demonstrate the core use case: a new source file arrives, the agent auto-maps
it to the enterprise domain model, produces the mapping spreadsheet, identifies
governance issues, and frames the impact of integration — all before a single
line of pipeline code is written.

## Audience

Business Analysts primarily. This is the centrepiece demo.

## Duration

~20 minutes

## Narrative Script

**Setup line (presenter):**
> "Sarah has just received an email from the Risk team. They've arranged a new
> bureau data feed from Equifax — a regular extract that will refresh credit
> scores and flag any customers with derogatory marks. The feed starts next month.
> Sarah needs to produce the source-to-target mapping so the pipeline team can
> build the ingestion job. Normally this would take her 2–3 days."

## Demo Steps

Before you begin, follow the instructions in: 08_withheld_source/README.md

This will generate the bureau data, create the staging table and load the new data.

### Step 1 — Show the raw bureau feed

Present the first 10 rows of `bureau_feed.csv`. Point out:
- Column names like `ENQ_3M`, `CRED_SCORE_CURR`, `DEROG_MARKS` — not self-explanatory
- No domain context — a new BA would have no idea what maps where
- The Equifax scale (0–1200) is different from the FICO scale already in the model

**Talking point:**
> "This is what lands in Sarah's inbox. In the old world, she'd spend the first
> day just working out what these columns mean."

### Step 2 — Give the agent the data dictionary

Direct the agent to the data dictionary:

> "I have a new source file to onboard — a credit bureau feed from Equifax.
> Please map this to our existing MortgagePlatform data product.
> The new feed table can be found in the Staging database."

Expected agent behaviour:
- Reads `data_product_map` to discover existing entities and attributes
- Cross-references source column descriptions against domain attribute metadata
- Produces the full mapping table with confidence tiers
- **Flags the FICO vs Equifax scale mismatch** — this is the "wow moment"
- **Flags regulated attributes** (BANKRUPTCY_FLAG, SERIOUS_CREDIT_IMPAIRMENT, PART_IX_FLAG)
- Identifies UNMAPPED columns and recommends new attributes

### Step 3 — Show the confidence tiers

Walk through the mapping output:

| Tier | Example columns | Point to make |
|------|-----------------|---------------|
| AUTO | CUSTOMER_ID, BUREAU_ENQUIRY_DATE | "These are unambiguous — the agent can map them with no human input" |
| REVIEW | CRED_SCORE_CURR | "Same concept, different scale — the agent caught this and flagged it" |
| FLAG | REPMT_HIST_SCORE | "Proprietary bureau metric — no direct domain equivalent yet" |

**Talking point:**
> "The agent isn't trying to be a black box. It tells Sarah exactly what it's
> confident about, what it needs her to confirm, and what it can't resolve.
> That's the human-in-the-loop design."

### Step 4 — Export the mapping spreadsheet

Show the mapping output formatted as the standard template:

> "Export this mapping to the standard spreadsheet format."

The agent produces an output matching `mapping_output_template.xlsx`.

**Talking point:**
> "This drops straight into Sarah's existing pipeline process. No format change,
> no rework. The automation meets her workflow, not the other way around."

### Step 5 — Forward-looking impact analysis

With the mapping complete, ask the agent to assess what changes integration
will require — without needing the data to already be loaded:

> "Based on this mapping, what changes will need to be made to the domain model
> to integrate this data, and which downstream views and reports will be affected
> once the bureau feed is live?"

Expected agent behaviour:
- Uses the mapping output and existing Semantic layer metadata to reason forward
- Identifies which existing entities will be enriched (CustomerCompliance_H,
  CustomerInsight_H) and which new attributes need to be added
- Flags that existing views (Customer_Enriched) will automatically surface the
  new attributes once the DDL changes are applied
- Notes any governance implications — regulated attributes that will need access
  controls before the feed goes live

**Talking point:**
> "The pipeline team hasn't written a line of code yet, but the impact analysis
> is already done. Sarah can hand the mapping spec and the impact report to the
> engineer on the same day. That's what compresses the 2–3 day process into
> a morning's work."

**Why we stop here:**
> "In a real organisation, the actual domain model changes and pipeline build
> happen after this mapping spec is reviewed and approved — just as Sarah would
> do in her normal workflow. What we've demonstrated is the part that AI makes
> fast: the knowledge work. The pipeline engineering follows the normal process."

## Key Talking Points

- **Days to minutes**: the mapping that would take 2–3 days is done in minutes
- **Tacit knowledge is irrelevant**: the agent doesn't need to know that `ORIG_CLTV`
  means Combined LTV because that knowledge is already in the semantic metadata
- **Confidence tiers build trust**: a BA can act on AUTO mappings immediately
  and focus her attention on REVIEW and FLAG items only
- **Governance-aware**: the agent proactively identifies regulated attributes —
  the human doesn't have to remember to check
- **Scale mismatch detection**: this is the killer demo moment — the agent spots
  that two "credit score" columns use different scales, which a tired BA working
  at midnight might easily miss
- **The output is a deliverable**: the mapping spec and impact analysis go
  straight to the pipeline team; the framework produces artefacts that fit the
  existing engineering workflow
