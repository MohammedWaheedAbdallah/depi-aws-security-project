resource "aws_cloudfront_distribution" "cdn" {
  count   = var.enable_cloudfront ? 1 : 0
  enabled = true

  origin {
    domain_name = aws_lb.alb.dns_name
    origin_id   = aws_lb.alb.name

    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.cf_secret.result
    }

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = aws_lb.alb.name
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.logs_bucket.bucket_regional_domain_name
    prefix          = "cf-logs/"
  }
}

output "cloudfront_domain_name" {
  description = "HTTPS CloudFront domain when the distribution is enabled"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.cdn[0].domain_name : null
}
