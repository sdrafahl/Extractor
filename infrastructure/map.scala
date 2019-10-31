def mapFunction(dynamicRecord: com.amazonaws.services.glue.DynamicRecord): com.amazonaws.services.glue.DynamicRecord = {
  println("######################################################################## here I go")
  val link = dynamicRecord.getField("link").get
  println(link)
  dynamicRecord
}
