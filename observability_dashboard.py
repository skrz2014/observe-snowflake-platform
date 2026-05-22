# ==============================================================================
# OBSERVE BY SNOWFLAKE - STREAMLIT OBSERVABILITY COMMAND CENTER
# Enterprise-Grade Real-Time Monitoring Dashboard
# ==============================================================================

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from datetime import datetime, timedelta
from snowflake.snowpark.context import get_active_session

st.set_page_config(
    page_title="Observability Command Center",
    page_icon="🔭",
    layout="wide",
    initial_sidebar_state="expanded",
)

session = get_active_session()
DB = "OBSERVABILITY_PLATFORM"


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

@st.cache_data(ttl=60)
def run_query(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


def get_service_health() -> pd.DataFrame:
    return run_query(f"""
        SELECT SERVICE_NAME, ENVIRONMENT, HEALTH_SCORE, SUCCESS_RATE,
               AVG_LATENCY_MS, ERROR_COUNT, REQUEST_COUNT, HOUR_BUCKET
        FROM {DB}.GOLD.DT_SERVICE_HEALTH_SCORE
        WHERE HOUR_BUCKET >= DATEADD('HOUR', -24, CURRENT_TIMESTAMP())
        ORDER BY HOUR_BUCKET DESC
    """)


def get_slo_compliance() -> pd.DataFrame:
    return run_query(f"""
        SELECT SERVICE_NAME, SLO_DATE, AVAILABILITY_SLI, LATENCY_SLI,
               P50_LATENCY, P95_LATENCY, P99_LATENCY, TOTAL_REQUESTS, FAILED_REQUESTS
        FROM {DB}.GOLD.DT_SLO_COMPLIANCE
        WHERE SLO_DATE >= DATEADD('DAY', -30, CURRENT_DATE())
        ORDER BY SLO_DATE DESC
    """)


def get_recent_incidents() -> pd.DataFrame:
    return run_query(f"""
        SELECT INCIDENT_ID, CREATED_AT, SEVERITY, STATUS, TITLE,
               SERVICE_NAME, AI_SUMMARY, TTDA_MINUTES, TTTA_MINUTES, TTTR_MINUTES
        FROM {DB}.AI_SRE.INCIDENTS
        WHERE CREATED_AT >= DATEADD('DAY', -30, CURRENT_TIMESTAMP())
        ORDER BY CREATED_AT DESC
        LIMIT 100
    """)


def get_alert_counts() -> pd.DataFrame:
    return run_query(f"""
        SELECT DATE_TRUNC('HOUR', TRIGGERED_AT) AS HOUR,
               SEVERITY, COUNT(*) AS ALERT_COUNT
        FROM {DB}.ALERTING.ALERT_HISTORY
        WHERE TRIGGERED_AT >= DATEADD('DAY', -7, CURRENT_TIMESTAMP())
        GROUP BY ALL
        ORDER BY HOUR DESC
    """)


def get_cost_data() -> pd.DataFrame:
    return run_query(f"""
        SELECT COST_DATE, WAREHOUSE_NAME, TOTAL_CREDITS,
               QUERY_COUNT, AVG_EXECUTION_MS, CREDITS_PER_QUERY
        FROM {DB}.GOLD.DT_COST_ANALYTICS
        WHERE COST_DATE >= DATEADD('DAY', -30, CURRENT_DATE())
        ORDER BY COST_DATE DESC
    """)


def get_error_trends() -> pd.DataFrame:
    return run_query(f"""
        SELECT LOG_HOUR, SERVICE_NAME, SEVERITY,
               COUNT(*) AS LOG_COUNT
        FROM {DB}.SILVER.DT_ENRICHED_LOGS
        WHERE SEVERITY IN ('ERROR', 'FATAL', 'CRITICAL')
            AND LOG_TIMESTAMP >= DATEADD('DAY', -7, CURRENT_TIMESTAMP())
        GROUP BY ALL
        ORDER BY LOG_HOUR DESC
    """)


def get_trace_latency() -> pd.DataFrame:
    return run_query(f"""
        SELECT TRACE_HOUR, SERVICE_NAME, LATENCY_BUCKET,
               COUNT(*) AS SPAN_COUNT,
               AVG(DURATION_MS) AS AVG_DURATION_MS,
               APPROX_PERCENTILE(DURATION_MS, 0.95) AS P95_MS
        FROM {DB}.SILVER.DT_ENRICHED_TRACES
        WHERE IS_ROOT_SPAN = TRUE
            AND START_TIME >= DATEADD('DAY', -7, CURRENT_TIMESTAMP())
        GROUP BY ALL
        ORDER BY TRACE_HOUR DESC
    """)


def get_anomalies() -> pd.DataFrame:
    return run_query(f"""
        SELECT DETECTED_AT, METRIC_NAME, SERVICE_NAME,
               EXPECTED_VALUE, ACTUAL_VALUE, DEVIATION_SCORE, ANOMALY_TYPE
        FROM {DB}.AI_SRE.ANOMALY_DETECTIONS
        WHERE DETECTED_AT >= DATEADD('DAY', -7, CURRENT_TIMESTAMP())
        ORDER BY DEVIATION_SCORE DESC
        LIMIT 50
    """)


# ==============================================================================
# SIDEBAR
# ==============================================================================

with st.sidebar:
    st.title("Observability Command Center")
    st.divider()

    page = st.radio(
        "Navigation",
        [
            "Executive Overview",
            "Service Health",
            "SLO Dashboard",
            "Incident Management",
            "Distributed Tracing",
            "Log Analytics",
            "Cost Observatory",
            "AI SRE Assistant",
            "Anomaly Detection",
            "Infrastructure",
        ],
    )

    st.divider()
    env_filter = st.selectbox("Environment", ["All", "production", "staging", "development"])
    time_range = st.selectbox("Time Range", ["1h", "6h", "24h", "7d", "30d"])

    st.divider()
    st.caption("Last refreshed: " + datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    if st.button("Refresh Data"):
        st.cache_data.clear()
        st.rerun()


# ==============================================================================
# PAGE: EXECUTIVE OVERVIEW
# ==============================================================================

if page == "Executive Overview":
    st.header("Executive Observability Overview")

    col1, col2, col3, col4, col5 = st.columns(5)

    health_df = get_service_health()
    incidents_df = get_recent_incidents()
    cost_df = get_cost_data()

    if not health_df.empty:
        latest_health = health_df.groupby("SERVICE_NAME")["HEALTH_SCORE"].first()
        avg_health = latest_health.mean()
        col1.metric("Avg Health Score", f"{avg_health:.1f}/100",
                    delta=f"{avg_health - 85:.1f}" if avg_health else None)

    if not incidents_df.empty:
        open_incidents = len(incidents_df[incidents_df["STATUS"] == "OPEN"])
        col2.metric("Open Incidents", open_incidents)
        p1_incidents = len(incidents_df[
            (incidents_df["STATUS"] == "OPEN") & (incidents_df["SEVERITY"].isin(["P1", "CRITICAL"]))
        ])
        col3.metric("P1/Critical", p1_incidents, delta_color="inverse")

    if not cost_df.empty:
        today_credits = cost_df[cost_df["COST_DATE"] == cost_df["COST_DATE"].max()]["TOTAL_CREDITS"].sum()
        col4.metric("Today's Credits", f"{today_credits:.1f}")

    if not incidents_df.empty and "TTTR_MINUTES" in incidents_df.columns:
        resolved = incidents_df[incidents_df["TTTR_MINUTES"].notna()]
        if not resolved.empty:
            avg_mttr = resolved["TTTR_MINUTES"].mean()
            col5.metric("Avg MTTR (min)", f"{avg_mttr:.0f}")

    st.divider()

    col_left, col_right = st.columns(2)

    with col_left:
        st.subheader("Service Health Heatmap")
        if not health_df.empty:
            pivot = health_df.pivot_table(
                index="SERVICE_NAME", columns="HOUR_BUCKET", values="HEALTH_SCORE", aggfunc="mean"
            )
            fig = px.imshow(
                pivot.values,
                labels=dict(x="Time", y="Service", color="Health Score"),
                y=pivot.index.tolist(),
                color_continuous_scale="RdYlGn",
                zmin=0, zmax=100,
            )
            fig.update_layout(height=400)
            st.plotly_chart(fig, use_container_width=True)

    with col_right:
        st.subheader("Alert Trend")
        alerts_df = get_alert_counts()
        if not alerts_df.empty:
            fig = px.bar(
                alerts_df, x="HOUR", y="ALERT_COUNT", color="SEVERITY",
                color_discrete_map={
                    "CRITICAL": "#dc3545", "WARNING": "#ffc107", "INFO": "#17a2b8"
                },
            )
            fig.update_layout(height=400)
            st.plotly_chart(fig, use_container_width=True)

    st.subheader("Recent Incidents")
    if not incidents_df.empty:
        st.dataframe(
            incidents_df[["CREATED_AT", "SEVERITY", "STATUS", "TITLE", "SERVICE_NAME"]].head(10),
            use_container_width=True,
            hide_index=True,
        )


# ==============================================================================
# PAGE: SERVICE HEALTH
# ==============================================================================

elif page == "Service Health":
    st.header("Service Health Monitor")

    health_df = get_service_health()

    if not health_df.empty:
        services = health_df["SERVICE_NAME"].unique()

        col1, col2 = st.columns([1, 3])
        with col1:
            selected_service = st.selectbox("Select Service", ["All"] + list(services))

        if selected_service != "All":
            health_df = health_df[health_df["SERVICE_NAME"] == selected_service]

        st.subheader("Current Health Scores")
        latest = health_df.sort_values("HOUR_BUCKET", ascending=False).groupby("SERVICE_NAME").first().reset_index()

        cols = st.columns(min(len(latest), 6))
        for idx, row in latest.iterrows():
            with cols[idx % len(cols)]:
                score = row["HEALTH_SCORE"]
                color = "normal" if score >= 80 else ("off" if score >= 50 else "inverse")
                st.metric(row["SERVICE_NAME"], f"{score:.0f}/100", delta_color=color)

        st.subheader("Health Score Over Time")
        fig = px.line(
            health_df, x="HOUR_BUCKET", y="HEALTH_SCORE",
            color="SERVICE_NAME", markers=True,
        )
        fig.add_hline(y=80, line_dash="dash", line_color="orange", annotation_text="Warning Threshold")
        fig.add_hline(y=50, line_dash="dash", line_color="red", annotation_text="Critical Threshold")
        fig.update_layout(height=500)
        st.plotly_chart(fig, use_container_width=True)

        col_left, col_right = st.columns(2)
        with col_left:
            st.subheader("Error Rate by Service")
            fig = px.bar(latest, x="SERVICE_NAME", y="ERROR_COUNT", color="SERVICE_NAME")
            st.plotly_chart(fig, use_container_width=True)

        with col_right:
            st.subheader("Avg Latency by Service")
            fig = px.bar(latest, x="SERVICE_NAME", y="AVG_LATENCY_MS", color="SERVICE_NAME")
            st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No service health data available yet.")


# ==============================================================================
# PAGE: SLO DASHBOARD
# ==============================================================================

elif page == "SLO Dashboard":
    st.header("SLO Compliance Dashboard")

    slo_df = get_slo_compliance()

    if not slo_df.empty:
        col1, col2, col3 = st.columns(3)

        with col1:
            avg_avail = slo_df["AVAILABILITY_SLI"].mean() * 100
            st.metric("Avg Availability", f"{avg_avail:.3f}%",
                      delta=f"{avg_avail - 99.9:.3f}%" if avg_avail else None)
        with col2:
            avg_latency_sli = slo_df["LATENCY_SLI"].mean() * 100
            st.metric("Avg Latency SLI", f"{avg_latency_sli:.2f}%")
        with col3:
            st.metric("Avg P99 Latency", f"{slo_df['P99_LATENCY'].mean():.0f}ms")

        st.subheader("Availability SLI Trend")
        fig = px.line(
            slo_df, x="SLO_DATE", y="AVAILABILITY_SLI", color="SERVICE_NAME",
        )
        fig.add_hline(y=0.999, line_dash="dash", line_color="red", annotation_text="SLO Target (99.9%)")
        fig.update_layout(height=400, yaxis_tickformat=".4f")
        st.plotly_chart(fig, use_container_width=True)

        st.subheader("Latency Percentiles")
        fig = make_subplots(rows=1, cols=1)
        for service in slo_df["SERVICE_NAME"].unique()[:5]:
            svc_data = slo_df[slo_df["SERVICE_NAME"] == service]
            fig.add_trace(go.Scatter(
                x=svc_data["SLO_DATE"], y=svc_data["P95_LATENCY"],
                name=f"{service} (P95)", mode="lines",
            ))
        fig.update_layout(height=400, title="P95 Latency by Service")
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No SLO data available yet.")


# ==============================================================================
# PAGE: INCIDENT MANAGEMENT
# ==============================================================================

elif page == "Incident Management":
    st.header("Incident Management")

    incidents_df = get_recent_incidents()

    if not incidents_df.empty:
        col1, col2, col3, col4 = st.columns(4)
        col1.metric("Total Incidents (30d)", len(incidents_df))
        col2.metric("Open", len(incidents_df[incidents_df["STATUS"] == "OPEN"]))
        col3.metric("Resolved", len(incidents_df[incidents_df["STATUS"] == "RESOLVED"]))

        resolved = incidents_df[incidents_df["TTTR_MINUTES"].notna()]
        if not resolved.empty:
            col4.metric("Avg MTTR", f"{resolved['TTTR_MINUTES'].mean():.0f} min")

        st.subheader("Incidents by Severity")
        severity_counts = incidents_df["SEVERITY"].value_counts().reset_index()
        fig = px.pie(severity_counts, values="count", names="SEVERITY",
                     color="SEVERITY",
                     color_discrete_map={"P1": "#dc3545", "P2": "#fd7e14",
                                         "P3": "#ffc107", "P4": "#28a745"})
        st.plotly_chart(fig, use_container_width=True)

        st.subheader("Incident Timeline")
        st.dataframe(
            incidents_df[["CREATED_AT", "SEVERITY", "STATUS", "TITLE", "SERVICE_NAME", "AI_SUMMARY"]],
            use_container_width=True, hide_index=True,
        )
    else:
        st.info("No incidents recorded yet.")


# ==============================================================================
# PAGE: DISTRIBUTED TRACING
# ==============================================================================

elif page == "Distributed Tracing":
    st.header("Distributed Tracing Analysis")

    trace_df = get_trace_latency()

    if not trace_df.empty:
        col1, col2 = st.columns(2)
        with col1:
            st.subheader("Latency Distribution by Service")
            fig = px.box(trace_df, x="SERVICE_NAME", y="AVG_DURATION_MS", color="SERVICE_NAME")
            fig.update_layout(height=400)
            st.plotly_chart(fig, use_container_width=True)

        with col2:
            st.subheader("Latency Bucket Distribution")
            bucket_counts = trace_df.groupby("LATENCY_BUCKET")["SPAN_COUNT"].sum().reset_index()
            fig = px.pie(bucket_counts, values="SPAN_COUNT", names="LATENCY_BUCKET",
                         color="LATENCY_BUCKET",
                         color_discrete_map={
                             "NORMAL": "#28a745", "MODERATE": "#ffc107",
                             "SLOW": "#fd7e14", "CRITICAL": "#dc3545"
                         })
            fig.update_layout(height=400)
            st.plotly_chart(fig, use_container_width=True)

        st.subheader("P95 Latency Over Time")
        fig = px.line(trace_df, x="TRACE_HOUR", y="P95_MS", color="SERVICE_NAME")
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)

        st.subheader("Trace Search")
        trace_id = st.text_input("Enter Trace ID")
        if trace_id:
            spans = run_query(f"""
                SELECT SPAN_NAME, SERVICE_NAME, DURATION_MS, STATUS_CODE,
                       START_TIME, END_TIME, IS_ERROR, LATENCY_BUCKET
                FROM {DB}.SILVER.DT_ENRICHED_TRACES
                WHERE TRACE_ID = '{trace_id}'
                ORDER BY START_TIME
            """)
            if not spans.empty:
                st.dataframe(spans, use_container_width=True, hide_index=True)
            else:
                st.warning("No spans found for this trace ID.")
    else:
        st.info("No trace data available yet.")


# ==============================================================================
# PAGE: LOG ANALYTICS
# ==============================================================================

elif page == "Log Analytics":
    st.header("Log Analytics")

    error_df = get_error_trends()

    if not error_df.empty:
        st.subheader("Error Volume Over Time")
        fig = px.area(
            error_df.groupby(["LOG_HOUR", "SEVERITY"])["LOG_COUNT"].sum().reset_index(),
            x="LOG_HOUR", y="LOG_COUNT", color="SEVERITY",
            color_discrete_map={"ERROR": "#fd7e14", "FATAL": "#dc3545", "CRITICAL": "#6f42c1"},
        )
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)

        st.subheader("Errors by Service")
        svc_errors = error_df.groupby("SERVICE_NAME")["LOG_COUNT"].sum().reset_index().sort_values("LOG_COUNT", ascending=False)
        fig = px.bar(svc_errors.head(10), x="SERVICE_NAME", y="LOG_COUNT", color="SERVICE_NAME")
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)

        st.subheader("Log Search")
        search_term = st.text_input("Search logs (keyword)")
        if search_term:
            results = run_query(f"""
                SELECT LOG_TIMESTAMP, SEVERITY, SERVICE_NAME, LOG_MESSAGE
                FROM {DB}.SILVER.DT_ENRICHED_LOGS
                WHERE CONTAINS(LOWER(LOG_MESSAGE), LOWER('{search_term}'))
                    AND LOG_TIMESTAMP >= DATEADD('DAY', -1, CURRENT_TIMESTAMP())
                ORDER BY LOG_TIMESTAMP DESC
                LIMIT 100
            """)
            st.dataframe(results, use_container_width=True, hide_index=True)
    else:
        st.info("No error log data available yet.")


