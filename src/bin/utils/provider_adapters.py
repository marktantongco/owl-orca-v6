# -*- coding: utf-8 -*-
"""OWL-ORCA v6 — provider adapters (v4.5 restore, F9 port fix: NIM :60008).

Registry loaded from config/providers.json at runtime; this module holds
the translation metadata for the SSE rewriter (H3b).
"""
PROVIDERS = {
    "antigravity": {"type": "bun_gateway", "base": "http://127.0.0.1:60003",
                    "format": "anthropic", "thinking_field": "thinking"},
    "novada": {"type": "residential_mcp", "base": "http://127.0.0.1:60000",
               "format": "mcp", "bypass": ["cloudflare", "akamai", "datadome"]},
    "nim": {"type": "nvidia_nim", "base": "http://127.0.0.1:60008",   # F9
            "format": "openai", "translate": "openai"},
    "copilot": {"type": "github", "base": "https://api.githubcopilot.com",
                "format": "openai"},
    "kiro": {"type": "aws_builder", "base": "http://127.0.0.1:8333",
             "format": "openai"},
    "freebuff": {"type": "go_ja3", "base": "http://127.0.0.1:1455/v1",
                 "format": "openai_and_anthropic", "stealth": "chrome120"},
}

# H3b: Anthropic SSE event -> OpenAI-style chunk field mapping
SSE_TRANSLATION = {
    "message_start": "role_chunk",
    "content_block_delta_text": "content_delta",
    "thinking_delta": "reasoning_content",
    "input_json_delta": "tool_call_args",
}
