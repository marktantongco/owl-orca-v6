<!-- owl-orca v6.2 prompt-card | kind: hack | H5 SIGHUP atomic-rename reload (ExecReload restored) -->
# H5: SIGHUP atomic-rename reload (ExecReload restored)

**One of the top-10 upstream speed/resilience hacks**
**Proof:** Reload proof: socket stays LISTEN, configs swap, 4 files re-read, breaker policies hot-applied in the same pass.

## The technique

Config edits never cost a restart: files are written to temp and rename()d (inode swap — watchers never see torn reads), then SIGHUP re-opens by path. The systemd ExecReload line lost in v5 is restored, and the v6.1 reload script falls back to pkill -HUP when systemd is absent (sandbox-proof).

## Rebuild instruction (paste to any coding agent)

> Implement hack H5 (**SIGHUP atomic-rename reload (ExecReload restored)**) in the owl-orca router with the exact
> semantics described above. The proof bar: Reload proof: socket stays LISTEN, configs swap, 4 files re-read, breaker policies hot-applied in the same pass.
> Do not declare done until the same proof passes in-process.
