#!/usr/bin/env bash
# Развертывание YARN + JobHistory и публикация веб-интерфейсов через nginx.
# Запускать на edge-ноде от пользователя team, ПОСЛЕ hw1 (HDFS уже работает, /etc/hosts исправлен).
# SKIP_NGINX=1 ./script_hw2.sh — выполнить всё, кроме публикации через nginx (шаг 4)
set -e # остановиться на первой ошибке

# переменные
KEY=$HOME/.ssh/team_internal
EDGE=team-32-en
NAMENODE=team-32-nn
DATANODE0=team-32-00
DATANODE1=team-32-01
NODES="$NAMENODE $DATANODE0 $DATANODE1"
HADOOP_VERSION=3.4.0
HADOOP_DIR=/home/hadoop/hadoop-$HADOOP_VERSION
CONF=$HADOOP_DIR/etc/hadoop
# ресурсы, которые каждый NodeManager отдает под контейнеры (на узле 2 vCPU и 3.8 ГБ RAM)
NM_MEMORY_MB=2048
NM_VCORES=2
# частые команды
SSH="ssh -i $KEY -o StrictHostKeyChecking=accept-new"
SSH_HADOOP_NN="$SSH team@$NAMENODE sudo -i -u hadoop"
APT="DEBIAN_FRONTEND=noninteractive apt"


# 1. Конфигурация YARN и MapReduce
echo "Шаг 1"
# yarn-site.xml
sudo -u hadoop tee $CONF/yarn-site.xml > /dev/null <<EOF
<?xml version="1.0"?>
<configuration>
    <!-- где живет ResourceManager; слушать на всех интерфейсах -->
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>$NAMENODE</value>
    </property>
    <property>
        <name>yarn.resourcemanager.bind-host</name>
        <value>0.0.0.0</value>
    </property>
    <property>
        <name>yarn.nodemanager.bind-host</name>
        <value>0.0.0.0</value>
    </property>
    <!-- сервис shuffle: reduce-задачи забирают через него результаты map-задач -->
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <!-- переменные окружения, которые NodeManager передает в контейнеры -->
    <property>
        <name>yarn.nodemanager.env-whitelist</name>
        <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_HOME,PATH,LANG,TZ,HADOOP_MAPRED_HOME</value>
    </property>
    <!-- ресурсы узла под контейнеры (по умолчанию 8 ГБ и 8 vcores, которых у нас нет) -->
    <property>
        <name>yarn.nodemanager.resource.memory-mb</name>
        <value>$NM_MEMORY_MB</value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.cpu-vcores</name>
        <value>$NM_VCORES</value>
    </property>
    <property>
        <name>yarn.scheduler.minimum-allocation-mb</name>
        <value>256</value>
    </property>
    <property>
        <name>yarn.scheduler.maximum-allocation-mb</name>
        <value>$NM_MEMORY_MB</value>
    </property>
    <property>
        <name>yarn.scheduler.maximum-allocation-vcores</name>
        <value>$NM_VCORES</value>
    </property>
    <!-- проверка виртуальной памяти на маленьких VM убивает контейнеры зря -->
    <property>
        <name>yarn.nodemanager.vmem-check-enabled</name>
        <value>false</value>
    </property>
    <!-- логи контейнеров собираются в HDFS и доступны через JobHistory -->
    <property>
        <name>yarn.log-aggregation-enable</name>
        <value>true</value>
    </property>
    <property>
        <name>yarn.log.server.url</name>
        <value>http://$NAMENODE:19888/jobhistory/logs</value>
    </property>
</configuration>
EOF

# mapred-site.xml
sudo -u hadoop tee $CONF/mapred-site.xml > /dev/null <<EOF
<?xml version="1.0"?>
<configuration>
    <!-- MapReduce-задачи запускаются в YARN -->
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>\$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:\$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.env</name>
        <value>HADOOP_MAPRED_HOME=$HADOOP_DIR</value>
    </property>
    <property>
        <name>mapreduce.map.env</name>
        <value>HADOOP_MAPRED_HOME=$HADOOP_DIR</value>
    </property>
    <property>
        <name>mapreduce.reduce.env</name>
        <value>HADOOP_MAPRED_HOME=$HADOOP_DIR</value>
    </property>
    <!-- размеры контейнеров под маленькие узлы (по умолчанию 1-1.5 ГБ) -->
    <property>
        <name>yarn.app.mapreduce.am.resource.mb</name>
        <value>512</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.command-opts</name>
        <value>-Xmx410m</value>
    </property>
    <property>
        <name>mapreduce.map.memory.mb</name>
        <value>512</value>
    </property>
    <property>
        <name>mapreduce.map.java.opts</name>
        <value>-Xmx410m</value>
    </property>
    <property>
        <name>mapreduce.reduce.memory.mb</name>
        <value>512</value>
    </property>
    <property>
        <name>mapreduce.reduce.java.opts</name>
        <value>-Xmx410m</value>
    </property>
    <!-- JobHistory server: история завершенных задач и их логи -->
    <property>
        <name>mapreduce.jobhistory.address</name>
        <value>$NAMENODE:10020</value>
    </property>
    <property>
        <name>mapreduce.jobhistory.webapp.address</name>
        <value>$NAMENODE:19888</value>
    </property>
    <property>
        <name>mapreduce.jobhistory.bind-host</name>
        <value>0.0.0.0</value>
    </property>
