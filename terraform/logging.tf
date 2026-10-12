data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "trail_logs" {
  name              = "/depi-sec/cloudtrail"
  retention_in_days = 14
}

resource "aws_iam_role" "trail_role" {
  name = "depi-sec-trail-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "trail_policy" {
  name = "depi-sec-trail-policy"
  role = aws_iam_role.trail_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.trail_logs.arn}:*"
    }]
  })
}

resource "aws_cloudtrail" "trail" {
  name                       = "depi-sec-trail"
  s3_bucket_name             = aws_s3_bucket.logs_bucket.id
  enable_log_file_validation = true
  is_multi_region_trail      = true
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.trail_logs.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.trail_role.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.app_bucket.arn}/"]
    }
  }

  depends_on = [aws_s3_bucket_policy.logs_policy]
}

resource "aws_cloudwatch_log_group" "vpc_flowlogs" {
  name              = "/depi-sec/vpc/flowlogs"
  retention_in_days = 14
}

resource "aws_iam_role" "flowlogs_role" {
  name = "depi-sec-flowlogs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flowlogs_policy" {
  name = "depi-sec-flowlogs-policy"
  role = aws_iam_role.flowlogs_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "vpc_flow" {
  vpc_id                   = aws_vpc.app_vpc.id
  traffic_type             = "ALL"
  log_destination          = aws_cloudwatch_log_group.vpc_flowlogs.arn
  log_destination_type     = "cloud-watch-logs"
  iam_role_arn             = aws_iam_role.flowlogs_role.arn
  max_aggregation_interval = 60
}

resource "aws_sns_topic" "alerts" {
  name = "depi-sec-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "cpu_a" {
  alarm_name          = "depi-sec-cpu-app-a"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions          = { InstanceId = aws_instance.app_a.id }
}

resource "aws_cloudwatch_metric_alarm" "cpu_b" {
  alarm_name          = "depi-sec-cpu-app-b"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions          = { InstanceId = aws_instance.app_b.id }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy" {
  alarm_name          = "depi-sec-alb-unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    LoadBalancer = aws_lb.alb.arn_suffix
    TargetGroup  = aws_lb_target_group.app_tg.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "depi-sec-rds-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 2000000000
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions          = { DBInstanceIdentifier = aws_db_instance.mysql.identifier }
}

resource "aws_cloudwatch_log_metric_filter" "failed_login" {
  name           = "failed-console-login"
  pattern        = "{ $.eventName = \"ConsoleLogin\" && $.errorMessage = \"Failed authentication\" }"
  log_group_name = aws_cloudwatch_log_group.trail_logs.name

  metric_transformation {
    name      = "FailedLoginCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "login_alarm" {
  alarm_name          = "depi-sec-failed-login"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.failed_login.metric_transformation[0].name
  namespace           = "CloudTrailMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "depi-sec-overview"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6,
        properties = {
          metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.app_a.id], ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.app_b.id]]
          view    = "timeSeries", stacked = false, region = var.region, title = "EC2 CPU"
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6,
        properties = {
          metrics = [["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", aws_lb.alb.arn_suffix, "TargetGroup", aws_lb_target_group.app_tg.arn_suffix]]
          view    = "timeSeries", stacked = false, region = var.region, title = "ALB unhealthy hosts"
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6,
        properties = {
          metrics = [["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.mysql.identifier]]
          view    = "timeSeries", stacked = false, region = var.region, title = "RDS free storage"
        }
      },
      {
        type = "metric", x = 0, y = 18, width = 12, height = 6,
        properties = {
          metrics = [["CloudTrailMetrics", "FailedLoginCount"]]
          view    = "timeSeries", stacked = false, region = var.region, title = "Failed console logins"
        }
      }
    ]
  })
}
