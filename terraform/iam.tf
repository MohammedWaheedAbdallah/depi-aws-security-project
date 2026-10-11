resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length      = 14
  require_lowercase_characters = true
  require_uppercase_characters = true
  require_numbers              = true
  require_symbols              = true
  max_password_age             = 90
}

resource "aws_iam_group" "devs" { name = "depi-sec-developers" }
resource "aws_iam_group_policy_attachment" "devs_ro" {
  group      = aws_iam_group.devs.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_user" "dev1" { name = "depi-dev-1" }
resource "aws_iam_user_login_profile" "dev1_login" { user = aws_iam_user.dev1.name }
resource "aws_iam_user_group_membership" "dev1_grp" {
  user   = aws_iam_user.dev1.name
  groups = [aws_iam_group.devs.name]
}

resource "aws_iam_policy" "s3_app_read" {
  name = "depi-sec-s3-app-read"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "s3:GetObject", Resource = "${aws_s3_bucket.app_bucket.arn}/*" }]
  })
}

resource "aws_iam_role" "ec2_role" {
  name = "depi-sec-ec2-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy_attachment" "s3_read_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_app_read.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "depi-sec-ec2-profile"
  role = aws_iam_role.ec2_role.name
}