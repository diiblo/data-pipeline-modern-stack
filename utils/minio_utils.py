import os
import boto3
from botocore.exceptions import ClientError
from dotenv import load_dotenv
load_dotenv()

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
        local_file_path="data/ecommerce.csv",
        object_path="raw/ecommerce/ecommerce.csv"
    )