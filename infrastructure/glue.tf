variable "GlueCatalogDatabase" {
  type = string
  default = "extractorcatalogdb"
}

variable "CrawlerRole" {
  type = string
  default = "arn:aws:iam::061753407487:role/Glue"
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

resource "aws_glue_catalog_database" "aws_glue_catalog_database_destination" {
  name = "aws_glue_catalog_database_destination"
}

resource "aws_glue_catalog_table" "aws_glue_catalog_table_destination" {
  name          = "ExtractorCatalogTable"
  database_name = aws_glue_catalog_database.aws_glue_catalog_database_destination.name
  table_type = "EXTERNAL_TABLE"
  description = "stuff"

  parameters = {
    EXTERNAL              = "TRUE"
    "parquet.compression" = "SNAPPY"
  }
  
  storage_descriptor {
    location      = "s3://shanesscaladag/stuff"
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
      name = "secondary"
      type = "string"
    }

    columns {
      name = "column2"
      type = "string"
    }
  }
  
}

resource "aws_glue_crawler" "dynamo_crawler" {
  database_name = "${aws_glue_catalog_database.aws_glue_catalog_database.name}"
  name          = "crawler"
  role          = var.CrawlerRole
  schedule      = "cron(15 12 * * ? *)"

  dynamodb_target {
    path = var.DynamoTableName
  }
}

data "aws_glue_script" "scala_script" {
  language = "SCALA"

  dag_edge {
    source = "datasource0"
    target = "applymapping1"
  }

  dag_edge {
    source = "applymapping1"
    target = "selectfields2"
  }

  dag_edge {
    source = "selectfields2"
    target = "resolvechoice4"
  }

  dag_edge {
    source = "resolvechoice4"
    target = "datasink5"
  }

  dag_node {
    id        = "datasource0"
    node_type = "DataSource"

    args {
      name  = "database"
      value = "\"${aws_glue_catalog_database.aws_glue_catalog_database.name}\""
    }

    args {
      name  = "table_name"
      value = "\"${var.DynamoTableName}\""
    }
  }

  dag_node {
    id        = "applymapping1"
    node_type = "ApplyMapping"

    args {
      name  = "mappings"
      value = "[(\"column1\", \"string\", \"secondary\", \"string\"), (\"column2\", \"string\", \"column2\", \"string\")]"
    }
  }

  dag_node {
    id        = "selectfields2"
    node_type = "SelectFields"

    args {
      name  = "paths"
      value = "[\"secondary\"]"
    }
  }


  dag_node {
    id        = "resolvechoice4"
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
      value = "\"dest\""
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
                "Name" :"glueetl",
                "GlueVersion": "1.0",
                "Command" : {
                  "Name":"glueetl",
                  "ScriptLocation": "s3://${aws_s3_bucket.scala_dag.bucket}/${aws_s3_bucket_object.file_upload.key}"
                },
                "Role" : "${var.CrawlerRole}",
                "DefaultArguments" : {
                  "--job-language": "scala"
                },
                "Description" : "Glue job"      
              }
           } 
         }
     }
STACK
}





































 
