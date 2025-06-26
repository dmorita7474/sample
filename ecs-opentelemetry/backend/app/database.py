
import os
import json
import boto3
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# --- Database Connection Setup ---

DB_HOST = os.environ.get("DB_HOST")
DB_NAME = os.environ.get("DB_NAME")
SECRET_ARN = os.environ.get("DB_CREDENTIALS_SECRET_ARN")

def get_db_credentials():
    """Fetches database credentials from AWS Secrets Manager."""
    if not SECRET_ARN:
        raise ValueError("DB_CREDENTIALS_SECRET_ARN environment variable not set.")

    session = boto3.session.Session()
    client = session.client(service_name='secretsmanager', region_name='ap-northeast-1')
    
    try:
        get_secret_value_response = client.get_secret_value(SecretId=SECRET_ARN)
    except Exception as e:
        raise Exception(f"Failed to retrieve secret from Secrets Manager: {e}")
    else:
        secret = get_secret_value_response['SecretString']
        return json.loads(secret)

# Construct the database URL
if all([DB_HOST, DB_NAME, SECRET_ARN]):
    credentials = get_db_credentials()
    DB_USER = credentials['username']
    DB_PASSWORD = credentials['password']
    SQLALCHEMY_DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}"
    engine = create_engine(SQLALCHEMY_DATABASE_URL)
else:
    # Fallback for local development or testing without AWS integration
    SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"
    engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# --- Dependency for FastAPI ---

def get_db():
    """FastAPI dependency to get a DB session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
