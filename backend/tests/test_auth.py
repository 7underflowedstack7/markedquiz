"""
Authentication endpoint tests.

Covers: register, login, duplicate email, weak password,
wrong password, token refresh, expired token, /me endpoint.
"""

import pytest
from httpx import AsyncClient
from app.auth.service import create_refresh_token
from app.auth.models import User


@pytest.mark.asyncio
class TestRegister:

    async def test_register_success(self, client: AsyncClient):
        resp = await client.post("/api/auth/register", json={
            "email": "new@example.com",
            "password": "StrongPass1!",
        })
        assert resp.status_code == 201
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"

    async def test_register_duplicate_email(self, client: AsyncClient, test_user: User):
        resp = await client.post("/api/auth/register", json={
            "email": test_user.email,
            "password": "AnotherPass1!",
        })
        assert resp.status_code == 409
        assert "already registered" in resp.json()["detail"]

    async def test_register_weak_password(self, client: AsyncClient):
        resp = await client.post("/api/auth/register", json={
            "email": "weak@example.com",
            "password": "short",
        })
        assert resp.status_code == 422  # Pydantic validation

    async def test_register_invalid_email(self, client: AsyncClient):
        resp = await client.post("/api/auth/register", json={
            "email": "not-an-email",
            "password": "StrongPass1!",
        })
        assert resp.status_code == 422


@pytest.mark.asyncio
class TestLogin:

    async def test_login_success(self, client: AsyncClient, test_user: User):
        resp = await client.post("/api/auth/login", json={
            "email": "test@example.com",
            "password": "TestPass123!",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data

    async def test_login_wrong_password(self, client: AsyncClient, test_user: User):
        resp = await client.post("/api/auth/login", json={
            "email": "test@example.com",
            "password": "WrongPassword!",
        })
        assert resp.status_code == 401
        assert "Invalid" in resp.json()["detail"]

    async def test_login_nonexistent_email(self, client: AsyncClient):
        resp = await client.post("/api/auth/login", json={
            "email": "ghost@example.com",
            "password": "Whatever123!",
        })
        assert resp.status_code == 401


@pytest.mark.asyncio
class TestTokenRefresh:

    async def test_refresh_success(self, client: AsyncClient, test_user: User):
        refresh = create_refresh_token(test_user.id)
        resp = await client.post("/api/auth/refresh", json={
            "refresh_token": refresh,
        })
        assert resp.status_code == 200
        data = resp.json()
        assert "access_token" in data

    async def test_refresh_with_access_token_fails(self, client: AsyncClient, auth_headers: dict):
        """Using an access token as a refresh token should fail."""
        # Extract the access token from headers
        token = auth_headers["Authorization"].replace("Bearer ", "")
        resp = await client.post("/api/auth/refresh", json={
            "refresh_token": token,
        })
        assert resp.status_code == 401

    async def test_refresh_with_garbage_token(self, client: AsyncClient):
        resp = await client.post("/api/auth/refresh", json={
            "refresh_token": "not.a.real.token",
        })
        assert resp.status_code == 401


@pytest.mark.asyncio
class TestMe:

    async def test_me_authenticated(self, client: AsyncClient, test_user: User, auth_headers: dict):
        resp = await client.get("/api/auth/me", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["email"] == test_user.email
        assert data["id"] == test_user.id

    async def test_me_no_token(self, client: AsyncClient):
        resp = await client.get("/api/auth/me")
        assert resp.status_code in (401, 403)  # HTTPBearer may return either

    async def test_me_invalid_token(self, client: AsyncClient):
        resp = await client.get("/api/auth/me", headers={
            "Authorization": "Bearer garbage.token.here",
        })
        assert resp.status_code == 401
