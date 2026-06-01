import logging

from sqlmodel import Session, select

from .models import Name

logger = logging.getLogger(__name__)

SEED_NAMES = [
    "Alan Turing",
    "Grace Hopper",
    "Linus Torvalds",
    "Dennis Ritchie",
    "Margaret Hamilton",
    "Donald Knuth",
    "Barbara Liskov",
    "Edsger Dijkstra",
    "Tim Berners-Lee",
    "Ken Thompson",
]


def idempotent_seed(session: Session) -> None:
    existing = session.exec(select(Name)).first()
    if existing is not None:
        logger.info("Seed skipped — names already present")
        return
    for name_str in SEED_NAMES:
        session.add(Name(name=name_str))
    session.commit()
    logger.info("Seeded %d names", len(SEED_NAMES))
