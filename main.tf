provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "s3_source_bucket" {
  bucket = "${var.source_bucket}"
  acl = "private"
  tags {
    Environment="s3"
    name="my_source_bucket"
  }
}
resource "aws_s3_bucket" "s3_dest_bucket" {
  bucket = "${var.dest_bucket}"
  acl = "private"
  tags {
    Environment="s3"
    name="my_dest_bucket"
  }
}
resource "aws_s3_bucket" "s3_log_bucket" {
  bucket = "${var.cloudtrail_bucket}"
  acl = "private"
  force_destroy = "true"
  tags {
    Name = "log_storage"
  }

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Effect": "Allow",
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${var.cloudtrail_bucket}"
        },
        {
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Effect": "Allow",
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${var.cloudtrail_bucket}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY
}

resource "aws_cloudtrail" "terra_cloudtrail" {
  name = "s3-source-bucket-log"
  s3_bucket_name = "${aws_s3_bucket.s3_log_bucket.id}"
  include_global_service_events = "false"

  event_selector {
    read_write_type = "All"
    include_management_events = true

    data_resource {
      type = "AWS::S3::Object"
      values = ["${aws_s3_bucket.s3_source_bucket.arn}/"]
    }
  }
}

resource "aws_cloudwatch_event_rule" "CW_event" {
  name        = "capture-source-bucket"
  is_enabled = "true"
  description = "Cloudtrail to cloudevent"

  event_pattern = <<PATTERN
  {
    "source": [
      "aws.s3"
    ],
    "detail-type": [
      "AWS API Call via CloudTrail"
    ],
    "detail": {
      "eventSource": [
        "s3.amazonaws.com"
    ],
    "eventName": [
      "PutObject"
    ],
    "requestParameters": {
      "bucketName": [
        "${var.source_bucket}"
      ]
    }
  }
  }
PATTERN
}
resource "aws_cloudwatch_event_target" "cloudevent_lambda" {
  arn = "${aws_lambda_function.lambda_func.arn}"
  rule = "${aws_cloudwatch_event_rule.CW_event.name}"
}

resource "aws_iam_role_policy" "s3_policy_role" {
  role = "${aws_iam_role.lambda_role.id}"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
POLICY
}
resource "aws_iam_role" "lambda_role" {
  name = "lambda-s3-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_lambda_function" "lambda_func" {
  function_name = "lambda-To-s3"
  filename = "lambda_function_s3.zip"
  handler = "test_py.sample"
  role = "${aws_iam_role.lambda_role.arn}"
  source_code_hash = "${base64sha256(file("lambda_function_s3.zip"))}"
  runtime = "python2.7"
  memory_size = 128
  publish = "false"
}
resource "aws_lambda_permission" "lambda_access" {
  statement_id  = "AllowCloudEventInvokeLambda"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda_func.arn}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.CW_event.arn}"
}
