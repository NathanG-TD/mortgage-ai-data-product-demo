---
name: bian-mortgage-mapping
description: >
  Maps source system tables and columns to the MortgagePlatform BIAN-aligned
  domain model, with column-level confidence scoring, governance flagging, and
  Excel output. Designed for use with the MortgagePlatform Teradata environment
  and the Claude Desktop MCP integration.
  Use this skill whenever a user asks to map, analyse, or align any source data
  file to the MortgagePlatform domain model. Also use when the user asks to
  onboard a new source system, assess data coverage, identify gaps in the domain
  model, or produce a mapping specification for a Business Analyst to review.
  This skill is specifically scoped to the 8 BIAN Service Domains implemented
  in MortgagePlatform_Domain (Mortgage Loan Application, Mortgage Loan, Party,
  Customer Profile, Customer Credit Rating, Collateral Asset Administration,
  Payment, Customer Statement). For mappings outside this scope, a different
  skill or custom approach is required.
---

# BIAN Mortgage Mapping Agent -- Skill

## 1. Overview

This skill maps source system columns to target entities in the MortgagePlatform
BIAN-aligned domain model. It operates in three phases:

1. **Phase 1 -- KS Readiness Check** -- validates that the MortgagePlatform
   Knowledge Source (Semantic + Domain modules) is present and sufficiently
   populated to support accurate mapping
2. **Phase 2 -- SS Configuration & Readiness Check** -- user declares the Source
   Specification (the source tables to be mapped); agent validates metadata and
   runs SMAG (Source Metadata Auto-Generation) if descriptions are missing
3. **Phase 3 -- Mapping Execution** -- BIAN Service Domain candidate selection,
   entity-level candidate scoring, column-level confidence scoring, governance
   flagging, and Excel output

**Read bian_knowledge.md before every mapping session** to apply the correct
BIAN Service Domain vocabulary, scoring heuristics, and governance triggers.

**Mapping approach -- Version 1.0:**
This skill implements bottom-up mapping only: source columns are analysed and
mapped to their corresponding domain model entities and attributes. Top-down
mapping (starting from domain model gaps) is planned for v2.0.

---

## 2. Phase 1 -- Knowledge Source Readiness Check

**MANDATORY -- FIRST ACTION OF EVERY SESSION:**

Before doing anything else, capture the current timestamp:

```python
from datetime import datetime
SESSION_TIMESTAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
print(SESSION_TIMESTAMP)
```

**ABSOLUTE RULE: NEVER use "000000" as the time component. The HHMMSS portion
of every filename and session ID MUST come from the actual captured timestamp.
If the timestamp was not captured, capture it now before generating any filename.**

### 2.1 KS Configuration

The KS is always fixed for this skill -- no user configuration required:

```
KS_SEMANTIC_DB   : MortgagePlatform_Semantic
KS_DOMAIN_DB     : MortgagePlatform_Domain
KS_MEMORY_DB     : MortgagePlatform_Memory
```

### 2.2 KS Readiness Check

Run these queries immediately after capturing the session timestamp.

**Required items:**

| # | Item | Query |
|---|------|-------|
| 1 | Domain entity catalogue | COUNT(*) WHERE module_name = 'DOMAIN' in entity_metadata |
| 2 | Column metadata (PII/sensitive flags) | COUNT(*) WHERE database_name = 'MortgagePlatform_Domain' in column_metadata |
| 3 | Business glossary | COUNT(*) WHERE source_module = 'DOMAIN' in Business_Glossary |
| 4 | FK relationships | COUNT(*) WHERE from_database = 'MortgagePlatform_Domain' in table_relationship |

```sql
SELECT 'entity_metadata'    AS ks_table, COUNT(*) AS domain_entries
FROM MortgagePlatform_Semantic.entity_metadata WHERE module_name = 'DOMAIN'
UNION ALL
SELECT 'column_metadata',   COUNT(*)
FROM MortgagePlatform_Semantic.column_metadata WHERE database_name = 'MortgagePlatform_Domain'
UNION ALL
SELECT 'business_glossary', COUNT(*)
FROM MortgagePlatform_Memory.Business_Glossary WHERE source_module = 'DOMAIN'
UNION ALL
SELECT 'table_relationship',COUNT(*)
FROM MortgagePlatform_Semantic.table_relationship WHERE from_database = 'MortgagePlatform_Domain'
ORDER BY 1;
```