# ==============================================================================
# PAGE: COST OBSERVATORY
# ==============================================================================

elif page == "Cost Observatory":
    st.header("Cost Observatory")

    cost_df = get_cost_data()

    if not cost_df.empty:
        col1, col2, col3 = st.columns(3)
        total_30d = cost_df["TOTAL_CREDITS"].sum()
        col1.metric("Total Credits (30d)", f"{total_30d:.0f}")
        col2.metric("Avg Daily Credits", f"{total_30d / 30:.1f}")
        col3.metric("Avg Cost/Query", f"{cost_df['CREDITS_PER_QUERY'].mean():.4f}")

        st.subheader("Daily Credit Consumption")
        daily = cost_df.groupby("COST_DATE")["TOTAL_CREDITS"].sum().reset_index()
        fig = px.bar(daily, x="COST_DATE", y="TOTAL_CREDITS")
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)

        st.subheader("Credits by Warehouse")
        wh_credits = cost_df.groupby("WAREHOUSE_NAME")["TOTAL_CREDITS"].sum().reset_index().sort_values("TOTAL_CREDITS", ascending=False)
        fig = px.pie(wh_credits, values="TOTAL_CREDITS", names="WAREHOUSE_NAME")
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)

        st.subheader("Query Performance vs Cost")
        fig = px.scatter(
            cost_df, x="AVG_EXECUTION_MS", y="CREDITS_PER_QUERY",
            color="WAREHOUSE_NAME", size="QUERY_COUNT",
            hover_data=["COST_DATE"],
        )
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No cost data available yet.")


