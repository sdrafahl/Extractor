variable "GlueCatalogDatabaseName" {
  type = string
  default = "demogluedatabase"
}

variable "CrawlerRole" {
  type = string
  default = "arn:aws:iam::061753407487:role/Glue"
}

variable "DynamoTableName" {
  type = string
}

variable "S3BucketName" {
  type = string
}

provider "aws" {
  region = "us-east-1"
  profile = "default"
}

resource "aws_glue_catalog_database" "aws_glue_catalog_database" {
  name = var.GlueCatalogDatabaseName
}






