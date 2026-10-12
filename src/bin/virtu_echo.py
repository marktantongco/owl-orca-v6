#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OWL-ORCA v6.1 — virtu-echo: the virtual completion backend (:60009).

The "virtu" in owl-orca-virtu CV: an in-sandbox virtual upstream that the
router races ONLY as the terminal fallback after the rules fallback_tier
ladder is exhausted (every real upstream gated or failing). Real upstreams
always win on merit when they are alive — virtu-echo never enters a normal
race.

Answers are OpenAI-shaped (chat completions + SSE) and self-labeled with
the Tier-0 verdict, so clients like OpenCode can SEE the animal ladder that
routed them:

    [virtu-echo animal=rabbit tier=cheap route=virtual]
    Speed mode: ...

Uses the SAME tier0 classifier (H2 radix trie + H7 LRU) as the router, so
the label always matches the router's routing decision.
"""
import json
import os
import sys
import time

BASE = os.path.expanduser("~/.owl-orca-v6")
sys.path.insert(0, BASE)                       # tier0 + utils from the tree

from fastapi import FastAPI, Request                     # noqa: E402
from fastapi.responses import JSONResponse, StreamingResponse  # noqa: E402
from tier0.classifier import classify as tier0_classify  # noqa: E402

app = FastAPI(title="owl-orca-v6.1-virtu-echo", version="6.1.0")

_MODE_REPLY = {
    "rabbit": ("Speed mode (rabbit/cheap): three fastest paths to ship now — "
               "(1) smallest vertical slice, (2) stub every unknown behind an "
               "interface, (3) demo before polish. Optimize for the demo "
               "story, not the architecture. park big-picture work entirely."),
    "ant": ("Precision mode (ant/cheap): execution checklist — verify each "
            "item in order, no skipping: inputs pinned, edge cases listed, "
            "failure modes enumerated, regression test written first, then "
            "the smallest change that passes it. Singular focus per step."),
    "dolphin": ("Creative mode (dolphin/cheap): remix idea — combine the "
                "current task's core mechanic with an unrelated pattern from "
                "a different domain (game design, choreography, kitchens). "
                "Keep the constraint that makes it playful; drop the "
                "convention that makes it boring. Ship the weird version "
                "behind a flag."),
    "beaver": ("Systems mode (beaver/medium): build plan — map the current "
               "state, define the target interface, cut the migration into "
               "reversible steps, each behind a flag, each independently "
               "revertible, then land them in dependency order. Practical "
               "beats elegant."),
    "elephant": ("Consistency mode (elephant/medium): consolidate — restate "
                 "the durable facts, align the new work with prior "
                 "decisions, flag any contradiction with the existing "
                 "conventions before writing new ones. Long-term coherent "
                 "memory over local cleverness."),
    "eagle": ("Strategy mode (eagle/premium): zoom out — name the objective, "
              "the constraint set, and the one metric that matters; rank the "
              "options by leverage per unit of effort; pick the option that "
              "keeps the most doors open. Capital and attention go to the "
              "top of that list only."),
    "owl": ("Deep-analysis mode (owl/premium): hidden-factor pass — surface "
            "the assumptions nobody wrote down, the second-order effects "
            "nobody priced in, and the failure mode that shows up only under "
            "load or adversarial input. Root cause before remedy."),
}


def _verdict(prompt: str) -> dict:
    try:
        return json.loads(tier0_classify(prompt))
    except Exception:
        return {"animal": "owl", "mode": "Deep Analysis", "cost_tier": "premium"}


def _content(verdict: dict, prompt: str) -> str:
    animal = verdict.get("animal", "owl")
    tier = verdict.get("cost_tier", "premium")
    label = (f"[virtu-echo animal={animal} tier={tier} route=virtual "
             f"mode={verdict.get('mode', 'Deep Analysis')}]")
    body = _MODE_REPLY.get(animal, _MODE_REPLY["owl"])
    note = (" Real upstreams are gated/absent in this sandbox (no external "
            "credentials), so the virtual backend answered. Add real "
            "upstream credentials and this request would race them instead.")
    echo = f" Prompt head: {prompt[:180].strip()}"
    return label + "\n" + body + note + echo


def _completion_body(model: str, content: str) -> dict:
    return {
        "id": f"chatcmpl-virtu-{time.time_ns()}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": model or "virtu-echo",
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": content},
            "finish_reason": "stop",
        }],
        "usage": {"prompt_tokens": 0, "completion_tokens": 0,
                  "total_tokens": 0},
    }


async def _completions(req: Request):
    body = await req.json()
    msgs = [m for m in body.get("messages", [])
            if isinstance(m, dict) and m.get("role") == "user"]
    if msgs:
        prompt = str(msgs[-1].get("content", ""))   # match router routing
    else:
        prompt = " ".join(str(m.get("content", ""))
                           for m in body.get("messages", []))
    verdict = _verdict(prompt)
    content = _content(verdict, prompt)
    model = body.get("model", "virtu-echo")
    if body.get("stream"):
        cid = f"chatcmpl-virtu-{time.time_ns()}"

        def chunk(delta, finish=None):
            return {
                "id": cid, "object": "chat.completion.chunk",
                "created": int(time.time()), "model": model,
                "choices": [{"index": 0, "delta": delta,
                             "finish_reason": finish}],
            }

        async def gen():
            pieces = content.split("\n")
            for i, piece in enumerate(pieces):
                delta = {"role": "assistant"} if i == 0 else {}
                if piece:
                    delta["content"] = piece + ("\n" if i < len(pieces) - 1 else "")
                yield b"data: " + json.dumps(chunk(delta)).encode() + b"\n\n"
            yield b"data: " + json.dumps(chunk({}, "stop")).encode() + b"\n\n"
            yield b"data: [DONE]\n\n"

        return StreamingResponse(gen(), media_type="text/event-stream",
                                 headers={"X-Virtu-Animal": verdict.get("animal", "owl"),
                                          "X-Virtu-Tier": verdict.get("cost_tier", "premium")})
    resp = _completion_body(model, content)
    return JSONResponse(resp, headers={
        "X-Virtu-Animal": verdict.get("animal", "owl"),
        "X-Virtu-Tier": verdict.get("cost_tier", "premium")})


# router builds base_url + "/v1/chat/completions"; provider base_urls carry
# their own /v1, so BOTH path shapes are served.
app.add_api_route("/v1/chat/completions", _completions, methods=["POST"])
app.add_api_route("/v1/v1/chat/completions", _completions, methods=["POST"])


@app.get("/v1/models")
@app.get("/v1/v1/models")
async def models():
    return {"object": "list",
            "data": [{"id": "virtu-echo", "owned_by": "virtu-echo"},
                     {"id": "virtu-echo-cheap", "owned_by": "virtu-echo"},
                     {"id": "virtu-echo-premium", "owned_by": "virtu-echo"}]}


@app.get("/healthz")
async def healthz():
    return {"ok": True, "service": "virtu-echo", "port": 60009,
            "cap": "64M", "role": "virtual terminal fallback (never raced "
            "against live upstreams; engaged only when the fallback_tier "
            "ladder is exhausted)"}


if __name__ == "__main__":
    import uvicorn
    try:
        import uvloop                              # H1 lineage
        uvloop.install()
    except ImportError:
        pass
    uvicorn.run(app, host="127.0.0.1", port=60009, log_level="warning")
