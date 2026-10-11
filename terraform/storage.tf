resource "random_id" "s3_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "app_bucket" {
  bucket = "depi-sec-app-${random_id.s3_suffix.hex}"
}

resource "aws_s3_bucket" "logs_bucket" {
  bucket = "depi-sec-logs-${random_id.s3_suffix.hex}"
}

resource "aws_s3_bucket_ownership_controls" "logs_ownership" {
  bucket = aws_s3_bucket.logs_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logs_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.logs_ownership]
  bucket     = aws_s3_bucket.logs_bucket.id
  acl        = "log-delivery-write"
}

resource "aws_s3_bucket_public_access_block" "app_pab" {
  bucket                  = aws_s3_bucket.app_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "logs_pab" {
  bucket                  = aws_s3_bucket.logs_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "app_ver" {
  bucket = aws_s3_bucket.app_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "logs_ver" {
  bucket = aws_s3_bucket.logs_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_enc" {
  bucket = aws_s3_bucket.app_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs_enc" {
  bucket = aws_s3_bucket.logs_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "app_policy" {
  bucket = aws_s3_bucket.app_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.app_bucket.arn, "${aws_s3_bucket.app_bucket.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

resource "aws_s3_bucket_policy" "logs_policy" {
  bucket = aws_s3_bucket.logs_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.logs_bucket.arn, "${aws_s3_bucket.logs_bucket.arn}/*"],
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Effect = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" }, Action = "s3:GetBucketAcl", Resource = aws_s3_bucket.logs_bucket.arn
      },
      {
        Effect    = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" }, Action = "s3:PutObject", Resource = "${aws_s3_bucket.logs_bucket.arn}/AWSLogs/*",
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      },
      {
        Effect    = "Allow", Principal = { Service = "delivery.logs.amazonaws.com" }, Action = "s3:GetBucketAcl", Resource = aws_s3_bucket.logs_bucket.arn,
        Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
      },
      {
        Effect    = "Allow", Principal = { Service = "delivery.logs.amazonaws.com" }, Action = "s3:PutObject", Resource = "${aws_s3_bucket.logs_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id, "s3:x-amz-acl" = "bucket-owner-full-control" } }
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "app_lc" {
  bucket = aws_s3_bucket.app_bucket.id
  rule {
    id     = "archive"
    status = "Enabled"
    filter {}
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }
    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs_lc" {
  bucket = aws_s3_bucket.logs_bucket.id
  rule {
    id     = "archive"
    status = "Enabled"
    filter {}
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }
    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

resource "aws_efs_file_system" "shared" {
  encrypted = true
  tags      = { Name = "depi-sec-efs" }
}

resource "aws_efs_mount_target" "mt_a" {
  file_system_id  = aws_efs_file_system.shared.id
  subnet_id       = aws_subnet.private_a.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "mt_b" {
  file_system_id  = aws_efs_file_system.shared.id
  subnet_id       = aws_subnet.private_b.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_access_point" "ap" {
  file_system_id = aws_efs_file_system.shared.id
  posix_user {
    gid = 1000
    uid = 1000
  }
  root_directory {
    path = "/app-data"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }
}
