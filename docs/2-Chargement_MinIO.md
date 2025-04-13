## 🧩 Étape 2 – Chargement des données dans MinIO (`raw/`)

---

### 🎯 Objectif pédagogique

Tu vas apprendre à :
- Créer un bucket et des dossiers logiques dans MinIO
- Uploader un fichier via Python (`boto3`)
- Comprendre **comment fonctionne un Data Lake sur S3/MinIO**
- Valider l’intégration entre Python ↔ MinIO (comme avec AWS)

---

## ✅ Étapes détaillées de ce qu'on va faire

| Étape | Ce que tu fais | Tu dois comprendre |
|-------|----------------|--------------------|
| 1️⃣ | Créer le bucket `datalake` | C'est la racine de ton Data Lake |
| 2️⃣ | Créer le dossier `raw/ecommerce/` | C'est ta zone d’ingestion |
| 3️⃣ | Uploader `data/ecommerce.csv` | Tu simules un flux entrant |
| 4️⃣ | Vérifier sur l’UI MinIO (`localhost:9001`) | Pour valider ce que tu fais |

---

## ⚙️ Script Python : `utils/minio_utils.py`

Voici un **script complet, commenté ligne par ligne**, pour t'aider à comprendre et **réutiliser seul** :

```python
import os
import boto3
from botocore.exceptions import ClientError

# Charger les variables d'environnement
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY")
MINIO_BUCKET = os.getenv("MINIO_BUCKET")

# Initialiser la connexion MinIO
def connect_minio():
    session = boto3.session.Session()
    client = session.client(
        service_name="s3",
        endpoint_url=f"http://{MINIO_ENDPOINT}",
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY
    )
    return client

# Créer le bucket s’il n’existe pas
def create_bucket_if_not_exists(client, bucket_name):
    try:
        client.head_bucket(Bucket=bucket_name)
        print(f"✅ Bucket '{bucket_name}' déjà existant.")
    except ClientError:
        client.create_bucket(Bucket=bucket_name)
        print(f"🪣 Bucket '{bucket_name}' créé.")

# Uploader un fichier
def upload_file_to_minio(local_file_path, object_path):
    client = connect_minio()
    create_bucket_if_not_exists(client, MINIO_BUCKET)
    
    with open(local_file_path, "rb") as f:
        client.upload_fileobj(f, MINIO_BUCKET, object_path)
        print(f"📤 Fichier '{local_file_path}' → '{MINIO_BUCKET}/{object_path}'")

# Exemple d’utilisation
if __name__ == "__main__":
    upload_file_to_minio(
        local_file_path="../data/ecommerce.csv",
        object_path="raw/ecommerce/ecommerce.csv"
    )
```

---

### ✅ Résultat attendu :

- Sur http://localhost:9001 (MinIO), tu verras :
  ```
  Bucket : datalake
    └── raw/
        └── ecommerce/
            └── ecommerce.csv
  ```