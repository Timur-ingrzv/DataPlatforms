CREATE DATABASE IF NOT EXISTS hw4;

CREATE EXTERNAL TABLE hw4.${hivevar:table_name} (
    cat_id STRING,
    transaction_count BIGINT,
    total_amount DECIMAL(28,2),
    avg_amount DECIMAL(18,2)
)
PARTITIONED BY (us_state STRING)
STORED AS PARQUET
LOCATION '${hivevar:output_path}';

MSCK REPAIR TABLE hw4.${hivevar:table_name};
SHOW PARTITIONS hw4.${hivevar:table_name};
DESCRIBE FORMATTED hw4.${hivevar:table_name};
SELECT * FROM hw4.${hivevar:table_name} LIMIT 20;
