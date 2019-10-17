variable "GlueCatalogDatabase" {
  type = string
  default = "extractorcatalogdb"
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

resource "aws_glue_crawler" "dynamo_crawler" {
  database_name = "${aws_glue_catalog_database.aws_glue_catalog_database.name}"
  name          = "crawler"
  role          = var.CrawlerRole

  dynamodb_target {
    path = var.DynamoTableName
  }
}

data "aws_glue_script" "scala_script" {
  language = "SCALA"

  dag_edge {
    source = "dynamo_catalog"
    target = "mapping"
  }

  dag_edge {
    source = "mapping"
    target = "selectfields"
  }

  dag_edge {
    source = "selectfields"
    target = "resolvechoice"
  }

  dag_edge {
    source = "resolvechoice"
    target = "datasink"
  }

  dag_node {
    id        = "dynamo_catalog"
    node_type = "DataSource"

    args {
      name  = "database"
      value = "\"${aws_glue_catalog_database.aws_glue_catalog_database.name}\""
    }

    args {
      name  = "table_name"
      value = "\"${aws_glue_catalog_table.aws_glue_catalog_table.name}\""
    }
  }

  dag_node {
    id        = "mapping"
    node_type = "ApplyMapping"

    args {
      name  = "mappings"
      value = "[(\"column1\", \"string\", \"column1\", \"string\")]"
    }
  }

  dag_node {
    id        = "selectfields"
    node_type = "SelectFields"

    args {
      name  = "paths"
      value = "[\"column1\"]"
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
      value = "\"${aws_glue_catalog_table.aws_glue_catalog_table.name}\""
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
      value = "\"${aws_glue_catalog_table.aws_glue_catalog_table.name}\""
    }
  }
}

output "scala_code" {
  value = "${data.aws_glue_script.scala_script}"
}




































 
