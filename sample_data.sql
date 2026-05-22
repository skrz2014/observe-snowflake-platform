-- ==============================================================================
-- OBSERVE BY SNOWFLAKE - SAMPLE DATA FOR TESTING
-- Re-run this file to repopulate all tables with test data
-- ==============================================================================

USE DATABASE OBSERVABILITY_PLATFORM;
USE WAREHOUSE COMPUTE_WH;

-- ============================================================================
-- 1. RAW LOGS (500 records)
-- ============================================================================

USE SCHEMA RAW_TELEMETRY;

INSERT INTO RAW_LOGS 
    (SOURCE_SYSTEM, LOG_TIMESTAMP, SEVERITY, SERVICE_NAME, ENVIRONMENT, REGION, TRACE_ID, SPAN_ID, HOST, CONTAINER_ID, POD_NAME, NAMESPACE, LOG_MESSAGE)
SELECT 
    'otel-collector',
    DATEADD('MINUTE', -SEQ4() * 5, CURRENT_TIMESTAMP()),
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN 'FATAL'
        WHEN 1 THEN 'ERROR'
        WHEN 2 THEN 'ERROR'
        WHEN 3 THEN 'WARN'
        WHEN 4 THEN 'WARN'
        ELSE 'INFO'
    END,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'payment-service'
        WHEN 1 THEN 'user-service'
        WHEN 2 THEN 'order-service'
        WHEN 3 THEN 'inventory-service'
        WHEN 4 THEN 'notification-service'
    END,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'production' WHEN 1 THEN 'staging' ELSE 'development' END,
    CASE MOD(SEQ4(), 2) WHEN 0 THEN 'us-west-2' ELSE 'us-east-1' END,
    UUID_STRING(),
    UUID_STRING(),
    'host-' || MOD(SEQ4(), 20)::VARCHAR,
    'container-' || UUID_STRING(),
    'payment-svc-pod-' || MOD(SEQ4(), 5)::VARCHAR,
    'default',
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN 'FATAL: Database connection pool exhausted'
        WHEN 1 THEN 'ERROR: Payment processing failed - gateway timeout'
        WHEN 2 THEN 'ERROR: Authentication token expired'
        WHEN 3 THEN 'WARN: Response time exceeded SLO threshold'
        WHEN 4 THEN 'WARN: Memory usage at 85%'
        WHEN 5 THEN 'INFO: Order processed successfully'
        WHEN 6 THEN 'INFO: User login successful'
        WHEN 7 THEN 'INFO: Inventory sync completed'
        WHEN 8 THEN 'INFO: Notification dispatched'
        ELSE 'INFO: Health check passed'
    END
FROM TABLE(GENERATOR(ROWCOUNT => 500));

-- ============================================================================
-- 2. RAW METRICS (1000 records)
-- ============================================================================

INSERT INTO RAW_METRICS
    (SOURCE_SYSTEM, METRIC_TIMESTAMP, METRIC_NAME, METRIC_TYPE, METRIC_VALUE, METRIC_UNIT, SERVICE_NAME, ENVIRONMENT, REGION, HOST, DIMENSIONS, RESOURCE_ATTRIBUTES, EXEMPLARS)
SELECT
    'otel-collector',
    DATEADD('MINUTE', -SEQ4() * 2, CURRENT_TIMESTAMP()),
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'http.request.count'
        WHEN 1 THEN 'http.request.duration'
        WHEN 2 THEN 'http.request.error_count'
        WHEN 3 THEN 'system.cpu.utilization'
        WHEN 4 THEN 'system.memory.utilization'
        WHEN 5 THEN 'jvm.gc.duration'
        WHEN 6 THEN 'db.connection.pool.active'
        ELSE 'http.request.size'
    END,
    CASE WHEN MOD(SEQ4(), 8) = 0 THEN 'counter' ELSE 'gauge' END,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 50 + RANDOM() / 1e18 * 200
        WHEN 1 THEN 100 + RANDOM() / 1e18 * 900
        WHEN 2 THEN RANDOM() / 1e18 * 15
        WHEN 3 THEN 20 + RANDOM() / 1e18 * 60
        WHEN 4 THEN 40 + RANDOM() / 1e18 * 45
        WHEN 5 THEN 5 + RANDOM() / 1e18 * 50
        WHEN 6 THEN 5 + RANDOM() / 1e18 * 25
        ELSE 1024 + RANDOM() / 1e18 * 8192
    END,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'requests' WHEN 1 THEN 'ms' WHEN 2 THEN 'errors'
        WHEN 3 THEN 'percent' WHEN 4 THEN 'percent' WHEN 5 THEN 'ms'
        WHEN 6 THEN 'connections' ELSE 'bytes'
    END,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'payment-service'
        WHEN 1 THEN 'user-service'
        WHEN 2 THEN 'order-service'
        WHEN 3 THEN 'inventory-service'
        WHEN 4 THEN 'notification-service'
    END,
    'production',
    CASE MOD(SEQ4(), 2) WHEN 0 THEN 'us-west-2' ELSE 'us-east-1' END,
    'host-' || MOD(SEQ4(), 20)::VARCHAR,
    OBJECT_CONSTRUCT('http.method', 'GET', 'http.status_code', CASE WHEN MOD(SEQ4(), 10) < 2 THEN '500' ELSE '200' END),
    OBJECT_CONSTRUCT('service.version', '2.4.1', 'host.name', 'host-' || MOD(SEQ4(), 20)::VARCHAR),
    NULL
