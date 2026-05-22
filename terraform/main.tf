# ==============================================================================
# OBSERVE BY SNOWFLAKE - TERRAFORM INFRASTRUCTURE AS CODE
# Enterprise Observability Platform Deployment
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.90"
    }
  }
  backend "s3" {
    bucket  = "observability-terraform-state"
    key     = "snowflake/observability-platform.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
}

provider "snowflake" {
  role = "ACCOUNTADMIN"
}

# ==============================================================================
# VARIABLES
# ==============================================================================

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
  default     = "prod"
}

variable "region" {
  type        = string
  description = "Primary deployment region"
  default     = "us-west-2"
}

variable "retention_logs_days" {
  type    = number
  default = 90
}

variable "retention_metrics_days" {
  type    = number
  default = 365
}

variable "retention_traces_days" {
  type    = number
  default = 30
}

variable "credit_quota_monthly" {
  type    = number
  default = 5000
}

# ==============================================================================
# DATABASES
# ==============================================================================

resource "snowflake_database" "observability" {
  name                        = "OBSERVABILITY_PLATFORM"
  data_retention_time_in_days = var.retention_logs_days
  comment                     = "Enterprise observability lakehouse - ${var.environment}"
}

# ==============================================================================
# SCHEMAS
# ==============================================================================

locals {
  schemas = ["RAW_TELEMETRY", "BRONZE", "SILVER", "GOLD", "AI_SRE", "GOVERNANCE", "CONTEXT_GRAPH", "ALERTING", "COST_OPS"]
}

resource "snowflake_schema" "schemas" {
  for_each = toset(local.schemas)
  database = snowflake_database.observability.name
  name     = each.value
  comment  = "Observability platform schema: ${each.value}"
}

# ==============================================================================
# WAREHOUSES
# ==============================================================================

resource "snowflake_warehouse" "ingest" {
  name                = "INGEST_WH"
  warehouse_size      = "MEDIUM"
  auto_suspend        = 60
  auto_resume         = true
  min_cluster_count   = 1
  max_cluster_count   = 4
  scaling_policy      = "STANDARD"
  comment             = "Telemetry ingestion workloads"
}

resource "snowflake_warehouse" "transform" {
  name                = "TRANSFORM_WH"
  warehouse_size      = "LARGE"
  auto_suspend        = 120
  auto_resume         = true
  min_cluster_count   = 1
  max_cluster_count   = 3
  scaling_policy      = "STANDARD"
  comment             = "Bronze-Silver-Gold transformations"
}

resource "snowflake_warehouse" "ai_sre" {
  name                = "AI_SRE_WH"
  warehouse_size      = "MEDIUM"
  auto_suspend        = 300
  auto_resume         = true
  min_cluster_count   = 1
  max_cluster_count   = 2
  scaling_policy      = "ECONOMY"
  comment             = "AI SRE inference and analysis"
}

resource "snowflake_warehouse" "dashboard" {
  name                = "DASHBOARD_WH"
  warehouse_size      = "SMALL"
  auto_suspend        = 60
  auto_resume         = true
  min_cluster_count   = 1
  max_cluster_count   = 2
  scaling_policy      = "STANDARD"
  comment             = "Streamlit dashboard queries"
}

# ==============================================================================
# ROLES & GRANTS
# ==============================================================================

resource "snowflake_role" "observability_admin" {
  name    = "OBSERVABILITY_ADMIN"
  comment = "Full admin for observability platform"
}

resource "snowflake_role" "observability_engineer" {
  name    = "OBSERVABILITY_ENGINEER"
  comment = "Engineer role for observability platform"
}

resource "snowflake_role" "observability_analyst" {
  name    = "OBSERVABILITY_ANALYST"
  comment = "Read/analyze observability data"
}

resource "snowflake_role" "observability_viewer" {
  name    = "OBSERVABILITY_VIEWER"
  comment = "View-only observability access"
}

resource "snowflake_role" "ai_sre_agent" {
  name    = "AI_SRE_AGENT"
  comment = "AI SRE automated agent role"
}

resource "snowflake_role" "telemetry_ingestor" {
  name    = "TELEMETRY_INGESTOR"
  comment = "Telemetry ingestion service account role"
}

resource "snowflake_role_grants" "hierarchy" {
  role_name = snowflake_role.observability_admin.name
  roles     = ["SYSADMIN"]
}

resource "snowflake_database_grant" "usage" {
  database_name = snowflake_database.observability.name
  privilege     = "USAGE"
  roles         = [
    snowflake_role.observability_admin.name,
    snowflake_role.observability_engineer.name,
    snowflake_role.observability_analyst.name,
    snowflake_role.observability_viewer.name,
  ]
}

# ==============================================================================
# RESOURCE MONITORS
# ==============================================================================

resource "snowflake_resource_monitor" "observability" {
  name            = "OBSERVABILITY_MONITOR"
  credit_quota    = var.credit_quota_monthly
  frequency       = "MONTHLY"
  start_timestamp = "IMMEDIATELY"

  notify_triggers = [75, 90]
  suspend_trigger = 100
}

# ==============================================================================
# NETWORK POLICIES (Zero Trust)
# ==============================================================================

resource "snowflake_network_policy" "observability_ingestion" {
  name            = "OBSERVABILITY_INGESTION_POLICY"
  allowed_ip_list = ["10.0.0.0/8", "172.16.0.0/12"]
  comment         = "Restrict ingestion to internal network CIDRs"
}

# ==============================================================================
# OUTPUTS
# ==============================================================================

output "database_name" {
  value = snowflake_database.observability.name
}

output "warehouse_names" {
  value = {
    ingest    = snowflake_warehouse.ingest.name
    transform = snowflake_warehouse.transform.name
    ai_sre    = snowflake_warehouse.ai_sre.name
    dashboard = snowflake_warehouse.dashboard.name
  }
}

output "role_names" {
  value = {
    admin    = snowflake_role.observability_admin.name
    engineer = snowflake_role.observability_engineer.name
    analyst  = snowflake_role.observability_analyst.name
    viewer   = snowflake_role.observability_viewer.name
    ai_agent = snowflake_role.ai_sre_agent.name
    ingestor = snowflake_role.telemetry_ingestor.name
  }
}
