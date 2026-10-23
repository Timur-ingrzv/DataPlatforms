#!/usr/bin/env bash
# развертывание Apache Hive 
# предусловия: HDFS и YARN работают; файл с данными лежит в /home/hadoop/test.csv
# запускать на edge от пользователя team: ./script_hw3.sh

set -e # остановиться на первой ошибке

# переменные
KEY=$HOME/.ssh/team_internal
EDGE=team-32-en
POSTGRES_HOST=team-32-01
IPS="10.32.0.10 10.32.0.11 10.32.0.12 10.32.0.13" # адреса всех машин
DB_PASS=hiveMegaPass
HIVE_VERSION=4.0.0-alpha-2
HIVE_TARBALL=apache-hive-$HIVE_VERSION-bin.tar.gz
HIVE_DIR=/home/hadoop/apache-hive-$HIVE_VERSION-bin
JDBC_JAR=postgresql-42.7.14.jar
HS2_PORT=5433 # порт HiveServer2
HMS_PORT=9083 # порт metastore

# частые команды
SSH="ssh -i $KEY -o StrictHostKeyChecking=accept-new"
HIVE_OPTS="--hiveconf hive.server2.enable.doAs=false --hiveconf hive.security.authorization.enabled=false"
APT="DEBIAN_FRONTEND=noninteractive apt"
BEELINE="sudo -i -u hadoop beeline -u jdbc:hive2://$EDGE:$HS2_PORT -n scott -p tiger"

# 1. Развертывание Postgres на Datanode 1
echo "Шаг 1"
$SSH team@$POSTGRES_HOST "sudo $APT install -y postgresql"
# меняем конфигурацию
$SSH team@$POSTGRES_HOST "sudo tee -a /etc/postgresql/16/main/postgresql.conf > /dev/null" <<EOF
listen_addresses = '$POSTGRES_HOST'
EOF
for ip in $IPS; do
    $SSH team@$POSTGRES_HOST "sudo tee -a /etc/postgresql/16/main/pg_hba.conf > /dev/null" <<EOF
host    metastore       hive            $ip/32           password
EOF
done

# перезапуск postgres и создание metastore
$SSH team@$POSTGRES_HOST "sudo systemctl restart postgresql"
$SSH team@$POSTGRES_HOST "cd /tmp && sudo -u postgres psql" <<EOF
CREATE DATABASE metastore;
CREATE USER hive WITH PASSWORD '$DB_PASS';
GRANT ALL PRIVILEGES ON DATABASE "metastore" TO hive;
ALTER DATABASE metastore OWNER TO hive;
EOF
sudo $APT install -y postgresql-client-16

# проверка
PGPASSWORD=$DB_PASS psql -h $POSTGRES_HOST -p 5432 -U hive -d metastore -c "SELECT 1;"


# 2. Настройка hdfs
echo "Шаг 2"
sudo -i -u hadoop hdfs dfs -mkdir -p /user/hive/warehouse
sudo -i -u hadoop hdfs dfs -mkdir -p /tmp
sudo -i -u hadoop hdfs dfs -chmod g+w /tmp
sudo -i -u hadoop hdfs dfs -chmod g+w /user/hive/warehouse


# 3. Настройка Hive
echo "Шаг 3"
sudo -i -u hadoop wget -q https://jdbc.postgresql.org/download/$JDBC_JAR
sudo -i -u hadoop wget -q https://archive.apache.org/dist/hive/hive-$HIVE_VERSION/$HIVE_TARBALL
sudo -i -u hadoop tar -xzf $HIVE_TARBALL

# hive-site.xml
sudo -u hadoop tee /home/hadoop/hive-site.xml > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>hive.server2.authentication</name>
        <value>NONE</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionURL</name>
        <value>jdbc:postgresql://$POSTGRES_HOST:5432/metastore</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionDriverName</name>
        <value>org.postgresql.Driver</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionUserName</name>
        <value>hive</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionPassword</name>
        <value>$DB_PASS</value>
    </property>
    <property>
        <name>hive.metastore.warehouse.dir</name>
        <value>/user/hive/warehouse</value>
    </property>
    <property>
        <name>hive.server2.thrift.port</name>
        <value>$HS2_PORT</value>
    </property>
</configuration>
EOF