FROM TABLE(GENERATOR(ROWCOUNT => 1000));

-- ============================================================================
-- 3. RAW TRACES (600 records)
-- ============================================================================

INSERT INTO RAW_TRACES
    (SOURCE_SYSTEM, TRACE_ID, SPAN_ID, PARENT_SPAN_ID, SPAN_NAME, SPAN_KIND, SERVICE_NAME, ENVIRONMENT, REGION, START_TIME, END_TIME, DURATION_MS, STATUS_CODE, STATUS_MESSAGE, SPAN_ATTRIBUTES, RESOURCE_ATTRIBUTES, EVENTS, LINKS)
SELECT
    'otel-collector',
    'trace-' || LPAD(DIV0NULL(SEQ4(), 3)::INT::VARCHAR, 6, '0'),
    UUID_STRING(),
    CASE WHEN MOD(SEQ4(), 3) = 0 THEN NULL ELSE UUID_STRING() END,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'POST /api/v1/payments'
        WHEN 1 THEN 'GET /api/v1/users/{id}'
        WHEN 2 THEN 'POST /api/v1/orders'
        WHEN 3 THEN 'GET /api/v1/inventory'
        WHEN 4 THEN 'POST /api/v1/notifications'
        ELSE 'SELECT from database'
    END,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'SERVER' WHEN 1 THEN 'CLIENT' ELSE 'INTERNAL' END,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'payment-service'
        WHEN 1 THEN 'user-service'
        WHEN 2 THEN 'order-service'
        WHEN 3 THEN 'inventory-service'
        WHEN 4 THEN 'notification-service'
    END,
    'production',
    CASE MOD(SEQ4(), 2) WHEN 0 THEN 'us-west-2' ELSE 'us-east-1' END,
    DATEADD('MINUTE', -SEQ4() * 3, CURRENT_TIMESTAMP()),
    DATEADD('MILLISECOND', 50 + ABS(RANDOM() / 1e16), DATEADD('MINUTE', -SEQ4() * 3, CURRENT_TIMESTAMP())),
    CASE 
        WHEN MOD(SEQ4(), 20) = 0 THEN 5000 + ABS(RANDOM() / 1e16)
        WHEN MOD(SEQ4(), 10) = 0 THEN 2000 + ABS(RANDOM() / 1e16)
        WHEN MOD(SEQ4(), 5) = 0 THEN 800 + ABS(RANDOM() / 1e16)
        ELSE 50 + ABS(RANDOM() / 1e16) * 3
    END,
    CASE WHEN MOD(SEQ4(), 8) = 0 THEN 'ERROR' ELSE 'OK' END,
    CASE WHEN MOD(SEQ4(), 8) = 0 THEN 'Internal server error' ELSE NULL END,
    OBJECT_CONSTRUCT(
        'http.method', CASE MOD(SEQ4(), 3) WHEN 0 THEN 'POST' WHEN 1 THEN 'GET' ELSE 'PUT' END,
        'http.status_code', CASE WHEN MOD(SEQ4(), 8) = 0 THEN 500 ELSE 200 END,
        'peer.service', CASE MOD(SEQ4(), 4) WHEN 0 THEN 'user-service' WHEN 1 THEN 'payment-service' WHEN 2 THEN 'order-service' ELSE 'inventory-service' END
    ),
    OBJECT_CONSTRUCT('service.version', '2.4.1', 'deployment.environment', 'production'),
    CASE WHEN MOD(SEQ4(), 8) = 0 THEN ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('name', 'exception', 'message', 'NullPointerException')) ELSE ARRAY_CONSTRUCT() END,
    ARRAY_CONSTRUCT()
FROM TABLE(GENERATOR(ROWCOUNT => 600));

-- ============================================================================
-- 4. RAW K8S EVENTS (200 records)
-- ============================================================================

INSERT INTO RAW_K8S_EVENTS
    (EVENT_TIMESTAMP, CLUSTER_NAME, NAMESPACE, EVENT_TYPE, REASON, OBJECT_KIND, OBJECT_NAME, MESSAGE, SOURCE_COMPONENT, COUNT, FIRST_TIMESTAMP, LAST_TIMESTAMP, METADATA)
