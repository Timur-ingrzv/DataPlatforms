# Инструкция для развертывания Hive

### 1. Развертывание Postgres на Datanode 1
```bash
team@team-32-en:~$ ssh -i .ssh/team_internal team-32-01
team@team-32-01:~$ sudo apt install postgresql

# меняем конфигурацию 
team@team-32-01:~$ sudo vim /etc/postgresql/16/main/postgresql.conf 
# listen_addresses = 'team-32-01' > postgresql.conf

team@team-32-01:~$ sudo vim /etc/postgresql/16/main/pg_hba.conf 
# host    metastore       hive            10.32.0.10/32           password
# host    metastore       hive            10.32.0.11/32           password
# host    metastore       hive            10.32.0.12/32           password
# host    metastore       hive            10.32.0.13/32           password

# перезапуск postgres и создание metastore
team@team-32-01:~$ sudo systemctl restart postgresql

team@team-32-01:~$ sudo -i -u postgres
postgres@team-32-01:~$ psql 
postgres=# CREATE DATABASE metastore;
postgres=# CREATE USER hive with password 'hiveMegaPass';
postgres=# GRANT ALL PRIVILEGES ON DATABASE "metastore" to hive;
postgres=# ALTER DATABASE metastore OWNER TO hive;
postgres=# \q
postgres@team-32-01:~$ exit
team@team-32-01:~$ exit
team@team-32-en:~$ sudo apt install postgresql-client-16

# проверка
team@team-32-en:~$ psql -h team-32-01 -p 5432 -U hive -W -d metastore
```

### 2. Настройка hdfs
```bash
team@team-32-en:~$ sudo -i -u hadoop
hadoop@team-32-en:~$ hdfs dfs -mkdir -p /user/hive/warehouse
hadoop@team-32-en:~$ hdfs dfs -chmod g+w /tmp
hadoop@team-32-en:~$ hdfs dfs -chmod g+w /user/hive/warehouse
```

### 3. Настройка Hive
```bash
hadoop@team-32-en:~$ wget https://jdbc.postgresql.org/download/postgresql-42.7.14.jar
hadoop@team-32-en:~$ wget https://archive.apache.org/dist/hive/hive-4.0.0-alpha-2/apache-hive-4.0.0-alpha-2-bin.tar.gz

hadoop@team-32-en:~$ vim hive-site.xml # из config/hive-site.xml
hadoop@team-32-en:~$ cat >> ~/.profile << 'EOF'
export HIVE_HOME=/home/hadoop/apache-hive-4.0.0-alpha-2-bin
export HIVE_CONF_DIR=$HIVE_HOME/conf
export HIVE_AUX_JARS_PATH=$HIVE_HOME/lib/*
export PATH=$PATH:$HIVE_HOME/bin
EOF
hadoop@team-32-en:~$ source .profile

hadoop@team-32-en:~$ cp postgresql-42.7.14.jar apache-hive-4.0.0-alpha-2-bin/lib/
hadoop@team-32-en:~$ cp hive-site.xml apache-hive-4.0.0-alpha-2-bin/conf/

hadoop@team-32-en:~$ hive --version

# Инициализация схемы бд
hadoop@team-32-en:~$ cd apache-hive-4.0.0-alpha-2-bin/
hadoop@team-32-en:~/apache-hive-4.0.0-alpha-2-bin$ bin/schematool -dbType postgres -initSchema
```

### Запуск серверов
```bash
hadoop@team-32-en:~/apache-hive-4.0.0-alpha-2-bin$ hive --hiveconf hive.server2.enable.doAs=false -hiveconf hive.security.authorization.enabled=false --service hiveserver2 1>> /tmp/hs2.log 2>> /tmp/hs2.log &
hadoop@team-32-en:~/apache-hive-4.0.0-alpha-2-bin$ hive --hiveconf hive.server2.enable.doAs=false -hiveconf hive.security.authorization.enabled=false --service metastore 1>> /tmp/hms.log 2>> /tmp/hms.log &
hadoop@team-32-en:~/apache-hive-4.0.0-alpha-2-bin$ beeline -u jdbc:hive2://team-32-en:5433 -n scott -p tiger
```