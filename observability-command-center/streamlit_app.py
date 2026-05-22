import os
import streamlit as st

st.set_page_config(
    page_title="Observability Command Center",
    layout="wide",
    initial_sidebar_state="expanded",
)

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
DB = "OBSERVABILITY_PLATFORM"


@st.cache_data(ttl=60)
def run_query(sql: str):
    return conn.query(sql)


with st.sidebar:
    st.title("Observability Command Center")
    st.divider()
    page = st.radio(
        "Navigation",
        [
            "Executive Overview",
            "Service Health",
            "SLO Dashboard",
            "Incidents",
            "Cost Observatory",
            "AI SRE Assistant",
        ],
    )
    st.divider()
    if st.button("Refresh Data", on_click=run_query.clear):
        st.rerun()


if page == "Executive Overview":
    st.header("Executive Observability Overview")

    health_df = run_query(f"""
        SELECT SERVICE_NAME, HEALTH_SCORE, SUCCESS_RATE, AVG_LATENCY_MS, ERROR_COUNT, HOUR_BUCKET
        FROM {DB}.GOLD.DT_SERVICE_HEALTH_SCORE
        WHERE HOUR_BUCKET >= DATEADD('HOUR', -24, CURRENT_TIMESTAMP())
        ORDER BY HOUR_BUCKET DESC
    """)

    incidents_df = run_query(f"""
        SELECT SEVERITY, STATUS, TITLE, SERVICE_NAME, CREATED_AT, TTTR_MINUTES
        FROM {DB}.AI_SRE.INCIDENTS
        ORDER BY CREATED_AT DESC
        LIMIT 20
    """)

    alerts_df = run_query(f"""
        SELECT DATE_TRUNC('HOUR', TRIGGERED_AT) AS HOUR, SEVERITY, COUNT(*) AS CNT
        FROM {DB}.ALERTING.ALERT_HISTORY
        WHERE TRIGGERED_AT >= DATEADD('DAY', -7, CURRENT_TIMESTAMP())
        GROUP BY ALL ORDER BY HOUR DESC
    """)

    col1, col2, col3, col4 = st.columns(4)

    if not health_df.empty:
        latest = health_df.groupby("SERVICE_NAME")["HEALTH_SCORE"].first()
        col1.metric("Avg Health Score", f"{latest.mean():.0f}/100")
    if not incidents_df.empty:
        open_count = len(incidents_df[incidents_df["STATUS"] == "OPEN"])
        col2.metric("Open Incidents", open_count)
        resolved = incidents_df[incidents_df["TTTR_MINUTES"].notna()]
        if not resolved.empty:
            col3.metric("Avg MTTR (min)", f"{resolved['TTTR_MINUTES'].mean():.0f}")
    if not alerts_df.empty:
        col4.metric("Alerts (7d)", int(alerts_df["CNT"].sum()))

    st.divider()

    col_left, col_right = st.columns(2)

    with col_left:
        st.subheader("Service Health Over Time")
        if not health_df.empty:
            st.line_chart(health_df, x="HOUR_BUCKET", y="HEALTH_SCORE", color="SERVICE_NAME")

    with col_right:
        st.subheader("Alert Volume")
        if not alerts_df.empty:
            st.bar_chart(alerts_df, x="HOUR", y="CNT", color="SEVERITY")

    st.subheader("Recent Incidents")
    if not incidents_df.empty:
        st.dataframe(
            incidents_df[["CREATED_AT", "SEVERITY", "STATUS", "TITLE", "SERVICE_NAME"]],
            use_container_width=True, hide_index=True,
        )


elif page == "Service Health":
    st.header("Service Health Monitor")

    health_df = run_query(f"""
        SELECT SERVICE_NAME, HEALTH_SCORE, AVG_LATENCY_MS, ERROR_COUNT, SUCCESS_RATE, HOUR_BUCKET
        FROM {DB}.GOLD.DT_SERVICE_HEALTH_SCORE
        WHERE HOUR_BUCKET >= DATEADD('HOUR', -24, CURRENT_TIMESTAMP())
        ORDER BY HOUR_BUCKET DESC
    """)

    if not health_df.empty:
        latest = health_df.sort_values("HOUR_BUCKET", ascending=False).groupby("SERVICE_NAME").first().reset_index()

        cols = st.columns(min(len(latest), 5))
        for idx, row in latest.iterrows():
            with cols[idx % len(cols)]:
                st.metric(row["SERVICE_NAME"], f"{row['HEALTH_SCORE']:.0f}/100")

        st.divider()
        st.subheader("Health Score Trend")
        st.line_chart(health_df, x="HOUR_BUCKET", y="HEALTH_SCORE", color="SERVICE_NAME")

        st.subheader("Error Count by Service")
        st.bar_chart(latest, x="SERVICE_NAME", y="ERROR_COUNT")
    else:
        st.info("No health data available.")


elif page == "SLO Dashboard":
    st.header("SLO Compliance")

    slo_df = run_query(f"""
        SELECT SERVICE_NAME, SLO_DATE, AVAILABILITY_SLI, LATENCY_SLI,
               P50_LATENCY, P95_LATENCY, P99_LATENCY, TOTAL_REQUESTS
        FROM {DB}.GOLD.DT_SLO_COMPLIANCE
        WHERE SLO_DATE >= DATEADD('DAY', -30, CURRENT_DATE())
        ORDER BY SLO_DATE DESC
    """)

    if not slo_df.empty:
        col1, col2, col3 = st.columns(3)
        col1.metric("Avg Availability", f"{slo_df['AVAILABILITY_SLI'].mean() * 100:.3f}%")
        col2.metric("Avg Latency SLI", f"{slo_df['LATENCY_SLI'].mean() * 100:.2f}%")
        col3.metric("Avg P99 Latency", f"{slo_df['P99_LATENCY'].mean():.0f}ms")

        st.subheader("Availability SLI Trend")
        st.line_chart(slo_df, x="SLO_DATE", y="AVAILABILITY_SLI", color="SERVICE_NAME")

        st.subheader("Latency Percentiles")
        st.line_chart(slo_df, x="SLO_DATE", y="P95_LATENCY", color="SERVICE_NAME")
    else:
        st.info("No SLO data available.")