SELECT
    DATEADD('MINUTE', -SEQ4() * 10, CURRENT_TIMESTAMP()),
    CASE MOD(SEQ4(), 2) WHEN 0 THEN 'prod-cluster-west' ELSE 'prod-cluster-east' END,
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'production' WHEN 1 THEN 'monitoring' WHEN 2 THEN 'ingress' ELSE 'kube-system' END,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Warning' WHEN 1 THEN 'Normal' ELSE 'Normal' END,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'OOMKilled'
        WHEN 1 THEN 'Pulled'
        WHEN 2 THEN 'Started'
        WHEN 3 THEN 'BackOff'
        WHEN 4 THEN 'Scheduled'
        ELSE 'FailedMount'
    END,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Pod' WHEN 1 THEN 'Deployment' ELSE 'Node' END,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'payment-service-7f8d9-abc12'
        WHEN 1 THEN 'user-service-6e4c2-def34'
        WHEN 2 THEN 'order-service-5b3a1-ghi56'
        WHEN 3 THEN 'inventory-service-4a2b0-jkl78'
        ELSE 'notification-service-3c1d9-mno90'
    END,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'Container exceeded memory limit (2Gi). OOMKilled.'
        WHEN 1 THEN 'Successfully pulled image payment-service:2.4.1'
        WHEN 2 THEN 'Started container payment-service'
        WHEN 3 THEN 'Back-off restarting failed container'
        WHEN 4 THEN 'Successfully assigned pod to node-' || MOD(SEQ4(), 10)::VARCHAR
        ELSE 'Unable to attach volume pvc-data-' || MOD(SEQ4(), 5)::VARCHAR
    END,
    'kubelet',
    1 + MOD(SEQ4(), 5),
    DATEADD('MINUTE', -SEQ4() * 10 - 5, CURRENT_TIMESTAMP()),
    DATEADD('MINUTE', -SEQ4() * 10, CURRENT_TIMESTAMP()),
    OBJECT_CONSTRUCT('cluster_version', '1.28', 'node_pool', 'default-pool')
FROM TABLE(GENERATOR(ROWCOUNT => 200));

-- ============================================================================
-- 5. SERVICE REGISTRY (5 services)
-- ============================================================================

USE SCHEMA CONTEXT_GRAPH;

INSERT INTO SERVICE_REGISTRY
    (SERVICE_NAME, SERVICE_TYPE, TEAM_OWNER, TIER, ENVIRONMENT, REPOSITORY_URL, ON_CALL_CHANNEL, SLO_AVAILABILITY, SLO_LATENCY_P99_MS, METADATA)
SELECT 'payment-service', 'backend', 'Payments Team', 'T1', 'production', 'https://github.com/org/payment-service', '#payments-oncall', 0.9999, 1000, PARSE_JSON('{"language":"Java","framework":"Spring Boot"}')
UNION ALL SELECT 'user-service', 'backend', 'Identity Team', 'T1', 'production', 'https://github.com/org/user-service', '#identity-oncall', 0.9995, 500, PARSE_JSON('{"language":"Go","framework":"Gin"}')
UNION ALL SELECT 'order-service', 'backend', 'Commerce Team', 'T1', 'production', 'https://github.com/org/order-service', '#commerce-oncall', 0.999, 2000, PARSE_JSON('{"language":"Python","framework":"FastAPI"}')
UNION ALL SELECT 'inventory-service', 'backend', 'Supply Chain Team', 'T2', 'production', 'https://github.com/org/inventory-service', '#supply-oncall', 0.999, 3000, PARSE_JSON('{"language":"Java","framework":"Spring Boot"}')
UNION ALL SELECT 'notification-service', 'backend', 'Platform Team', 'T2', 'production', 'https://github.com/org/notification-service', '#platform-oncall', 0.995, 5000, PARSE_JSON('{"language":"Node.js","framework":"Express"}');

-- ============================================================================
-- 6. SERVICE DEPENDENCIES (8 relationships)
-- ============================================================================

INSERT INTO SERVICE_DEPENDENCIES
    (SOURCE_SERVICE, TARGET_SERVICE, DEPENDENCY_TYPE, PROTOCOL, IS_CRITICAL, AVG_CALL_RATE_PER_MIN, AVG_LATENCY_MS, ERROR_RATE)
