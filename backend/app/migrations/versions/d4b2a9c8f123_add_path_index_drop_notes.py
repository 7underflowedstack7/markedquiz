"""add path index on files, drop orphaned notes table

Revision ID: d4b2a9c8f123
Revises: c3a8d1f2e456
Create Date: 2026-03-20 12:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = 'd4b2a9c8f123'
down_revision: Union[str, Sequence[str], None] = 'c3a8d1f2e456'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_index('ix_files_path', 'files', ['path'])
    op.drop_table('notes')


def downgrade() -> None:
    op.drop_index('ix_files_path', table_name='files')
    op.create_table(
        'notes',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('content', sa.Text(), server_default='', nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_notes_id'), 'notes', ['id'], unique=False)
    op.create_index(op.f('ix_notes_user_id'), 'notes', ['user_id'], unique=False)
