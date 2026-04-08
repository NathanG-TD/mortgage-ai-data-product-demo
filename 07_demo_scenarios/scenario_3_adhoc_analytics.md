# Scenario 3 — Ad-hoc Analytics in Natural Language

## Objective

Show that the same framework that powers data mapping also enables business users
to ask analytics questions in plain English — against the now-enriched domain model.

## Audience

Business stakeholders (risk, product, marketing). Can run after Scenario 2.

## Duration

~10 minutes

## Narrative Script

**Setup line (presenter):**
> "Now that the bureau data is in the domain model, the Risk team doesn't have
> to wait for a new report to be built. They can ask questions right now."

## Suggested Questions

These questions are designed to span multiple entities and demonstrate
the value of a well-structured domain model:

### Risk / Fraud questions

> "Show me customers who have a credit score drop of more than 50 points
> since last bureau refresh AND are currently more than 60 days delinquent."

> "Which loans have an estimated LTV above 90% where the property is in a
> high or extreme fire risk zone?"

> "How many customers have both a derogatory mark on their bureau file
> AND a churn risk score above 0.7?"

### Churn questions

> "What is the distribution of churn risk scores across customer segments?
> Which segment has the highest proportion of high-risk customers?"

> "Show me customers who are digitally enrolled but haven't logged in for
> more than 90 days AND have a high churn risk band."

### Portfolio questions

> "What is the total current UPB of loans where the borrower is in the
> Emerging Affluent or Affluent segment?"

> "For loans that were modified in the last 12 months, what is the average
> credit score and delinquency status distribution?"

### Lineage questions (for a data-literate audience)

> "Where does the `bureau_credit_score_equifax` attribute on the Customer
> entity come from, and what transformation was applied?"

> "If the Equifax feed changes its score scale, which domain attributes
> and downstream reports would be affected?"

## Key Talking Points

- **No SQL required**: the business user gets answers without needing to know
  the data model structure
- **Lineage on demand**: "where does this data come from?" is a first-class
  question the agent can answer, not a ticket to raise with the data team
- **The mapping work pays dividends immediately**: the metadata created during
  the Scenario 2 mapping exercise is what makes these questions answerable

## Closing Line

> "What Sarah built in minutes during Scenario 2 — the mapping, the semantic
> registration, the documentation — that's the investment that makes Scenario 3
> possible. Every new source that gets onboarded this way makes the whole platform
> smarter. That's the compounding value of the AI-Native Data Product framework."