SELECT 'order-service', 'payment-service', 'sync', 'gRPC', TRUE, 120, 85, 0.002
UNION ALL SELECT 'order-service', 'inventory-service', 'sync', 'REST', TRUE, 95, 120, 0.005
UNION ALL SELECT 'order-service', 'user-service', 'sync', 'gRPC', FALSE, 60, 45, 0.001
UNION ALL SELECT 'order-service', 'notification-service', 'async', 'Kafka', FALSE, 80, 15, 0.0005
UNION ALL SELECT 'payment-service', 'user-service', 'sync', 'gRPC', TRUE, 200, 35, 0.001
UNION ALL SELECT 'payment-service', 'notification-service', 'async', 'Kafka', FALSE, 150, 10, 0.0002
UNION ALL SELECT 'user-service', 'notification-service', 'async', 'Kafka', FALSE, 40, 12, 0.001
UNION ALL SELECT 'inventory-service', 'notification-service', 'async', 'Kafka', FALSE, 30, 8, 0.0003;

-- ============================================================================
-- 7. INCIDENTS (6 records)
-- ============================================================================

USE SCHEMA AI_SRE;

INSERT INTO INCIDENTS
    (CREATED_AT, SEVERITY, STATUS, TITLE, SERVICE_NAME, ENVIRONMENT, ROOT_CAUSE, TTDA_MINUTES, TTTA_MINUTES, TTTR_MINUTES, ASSIGNED_TEAM)
SELECT DATEADD('HOUR', -2, CURRENT_TIMESTAMP()), 'P1', 'RESOLVED', 'Payment service timeout - gateway unreachable', 'payment-service', 'production', 'Payment gateway provider experienced network partition', 3, 8, 45, 'Payments Team'
UNION ALL SELECT DATEADD('HOUR', -6, CURRENT_TIMESTAMP()), 'P2', 'RESOLVED', 'User authentication failures spike', 'user-service', 'production', 'Token cache invalidation after deployment', 5, 12, 30, 'Identity Team'
UNION ALL SELECT DATEADD('HOUR', -1, CURRENT_TIMESTAMP()), 'P2', 'OPEN', 'Order processing latency exceeds SLO', 'order-service', 'production', NULL, 4, NULL, NULL, 'Commerce Team'
UNION ALL SELECT DATEADD('DAY', -1, CURRENT_TIMESTAMP()), 'P3', 'RESOLVED', 'Inventory sync delay - stale stock data', 'inventory-service', 'production', 'Database connection pool exhausted under load', 15, 20, 60, 'Supply Chain Team'
UNION ALL SELECT DATEADD('DAY', -2, CURRENT_TIMESTAMP()), 'P1', 'RESOLVED', 'Complete order pipeline failure', 'order-service', 'production', 'Cascading failure from payment-service OOM', 2, 5, 90, 'Commerce Team'
UNION ALL SELECT DATEADD('DAY', -3, CURRENT_TIMESTAMP()), 'P3', 'RESOLVED', 'Notification delivery delays >5min', 'notification-service', 'production', 'Kafka consumer lag due to rebalancing', 10, 15, 25, 'Platform Team';

-- ============================================================================
-- 8. ALERT RULES (5 rules)
-- ============================================================================

USE SCHEMA ALERTING;

INSERT INTO ALERT_RULES
    (RULE_NAME, DESCRIPTION, SERVICE_NAME, METRIC_NAME, CONDITION_SQL, THRESHOLD_VALUE, COMPARISON_OPERATOR, EVALUATION_WINDOW_MINUTES, SEVERITY, IS_ENABLED, COOLDOWN_MINUTES)
SELECT 'Payment Service Health Critical', 'Health score below critical threshold', 'payment-service', 'health_score', 'health_score < 50', 50, '<', 5, 'CRITICAL', TRUE, 15
UNION ALL SELECT 'Order Service Latency Warning', 'P99 latency exceeds SLO', 'order-service', 'p99_latency', 'p99_latency > 2000', 2000, '>', 5, 'WARNING', TRUE, 30
UNION ALL SELECT 'User Service Error Rate', 'Error rate above 5%', 'user-service', 'error_rate', 'error_rate > 0.05', 0.05, '>', 5, 'WARNING', TRUE, 15
UNION ALL SELECT 'Inventory Service Health Warning', 'Health score below warning threshold', 'inventory-service', 'health_score', 'health_score < 80', 80, '<', 5, 'WARNING', TRUE, 30
UNION ALL SELECT 'Global Error Burst', 'Sudden spike in errors across all services', NULL, 'error_count', 'error_count > 100', 100, '>', 2, 'CRITICAL', TRUE, 10;

-- ============================================================================
-- 9. ALERT HISTORY (50 records)
-- ============================================================================

INSERT INTO ALERT_HISTORY
    (TRIGGERED_AT, RULE_ID, RULE_NAME, SEVERITY, SERVICE_NAME, METRIC_VALUE, THRESHOLD_VALUE, ALERT_MESSAGE, NOTIFICATION_SENT)
