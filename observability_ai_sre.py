# ==============================================================================
# OBSERVE BY SNOWFLAKE - SNOWPARK PYTHON AI SRE FRAMEWORK
# Enterprise-Grade Observability Platform
# ==============================================================================

import json
from datetime import datetime, timedelta
from typing import Optional

from snowflake.snowpark import Session
from snowflake.snowpark.functions import (
    col, lit, when, avg, sum as sum_, count, max as max_,
    min as min_, datediff, current_timestamp, dateadd,
    parse_json, to_timestamp, udf, sproc, call_function
)
from snowflake.snowpark.types import (
    StructType, StructField, StringType, TimestampType,
    DoubleType, VariantType, IntegerType, BooleanType
)


# ==============================================================================
# 1. TELEMETRY INGESTION FRAMEWORK
# ==============================================================================

class TelemetryIngestor:
    def __init__(self, session: Session):
        self.session = session
        self.db = "OBSERVABILITY_PLATFORM"

    def ingest_otel_logs(self, log_batch: list[dict]) -> dict:
        schema = StructType([
            StructField("SOURCE_SYSTEM", StringType()),
            StructField("LOG_TIMESTAMP", TimestampType()),
            StructField("SEVERITY", StringType()),
            StructField("SERVICE_NAME", StringType()),
            StructField("ENVIRONMENT", StringType()),
            StructField("REGION", StringType()),
            StructField("TRACE_ID", StringType()),
            StructField("SPAN_ID", StringType()),
            StructField("HOST", StringType()),
            StructField("CONTAINER_ID", StringType()),
            StructField("POD_NAME", StringType()),
            StructField("NAMESPACE", StringType()),
            StructField("LOG_MESSAGE", StringType()),
            StructField("STRUCTURED_DATA", VariantType()),
            StructField("RESOURCE_ATTRIBUTES", VariantType()),
            StructField("LOG_ATTRIBUTES", VariantType()),
        ])

        rows = []
        for log in log_batch:
            rows.append((
                log.get("source_system", "unknown"),
                log.get("timestamp"),
                log.get("severity", "INFO"),
                log.get("service_name"),
                log.get("environment", "production"),
                log.get("region"),
                log.get("trace_id"),
                log.get("span_id"),
                log.get("host"),
                log.get("container_id"),
                log.get("pod_name"),
                log.get("namespace"),
                log.get("message"),
                json.dumps(log.get("structured_data", {})),
                json.dumps(log.get("resource_attributes", {})),
                json.dumps(log.get("log_attributes", {})),
            ))

        df = self.session.create_dataframe(rows, schema=schema)
        df.write.mode("append").save_as_table(
            f"{self.db}.RAW_TELEMETRY.RAW_LOGS"
        )

        return {"status": "success", "records_ingested": len(rows)}

    def ingest_otel_metrics(self, metric_batch: list[dict]) -> dict:
        schema = StructType([
            StructField("SOURCE_SYSTEM", StringType()),
            StructField("METRIC_TIMESTAMP", TimestampType()),
            StructField("METRIC_NAME", StringType()),
            StructField("METRIC_TYPE", StringType()),
            StructField("METRIC_VALUE", DoubleType()),
            StructField("METRIC_UNIT", StringType()),
            StructField("SERVICE_NAME", StringType()),
            StructField("ENVIRONMENT", StringType()),
            StructField("REGION", StringType()),
            StructField("HOST", StringType()),
            StructField("DIMENSIONS", VariantType()),
            StructField("RESOURCE_ATTRIBUTES", VariantType()),
            StructField("EXEMPLARS", VariantType()),
        ])

        rows = []
        for metric in metric_batch:
            rows.append((
                metric.get("source_system", "otel-collector"),
                metric.get("timestamp"),
                metric.get("name"),
                metric.get("type", "gauge"),
                metric.get("value"),
                metric.get("unit"),
                metric.get("service_name"),
                metric.get("environment", "production"),
                metric.get("region"),
                metric.get("host"),
                json.dumps(metric.get("dimensions", {})),
                json.dumps(metric.get("resource_attributes", {})),
                json.dumps(metric.get("exemplars", {})),
            ))

        df = self.session.create_dataframe(rows, schema=schema)
        df.write.mode("append").save_as_table(
            f"{self.db}.RAW_TELEMETRY.RAW_METRICS"
        )

        return {"status": "success", "records_ingested": len(rows)}

    def ingest_otel_traces(self, span_batch: list[dict]) -> dict:
        schema = StructType([
            StructField("SOURCE_SYSTEM", StringType()),
            StructField("TRACE_ID", StringType()),
            StructField("SPAN_ID", StringType()),
            StructField("PARENT_SPAN_ID", StringType()),
            StructField("SPAN_NAME", StringType()),
            StructField("SPAN_KIND", StringType()),
            StructField("SERVICE_NAME", StringType()),
            StructField("ENVIRONMENT", StringType()),
            StructField("REGION", StringType()),
            StructField("START_TIME", TimestampType()),
            StructField("END_TIME", TimestampType()),
            StructField("DURATION_MS", DoubleType()),
            StructField("STATUS_CODE", StringType()),
            StructField("STATUS_MESSAGE", StringType()),
            StructField("SPAN_ATTRIBUTES", VariantType()),
            StructField("RESOURCE_ATTRIBUTES", VariantType()),
            StructField("EVENTS", VariantType()),
            StructField("LINKS", VariantType()),
        ])

        rows = []
        for span in span_batch:
            rows.append((
                span.get("source_system", "otel-collector"),
                span.get("trace_id"),
                span.get("span_id"),
                span.get("parent_span_id"),
                span.get("span_name"),
                span.get("span_kind", "INTERNAL"),
                span.get("service_name"),
                span.get("environment", "production"),
                span.get("region"),
                span.get("start_time"),
                span.get("end_time"),
                span.get("duration_ms"),
                span.get("status_code", "OK"),
                span.get("status_message"),
                json.dumps(span.get("span_attributes", {})),
                json.dumps(span.get("resource_attributes", {})),
                json.dumps(span.get("events", [])),
                json.dumps(span.get("links", [])),
            ))

        df = self.session.create_dataframe(rows, schema=schema)
        df.write.mode("append").save_as_table(
            f"{self.db}.RAW_TELEMETRY.RAW_TRACES"
        )

        return {"status": "success", "records_ingested": len(rows)}


