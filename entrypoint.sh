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
  
  # Lancer Spark master en tant que jovyan
  su $NB_USER -c "/usr/local/spark/sbin/start-master.sh"

  # Lancer le notebook avec environnement Conda activé
  start-notebook.sh --NotebookApp.token=''

elif [ "$SPARK_MODE" == "worker" ]; then
  echo "🟢 Démarrage Spark Worker"
  
  # Attendre que le master soit prêt
  until nc -z spark-master 7077; do
    echo "⏳ En attente de spark-master:7077..."
    sleep 2
  done

  su $NB_USER -c "/usr/local/spark/sbin/start-worker.sh spark://spark-master:7077"
  tail -f /dev/null

else
  echo "⚪ Mode inconnu, lancement Notebook seul"
  start-notebook.sh --NotebookApp.token=''
fi