SELECT 
    DATEADD('MINUTE', -SEQ4() * 30, CURRENT_TIMESTAMP()),
    UUID_STRING(),
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'Payment Service Health Critical'
        WHEN 1 THEN 'Order Service Latency Warning'
        WHEN 2 THEN 'User Service Error Rate'
        ELSE 'Global Error Burst'
    END,
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'CRITICAL' WHEN 3 THEN 'CRITICAL' ELSE 'WARNING' END,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'payment-service'
        WHEN 1 THEN 'order-service'
        WHEN 2 THEN 'user-service'
        ELSE NULL
    END,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 35 + RANDOM() / 1e18 * 15
        WHEN 1 THEN 2500 + RANDOM() / 1e18 * 1500
        WHEN 2 THEN 0.06 + RANDOM() / 1e18 * 0.04
        ELSE 120 + RANDOM() / 1e18 * 80
    END,
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 50 WHEN 1 THEN 2000 WHEN 2 THEN 0.05 ELSE 100 END,
    'Alert triggered: threshold breached',
    TRUE
FROM TABLE(GENERATOR(ROWCOUNT => 50));

-- ============================================================================
-- 10. RUNBOOKS (4 records)
-- ============================================================================

INSERT INTO RUNBOOKS
    (TITLE, SERVICE_NAME, TRIGGER_CONDITION, STEPS, AUTOMATION_LEVEL, AVG_RESOLUTION_MINUTES)
SELECT 'Payment Gateway Timeout Recovery', 'payment-service', 'Payment gateway response time > 10s for 3+ minutes',
    '1. Check payment gateway status page
2. Verify network connectivity to gateway
3. Check circuit breaker state
4. If gateway down: activate fallback processor
5. If network issue: check VPN/peering
6. Monitor recovery and reset circuit breaker',
    'SEMI_AUTOMATED', 25
UNION ALL SELECT 'Database Connection Pool Exhaustion', NULL, 'Active connections > 90% of pool max',
    '1. Check current connection count vs max
2. Identify long-running queries holding connections
3. Kill idle connections older than 5 minutes
4. If persists: increase pool max temporarily
5. Check for connection leaks in recent deployments
6. Scale horizontally if sustained load',
    'SEMI_AUTOMATED', 15
UNION ALL SELECT 'OOMKill Pod Recovery', NULL, 'Kubernetes pod OOMKilled event',
    '1. Check pod memory requests vs limits
2. Review recent memory usage trend
3. Check for memory leaks (growing RSS)
4. If leak: trigger rolling restart
5. If undersized: increase memory limit
6. If burst: add HPA memory-based scaling',
    'AUTOMATED', 10
UNION ALL SELECT 'High Error Rate Triage', NULL, 'Error rate > 5% for any T1 service',
    '1. Identify error types from log patterns
2. Check if correlated with recent deployment
3. Check upstream dependencies health
4. If deployment related: initiate rollback
5. If dependency: check dependency service
6. Escalate if not resolved in 15 minutes',
    'MANUAL', 30;

-- ============================================================================
-- 11. ADDITIONAL LOGS (1000 more records)
-- ============================================================================

USE SCHEMA RAW_TELEMETRY;

INSERT INTO RAW_LOGS
    (SOURCE_SYSTEM, LOG_TIMESTAMP, SEVERITY, SERVICE_NAME, ENVIRONMENT, REGION, TRACE_ID, SPAN_ID, HOST, CONTAINER_ID, POD_NAME, NAMESPACE, LOG_MESSAGE)