# ==============================================================================
# 2. AI SRE ENGINE - CORTEX AI POWERED
# ==============================================================================

class AISREEngine:
    def __init__(self, session: Session):
        self.session = session
        self.db = "OBSERVABILITY_PLATFORM"
        self.model = "mistral-large2"

    def investigate_incident(self, incident_id: str) -> dict:
        incident = self.session.table(f"{self.db}.AI_SRE.INCIDENTS").filter(
            col("INCIDENT_ID") == incident_id
        ).collect()

        if not incident:
            return {"error": "Incident not found"}

        incident_data = incident[0]

        recent_errors = self.session.sql(f"""
            SELECT SERVICE_NAME, SEVERITY, LOG_MESSAGE, LOG_TIMESTAMP, TRACE_ID
            FROM {self.db}.SILVER.DT_ENRICHED_LOGS
            WHERE SERVICE_NAME = '{incident_data["SERVICE_NAME"]}'
                AND SEVERITY IN ('ERROR', 'FATAL', 'CRITICAL')
                AND LOG_TIMESTAMP >= DATEADD('HOUR', -1, CURRENT_TIMESTAMP())
            ORDER BY LOG_TIMESTAMP DESC
            LIMIT 50
        """).collect()

        related_traces = self.session.sql(f"""
            SELECT TRACE_ID, SPAN_NAME, DURATION_MS, STATUS_CODE, STATUS_MESSAGE
            FROM {self.db}.SILVER.DT_ENRICHED_TRACES
            WHERE SERVICE_NAME = '{incident_data["SERVICE_NAME"]}'
                AND IS_ERROR = TRUE
                AND START_TIME >= DATEADD('HOUR', -1, CURRENT_TIMESTAMP())
            ORDER BY START_TIME DESC
            LIMIT 20
        """).collect()

        context = f"""
        INCIDENT: {incident_data["TITLE"]}
        SERVICE: {incident_data["SERVICE_NAME"]}
        ENVIRONMENT: {incident_data["ENVIRONMENT"]}
        SEVERITY: {incident_data["SEVERITY"]}

        RECENT ERRORS ({len(recent_errors)} found):
        {json.dumps([dict(r) for r in recent_errors[:10]], default=str, indent=2)}

        RELATED ERROR TRACES ({len(related_traces)} found):
        {json.dumps([dict(r) for r in related_traces[:10]], default=str, indent=2)}
        """

        prompt = f"""You are an expert SRE AI agent. Analyze this incident and provide:
1. Root cause analysis
2. Impact assessment
3. Recommended remediation steps
4. Preventive measures

{context}

Respond in structured JSON with keys: root_cause, impact, remediation_steps, prevention."""

        result = self.session.sql(f"""
            SELECT SNOWFLAKE.CORTEX.COMPLETE(
                '{self.model}',
                '{prompt.replace("'", "''")}'
            ) AS AI_ANALYSIS
        """).collect()

        ai_analysis = result[0]["AI_ANALYSIS"]

        self.session.sql(f"""
            UPDATE {self.db}.AI_SRE.INCIDENTS
            SET AI_SUMMARY = '{ai_analysis[:2000].replace("'", "''")}',
                AI_ROOT_CAUSE = '{ai_analysis[:1000].replace("'", "''")}',
                AI_RECOMMENDATIONS = '{ai_analysis[:1000].replace("'", "''")}'
            WHERE INCIDENT_ID = '{incident_id}'
        """).collect()

        self.session.sql(f"""
            INSERT INTO {self.db}.AI_SRE.AI_SRE_ACTIONS
            (INCIDENT_ID, ACTION_TYPE, ACTION_DESCRIPTION, AI_MODEL_USED, INPUT_CONTEXT, AI_OUTPUT, CONFIDENCE_SCORE)
            VALUES (
                '{incident_id}',
                'INCIDENT_INVESTIGATION',
                'AI-powered root cause analysis',
                '{self.model}',
                '{context[:500].replace("'", "''")}',
                '{ai_analysis[:2000].replace("'", "''")}',
                0.85
            )
        """).collect()

        return {"incident_id": incident_id, "ai_analysis": ai_analysis}

    def detect_anomalies(self, service_name: str, lookback_hours: int = 24) -> list[dict]:
        metrics = self.session.sql(f"""
            SELECT
                METRIC_NAME,
                METRIC_HOUR,
                AVG(METRIC_VALUE) AS AVG_VALUE,
                STDDEV(METRIC_VALUE) AS STDDEV_VALUE
            FROM {self.db}.SILVER.DT_ENRICHED_METRICS
            WHERE SERVICE_NAME = '{service_name}'
                AND METRIC_TIMESTAMP >= DATEADD('HOUR', -{lookback_hours}, CURRENT_TIMESTAMP())
            GROUP BY METRIC_NAME, METRIC_HOUR
            ORDER BY METRIC_HOUR DESC
        """).collect()

        anomalies = []
        metric_baselines = {}

        for row in metrics:
            key = row["METRIC_NAME"]
            if key not in metric_baselines:
                metric_baselines[key] = {"values": [], "stddevs": []}
            metric_baselines[key]["values"].append(row["AVG_VALUE"])
            metric_baselines[key]["stddevs"].append(row["STDDEV_VALUE"])

        for metric_name, data in metric_baselines.items():
            if len(data["values"]) < 3:
                continue

            latest = data["values"][0]
            historical_avg = sum(data["values"][1:]) / len(data["values"][1:])
            historical_stddev = (
                sum(data["stddevs"][1:]) / len(data["stddevs"][1:])
                if any(data["stddevs"][1:])
                else 0
            )

            if historical_stddev > 0:
                z_score = abs(latest - historical_avg) / historical_stddev
                if z_score > 3:
                    anomalies.append({
                        "metric_name": metric_name,
                        "service_name": service_name,
                        "expected_value": historical_avg,
                        "actual_value": latest,
                        "deviation_score": z_score,
                        "anomaly_type": "STATISTICAL_OUTLIER",
                    })

        if anomalies:
            for anomaly in anomalies:
                self.session.sql(f"""
                    INSERT INTO {self.db}.AI_SRE.ANOMALY_DETECTIONS
                    (METRIC_NAME, SERVICE_NAME, EXPECTED_VALUE, ACTUAL_VALUE,
                     DEVIATION_SCORE, ANOMALY_TYPE)
                    VALUES (
                        '{anomaly["metric_name"]}',
                        '{anomaly["service_name"]}',
                        {anomaly["expected_value"]},
                        {anomaly["actual_value"]},
                        {anomaly["deviation_score"]},
                        '{anomaly["anomaly_type"]}'
                    )
                """).collect()

        return anomalies

    def generate_alert_summary(self, hours: int = 1) -> str:
        alerts = self.session.sql(f"""
            SELECT RULE_NAME, SEVERITY, SERVICE_NAME, ALERT_MESSAGE, TRIGGERED_AT
            FROM {self.db}.ALERTING.ALERT_HISTORY
            WHERE TRIGGERED_AT >= DATEADD('HOUR', -{hours}, CURRENT_TIMESTAMP())
            ORDER BY TRIGGERED_AT DESC
            LIMIT 50
        """).collect()

        if not alerts:
            return "No alerts in the specified time window."

        alert_context = json.dumps([dict(a) for a in alerts], default=str)

        prompt = f"""Summarize these operational alerts for an SRE team.
Group by severity and service. Identify patterns and correlations.
Recommend priority actions.

Alerts: {alert_context}

Provide a concise executive summary."""

        result = self.session.sql(f"""
            SELECT SNOWFLAKE.CORTEX.COMPLETE(
                '{self.model}',
                '{prompt.replace("'", "''")}'
            ) AS SUMMARY
        """).collect()

        return result[0]["SUMMARY"]

    def search_runbooks(self, query: str) -> list[dict]:
        results = self.session.sql(f"""
            SELECT *
            FROM TABLE(
                SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                    '{self.db}.AI_SRE.AI_SRE_RUNBOOK_SEARCH',
                    '{query.replace("'", "''")}',
                    {{
                        'columns': ['RUNBOOK_ID', 'TITLE', 'SERVICE_NAME', 'STEPS', 'AUTOMATION_LEVEL'],
                        'limit': 5
                    }}
                )
            )
        """).collect()

        return [dict(r) for r in results]


