# Инструкция для развертывания кластера Hadoop

### 1. Обновление пакетов на всех нодах
```bash
# Edgenode
team@team-32-en:~$ sudo apt update
team@team-32-en:~$ sudo apt upgrade

# Namenode
team@team-32-en:~$ ssh -i ~/.ssh/team_internal team@team-32-nn
team@team-32-nn:~$ sudo apt update
team@team-32-nn:~$ sudo apt upgrade
team@team-32-nn:~$ exit

# Datanode 0
team@team-32-en:~$ ssh -i ~/.ssh/team_internal team@team-32-00
team@team-32-00:~$ sudo apt update
team@team-32-00:~$ sudo apt upgrade
team@team-32-00:~$ exit

# Datanode 1
team@team-32-en:~$ ssh -i ~/.ssh/team_internal team@team-32-01
team@team-32-01:~$ sudo apt update
team@team-32-01:~$ sudo apt upgrade
team@team-32-01:~$ exit
```


### 2. Создание пользователя hadoop
Пользователь hadoop нужен для коммуникации узлов кластера и при этом он без прав sudo.
```bash
# Edgenode
team@team-32-en:~$ sudo adduser hadoop

# Namenode
team@team-32-en:~$ ssh -i ~/.ssh/team_internal team@team-32-nn
team@team-32-nn:~$ sudo adduser hadoop
team@team-32-nn:~$ sudo -i -u hadoop
hadoop@team-32-nn:~$ mkdir .ssh
hadoop@team-32-nn:~$ exit

# Datanode 0
team@team-32-en:~$ ssh -i ~/.ssh/team_internal team@team-32-00
team@team-32-00:~$ sudo adduser hadoop
team@team-32-00:~$ sudo -i -u hadoop
hadoop@team-32-00:~$ mkdir .ssh
hadoop@team-32-00:~$ exit

# Datanode 1
team@team-32-en:~$ ssh -i ~/.ssh/team_internal team@team-32-01
team@team-32-01:~$ sudo adduser hadoop
team@team-32-01:~$ sudo -i -u hadoop
hadoop@team-32-01:~$ mkdir .ssh
hadoop@team-32-01:~$ exit
```

### 3. Настройка ssh подключения пользователей hadoop между нодами
Создание ключей и настройка прав для передачи на другие ноды
```bash
# создание ssh ключа и файла authorized_keys
team@team-32-en:~$ sudo -i -u hadoop
hadoop@team-32-en:~$ ssh-keygen
hadoop@team-32-en:~$ cat .ssh/id_ed25519.pub  >> .ssh/authorized_keys

# копируем ключи на пользователя team (для передачи на другие ноды)
hadoop@team-32-en:~$ exit
team@team-32-en:~$ mkdir hadoop_ssh
team@team-32-en:~$ mkdir hadoop_ssh/.ssh

team@team-32-en:~$ sudo cp /home/hadoop/.ssh/authorized_keys hadoop_ssh/.ssh/
team@team-32-en:~$ sudo cp /home/hadoop/.ssh/id_ed25519 hadoop_ssh/.ssh/
team@team-32-en:~$ sudo cp /home/hadoop/.ssh/id_ed25519.pub hadoop_ssh/.ssh/

# меняем права ключей (иначе не отправим на другие ноды)
team@team-32-en:~$ sudo chown team:team hadoop_ssh/.ssh/authorized_keys 
team@team-32-en:~$ sudo chown team:team hadoop_ssh/.ssh/id_ed25519
team@team-32-en:~$ sudo chown team:team hadoop_ssh/.ssh/id_ed25519.pub
```

\
Передача и настройка ключей на Namenode. 

Ключи должны оказаться в папке hadoop/.ssh и быть доступными пользователю hadoop.
```bash
# Namenode
team@team-32-en:~$ scp -i .ssh/team_internal -r hadoop_ssh/.ssh/. team@team-32-nn:/home/team/
team@team-32-en:~$ ssh -i ~/.ssh/team_internal team@team-32-nn
team@team-32-nn:~$ sudo mv authorized_keys  id_ed25519  id_ed25519.pub /home/hadoop/.ssh

# отдаем права на ключи пользователю hadoop
team@team-32-nn:~$ sudo chown hadoop:hadoop /home/hadoop/.ssh/authorized_keys
team@team-32-nn:~$ sudo chown hadoop:hadoop /home/hadoop/.ssh/id_ed25519
team@team-32-nn:~$ sudo chown hadoop:hadoop /home/hadoop/.ssh/id_ed25519.pub
team@team-32-nn:~$ exit
```

