"""Upload de PDF par morceaux (Story 7.11) — état Redis (TTL 24 h) + morceaux sur le volume partagé.

Cloudflare limite chaque requête à 100 MB : l'app envoie des morceaux de PART_SIZE
que `complete` assemble avant de rejoindre le pipeline d'import existant.
"""

from __future__ import annotations

import os
import shutil
import uuid
from collections.abc import AsyncIterator
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Protocol

PART_SIZE = 25 * 1024 * 1024
UPLOAD_TTL_SECONDS = 24 * 3600
MAX_UPLOAD_SIZE = 500 * 1024 * 1024
_WRITE_CHUNK = 1024 * 1024


class UploadRedis(Protocol):
    """Sous-ensemble de redis.asyncio.Redis (ArqRedis le satisfait)."""

    async def hset(self, name: str, mapping: dict) -> int: ...
    async def hgetall(self, name: str) -> dict: ...
    async def sadd(self, name: str, *values: str | int) -> int: ...
    async def smembers(self, name: str) -> set: ...
    async def expire(self, name: str, seconds: int) -> bool: ...
    async def delete(self, *names: str) -> int: ...


class PartSizeError(ValueError):
    """Taille de morceau différente de celle attendue."""


class InvalidPartIndex(ValueError):
    """Index de morceau hors de [0, parts_total)."""


@dataclass
class UploadState:
    upload_id: str
    user_id: str
    ref_id: int
    size_bytes: int
    part_size: int
    parts_total: int
    created_at: datetime
    received: set[int] = field(default_factory=set)

    @property
    def expires_at(self) -> datetime:
        return self.created_at + timedelta(seconds=UPLOAD_TTL_SECONDS)

    @property
    def missing(self) -> list[int]:
        return [n for n in range(self.parts_total) if n not in self.received]

    @property
    def is_complete(self) -> bool:
        return not self.missing

    def expected_part_size(self, n: int) -> int:
        if not (0 <= n < self.parts_total):
            raise InvalidPartIndex(n)
        if n == self.parts_total - 1:
            return self.size_bytes - self.part_size * n
        return self.part_size


def _s(v: object) -> str:
    return v.decode() if isinstance(v, bytes) else str(v)


class ChunkedUploadStore:
    def __init__(self, redis: UploadRedis, base_dir: Path) -> None:
        self._redis = redis
        self._base = Path(base_dir) / "uploads"

    # ── clés / chemins ────────────────────────────────────────────────────────
    @staticmethod
    def _key(upload_id: str) -> str:
        return f"upload:{upload_id}"

    @staticmethod
    def _parts_key(upload_id: str) -> str:
        return f"upload:{upload_id}:parts"

    def part_path(self, upload_id: str, n: int) -> Path:
        return self._base / upload_id / f"part_{n}"

    # ── état ──────────────────────────────────────────────────────────────────
    async def create(self, user_id: uuid.UUID, ref_id: int, size_bytes: int) -> UploadState:
        state = UploadState(
            upload_id=str(uuid.uuid4()),
            user_id=str(user_id),
            ref_id=ref_id,
            size_bytes=size_bytes,
            part_size=PART_SIZE,
            parts_total=-(-size_bytes // PART_SIZE),
            created_at=datetime.now(UTC),
        )
        await self._write_state(state)
        return state

    async def _write_state(self, state: UploadState) -> None:
        key = self._key(state.upload_id)
        await self._redis.hset(
            key,
            mapping={
                "user_id": state.user_id,
                "ref_id": state.ref_id,
                "size_bytes": state.size_bytes,
                "part_size": state.part_size,
                "parts_total": state.parts_total,
                "created_at": state.created_at.isoformat(),
            },
        )
        await self._redis.expire(key, UPLOAD_TTL_SECONDS)
        if state.received:
            await self._redis.sadd(self._parts_key(state.upload_id), *state.received)
        await self._redis.expire(self._parts_key(state.upload_id), UPLOAD_TTL_SECONDS)

    async def get(self, upload_id: str) -> UploadState | None:
        raw = await self._redis.hgetall(self._key(upload_id))
        if not raw:
            return None
        h = {_s(k): _s(v) for k, v in raw.items()}
        received = {int(_s(v)) for v in await self._redis.smembers(self._parts_key(upload_id))}
        return UploadState(
            upload_id=upload_id,
            user_id=h["user_id"],
            ref_id=int(h["ref_id"]),
            size_bytes=int(h["size_bytes"]),
            part_size=int(h["part_size"]),
            parts_total=int(h["parts_total"]),
            created_at=datetime.fromisoformat(h["created_at"]),
            received=received,
        )

    async def claim(self, upload_id: str) -> UploadState | None:
        """Prise de possession atomique : seul l'appelant dont le DEL renvoie 1 gagne."""
        state = await self.get(upload_id)
        if state is None:
            return None
        deleted = await self._redis.delete(self._key(upload_id))
        if not deleted:
            return None
        await self._redis.delete(self._parts_key(upload_id))
        return state

    async def restore(self, state: UploadState) -> None:
        """Remet l'état (clé + morceaux reçus) après un `claim` dont la suite a échoué."""
        await self._write_state(state)

    # ── morceaux ──────────────────────────────────────────────────────────────
    async def write_part(self, state: UploadState, n: int, chunks: AsyncIterator[bytes]) -> None:
        """Écrit le morceau n (fichier .tmp puis os.replace) et le marque reçu. Idempotent."""
        expected = state.expected_part_size(n)  # lève InvalidPartIndex
        path = self.part_path(state.upload_id, n)
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        written = 0
        try:
            with open(tmp, "wb") as f:
                async for chunk in chunks:
                    written += len(chunk)
                    if written > expected:
                        raise PartSizeError(f"part {n}: {written} > {expected}")
                    f.write(chunk)
            if written != expected:
                raise PartSizeError(f"part {n}: {written} != {expected}")
        except Exception:
            tmp.unlink(missing_ok=True)
            raise
        os.replace(tmp, path)
        await self._redis.sadd(self._parts_key(state.upload_id), n)
        await self._redis.expire(self._parts_key(state.upload_id), UPLOAD_TTL_SECONDS)

    def assemble(self, state: UploadState, dest: Path) -> int:
        """Concatène part_0..part_{N-1} dans `dest` ; renvoie le nombre d'octets écrits."""
        total = 0
        with open(dest, "wb") as out:
            for n in range(state.parts_total):
                with open(self.part_path(state.upload_id, n), "rb") as part:
                    while chunk := part.read(_WRITE_CHUNK):
                        out.write(chunk)
                        total += len(chunk)
        return total

    def purge(self, upload_id: str) -> None:
        shutil.rmtree(self._base / upload_id, ignore_errors=True)

    def stale_dirs(self, max_age: timedelta) -> list[Path]:
        if not self._base.exists():
            return []
        cutoff = datetime.now(UTC).timestamp() - max_age.total_seconds()
        return sorted(p for p in self._base.iterdir() if p.is_dir() and p.stat().st_mtime < cutoff)
