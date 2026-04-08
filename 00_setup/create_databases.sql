-- =============================================================================
-- create_databases.sql
-- MortgagePlatform AI-Native Data Product — Database Setup
--
-- Run this script once before any module scripts.
-- Idempotent: uses CREATE DATABASE IF NOT EXISTS equivalent pattern.
-- Adjust PERM sizes to match your Teradata environment.
-- =============================================================================

-- Staging: raw source data ingestion area
CREATE DATABASE MortgagePlatform_Staging
    AS PERMANENT = 2e9,   -- 2 GB default; increase for full Freddie Mac dataset
       SPOOL = 2e9;

-- Memory: agent memory, design decisions, business glossary, documentation
CREATE DATABASE MortgagePlatform_Memory
    AS PERMANENT = 500e6,
       SPOOL = 1e9;

-- Semantic: discovery metadata, data product map, relationship paths
CREATE DATABASE MortgagePlatform_Semantic
    AS PERMANENT = 500e6,
       SPOOL = 1e9;

-- Domain: core business entities — the enterprise target model
CREATE DATABASE MortgagePlatform_Domain
    AS PERMANENT = 2e9,
       SPOOL = 2e9;
