#!/bin/bash

# Création des logs Spark
mkdir -p /usr/local/spark/logs
chown -R $NB_UID:$NB_GID /usr/local/spark/logs

# Configuration de Spark
echo "SPARK_MASTER_HOST='spark-master'" >> /usr/local/spark/conf/spark-env.sh
echo "SPARK_WORKER_CORES=2" >> /usr/local/spark/conf/spark-env.sh
echo "SPARK_WORKER_MEMORY=1g" >> /usr/local/spark/conf/spark-env.sh

if [ "$SPARK_MODE" = "master" ]; then
  echo "🔵 Lancement Spark Master + Jupyter Notebook"
  /usr/local/spark/sbin/start-master.sh
  start-notebook.sh --NotebookApp.token=''

elif [ "$SPARK_MODE" = "worker" ]; then
  echo "🟢 Lancement Spark Worker"
  echo "⌛ Attente que spark-master:7077 soit prêt..."

  # Vérifie que netcat est bien installé
  if ! command -v nc &> /dev/null; then
    echo "❌ Netcat (nc) n'est pas installé. Installer via apt-get."
    exit 1
  fi

  until nc -z spark-master 7077; do
    echo "⏳ spark-master:7077 non disponible, nouvelle tentative..."
    sleep 2
  done

  echo "✅ spark-master détecté, lancement du Worker..."
  /usr/local/spark/sbin/start-worker.sh spark://spark-master:7077

  # Garder le container actif
  tail -f /dev/null


else
  echo "⚪ Aucun SPARK_MODE défini. Lancement Notebook seul"
  start-notebook.sh --NotebookApp.token=''
fi
