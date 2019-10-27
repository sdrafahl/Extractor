import com.amazonaws.services.glue.ChoiceOption
import com.amazonaws.services.glue.GlueContext
import com.amazonaws.services.glue.MappingSpec
import com.amazonaws.services.glue.ResolveSpec
import com.amazonaws.services.glue.errors.CallSite
import com.amazonaws.services.glue.util.GlueArgParser
import com.amazonaws.services.glue.util.Job
import com.amazonaws.services.glue.util.JsonOptions
import org.apache.spark.SparkContext
import scala.collection.JavaConverters._

object GlueApp {
  def main(sysArgs: Array[String]) {
    val spark: SparkContext = new SparkContext()
    val glueContext: GlueContext = new GlueContext(spark)
    // @params: [JOB_NAME]
    val args = GlueArgParser.getResolvedOptions(sysArgs, Seq("JOB_NAME").toArray)
    Job.init(args("JOB_NAME"), glueContext, args.asJava)
    // @type: DataSource
    // @args: [database = "extractorcatalogdb", table_name = "testtable", transformation_ctx = "datasource0"]
    // @return: datasource0
    // @inputs: []
    val datasource0 = glueContext.getCatalogSource(database = "extractorcatalogdb", tableName = "testtable", redshiftTmpDir = "", transformationContext = "datasource0").getDynamicFrame()
    // @type: ApplyMapping
    // @args: [mappings = [("column1", "string", "secondary", "string"), ("column2", "string", "column2", "string")], transformation_ctx = "applymapping1"]
    // @return: applymapping1
    // @inputs: [frame = datasource0]
    val applymapping1 = datasource0.applyMapping(mappings = Seq(("column1", "string", "secondary", "string"), ("column2", "string", "column2", "string")), caseSensitive = false, transformationContext = "applymapping1")
    // @type: SelectFields
    // @args: [paths = ["secondary"], transformation_ctx = "selectfields2"]
    // @return: selectfields2
    // @inputs: [frame = applymapping1]
    val selectfields2 = applymapping1.selectFields(paths = Seq("secondary"), transformationContext = "selectfields2")
    // @type: ResolveChoice
    // @args: [database = "aws_glue_catalog_database_destination", choice = "MATCH_CATALOG", table_name = "dest", transformation_ctx = "resolvechoice4"]
    // @return: resolvechoice4
    // @inputs: [frame = selectfields2]
    val resolvechoice4 = selectfields2.resolveChoice(choiceOption = Some(ChoiceOption("MATCH_CATALOG")), database = Some("aws_glue_catalog_database_destination"), tableName = Some("dest"), transformationContext = "resolvechoice4")
    // @type: DataSink
    // @args: [database = "aws_glue_catalog_database_destination", table_name = "dest", transformation_ctx = "datasink5"]
    // @return: datasink5
    // @inputs: [frame = resolvechoice4]
    val datasink5 = glueContext.getCatalogSink(database = "aws_glue_catalog_database_destination", tableName = "dest", redshiftTmpDir = "", transformationContext = "datasink5").writeDynamicFrame(resolvechoice4)
    Job.commit()
  }
}