\
Передача ключей на Datanode 0

Ключи должны оказаться в папке hadoop/.ssh и быть доступными пользователю hadoop.
```bash
# Datanode 0
team@team-32-en:~$ scp -i .ssh/team_internal -r hadoop_ssh/.ssh/. team@team-32-00:/home/team/
team@team-32-en:~$ ssh -i ~/.ssh/team_internal team@team-32-00
team@team-32-00:~$ sudo mv authorized_keys  id_ed25519  id_ed25519.pub /home/hadoop/.ssh

# отдаем права на ключи пользователю hadoop
team@team-32-00:~$ sudo chown hadoop:hadoop /home/hadoop/.ssh/authorized_keys
team@team-32-00:~$ sudo chown hadoop:hadoop /home/hadoop/.ssh/id_ed25519
team@team-32-00:~$ sudo chown hadoop:hadoop /home/hadoop/.ssh/id_ed25519.pub
team@team-32-00:~$ exit
```

\
Передача ключей на Datanode 1

Ключи должны оказаться в папке hadoop/.ssh и быть доступными пользователю hadoop.
```bash
# Datanode 0
team@team-32-en:~$ scp -i .ssh/team_internal -r hadoop_ssh/.ssh/. team@team-32-01:/home/team/
team@team-32-en:~$ ssh -i ~/.ssh/team_internal team@team-32-01
team@team-32-01:~$ sudo mv authorized_keys  id_ed25519  id_ed25519.pub /home/hadoop/.ssh

# отдаем права на ключи пользователю hadoop
team@team-32-01:~$ sudo chown hadoop:hadoop /home/hadoop/.ssh/authorized_keys
team@team-32-01:~$ sudo chown hadoop:hadoop /home/hadoop/.ssh/id_ed25519
team@team-32-01:~$ sudo chown hadoop:hadoop /home/hadoop/.ssh/id_ed25519.pub
team@team-32-01:~$ exit
```

### 4. Скачивание дистрибутива hadoop-3.4.0 и зависмостей (на все узлы)
Скачиваем архив и копируем на все узлы.
```bash
team@team-32-en:~$ sudo -i -u hadoop
hadoop@team-32-en:~$ wget https://dlcdn.apache.org/hadoop/common/hadoop-3.4.0/hadoop-3.4.0.tar.gz

# копируем на остальные узлы
hadoop@team-32-en:~$ scp hadoop-3.4.0.tar.gz team-32-nn:/home/hadoop/
hadoop@team-32-en:~$ scp hadoop-3.4.0.tar.gz team-32-00:/home/hadoop/
hadoop@team-32-en:~$ scp hadoop-3.4.0.tar.gz team-32-01:/home/hadoop/
```

\
Скачиваем java (с пользователя team из-за наличия прав на скачивание из интернета)
```bash
hadoop@team-32-en:~$ exit
team@team-32-en:~$ sudo apt install openjdk-11-jdk-headless

# Namenode
team@team-32-en:~$ ssh -i ~/.ssh/team_internal team@team-32-nn
team@team-32-nn:~$ sudo apt install openjdk-11-jdk-headless -y
exit

# Datanode 0
team@team-32-en:~$ ssh -i ~/.ssh/team_internal team@team-32-00
team@team-32-00:~$ sudo apt install openjdk-11-jdk-headless -y
exit

# Datanode 1
team@team-32-en:~$ ssh -i ~/.ssh/team_internal team@team-32-01
team@team-32-01:~$ sudo apt install openjdk-11-jdk-headless -y
exit
```

\
Разархивируем hadoop архив
```bash
team@team-32-en:~$ sudo -i -u hadoop
hadoop@team-32-en:~$ tar -xzf hadoop-3.4.0.tar.gz 

hadoop@team-32-en:~$ ssh team-32-nn
hadoop@team-32-nn:~$ tar -xzf hadoop-3.4.0.tar.gz 

hadoop@team-32-nn:~$ ssh team-32-00
hadoop@team-32-00:~$ tar -xzf hadoop-3.4.0.tar.gz 

hadoop@team-32-00:~$ ssh team-32-01
hadoop@team-32-01:~$ tar -xzf hadoop-3.4.0.tar.gz 
```

