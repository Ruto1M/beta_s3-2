terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
module "template_files" {
  source = "hashicorp/dir/template"
  base_dir = "${path.module}/website"
}

resource "aws_s3_bucket" "host_bucket" {
  bucket = var.bucket_name
}

# resource "aws_s3_bucket_acl" "host_acl" {
#   bucket = aws_s3_bucket.host_bucket.id
#   acl = "public-read"
# }
resource "aws_s3_bucket_public_access_block" "s3_public_block" {
  bucket= aws_s3_bucket.host_bucket.id

  block_public_acls = false
  block_public_policy = false
  ignore_public_acls = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "host_policy" {
  bucket = aws_s3_bucket.host_bucket.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.host_bucket.arn}/*"
      }
    ]
  })
  depends_on = [
  aws_s3_bucket_policy.host_policy,
  aws_s3_bucket_ownership_controls.s3_ownership_controls,
  aws_s3_bucket_website_configuration.host_website,
  aws_s3_object.host_files_html ]
}

resource "aws_s3_bucket_ownership_controls" "s3_ownership_controls" {
  bucket = aws_s3_bucket.host_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
  
}
resource "aws_s3_bucket_website_configuration" "host_website" {
  bucket = aws_s3_bucket.host_bucket.id

  index_document {
    suffix = "index.html"
  }
}
resource "aws_s3_object" "host_files_html" {
  bucket = aws_s3_bucket.host_bucket.id

  for_each = module.template_files.files
  key = each.key
  content_type = each.value.content_type

  source = each.value.source_path
  content = each.value.content

  etag = each.value.digests.md5
}