# .profile
sudo -u hadoop tee -a /home/hadoop/.profile > /dev/null <<EOF
export HIVE_HOME=$HIVE_DIR
export HIVE_CONF_DIR=\$HIVE_HOME/conf
export HIVE_AUX_JARS_PATH=\$HIVE_HOME/lib/*
export PATH=\$PATH:\$HIVE_HOME/bin
EOF

sudo -i -u hadoop cp $JDBC_JAR $HIVE_DIR/lib/
sudo -i -u hadoop cp hive-site.xml $HIVE_DIR/conf/
sudo -i -u hadoop hive --version

# инициализация схемы бд
sudo -i -u hadoop $HIVE_DIR/bin/schematool -dbType postgres -initSchema


# 4. Запуск серверов
echo "Шаг 4"
sudo -i -u hadoop bash -c "nohup hive $HIVE_OPTS --service metastore >> /tmp/hms.log 2>&1 < /dev/null &"
# ждём, пока metastore начнёт слушать порт
until (echo > /dev/tcp/$EDGE/$HMS_PORT) 2>/dev/null; do sleep 5; done
sudo -i -u hadoop bash -c "nohup hive $HIVE_OPTS --service hiveserver2 >> /tmp/hs2.log 2>&1 < /dev/null &"
# ждём, пока HiveServer2 начнёт слушать порт
until (echo > /dev/tcp/$EDGE/$HS2_PORT) 2>/dev/null; do sleep 5; done

echo "Список баз"
$BEELINE -e "SHOW DATABASES;"


# 5. Загрузка данных
echo "Шаг 5"
# создание партицированной и временной таблиц
# партиции по us_state
sudo -u hadoop tee /home/hadoop/create_tables.sql > /dev/null <<'EOF'
DROP TABLE IF EXISTS transactions_partitioned;
 
CREATE TABLE transactions_partitioned (
    transaction_time STRING,
    merch            STRING,
    cat_id           STRING,
    amount           DOUBLE,
    name_1           STRING,
    name_2           STRING,
    gender           STRING,
    street           STRING,
    one_city         STRING,
    post_code        STRING,
    lat              DOUBLE,
    lon              DOUBLE,
    population_city  INT,
    jobs             STRING,
    merchant_lat     DOUBLE,
    merchant_lon     DOUBLE
)
PARTITIONED BY (us_state STRING)
STORED AS ORC;
 
DROP TABLE IF EXISTS transactions_staging;
 
CREATE TABLE transactions_staging (
    transaction_time STRING,
    merch            STRING,
    cat_id           STRING,
    amount           DOUBLE,
    name_1           STRING,
    name_2           STRING,
    gender           STRING,
    street           STRING,
    one_city         STRING,
    us_state         STRING,
    post_code        STRING,
    lat              DOUBLE,
    lon              DOUBLE,
    population_city  INT,
    jobs             STRING,
    merchant_lat     DOUBLE,
    merchant_lon     DOUBLE
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    "separatorChar" = ",",
    "quoteChar"     = "\"",
    "escapeChar"    = "\\"
)
STORED AS TEXTFILE
TBLPROPERTIES ("skip.header.line.count"="1");
EOF
$BEELINE -f /home/hadoop/create_tables.sql
 
# загрузка данных во временную таблицу + добавление строк в нужную партицию
sudo -u hadoop tee /home/hadoop/load_data.sql > /dev/null <<'EOF'
LOAD DATA LOCAL INPATH '/home/hadoop/test.csv'
OVERWRITE INTO TABLE transactions_staging;

SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;
 
INSERT OVERWRITE TABLE transactions_partitioned
PARTITION (us_state)
SELECT
    transaction_time,
    merch,
    cat_id,
    amount,
    name_1,
    name_2,
    gender,
    street,
    one_city,
    post_code,
    lat,
    lon,
    population_city,
    jobs,
    merchant_lat,
    merchant_lon,
    us_state
FROM transactions_staging
WHERE transaction_time <> 'transaction_time';
EOF
$BEELINE -f /home/hadoop/load_data.sql

echo "Проверка разбиения"
sudo -i -u hadoop hdfs dfs -ls /user/hive/warehouse/transactions_partitioned
$BEELINE -e "SHOW PARTITIONS transactions_partitioned;"
$BEELINE -e "SELECT * FROM transactions_partitioned LIMIT 3;"
 

# Проверка одновременного использования двумя клиентами
echo "Проверка: 2 клиента"
sudo -i -u hadoop beeline -u jdbc:hive2://$EDGE:$HS2_PORT -n user1 -p pass1 -e "SELECT * FROM transactions_partitioned LIMIT 3;" < /dev/null &
pid1=$!
sudo -i -u hadoop beeline -u jdbc:hive2://$EDGE:$HS2_PORT -n user2 -p pass2 -e "SHOW PARTITIONS transactions_partitioned;" < /dev/null &
pid2=$!
wait $pid1 $pid2

echo "Готово"