# ==============================================================================
# 3. OBSERVABILITY CONTEXT GRAPH BUILDER
# ==============================================================================

class ContextGraphBuilder:
    def __init__(self, session: Session):
        self.session = session
        self.db = "OBSERVABILITY_PLATFORM"

    def discover_service_topology(self) -> dict:
        dependencies = self.session.sql(f"""
            SELECT
                SOURCE_SERVICE,
                TARGET_SERVICE,
                CALL_TYPE,
                CALL_COUNT,
                AVG_LATENCY_MS,
                ERROR_RATE
            FROM {self.db}.CONTEXT_GRAPH.DT_AUTO_DISCOVERED_DEPENDENCIES
            ORDER BY CALL_COUNT DESC
        """).collect()

        topology = {"nodes": set(), "edges": []}
        for dep in dependencies:
            topology["nodes"].add(dep["SOURCE_SERVICE"])
            topology["nodes"].add(dep["TARGET_SERVICE"])
            topology["edges"].append({
                "source": dep["SOURCE_SERVICE"],
                "target": dep["TARGET_SERVICE"],
                "call_type": dep["CALL_TYPE"],
                "call_count": dep["CALL_COUNT"],
                "avg_latency_ms": dep["AVG_LATENCY_MS"],
                "error_rate": dep["ERROR_RATE"],
            })

        topology["nodes"] = list(topology["nodes"])
        return topology

    def correlate_trace_to_logs(self, trace_id: str) -> dict:
        spans = self.session.sql(f"""
            SELECT SPAN_ID, SPAN_NAME, SERVICE_NAME, DURATION_MS,
                   STATUS_CODE, START_TIME, END_TIME
            FROM {self.db}.SILVER.DT_ENRICHED_TRACES
            WHERE TRACE_ID = '{trace_id}'
            ORDER BY START_TIME
        """).collect()

        logs = self.session.sql(f"""
            SELECT LOG_TIMESTAMP, SEVERITY, SERVICE_NAME, LOG_MESSAGE, SPAN_ID
            FROM {self.db}.SILVER.DT_ENRICHED_LOGS
            WHERE TRACE_ID = '{trace_id}'
            ORDER BY LOG_TIMESTAMP
        """).collect()

        return {
            "trace_id": trace_id,
            "span_count": len(spans),
            "spans": [dict(s) for s in spans],
            "log_count": len(logs),
            "logs": [dict(l) for l in logs],
        }

    def build_blast_radius(self, service_name: str) -> dict:
        downstream = self.session.sql(f"""
            WITH RECURSIVE dep_tree AS (
                SELECT TARGET_SERVICE AS SERVICE, 1 AS DEPTH
                FROM {self.db}.CONTEXT_GRAPH.SERVICE_DEPENDENCIES
                WHERE SOURCE_SERVICE = '{service_name}'
                UNION ALL
                SELECT sd.TARGET_SERVICE, dt.DEPTH + 1
                FROM {self.db}.CONTEXT_GRAPH.SERVICE_DEPENDENCIES sd
                JOIN dep_tree dt ON sd.SOURCE_SERVICE = dt.SERVICE
                WHERE dt.DEPTH < 5
            )
            SELECT DISTINCT SERVICE, MIN(DEPTH) AS DEPTH
            FROM dep_tree
            GROUP BY SERVICE
            ORDER BY DEPTH
        """).collect()

        return {
            "source_service": service_name,
            "blast_radius": [dict(d) for d in downstream],
            "total_affected_services": len(downstream),
        }