**Readiness status:**

| Status | Condition | Action |
|--------|-----------|--------|
| **READY** | All 4 items present with >= 1 row each | Proceed to Phase 2 |
| **DEGRADED** | entity_metadata OK but column_metadata < 5 rows | Warn: governance flagging will be incomplete; proceed |
| **BLOCKED** | entity_metadata = 0 rows | STOP: MortgagePlatform_Semantic is not populated. Run 03_semantic scripts first. |

**KS Readiness Report format:**
```
=== PHASE 1: KNOWLEDGE SOURCE READINESS ===

  Semantic DB : MortgagePlatform_Semantic
  Domain DB   : MortgagePlatform_Domain
  Memory DB   : MortgagePlatform_Memory

  [OK/!!]  Domain entities catalogued : <N> entities
  [OK/!!]  Column metadata             : <N> columns with descriptions
  [OK/!!]  Business glossary           : <N> terms
  [OK/!!]  FK relationships            : <N> relationships

  -> KS Readiness: READY | DEGRADED | BLOCKED
     <reason and next action if not READY>

Session ID: <ks_db>_<ss_db>_<YYYYMMDD>_<HHMMSS>

OUTPUT_LANGUAGE : english (default)
  -> To change to Japanese output, specify OUTPUT_LANGUAGE: japanese
     when providing the SS configuration.

Please provide the Source Specification (SS).
  SS_TYPE options:
    teradata_db   -- source tables already on Teradata (provide SS_DATABASE)
    excel_upload  -- column definition spreadsheet (provide filename)
```

---

## 3. Phase 2 -- Source Specification (SS) Configuration

Only reached after KS readiness is READY or DEGRADED.

### 3.1 SS Configuration

#### SS-1: Teradata DB

```
SS_TYPE          : teradata_db
SS_DATABASE      : <db_name>            -- e.g. MortgagePlatform_Staging
SS_TABLES        : all | [table1, ...]  -- default: all tables in DB
SS_SOURCE_SYSTEM : <free text>          -- e.g. "Credit Bureau Feed", "Core Banking"
SMAG_DATABASE    : <db_name>            -- default: same as SS_DATABASE
OUTPUT_LANGUAGE  : english | japanese   -- default: english
```

#### SS-3: Excel Upload

```
SS_TYPE          : excel_upload
SS_FILE          : <filename>.xlsx
SS_SHEET         : <sheet_name>
SS_SOURCE_SYSTEM : <free text>
SMAG_DATABASE    : <db_name>
OUTPUT_LANGUAGE  : english | japanese
SS_COLUMN_MAP    :
  table_name     : <excel_column>   -- required
  column_name    : <excel_column>   -- required
  data_type      : <excel_column>   -- required
  is_pk          : <excel_column>   -- optional
  column_desc    : <excel_column>   -- optional
```

### 3.2 SS Readiness Check

**Required items for SS:**

| # | Item | Action if absent |
|---|------|-----------------|
| 1 | Table name + column name + data type | BLOCKED -- cannot proceed |
| 2 | Business descriptions | Trigger SMAG |
| 3 | PK/FK information | SMAG infers from DDL and naming conventions |

**Readiness status:**

| Status | Condition |
|--------|-----------|
| **READY** | Items 1-3 all present |
| **READY (SMAG-assisted)** | Item 1 present; items 2-3 absent -> SMAG completed |
| **BLOCKED** | Item 1 absent |

**CRITICAL -- OUTPUT_LANGUAGE applies to ALL text written by the agent into the
Excel output. The language of the conversation does NOT determine the language
of the Excel output. Only OUTPUT_LANGUAGE does. Default is ENGLISH.**

---

## 4. Source Metadata Auto-Generation (SMAG)

SMAG runs when source descriptions or PK/FK info are absent. It follows the
same three stages as the fs-mapping-agent skill:

### 4.1 SMAG Stage 1 -- DDL Structure Analysis

