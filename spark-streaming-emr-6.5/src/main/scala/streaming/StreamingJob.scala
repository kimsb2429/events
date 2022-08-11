package weclouddata.streaming

import weclouddata.wrapper.SparkSessionWrapper
import org.apache.spark.sql.execution.datasources.jdbc.JDBCOptions
import org.apache.spark.sql.{DataFrame, SaveMode, SparkSession}
import org.apache.spark.sql.functions._
import org.apache.spark.sql.types.StructType
import org.apache.spark.sql.SaveMode

object StreamingJob extends App with SparkSessionWrapper {  
  def get_schema(path_schema_seed: String) = {
    val df = spark.read.json(path_schema_seed)
    df.schema
  }

  val kafkaReaderConfig = KafkaReaderConfig("b-3.wcdmsk.i8iu17.c25.kafka.us-east-1.amazonaws.com:9092,b-1.wcdmsk.i8iu17.c25.kafka.us-east-1.amazonaws.com:9092,b-2.wcdmsk.i8iu17.c25.kafka.us-east-1.amazonaws.com:9092", "dbserver1.tweetdata.tweets")
  val schemas  = get_schema("s3://tweetevents/tweetdata.json")
  new StreamingJobExecutor(spark, kafkaReaderConfig, "s3://tweetevents/checkpoint/job", schemas).execute()
}

case class KafkaReaderConfig(kafkaBootstrapServers: String, topics: String, startingOffsets: String = "latest")

class StreamingJobExecutor(spark: SparkSession, kafkaReaderConfig: KafkaReaderConfig, checkpointLocation: String, schema: StructType) {
  import spark.implicits._

  def read(): DataFrame = {
    spark
      .readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", kafkaReaderConfig.kafkaBootstrapServers)
      .option("subscribe", kafkaReaderConfig.topics)
      .option("startingOffsets", kafkaReaderConfig.startingOffsets)
      .load()
  }

  def execute(): Unit = {
    // read data from kafka and parse them
    val transformDF = read().select(from_json($"value".cast("string"), schema).as("value"))
    val tableName = "tweet_events_emr_6_5"

    transformDF.select($"value.payload.after.*")
                .writeStream
                .option("checkpointLocation", checkpointLocation) 
                .queryName("tweet events streaming app")
                .foreachBatch{
                  (batchDF : DataFrame, _: Long) => {
                    //batchDF.cache()
                    batchDF.write.format("org.apache.hudi")
                    .option("hoodie.datasource.write.table.type", "COPY_ON_WRITE")
                    .option("hoodie.datasource.write.precombine.field", "record_id")
                    .option("hoodie.datasource.write.recordkey.field", "record_id")
                    .option("hoodie.datasource.write.partitionpath.field", "location")
                    .option("hoodie.datasource.write.hive_style_partitioning", "true")
                    //.option("hoodie.datasource.hive_sync.jdbcurl", " jdbc:hive2://localhost:10000")
                    .option("hoodie.datasource.hive_sync.database", "tweetevents")
                    .option("hoodie.datasource.hive_sync.enable", "true")
                    .option("hoodie.datasource.hive_sync.table", tableName)
                    .option("hoodie.table.name", tableName)
                    .option("hoodie.datasource.hive_sync.partition_fields", "location")
                    .option("hoodie.datasource.hive_sync.partition_extractor_class", "org.apache.hudi.hive.MultiPartKeysValueExtractor")
                    .option("hoodie.upsert.shuffle.parallelism", "100")
                    .option("hoodie.insert.shuffle.parallelism", "100")
                    .mode(SaveMode.Append)
                    .save("s3://tweetevents/hudi/tweets_emr_6_5")
                  }
                }
                .start()
                .awaitTermination() 

  }


}
