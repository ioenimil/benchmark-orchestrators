import os

from sqlmodel import Session, SQLModel, create_engine


def _database_url() -> str:
    # Local dev (docker-compose) sets DATABASE_URL directly.
    # ECS/EKS inject individual vars; DB_PASSWORD comes from Secrets Manager.
    if url := os.environ.get("DATABASE_URL"):
        return url
    host = os.environ["DB_HOST"]
    port = os.environ.get("DB_PORT", "5432")
    name = os.environ["DB_NAME"]
    user = os.environ["DB_USER"]
    password = os.environ["DB_PASSWORD"]
    return f"postgresql+psycopg://{user}:{password}@{host}:{port}/{name}"


engine = create_engine(_database_url())


def create_db_and_tables() -> None:
    SQLModel.metadata.create_all(engine)


def get_session():
    with Session(engine) as session:
        yield session
