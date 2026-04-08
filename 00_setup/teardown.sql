-- =============================================================================
-- teardown.sql
-- MortgagePlatform AI-Native Data Product — Full Teardown
--
-- Drops all module databases and all objects within them.
-- Run this to fully reset the demo environment.
-- Safe to re-run: errors on non-existent databases are expected and ignorable.
-- =============================================================================

-- Drop in reverse dependency order
DELETE DATABASE MortgagePlatform_Domain ALL;
DROP DATABASE MortgagePlatform_Domain;

DELETE DATABASE MortgagePlatform_Semantic ALL;
DROP DATABASE MortgagePlatform_Semantic;

DELETE DATABASE MortgagePlatform_Memory ALL;
DROP DATABASE MortgagePlatform_Memory;

DELETE DATABASE MortgagePlatform_Staging ALL;
DROP DATABASE MortgagePlatform_Staging;
