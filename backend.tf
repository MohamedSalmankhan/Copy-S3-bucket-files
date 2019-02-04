terraform {
  backend "s3" {
    bucket = "tf-task-salman-ebiz"
    key    = "task5/tf-backend"
    region = "us-east-1"
  }
}
