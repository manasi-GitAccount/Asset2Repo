# Create DynamoDB Table
resource "aws_dynamodb_table" "file_processing_log" {
  name           = "FileProcessingLog"  # Table name

  # Define primary key
  hash_key       = "ProcessDate"        # Partition key (Primary Key)
  range_key      = "FileName"           # Sort key

  attribute {
    name = "ProcessDate"
    type = "S"  # Attribute type (S = String)
  }

  attribute {
    name = "FileName"
    type = "S"  # Attribute type (S = String)
  }

  # Provisioned throughput (default mode)
  read_capacity  = 5
  write_capacity = 5

}
