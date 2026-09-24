"""Fake minimal de redis.asyncio pour les tests du store d'upload (bytes comme le vrai client)."""

from __future__ import annotations


class FakeRedis:
    def __init__(self) -> None:
        self.hashes: dict[str, dict[bytes, bytes]] = {}
        self.sets: dict[str, set[bytes]] = {}
        self.ttl: dict[str, int] = {}

    @staticmethod
    def _b(v) -> bytes:
        return v if isinstance(v, bytes) else str(v).encode()

    async def hset(self, name, mapping):
        self.hashes.setdefault(name, {}).update({self._b(k): self._b(v) for k, v in mapping.items()})
        return len(mapping)

    async def hgetall(self, name):
        return dict(self.hashes.get(name, {}))

    async def sadd(self, name, *values):
        s = self.sets.setdefault(name, set())
        before = len(s)
        s.update(self._b(v) for v in values)
        return len(s) - before

    async def smembers(self, name):
        return set(self.sets.get(name, set()))

    async def expire(self, name, seconds):
        self.ttl[name] = seconds
        return True

    async def delete(self, *names):
        n = 0
        for name in names:
            n += int(self.hashes.pop(name, None) is not None) + int(self.sets.pop(name, None) is not None)
        return n
