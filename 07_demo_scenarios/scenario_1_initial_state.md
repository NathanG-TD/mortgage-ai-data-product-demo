# Scenario 1 — The Mature Domain Model

## Objective

Orient the audience to the existing state of the MortgagePlatform data product.
Show that the domain model is rich, well-documented, and fully discoverable by
an agent — without any manual intervention.

## Audience

Business Analysts, Data Architects, and any business stakeholders attending.

## Duration

~10 minutes

## Narrative Script

**Setup line (presenter):**
> "Before we look at what happens when new data arrives, let me show you what
> Sarah is working with today. The MortgagePlatform has four source systems feeding
> into an enterprise domain model — Loan Origination, Loan Servicing, Customer CRM,
> and our Collateral system. All of this has been modelled, documented, and made
> agent-discoverable using our AI-Native Data Product framework."

## Demo Steps

### Step 1 — Show the data_product_map

Run in Claude / agent interface:

Attach the "Access_Data_Product_Starter.md" file into Claude, from the AI Native Data Products design standards repository, this gives the Agent clear instructions on how to use the data product.

> "What source systems are currently registered in the MortgagePlatform and
> what domain entities do they feed?"

Expected agent behaviour:
- Queries `MortgagePlatform_Memory.data_product_map`
- Returns a table of: source system → staging table → domain entity mappings
- Notes which entities have the richest metadata (COMMENT ON coverage)

### Step 2 — Show the Business Glossary

> "What does 'CLTV' mean in the context of this data product?"

Expected agent behaviour:
- Queries `MortgagePlatform_Memory.Business_Glossary`
- Returns the glossary entry for CLTV with business definition and source reference
- This demonstrates that tacit knowledge has been made explicit

### Step 3 — Show domain entity richness

> "Tell me about the Customer entity — what attributes does it have and
> where do they come from?"

Expected agent behaviour:
- Reads `MortgagePlatform_Domain.Customer` COMMENT ON metadata
- Lists attributes with their source system origins
- Shows the Customer entity is currently fed by the CRM source only
  (sets up the Act 2 reveal that bureau data will enrich it)

### Step 4 — Ad-hoc analytics question

> "How many customers in the portfolio have an LTV above 80% and are
> currently more than 30 days delinquent?"

Expected agent behaviour:
- Identifies the relevant domain entities (Loan, LoanPerformance)
- Generates the appropriate SQL join
- Returns the result with a plain-language summary

## Key Talking Points

- **No manual documentation**: every piece of metadata was captured at design time
  and is queryable by the agent right now
- **Discoverability**: the agent doesn't need to be told which tables to look at —
  it discovers them from the Memory module
- **Tacit knowledge made explicit**: business definitions, source lineage, and
  transformation rules are all stored, not in someone's head
