output "source-s3-arn" {
  value = "${aws_s3_bucket.s3_source_bucket.arn}"
}
output "dest-s3-arn" {
  value = "${aws_s3_bucket.s3_dest_bucket.arn}"
}
output "lambda-arn" {
  value = "${aws_lambda_function.lambda_func.arn}"
}