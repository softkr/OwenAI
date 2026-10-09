"""mlx_vlm.server that speaks both the OpenAI and the Anthropic API formats.

  OpenAI:    POST /v1/chat/completions, /v1/responses   key in "Authorization: Bearer <key>"
  Anthropic: POST /v1/messages, /v1/messages/count_tokens   key in "x-api-key: <key>"

mlx_vlm already serves /v1/messages but only checks the Bearer header, so the
Anthropic SDKs (which send x-api-key) get 401. This maps x-api-key onto the
Bearer header before the request reaches the app. Same CLI args as mlx_vlm.server.
"""

import mlx_vlm.server as server
from mlx_vlm.server.cli import main


class AnthropicKeyAuth:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] in ("http", "websocket"):
            headers = scope["headers"]
            key = next((v for k, v in headers if k == b"x-api-key"), None)
            if key and not any(k == b"authorization" for k, _ in headers):
                scope = dict(scope, headers=[*headers, (b"authorization", b"Bearer " + key)])
        await self.app(scope, receive, send)


server.app.add_middleware(AnthropicKeyAuth)

if __name__ == "__main__":
    main()
