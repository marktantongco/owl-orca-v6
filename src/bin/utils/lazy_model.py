# -*- coding: utf-8 -*-
"""OWL-ORCA v6 — Hack #6: LazyModel.

embeddinggemma-300m (300MB) and MiniLM (80MB) are loaded on the FIRST
tool call, never at startup; an idle watchdog unloads the model after
300s of inactivity. Result: zero fixed memory for the embedding tier
between bursts — mempalace no longer costs 300MB of resident budget.
"""
import asyncio
import time


class LazyModel:
    IDLE_UNLOAD_S = 300.0            # 5 minutes
    _WATCH_TICK_S = 30.0

    def __init__(self, model_name="sentence-transformers/all-MiniLM-L6-v2"):
        self.model_name = model_name
        self._model = None
        self._last_used = 0.0
        self._lock = asyncio.Lock()
        self._watcher = None

    @property
    def loaded(self) -> bool:
        return self._model is not None

    async def ensure_loaded(self):
        if self._model is None:
            async with self._lock:
                if self._model is None:
                    # heavy import deferred to first use — cold start only
                    from sentence_transformers import SentenceTransformer
                    self._model = await asyncio.to_thread(
                        SentenceTransformer, self.model_name
                    )
        self._last_used = time.monotonic()
        if self._watcher is None or self._watcher.done():
            self._watcher = asyncio.create_task(self._idle_watchdog())

    async def embed(self, text):
        """First tool call pays the load; subsequent calls hit the warm model."""
        await self.ensure_loaded()
        self._last_used = time.monotonic()
        return await asyncio.to_thread(self._model.encode, text)

    async def embed_batch(self, texts):
        await self.ensure_loaded()
        self._last_used = time.monotonic()
        return await asyncio.to_thread(self._model.encode, list(texts))

    async def _idle_watchdog(self):
        """Unload after 300s idle -> zero fixed memory. Watcher exits on unload."""
        try:
            while True:
                await asyncio.sleep(self._WATCH_TICK_S)
                if self._model is None:
                    return
                if time.monotonic() - self._last_used >= self.IDLE_UNLOAD_S:
                    self._model = None      # release ~80MB (MiniLM) / ~300MB
                    return                 # recreated on next ensure_loaded()
        except asyncio.CancelledError:
            return

    async def shutdown(self):
        if self._watcher is not None and not self._watcher.done():
            self._watcher.cancel()
        self._model = None