```sql
-- Table list
SELECT TableName FROM DBC.TablesV
WHERE DatabaseName = '<ss_database>' AND TableKind = 'T'
ORDER BY TableName;

-- Column structure
SELECT ColumnName, ColumnType, Nullable, DecimalTotalDigits,
       DecimalFractionalDigits, CharType, ColumnLength
FROM DBC.ColumnsV
WHERE DatabaseName = '<ss_database>' AND TableName = '<table_name>'
ORDER BY ColumnId;

-- Index information (PK inference)
SELECT IndexNumber, IndexType, UniqueFlag, ColumnName, ColumnPosition
FROM DBC.IndicesV
WHERE DatabaseName = '<ss_database>' AND TableName = '<table_name>'
ORDER BY IndexNumber, ColumnPosition;
```

**PK inference rules (apply in order, stop at first match):**

| Priority | Rule |
|----------|------|
| 1 | Column is part of a UNIQUE PRIMARY INDEX |
| 2 | Column named `<table>_id` (exact match) |
| 3 | Column named `id`, NOT NULL, high distinct rate |

### 4.2 SMAG Stage 2 -- Data Content Analysis

Run statistics per column to identify value patterns:

```sql
SELECT
    '<column_name>'                                     AS column_name,
    COUNT(*)                                            AS total_rows,
    COUNT(<column_name>)                                AS non_null_count,
    CAST((COUNT(*) - COUNT(<column_name>)) * 100.0
         / NULLIF(COUNT(*), 0) AS DECIMAL(5,2))         AS null_rate_pct,
    COUNT(DISTINCT <column_name>)                       AS distinct_count,
    CAST(MIN(<column_name>) AS VARCHAR(200))            AS sample_min,
    CAST(MAX(<column_name>) AS VARCHAR(200))            AS sample_max
FROM <ss_database>.<table_name>
SAMPLE 1000;
```

### 4.3 SMAG Stage 3 -- AI Description Generation

Use Stage 1 + Stage 2 results to generate a 1-3 sentence business description
for each column. Apply these BIAN-specific heuristics:

| Column name pattern | Inferred business concept |
|---------------------|--------------------------|
| _id, _key | Identifier or join key |
| _dt, _date | Date field |
| _amt, _amount | Monetary amount |
| _score | Risk or quality score |
| _flag, _indicator | Boolean condition |
| _cd, _code | Reference code value |
| _nm, _name | Name or label |
| _pct, _ratio | Percentage or ratio |
| enq_, enquiry_ | Credit bureau enquiry |
| num_, count_ | Count of events |

Apply GOVERNANCE_FLAG = Y in descriptions if column name matches Section 4 of
bian_knowledge.md governance vocabulary triggers.

---

## 5. Mapping Execution

### 5.1 Execution Modes

| Mode | Description | When to use |
|------|-------------|-------------|
| **Interactive** | One source table at a time; agent presents candidates for user confirmation before proceeding | High-value or ambiguous source systems |
| **Batch** | All tables processed automatically; flags low-confidence mappings for review | Well-understood source systems, large table counts |
| **Hybrid** | Auto-select when confidence > 0.75; pause for user confirmation otherwise | Default recommended mode |

### 5.2 Step A -- BIAN Service Domain Candidate Selection

For each source table:

1. Extract keywords from: table name + SMAG inferred_domain + column name patterns
2. Score each of the 8 BIAN Service Domains against keywords using vocabulary
   triggers from bian_knowledge.md Section 2
3. Select the top-scoring Service Domain as the primary candidate
4. Note the secondary candidate if scores are close (within 0.15)

**Output format:**
```
Source table   : <TABLE_NAME>
Primary SD     : <BIAN Service Domain> (score: 0.XX)
Secondary SD   : <BIAN Service Domain> (score: 0.XX) [if within 0.15]
Reasoning      : <1 sentence>
```

In Interactive mode, present candidates and wait for user confirmation before
proceeding to entity selection.

### 5.3 Step B -- Entity Candidate Selection

Within the chosen BIAN Service Domain, query entity_metadata:

```sql
SELECT entity_name, table_name, entity_description, entity_category,
       natural_key_column, record_count_approx
FROM MortgagePlatform_Semantic.entity_metadata
WHERE module_name = 'DOMAIN'
ORDER BY entity_name;
```

