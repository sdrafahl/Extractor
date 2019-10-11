variable "GlueCatalogDatabase" {
  type = string
  default = "ExtractorCatalogDB"
}

variable "CrawlerRole" {
  type = string
}

variable "DynamoTableName" {
  type = string
}

provider "aws" {
  region = "us-east-1"
  profile = "default"
}

resource "aws_glue_catalog_database" "aws_glue_catalog_database" {
  name = var.GlueCatalogDatabase
}

resource "aws_glue_catalog_table" "aws_glue_catalog_table" {
  name          = "ExtractorCatalogTable"
  database_name = var.GlueCatalogDatabase
}

resource "aws_glue_crawler" "example" {
  database_name = "${aws_glue_catalog_database.aws_glue_catalog_database.name}"
  name          = "crawler"
  role          = var.CrawlerRole

  dynamodb_target {
    path = var.DynamoTableName
  }
}



 
