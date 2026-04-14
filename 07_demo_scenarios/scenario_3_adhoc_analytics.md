# Scenario 3 — Ad-hoc Analytics in Natural Language

## Objective

Show that the same framework that powers data mapping also enables business users
to ask analytics questions in plain English — against the existing domain model,
right now, without waiting for the bureau integration to be built.

## Audience

Business stakeholders (risk, product, marketing). Can run after Scenario 2.

## Duration

~10 minutes

## Narrative Script

**Setup line (presenter):**
> "While the pipeline team works through the bureau feed integration, the Risk
> team doesn't have to wait. The domain model we already have is rich enough to
> answer most of their questions today. Let's show what that looks like."

**Why this framing matters:**
> "This is actually the realistic story. In most organisations, a new data
> source takes weeks to integrate properly. But the AI-Native Data Product
> means the existing model is already queryable in natural language — so the
> business gets value from day one, not from integration day."

## Suggested Questions

These questions are designed to span multiple entities and demonstrate
the depth of the existing domain model. Every question below has been
verified to return meaningful results from the loaded data.

### Risk questions

> "Show me loans where the current estimated LTV is above 80% and the
> security property is in a High or Extreme fire risk zone."

Expected result: ~3,886 loans — a genuine concentration risk story.

**Talking point:**
> "That answer requires joining loan performance data, property data, and
> a risk classification table. The agent did that in seconds. A risk analyst
> doing this manually would spend half a day writing the query and validating
> the joins."

> "Of those high-LTV fire-risk loans, how many are also showing delinquency
> of 30 days or more?"

Expected result: a small number — demonstrates the agent can layer conditions
without being re-taught the model structure.

### Churn / retention questions

> "Which customers are enrolled in digital banking but haven't logged in for
> more than 90 days AND have a High churn risk band?"

Expected result: ~365 customers — a concrete, actionable retention list.

**Talking point:**
> "That's a retargeting segment the marketing team can act on today.
> No data warehouse ticket, no BI report request."

> "What is the distribution of churn risk scores across customer segments?
> Which segment has the highest proportion of high-risk customers?"

Expected result: Mass Market has the largest volume; show churn band breakdown
by segment. Demonstrates the agent understands the segment hierarchy.

### Portfolio / compliance questions

> "What is the total current outstanding balance across each customer segment?"

Expected result:
- Mass Market: ~$5.6B
- Emerging Affluent: ~$3.8B
- Affluent: ~$2.2B
- Private Banking: ~$492M
- Business Owner: ~$397M

**Talking point:**
> "The relationship manager for Private Banking can immediately see that segment
> holds $492 million in mortgage balances. That's a talking point for an executive
> briefing — pulled in seconds."

> "How many customers currently have a KYC status that is non-compliant —
> either Expired, Pending, or Failed — and what is their combined outstanding
> loan balance?"

Expected result: ~4,544 customers with non-compliant KYC — a genuine compliance
exposure the bank needs to act on.

**Talking point:**
> "KYC remediation is a real regulatory obligation. The compliance team can now
> generate their remediation list directly, without a data extract request."

### Lineage question (for a data-literate audience)

> "Where does the churn_risk_score attribute come from, and what does
> a score of 0.7 or above indicate?"

Expected agent behaviour: reads Semantic layer metadata and Business Glossary
to explain that churn_risk_score is sourced from STG_Borrower_Profile,
is a model-generated propensity score on a 0–1 scale, and that values
above 0.7 are classified as High risk in the churn_risk_band column.

**Talking point:**
> "The agent can explain the data, not just query it. That's lineage on demand —
> no ticket to raise with the data engineering team."

## What This Demo Does NOT Show (and Why That's Fine)

The bureau data mapped in Scenario 2 is not yet in the domain model —
it is a specification waiting to be built. Questions referencing bureau
attributes (credit score from Equifax, derogatory marks, bankruptcy flags)
will correctly return "that attribute does not yet exist in the domain model."

This is the honest answer. Use it as a talking point:

> "The agent knows what it knows and what it doesn't. It won't hallucinate
> an answer from data that hasn't been integrated yet. When the pipeline team
> finishes the bureau feed ingestion, these same questions will just work —
> the semantic layer is already ready for them."

## Key Talking Points

- **No SQL required**: the business user gets answers without needing to know
  the data model structure
- **Value from day one**: the existing model answers real business questions
  right now — no need to wait for the next data source to be integrated
- **Lineage on demand**: "where does this data come from?" is a first-class
  question the agent can answer, not a ticket to raise with the data team
- **Honest about gaps**: the agent correctly identifies attributes that don't
  exist yet, which builds trust — it won't fabricate answers

## Closing Line

> "What Sarah built in minutes during Scenario 2 — the mapping spec, the impact
> analysis, the governance flags — that's the investment that makes the next
> integration faster. And what we've just seen is what the platform already
> delivers today, before that integration is even built. Every new source
> onboarded this way makes the whole platform smarter. That's the compounding
> value of the AI-Native Data Product framework."