Score the entity descriptions against the source table description using:
- Name similarity: does entity_name contain keywords from source table name?
- Description overlap: do entity_description terms match SMAG table description terms?
- Category match: SNAPSHOT entities for time-series sources; MASTER for static

Shortlist top 3 entity candidates. Present with rationale in Interactive mode.

### 5.4 Step C -- Column-Level Mapping

For the confirmed target entity, retrieve its full column list:

```sql
-- Physical columns from DBC
SELECT ColumnName, ColumnType, ColumnLength, Nullable
FROM DBC.ColumnsV
WHERE DatabaseName = 'MortgagePlatform_Domain'
  AND TableName = '<Entity_H>'
ORDER BY ColumnId;

-- Semantic descriptions for flagged columns
SELECT column_name, business_description, is_pii, is_sensitive
FROM MortgagePlatform_Semantic.column_metadata
WHERE database_name = 'MortgagePlatform_Domain'
  AND table_name = '<Entity_H>';
```

For each source column, apply the 3-layer confidence scoring:

**Layer 1 -- Name similarity (weight: 0.4)**

| Score | Rule |
|-------|------|
| 1.0 | Exact or near-exact name match (same root word) |
| 0.8 | Source column name contains vocabulary trigger for target column (bian_knowledge.md Section 2) |
| 0.6 | Partial name match (abbreviation resolves to target concept) |
| 0.3 | Semantic relationship clear from description but name differs |
| 0.0 | No relationship to target column |

**Layer 2 -- Data type compatibility (weight: 0.3)**

| Score | Rule |
|-------|------|
| 1.0 | Exact type match (both DECIMAL, both DATE, both VARCHAR) |
| 0.8 | Compatible type (CHAR source -> VARCHAR target; INTEGER -> SMALLINT) |
| 0.5 | Implicit cast possible with documented transform |
| 0.0 | Incompatible without significant transformation |

**Layer 3 -- Value pattern/range (weight: 0.3)**

| Score | Rule |
|-------|------|
| 1.0 | Value range falls within documented domain column range |
| 0.5 | Value pattern matches but different scale (e.g. credit score scale) |
| 0.0 | Pattern clearly incompatible with target column semantics |

**Overall confidence = Layer1*0.4 + Layer2*0.3 + Layer3*0.3**

**Confidence tiers:**

| Tier | Score | Label | Meaning |
|------|-------|-------|---------|
| 1 | >= 0.85 | AUTO | High confidence -- auto-map recommended; BA should spot-check |
| 2 | 0.50-0.84 | REVIEW | BA confirmation required before pipeline use |
| 3 | < 0.50 | FLAG | Low confidence or ambiguous -- manual resolution required |

### 5.5 Special Mapping Rules

**UNMAPPED columns:**
If no target attribute exists for a source column, output TARGET_ATTRIBUTE = UNMAPPED.
Recommend the appropriate entity and suggest the new attribute name following
domain naming conventions (snake_case, descriptive, with appropriate suffix:
_dt for dates, _amt for amounts, _flag for booleans, _cd for codes).

**JOIN KEY detection:**
Mark IS_JOIN_KEY = Y when:
- Column is a primary key in the source (inferred from SMAG Stage 1)
- Column name is LOAN_SEQUENCE_NUMBER, CUSTOMER_ID, PROPERTY_ID, or any known
  natural key from the domain model keymaps

**GOVERNANCE FLAG:**
Mark GOVERNANCE_FLAG = Y when source column name or SMAG description contains
any term from bian_knowledge.md Section 4 governance vocabulary.
Always provide a GOVERNANCE_NOTE explaining the regulatory implication.

**SCALE MISMATCH:**
Mark TRANSFORMATION_RULE with explicit note when:
- Credit score source is Equifax 0-1200 (bureau feed) vs FICO 300-850 (origination)
- Date format is YYYYMM CHAR(6) -> DATE conversion required
- Y/N CHAR(1) -> BYTEINT 1/0 conversion required
- Any amount currency conversion

**IS_ENRICHMENT:**
Mark IS_ENRICHMENT = Y when:
- Source adds attributes to existing domain entities (e.g. bureau scores enriching
  CustomerCompliance_H or CustomerInsight_H that already has 37,500 customer rows)
