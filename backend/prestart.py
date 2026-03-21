"""Ensure alembic_version is stamped before running migrations.

On first deploy, the DB was built by create_all (not alembic), so
alembic_version doesn't exist. This script stamps it at the last
known migration so `alembic upgrade head` only runs new migrations.
"""

import asyncio
import subprocess

from sqlalchemy import text

from app.database import engine

# Last migration that matches what create_all already built
BASELINE_REVISION = "c3a8d1f2e456"


async def stamp_if_needed():
    async with engine.connect() as conn:
        result = await conn.execute(
            text(
                "SELECT EXISTS ("
                "  SELECT FROM information_schema.tables "
                "  WHERE table_name = 'alembic_version'"
                ")"
            )
        )
        exists = result.scalar()

    if not exists:
        print(f"No alembic_version table — stamping at {BASELINE_REVISION}")
        subprocess.run(["alembic", "stamp", BASELINE_REVISION], check=True)
    else:
        print("alembic_version exists — skipping stamp")


asyncio.run(stamp_if_needed())