SELECT
    'otel-collector',
    DATEADD('SECOND', -SEQ4() * 15, CURRENT_TIMESTAMP()),
    CASE MOD(SEQ4(), 12)
        WHEN 0 THEN 'FATAL'
        WHEN 1 THEN 'ERROR'
        WHEN 2 THEN 'ERROR'
        WHEN 3 THEN 'ERROR'
        WHEN 4 THEN 'WARN'
        WHEN 5 THEN 'WARN'
        ELSE 'INFO'
    END,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'payment-service'
        WHEN 1 THEN 'user-service'
        WHEN 2 THEN 'order-service'
        WHEN 3 THEN 'inventory-service'
        WHEN 4 THEN 'notification-service'
    END,
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'production' WHEN 1 THEN 'production' WHEN 2 THEN 'staging' ELSE 'development' END,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'us-west-2' WHEN 1 THEN 'us-east-1' ELSE 'eu-west-1' END,
    UUID_STRING(),
    UUID_STRING(),
    'host-' || MOD(SEQ4(), 30)::VARCHAR,
    'ctr-' || UUID_STRING(),
    CASE MOD(SEQ4(), 5) WHEN 0 THEN 'payment' WHEN 1 THEN 'user' WHEN 2 THEN 'order' WHEN 3 THEN 'inventory' ELSE 'notification' END || '-svc-' || MOD(SEQ4(), 4)::VARCHAR || '-pod-' || MOD(SEQ4(), 8)::VARCHAR,
    'default',
    CASE MOD(SEQ4(), 15)
        WHEN 0 THEN 'FATAL: Out of memory - heap space exhausted after GC'
        WHEN 1 THEN 'ERROR: Connection refused to downstream service payment-gateway:8443'
        WHEN 2 THEN 'ERROR: SQL query timeout after 30000ms on inventory_db'
        WHEN 3 THEN 'ERROR: Rate limit exceeded for API key ending in ...x4f2'
        WHEN 4 THEN 'WARN: Circuit breaker OPEN for payment-gateway (failures=15/20)'
        WHEN 5 THEN 'WARN: Thread pool saturation at 95% - queuing requests'
        WHEN 6 THEN 'INFO: Deployment v2.5.3 rolling update started (0/5 pods ready)'
        WHEN 7 THEN 'INFO: Successfully processed batch of 1250 orders in 3.2s'
        WHEN 8 THEN 'INFO: Cache hit ratio 94.2% for session store (Redis cluster-0)'
        WHEN 9 THEN 'INFO: Kafka consumer group rebalance completed in 450ms'
        WHEN 10 THEN 'INFO: Health check passed - all 4 dependencies responsive'
        WHEN 11 THEN 'WARN: Disk usage 78% on /data volume - approaching threshold'
        WHEN 12 THEN 'ERROR: TLS handshake failed with upstream proxy - cert expired'
        WHEN 13 THEN 'INFO: Auto-scaled from 3 to 5 replicas based on CPU metric'
        ELSE 'INFO: Request completed in ' || (50 + MOD(SEQ4(), 950))::VARCHAR || 'ms'
    END
FROM TABLE(GENERATOR(ROWCOUNT => 1000));

-- ============================================================================
-- 12. ADDITIONAL METRICS (2000 more records)
-- ============================================================================

INSERT INTO RAW_METRICS
    (SOURCE_SYSTEM, METRIC_TIMESTAMP, METRIC_NAME, METRIC_TYPE, METRIC_VALUE, METRIC_UNIT, SERVICE_NAME, ENVIRONMENT, REGION, HOST, DIMENSIONS, RESOURCE_ATTRIBUTES, EXEMPLARS)
SELECT
    'otel-collector',
    DATEADD('SECOND', -SEQ4() * 30, CURRENT_TIMESTAMP()),
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'http.request.count'
        WHEN 1 THEN 'http.request.duration'
        WHEN 2 THEN 'http.request.error_count'
        WHEN 3 THEN 'system.cpu.utilization'
        WHEN 4 THEN 'system.memory.utilization'
        WHEN 5 THEN 'jvm.gc.duration'
        WHEN 6 THEN 'db.connection.pool.active'
        ELSE 'http.request.size'
    END,
    CASE WHEN MOD(SEQ4(), 8) = 0 THEN 'counter' ELSE 'gauge' END,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 80 + RANDOM() / 1e18 * 300
        WHEN 1 THEN 50 + RANDOM() / 1e18 * 1200
        WHEN 2 THEN RANDOM() / 1e18 * 20
        WHEN 3 THEN 15 + RANDOM() / 1e18 * 70
        WHEN 4 THEN 35 + RANDOM() / 1e18 * 50
        WHEN 5 THEN 3 + RANDOM() / 1e18 * 60
        WHEN 6 THEN 8 + RANDOM() / 1e18 * 30
        ELSE 512 + RANDOM() / 1e18 * 10240
    END,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'requests' WHEN 1 THEN 'ms' WHEN 2 THEN 'errors'
        WHEN 3 THEN 'percent' WHEN 4 THEN 'percent' WHEN 5 THEN 'ms'
        WHEN 6 THEN 'connections' ELSE 'bytes'
    END,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'payment-service'
        WHEN 1 THEN 'user-service'
        WHEN 2 THEN 'order-service'
        WHEN 3 THEN 'inventory-service'
        WHEN 4 THEN 'notification-service'
    END,
    'production',
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'us-west-2' WHEN 1 THEN 'us-east-1' ELSE 'eu-west-1' END,
    'host-' || MOD(SEQ4(), 30)::VARCHAR,
    OBJECT_CONSTRUCT('http.method', CASE MOD(SEQ4(), 4) WHEN 0 THEN 'GET' WHEN 1 THEN 'POST' WHEN 2 THEN 'PUT' ELSE 'DELETE' END, 'http.status_code', CASE WHEN MOD(SEQ4(), 12) < 2 THEN '500' WHEN MOD(SEQ4(), 12) < 3 THEN '429' ELSE '200' END),
    OBJECT_CONSTRUCT('service.version', '2.5.' || MOD(SEQ4(), 5)::VARCHAR, 'host.name', 'host-' || MOD(SEQ4(), 30)::VARCHAR),
    NULL
