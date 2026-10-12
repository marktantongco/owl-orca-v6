# -*- coding: utf-8 -*-
"""OWL-ORCA v6 — Defense stack (merged owl-agent-proxy v3.0 + owl-agent-stack v4.5,
restored from the v4.5 installer that v5 dropped — fix F1).

Pipeline (per outbound request):
    cache -> dedup -> rate_limit -> proxy_rotate -> protocol_router
Cache: SHA256 key, TTL 300s. Dedup: coalesces identical in-flight requests.
RateLimit: token bucket per domain (1 req/s default). ProxyRotator: tiered
pool with health tracking. ProtocolRouter: http/1.1 vs http/2 per provider.
"""
import asyncio
import hashlib
import time


class HTTPCache:
    __slots__ = ("ttl", "store")

    def __init__(self, ttl=300):
        self.ttl = ttl
        self.store = {}              # key -> (expires_monotonic, payload)

    @staticmethod
    def key(req: str) -> str:
        return hashlib.sha256(req.encode()).hexdigest()

    def get(self, req: str):
        hit = self.store.get(self.key(req))
        if hit and hit[0] > time.monotonic():
            return hit[1]
        return None

    def put(self, req: str, payload):
        self.store[self.key(req)] = (time.monotonic() + self.ttl, payload)


class RequestDeduplicator:
    """Identical concurrent requests share one future (saves quota+bandwidth)."""
    __slots__ = ("inflight",)

    def __init__(self):
        self.inflight = {}

    async def dedup(self, key: str, factory):
        fut = self.inflight.get(key)
        if fut is not None:
            return await fut
        fut = asyncio.get_event_loop().create_future()
        self.inflight[key] = fut
        try:
            result = await factory()
            if not fut.done():
                fut.set_result(result)
            return result
        except Exception as e:
            if not fut.done():
                fut.set_exception(e)
            raise
        finally:
            self.inflight.pop(key, None)


class DomainRateLimiter:
    """Token bucket, no lock (event-loop atomic, H4 pattern)."""
    __slots__ = ("rate", "tokens", "updated")

    def __init__(self, rate=1.0):
        self.rate = rate
        self.tokens = rate
        self.updated = time.monotonic()

    async def acquire(self):
        while True:
            now = time.monotonic()
            self.tokens = min(self.rate, self.tokens + (now - self.updated) * self.rate)
            self.updated = now
            if self.tokens >= 1.0:
                self.tokens -= 1.0
                return
            await asyncio.sleep((1.0 - self.tokens) / self.rate)


class ProxyRotator:
    """Tiered SOCKS5/HTTP pool — freebuff :1455 (JA3), hydra :10808 (6 rotations),
    novada residential last-resort (403 only)."""
    __slots__ = ("pool", "health", "cursor")

    def __init__(self, pool=None):
        self.pool = pool or [
            {"name": "freebuff", "url": "socks5://127.0.0.1:1455", "tier": 1},
            {"name": "hydra", "url": "socks5://127.0.0.1:10808", "tier": 1},
            {"name": "novada", "url": "http://127.0.0.1:60000", "tier": 2, "note": "403 only"},
        ]
        self.health = {}
        self.cursor = 0

    def next(self):
        live = [p for p in self.pool if self.health.get(p["name"], True)]
        if not live:
            return None
        self.cursor = (self.cursor + 1) % len(live)
        return live[self.cursor]

    def mark_down(self, name):
        self.health[name] = False

    def mark_up(self, name):
        self.health[name] = True


class ProtocolRouter:
    """http/2 preferred (H8 pool multiplexes), http/1.1 for picky origins."""
    __slots__ = ("prefer_h2",)

    def __init__(self, prefer_h2=True):
        self.prefer_h2 = prefer_h2

    def choose(self, provider):
        return "http/2" if self.prefer_h2 and provider.get("format") != "mcp" else "http/1.1"


class ResilientClient:
    """Facade: cache -> dedup -> rate_limit -> proxy_rotate -> protocol_router."""
    __slots__ = ("cache", "dedup", "limiter", "rotator", "proto")

    def __init__(self, cache_ttl=300, rate_limit=1.0):
        self.cache = HTTPCache(cache_ttl)
        self.dedup = RequestDeduplicator()
        self.limiter = DomainRateLimiter(rate_limit)
        self.rotator = ProxyRotator()
        self.proto = ProtocolRouter()

    async def request(self, key: str, factory, *, cacheable=False):
        if cacheable:
            hit = self.cache.get(key)
            if hit is not None:
                return hit, "cache-hit"
        result = await self.dedup.dedup("dedup:" + key, factory)
        if cacheable:
            self.cache.put(key, result)
        return result, "fresh"

    def get_stats(self):
        return {
            "cache_entries": len(self.cache.store),
            "inflight": len(self.dedup.inflight),
            "proxy_health": dict(self.rotator.health),
        }
