# ⚙️ Étape 1 – Mise en place de l’architecture Dockerisée

Cette première étape vise à créer un environnement Big Data local permettant de simuler un Data Lake avec traitement distribué et orchestration automatisée. On utilise Docker pour contenir et orchestrer les différents services nécessaires.

---

## 🎯 Objectif

Construire une architecture capable de :
- Stocker des fichiers bruts (CSV, JSON) dans un système objet (MinIO = S3 local)
- Traiter ces fichiers avec Apache Spark (cluster distribué)
- Orchestrer les jobs Spark avec Airflow
- Développer et tester facilement via Jupyter Notebook

---

## 🛠️ Services Docker utilisés

| Service        | Rôle                                                         | Port(s)         |
|----------------|--------------------------------------------------------------|-----------------|
| `spark-master` | Nœud principal Spark pour soumettre les jobs                 | `8887`, `8888`  |
| `spark-worker` | Nœuds esclaves Spark qui exécutent les tâches                |                 |
| `minio`        | Alternative locale à AWS S3 pour stocker les données brutes  | `9000`, `9001`  |
| `airflow`      | Orchestration des jobs Spark (scheduling + UI)               | `8081`          |
| `jupyter`      | (Inclus dans spark-master) Interface Notebook pour tester    | `8888`          |

---

## 📦 Étapes de mise en place

### 1. Créer le réseau Docker

Permet aux conteneurs de communiquer entre eux :
```bash
docker network create --driver bridge datalake-cluster
```

---

### 2. Créer l’image Docker personnalisée Spark

Créer un fichier `Dockerfile` avec les connecteurs Spark ↔ MinIO (S3), Delta Lake, etc.

```dockerfile
FROM jupyter/all-spark-notebook

USER root

# Installer des outils système
RUN apt-get update && apt-get install -y curl git

# Ajouter des connecteurs JDBC, Kafka, Mongo, AWS
RUN curl -o /usr/local/spark/jars/postgresql-42.6.0.jar https://jdbc.postgresql.org/download/postgresql-42.6.0.jar && \
    curl -o /usr/local/spark/jars/mysql-connector-java-8.0.34.jar https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.34/mysql-connector-java-8.0.34.jar && \
    curl -o /usr/local/spark/jars/spark-sql-kafka-0-10_2.12-3.4.0.jar https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_2.12/3.4.0/spark-sql-kafka-0-10_2.12-3.4.0.jar && \
    curl -o /usr/local/spark/jars/mongo-spark-connector_2.12-10.2.0.jar https://repo1.maven.org/maven2/org/mongodb/spark/mongo-spark-connector_2.12/10.2.0/mongo-spark-connector_2.12-10.2.0.jar && \
    curl -o /usr/local/spark/jars/hadoop-aws-3.3.6.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.6/hadoop-aws-3.3.6.jar

# Installer les bibliothèques Python
RUN pip install psycopg2-binary kafka-python boto3 delta-spark python-dotenv

# Script pour lancer Spark selon SPARK_MODE
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER root
ENTRYPOINT ["/entrypoint.sh"]
```

---

### 3. Le fichier `entrypoint.sh` (automatisation Spark)

Ce script permet de :
- Configurer Spark (via spark-env.sh)
- Créer les dossiers de logs
- Lancer Spark master, worker ou notebook automatiquement

```bash
#!/bin/bash

# Créer les logs si besoin
mkdir -p /usr/local/spark/logs
chown -R $NB_UID:$NB_GID /usr/local/spark/logs

# Configuration Spark
echo "SPARK_MASTER_HOST='spark-master'" >> /usr/local/spark/conf/spark-env.sh
echo "SPARK_WORKER_CORES=2" >> /usr/local/spark/conf/spark-env.sh
echo "SPARK_WORKER_MEMORY=1g" >> /usr/local/spark/conf/spark-env.sh

if [ "$SPARK_MODE" == "master" ]; then
  echo "🔵 Démarrage Spark Master + Jupyter Notebook"

  # Lancer Spark master en arrière-plan en tant que jovyan
  su $NB_USER -c "/usr/local/spark/sbin/start-master.sh"

  # Lancer le notebook avec environnement Conda activé
  start-notebook.sh --NotebookApp.token=''

elif [ "$SPARK_MODE" == "worker" ]; then
  echo "🟢 Démarrage Spark Worker"
  su $NB_USER -c "/usr/local/spark/sbin/start-worker.sh spark://spark-master:7077"
  tail -f /dev/null

else
  echo "⚪ Mode inconnu, lancement Notebook seul"
  start-notebook.sh --NotebookApp.token=''
fi
```

---

### 4. Le fichier `docker-compose.yml`

Orchestre tous les services et monte les bons ports.

```yaml
services:
  minio:
    image: minio/minio
    container_name: minio
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ACCESS_KEY: admin
      MINIO_SECRET_KEY: admin123
    command: server /data --console-address ":9001"
    volumes:
      - ./minio_data:/data
    networks:
      - datalake-cluster

  spark-master:
    image: datascience-env
    container_name: spark-master
    ports:
      - "8888:8888"  # Jupyter Notebook
      - "8887:8080"  # Spark UI
      - "4040:4040"  # Spark Job UI
      - "7077:7077"  # Communication worker/master
    environment:
      - SPARK_MODE=master
    networks:
      - datalake-cluster
    command: /entrypoint.sh

  spark-worker1:
    image: datascience-env
    container_name: spark-worker1
    environment:
      - SPARK_MODE=worker
    networks:
      - datalake-cluster
    command: /entrypoint.sh

  spark-worker2:
    image: datascience-env
    container_name: spark-worker2
    environment:
      - SPARK_MODE=worker
    networks:
      - datalake-cluster
    command: /entrypoint.sh

  airflow:
    image: apache/airflow:2.7.3-python3.10
    container_name: airflow
    restart: always
    environment:
      AIRFLOW__CORE__EXECUTOR: SequentialExecutor
      AIRFLOW__CORE__FERNET_KEY: ''
      AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION: 'true'
      AIRFLOW__CORE__LOAD_EXAMPLES: 'false'
      AIRFLOW__CORE__SQL_ALCHEMY_CONN: sqlite:////opt/airflow/airflow.db
      AIRFLOW__WEBSERVER__AUTH_BACKEND: airflow.www.security.auth_backend.password_auth
      _AIRFLOW_WWW_USER_USERNAME: admin
      _AIRFLOW_WWW_USER_PASSWORD: admin123
    volumes:
      - ./dags:/opt/airflow/dags
    ports:
      - "8081:8080"
    command: >
      bash -c "airflow db init &&
               airflow users create --username admin --password admin123 --firstname Admin --lastname User --role Admin --email admin@example.com &&
               airflow webserver"
    networks:
      - datalake-cluster

networks:
  datalake-cluster:
    external: true
```

---

### 5. Démarrer le cluster

```bash
docker compose up -d
```

---

### 6. Vérifications

| Interface         | URL                   |
|------------------|------------------------|
| MinIO Console     | http://localhost:9001 |
| Spark Master UI   | http://localhost:8887 |
| Spark Job UI      | http://localhost:4040 |
| Jupyter Notebook  | http://localhost:8888 |
| Airflow Web UI    | http://localhost:8081 |

---

## ✅ Résultat attendu

À la fin de cette étape :
- Tous les services sont lancés et opérationnels
- Spark Master et Notebook sont lancés automatiquement
- Tu es prêt pour [l’étape 2 : chargement des données dans MinIO](./2-Chargement_MinIO.md)