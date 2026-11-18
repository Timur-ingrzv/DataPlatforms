# Инструкция для запуска процесса обработки данных в Prefect

Предусловия: работающие HDFS, YARN, Hive, Spark, CSV таблицы transactions_staging

Используемые файлы:

- flow.py - процесс на Prefect
- create_table.sql - запрос Hive, создающий партиционированную таблицу

### 1. Подготовка
Кладем файлы flow.py, create_table.sql в папку hw5 и копируем ее на edge-ноду, передаем пользователю hadoop.
```bash
scp -r hw5 team@111.88.128.31:/home/team/
ssh team@111.88.128.31

team@team-32-en:~$ sudo mkdir -p /home/hadoop/hw5
team@team-32-en:~$ sudo cp /home/team/hw5/{flow.py,create_table.sql} /home/hadoop/hw5/
team@team-32-en:~$ sudo chown -R hadoop:hadoop /home/hadoop/hw5
```

### 2. Установка Prefect
```bash
team@team-32-en:~$ sudo apt install -y python3-venv
team@team-32-en:~$ sudo -i -u hadoop
hadoop@team-32-en:~$ cd hw5
hadoop@team-32-en:~/hw5$ python3 -m venv venv
hadoop@team-32-en:~/hw5$ source venv/bin/activate
(venv) hadoop@team-32-en:~/hw5$ pip install prefect
```

### 3. Запуск процесса
Процесс `flow.py` состоит из задач:
1. start_spark - сессия Spark на YARN
2. check_hdfs - подключение к HDFS и проверка, что данные на месте
3. read_data - чтение CSV из HDFS
4. transform - приведение типов, очистка, фильтрация и агрегация (количество, сумма и среднее по штату и категории)
5. save_partitioned, create_table - запись в HDFS в формате Parquet с партиционированием по штату и создание таблицы Hive
6. check_table - чтение таблицы через beeline и проверка

```bash
(venv) hadoop@team-32-en:~/hw5$ python flow.py
```
В выводе у каждой задачи Finished in state Completed()

### 4. Проверка
check_table во время выполнения процесса должен был вывести 47 партиций.

Подставить application_id из вывода выше (в первых строчках YARN application ID: application_id)
```bash
(venv) hadoop@team-32-en:~/hw5$ yarn application -status application_id
# State : FINISHED
# Final-State : SUCCEEDED
```
