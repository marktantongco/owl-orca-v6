<!-- owl-orca v6.2 prompt-card | kind: config | graftcp Seccomp-BPF Proxy Chaining (only_socks5) -->
# graftcp Seccomp-BPF Proxy Chaining (only_socks5)

**Rank #10 of the top-10 battle-tested upstream configurations**
**Origin:** hmgle/graftcp — 2,584 stars, verified; v6 H9 wrapper
**Battle evidence:** Upstream-proven transparent proxy tool; the v6 wrapper adds --select_proxy_mode only_socks5 with black/white IP files so ONLY socket syscalls are trapped (less overhead than full ptrace).

## What it is

A seccomp-BPF-based transparent proxy that forces arbitrary programs' TCP traffic through SOCKS5 without LD_PRELOAD or root. The v6 wrapper constrains the syscall surface and pins IP exclusion lists so control-plane traffic never enters the egress tunnel.

## The config (copy-ready)

```yaml
graftcp-wrapper.sh: graftcp --select_proxy_mode only_socks5 \
  --black-ip-file <ctrl-net> --white-ip-file <egress-net> \
  --socks5 127.0.0.1:1080  <command>
usage: graftcp-wrapper.sh curl https://example.com
```

## Why it earns its rank

Per-invocation (not resident) proxying means the memory ledger only pays ~10M transiently, and any existing tool — including the router's own httpx pool — inherits the stealth egress without code changes.

## Rebuild instruction (paste to any coding agent)

> Rebuild this routing configuration in the owl-orca gateway: implement
> **graftcp Seccomp-BPF Proxy Chaining (only_socks5)** exactly as specified above. Source lineage: hmgle/graftcp — 2,584 stars, verified; v6 H9 wrapper.
> Verify with a probe battery before declaring done; wire config changes
> through the atomic-rename + SIGHUP hot-apply path so no TCP drop occurs.