</configuration>
EOF

# копируем на узлы
for node in $NODES; do
    for f in yarn-site.xml mapred-site.xml; do
        sudo -i -u hadoop scp $CONF/$f $node:$CONF
    done
done


# 2. Запуск YARN и JobHistory
echo "Шаг 2"
# stop перед start, чтобы скрипт можно было запускать повторно
$SSH_HADOOP_NN $HADOOP_DIR/bin/mapred --daemon stop historyserver || true
$SSH_HADOOP_NN $HADOOP_DIR/sbin/stop-yarn.sh || true
$SSH_HADOOP_NN $HADOOP_DIR/sbin/start-yarn.sh
$SSH_HADOOP_NN $HADOOP_DIR/bin/mapred --daemon start historyserver


# 3. Проверка
echo "Шаг 3"
sleep 20
$SSH_HADOOP_NN $HADOOP_DIR/bin/hdfs dfsadmin -report | grep -E 'Live datanodes|^Name:'
sudo -i -u hadoop $HADOOP_DIR/bin/yarn node -list
# тестовая задача MapReduce: оценка числа pi (3 map-задачи)
sudo -i -u hadoop $HADOOP_DIR/bin/yarn jar \
    $HADOOP_DIR/share/hadoop/mapreduce/hadoop-mapreduce-examples-$HADOOP_VERSION.jar pi 3 100


# 4. Публикация веб-интерфейсов через nginx на edge-ноде (на localhost, снаружи — через ssh-туннель)
if [ "${SKIP_NGINX:-0}" = "1" ]; then
    echo "Шаг 4 пропущен (SKIP_NGINX=1)"
    exit 0
fi
echo "Шаг 4"
sudo $APT install -y nginx

# внешний порт на edge -> внутренний адрес демона
# NameNode, ResourceManager, JobHistory, SecondaryNameNode,
# NodeManager на 3 узлах, DataNode на 3 узлах
ROUTES="9870:$NAMENODE:9870
8088:$NAMENODE:8088
19888:$NAMENODE:19888
9868:$NAMENODE:9868
8042:$NAMENODE:8042
8043:$DATANODE0:8042
8044:$DATANODE1:8042
9864:$NAMENODE:9864
9865:$DATANODE0:9864
9866:$DATANODE1:9864"

# правила замены внутренних ссылок на внешние (чтобы переходы между UI работали снаружи)
SUB_FILTERS=""
for route in $ROUTES; do
    IFS=: read -r port host target <<< "$route"
    ip=$(getent hosts $host | awk '{print $1}')
    # ссылки встречаются и по имени узла, и по IP (UI NameNode показывает DataNode по IP)
    SUB_FILTERS+="        sub_filter '$host:$target' '\$host:$port';"$'\n'
    SUB_FILTERS+="        sub_filter '$ip:$target' '\$host:$port';"$'\n'
done

{
    for route in $ROUTES; do
        IFS=: read -r port host target <<< "$route"
        cat <<EOF
server {
    listen 127.0.0.1:$port; # только localhost, доступ через ssh-туннель
    location / {
        # только чтение: POST/PUT в REST API YARN позволяют запускать произвольный код
        limit_except GET HEAD { deny all; }
        proxy_pass http://$host:$target;
        proxy_set_header Host \$http_host; # с портом, иначе редиректы уводят на порт 80
        proxy_set_header Accept-Encoding "";
        sub_filter_once off;
        sub_filter_types *;
$SUB_FILTERS    }
}
EOF
    done
} | sudo tee /etc/nginx/sites-available/hadoop > /dev/null

sudo ln -sf /etc/nginx/sites-available/hadoop /etc/nginx/sites-enabled/hadoop
sudo rm -f /etc/nginx/sites-enabled/default # стандартную страницу nginx не публикуем
sudo nginx -t
sudo systemctl restart nginx

echo "Проверка nginx"
for route in $ROUTES; do
    port=${route%%:*}
    curl -s -L -o /dev/null -w "$port -> HTTP %{http_code}\n" http://localhost:$port/
done
