# Security Policy

## Reporting a Vulnerability

Open a private security advisory on this repo (GitHub → Security → Advisories) or contact the maintainer. Please do not open public issues for exploitable findings. Reports are acknowledged within 72 hours.

## Security Model

- **No credentials in this repository.** Upstream tokens are generated at install time and stored Fernet-encrypted with `0600` permissions in `~/.owl-orca-v6/tokens.enc`; the key lives in `.fernet.key` beside it. Neither file is ever committed.
- **Key hygiene.** All writes use atomic rename — no partially-written credential files. Rotate a compromised token by re-running the provider's login flow; the vault re-encrypts.
- **Guardrails.** The router runs a pre-flight regex battery (prompt-injection, exfiltration, self-harm patterns) and returns OpenAI-shaped `400 guardrail_violation` errors — hostile prompts never reach upstreams.
- **Egress discipline.** Optional seccomp confinement (graftcp `only_socks5`) restricts the router's outbound surface to the SOCKS5 pool. DPI-bypass tiers are install-gated and off by default.
- **Hot-reload safety.** Config changes land via `tmp + os.replace + SIGHUP`; a failed reload leaves the previous state serving.

## Hardening Checklist for Operators

- [ ] Keep `tokens.enc` / `.fernet.key` at `0600`, never back them up to public storage
- [ ] Bind `:60001` to `127.0.0.1` (default) unless you front it with your own TLS reverse proxy
- [ ] Put a real reverse proxy (TLS, auth, WAF) in front of any internet-exposed deployment
- [ ] Rotate upstream tokens on any suspicion of leakage
- [ ] Review `/admin/*` exposure before allowing multi-user access — add auth at the proxy layer

## Terms-of-Service Boundaries

This project routes requests to upstream providers **using your own accounts and entitlements**. It is your responsibility to operate within each provider's terms: the quota guard exists to keep usage inside your grants. Deliberate evasion of provider limits (account pooling, anti-ban abuse) is outside the project's design and not supported.

## Supported Versions

| Version | Supported |
|---|---|
| v6.2.x (this branch) | ✅ |
| ≤ v6.1 | best-effort, upgrade recommended |
