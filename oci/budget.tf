# 1. Define the Budget at the root level of your subscription
resource "oci_budget_budget" "free_tier_guard" {
  compartment_id = var.tenancy_ocid # Budgets for the whole account must be in the Root Compartment
  amount         = 1                # Budget target: 1 USD / 1 EUR
  reset_period   = "MONTHLY"
  targets        = [var.tenancy_ocid]

  display_name = "free-tier-guard"
  description  = "Alert guard to ensure infrastructure stays within the Always Free tier limits."
}

# 2. Alert Rule: Forecasted Spend (Preventative)
resource "oci_budget_alert_rule" "forecast_alert" {
  budget_id      = oci_budget_budget.free_tier_guard.id
  threshold      = 100 # 100% of the $1 amount (triggers if the system predicts you will reach $1)
  threshold_type = "PERCENTAGE"
  type           = "FORECAST" # Evaluates predicted spending by the end of the month

  recipients = var.notification_email # Replace with your actual email address
  message    = "OCI WARNING: Algorithmic forecast predicts you will exceed the free tier budget this month!"
}

# 3. Alert Rule: Actual Spend (Immediate Reaction)
resource "oci_budget_alert_rule" "actual_alert" {
  budget_id      = oci_budget_budget.free_tier_guard.id
  threshold      = 50 # 50% of the $1 amount (triggers as soon as you are billed the first $0.50)
  threshold_type = "PERCENTAGE"
  type           = "ACTUAL" # Evaluates real-time billed charges

  recipients = var.notification_email # Replace with your actual email address
  message    = "OCI ALERT: Real charges have been detected on your account! Inspect your resources immediately."
}
