"""Jetons JWT (PyJWT) : claims jti/tv, expiration, signature, token_version_ok (chantier 2, § 2)."""

from __future__ import annotations

import re
from datetime import UTC, datetime, timedelta

import jwt
import pytest

from app.core.config import settings
from app.core.security import (
    JWTError,
    create_access_token,
    create_refresh_token,
    decode_token,
    token_version_ok,
)


def test_access_token_porte_jti_et_tv():
    payload = decode_token(create_access_token("u1", token_version=3))
    assert payload["sub"] == "u1"
    assert payload["type"] == "access"
    assert re.fullmatch(r"[0-9a-f]{32}", payload["jti"])
    assert payload["tv"] == 3


def test_refresh_token_porte_jti_et_tv():
    payload = decode_token(create_refresh_token("u1"))
    assert payload["type"] == "refresh"
    assert re.fullmatch(r"[0-9a-f]{32}", payload["jti"])
    assert payload["tv"] == 0


def test_jti_unique_par_jeton():
    a = decode_token(create_access_token("u1"))["jti"]
    b = decode_token(create_access_token("u1"))["jti"]
    assert a != b


def test_duree_access_30_min_refresh_30_jours():
    now = datetime.now(UTC).timestamp()
    access_exp = decode_token(create_access_token("u1"))["exp"]
    refresh_exp = decode_token(create_refresh_token("u1"))["exp"]
    assert abs(access_exp - (now + 30 * 60)) < 5
    assert abs(refresh_exp - (now + 30 * 86400)) < 5


def test_jeton_expire_leve_jwterror():
    expired = jwt.encode(
        {"sub": "u1", "type": "access", "exp": datetime.now(UTC) - timedelta(seconds=1)},
        settings.secret_key,
        algorithm="HS256",
    )
    with pytest.raises(JWTError):
        decode_token(expired)


def test_signature_invalide_leve_jwterror():
    forged = jwt.encode({"sub": "u1", "type": "access"}, "autre-secret-" + "x" * 32, algorithm="HS256")
    with pytest.raises(JWTError):
        decode_token(forged)


def test_jeton_mal_forme_leve_jwterror():
    with pytest.raises(JWTError):
        decode_token("not.a.valid.token")


def test_algorithme_none_refuse():
    unsigned = jwt.encode({"sub": "u1", "type": "access"}, key=None, algorithm="none")
    with pytest.raises(JWTError):
        decode_token(unsigned)


def test_token_version_ok_sans_tv_version_0():
    assert token_version_ok({"sub": "u1"}, 0) is True


def test_token_version_ok_sans_tv_version_1():
    assert token_version_ok({"sub": "u1"}, 1) is False


def test_token_version_ok_tv_perime():
    assert token_version_ok({"tv": 1}, 2) is False


def test_token_version_ok_tv_courant_ou_superieur():
    assert token_version_ok({"tv": 2}, 2) is True
    assert token_version_ok({"tv": 3}, 2) is True
