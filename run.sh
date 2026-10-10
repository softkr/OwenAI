#!/bin/zsh
# Qwen3.8-27B MLX model server (OpenAI + Anthropic API, http://localhost:8080/v1).
#
#   ./run.sh              start the model server
#   ./run.sh -- <args>    extra args are passed to mlx_vlm.server (via api_server.py)
#
# Listens on BIND_HOST (default 0.0.0.0) and only answers loopback / LAN clients.
#
# Env: MODEL, DRAFT (empty disables MTP speculative decoding), BIND_HOST, PORT,
#      API_KEY (required as "Authorization: Bearer $API_KEY" when set), APC_ENABLED, APC_DISK_ENABLED
cd "${0:A:h}"

[[ "$1" == server ]] && shift  # old "./run.sh server" form
[[ "$1" == -- ]] && shift

export HF_HOME="$PWD/hf-cache"
# Automatic prefix cache: follow-up turns reuse the KV cache of the conversation so far,
# so only the new tokens get prefilled. Memory-only (no disk tier).
export APC_ENABLED="${APC_ENABLED:-1}" APC_DISK_ENABLED="${APC_DISK_ENABLED:-0}"
MODEL="${MODEL:-mlx-community/Qwen3.8-27B-4bit}"
DRAFT="${DRAFT-mlx-community/Qwen3.8-27B-MTP-4bit}"
BIND_HOST="${BIND_HOST:-0.0.0.0}"
PORT="${PORT:-8080}"

lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t >/dev/null 2>&1 && {
  echo "포트 $PORT 사용 중 — 이미 서버가 실행 중인지 확인하세요"; exit 1;
}

server_cmd=(.venv/bin/python api_server.py --model "$MODEL")
[[ -n "$DRAFT" ]] && server_cmd+=(--draft-model "$DRAFT")
server_cmd+=(--host "$BIND_HOST" --port "$PORT" "$@")

[[ -n "$API_KEY" ]] && export MLX_VLM_SERVER_API_KEY="$API_KEY"
exec "${server_cmd[@]}"
