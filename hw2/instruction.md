# Инструкция для развертывания YARN и публикации веб-интерфейсов

Выполняется после hw1 (HDFS уже запущен).

### 1. Конфигурация YARN и MapReduce
```bash
team@team-32-en:~$ sudo -i -u hadoop

# yarn-site.xml
hadoop@team-32-en:~$ vim hadoop-3.4.0/etc/hadoop/yarn-site.xml # копируем содержимое из config/yarn-site.xml

# mapred-site.xml
hadoop@team-32-en:~$ vim hadoop-3.4.0/etc/hadoop/mapred-site.xml # копируем содержимое из config/mapred-site.xml

# копируем на узлы
hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/yarn-site.xml team-32-nn:/home/hadoop/hadoop-3.4.0/etc/hadoop
hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/yarn-site.xml team-32-00:/home/hadoop/hadoop-3.4.0/etc/hadoop
hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/yarn-site.xml team-32-01:/home/hadoop/hadoop-3.4.0/etc/hadoop

hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/mapred-site.xml team-32-nn:/home/hadoop/hadoop-3.4.0/etc/hadoop
hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/mapred-site.xml team-32-00:/home/hadoop/hadoop-3.4.0/etc/hadoop
hadoop@team-32-en:~$ scp hadoop-3.4.0/etc/hadoop/mapred-site.xml team-32-01:/home/hadoop/hadoop-3.4.0/etc/hadoop
```
Память и ядра в конфигах подобраны под ноды с 2 vCPU и 3.8 ГБ RAM.

### 2. Запуск YARN и JobHistory
```bash
hadoop@team-32-en:~$ ssh team-32-nn
hadoop@team-32-nn:~$ cd hadoop-3.4.0/
hadoop@team-32-nn:~/hadoop-3.4.0$ sbin/start-yarn.sh
hadoop@team-32-nn:~/hadoop-3.4.0$ bin/mapred --daemon start historyserver
hadoop@team-32-nn:~/hadoop-3.4.0$ jps
## Вывод:
DataNode
JobHistoryServer
NameNode
NodeManager
ResourceManager
SecondaryNameNode
hadoop@team-32-nn:~/hadoop-3.4.0$ exit
```

### 3. Проверка YARN
```bash
hadoop@team-32-en:~$ yarn node -list
## Вывод включает:
Total Nodes:3
...

# тестовая задача
hadoop@team-32-en:~$ yarn jar hadoop-3.4.0/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.0.jar pi 3 100
## Вывод включает:
...
Job ... completed successfully
...
Estimated value of Pi is 3.16000000000000000000
```

### 4. Публикация веб-интерфейсов через nginx
```bash
hadoop@team-32-en:~$ exit
team@team-32-en:~$ sudo apt install nginx -y

team@team-32-en:~$ sudo vim /etc/nginx/sites-available/hadoop # копируем содержимое из config/nginx-hadoop.conf
team@team-32-en:~$ sudo ln -s /etc/nginx/sites-available/hadoop /etc/nginx/sites-enabled/hadoop
team@team-32-en:~$ sudo rm /etc/nginx/sites-enabled/default

team@team-32-en:~$ sudo nginx -t
team@team-32-en:~$ sudo systemctl restart nginx
```

Порты на edge-ноде:
```
9870  - NameNode
8088  - ResourceManager
19888 - JobHistory
9868  - SecondaryNameNode
8042  - NodeManager team-32-nn
8043  - NodeManager team-32-00
8044  - NodeManager team-32-01
9864  - DataNode team-32-nn
9865  - DataNode team-32-00
9866  - DataNode team-32-01
```

nginx слушает только localhost edge-ноды.

### 5. Проверка
```bash
team@team-32-en:~$ curl -s -L -o /dev/null -w "%{http_code}\n" http://localhost:8088/
## Вывод:
200
team@team-32-en:~$ exit
```

Пробрасываем порты на свой компьютер:
```bash
t.i@MacBook-Air-Timur ~ % ssh -L 9870:localhost:9870 -L 8088:localhost:8088 -L 19888:localhost:19888 -L 9868:localhost:9868 -L 8042:localhost:8042 -L 8043:localhost:8043 -L 8044:localhost:8044 -L 9864:localhost:9864 -L 9865:localhost:9865 -L 9866:localhost:9866 team@111.88.128.31
```
В браузере: `http://localhost:<порт>`.

### Автоматический запуск
Все шаги выполняет скрипт `script_hw2.sh`:
```bash
team@team-32-en:~$ ./script_hw2.sh
```
