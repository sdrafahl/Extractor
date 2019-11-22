import com.amazonaws.services.glue.GlueContext
import com.amazonaws.services.glue.MappingSpec
import com.amazonaws.services.glue.errors.CallSite
import com.amazonaws.services.glue.util.GlueArgParser
import com.amazonaws.services.glue.util.Job
import com.amazonaws.services.glue.util.JsonOptions
import org.apache.spark.SparkContext
import scala.collection.JavaConverters._
import org.apache.spark.sql._
import org.apache.spark.sql.types._
import com.amazonaws.services.glue._
import scala.sys.process._
import sys.process._

object GlueApp {
  def main(sysArgs: Array[String]) {
    val spark: SparkContext = new SparkContext()
    val glueContext: GlueContext = new GlueContext(spark)
    val args = GlueArgParser.getResolvedOptions(sysArgs, Seq("JOB_NAME").toArray)
    Job.init(args("JOB_NAME"), glueContext, args.asJava)
    val datasource0 = glueContext.getCatalogSource(database = "glue_database", tableName = "testavrodatasource", redshiftTmpDir = "", transformationContext = "datasource0").getDynamicFrame()
    val mapped = datasource0.map(GlueApp.mapFunction)
    val datasink = glueContext.getCatalogSink(database = "glue_database", tableName = "mapped_table", redshiftTmpDir = "", transformationContext = "datasink").writeDynamicFrame(mapped)
    Job.commit()
  }
  def mapFunction(dynamicRecord: com.amazonaws.services.glue.DynamicRecord): com.amazonaws.services.glue.DynamicRecord = {
        val a = dynamicRecord.getField("a").get
        val b = dynamicRecord.getField("b").get
        val c = dynamicRecord.getField("c").get
        val response = "Response"
        val row = Row(response, "testId")
        val schema = StructType(StructField("average", StringType, true) :: StructField("id", StringType, true) :: Nil)
	DynamicRecord(row, schema)
  }
}
