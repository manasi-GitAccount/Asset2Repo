# Create an S3 bucket with ACL enabled
resource "aws_s3_bucket" "example_bucket" {
  bucket = "mybucket637423220670"  # Change this to your bucket name
}

# Disable block public access settings selectively using a separate resource
resource "aws_s3_bucket_public_access_block" "example_bucket_public_access_block" {
  bucket = aws_s3_bucket.example_bucket.id

  block_public_acls   = false
  ignore_public_acls  = false
  block_public_policy = false
  restrict_public_buckets = false
}


# Bucket policy to allow public access to GetObject and PutObject
resource "aws_s3_bucket_policy" "public_policy" {
  bucket = aws_s3_bucket.example_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.example_bucket.arn}/*"
      }
    ]
  })
}

# Create input/ folder
resource "aws_s3_object" "input_folder" {
  bucket = aws_s3_bucket.example_bucket.bucket
  key    = "input/"  # S3 folder is just a key with a trailing slash
}

# Create output/ folder
resource "aws_s3_object" "output_folder" {
  bucket = aws_s3_bucket.example_bucket.bucket
  key    = "output/"  # S3 folder is just a key with a trailing slash
}

# Create query_results/ folder
resource "aws_s3_object" "query_results_folder" {
  bucket = aws_s3_bucket.example_bucket.bucket
  key = "query_results/"
}