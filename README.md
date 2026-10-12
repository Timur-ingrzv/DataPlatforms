# DataPlatforms

- [hw1](hw1/instruction.md) — развертывание HDFS
- [hw2](hw2/instruction.md) — развертывание YARN и публикация веб-интерфейсов

## Как посмотреть веб-интерфейсы кластера

Интерфейсы опубликованы через nginx на localhost edge-ноды. Чтобы открыть их у себя, пробрасываем порты по ssh:
```bash
ssh -L 9870:localhost:9870 -L 8088:localhost:8088 -L 19888:localhost:19888 -L 9868:localhost:9868 -L 8042:localhost:8042 -L 8043:localhost:8043 -L 8044:localhost:8044 -L 9864:localhost:9864 -L 9865:localhost:9865 -L 9866:localhost:9866 team@111.88.128.31
```
Пока ssh-сессия открыта, интерфейсы доступны в браузере:

| Адрес | Интерфейс |
|---|---|
| http://localhost:9870 | NameNode (HDFS) |
| http://localhost:8088 | ResourceManager (YARN) |
| http://localhost:19888 | JobHistory |
| http://localhost:9868 | SecondaryNameNode |
| http://localhost:8042 | NodeManager team-32-nn |
| http://localhost:8043 | NodeManager team-32-00 |
| http://localhost:8044 | NodeManager team-32-01 |
| http://localhost:9864 | DataNode team-32-nn |
| http://localhost:9865 | DataNode team-32-00 |
| http://localhost:9866 | DataNode team-32-01 |

Если нужен только один интерфейс, достаточно одного порта:
```bash
ssh -L 8088:localhost:8088 team@111.88.128.31
```