- Mark IS_ENRICHMENT = N when source introduces entirely new entity rows

**IS_NEW_ATTRIBUTE:**
Mark IS_NEW_ATTRIBUTE = Y when:
- No matching column exists in the target entity for the source concept
- The concept belongs in this entity but the attribute needs to be added
- Always provide a recommended new column name and data type in AGENT_NOTES

---

## 6. Mapping Output

### 6.1 Output Format

One row per source column:

| Column | Description |
|--------|-------------|
| SOURCE_SYSTEM | From SS_SOURCE_SYSTEM parameter |
| SOURCE_TABLE | Staging table or Excel sheet name |
| SOURCE_COLUMN | Exact source column name |
| SOURCE_DATA_TYPE | Source column data type |
| SOURCE_DESCRIPTION | From SMAG or provided data dictionary |
| BIAN_SERVICE_DOMAIN | Target BIAN Service Domain (one of the 8 in scope) |
| TARGET_DATABASE | MortgagePlatform_Domain |
| TARGET_ENTITY | Target _H or _R table name (or UNMAPPED) |
| TARGET_ATTRIBUTE | Target column name (or UNMAPPED) |
| TARGET_DATA_TYPE | Target column data type |
| IS_ENRICHMENT | Y=adds to existing entity; N=new entity rows |
| IS_NEW_ATTRIBUTE | Y=attribute does not yet exist in target; N=existing column |
| IS_JOIN_KEY | Y if this is a natural key / join key |
| TRANSFORMATION_RULE | Required transform (NULL if direct map) |
| CONFIDENCE_TIER | AUTO / REVIEW / FLAG |
| CONFIDENCE_SCORE | 0.00-1.00 |
| MAPPING_RATIONALE | 1-2 sentence justification referencing both source and target semantics |
| GOVERNANCE_FLAG | Y if regulated attribute per bian_knowledge.md Section 4 |
| GOVERNANCE_NOTE | Regulatory implication if GOVERNANCE_FLAG = Y |
| AGENT_NOTES | Warnings, recommendations, scale mismatch notes, new attribute suggestions |

**OUTPUT_LANGUAGE rule:** All agent-written text (rationale, notes, governance notes)
MUST be in the OUTPUT_LANGUAGE setting. DEFAULT IS ENGLISH. Conversation language
does NOT override this setting.

### 6.2 Post-Mapping Summary

After the mapping table, always produce a structured summary:

```
=== MAPPING SUMMARY ===

Source: <SS_SOURCE_SYSTEM>
Tables mapped: <N>
Columns processed: <N>

Confidence breakdown:
  AUTO   (<N> columns, <pct>%)
  REVIEW (<N> columns, <pct>%)
  FLAG   (<N> columns, <pct>%)

UNMAPPED columns: <N>
  <column_name>: <recommendation>

Governance flags raised: <N>
  <column_name> [<category>]: <brief note>

Scale/encoding mismatches: <N>
  <description of each>

Recommended new attributes: <N>
  <entity>.<new_column> (<type>): <justification>

Is_Enrichment summary:
  <N> columns enrich existing entities
  <N> columns require new entity rows

BIAN Service Domain coverage:
  <domain>: <N> columns mapped
```

### 6.3 Excel Output File

Generate the mapping output to:
```
/mnt/user-data/outputs/bian_mapping_<ss_db_or_system>_<YYYYMMDD>_<HHMMSS>.xlsx
```

Structure: two sheets
- **Mapping Spec**: all columns from Section 6.1, one row per source column
- **Summary**: the post-mapping summary from Section 6.2

---

## 7. Session Logging

After generating the Excel output, log the session to Memory:

```sql
-- Check if agent_session table exists
SELECT COUNT(*) FROM DBC.TablesV
WHERE DatabaseName = 'MortgagePlatform_Memory'
  AND TableName = 'agent_session';
```

If it exists, insert a session record:
```sql
INSERT INTO MortgagePlatform_Memory.agent_session
(session_id, session_type, session_notes, session_date)
VALUES
('<YYYYMMDD_HHMMSS>_bian_mapping',
 'BIAN_MAPPING',
 'Mapped <SS_SOURCE_SYSTEM>: <N> tables, <N> columns, <N> AUTO/<N> REVIEW/<N> FLAG',
 CURRENT_DATE);
```

