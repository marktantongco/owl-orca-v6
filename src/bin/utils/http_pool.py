# -*- coding: utf-8 -*-
"""OWL-ORCA v6 — Hack #8: process-wide httpx HTTP/2 keep-alive pool.

ONE AsyncClient per process (singleton). HTTP/2 multiplexes many requests
over one connection; the pool keeps 100 connections + 20 keep-alive slots
warm so provider fetches skip TCP+TLS handshake (~100-300ms each) on the
racing hot path. User-Agent pinned to Chrome/120 so the TLS/UA pair stays
JA3-consistent with freebuff's chrome120 stealth profile.
"""
import httpx

CHROME120_UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

_client = None


def get_client() -> httpx.AsyncClient:
    """Singleton client — call from anywhere, never close per-request."""
    global _client
    if _client is None or _client.is_closed:
        _client = httpx.AsyncClient(
            http2=True,
            limits=httpx.Limits(
                max_connections=100,
                max_keepalive_connections=20,
                keepalive_expiry=30.0,
            ),
            headers={
                "User-Agent": CHROME120_UA,
                "Accept": "application/json, text/event-stream",
                "Accept-Language": "en-US,en;q=0.9",
            },
            timeout=httpx.Timeout(30.0, connect=5.0),
            follow_redirects=True,
        )
    return _client


async def aclose() -> None:
    """Shutdown hook (SIGHUP does NOT call this — reload keeps the pool warm)."""
    global _client
    if _client is not None and not _client.is_closed:
        await _client.aclose()
    _client = None
