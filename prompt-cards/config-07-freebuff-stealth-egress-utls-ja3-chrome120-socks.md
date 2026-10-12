<!-- owl-orca v6.2 prompt-card | kind: config | Freebuff Stealth Egress: uTLS JA3 chrome120 + SOCKS5 Pool + Token Rotation -->
# Freebuff Stealth Egress: uTLS JA3 chrome120 + SOCKS5 Pool + Token Rotation

**Rank #7 of the top-10 battle-tested upstream configurations**
**Origin:** marktantongco/freebuff-proxy (Go Fiber, verified in v4.7 egress research)
**Battle evidence:** Ecosystem-verified Go build with JA3 fingerprint spoofing, SOCKS5 pool with 30-minute proxy refresh, and multi-token rotation; ports :1455 (data) + :9091/:9092 (dashboards).

## What it is

A Go proxy that presents a Chrome-120 TLS fingerprint (uTLS) while cycling a pool of SOCKS5 residential exits and free-tier tokens, translating OpenAI and Anthropic protocols. DeepSeek models ride it as the cheap tier's volume workhorse.

## The config (copy-ready)

```yaml
freebuff-deepseek: { base_url: http://127.0.0.1:1455/v1,
  stealth: { ja3: chrome120, socks5_pool: true,
             multi_token: true, proxy_refresh_mins: 30 },
  cost_tier: cheap, breaker: 3/45/2 }
curl --socks5-hostname 127.0.0.1:1455 https://api.example.com
```

## Why it earns its rank

Fingerprint realism plus exit rotation is what keeps free-tier volume sustainable; the breaker trips fast (3) because the pool self-heals through rotation rather than waiting out provider bans.

## Rebuild instruction (paste to any coding agent)

> Rebuild this routing configuration in the owl-orca gateway: implement
> **Freebuff Stealth Egress: uTLS JA3 chrome120 + SOCKS5 Pool + Token Rotation** exactly as specified above. Source lineage: marktantongco/freebuff-proxy (Go Fiber, verified in v4.7 egress research).
> Verify with a probe battery before declaring done; wire config changes
> through the atomic-rename + SIGHUP hot-apply path so no TCP drop occurs.
