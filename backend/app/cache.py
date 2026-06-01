import json
import logging
import os
from typing import Optional

import redis
from sqlmodel import Session, select

from .models import Name

logger = logging.getLogger(__name__)

CACHE_KEY = "names:all"
TTL = 30

_redis_client: Optional[redis.Redis] = None


def get_redis() -> redis.Redis:
    global _redis_client
    if _redis_client is None:
        _redis_client = redis.Redis(
            host=os.environ.get("REDIS_HOST", "localhost"),
            port=int(os.environ.get("REDIS_PORT", "6379")),
            decode_responses=True,
        )
    return _redis_client


def get_names_cached(session: Session) -> list:
    r = get_redis()
    try:
        cached = r.get(CACHE_KEY)
        if cached is not None:
            logger.info("CACHE HIT for %s", CACHE_KEY)
            return json.loads(cached)
        logger.info("CACHE MISS for %s", CACHE_KEY)
    except redis.RedisError as exc:
        logger.warning("Redis unavailable (%s), falling back to Postgres", exc)
        return _query_db(session)

    names = _query_db(session)
    try:
        r.setex(CACHE_KEY, TTL, json.dumps(names))
    except redis.RedisError as exc:
        logger.warning("Redis unavailable, could not cache result: %s", exc)
    return names


def _query_db(session: Session) -> list:
    rows = session.exec(select(Name).order_by(Name.id)).all()
    return [
        {"id": n.id, "name": n.name, "created_at": n.created_at.isoformat()}
        for n in rows
    ]


def invalidate_names_cache() -> None:
    try:
        get_redis().delete(CACHE_KEY)
    except redis.RedisError as exc:
        logger.warning("Redis unavailable, cache not invalidated: %s", exc)
