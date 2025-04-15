# Utiliser l'image de base Jupyter avec Spark
FROM jupyter/all-spark-notebook

USER root

# Installer des outils système
RUN apt-get update && apt-get install -y curl git netcat

# Ajouter des connecteurs JDBC (Au choix)
RUN curl -o /usr/local/spark/jars/postgresql-42.6.0.jar https://jdbc.postgresql.org/download/postgresql-42.6.0.jar && \
   curl -o /usr/local/spark/jars/mysql-connector-java-8.0.34.jar https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.34/mysql-connector-java-8.0.34.jar && \
   curl -o /usr/local/spark/jars/spark-sql-kafka-0-10_2.12-3.4.0.jar https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_2.12/3.4.0/spark-sql-kafka-0-10_2.12-3.4.0.jar && \
   curl -o /usr/local/spark/jars/mongo-spark-connector_2.12-10.2.0.jar https://repo1.maven.org/maven2/org/mongodb/spark/mongo-spark-connector_2.12/10.2.0/mongo-spark-connector_2.12-10.2.0.jar && \
   curl -o /usr/local/spark/jars/hadoop-aws-3.3.1.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.1/hadoop-aws-3.3.1.jar && \
   curl -o /usr/local/spark/jars/hadoop-common-3.3.1.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-common/3.3.1/hadoop-common-3.3.1.jar && \
   curl -o /usr/local/spark/jars/aws-java-sdk-bundle-1.11.1026.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.11.1026/aws-java-sdk-bundle-1.11.1026.jar

# Installer des bibliothèques Python
RUN pip install psycopg2-binary kafka-python boto3 python-dotenv
RUN pip install --default-timeout=300 delta-spark

# Fichier Shell pour lancer Spark
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Commande par défaut
ENTRYPOINT ["/entrypoint.sh"]