# ==============================================================================
# PAGE: AI SRE ASSISTANT
# ==============================================================================

elif page == "AI SRE Assistant":
    st.header("AI SRE Assistant")

    st.subheader("Natural Language Observability Query")
    user_query = st.text_area("Ask about your systems:", placeholder="e.g., Why is the payment service slow?")

    if st.button("Ask AI SRE") and user_query:
        with st.spinner("AI SRE is analyzing..."):
            context_sql = f"""
                SELECT TOP 5 SERVICE_NAME, HEALTH_SCORE, AVG_LATENCY_MS, ERROR_COUNT
                FROM {DB}.GOLD.DT_SERVICE_HEALTH_SCORE
                WHERE HOUR_BUCKET = DATE_TRUNC('HOUR', CURRENT_TIMESTAMP())
                ORDER BY HEALTH_SCORE ASC
            """
            context_data = run_query(context_sql)

            prompt = f"""You are an expert SRE AI assistant. Answer the following question using the system context.

Question: {user_query}

Current System Context:
{context_data.to_string() if not context_data.empty else 'No data available'}

Provide actionable insights and recommendations."""

            result = run_query(f"""
                SELECT SNOWFLAKE.CORTEX.COMPLETE('mistral-large2', '{prompt.replace("'", "''")}') AS RESPONSE
            """)

            if not result.empty:
                st.markdown("**AI SRE Response:**")
                st.markdown(result.iloc[0]["RESPONSE"])

    st.divider()

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("Investigate Incident")
        incident_id = st.text_input("Incident ID")
        if st.button("Investigate") and incident_id:
            with st.spinner("Investigating..."):
                result = run_query(f"""
                    CALL {DB}.AI_SRE.SP_INVESTIGATE_INCIDENT('{incident_id}')
                """)
                if not result.empty:
                    st.json(result.iloc[0][0])

    with col2:
        st.subheader("Generate Alert Summary")
        hours = st.slider("Lookback Hours", 1, 24, 6)
        if st.button("Summarize Alerts"):
            with st.spinner("Generating summary..."):
                result = run_query(f"""
                    CALL {DB}.AI_SRE.SP_GENERATE_ALERT_SUMMARY({hours})
                """)
                if not result.empty:
                    st.markdown(result.iloc[0][0])