# ==============================================================================
# 4. STORED PROCEDURES FOR AUTOMATION
# ==============================================================================

def register_stored_procedures(session: Session):

    @sproc(
        name="OBSERVABILITY_PLATFORM.AI_SRE.SP_INVESTIGATE_INCIDENT",
        is_permanent=True,
        stage_location="@OBSERVABILITY_PLATFORM.AI_SRE.PROC_STAGE",
        replace=True,
        packages=["snowflake-snowpark-python"],
    )
    def sp_investigate_incident(session: Session, incident_id: str) -> str:
        engine = AISREEngine(session)
        result = engine.investigate_incident(incident_id)
        return json.dumps(result, default=str)

    @sproc(
        name="OBSERVABILITY_PLATFORM.AI_SRE.SP_DETECT_ANOMALIES",
        is_permanent=True,
        stage_location="@OBSERVABILITY_PLATFORM.AI_SRE.PROC_STAGE",
        replace=True,
        packages=["snowflake-snowpark-python"],
    )
    def sp_detect_anomalies(session: Session, service_name: str, lookback_hours: int) -> str:
        engine = AISREEngine(session)
        anomalies = engine.detect_anomalies(service_name, lookback_hours)
        return json.dumps(anomalies, default=str)

    @sproc(
        name="OBSERVABILITY_PLATFORM.AI_SRE.SP_GENERATE_ALERT_SUMMARY",
        is_permanent=True,
        stage_location="@OBSERVABILITY_PLATFORM.AI_SRE.PROC_STAGE",
        replace=True,
        packages=["snowflake-snowpark-python"],
    )
    def sp_generate_alert_summary(session: Session, hours: int) -> str:
        engine = AISREEngine(session)
        summary = engine.generate_alert_summary(hours)
        return summary

    @sproc(
        name="OBSERVABILITY_PLATFORM.CONTEXT_GRAPH.SP_BUILD_BLAST_RADIUS",
        is_permanent=True,
        stage_location="@OBSERVABILITY_PLATFORM.AI_SRE.PROC_STAGE",
        replace=True,
        packages=["snowflake-snowpark-python"],
    )
    def sp_build_blast_radius(session: Session, service_name: str) -> str:
        builder = ContextGraphBuilder(session)
        result = builder.build_blast_radius(service_name)
        return json.dumps(result, default=str)


