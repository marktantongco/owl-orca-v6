# -*- coding: utf-8 -*-
"""OWL-ORCA v6 — Hack #4: CircuitBreaker.

Atomicity without locks: this class runs on the single-threaded asyncio
event loop and has NO await points inside its mutation methods, so no
interleaving can occur; plain int ops are additionally atomic under the
GIL. Zero lock contention, zero allocations on the hot path (__slots__).

State machine (providers.json defaults):
    CLOSED -> fails >= 5  -> OPEN
    OPEN   -> 60s elapsed -> HALF_OPEN (decay: fails -= 1)
    HALF_OPEN -> 1 probe  -> success: CLOSED / fail: back to OPEN

v6.1: apply_policy()/BreakerRegistry.apply_all() give a hot-apply path —
threshold/cooldown/decay edits land on LIVE breakers via POST
/admin/breakers or SIGHUP reload, without a restart. State survives by
design (only the thresholds change).
"""
import time

CLOSED, HALF_OPEN, OPEN = 0, 1, 2
_NAMES = {CLOSED: "CLOSED", HALF_OPEN: "HALF_OPEN", OPEN: "OPEN"}


class CircuitBreaker:
    __slots__ = ("fails", "state", "opened_at", "threshold",
                 "cooldown", "decay", "_probing")

    def __init__(self, threshold=5, cooldown=60.0, decay=1):
        self.fails = 0                # atomic int
        self.state = CLOSED
        self.opened_at = 0.0
        self.threshold = threshold
        self.cooldown = cooldown
        self.decay = decay
        self._probing = False

    def allow(self) -> bool:
        """May I send a request right now? No locks, no allocation."""
        st = self.state
        if st == OPEN:
            if time.monotonic() - self.opened_at >= self.cooldown:
                # 60s -> HALF_OPEN, decay 1 failure, admit ONE probe
                self.fails = self.fails - self.decay if self.fails >= self.decay else 0
                if self.fails < self.threshold:
                    self.state = HALF_OPEN
                    self._probing = True
                    return True
                self.opened_at = time.monotonic()
                return False
            return False
        if st == HALF_OPEN:
            if self._probing:
                return False           # single probe already in flight
            self._probing = True
            return True
        return True

    def record_success(self) -> None:
        self.fails = 0
        self.state = CLOSED
        self._probing = False

    def record_fail(self) -> None:
        if self.state == HALF_OPEN:    # the probe failed
            self.state = OPEN
            self.opened_at = time.monotonic()
            self._probing = False
            return
        self.fails += 1
        if self.fails >= self.threshold:
            self.state = OPEN
            self.opened_at = time.monotonic()

    @property
    def status(self) -> str:
        return _NAMES[self.state]

    def apply_policy(self, policy):
        """v6.1 STRATEGIC: hot-apply a breaker policy to a LIVE breaker —
        no restart, no socket drop. State (fails/opened_at) is preserved by
        design: only the thresholds change; the machine re-evaluates on the
        next allow()/record_* call. Values are clamped sane."""
        old = (self.threshold, self.cooldown, self.decay)
        self.threshold = max(1, int(policy.get("threshold", self.threshold)))
        self.cooldown = max(0.0, float(policy.get("cooldown", self.cooldown)))
        self.decay = max(0, int(policy.get("decay", self.decay)))
        # invariant repair: CLOSED means 'admitted' and CLOSED with
        # fails >= threshold is unreachable through record_fail(); a hot
        # applied LOWER threshold re-trips immediately instead of letting
        # a known-bad upstream absorb one more request.
        if self.state == CLOSED and self.fails >= self.threshold:
            self.state = OPEN
            self.opened_at = time.monotonic()
        return old, (self.threshold, self.cooldown, self.decay)


class BreakerRegistry:
    """One breaker per provider, created lazily from providers.json policy."""
    __slots__ = ("_map",)

    def __init__(self):
        self._map = {}

    def get(self, name, policy=None):
        b = self._map.get(name)
        if b is None:
            p = policy or {}
            b = CircuitBreaker(
                threshold=p.get("threshold", 5),
                cooldown=float(p.get("cooldown", 60)),
                decay=p.get("decay", 1),
            )
            self._map[name] = b
        return b

    def apply_all(self, providers):
        """v6.1: hot-apply breaker policies from a providers dict (post-SIGHUP
        reload path). Created-when-absent breakers adopt the fresh policy;
        existing ones update in place. Returns a delta report for /admin."""
        deltas = {}
        for name, p in (providers or {}).items():
            pol = (p or {}).get("circuit_breaker")
            if not pol:
                continue
            b = self._map.get(name)
            if b is None:
                self.get(name, pol)
                deltas[name] = {"created": True,
                                "policy": [pol.get("threshold", 5),
                                            pol.get("cooldown", 60),
                                            pol.get("decay", 1)]}
                continue
            old, new = b.apply_policy(pol)
            if old != new:
                deltas[name] = {"from": old, "to": new}
        return deltas

    def policies(self):
        """v6.1: full snapshot for GET /admin/breakers — live state + live
        effective policy (what a hot-apply actually changed)."""
        return {k: {"state": v.status, "fails": v.fails,
                    "policy": {"threshold": v.threshold,
                               "cooldown": v.cooldown,
                               "decay": v.decay}}
                for k, v in self._map.items()}

    def snapshot(self):
        return {k: (v.status, v.fails) for k, v in self._map.items()}
