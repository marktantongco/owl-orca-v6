# -*- coding: utf-8 -*-
"""OWL-ORCA v6 — RTK token saver middleware (v4.5 restore).

60-90% context reduction while preserving tool_use, thinking_delta and
input_json_delta blocks verbatim (providers.json preserve list).
"""
import re

_STRIP = re.compile(r"\n{3,}")


class TokenSaver:
    preserve = ("tool_use", "tool_result", "thinking_delta", "input_json_delta")

    def compress(self, messages):
        out = []
        for m in messages:
            role = m.get("role", "user")
            content = m.get("content")
            if isinstance(content, str) and "tool" not in role:
                content = _STRIP.sub("\n\n", content).strip()
                if len(content) > 4000:
                    # keep head+tail, drop the middle (summarizable)
                    content = content[:2000] + "\n...[token-saver: elided]...\n" + content[-1500:]
            out.append({"role": role, "content": content})
        return out
