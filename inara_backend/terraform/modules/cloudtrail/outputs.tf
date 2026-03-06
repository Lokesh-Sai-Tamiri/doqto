output "trail_arn" {
  value = aws_cloudtrail.main.arn
}

output "trail_bucket" {
  value = aws_s3_bucket.trail.bucket
}