# ==============================================================================
# PAGE: ANOMALY DETECTION
# ==============================================================================

elif page == "Anomaly Detection":
    st.header("AI Anomaly Detection")

    anomalies_df = get_anomalies()

    if not anomalies_df.empty:
        col1, col2 = st.columns(2)
        col1.metric("Active Anomalies", len(anomalies_df))
        col2.metric("Avg Deviation Score", f"{anomalies_df['DEVIATION_SCORE'].mean():.2f}")

        st.subheader("Anomaly Heatmap")
        fig = px.scatter(
            anomalies_df, x="DETECTED_AT", y="METRIC_NAME",
            color="DEVIATION_SCORE", size="DEVIATION_SCORE",
            color_continuous_scale="Reds",
            hover_data=["SERVICE_NAME", "EXPECTED_VALUE", "ACTUAL_VALUE"],
        )
        fig.update_layout(height=500)
        st.plotly_chart(fig, use_container_width=True)

        st.subheader("Anomaly Details")
        st.dataframe(anomalies_df, use_container_width=True, hide_index=True)

        st.subheader("Run Anomaly Detection")
        svc = st.text_input("Service Name for Detection")
        lookback = st.slider("Lookback Hours", 1, 72, 24)
        if st.button("Detect Anomalies") and svc:
            with st.spinner("Running anomaly detection..."):
                result = run_query(f"""
                    CALL {DB}.AI_SRE.SP_DETECT_ANOMALIES('{svc}', {lookback})
                """)
                if not result.empty:
                    st.json(result.iloc[0][0])
    else:
        st.info("No anomalies detected recently.")


