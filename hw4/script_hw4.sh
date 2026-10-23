#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_HOME=/home/hadoop/hadoop-3.4.0
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export YARN_CONF_DIR=$HADOOP_CONF_DIR
export HIVE_HOME=/home/hadoop/apache-hive-4.0.0-alpha-2-bin
export SPARK_HOME=$SCRIPT_DIR/spark-3.5.8-bin-hadoop3
export SPARK_CONF_DIR=$SPARK_HOME/conf
export PYSPARK_PYTHON=/usr/bin/python3
export PYSPARK_DRIVER_PYTHON=/usr/bin/python3
export PATH=$JAVA_HOME/bin:$HADOOP_HOME/bin:$PATH
unset HIVE_AUX_JARS_PATH SPARK_DIST_CLASSPATH

INPUT_PATH=${INPUT_PATH:-hdfs://team-32-nn:9000/user/hive/warehouse/transactions_staging}
TABLE_NAME=transactions_summary_$(date -u +%Y%m%d_%H%M%S)_$$
OUTPUT_PATH=hdfs://team-32-nn:9000/user/hadoop/hw4/$TABLE_NAME
BEELINE=("$HIVE_HOME/bin/beeline" -u jdbc:hive2://team-32-en:5433/default -n scott -p tiger --force=false)

echo 'Шаг 1. Проверка HDFS и YARN'
hdfs dfs -ls "$INPUT_PATH"
yarn node -list

echo 'Шаг 2. Установка Spark'
if [[ ! -x $SPARK_HOME/bin/spark-submit ]]; then
    curl --fail --location --retry 3 \
        https://archive.apache.org/dist/spark/spark-3.5.8/spark-3.5.8-bin-hadoop3.tgz \
        -o "$SCRIPT_DIR/spark-3.5.8-bin-hadoop3.tgz"
    tar -xzf "$SCRIPT_DIR/spark-3.5.8-bin-hadoop3.tgz" -C "$SCRIPT_DIR"
fi

echo 'Шаг 3. Чтение, трансформации и партиционированная запись Spark на YARN'
"$SPARK_HOME/bin/spark-submit" \
    --master yarn --deploy-mode client \
    --driver-memory 512m --executor-memory 512m --executor-cores 1 --num-executors 2 \
    --conf spark.executor.memoryOverhead=512 \
    --conf spark.yarn.am.memory=512m \
    --conf spark.yarn.am.memoryOverhead=384 \
    --conf spark.dynamicAllocation.enabled=false \
    --conf spark.sql.shuffle.partitions=3 \
    --conf spark.sql.ansi.enabled=false \
    --conf spark.sql.catalogImplementation=in-memory \
    --conf spark.sql.parquet.compression.codec=snappy \
    --conf spark.driver.host=team-32-en \
    --conf spark.driver.bindAddress=0.0.0.0 \
    --conf spark.yarn.appMasterEnv.JAVA_HOME="$JAVA_HOME" \
    --conf spark.executorEnv.JAVA_HOME="$JAVA_HOME" \
    --conf spark.executorEnv.PYSPARK_PYTHON=/usr/bin/python3 \
    "$SCRIPT_DIR/transform.py" --input "$INPUT_PATH" --output "$OUTPUT_PATH"
hdfs dfs -ls -R "$OUTPUT_PATH"

echo 'Шаг 4. Создание таблицы и проверка чтения через Beeline'
"${BEELINE[@]}" --hivevar table_name="$TABLE_NAME" --hivevar output_path="$OUTPUT_PATH" \
    -f "$SCRIPT_DIR/create_table.sql"
printf 'Таблица: hw4.%s\nHDFS: %s\n' "$TABLE_NAME" "$OUTPUT_PATH"
