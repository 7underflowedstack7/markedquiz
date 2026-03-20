"""remove txt files from database

Revision ID: b9675e7dd698
Revises: a7e2f4bc1d09
Create Date: 2026-03-19 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


revision: str = 'b9675e7dd698'
down_revision: Union[str, Sequence[str], None] = 'a7e2f4bc1d09'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("DELETE FROM files WHERE extension = 'txt'")


def downgrade() -> None:
    pass
