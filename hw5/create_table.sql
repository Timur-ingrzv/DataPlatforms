CREATE DATABASE IF NOT EXISTS hw5;

CREATE EXTERNAL TABLE hw5.${hivevar:table_name} (
    cat_id STRING,
    transaction_count BIGINT,
    total_amount DECIMAL(28,2),
    avg_amount DECIMAL(18,2)
)
PARTITIONED BY (us_state STRING)
STORED AS PARQUET
LOCATION '${hivevar:output_path}';

MSCK REPAIR TABLE hw5.${hivevar:table_name};
