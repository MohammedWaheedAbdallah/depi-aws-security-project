resource "aws_iam_role" "backup_role" {
  name = "depi-sec-backup-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "backup.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "backup_attach" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore_attach" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_vault" "vault" {
  name = "depi-sec-vault"
}

resource "aws_backup_vault_lock_configuration" "vault_lock" {
  backup_vault_name  = aws_backup_vault.vault.name
  min_retention_days = 7
  max_retention_days = 365

  # Omitting changeable_for_days creates a Governance-mode lock on a new vault.
  # Ignore historical values if this module is used for a legacy deployment.
  lifecycle {
    ignore_changes = [changeable_for_days]
  }
}

resource "aws_backup_plan" "daily" {
  name = "depi-sec-daily-plan"
  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.vault.name
    schedule          = "cron(0 5 * * ? *)"
    start_window      = 60
    lifecycle {
      delete_after = 30
    }
  }
}

resource "aws_backup_selection" "all_resources" {
  count        = var.enable_scheduled_backups ? 1 : 0
  name         = "depi-sec-selection"
  plan_id      = aws_backup_plan.daily.id
  iam_role_arn = aws_iam_role.backup_role.arn
  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Project"
    value = var.project_name
  }
}
