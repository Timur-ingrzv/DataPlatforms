# процесс обработки данных в Prefect.

import glob
import os
import subprocess
import sys
from datetime import datetime, timezone

from prefect import flow, task
from prefect.cache_policies import NO_CACHE

SPARK_HOME = "/home/hadoop/hw4/spark-3.5.8-bin-hadoop3"
HADOOP_HOME = "/home/hadoop/hadoop-3.4.0"
HIVE_HOME = "/home/hadoop/apache-hive-4.0.0-alpha-2-bin"
JAVA_HOME = "/usr/lib/jvm/java-11-openjdk-amd64"
EDGE = "team-32-en"
INPUT_PATH = "hdfs://team-32-nn:9000/user/hive/warehouse/transactions_staging"
OUTPUT_DIR = "hdfs://team-32-nn:9000/user/hadoop/hw5"
HERE = os.path.dirname(os.path.abspath(__file__))

# окружение
os.environ["JAVA_HOME"] = JAVA_HOME
os.environ["HADOOP_HOME"] = HADOOP_HOME
os.environ["HADOOP_CONF_DIR"] = HADOOP_HOME + "/etc/hadoop"
os.environ["YARN_CONF_DIR"] = HADOOP_HOME + "/etc/hadoop"
os.environ["SPARK_HOME"] = SPARK_HOME
os.environ["PYSPARK_PYTHON"] = "/usr/bin/python3"
os.environ["PATH"] = JAVA_HOME + "/bin:" + HADOOP_HOME + "/bin:" + os.environ["PATH"]
os.environ.pop("HIVE_AUX_JARS_PATH", None)
os.environ.pop("SPARK_DIST_CLASSPATH", None)
sys.path.insert(0, SPARK_HOME + "/python")
sys.path += glob.glob(SPARK_HOME + "/python/lib/py4j-*-src.zip")

from pyspark.sql import SparkSession, functions, types


@task(cache_policy=NO_CACHE)
def start_spark():
    # 1. запуск Spark под управлением YARN
    spark = (
        SparkSession.builder.appName("hw5-prefect")
        .master("yarn")
        .config("spark.driver.memory", "512m")
        .config("spark.executor.memory", "512m")
        .config("spark.executor.memoryOverhead", "512")
        .config("spark.executor.cores", "1")
        .config("spark.executor.instances", "2")
        .config("spark.yarn.am.memory", "512m")
        .config("spark.yarn.am.memoryOverhead", "384")
        .config("spark.dynamicAllocation.enabled", "false")
        .config("spark.sql.shuffle.partitions", "3")
        .config("spark.sql.ansi.enabled", "false")
        .config("spark.sql.catalogImplementation", "in-memory")
        .config("spark.sql.parquet.compression.codec", "snappy")
        .config("spark.driver.host", EDGE)
        .config("spark.driver.bindAddress", "0.0.0.0")
        .config("spark.yarn.appMasterEnv.JAVA_HOME", JAVA_HOME)
        .config("spark.executorEnv.JAVA_HOME", JAVA_HOME)
        .config("spark.executorEnv.PYSPARK_PYTHON", "/usr/bin/python3")
        .getOrCreate()
    )
    spark.sparkContext.setLogLevel("WARN")
    print("YARN application ID:", spark.sparkContext.applicationId)
    return spark


@task(cache_policy=NO_CACHE)
def check_hdfs(spark, path):
    # 2. Подключение к HDFS
    hadoop_path = spark._jvm.org.apache.hadoop.fs.Path(path)
    fs = hadoop_path.getFileSystem(spark._jsc.hadoopConfiguration())
    print("Файлы в HDFS:", [str(s.getPath()) for s in fs.listStatus(hadoop_path)])


@task(cache_policy=NO_CACHE)
def read_data(spark, path):
    # 3. Чтение данных из HDFS 
    columns = (
        "transaction_time merch cat_id amount name_1 name_2 gender street "
        "one_city us_state post_code lat lon population_city jobs merchant_lat merchant_lon"
    ).split()
    schema = types.StructType([types.StructField(c, types.StringType(), True) for c in columns])
    return (
        spark.read.schema(schema)
        .option("header", "true")
        .option("enforceSchema", "false")
        .option("mode", "FAILFAST")
        .option("quote", '"')
        .option("escape", "\\")
        .csv(path)
    )


@task(cache_policy=NO_CACHE)
def transform(df):
    # 4. Трансформация данных
    prepared = df.select(
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
    return valid.groupBy("us_state", "cat_id").agg(
        functions.count("*").alias("transaction_count"),
        functions.sum("amount").alias("total_amount"),
        functions.avg("amount").cast("decimal(18,2)").alias("avg_amount"),
    )


@task(cache_policy=NO_CACHE)
def save_partitioned(result, output_path):
    # Сохранение в HDFS (Parquet)
    result.repartition(3, "us_state").write.mode("errorifexists").partitionBy(
        "us_state"
    ).parquet(output_path)
    return output_path


def beeline(*args):
    # Запуск beeline
    subprocess.run(
        [
            HIVE_HOME + "/bin/beeline",
            "-u", "jdbc:hive2://%s:5433/default" % EDGE,
            "-n", "scott", "-p", "tiger",
        ] + list(args),
        check=True,
    )


@task(cache_policy=NO_CACHE)
def create_table(table_name, output_path):
    # 5. таблица Hive
    beeline(
        "--hivevar", "table_name=" + table_name,
        "--hivevar", "output_path=" + output_path,
        "-f", os.path.join(HERE, "create_table.sql"),
    )


@task(cache_policy=NO_CACHE)
def check_table(table_name):
    # проверка
    beeline("-e", "SHOW PARTITIONS hw5.%s;" % table_name)
    beeline("-e", "SELECT * FROM hw5.%s LIMIT 10;" % table_name)


@flow(name="spark-yarn-pipeline", log_prints=True)
def pipeline(input_path: str = INPUT_PATH):
    table_name = "transactions_summary_" + datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    output_path = OUTPUT_DIR + "/" + table_name

    spark = start_spark()
    try:
        check_hdfs(spark, input_path)
        df = read_data(spark, input_path)
        result = transform(df)
        save_partitioned(result, output_path)
    finally:
        spark.stop()

    create_table(table_name, output_path)
    check_table(table_name)


if __name__ == "__main__":
    pipeline()
