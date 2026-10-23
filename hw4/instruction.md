# Инструкция для обработки данных Apache Spark под управлением YARN

### 1. Подготовка

Копируем задание на edge-ноду:
```bash
scp -r hw4 team@111.88.128.31:/home/team/
ssh team@111.88.128.31
```

Переходим к пользователю hadoop:
```bash
team@team-32-en:~$ sudo mkdir -p /home/hadoop/hw4
team@team-32-en:~$ sudo cp /home/team/hw4/{instruction.md,script_hw4.sh,transform.py,create_table.sql} /home/hadoop/hw4/
team@team-32-en:~$ sudo chown -R hadoop:hadoop /home/hadoop/hw4
team@team-32-en:~$ sudo -i -u hadoop
hadoop@team-32-en:~$ cd /home/hadoop/hw4
```

На всех узлах нужны одинаковые версии Python 3.8+ (`/usr/bin/python3`) и Java 11 (`/usr/lib/jvm/java-11-openjdk-amd64`). На edge — интернет. Пользователю hadoop нужны права чтения источника и записи результата в HDFS.

### 2. Подключение к HDFS

Источник — CSV таблицы `transactions_staging` из hw3. Проверяем `Location`:
```bash
hadoop@team-32-en:~/hw4$ /home/hadoop/apache-hive-4.0.0-alpha-2-bin/bin/beeline -u jdbc:hive2://team-32-en:5433/default -n scott -p tiger -e 'DESCRIBE FORMATTED default.transactions_staging;'
hadoop@team-32-en:~/hw4$ /home/hadoop/hadoop-3.4.0/bin/hdfs dfs -ls hdfs://team-32-nn:9000/user/hive/warehouse/transactions_staging
```

CSV должен содержать заголовок и 17 колонок в порядке из hw3. Исходные данные не изменяются.

### 3. Запуск Spark на YARN

Скрипт скачивает Spark 3.5.8 и выполняет все шаги:
```bash
hadoop@team-32-en:~/hw4$ bash script_hw4.sh
```

Если `Location` отличается, указываем фактический путь:
```bash
hadoop@team-32-en:~/hw4$ INPUT_PATH=hdfs://team-32-nn:9000/actual/csv/directory bash script_hw4.sh
```

Запуск: `spark-submit --master yarn --deploy-mode client`. Драйвер — на edge, executors — в YARN. SSH не закрываем до завершения.

Конфигурация HDFS и YARN берется из `/home/hadoop/hadoop-3.4.0/etc/hadoop`. Сессия создается в `transform.py`.

### 4. Чтение и трансформации

`transform.py` читает CSV из HDFS и выполняет:
- Приведение `amount` к `DECIMAL(18,2)`.
- Очистку пробелов и перевод штата в верхний регистр.
- Фильтрацию некорректных значений.
- Подсчет количества, суммы и среднего по штату и категории.

### 5. Партиционирование

Результат записывается в Parquet через `partitionBy('us_state')`:
```text
/user/hadoop/hw4/transactions_summary_<run_id>/
    us_state=CA/part-....snappy.parquet
    us_state=NY/part-....snappy.parquet
```

Каждый запуск создает отдельный каталог.

### 6. Сохранение таблицы

`create_table.sql` создает внешнюю таблицу `hw4.transactions_summary_<run_id>` поверх Parquet. `MSCK REPAIR TABLE` регистрирует партиции.

### 7. Проверка чтения через Hive

Скрипт автоматически выполняет `SHOW PARTITIONS`, `DESCRIBE FORMATTED` и `SELECT` через Beeline.

Для ручной проверки:
```bash
hadoop@team-32-en:~/hw4$ /home/hadoop/apache-hive-4.0.0-alpha-2-bin/bin/beeline -u jdbc:hive2://team-32-en:5433/default -n scott -p tiger
```

Подставляем имя таблицы из вывода скрипта:
```sql
SHOW TABLES IN hw4;
SHOW PARTITIONS hw4.transactions_summary_<run_id>;
SELECT * FROM hw4.transactions_summary_<run_id> LIMIT 10;
```

`<run_id>` заменяем фактическим значением.
