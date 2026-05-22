-- ==============================================================================
-- OBSERVE BY SNOWFLAKE - COMPLETE DEPLOYMENT LOG
-- All Steps Performed in This Implementation Session
-- ==============================================================================
-- Date: 2026-05-22
-- Account: TZC19654 | User: SATISH | Role: ACCOUNTADMIN
-- ==============================================================================

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 1: FOUNDATION - DATABASE, SCHEMAS, ROLES, WAREHOUSES                 ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 1.1 Created databases
-- CREATE DATABASE IF NOT EXISTS OBSERVABILITY_PLATFORM;
-- CREATE DATABASE IF NOT EXISTS OBSERVABILITY_PLATFORM_DEV;
-- CREATE DATABASE IF NOT EXISTS OBSERVABILITY_PLATFORM_STAGING;

-- 1.2 Created schemas
-- RAW_TELEMETRY, BRONZE, SILVER, GOLD, AI_SRE, GOVERNANCE, CONTEXT_GRAPH, ALERTING, COST_OPS

-- 1.3 Created RBAC roles hierarchy
-- OBSERVABILITY_ADMIN > OBSERVABILITY_ENGINEER > OBSERVABILITY_ANALYST > OBSERVABILITY_VIEWER
-- AI_SRE_AGENT, TELEMETRY_INGESTOR, GOVERNANCE_OFFICER

-- 1.4 Created warehouses
-- INGEST_WH (MEDIUM, multi-cluster 1-4)
-- TRANSFORM_WH (LARGE, multi-cluster 1-3)
-- AI_SRE_WH (MEDIUM, multi-cluster 1-2)
-- DASHBOARD_WH (SMALL, multi-cluster 1-2)

-- 1.5 Created resource monitor
-- OBSERVABILITY_MONITOR (5000 credits/month, alerts at 75%/90%, suspend at 100%)

-- Source file: /Untitled 1.sql (Sections 1-3)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 2: RAW TELEMETRY TABLES (BRONZE LAYER)                                ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 2.1 Created raw ingestion tables
-- RAW_LOGS (clustered by date/service/severity, 90-day retention)
-- RAW_METRICS (clustered by date/metric/service, 90-day retention)
-- RAW_TRACES (clustered by date/service/trace_id, 30-day retention)
-- RAW_K8S_EVENTS (clustered by date/cluster/namespace, 90-day retention)
-- RAW_SNOWFLAKE_TELEMETRY (clustered by date/type/warehouse, 90-day retention)
-- RAW_CLOUD_TELEMETRY (clustered by date/provider/service, 90-day retention)
-- RAW_CICD_TELEMETRY (clustered by date/system/status, 90-day retention)

-- 2.2 Created ingestion infrastructure
-- TELEMETRY_LANDING_STAGE (internal stage with directory enabled)
-- OTEL_JSON_FORMAT (JSON file format for OpenTelemetry)
-- TELEMETRY_PARQUET_FORMAT (Parquet for batch ingestion)
-- LOGS_SNOWPIPE (auto-ingest pipe for log files)

-- Source file: /Untitled 1.sql (Sections 4-5)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 3: DYNAMIC TABLES - SILVER LAYER (Enriched)                           ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 3.1 DT_ENRICHED_LOGS (5-min lag, incremental refresh)
--     Adds: severity_rank, log_hour, log_date, is_error_indicator

-- 3.2 DT_ENRICHED_METRICS (2-min lag, incremental refresh)
--     Adds: metric_minute, metric_hour, metric_date

-- 3.3 DT_ENRICHED_TRACES (2-min lag, incremental refresh)
--     Adds: is_error, is_root_span, latency_bucket, trace_hour

-- Source file: /Untitled 1.sql (Section 6)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 4: DYNAMIC TABLES - GOLD LAYER (Aggregated Analytics)                 ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 4.1 DT_SERVICE_HEALTH_SCORE (5-min lag)
--     Computes: health_score (0-100), success_rate, avg_latency, error_count