# ==============================================================================
# 5. SNOWFLAKE TELEMETRY COLLECTOR
# ==============================================================================

class SnowflakeTelemetryCollector:
    def __init__(self, session: Session):
        self.session = session
        self.db = "OBSERVABILITY_PLATFORM"

    def collect_query_history(self, hours: int = 1):
        self.session.sql(f"""
            INSERT INTO {self.db}.RAW_TELEMETRY.RAW_SNOWFLAKE_TELEMETRY
            (TELEMETRY_TYPE, EVENT_TIMESTAMP, WAREHOUSE_NAME, QUERY_ID,
             USER_NAME, ROLE_NAME, DATABASE_NAME, SCHEMA_NAME,
             EXECUTION_TIME_MS, BYTES_SCANNED, ROWS_PRODUCED,
             CREDITS_USED, QUERY_TEXT, ERROR_CODE, ERROR_MESSAGE)
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
                QUERY_TEXT,
                ERROR_CODE,
                ERROR_MESSAGE
            FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
            WHERE START_TIME >= DATEADD('HOUR', -{hours}, CURRENT_TIMESTAMP())
                AND START_TIME > (
                    SELECT COALESCE(MAX(EVENT_TIMESTAMP), '1970-01-01'::TIMESTAMP_NTZ)
                    FROM {self.db}.RAW_TELEMETRY.RAW_SNOWFLAKE_TELEMETRY
                    WHERE TELEMETRY_TYPE = 'QUERY_HISTORY'
                )
        """).collect()

    def collect_warehouse_metrics(self, hours: int = 1):
        self.session.sql(f"""
            INSERT INTO {self.db}.RAW_TELEMETRY.RAW_SNOWFLAKE_TELEMETRY
            (TELEMETRY_TYPE, EVENT_TIMESTAMP, WAREHOUSE_NAME, CREDITS_USED,
             ADDITIONAL_METADATA)
            SELECT
                'WAREHOUSE_METERING',
                START_TIME,
                WAREHOUSE_NAME,
                CREDITS_USED,
                OBJECT_CONSTRUCT(
                    'credits_compute', CREDITS_USED_COMPUTE,
                    'credits_cloud', CREDITS_USED_CLOUD_SERVICES,
                    'avg_running', AVG_RUNNING
                )
            FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
            WHERE START_TIME >= DATEADD('HOUR', -{hours}, CURRENT_TIMESTAMP())
                AND START_TIME > (
                    SELECT COALESCE(MAX(EVENT_TIMESTAMP), '1970-01-01'::TIMESTAMP_NTZ)
                    FROM {self.db}.RAW_TELEMETRY.RAW_SNOWFLAKE_TELEMETRY
                    WHERE TELEMETRY_TYPE = 'WAREHOUSE_METERING'
                )
        """).collect()


# ==============================================================================
# 6. MAIN ORCHESTRATOR
# ==============================================================================

def main():
    session = Session.builder.configs({"connection_name": "default"}).create()

    ingestor = TelemetryIngestor(session)
    ai_engine = AISREEngine(session)
    graph_builder = ContextGraphBuilder(session)
    sf_collector = SnowflakeTelemetryCollector(session)

    sf_collector.collect_query_history(hours=1)
    sf_collector.collect_warehouse_metrics(hours=1)

    topology = graph_builder.discover_service_topology()
    print(f"Discovered {len(topology['nodes'])} services, {len(topology['edges'])} dependencies")

    summary = ai_engine.generate_alert_summary(hours=1)
    print(f"Alert Summary: {summary}")

    session.close()


if __name__ == "__main__":
    main()