### 5. Конфигурация hadoop файлов
```bash
# .profile
hadoop@team-32-01:~$ ssh team-32-en
hadoop@team-32-en:~$ echo 'export HADOOP_HOME=/home/hadoop/hadoop-3.4.0' >> .profile
hadoop@team-32-en:~$ echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> .profile
hadoop@team-32-en:~$ echo 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin' >> .profile

# копируем на узлы
hadoop@team-32-en:~$ scp .profile team-32-nn:/home/hadoop
hadoop@team-32-en:~$ scp .profile team-32-00:/home/hadoop
hadoop@team-32-en:~$ scp .profile team-32-01:/home/hadoop

# hadoop-env.sh 
hadoop@team-32-en:~$ vim hadoop-3.4.0/etc/hadoop/hadoop-env.sh # копируем содержимое из config/hadoop-env.sh

# core-site.xml
hadoop@team-32-en:~$ vim hadoop-3.4.0/etc/hadoop/core-site.xml

# hdfs-site.xml
hadoop@team-32-en:~$ vim hadoop-3.4.0/etc/hadoop/hdfs-site.xml # берем содержимое из файла config/dn_hdfs-site.xml

# workers
hadoop@team-32-en:~$ echo 'team-32-nn' > hadoop-3.4.0/etc/hadoop/workers
hadoop@team-32-en:~$ echo 'team-32-00' >> hadoop-3.4.0/etc/hadoop/workers
hadoop@team-32-en:~$ echo 'team-32-01' >> hadoop-3.4.0/etc/hadoop/workers

# копируем отредактированные файлы
hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/hadoop-env.sh team-32-nn:/home/hadoop/hadoop-3.4.0/etc/hadoop
hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/hadoop-env.sh team-32-00:/home/hadoop/hadoop-3.4.0/etc/hadoop
hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/hadoop-env.sh team-32-01:/home/hadoop/hadoop-3.4.0/etc/hadoop

hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/hdfs-site.xml team-32-nn:/home/hadoop/hadoop-3.4.0/etc/hadoop 
hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/hdfs-site.xml team-32-00:/home/hadoop/hadoop-3.4.0/etc/hadoop
hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/hdfs-site.xml team-32-01:/home/hadoop/hadoop-3.4.0/etc/hadoop
hadoop@team-32-en:~$ ssh team-32-nn
hadoop@team-32-nn:~$ vim hadoop-3.4.0/etc/hadoop/hdfs-site.xml # РАЗНЫЕ ФАЙЛЫ ДЛЯ NAMENODE и DATANODE (nn_hdfs-site и dn_hdfs-site)
hadoop@team-32-nn:~$ exit

hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/core-site.xml team-32-nn:/home/hadoop/hadoop-3.4.0/etc/hadoop
hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/core-site.xml team-32-00:/home/hadoop/hadoop-3.4.0/etc/hadoop
hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/core-site.xml team-32-01:/home/hadoop/hadoop-3.4.0/etc/hadoop

hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/workers team-32-nn:/home/hadoop/hadoop-3.4.0/etc/hadoop
hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/workers team-32-00:/home/hadoop/hadoop-3.4.0/etc/hadoop
hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/workers team-32-01:/home/hadoop/hadoop-3.4.0/etc/hadoop
``` 

### 6. Запуска кластера
```bash
# настраиваем UI hadoop
t.i@MacBook-Air-Timur ~ % ssh -L 9870:10.0.0.11:9870 team@111.88.128.31

# форматируем hdfs
hadoop@team-32-nn:~$ cd hadoop-3.4.0/
hadoop@team-32-nn:~/hadoop-3.4.0$ bin/hdfs namenode -format
hadoop@team-32-nn:~/hadoop-3.4.0$ sbin/start-dfs.sh 
```

### 7. Проверка
```bash
hadoop@team-32-nn:~$ hdfs dfsadmin -report
## Вывод включает:
...
Live datanodes (3):
...
```