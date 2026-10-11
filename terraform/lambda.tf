resource "aws_iam_role" "lambda_role" {
  name = "depi-sec-lambda-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["ec2:DescribeSecurityGroups", "ec2:RevokeSecurityGroupIngress", "sns:Publish", "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*" }]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/remediation.py"
  output_path = "${path.root}/lambda_function.zip"
}

resource "aws_lambda_function" "remediator" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "depi-sec-sg-remediation"
  role             = aws_iam_role.lambda_role.arn
  handler          = "remediation.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }
}

resource "aws_cloudwatch_event_rule" "sg_change" {
  name = "depi-sec-sg-rule"
  event_pattern = jsonencode({
    source        = ["aws.ec2"]
    "detail-type" = ["AWS API Call via CloudTrail"]
    detail        = { eventSource = ["ec2.amazonaws.com"], eventName = ["AuthorizeSecurityGroupIngress"] }
  })
}

resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.sg_change.name
  target_id = "RemediateSG"
  arn       = aws_lambda_function.remediator.arn
}

resource "aws_lambda_permission" "allow_eb" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sg_change.arn
}