FROM TABLE(GENERATOR(ROWCOUNT => 2000));

-- ============================================================================
-- 13. ADDITIONAL TRACES (1000 more records)
-- ============================================================================

INSERT INTO RAW_TRACES
    (SOURCE_SYSTEM, TRACE_ID, SPAN_ID, PARENT_SPAN_ID, SPAN_NAME, SPAN_KIND, SERVICE_NAME, ENVIRONMENT, REGION, START_TIME, END_TIME, DURATION_MS, STATUS_CODE, STATUS_MESSAGE, SPAN_ATTRIBUTES, RESOURCE_ATTRIBUTES, EVENTS, LINKS)
SELECT
    'otel-collector',
    'trace-' || LPAD(DIV0NULL(SEQ4(), 4)::INT::VARCHAR, 8, '0'),
    UUID_STRING(),
    CASE WHEN MOD(SEQ4(), 4) = 0 THEN NULL ELSE UUID_STRING() END,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'POST /api/v2/payments/charge'
        WHEN 1 THEN 'GET /api/v2/users/{id}/profile'
        WHEN 2 THEN 'POST /api/v2/orders/create'
        WHEN 3 THEN 'GET /api/v2/inventory/check'
        WHEN 4 THEN 'POST /api/v2/notifications/send'
        WHEN 5 THEN 'SELECT orders WHERE status=pending'
        WHEN 6 THEN 'PUBLISH event.order.created'
        ELSE 'GET /health'
    END,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'SERVER' WHEN 1 THEN 'CLIENT' ELSE 'INTERNAL' END,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'payment-service'
        WHEN 1 THEN 'user-service'
        WHEN 2 THEN 'order-service'
        WHEN 3 THEN 'inventory-service'
        WHEN 4 THEN 'notification-service'
    END,
    'production',
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'us-west-2' WHEN 1 THEN 'us-east-1' ELSE 'eu-west-1' END,
    DATEADD('SECOND', -SEQ4() * 20, CURRENT_TIMESTAMP()),
    DATEADD('MILLISECOND', 20 + ABS(RANDOM() / 1e16), DATEADD('SECOND', -SEQ4() * 20, CURRENT_TIMESTAMP())),
    CASE 
        WHEN MOD(SEQ4(), 25) = 0 THEN 7000 + ABS(RANDOM() / 1e16)
        WHEN MOD(SEQ4(), 12) = 0 THEN 2500 + ABS(RANDOM() / 1e16)
        WHEN MOD(SEQ4(), 6) = 0 THEN 800 + ABS(RANDOM() / 1e16)
        ELSE 30 + ABS(RANDOM() / 1e16) * 4
    END,
    CASE WHEN MOD(SEQ4(), 10) = 0 THEN 'ERROR' ELSE 'OK' END,
    CASE WHEN MOD(SEQ4(), 10) = 0 THEN 'Service unavailable' ELSE NULL END,
    OBJECT_CONSTRUCT(
        'http.method', CASE MOD(SEQ4(), 3) WHEN 0 THEN 'POST' WHEN 1 THEN 'GET' ELSE 'PUT' END,
        'http.status_code', CASE WHEN MOD(SEQ4(), 10) = 0 THEN 503 ELSE 200 END,
        'peer.service', CASE MOD(SEQ4(), 5) WHEN 0 THEN 'user-service' WHEN 1 THEN 'payment-service' WHEN 2 THEN 'order-service' WHEN 3 THEN 'inventory-service' ELSE 'notification-service' END
    ),
    OBJECT_CONSTRUCT('service.version', '2.5.2', 'deployment.environment', 'production'),
    CASE WHEN MOD(SEQ4(), 10) = 0 THEN ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('name', 'exception', 'message', 'TimeoutException')) ELSE ARRAY_CONSTRUCT() END,
    ARRAY_CONSTRUCT()
FROM TABLE(GENERATOR(ROWCOUNT => 1000));

-- ============================================================================
-- 14. ADDITIONAL K8S EVENTS (300 more records)
-- ============================================================================

INSERT INTO RAW_K8S_EVENTS
    (EVENT_TIMESTAMP, CLUSTER_NAME, NAMESPACE, EVENT_TYPE, REASON, OBJECT_KIND, OBJECT_NAME, MESSAGE, SOURCE_COMPONENT, COUNT, FIRST_TIMESTAMP, LAST_TIMESTAMP, METADATA)
