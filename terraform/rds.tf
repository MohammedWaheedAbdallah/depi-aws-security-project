resource "aws_db_subnet_group" "db_subnet" {
  name       = "depi-sec-db-subnet"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "random_password" "db_pass" {
  length           = 16
  special          = true
  override_special = "_%*"
}

resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "depi-sec-db-password-v2-${random_id.s3_suffix.hex}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_secret_val" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = random_password.db_pass.result
}

resource "aws_db_instance" "mysql" {
  identifier             = "depi-sec-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp3"
  username               = "admin"
  password               = random_password.db_pass.result
  db_subnet_group_name   = aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false
  storage_encrypted      = true
  skip_final_snapshot    = true
  deletion_protection    = false
}
