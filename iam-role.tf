# Create IAM Role for AWS Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_access_role"  # Replace with your desired role name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the DynamoDB Full Access Policy to the Role
resource "aws_iam_policy_attachment" "dynamodb_full_access_attachment" {
  name       = "dynamodb_full_access_attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Attach the S3 Full Access Policy to the Role
resource "aws_iam_policy_attachment" "s3_full_access_attachment" {
  name       = "s3_full_access_attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Attach the CloudWatch Logs Full Access Policy to the Role
resource "aws_iam_policy_attachment" "cloudwatch_logs_full_access_attachment" {
  name       = "cloudwatch_logs_full_access_attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}
