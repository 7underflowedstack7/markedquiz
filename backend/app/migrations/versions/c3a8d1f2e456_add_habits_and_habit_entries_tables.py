"""add habits and habit_entries tables

Revision ID: c3a8d1f2e456
Revises: b9675e7dd698
Create Date: 2026-03-20 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = 'c3a8d1f2e456'
down_revision: Union[str, Sequence[str], None] = 'b9675e7dd698'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'habits',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('title', sa.String(255), nullable=False),
        sa.Column('description', sa.Text(), server_default=''),
        sa.Column('icon', sa.String(100), server_default='flame.fill'),
        sa.Column('color', sa.String(20), server_default='teal'),
        sa.Column('frequency', sa.String(20), server_default='daily'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_habits_id', 'habits', ['id'])
    op.create_index('ix_habits_user_id', 'habits', ['user_id'])

    op.create_table(
        'habit_entries',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('habit_id', sa.Integer(), sa.ForeignKey('habits.id', ondelete='CASCADE'), nullable=False),
        sa.Column('date', sa.String(10), nullable=False),
        sa.Column('completed', sa.Boolean(), server_default='true', nullable=False),
        sa.UniqueConstraint('habit_id', 'date', name='uq_habit_entry_per_day'),
    )
    op.create_index('ix_habit_entries_id', 'habit_entries', ['id'])
    op.create_index('ix_habit_entries_user_id', 'habit_entries', ['user_id'])
    op.create_index('ix_habit_entries_habit_id', 'habit_entries', ['habit_id'])


def downgrade() -> None:
    op.drop_table('habit_entries')
    op.drop_table('habits')
