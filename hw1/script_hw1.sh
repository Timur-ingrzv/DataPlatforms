#!/usr/bin/env bash
set -e # остановиться на первой ошибке

# переменные
KEY=$HOME/.ssh/team_internal
NAMENODE=team-32-nn
DATANODE0=team-32-00
DATANODE1=team-32-01
NODES="$NAMENODE $DATANODE0 $DATANODE1"
HADOOP_VERSION=3.4.0
TARBALL=hadoop-$HADOOP_VERSION.tar.gz
HADOOP_DIR=/home/hadoop/hadoop-$HADOOP_VERSION
JAVA_DIR=/usr/lib/jvm/java-11-openjdk-amd64
CONF=$HADOOP_DIR/etc/hadoop
# частые команды
SSH="ssh -i $KEY -o StrictHostKeyChecking=accept-new"
SCP="scp -i $KEY -o StrictHostKeyChecking=accept-new"
# замена, чтобы не останавливаться на вопросах
APT="DEBIAN_FRONTEND=noninteractive apt"


# 1. Обновление пакетов на всех нодах
echo "Шаг 1"
# Edgenode
sudo $APT update
sudo $APT upgrade -y

# Namenode, Datanode 0, Datanode 1
for node in $NODES; do
    $SSH team@$node "sudo $APT update"
    $SSH team@$node "sudo $APT upgrade -y"
done


# 2. Создание пользователя hadoop
echo "Шаг 2"
# Edgenode
sudo adduser --disabled-password --gecos "" hadoop # без пароля и вопросов

# Nodes
for node in $NODES; do
    $SSH team@$node "sudo adduser --disabled-password --gecos '' hadoop"
    $SSH team@$node "sudo -i -u hadoop mkdir /home/hadoop/.ssh"
done


# 3. Настройка ssh подключения пользователей hadoop между нодами
echo "Шаг 3"
cd ~

# создание ssh ключа и файла authorized_keys
sudo -u hadoop ssh-keygen -t ed25519 -N "" -f /home/hadoop/.ssh/id_ed25519
sudo -u hadoop sh -c "cat /home/hadoop/.ssh/id_ed25519.pub >> /home/hadoop/.ssh/authorized_keys"
sudo -u hadoop sh -c "printf 'Host *\n    StrictHostKeyChecking accept-new\n' > /home/hadoop/.ssh/config"

# копируем ключи на пользователя team (для передачи на другие ноды)
mkdir hadoop_ssh
mkdir hadoop_ssh/.ssh
sudo cp /home/hadoop/.ssh/authorized_keys hadoop_ssh/.ssh/
sudo cp /home/hadoop/.ssh/id_ed25519 hadoop_ssh/.ssh/
sudo cp /home/hadoop/.ssh/id_ed25519.pub hadoop_ssh/.ssh/
sudo cp /home/hadoop/.ssh/config hadoop_ssh/.ssh/

# меняем права ключей (иначе не отправим на другие ноды)
sudo chown team:team hadoop_ssh/.ssh/authorized_keys
sudo chown team:team hadoop_ssh/.ssh/id_ed25519
sudo chown team:team hadoop_ssh/.ssh/id_ed25519.pub
sudo chown team:team hadoop_ssh/.ssh/config

# передача ключей на Nodes
for node in $NODES; do
    $SCP -r hadoop_ssh/.ssh/. team@$node:/home/team/
    $SSH team@$node "sudo mv authorized_keys id_ed25519 id_ed25519.pub config /home/hadoop/.ssh"
    # отдаем права на ключи пользователю hadoop
    $SSH team@$node "sudo chown hadoop:hadoop /home/hadoop/.ssh/authorized_keys"
    $SSH team@$node "sudo chown hadoop:hadoop /home/hadoop/.ssh/id_ed25519"
    $SSH team@$node "sudo chown hadoop:hadoop /home/hadoop/.ssh/id_ed25519.pub"
    $SSH team@$node "sudo chown hadoop:hadoop /home/hadoop/.ssh/config"
done


# 4. Скачивание дистрибутива hadoop-3.4.0 и зависмостей (на все узлы)
echo "Шаг 4"
# скачиваем архив
sudo -i -u hadoop wget -q -O $TARBALL https://dlcdn.apache.org/hadoop/common/hadoop-$HADOOP_VERSION/$TARBALL \
    || sudo -i -u hadoop wget -q -O $TARBALL https://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/$TARBALL

# копируем на остальные узлы
for node in $NODES; do
    sudo -i -u hadoop scp $TARBALL $node:/home/hadoop/
done

# скачиваем java
sudo $APT install -y openjdk-11-jdk-headless
for node in $NODES; do
    $SSH team@$node "sudo $APT install -y openjdk-11-jdk-headless"
done

# Разархивируем hadoop архив
sudo -i -u hadoop tar -xzf $TARBALL
for node in $NODES; do
    sudo -i -u hadoop ssh $node "tar -xzf $TARBALL"
done


# 5. Конфигурация hadoop файлов
echo "Шаг 5"
# .profile
echo "export HADOOP_HOME=$HADOOP_DIR" | sudo -u hadoop tee -a /home/hadoop/.profile > /dev/null
echo "export JAVA_HOME=$JAVA_DIR" | sudo -u hadoop tee -a /home/hadoop/.profile > /dev/null
echo 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin' | sudo -u hadoop tee -a /home/hadoop/.profile > /dev/null

# hadoop-env.sh
echo "export JAVA_HOME=$JAVA_DIR" | sudo -u hadoop tee -a $CONF/hadoop-env.sh > /dev/null

# core-site.xml
sudo -u hadoop tee $CONF/core-site.xml > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://$NAMENODE:9000</value>
    </property>
</configuration>
EOF

# hdfs-site.xml
sudo -u hadoop tee $CONF/hdfs-site.xml > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>3</value>
    </property>
    <property>
        <name>dfs.namenode.rpc-address</name>
        <value>$NAMENODE:9000</value>
    </property>
    <property>
        <name>dfs.namenode.rpc-bind-host</name>
        <value>0.0.0.0</value>
    </property>
    <property>
        <name>dfs.namenode.http-address</name>
        <value>$NAMENODE:9870</value>
    </property>
    <property>
        <name>dfs.namenode.http-bind-host</name>
        <value>0.0.0.0</value>
    </property>
</configuration>
EOF

# workers
echo $NAMENODE | sudo -u hadoop tee $CONF/workers > /dev/null
echo $DATANODE0 | sudo -u hadoop tee -a $CONF/workers > /dev/null
echo $DATANODE1 | sudo -u hadoop tee -a $CONF/workers > /dev/null

# копируем на узлы
for node in $NODES; do
    sudo -i -u hadoop scp .profile $node:/home/hadoop
    for f in hadoop-env.sh hdfs-site.xml core-site.xml workers; do
        sudo -i -u hadoop scp $CONF/$f $node:$CONF
    done
done


# 6. Запуск кластера
echo "Шаг 6"
# форматируем hdfs
$SSH team@$NAMENODE "sudo -i -u hadoop $HADOOP_DIR/bin/hdfs namenode -format -nonInteractive"
$SSH team@$NAMENODE "sudo -i -u hadoop $HADOOP_DIR/sbin/start-dfs.sh"


# 7. Проверка
echo "Проверка"
sleep 20
$SSH team@$NAMENODE "sudo -i -u hadoop $HADOOP_DIR/bin/hdfs dfsadmin -report | grep 'Live datanodes'"

# Хотим Live datanodes (3)