-- 4.2 DT_INCIDENT_METRICS (5-min lag)
--     Computes: error_count, affected_traces, duration, affected_hosts per day/service

-- 4.3 DT_SLO_COMPLIANCE (10-min lag)
--     Computes: availability_sli, latency_sli, p50/p95/p99 latency per day/service

-- 4.4 DT_COST_ANALYTICS (30-min lag)
--     Computes: total_credits, query_count, avg_execution_ms, credits_per_query

-- Source file: /Untitled 1.sql (Section 7)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 5: CONTEXT GRAPH - SERVICE DEPENDENCIES                               ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 5.1 SERVICE_REGISTRY table (service metadata, SLOs, ownership)
-- 5.2 SERVICE_DEPENDENCIES table (source->target relationships)
-- 5.3 DT_AUTO_DISCOVERED_DEPENDENCIES (15-min lag, auto-discovers from traces)

-- Source file: /Untitled 1.sql (Section 8)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 6: AI SRE TABLES & CORTEX SEARCH                                     ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 6.1 INCIDENTS table (full incident lifecycle tracking)
-- 6.2 ANOMALY_DETECTIONS table (detected anomalies with scores)
-- 6.3 AI_SRE_ACTIONS table (AI action audit trail)
-- 6.4 RUNBOOKS table (operational runbooks with embeddings)
-- 6.5 Cortex Search Service: COMMENTED OUT (not available on trial accounts)

-- Source file: /Untitled 1.sql (Section 9)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 7: ALERTING FRAMEWORK                                                 ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 7.1 ALERT_RULES table (configurable alert definitions)
-- 7.2 ALERT_HISTORY table (triggered alert records)
-- 7.3 EVALUATE_ALERTS task (1-minute schedule, checks health score thresholds)

-- Source file: /Untitled 1.sql (Section 10)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 8: GOVERNANCE & SECURITY POLICIES                                     ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 8.1 MASK_LOG_PII masking policy (role-based PII protection)
-- 8.2 MASK_QUERY_TEXT masking policy (role-based query text redaction)
-- 8.3 ENVIRONMENT_ACCESS row access policy (environment-based filtering)
-- 8.4 Applied policies to RAW_LOGS and RAW_SNOWFLAKE_TELEMETRY
-- 8.5 DATA_RETENTION_POLICIES table + retention rules
-- 8.6 ENFORCE_RETENTION task (daily at 2AM, deletes expired data)

-- Source file: /Untitled 1.sql (Section 11)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 9: COST MONITORING VIEWS                                              ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 9.1 V_DAILY_CREDIT_CONSUMPTION (warehouse credit usage over 90 days)
-- 9.2 V_AI_SERVICES_COST (AI services daily credit consumption)
-- 9.3 V_STORAGE_COST_ANALYSIS (table storage breakdown)

-- Source file: /Untitled 1.sql (Section 12)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 10: SAMPLE DATA INSERTION                                             ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 10.1 RAW_LOGS: 500 records (5 services, multi-severity, production/staging/dev)
-- 10.2 RAW_METRICS: 1000 records (8 metric types, 5 services)
-- 10.3 RAW_TRACES: 600 records (6 span types, latency buckets, error spans)
-- 10.4 RAW_K8S_EVENTS: 200 records (2 clusters, OOMKill/Pulled/BackOff events)
-- 10.5 SERVICE_REGISTRY: 5 services (payment, user, order, inventory, notification)
-- 10.6 SERVICE_DEPENDENCIES: 8 relationships (sync/async, gRPC/REST/Kafka)
-- 10.7 INCIDENTS: 6 incidents (P1-P3, open/resolved, with MTTR)
-- 10.8 ALERT_RULES: 5 rules (health/latency/error rate thresholds)
-- 10.9 ALERT_HISTORY: 52 triggered alerts (last 7 days)
-- 10.10 RUNBOOKS: 4 operational runbooks (gateway timeout, OOM, DB pool, error triage)