# ==============================================================================
# PAGE: INFRASTRUCTURE
# ==============================================================================

elif page == "Infrastructure":
    st.header("Infrastructure Monitoring")

    st.subheader("Snowflake Warehouse Performance")
    wh_data = run_query(f"""
        SELECT WAREHOUSE_NAME, EVENT_TIMESTAMP, CREDITS_USED,
               ADDITIONAL_METADATA:"avg_running"::FLOAT AS AVG_CONCURRENT
        FROM {DB}.RAW_TELEMETRY.RAW_SNOWFLAKE_TELEMETRY
        WHERE TELEMETRY_TYPE = 'WAREHOUSE_METERING'
            AND EVENT_TIMESTAMP >= DATEADD('DAY', -7, CURRENT_TIMESTAMP())
        ORDER BY EVENT_TIMESTAMP DESC
        LIMIT 500
    """)

    if not wh_data.empty:
        fig = px.line(wh_data, x="EVENT_TIMESTAMP", y="CREDITS_USED", color="WAREHOUSE_NAME")
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)

    st.subheader("Kubernetes Cluster Events")
    k8s_df = run_query(f"""
        SELECT EVENT_TIMESTAMP, CLUSTER_NAME, NAMESPACE, EVENT_TYPE,
               REASON, OBJECT_KIND, OBJECT_NAME, MESSAGE
        FROM {DB}.RAW_TELEMETRY.RAW_K8S_EVENTS
        WHERE EVENT_TIMESTAMP >= DATEADD('DAY', -1, CURRENT_TIMESTAMP())
        ORDER BY EVENT_TIMESTAMP DESC
        LIMIT 100
    """)

    if not k8s_df.empty:
        col1, col2 = st.columns(2)
        with col1:
            type_counts = k8s_df["EVENT_TYPE"].value_counts().reset_index()
            fig = px.pie(type_counts, values="count", names="EVENT_TYPE")
            st.plotly_chart(fig, use_container_width=True)
        with col2:
            ns_counts = k8s_df["NAMESPACE"].value_counts().head(10).reset_index()
            fig = px.bar(ns_counts, x="NAMESPACE", y="count")
            st.plotly_chart(fig, use_container_width=True)

        st.dataframe(k8s_df, use_container_width=True, hide_index=True)
    else:
        st.info("No Kubernetes event data available.")
