-- =============================================================================
-- recreate_staging_tables.sql
-- Drop and recreate STG_Freddie_Origination and STG_Freddie_Performance
-- to pick up the additional columns added after initial creation.
--
-- Run this once if you created the staging tables before the column-count
-- fixes were applied (commits 4069ce2 and 53f7c42).
--
-- Safe to run: STG_Borrower_Profile and STG_Property_Valuation are unchanged.
-- =============================================================================

DROP TABLE MortgagePlatform_Staging.STG_Freddie_Origination;
DROP TABLE MortgagePlatform_Staging.STG_Freddie_Performance;