-- Verified Dynamic Tables populated:
-- DT_ENRICHED_METRICS: 1000 rows
-- DT_ENRICHED_TRACES: 600 rows
-- DT_SERVICE_HEALTH_SCORE: 340 rows
-- DT_SLO_COMPLIANCE: 15 rows


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 11: ADVANCED OPS - CORTEX AGENT CONFIGS                               ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 11.1 CORTEX_AGENT_CONFIGS table
-- 11.2 Inserted 4 AI agent configurations:
--      - Incident Investigator (INCIDENT_ANALYSIS)
--      - Anomaly Detector (ANOMALY_DETECTION)
--      - Capacity Planner (CAPACITY_PLANNING)
--      - Cost Optimizer (COST_OPTIMIZATION)

-- Source file: /observability_advanced_ops.sql (Section A)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 12: ADVANCED OPS - ANOMALY DETECTION                                  ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 12.1 SP_TRAIN_ANOMALY_MODEL stored procedure (Cortex ML anomaly detection)
-- 12.2 V_METRIC_ANOMALY_CANDIDATES view (z-score anomaly candidates)

-- Source file: /observability_advanced_ops.sql (Section B)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 13: ADVANCED OPS - GOVERNANCE AUDIT VIEWS                             ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 13.1 V_ACCESS_AUDIT_REPORT (query history for observability DB)
-- 13.2 V_PRIVILEGE_AUDIT (grants to observability roles)
-- 13.3 V_AI_GOVERNANCE_AUDIT (AI action audit with token estimates)
-- 13.4 V_DATA_CLASSIFICATION_STATUS (PII column classification)
-- 13.5 V_GOVERNANCE_MATURITY_SCORE (compliance scoring across 4 domains)

-- Source file: /observability_advanced_ops.sql (Section C)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 14: ADVANCED OPS - COST OPTIMIZATION VIEWS                            ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 14.1 V_WAREHOUSE_OPTIMIZATION_RECOMMENDATIONS (right-sizing with savings estimates)
-- 14.2 V_QUERY_OPTIMIZATION_CANDIDATES (spill/pruning/long-running detection)
-- 14.3 V_STORAGE_LIFECYCLE_RECOMMENDATIONS (archival candidates by age/size)

-- Source file: /observability_advanced_ops.sql (Section D)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 15: ADVANCED OPS - STREAMS & TASKS ORCHESTRATION                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 15.1 LOGS_STREAM (append-only on RAW_LOGS)
-- 15.2 METRICS_STREAM (append-only on RAW_METRICS)
-- 15.3 TRACES_STREAM (append-only on RAW_TRACES)
-- 15.4 PROCESS_ERROR_LOGS task (2-min, detects error bursts from stream) - RESUMED
-- 15.5 SNOWFLAKE_TELEMETRY_COLLECTOR task (hourly, collects query history) - RESUMED

-- Source file: /observability_advanced_ops.sql (Section E)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 16: ADVANCED OPS - OPERATIONAL PLAYBOOKS                              ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 16.1 OPERATIONAL_PLAYBOOKS table
-- 16.2 Inserted 5 playbooks:
--      - P1 Service Outage Response (30 min estimated)
--      - High Error Rate Investigation (45 min)
--      - Cross-Region Failover Procedure (60 min)
--      - Warehouse Scaling Response (15 min)
--      - Monthly FinOps Review (120 min)

-- Source file: /observability_advanced_ops.sql (Section F)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 17: ADVANCED OPS - IMPLEMENTATION ROADMAP                             ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 17.1 IMPLEMENTATION_ROADMAP table
-- 17.2 Inserted 25 milestones across 6 phases:
--      Phase 1: Foundation (5 items - COMPLETE)
--      Phase 2: Telemetry Lakehouse (5 items - 4 COMPLETE, 1 IN_PROGRESS)
--      Phase 3: AI SRE Enablement (5 items - 1 COMPLETE, 1 IN_PROGRESS, 3 PLANNED)
--      Phase 4: Governance & Security (4 items - 3 COMPLETE, 1 PLANNED)
--      Phase 5: Enterprise Automation (3 items - 2 COMPLETE, 1 IN_PROGRESS)
--      Phase 6: Advanced AI Operations (3 items - all PLANNED)

