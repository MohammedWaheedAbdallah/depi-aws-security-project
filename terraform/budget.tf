resource "aws_iam_policy" "deny_expensive" {
  name = "depi-sec-deny-expensive"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Deny", Action = ["ec2:RunInstances", "rds:CreateDBInstance"], Resource = "*" }]
  })
}

resource "aws_iam_role" "budget_role" {
  name = "depi-sec-budget-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "budgets.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "budget_deny" {
  role       = aws_iam_role.budget_role.name
  policy_arn = aws_iam_policy.deny_expensive.arn
}

resource "aws_iam_role_policy" "budget_action" {
  name = "depi-sec-budget-action"
  role = aws_iam_role.budget_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["iam:AttachGroupPolicy"]
      Resource = aws_iam_group.devs.arn
    }]
  })
}

resource "aws_budgets_budget" "budget" {
  name         = "depi-sec-monthly"
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 90
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}

resource "aws_budgets_budget_action" "deny_action" {
  budget_name        = aws_budgets_budget.budget.name
  action_type        = "APPLY_IAM_POLICY"
  approval_model     = "AUTOMATIC"
  execution_role_arn = aws_iam_role.budget_role.arn
  notification_type  = "ACTUAL"

  subscriber {
    address           = var.alert_email
    subscription_type = "EMAIL"
  }

  action_threshold {
    action_threshold_type  = "PERCENTAGE"
    action_threshold_value = 90
  }

  definition {
    iam_action_definition {
      policy_arn = aws_iam_policy.deny_expensive.arn
      groups     = [aws_iam_group.devs.name]
    }
  }
}
