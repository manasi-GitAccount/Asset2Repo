data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function_payload.zip"

  source {
    content  = <<EOF
import boto3
import time
import csv
import fastavro
from io import StringIO, BytesIO
from decimal import Decimal
import io

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

def convert_to_decimal(value):
    if isinstance(value, float):
        return Decimal(str(value))
    return value

def generate_report_and_save(process_date, bucket_name, object_key, target_key, record_count, run_duration):
    report_key = f'reports/{process_date}_report.csv'
    try:
        existing_report = s3.get_object(Bucket=bucket_name, Key=report_key)
        existing_csv = io.StringIO(existing_report['Body'].read().decode('utf-8'))
        existing_rows = list(csv.reader(existing_csv))
    except s3.exceptions.ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchKey':
            existing_rows = []
        else:
            raise e

    new_csv = io.StringIO()
    csv_writer = csv.writer(new_csv, quoting=csv.QUOTE_MINIMAL)
    if not existing_rows:
        csv_writer.writerow(['ProcessDate', 'FileName', 'SourcePath', 'TargetPath', 'RecordCount', 'RunDuration (seconds)'])

    csv_writer.writerow([process_date, object_key, f's3://{bucket_name}/{object_key}', f's3://{bucket_name}/{target_key}', record_count, run_duration])

    combined_csv = io.StringIO()
    combined_csv_writer = csv.writer(combined_csv, quoting=csv.QUOTE_MINIMAL)
    combined_csv_writer.writerows(existing_rows)
    combined_csv_writer.writerows(csv.reader(new_csv.getvalue().splitlines()))

    s3.put_object(Bucket=bucket_name, Key=report_key, Body=combined_csv.getvalue())

def lambda_handler(event, context):
    start_time = time.time()
    if 'Records' not in event:
        raise KeyError("'Records' key not found in the event")
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']
    process_date = time.strftime('%Y-%m-%d')

    try:
        avro_obj = s3.get_object(Bucket=bucket_name, Key=object_key)
        avro_body = avro_obj['Body'].read()
        avro_file = BytesIO(avro_body)
        reader = fastavro.reader(avro_file)
        
        csv_content = []
        for record in reader:
            converted_record = {k: convert_to_decimal(v) for k, v in record.items()}
            csv_content.append(converted_record)

        if not csv_content:
            raise ValueError("CSV content is empty")
        
        fieldnames = csv_content[0].keys() if csv_content else []
        csv_output = StringIO()
        csv_writer = csv.DictWriter(csv_output, fieldnames=fieldnames, quoting=csv.QUOTE_MINIMAL)
        csv_writer.writeheader()
        csv_writer.writerows(csv_content)
        csv_output.seek(0)

        target_key = object_key.replace('input/', 'output/').replace('.avro', '.csv')
        s3.put_object(Bucket=bucket_name, Key=target_key, Body=csv_output.getvalue())
        
        run_duration = Decimal(str(time.time() - start_time))
        record_count = len(csv_content)

        table = dynamodb.Table('FileProcessingLog')
        table.put_item(
            Item={
                'ProcessDate': process_date,
                'FileName': object_key,
                'SourcePath': f's3://{bucket_name}/{object_key}',
                'TargetPath': f's3://{bucket_name}/{target_key}',
                'RunDuration': run_duration,
                'RecordCount': Decimal(str(record_count))
            }
        )

        generate_report_and_save(process_date, bucket_name, object_key, target_key, record_count, run_duration)

        return {
            'statusCode': 200,
            'body': f'Successfully processed {object_key} and saved as {target_key}'
        }

    except Exception as e:
        raise e
EOF
    filename = "${path.module}/lambda_function.py"
  }
}

resource "aws_lambda_function" "example_lambda" {
  function_name = "myFunction"
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  architectures = ["x86_64"]

  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)

  layers = [aws_lambda_layer_version.python_layer.arn]  # Add the layer reference
}

# Add the Lambda function as a trigger for S3 events (e.g., object creation in input/)
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.example_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.example_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "input/"  # Only trigger on objects within the input/ folder
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# Permission to allow S3 to invoke the Lambda function
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.example_bucket.arn
}

resource "aws_lambda_layer_version" "python_layer" {
  filename         = "C:/Users/manasi.lenka/test_env/lambda-layer-fastavro/python.zip"  # Replace with the path to your zip file on your machine
  layer_name       = "python-dependencies-layer"
  compatible_runtimes = ["python3.8", "python3.9", "python3.10", "python3.11", "python3.12"]
  description      = "Layer for Python dependencies"
}