"""add memory table

Revision ID: e5c3b0d9a234
Revises: d4b2a9c8f123
Create Date: 2026-03-23 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = 'e5c3b0d9a234'
down_revision: Union[str, Sequence[str], None] = 'd4b2a9c8f123'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'memories',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_memories_id', 'memories', ['id'])
    op.create_index('ix_memories_user_id', 'memories', ['user_id'])


def downgrade() -> None:
    op.drop_table('memories')
