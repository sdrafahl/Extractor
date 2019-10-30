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
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "id"

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

variable "GlueCatalogDatabaseName" {
  type = string
  default = "glue_database"
}

variable "CrawlerRole" {
  type = string
  default = "arn:aws:iam::061753407487:role/Glue"
}

provider "aws" {
  region = "us-east-1"
  profile = "default"
  max_retries = 1
}

resource "aws_glue_catalog_database" "aws_glue_catalog_database" {
  name = var.GlueCatalogDatabaseName
}

resource "aws_glue_crawler" "s3_crawler" {
  database_name = "${aws_dynamodb_table.test_avro_data_source_index.name}"
  name          = "s3Crawler"
  role          = var.CrawlerRole

  s3_target {
    path = "s3://${aws_s3_bucket.test_avro_data_source.bucket}/${aws_s3_bucket_object.file_upload.key}"
  }
}

resource "aws_glue_crawler" "dynamo_crawler" {
  database_name = "${aws_dynamodb_table.test_avro_data_source_index.name}"
  name          = "dynamoCrawler"
  role          = var.CrawlerRole
  schedule      = "cron(15 12 * * ? *)"

  dynamodb_target {
    path = aws_dynamodb_table.test_avro_data_source_index.name
  }
}

resource "aws_glue_catalog_table" "aws_glue_catalog_table_merged" {
  name          = "merged_table"
  database_name = aws_glue_catalog_database.aws_glue_catalog_database.name
  table_type = "EXTERNAL_TABLE"
  description = "table used to store the joined data"

  parameters = {
    EXTERNAL              = "TRUE"
    "parquet.compression" = "SNAPPY"
  }
  
  storage_descriptor {
    location      = "s3://${aws_s3_bucket.scala_dag.bucket}/mergedTable"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    
    ser_de_info {
      name                  = "my-stream"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = 1
      }
    }

    columns {
      name = "\"${aws_dynamodb_table.test_avro_data_source_index.hash_key}\""
      type = "string"
    }

    columns {
      name = "\"${aws_dynamodb_table.test_avro_data_source_index.range_key}\""
      type = "string"
    }
  }
}

data "aws_glue_script" "scala_script" {
  language = "SCALA"

  dag_edge {
    source = "datasource_dynamo"
    target = "joinDynamoAndS3"
  }

  dag_edge {
    source = "datasourceS3"
    target = "joinDynamoAndS3"
  }

  dag_edge {
    source = "joinDynamoAndS3"
    target = "resolvechoice"
  }

  dag_edge {
    source = "resolvechoice"
    target = "datasink"
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
    id        = "linkLookup"
    node_type = "Map"

    args {
      name  = "frame"
      value = "\"datasources3\""
    }

    args {
      name  = "f"
      value = "\"${file("${path.module}/map.scala")}\""
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
      value = "[\"${aws_dynamodb_table.test_avro_data_source_index.hash_key}\", \"s3location\"]"
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
      value = "\"${aws_glue_catalog_database.aws_glue_catalog_database.name}\""
    }

    args {
      name  = "table_name"
      value = "\"${aws_glue_catalog_table.aws_glue_catalog_table_merged.name}\""
    }
  }

  dag_node {
    id        = "datasink"
    node_type = "DataSink"

    args {
      name  = "database"
      value = "\"${aws_glue_catalog_database.aws_glue_catalog_database.name}\""
    }

    args {
      name  = "table_name"
      value = "\"${aws_glue_catalog_table.aws_glue_catalog_table_merged.name}\""
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

resource "aws_cloudformation_stack" "glue_job_stack" {
  name = "glue-job-stack"

  template_body = <<STACK
     {
       "Resources": {
          "GlueJob": {
            "Type" : "AWS::Glue::Job",
            "Properties" : {
                "Name" :"joinData",
                "GlueVersion": "1.0",
                "Command" : {
                  "Name":"glueetl",
                  "ScriptLocation": "s3://${aws_s3_bucket.scala_dag.bucket}/${aws_s3_bucket_object.file_upload.key}"
                },
                "Role" : "${var.CrawlerRole}",
                "DefaultArguments" : {
                  "--job-language": "scala",
                  "--class": "GlueApp"
                },
                "Description" : "Glue job"      
              }
           } 
         }
     }
STACK
}