SELECT
    DATEADD('MINUTE', -SEQ4() * 5, CURRENT_TIMESTAMP()),
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'prod-cluster-west' WHEN 1 THEN 'prod-cluster-east' ELSE 'prod-cluster-eu' END,
    CASE MOD(SEQ4(), 5) WHEN 0 THEN 'production' WHEN 1 THEN 'monitoring' WHEN 2 THEN 'ingress' WHEN 3 THEN 'kube-system' ELSE 'data-platform' END,
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'Warning' ELSE 'Normal' END,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'OOMKilled'
        WHEN 1 THEN 'Pulled'
        WHEN 2 THEN 'Started'
        WHEN 3 THEN 'ScalingReplicaSet'
        WHEN 4 THEN 'Scheduled'
        WHEN 5 THEN 'FailedMount'
        WHEN 6 THEN 'Unhealthy'
        ELSE 'SuccessfulCreate'
    END,
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'Pod' WHEN 1 THEN 'Deployment' WHEN 2 THEN 'ReplicaSet' ELSE 'Node' END,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'payment-service-' || MOD(SEQ4(), 99)::VARCHAR
        WHEN 1 THEN 'user-service-' || MOD(SEQ4(), 99)::VARCHAR
        WHEN 2 THEN 'order-service-' || MOD(SEQ4(), 99)::VARCHAR
        WHEN 3 THEN 'inventory-service-' || MOD(SEQ4(), 99)::VARCHAR
        ELSE 'notification-service-' || MOD(SEQ4(), 99)::VARCHAR
    END,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'Container exceeded memory limit. OOMKilled.'
        WHEN 1 THEN 'Successfully pulled image v2.5.' || MOD(SEQ4(), 5)::VARCHAR
        WHEN 2 THEN 'Started container successfully'
        WHEN 3 THEN 'Scaled up replica set to ' || (3 + MOD(SEQ4(), 5))::VARCHAR || ' replicas'
        WHEN 4 THEN 'Successfully assigned to node-' || MOD(SEQ4(), 15)::VARCHAR
        WHEN 5 THEN 'Unable to attach or mount volumes: timed out'
        WHEN 6 THEN 'Liveness probe failed: HTTP probe failed with statuscode 503'
        ELSE 'Created pod: svc-' || MOD(SEQ4(), 50)::VARCHAR
    END,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'kubelet' WHEN 1 THEN 'deployment-controller' ELSE 'scheduler' END,
    1 + MOD(SEQ4(), 8),
    DATEADD('MINUTE', -SEQ4() * 5 - 3, CURRENT_TIMESTAMP()),
    DATEADD('MINUTE', -SEQ4() * 5, CURRENT_TIMESTAMP()),
    OBJECT_CONSTRUCT('cluster_version', '1.29', 'node_pool', CASE MOD(SEQ4(), 2) WHEN 0 THEN 'default-pool' ELSE 'high-mem-pool' END)
FROM TABLE(GENERATOR(ROWCOUNT => 300));

-- ============================================================================
-- 15. ADDITIONAL INCIDENTS (6 more records)
-- ============================================================================

INSERT INTO INCIDENTS
    (CREATED_AT, SEVERITY, STATUS, TITLE, SERVICE_NAME, ENVIRONMENT, ROOT_CAUSE, TTDA_MINUTES, TTTA_MINUTES, TTTR_MINUTES, ASSIGNED_TEAM)
SELECT DATEADD('HOUR', -4, CURRENT_TIMESTAMP()), 'P2', 'RESOLVED', 'Memory leak detected in user-service v2.5.1', 'user-service', 'production', 'Unbounded cache growth in session handler', 8, 15, 55, 'Identity Team'
UNION ALL SELECT DATEADD('HOUR', -8, CURRENT_TIMESTAMP()), 'P3', 'RESOLVED', 'Notification delivery latency spike', 'notification-service', 'production', 'Kafka partition rebalance during deployment', 12, 18, 35, 'Platform Team'
UNION ALL SELECT DATEADD('HOUR', -12, CURRENT_TIMESTAMP()), 'P1', 'RESOLVED', 'Database failover triggered - primary unreachable', 'order-service', 'production', 'Network partition between AZ-a and AZ-b', 1, 3, 20, 'Commerce Team'
UNION ALL SELECT DATEADD('MINUTE', -30, CURRENT_TIMESTAMP()), 'P2', 'OPEN', 'Elevated 429 responses from payment gateway', 'payment-service', 'production', NULL, 5, NULL, NULL, 'Payments Team'
UNION ALL SELECT DATEADD('DAY', -4, CURRENT_TIMESTAMP()), 'P3', 'RESOLVED', 'Inventory cache stale after Redis failover', 'inventory-service', 'production', 'Redis sentinel failover cleared all caches', 20, 25, 40, 'Supply Chain Team'
UNION ALL SELECT DATEADD('DAY', -5, CURRENT_TIMESTAMP()), 'P2', 'RESOLVED', 'SSL certificate expiry caused auth failures', 'user-service', 'production', 'Internal CA cert not renewed before expiry', 3, 10, 65, 'Identity Team';
