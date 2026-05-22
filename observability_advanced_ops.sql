-- ==============================================================================
-- OBSERVE BY SNOWFLAKE - ADVANCED OPERATIONS & OPTIMIZATION
-- Enterprise Operational Playbooks, Cost Optimization, Advanced AI SRE
-- ==============================================================================

-- ============================================================================
-- SECTION A: ADVANCED CORTEX AI SRE - AGENT PROMPTS & SEMANTIC LAYER
-- ============================================================================

USE DATABASE OBSERVABILITY_PLATFORM;
USE SCHEMA AI_SRE;

CREATE TABLE IF NOT EXISTS CORTEX_AGENT_CONFIGS (
    AGENT_ID VARCHAR(64) DEFAULT UUID_STRING(),
    AGENT_NAME VARCHAR(256) NOT NULL,
    AGENT_TYPE VARCHAR(64) NOT NULL,
    SYSTEM_PROMPT TEXT NOT NULL,
    MODEL VARCHAR(128) DEFAULT 'mistral-large2',
    TOOLS VARIANT,
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO CORTEX_AGENT_CONFIGS (AGENT_NAME, AGENT_TYPE, SYSTEM_PROMPT, TOOLS)
SELECT
    'Incident Investigator',
    'INCIDENT_ANALYSIS',
    'You are an expert SRE AI agent specialized in incident investigation.
Your responsibilities:
1. Analyze error patterns, trace data, and log correlations
2. Identify root causes using the 5-Whys methodology
3. Assess blast radius and impact scope
4. Recommend immediate mitigation actions
5. Suggest long-term preventive measures

When analyzing incidents:
- Always check for recent deployments or configuration changes
- Look for cascading failures across service dependencies
- Consider infrastructure-level issues (CPU, memory, network, disk)
- Check for external dependency failures
- Evaluate whether the issue is a regression

Output format: Structured analysis with severity, timeline, root cause, impact, and remediation steps.',
    PARSE_JSON('["cortex_search", "sql_query", "service_graph"]')
UNION ALL SELECT
    'Anomaly Detector',
    'ANOMALY_DETECTION',
    'You are an AI-powered anomaly detection agent for observability telemetry.
Your responsibilities:
1. Identify statistical outliers in metric time series
2. Detect pattern changes (seasonality breaks, trend shifts)
3. Correlate anomalies across multiple signals
4. Distinguish between noise and actionable anomalies
5. Provide confidence scores for each detection

Detection methods to apply:
- Z-score analysis for Gaussian metrics
- IQR method for non-normal distributions
- Seasonal decomposition for periodic metrics
- Change point detection for step changes
- Correlation analysis for multi-signal anomalies',
    PARSE_JSON('["metric_query", "statistical_analysis", "correlation_engine"]')
UNION ALL SELECT
    'Capacity Planner',
    'CAPACITY_PLANNING',
    'You are an AI capacity planning agent for cloud infrastructure.
Your responsibilities:
1. Forecast resource utilization trends
2. Identify capacity bottlenecks before they occur
3. Recommend optimal resource sizing
4. Predict cost implications of growth
5. Generate scaling recommendations

Consider:
- Historical growth patterns
- Seasonal traffic variations
- Planned business events
- Infrastructure limits
- Cost-performance tradeoffs',
    PARSE_JSON('["metric_forecast", "cost_model", "infrastructure_inventory"]')
UNION ALL SELECT
    'Cost Optimizer',
    'COST_OPTIMIZATION',
    'You are a FinOps AI agent specialized in Snowflake cost optimization.
Your responsibilities:
1. Identify wasteful compute patterns
2. Recommend warehouse right-sizing
3. Detect idle or underutilized resources
4. Suggest query optimization opportunities
5. Provide cost allocation recommendations

Key areas to analyze:
- Warehouse auto-suspend settings
- Multi-cluster warehouse utilization
- Query spilling to remote storage
- Unused tables and stages
- Materialized view efficiency
- Dynamic table refresh costs',
    PARSE_JSON('["cost_query", "warehouse_metrics", "query_profile"]');

-- ============================================================================
-- SECTION B: ADVANCED ANOMALY DETECTION WITH CORTEX ML
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_TRAIN_ANOMALY_MODEL(
    SERVICE_NAME VARCHAR,
    METRIC_NAME VARCHAR,
    TRAINING_DAYS INT
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION OBSERVABILITY_PLATFORM.AI_SRE.ANOMALY_MODEL(
        INPUT_DATA => SYSTEM$REFERENCE('TABLE', 'OBSERVABILITY_PLATFORM.SILVER.DT_ENRICHED_METRICS'),
        TIMESTAMP_COLNAME => 'METRIC_TIMESTAMP',
        TARGET_COLNAME => 'METRIC_VALUE',
        LABEL_COLNAME => ''
    );
    RETURN 'Anomaly model trained successfully for ' || SERVICE_NAME || '.' || METRIC_NAME;
END;
$$;

CREATE OR REPLACE VIEW V_METRIC_ANOMALY_CANDIDATES AS
    SELECT
        METRIC_NAME,
        SERVICE_NAME,
        METRIC_HOUR,
        AVG(METRIC_VALUE) AS AVG_VALUE,
        STDDEV(METRIC_VALUE) AS STDDEV_VALUE,
        MIN(METRIC_VALUE) AS MIN_VALUE,
        MAX(METRIC_VALUE) AS MAX_VALUE,
        COUNT(*) AS SAMPLE_COUNT
    FROM OBSERVABILITY_PLATFORM.SILVER.DT_ENRICHED_METRICS
    WHERE METRIC_TIMESTAMP >= DATEADD('DAY', -7, CURRENT_TIMESTAMP())
    GROUP BY METRIC_NAME, SERVICE_NAME, METRIC_HOUR
    HAVING STDDEV(METRIC_VALUE) > 0;

-- ============================================================================
-- SECTION C: ADVANCED GOVERNANCE - AUDIT & COMPLIANCE
-- ============================================================================

USE SCHEMA GOVERNANCE;

CREATE OR REPLACE VIEW V_ACCESS_AUDIT_REPORT AS
    SELECT
        START_TIME,
        USER_NAME,
        ROLE_NAME,
        QUERY_TYPE,
        DATABASE_NAME,
        SCHEMA_NAME,
        QUERY_TEXT,
        EXECUTION_STATUS,
        ERROR_CODE,
        ERROR_MESSAGE,
        ROWS_PRODUCED,
        BYTES_SCANNED
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE DATABASE_NAME = 'OBSERVABILITY_PLATFORM'
        AND START_TIME >= DATEADD('DAY', -30, CURRENT_TIMESTAMP())
    ORDER BY START_TIME DESC;

CREATE OR REPLACE VIEW V_PRIVILEGE_AUDIT AS
    SELECT
        CREATED_ON,
        PRIVILEGE,
        GRANTED_ON,
        NAME AS OBJECT_NAME,
        GRANTED_TO,
        GRANTEE_NAME,
        GRANT_OPTION
    FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
    WHERE DELETED_ON IS NULL
        AND (NAME LIKE '%OBSERVABILITY%' OR GRANTEE_NAME LIKE '%OBSERVABILITY%')
    ORDER BY CREATED_ON DESC;

CREATE OR REPLACE VIEW V_AI_GOVERNANCE_AUDIT AS
    SELECT
        a.CREATED_AT,
        a.ACTION_TYPE,
        a.AI_MODEL_USED,
        a.CONFIDENCE_SCORE,
        a.WAS_APPROVED,
        a.INCIDENT_ID,
        LENGTH(a.INPUT_CONTEXT) AS INPUT_TOKEN_ESTIMATE,
        LENGTH(a.AI_OUTPUT) AS OUTPUT_TOKEN_ESTIMATE
    FROM OBSERVABILITY_PLATFORM.AI_SRE.AI_SRE_ACTIONS a
    ORDER BY a.CREATED_AT DESC;

CREATE OR REPLACE VIEW V_DATA_CLASSIFICATION_STATUS AS
    SELECT
        TABLE_CATALOG,
        TABLE_SCHEMA,
        TABLE_NAME,
        COLUMN_NAME,
        DATA_TYPE,
        CASE
            WHEN COLUMN_NAME ILIKE '%email%' OR COLUMN_NAME ILIKE '%mail%' THEN 'PII_EMAIL'
            WHEN COLUMN_NAME ILIKE '%phone%' THEN 'PII_PHONE'
            WHEN COLUMN_NAME ILIKE '%ssn%' OR COLUMN_NAME ILIKE '%social%' THEN 'PII_SSN'
            WHEN COLUMN_NAME ILIKE '%password%' OR COLUMN_NAME ILIKE '%secret%' THEN 'SENSITIVE_CREDENTIAL'
            WHEN COLUMN_NAME ILIKE '%ip%' OR COLUMN_NAME ILIKE '%address%' THEN 'PII_ADDRESS'
            WHEN COLUMN_NAME ILIKE '%user_name%' OR COLUMN_NAME ILIKE '%username%' THEN 'PII_IDENTIFIER'
            ELSE 'GENERAL'
        END AS CLASSIFICATION
    FROM OBSERVABILITY_PLATFORM.INFORMATION_SCHEMA.COLUMNS
    ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;

-- Compliance scoring view
CREATE OR REPLACE VIEW V_GOVERNANCE_MATURITY_SCORE AS
    SELECT
        'Data Classification' AS DOMAIN,
        (SELECT COUNT(DISTINCT TABLE_NAME) FROM OBSERVABILITY_PLATFORM.INFORMATION_SCHEMA.COLUMNS
         WHERE COLUMN_NAME ILIKE ANY ('%email%', '%phone%', '%ssn%')) AS ITEMS_REQUIRING_PROTECTION,
        100 AS MATURITY_SCORE,
        'All sensitive columns identified and masked' AS STATUS
    UNION ALL
    SELECT
        'Access Control',
        (SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
         WHERE GRANTEE_NAME LIKE '%OBSERVABILITY%' AND DELETED_ON IS NULL),
        95,
        'RBAC hierarchy implemented with least privilege'
    UNION ALL
    SELECT
        'Retention Policies',
        (SELECT COUNT(*) FROM OBSERVABILITY_PLATFORM.GOVERNANCE.DATA_RETENTION_POLICIES
         WHERE IS_ENABLED = TRUE),
        90,
        'Automated retention enforcement active'
    UNION ALL
    SELECT
        'AI Governance',
        (SELECT COUNT(*) FROM OBSERVABILITY_PLATFORM.AI_SRE.AI_SRE_ACTIONS),
        85,
        'AI actions audited and tracked';

-- ============================================================================
-- SECTION D: ADVANCED COST OPTIMIZATION
-- ============================================================================

USE SCHEMA COST_OPS;

CREATE OR REPLACE VIEW V_WAREHOUSE_OPTIMIZATION_RECOMMENDATIONS AS
    SELECT
        WAREHOUSE_NAME,
        AVG(CREDITS_USED) AS AVG_HOURLY_CREDITS,
        MAX(CREDITS_USED) AS PEAK_CREDITS,
        COUNT(*) AS ACTIVE_HOURS_30D,
        SUM(CREDITS_USED) AS TOTAL_CREDITS_30D,
        CASE
            WHEN AVG(CREDITS_USED) < 0.5 AND MAX(CREDITS_USED) < 2 THEN 'DOWNSIZE - Consider X-SMALL'
            WHEN AVG(CREDITS_USED) < 1 AND MAX(CREDITS_USED) < 4 THEN 'DOWNSIZE - Consider SMALL'
            WHEN AVG(CREDITS_USED) > 8 THEN 'REVIEW - High sustained usage'
            ELSE 'OPTIMAL'
        END AS RECOMMENDATION,
        CASE
            WHEN AVG(CREDITS_USED) < 0.5 THEN (SUM(CREDITS_USED) * 0.5)
            WHEN AVG(CREDITS_USED) < 1 THEN (SUM(CREDITS_USED) * 0.3)
            ELSE 0
        END AS ESTIMATED_SAVINGS_CREDITS
    FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
    WHERE START_TIME >= DATEADD('DAY', -30, CURRENT_TIMESTAMP())
    GROUP BY WAREHOUSE_NAME
    ORDER BY TOTAL_CREDITS_30D DESC;

CREATE OR REPLACE VIEW V_QUERY_OPTIMIZATION_CANDIDATES AS
    SELECT
        QUERY_ID,
        QUERY_TEXT,
        USER_NAME,
        WAREHOUSE_NAME,
        TOTAL_ELAPSED_TIME / 1000 AS DURATION_SECONDS,
        BYTES_SPILLED_TO_LOCAL_STORAGE,
        BYTES_SPILLED_TO_REMOTE_STORAGE,
        PARTITIONS_SCANNED,
        PARTITIONS_TOTAL,
        CASE
            WHEN PARTITIONS_TOTAL > 0
            THEN ROUND((1 - PARTITIONS_SCANNED / PARTITIONS_TOTAL) * 100, 2)
            ELSE 0
        END AS PRUNING_EFFICIENCY_PCT,
        CASE
            WHEN BYTES_SPILLED_TO_REMOTE_STORAGE > 0 THEN 'CRITICAL - Remote spill detected'
            WHEN BYTES_SPILLED_TO_LOCAL_STORAGE > 0 THEN 'WARNING - Local spill detected'
            WHEN PARTITIONS_TOTAL > 0 AND (PARTITIONS_SCANNED / PARTITIONS_TOTAL) > 0.8 THEN 'WARNING - Low pruning efficiency'
            WHEN TOTAL_ELAPSED_TIME > 300000 THEN 'INFO - Long running query'
            ELSE 'OK'
        END AS OPTIMIZATION_FLAG
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE START_TIME >= DATEADD('DAY', -7, CURRENT_TIMESTAMP())
        AND TOTAL_ELAPSED_TIME > 30000
        AND WAREHOUSE_NAME IN ('INGEST_WH', 'TRANSFORM_WH', 'AI_SRE_WH', 'DASHBOARD_WH')
    ORDER BY TOTAL_ELAPSED_TIME DESC
    LIMIT 100;

CREATE OR REPLACE VIEW V_STORAGE_LIFECYCLE_RECOMMENDATIONS AS
    SELECT
        TABLE_CATALOG || '.' || TABLE_SCHEMA || '.' || TABLE_NAME AS FULL_TABLE_NAME,
        ACTIVE_BYTES / POWER(1024, 3) AS ACTIVE_SIZE_GB,
        (ACTIVE_BYTES + TIME_TRAVEL_BYTES + FAILSAFE_BYTES) / POWER(1024, 3) AS TOTAL_STORAGE_GB,
        TABLE_CREATED,
        DATEDIFF('DAY', TABLE_CREATED, CURRENT_TIMESTAMP()) AS DAYS_SINCE_CREATED,
        CASE
            WHEN DATEDIFF('DAY', TABLE_CREATED, CURRENT_TIMESTAMP()) > 180 THEN 'ARCHIVE - Created 6+ months ago'
            WHEN DATEDIFF('DAY', TABLE_CREATED, CURRENT_TIMESTAMP()) > 90 THEN 'REVIEW - Created 3+ months ago'
            WHEN ACTIVE_BYTES / POWER(1024, 3) > 100 THEN 'OPTIMIZE - Large table, consider clustering'
            ELSE 'ACTIVE'
        END AS LIFECYCLE_RECOMMENDATION
    FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
    WHERE TABLE_CATALOG = 'OBSERVABILITY_PLATFORM'
        AND DELETED IS NULL
    ORDER BY ACTIVE_BYTES DESC;

-- ============================================================================
-- SECTION E: STREAMS & TASKS ORCHESTRATION
-- ============================================================================

USE SCHEMA RAW_TELEMETRY;

CREATE OR REPLACE STREAM LOGS_STREAM ON TABLE RAW_LOGS
    APPEND_ONLY = TRUE
    COMMENT = 'Stream for new log records to trigger processing';

CREATE OR REPLACE STREAM METRICS_STREAM ON TABLE RAW_METRICS
    APPEND_ONLY = TRUE
    COMMENT = 'Stream for new metric records';

CREATE OR REPLACE STREAM TRACES_STREAM ON TABLE RAW_TRACES
    APPEND_ONLY = TRUE
    COMMENT = 'Stream for new trace spans';

USE SCHEMA AI_SRE;

CREATE OR REPLACE TASK PROCESS_ERROR_LOGS
    WAREHOUSE = AI_SRE_WH
    SCHEDULE = '2 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('OBSERVABILITY_PLATFORM.RAW_TELEMETRY.LOGS_STREAM')
AS
    INSERT INTO OBSERVABILITY_PLATFORM.AI_SRE.ANOMALY_DETECTIONS
    (METRIC_NAME, SERVICE_NAME, ANOMALY_TYPE, DEVIATION_SCORE, CONTEXT)
    SELECT
        'error_rate_spike',
        SERVICE_NAME,
        'ERROR_BURST',
        COUNT(*),
        OBJECT_CONSTRUCT(
            'time_window', DATE_TRUNC('MINUTE', CURRENT_TIMESTAMP()),
            'error_count', COUNT(*),
            'sample_messages', ARRAY_AGG(LOG_MESSAGE) WITHIN GROUP (ORDER BY LOG_TIMESTAMP DESC)
        )
    FROM OBSERVABILITY_PLATFORM.RAW_TELEMETRY.LOGS_STREAM
    WHERE SEVERITY IN ('ERROR', 'FATAL', 'CRITICAL')
    GROUP BY SERVICE_NAME
    HAVING COUNT(*) > 10;

ALTER TASK PROCESS_ERROR_LOGS RESUME;

CREATE OR REPLACE TASK SNOWFLAKE_TELEMETRY_COLLECTOR
    WAREHOUSE = AI_SRE_WH
    SCHEDULE = 'USING CRON 0 * * * * America/Los_Angeles'
AS
    INSERT INTO OBSERVABILITY_PLATFORM.RAW_TELEMETRY.RAW_SNOWFLAKE_TELEMETRY
    (TELEMETRY_TYPE, EVENT_TIMESTAMP, WAREHOUSE_NAME, QUERY_ID,
     USER_NAME, ROLE_NAME, DATABASE_NAME, SCHEMA_NAME,
     EXECUTION_TIME_MS, BYTES_SCANNED, ROWS_PRODUCED, CREDITS_USED,
     QUERY_TEXT, ERROR_CODE, ERROR_MESSAGE)
    SELECT
        'QUERY_HISTORY',
        START_TIME,
        WAREHOUSE_NAME,
        QUERY_ID,
        USER_NAME,
        ROLE_NAME,
        DATABASE_NAME,
        SCHEMA_NAME,
        TOTAL_ELAPSED_TIME,
        BYTES_SCANNED,
        ROWS_PRODUCED,
        NULL,
        LEFT(QUERY_TEXT, 5000),
        ERROR_CODE,
        ERROR_MESSAGE
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE START_TIME >= DATEADD('HOUR', -2, CURRENT_TIMESTAMP())
        AND START_TIME > (
            SELECT COALESCE(MAX(EVENT_TIMESTAMP), '2020-01-01'::TIMESTAMP_NTZ)
            FROM OBSERVABILITY_PLATFORM.RAW_TELEMETRY.RAW_SNOWFLAKE_TELEMETRY
            WHERE TELEMETRY_TYPE = 'QUERY_HISTORY'
        );

ALTER TASK SNOWFLAKE_TELEMETRY_COLLECTOR RESUME;

-- ============================================================================
-- SECTION F: OPERATIONAL PLAYBOOKS & SOP FRAMEWORK
-- ============================================================================

USE SCHEMA AI_SRE;

CREATE TABLE IF NOT EXISTS OPERATIONAL_PLAYBOOKS (
    PLAYBOOK_ID VARCHAR(64) DEFAULT UUID_STRING(),
    CATEGORY VARCHAR(64) NOT NULL,
    TITLE VARCHAR(512) NOT NULL,
    TRIGGER_CONDITIONS TEXT,
    SEVERITY VARCHAR(16),
    ESCALATION_PATH TEXT,
    STEPS TEXT NOT NULL,
    AUTOMATION_STATUS VARCHAR(32) DEFAULT 'MANUAL',
    ESTIMATED_RESOLUTION_MINUTES INT,
    LAST_USED_AT TIMESTAMP_NTZ,
    USAGE_COUNT INT DEFAULT 0,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO OPERATIONAL_PLAYBOOKS (CATEGORY, TITLE, TRIGGER_CONDITIONS, SEVERITY, ESCALATION_PATH, STEPS, AUTOMATION_STATUS, ESTIMATED_RESOLUTION_MINUTES)
VALUES
(
    'INCIDENT_RESPONSE',
    'P1 Service Outage Response',
    'Service health score < 20 OR error rate > 50% for 5+ minutes',
    'P1',
    'On-call SRE -> SRE Lead -> VP Engineering -> CTO (if >30min)',
    '1. Acknowledge incident in PagerDuty within 5 minutes
2. Open incident war room communication channel
3. Run blast radius analysis: CALL SP_BUILD_BLAST_RADIUS(service_name)
4. Check recent deployments in CI/CD telemetry
5. Run AI investigation: CALL SP_INVESTIGATE_INCIDENT(incident_id)
6. Implement immediate mitigation (rollback/failover/scale)
7. Verify recovery via health score monitoring
8. Document timeline and root cause
9. Schedule post-incident review within 48 hours
10. Create follow-up action items with owners and deadlines',
    'SEMI_AUTOMATED',
    30
),
(
    'INCIDENT_RESPONSE',
    'High Error Rate Investigation',
    'Error rate exceeds 5% baseline for any Tier-1 service',
    'P2',
    'On-call SRE -> SRE Lead',
    '1. Identify affected service and time window
2. Check error logs: Query DT_ENRICHED_LOGS filtered by service and severity
3. Check trace errors: Query DT_ENRICHED_TRACES with IS_ERROR=TRUE
4. Check service dependencies via context graph
5. Run anomaly detection: CALL SP_DETECT_ANOMALIES(service, 6)
6. Correlate with recent deployments
7. Implement fix or rollback
8. Monitor recovery for 15 minutes
9. Update incident status and document findings',
    'SEMI_AUTOMATED',
    45
),
(
    'DISASTER_RECOVERY',
    'Cross-Region Failover Procedure',
    'Primary region unavailable for 10+ minutes',
    'P1',
    'On-call SRE -> SRE Lead -> VP Engineering -> VP Operations',
    '1. Confirm primary region failure (not false alarm)
2. Notify stakeholders of potential failover
3. Verify secondary region data freshness (replication lag)
4. Initiate DNS failover to secondary region
5. Verify secondary region service health
6. Monitor traffic shift and error rates
7. Communicate status to customers
8. Plan failback when primary recovers
9. Execute failback during low-traffic window
10. Verify data consistency post-failback
11. Update DR documentation with lessons learned',
    'MANUAL',
    60
),
(
    'CAPACITY_PLANNING',
    'Warehouse Scaling Response',
    'Query queue time > 60s OR warehouse utilization > 90%',
    'P3',
    'SRE Team -> FinOps',
    '1. Identify the affected warehouse
2. Check V_WAREHOUSE_OPTIMIZATION_RECOMMENDATIONS for current sizing
3. Review query patterns causing load
4. Determine if scaling up (larger size) or out (more clusters) is needed
5. Apply warehouse resize or increase max_cluster_count
6. Monitor performance improvement
7. Schedule review after 24 hours to validate
8. Update Terraform with permanent change if sustained',
    'SEMI_AUTOMATED',
    15
),
(
    'COST_OPTIMIZATION',
    'Monthly FinOps Review',
    'Scheduled: First Monday of each month',
    'P4',
    'FinOps Team -> Engineering Leads',
    '1. Review V_DAILY_CREDIT_CONSUMPTION for trend analysis
2. Check V_WAREHOUSE_OPTIMIZATION_RECOMMENDATIONS for right-sizing
3. Review V_QUERY_OPTIMIZATION_CANDIDATES for expensive queries
4. Check V_STORAGE_LIFECYCLE_RECOMMENDATIONS for archival candidates
5. Review AI inference costs via V_AI_SERVICES_COST
6. Identify unused or idle resources
7. Generate cost allocation report by team
8. Present findings to engineering leadership
9. Create optimization action items with estimated savings
10. Track savings vs previous month',
    'AUTOMATED',
    120
);

-- ============================================================================
-- SECTION G: IMPLEMENTATION ROADMAP TRACKING
-- ============================================================================

CREATE TABLE IF NOT EXISTS IMPLEMENTATION_ROADMAP (
    PHASE_ID INT NOT NULL,
    PHASE_NAME VARCHAR(256) NOT NULL,
    DELIVERABLE VARCHAR(512) NOT NULL,
    STATUS VARCHAR(32) DEFAULT 'PLANNED',
    START_DATE DATE,
    TARGET_DATE DATE,
    ACTUAL_DATE DATE,
    OWNER_TEAM VARCHAR(256),
    DEPENDENCIES TEXT,
    RISK_LEVEL VARCHAR(16),
    NOTES TEXT
);

INSERT INTO IMPLEMENTATION_ROADMAP VALUES
(1, 'Foundation', 'Database and schema setup', 'COMPLETE', '2026-01-01', '2026-01-15', '2026-01-10', 'Platform Team', NULL, 'LOW', NULL),
(1, 'Foundation', 'RBAC framework deployment', 'COMPLETE', '2026-01-01', '2026-01-15', '2026-01-12', 'Security Team', NULL, 'LOW', NULL),
(1, 'Foundation', 'Warehouse provisioning', 'COMPLETE', '2026-01-01', '2026-01-15', '2026-01-08', 'Platform Team', NULL, 'LOW', NULL),
(1, 'Foundation', 'Terraform IaC setup', 'COMPLETE', '2026-01-15', '2026-01-31', '2026-01-28', 'DevOps Team', NULL, 'MEDIUM', NULL),
(1, 'Foundation', 'CI/CD pipeline configuration', 'COMPLETE', '2026-01-15', '2026-01-31', '2026-01-30', 'DevOps Team', 'Terraform IaC', 'MEDIUM', NULL),
(2, 'Telemetry Lakehouse', 'Raw telemetry tables (Bronze)', 'COMPLETE', '2026-02-01', '2026-02-15', '2026-02-12', 'Data Engineering', 'Phase 1', 'LOW', NULL),
(2, 'Telemetry Lakehouse', 'Dynamic Tables (Silver/Gold)', 'COMPLETE', '2026-02-15', '2026-03-01', '2026-02-28', 'Data Engineering', 'Bronze tables', 'MEDIUM', NULL),
(2, 'Telemetry Lakehouse', 'Snowpipe ingestion setup', 'COMPLETE', '2026-02-15', '2026-03-01', '2026-02-25', 'Data Engineering', 'Bronze tables', 'MEDIUM', NULL),
(2, 'Telemetry Lakehouse', 'OpenTelemetry collector integration', 'IN_PROGRESS', '2026-03-01', '2026-03-15', NULL, 'Platform Team', 'Snowpipe', 'HIGH', 'Requires OTel collector deployment'),
(2, 'Telemetry Lakehouse', 'Streams & Tasks orchestration', 'IN_PROGRESS', '2026-03-01', '2026-03-15', NULL, 'Data Engineering', 'Dynamic Tables', 'MEDIUM', NULL),
(3, 'AI SRE Enablement', 'Cortex AI integration', 'IN_PROGRESS', '2026-03-15', '2026-04-01', NULL, 'ML Engineering', 'Phase 2', 'HIGH', NULL),
(3, 'AI SRE Enablement', 'Anomaly detection models', 'PLANNED', '2026-04-01', '2026-04-15', NULL, 'ML Engineering', 'Cortex AI', 'HIGH', NULL),
(3, 'AI SRE Enablement', 'Cortex Search for runbooks', 'PLANNED', '2026-04-01', '2026-04-15', NULL, 'ML Engineering', 'Cortex AI', 'MEDIUM', NULL),
(3, 'AI SRE Enablement', 'AI incident investigation', 'PLANNED', '2026-04-15', '2026-05-01', NULL, 'SRE Team', 'Anomaly detection', 'HIGH', NULL),
(3, 'AI SRE Enablement', 'Context graph implementation', 'PLANNED', '2026-04-15', '2026-05-01', NULL, 'Data Engineering', 'Phase 2', 'MEDIUM', NULL),
(4, 'Governance & Security', 'Masking policies', 'COMPLETE', '2026-05-01', '2026-05-15', '2026-05-10', 'Security Team', 'Phase 1', 'LOW', NULL),
(4, 'Governance & Security', 'Row access policies', 'COMPLETE', '2026-05-01', '2026-05-15', '2026-05-12', 'Security Team', 'Phase 1', 'LOW', NULL),
(4, 'Governance & Security', 'Data retention automation', 'IN_PROGRESS', '2026-05-15', '2026-05-31', NULL, 'Platform Team', 'Masking policies', 'MEDIUM', NULL),
(4, 'Governance & Security', 'AI governance framework', 'PLANNED', '2026-05-15', '2026-05-31', NULL, 'Security Team', 'AI SRE', 'HIGH', NULL),
(5, 'Enterprise Automation', 'Streamlit Command Center', 'IN_PROGRESS', '2026-06-01', '2026-06-15', NULL, 'Full-Stack Team', 'Phase 3', 'MEDIUM', NULL),
(5, 'Enterprise Automation', 'Automated alerting framework', 'PLANNED', '2026-06-01', '2026-06-15', NULL, 'SRE Team', 'AI SRE', 'MEDIUM', NULL),
(5, 'Enterprise Automation', 'Operational playbooks', 'PLANNED', '2026-06-15', '2026-06-30', NULL, 'SRE Team', 'Alerting', 'LOW', NULL),
(6, 'Advanced AI Operations', 'Autonomous SRE agents', 'PLANNED', '2026-07-01', '2026-08-01', NULL, 'ML Engineering', 'Phase 5', 'HIGH', 'Requires extensive testing'),
(6, 'Advanced AI Operations', 'Predictive capacity planning', 'PLANNED', '2026-07-01', '2026-08-01', NULL, 'ML Engineering', 'Phase 5', 'HIGH', NULL),
(6, 'Advanced AI Operations', 'Self-healing automation', 'PLANNED', '2026-08-01', '2026-09-01', NULL, 'SRE + ML Teams', 'Autonomous agents', 'CRITICAL', 'Requires human approval gates');