If agent_session does not exist, skip this step and note it in the output.

---

## 8. Complete Session Flow Reference

```
[1] User triggers skill
        |
[2] Capture session timestamp (MANDATORY -- FIRST ACTION)
        |
=============================================
 PHASE 1: KNOWLEDGE SOURCE CHECK
=============================================
[3] Run KS readiness query (4 tables)
[4] Display KS Readiness Report
    Generate Session ID
    -> READY/DEGRADED: proceed to Phase 2
    -> BLOCKED: stop, request fix
        |
=============================================
 PHASE 2: SOURCE SPECIFICATION
=============================================
[5] User provides SS configuration
[6] SS Readiness Check
    -> Descriptions present: READY
    -> Descriptions absent: run SMAG Stages 1-3
       -> Persist SMAG output to Teradata (if SS-1)
       -> Status: READY (SMAG-assisted)
    -> No columns: BLOCKED
[7] Display SS Readiness Report + SESSION READY banner
[8] Confirm execution mode: Interactive / Batch / Hybrid
[9] Confirm scope: all tables or subset
        |
=============================================
 MAPPING EXECUTION
=============================================
[10] For each source table:
  [A] Extract keywords -> score BIAN SDs -> select primary SD
      Interactive: present + wait for confirmation
      Batch/Hybrid: auto-select if score > 0.65
  [B] Score entity candidates within SD -> shortlist top 3
      Interactive: present + wait for confirmation
      Batch/Hybrid: auto-select top candidate
  [C] For each source column:
      -> 3-layer confidence scoring
      -> Identify: JOIN_KEY, GOVERNANCE_FLAG, SCALE_MISMATCH,
                   IS_ENRICHMENT, IS_NEW_ATTRIBUTE, UNMAPPED
      -> Assign confidence tier (AUTO/REVIEW/FLAG)
        |
[11] Generate Excel output
     bian_mapping_<system>_<YYYYMMDD>_<HHMMSS>.xlsx
        |
[12] Post-mapping summary (Section 6.2)
        |
[13] Session log to MortgagePlatform_Memory (if table exists)
        |
[14] Present output file to user
     Highlight: UNMAPPED columns, FLAG mappings, governance issues,
                new attribute recommendations
```

---

## 9. Demo Scenario -- Credit Bureau Feed (Act 2)

The primary test case for this skill is the credit bureau feed onboarding.
The withheld source (`08_withheld_source/`) simulates an Equifax/Illion feed.

**Key characteristics to handle well:**

1. **Abbreviated column names** (CRED_SCORE_CURR, ENQ_3M, REPMT_HIST_SCORE):
   Use SMAG Stage 1-3 to generate meaningful descriptions before mapping.

2. **Scale mismatch** (Equifax 0-1200 vs FICO 300-850):
   Flag explicitly with TRANSFORMATION_RULE and GOVERNANCE_NOTE.
   Do NOT map CRED_SCORE_CURR to LoanApplication_H.credit_score_at_application.
   Map to new CustomerInsight_H attribute (IS_NEW_ATTRIBUTE = Y).

3. **All mappings are IS_ENRICHMENT = Y**:
   The bureau feed enriches existing Customer entities -- it does not create
   new loan or property rows. All target entities already have 37,500 rows.

4. **Heavy governance flagging**:
   CRED_SCORE_CURR, NUM_DEFAULTS, BANKRUPTCY_FLAG, PART_IX_FLAG,
   SERIOUS_CREDIT_IMPAIRMENT, JUDGEMENT_AMT_TOTAL all trigger GOVERNANCE_FLAG = Y.

5. **Join via CUSTOMER_ID**:
   CUSTOMER_ID is the join key; BUREAU_RECORD_ID is the source PK.
   Both should be flagged IS_JOIN_KEY = Y.

6. **IS_NEW_ATTRIBUTE = Y for most bureau columns**:
   Most bureau attributes do not yet exist in the domain model.
   Agent should recommend specific new column names following domain conventions.
