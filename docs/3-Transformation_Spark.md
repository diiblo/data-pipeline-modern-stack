## ✅ **Étape 3 – Lecture & Nettoyage Brut**

### 🎯 Objectif :
Lire un fichier CSV *sans en-tête*, encodé en `ISO-8859-1`, depuis **MinIO (S3)**, et nettoyer une première ligne parasite pour structurer les données.

---

### 🔧 Problèmes rencontrés :

1. Le fichier n'a **pas de ligne d'en-tête** → Spark attribue automatiquement des colonnes `_c0`, `_c1`, etc.
2. La première ligne du fichier contient `SET,2,9/5/2011...`, qui n'est **pas une vraie ligne de données**.
3. Le fichier est encodé en `ISO-8859-1` (important pour Spark, sinon caractères spéciaux posent problème).

---

### 🛠️ Étapes de traitement :

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import split, col
from dotenv import load_dotenv
import os

# Charger les variables d’environnement (.env)
load_dotenv()

# Récupérer les identifiants depuis .env
minio_endpoint = os.getenv("MINIO_ENDPOINT")
minio_access_key = os.getenv("MINIO_ACCESS_KEY")
minio_secret_key = os.getenv("MINIO_SECRET_KEY")
bucket = os.getenv("MINIO_BUCKET")

# Initialisation de la SparkSession
spark = SparkSession.builder \
    .appName("TransformEcommerceData") \
    .master("spark://spark-master:7077") \
    .config("spark.hadoop.fs.s3a.endpoint", f"http://{minio_endpoint}") \
    .config("spark.hadoop.fs.s3a.access.key", minio_access_key) \
    .config("spark.hadoop.fs.s3a.secret.key", minio_secret_key) \
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()
```

```python
# 1️⃣ Lecture brute
raw_df = spark.read \
    .option("encoding", "ISO-8859-1") \
    .text(f"s3a://{bucket}/raw/ecommerce/ecommerce.csv")

# 2️⃣ Supprimer les lignes parasites (SET avec espaces, BOM, etc.)
filtered_df = raw_df.filter(~col("value").rlike(r"(?i)^.*\bSET\b.*")) \
                    .filter(col("value").isNotNull()) \
                    .filter(~col("value").rlike(r"^\s*$"))

# 3️⃣ Split manuel sur les virgules
split_df = filtered_df.withColumn("splitted", split(col("value"), ","))

# 4️⃣ Créer les vraies colonnes (on repart uniquement de 'split_df')
df = split_df.select(
    col("splitted")[0].alias("InvoiceNo"),
    col("splitted")[1].alias("StockCode"),
    col("splitted")[2].alias("Description"),
    col("splitted")[3].cast("int").alias("Quantity"),
    col("splitted")[4].alias("InvoiceDate"),
    col("splitted")[5].cast("float").alias("UnitPrice"),
    col("splitted")[6].alias("CustomerID"),
    col("splitted")[7].alias("Country")
)

# 5️⃣ Aperçu
df.printSchema()
df.show(5, truncate=False)
```

---

### ✅ Résultat attendu :
- Tu obtiens un `DataFrame` structuré prêt pour les **transformations analytiques**.
- La ligne parasite est éliminée.
- Les types (`int`, `float`) sont correctement castés.

---

### 🎓 Ce que tu dois retenir :
- Pour les fichiers *mal formés* (absence d'en-tête, encodage exotique), tu dois souvent lire ligne par ligne (`.text()`), puis parser toi-même.
- Spark ne gère pas bien les "métadonnées" parasites → d’où le filtrage par `startswith("SET")`.