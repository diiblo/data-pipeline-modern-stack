## 🚀 Étape 3 – Lecture du fichier avec Spark

---

### 🎯 Objectif pédagogique

Tu vas :
- Lire un fichier distant dans MinIO (S3) depuis Spark
- Comprendre la configuration S3A dans Spark
- Utiliser un `DataFrame` Spark pour inspecter et transformer les données

---

## 🧠 Ce que tu dois savoir avant de coder

### 🔹 Comment Spark accède à MinIO :
Spark utilise un **connecteur S3A** (déjà dans ton image via `hadoop-aws`)  
Mais il a besoin de :
- `endpoint` MinIO
- Access/secret keys
- Type d’accès (`path-style` pour MinIO)

---

## ✅ Code Spark complet pour lire ton fichier

📁 Place ce code dans un **Notebook** (`notebooks/lecture_ecommerce.ipynb`)  
ou dans un script `spark_jobs/read_raw_ecommerce.py`

```python
from pyspark.sql import SparkSession
from dotenv import load_dotenv
import os

# Charger les variables d’environnement (.env)
load_dotenv()

# Récupérer les identifiants depuis .env
minio_endpoint = os.getenv("MINIO_ENDPOINT", "minio:9000")
minio_access_key = os.getenv("MINIO_ACCESS_KEY", "admin")
minio_secret_key = os.getenv("MINIO_SECRET_KEY", "admin123")
bucket = os.getenv("MINIO_BUCKET", "datalake")

# Initialisation de la SparkSession
spark = SparkSession.builder \
    .appName("ReadEcommerceRawFromMinIO") \
    .master("spark://spark-master:7077") \
    .config("spark.hadoop.fs.s3a.endpoint", f"http://{minio_endpoint}") \
    .config("spark.hadoop.fs.s3a.access.key", minio_access_key) \
    .config("spark.hadoop.fs.s3a.secret.key", minio_secret_key) \
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
    .getOrCreate()

# 📄 Lecture du fichier CSV (dans le bucket 'datalake')
df = spark.read \
    .option("header", True) \
    .option("inferSchema", True) \
    .csv("s3a://datalake/raw/ecommerce/ecommerce.csv")

# 🧪 Aperçu
df.printSchema()
df.show(5, truncate=False)
```

---

## ✅ Ce que tu dois voir s'afficher :

- Le **schéma** inféré par Spark (types, colonnes comme `InvoiceNo`, `Quantity`, `UnitPrice`, etc.)
- Les **5 premières lignes**

---

## 🧠 À comprendre ici :

| Élément Spark                            | Ce que ça fait                                |
|-----------------------------------------|-----------------------------------------------|
| `s3a://...`                              | Accès à un fichier via S3 API                 |
| `.option("inferSchema", True)`           | Laisse Spark deviner les types des colonnes   |
| `.option("header", True)`                | Utilise la première ligne comme noms de colonnes |
| `printSchema()`                          | Affiche les types inférés par Spark           |
| `show()`                                 | Affiche un aperçu des données                 |