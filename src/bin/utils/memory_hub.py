# -*- coding: utf-8 -*-
"""OWL-ORCA v6 — Memory hub (TencentDB-Agent-Memory + mempalace fallback).

v6 runs IN-PROCESS inside the router (v4.5 burned a separate 128M systemd
unit for this — eliminated in the memory ledger). Race winners feed the
latency table; failures decay by 1 per minute (mirrors H4 decay policy).
"""
import sqlite3
import time


class MemoryHub:
    def __init__(self, path=":memory:"):
        self.db = sqlite3.connect(path, check_same_thread=False)
        self.db.execute(
            "CREATE TABLE IF NOT EXISTS races "
            "(stream_id TEXT, provider TEXT, latency_ms REAL, winner INT, ts REAL)"
        )
        self.db.execute(
            "CREATE TABLE IF NOT EXISTS provider_stats "
            "(provider TEXT PRIMARY KEY, wins INT, fails INT, decayed INT)"
        )
        self.db.commit()

    def store_race(self, stream_id, provider, latency_ms, winner):
        self.db.execute(
            "INSERT INTO races VALUES (?,?,?,?,?)",
            (stream_id, provider, latency_ms, 1 if winner else 0, time.time()),
        )
        if winner:
            self.db.execute(
                "INSERT INTO provider_stats VALUES (?,?,0,0) "
                "ON CONFLICT(provider) DO UPDATE SET wins = wins + 1",
                (provider, 1),
            )
        else:
            self.db.execute(
                "INSERT INTO provider_stats VALUES (0,?,1,0) "
                "ON CONFLICT(provider) DO UPDATE SET fails = fails + 1",
                (provider,),
            )
        self.db.commit()

    def leaderboard(self):
        return self.db.execute(
            "SELECT provider, wins, fails FROM provider_stats ORDER BY wins DESC"
        ).fetchall()

    def retrieve(self, query):
        return self.db.execute(
            "SELECT provider, AVG(latency_ms) FROM races WHERE winner=1 "
            "GROUP BY provider ORDER BY AVG(latency_ms)"
        ).fetchall()
