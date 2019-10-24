variable "CrawlerRole" {
  type = string
  default = "arn:aws:iam::061753407487:role/Glue"
}

resource "aws_s3_bucket" "test_avro_data_source" {
  bucket = "testavrodatasource"
  acl    = "public-read-write"
}

resource "aws_s3_bucket_object" "file_upload_testdata" {
  bucket = "${aws_s3_bucket.test_avro_data_source.bucket}"
  key = "GenerateNewData"
  source = "${path.module}/../GenerateNewData/target/debug/GenerateNewData"
}

resource "aws_dynamodb_table" "test_avro_data_source_index" {
  name           = "testindex"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "id"
  range_key      = "s3location"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "s3location"
    type = "S"
  }
  
  ttl {
    attribute_name = "TimeToExist"
    enabled        = false
  }
}


resource "aws_dynamodb_table_item" "example" {
  table_name = "${aws_dynamodb_table.test_avro_data_source_index.name}"
  hash_key   = "${aws_dynamodb_table.test_avro_data_source_index.hash_key}"

  item = <<ITEM
{
  "id": {"S": "1"},
  "s3location": {"S": ${aws_s3_bucket_object.file_upload.key}"}
}
ITEM
}

variable "GlueCatalogDatabaseName" {
  type = string
  default = "demogluedatabase"
}

variable "CrawlerRole" {
  type = string
  default = "arn:aws:iam::061753407487:role/Glue"
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

resource "aws_glue_crawler" "dynamo_crawler" {
  database_name = "${aws_dynamodb_table.test_avro_data_source_index.name}"
  name          = "dynamoCrawler"
  role          = var.CrawlerRole
  schedule      = "cron(15 12 * * ? *)"

  dynamodb_target {
    path = var.DynamoTableName
  }
}

resource "aws_glue_crawler" "example" {
  database_name = "${aws_dynamodb_table.test_avro_data_source_index.name}"
  name          = "s3Crawler"
  role          = var.CrawlerRole

  s3_target {
    path = "s3://${aws_s3_bucket.test_avro_data_source}/${aws_s3_bucket_object.file_upload.key}"
  }
}

data "aws_glue_script" "scala_script" {
  language = "SCALA"

  dag_node {
    id        = "datasourceDynamo"
    node_type = "DataSource"

    args {
      name  = "database"
      value = "\"${aws_glue_catalog_database.aws_glue_catalog_database.name}\""
    }

    args {
      name  = "table_name"
      value = "\"${aws_dynamodb_table.test_avro_data_source_index.name}\""
    }
  }

  dag_node {
    id        = "datasourceS3"
    node_type = "DataSource"

    args {
      name  = "database"
      value = "\"${aws_glue_catalog_database.aws_glue_catalog_database.name}\""
    }

    args {
      name  = "table_name"
      value = "\"${aws_s3_bucket.test_avro_data_source.bucket}\""
    }
  }

  dag_node {
    id        = "joinDynamoAndS3"
    node_type = "Join"

    args {
      name  = "frame1"
      value = "datasourceS3"
    }

    args {
      name  = "frame2"
      value = "datasourceDynamo"
    }

    args {
      name  = "keys1"
      value = "[\"${aws_s3_bucket_object.file_upload_testdata.key}\"]"
    }

    args {
      name = "keys2"
      value = "[\"${aws_dynamodb_table.test_avro_data_source_index.hash_key}\", \"${aws_dynamodb_table.test_avro_data_source_index.range_key}\"]"
    }
  }
  
  dag_node {
    id        = "resolvechoice"
    node_type = "ResolveChoice"

    args {
      name  = "choice"
      value = "\"MATCH_CATALOG\""
    }

    args {
      name  = "database"
      value = "\"${aws_glue_catalog_database.aws_glue_catalog_database_destination.name}\""
    }

    args {
      name  = "table_name"
      value = "\"dest\""
    }
  }

  dag_node {
    id        = "datasink5"
    node_type = "DataSink"

    args {
      name  = "database"
      value = "\"${aws_glue_catalog_database.aws_glue_catalog_database_destination.name}\""
    }

    args {
      name  = "table_name"
      value = "\"${aws_glue_catalog_table.aws_glue_catalog_table_destination.name}\""
    }
  }
}

resource "aws_s3_bucket" "scala_dag" {
  bucket = "shanesscaladag"
  acl    = "public-read-write"
}

resource "local_file" "scala_code" {
  content  = "${data.aws_glue_script.scala_script.scala_code}"
  filename = "${path.module}/scalaCode.scala"
}

resource "aws_s3_bucket_object" "file_upload" {
  bucket = "${aws_s3_bucket.scala_dag.bucket}"
  key = "transform.scala"
  source = "${local_file.scala_code.filename}"
}