elif page == "Incidents":
    st.header("Incident Management")

    incidents_df = run_query(f"""
        SELECT INCIDENT_ID, CREATED_AT, SEVERITY, STATUS, TITLE,
               SERVICE_NAME, TTTR_MINUTES, ASSIGNED_TEAM
        FROM {DB}.AI_SRE.INCIDENTS
        ORDER BY CREATED_AT DESC
    """)

    if not incidents_df.empty:
        col1, col2, col3 = st.columns(3)
        col1.metric("Total", len(incidents_df))
        col2.metric("Open", len(incidents_df[incidents_df["STATUS"] == "OPEN"]))
        resolved = incidents_df[incidents_df["TTTR_MINUTES"].notna()]
        if not resolved.empty:
            col3.metric("Avg MTTR", f"{resolved['TTTR_MINUTES'].mean():.0f} min")

        st.subheader("Incidents by Severity")
        severity_counts = incidents_df["SEVERITY"].value_counts().reset_index()
        severity_counts.columns = ["SEVERITY", "COUNT"]
        st.bar_chart(severity_counts, x="SEVERITY", y="COUNT")

        st.subheader("All Incidents")
        st.dataframe(incidents_df, use_container_width=True, hide_index=True)
    else:
        st.info("No incidents.")


elif page == "Cost Observatory":
    st.header("Cost Observatory")

    cost_df = run_query(f"""
        SELECT COST_DATE, WAREHOUSE_NAME, TOTAL_CREDITS, QUERY_COUNT, CREDITS_PER_QUERY
        FROM {DB}.GOLD.DT_COST_ANALYTICS
        WHERE COST_DATE >= DATEADD('DAY', -30, CURRENT_DATE())
        ORDER BY COST_DATE DESC
    """)

    if not cost_df.empty:
        col1, col2, col3 = st.columns(3)
        col1.metric("Total Credits (30d)", f"{cost_df['TOTAL_CREDITS'].sum():.0f}")
        col2.metric("Total Queries", f"{int(cost_df['QUERY_COUNT'].sum()):,}")
        col3.metric("Avg Cost/Query", f"{cost_df['CREDITS_PER_QUERY'].mean():.4f}")

        st.subheader("Daily Credit Consumption")
        daily = cost_df.groupby("COST_DATE")["TOTAL_CREDITS"].sum().reset_index()
        st.bar_chart(daily, x="COST_DATE", y="TOTAL_CREDITS")

        st.subheader("Credits by Warehouse")
        wh = cost_df.groupby("WAREHOUSE_NAME")["TOTAL_CREDITS"].sum().reset_index()
        st.bar_chart(wh, x="WAREHOUSE_NAME", y="TOTAL_CREDITS")
    else:
        st.info("No cost data available yet.")

    st.divider()
    st.subheader("Optimization Recommendations")
    recs = run_query(f"""
        SELECT WAREHOUSE_NAME, AVG_HOURLY_CREDITS, PEAK_CREDITS,
               TOTAL_CREDITS_30D, RECOMMENDATION, ESTIMATED_SAVINGS_CREDITS
        FROM {DB}.COST_OPS.V_WAREHOUSE_OPTIMIZATION_RECOMMENDATIONS
    """)
    if not recs.empty:
        st.dataframe(recs, use_container_width=True, hide_index=True)


elif page == "AI SRE Assistant":
    st.header("AI SRE Assistant")

    st.info("Cortex AI (COMPLETE) is not available on trial accounts. Showing system context and service data instead.")

    st.subheader("Current System Health (Lowest Scores)")
    context = run_query(f"""
        SELECT SERVICE_NAME, HEALTH_SCORE, AVG_LATENCY_MS, ERROR_COUNT, SUCCESS_RATE
        FROM {DB}.GOLD.DT_SERVICE_HEALTH_SCORE
        WHERE HOUR_BUCKET >= DATEADD('HOUR', -1, CURRENT_TIMESTAMP())
        ORDER BY HEALTH_SCORE ASC
        LIMIT 10
    """)
    if not context.empty:
        st.dataframe(context, use_container_width=True, hide_index=True)
    else:
        st.warning("No recent health data available.")

    st.divider()

    st.subheader("Service Registry")
    services = run_query(f"""
        SELECT SERVICE_NAME, SERVICE_TYPE, TEAM_OWNER, TIER, SLO_AVAILABILITY, SLO_LATENCY_P99_MS
        FROM {DB}.CONTEXT_GRAPH.SERVICE_REGISTRY
        ORDER BY TIER, SERVICE_NAME
    """)
    if not services.empty:
        st.dataframe(services, use_container_width=True, hide_index=True)

    st.subheader("Service Dependencies")
    deps = run_query(f"""
        SELECT SOURCE_SERVICE, TARGET_SERVICE, DEPENDENCY_TYPE, PROTOCOL, IS_CRITICAL, AVG_LATENCY_MS, ERROR_RATE
        FROM {DB}.CONTEXT_GRAPH.SERVICE_DEPENDENCIES
        ORDER BY IS_CRITICAL DESC, ERROR_RATE DESC
    """)
    if not deps.empty:
        st.dataframe(deps, use_container_width=True, hide_index=True)