-- Source file: /observability_advanced_ops.sql (Section G)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ STEP 18: STREAMLIT OBSERVABILITY COMMAND CENTER                             ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- 18.1 Created project: /observability-command-center/
-- 18.2 Files created:
--      - snowflake.yml (COMPUTE_WH, SYSTEM_COMPUTE_POOL_CPU)
--      - pyproject.toml (streamlit[snowflake]>=1.54.0)
--      - .streamlit/config.toml
--      - streamlit_app.py (6 pages)
-- 18.3 Dashboard pages:
--      - Executive Overview (health scores, MTTR, alerts, incidents)
--      - Service Health (per-service metrics, trends)
--      - SLO Dashboard (availability/latency SLI compliance)
--      - Incidents (management, severity breakdown)
--      - Cost Observatory (credits, optimization recommendations)
--      - AI SRE Assistant (Cortex AI natural language + service registry)


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ ADDITIONAL FILES GENERATED (Not Deployed to Snowflake)                     ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- /observability_ai_sre.py
--   - TelemetryIngestor class (logs, metrics, traces ingestion)
--   - AISREEngine class (Cortex AI incident investigation, anomaly detection, alert summary)
--   - ContextGraphBuilder class (topology discovery, trace-log correlation, blast radius)
--   - SnowflakeTelemetryCollector class (query history, warehouse metrics)
--   - Stored procedure registration framework

-- /terraform/main.tf
--   - Snowflake provider configuration
--   - Database, schema, warehouse, role resources
--   - Resource monitors, network policies
--   - Variables for environment/region/retention/credits

-- /github_actions_cicd.yml
--   - Validate & Lint job (SQL, Python, Terraform)
--   - Security Scan job (secret detection, SAST, Terraform security)
--   - Integration Tests job
--   - Deploy Infrastructure job (Terraform plan/apply)
--   - Deploy SQL Objects job (Snowflake CLI)
--   - Deploy Streamlit job
--   - Post-Deployment Validation job

-- /implementation_plan.sql
--   - 6-phase implementation roadmap with detailed steps
--   - Team structure & RACI matrix
--   - Cost estimates per phase
--   - Key risks & mitigations
--   - Deployment validation checklists


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ FIXES APPLIED DURING DEPLOYMENT                                            ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- Fix 1: DATA_RETENTION_TIME_IN_DAYS exceeds 90-day max (trial account)
--   - RAW_METRICS: 365 -> 90
--   - RAW_SNOWFLAKE_TELEMETRY: 365 -> 90
--   - RAW_CICD_TELEMETRY: 180 -> 90

-- Fix 2: EMBED_TEXT_1024 not available on trial accounts
--   - Commented out Cortex Search Service (AI_SRE_RUNBOOK_SEARCH)

-- Fix 3: AVG_RUNNING column doesn't exist in WAREHOUSE_METERING_HISTORY
--   - Removed AVG(AVG_RUNNING) AS AVG_CONCURRENT_QUERIES

-- Fix 4: START_TIME not QUERY_START_TIME in QUERY_HISTORY
--   - Replaced QUERY_START_TIME with START_TIME in V_ACCESS_AUDIT_REPORT

-- Fix 5: METERING_DAILY_HISTORY uses USAGE_DATE not START_TIME
--   - Replaced DATE_TRUNC('DAY', START_TIME) with USAGE_DATE

-- Fix 6: TABLE_STORAGE_METRICS has no ROW_COUNT, BYTES, LAST_ALTERED
--   - Replaced with ACTIVE_BYTES, TIME_TRAVEL_BYTES, FAILSAFE_BYTES, TABLE_CREATED

