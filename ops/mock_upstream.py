# -*- coding: utf-8 -*-
"""Tiny OpenAI-compatible mock upstream for ladder proofs.
Usage: mock_upstream.py <port> <label-content>"""
import sys
import time

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, StreamingResponse

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 1455
LABEL = sys.argv[2] if len(sys.argv) > 2 else "mock upstream"
app = FastAPI(title="mock-upstream")


@app.get("/healthz")
async def healthz():
    return {"ok": True, "service": "mock-upstream", "port": PORT}


@app.post("/v1/chat/completions")
@app.post("/v1/v1/chat/completions")
async def completions(req: Request):
    body = await req.json()
    if body.get("stream"):
        cid = f"chatcmpl-mock-{time.time_ns()}"

        async def gen():
            for piece in (LABEL, " — streamed from mock upstream.",):
                ch = {"id": cid, "object": "chat.completion.chunk",
                      "created": int(time.time()),
                      "model": body.get("model", "mock"),
                      "choices": [{"index": 0,
                                   "delta": {"content": piece},
                                   "finish_reason": None}]}
                yield b"data: " + __import__("json").dumps(ch).encode() + b"\n\n"
            yield b"data: [DONE]\n\n"

        return StreamingResponse(gen(), media_type="text/event-stream")
    return JSONResponse({
        "id": f"chatcmpl-mock-{time.time_ns()}",
        "object": "chat.completion", "created": int(time.time()),
        "model": body.get("model", "mock"),
        "choices": [{"index": 0,
                     "message": {"role": "assistant",
                                 "content": LABEL + " (non-stream)"},
                     "finish_reason": "stop"}],
    })


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=PORT, log_level="warning")
