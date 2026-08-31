# Remote state follows the same bootstrap boundary as Hisuiki: the bucket is created once outside
# this configuration because Terraform cannot safely describe the bucket holding its own state.
# Versioning makes an accidental or interrupted state write recoverable.

terraform {
  backend "gcs" {
    bucket = "cutedraw-tfstate-prod"
    prefix = "site"
  }
}