-- Fix 7: PARSE_JSON not allowed in VALUES clause
--   - Converted INSERT...VALUES to INSERT...SELECT...UNION ALL SELECT


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ DEPLOYED OBJECT INVENTORY                                                  ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- DATABASE: OBSERVABILITY_PLATFORM
--
-- SCHEMA: RAW_TELEMETRY
--   Tables: RAW_LOGS, RAW_METRICS, RAW_TRACES, RAW_K8S_EVENTS,
--           RAW_SNOWFLAKE_TELEMETRY, RAW_CLOUD_TELEMETRY, RAW_CICD_TELEMETRY
--   Stages: TELEMETRY_LANDING_STAGE
--   Pipes: LOGS_SNOWPIPE
--   Streams: LOGS_STREAM, METRICS_STREAM, TRACES_STREAM
--   File Formats: OTEL_JSON_FORMAT, TELEMETRY_PARQUET_FORMAT
--
-- SCHEMA: SILVER
--   Dynamic Tables: DT_ENRICHED_LOGS, DT_ENRICHED_METRICS, DT_ENRICHED_TRACES
--
-- SCHEMA: GOLD
--   Dynamic Tables: DT_SERVICE_HEALTH_SCORE, DT_INCIDENT_METRICS,
--                   DT_SLO_COMPLIANCE, DT_COST_ANALYTICS
--
-- SCHEMA: AI_SRE
--   Tables: INCIDENTS, ANOMALY_DETECTIONS, AI_SRE_ACTIONS, RUNBOOKS,
--           CORTEX_AGENT_CONFIGS, OPERATIONAL_PLAYBOOKS, IMPLEMENTATION_ROADMAP
--   Procedures: SP_TRAIN_ANOMALY_MODEL
--   Views: V_METRIC_ANOMALY_CANDIDATES
--   Tasks: PROCESS_ERROR_LOGS (RESUMED), SNOWFLAKE_TELEMETRY_COLLECTOR (RESUMED)
--
-- SCHEMA: CONTEXT_GRAPH
--   Tables: SERVICE_REGISTRY, SERVICE_DEPENDENCIES
--   Dynamic Tables: DT_AUTO_DISCOVERED_DEPENDENCIES
--
-- SCHEMA: ALERTING
--   Tables: ALERT_RULES, ALERT_HISTORY
--   Tasks: EVALUATE_ALERTS (RESUMED)
--
-- SCHEMA: GOVERNANCE
--   Tables: DATA_RETENTION_POLICIES
--   Views: V_ACCESS_AUDIT_REPORT, V_PRIVILEGE_AUDIT, V_AI_GOVERNANCE_AUDIT,
--          V_DATA_CLASSIFICATION_STATUS, V_GOVERNANCE_MATURITY_SCORE
--   Masking Policies: MASK_LOG_PII, MASK_QUERY_TEXT
--   Row Access Policies: ENVIRONMENT_ACCESS
--   Tasks: ENFORCE_RETENTION (RESUMED)
--
-- SCHEMA: COST_OPS
--   Views: V_DAILY_CREDIT_CONSUMPTION, V_AI_SERVICES_COST, V_STORAGE_COST_ANALYSIS,
--          V_WAREHOUSE_OPTIMIZATION_RECOMMENDATIONS, V_QUERY_OPTIMIZATION_CANDIDATES,
--          V_STORAGE_LIFECYCLE_RECOMMENDATIONS
--
-- ROLES: OBSERVABILITY_ADMIN, OBSERVABILITY_ENGINEER, OBSERVABILITY_ANALYST,
--        OBSERVABILITY_VIEWER, AI_SRE_AGENT, TELEMETRY_INGESTOR, GOVERNANCE_OFFICER
--
-- WAREHOUSES: INGEST_WH, TRANSFORM_WH, AI_SRE_WH, DASHBOARD_WH
--
-- RESOURCE MONITORS: OBSERVABILITY_MONITOR
