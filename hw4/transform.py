import argparse

from pyspark.sql import SparkSession, functions, types


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    spark = SparkSession.builder.appName("hw4-transactions").getOrCreate()
    try:
        if spark.sparkContext.master != "yarn":
            raise RuntimeError("Приложение должно запускаться с --master yarn")
        columns = (
            "transaction_time merch cat_id amount name_1 name_2 gender street "
            "one_city us_state post_code lat lon population_city jobs merchant_lat merchant_lon"
        ).split()
        schema = types.StructType([
            types.StructField(column, types.StringType(), True) for column in columns
        ])
        source = (
            spark.read.schema(schema).option("header", "true")
            .option("enforceSchema", "false").option("mode", "FAILFAST")
            .option("quote", '"').option("escape", "\\").csv(args.input)
        )
        prepared = source.select(
            functions.upper(functions.trim("us_state")).alias("us_state"),
            functions.trim("cat_id").alias("cat_id"),
            functions.col("amount").cast("decimal(18,2)").alias("amount"),
        )
        valid = prepared.filter(
            functions.col("us_state").rlike("^[A-Z]{2}$")
            & functions.col("cat_id").isNotNull()
            & (functions.length("cat_id") > 0)
            & functions.col("amount").isNotNull()
            & (functions.col("amount") >= 0)
        )
        if not valid.take(1):
            raise RuntimeError("В источнике нет подходящих строк")
        result = valid.groupBy("us_state", "cat_id").agg(
            functions.count("*").alias("transaction_count"),
            functions.sum("amount").alias("total_amount"),
            functions.avg("amount").cast("decimal(18,2)").alias("avg_amount"),
        )
        result.repartition(3, "us_state").write.mode("errorifexists").partitionBy(
            "us_state"
        ).parquet(args.output)
        print("YARN application ID:", spark.sparkContext.applicationId)
    finally:
        spark.stop()


if __name__ == "__main__":
    main()
