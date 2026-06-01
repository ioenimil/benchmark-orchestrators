import logging
from contextlib import asynccontextmanager
from typing import Any

import redis as redis_lib
from fastapi import Depends, FastAPI, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import text
from sqlmodel import Session

from .cache import get_names_cached, get_redis, invalidate_names_cache
from .database import create_db_and_tables, engine, get_session
from .models import Name
from .seed import idempotent_seed

logging.basicConfig(level=logging.INFO, format="%(levelname)s  %(name)s  %(message)s")
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    create_db_and_tables()
    with Session(engine) as session:
        idempotent_seed(session)
    yield


app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class NameCreate(BaseModel):
    name: str


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.get("/readyz")
def readyz(session: Session = Depends(get_session)) -> dict:
    errors: list[str] = []

    try:
        session.execute(text("SELECT 1"))
    except Exception as exc:
        errors.append(f"postgres: {exc}")

    try:
        get_redis().ping()
    except redis_lib.RedisError as exc:
        errors.append(f"redis: {exc}")

    if errors:
        raise HTTPException(status_code=503, detail={"errors": errors})
    return {"status": "ok"}


@app.get("/names")
def list_names(session: Session = Depends(get_session)) -> Any:
    return get_names_cached(session)


@app.post("/names", status_code=201)
def create_name(body: NameCreate, session: Session = Depends(get_session)) -> Name:
    name = body.name.strip()
    if not name:
        raise HTTPException(status_code=422, detail="name must not be blank")
    record = Name(name=name)
    session.add(record)
    session.commit()
    session.refresh(record)
    invalidate_names_cache()
    return record


@app.delete("/names/{name_id}", status_code=204)
def delete_name(name_id: int, session: Session = Depends(get_session)) -> Response:
    record = session.get(Name, name_id)
    if not record:
        raise HTTPException(status_code=404, detail="name not found")
    session.delete(record)
    session.commit()
    invalidate_names_cache()
    return Response(status_code=204)
