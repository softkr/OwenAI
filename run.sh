#!/bin/zsh
# Qwen3.8-27B MLX server (8080) + web chat page (8081) in one script.
#
#   ./run.sh              model server + web page, opens the browser (Ctrl+C stops both)
#   ./run.sh server       model server only (OpenAI + Anthropic API, http://localhost:8080/v1)
#   ./run.sh [server] -- <args>   extra args are passed to mlx_vlm.server (via api_server.py)
#
# Env: MODEL, DRAFT (empty disables MTP speculative decoding), PORT, WEB_PORT,
#      API_KEY (server mode only; web mode generates a fresh one), APC_ENABLED, APC_DISK_ENABLED
cd "${0:A:h}"

MODE=web
[[ "$1" == server || "$1" == web ]] && { MODE=$1; shift; }
[[ "$1" == -- ]] && shift

export HF_HOME="$PWD/hf-cache"
# Automatic prefix cache: follow-up turns reuse the KV cache of the conversation so far,
# so only the new tokens get prefilled. Memory-only (no disk tier).
export APC_ENABLED="${APC_ENABLED:-1}" APC_DISK_ENABLED="${APC_DISK_ENABLED:-0}"
MODEL="${MODEL:-mlx-community/Qwen3.8-27B-4bit}"
DRAFT="${DRAFT-mlx-community/Qwen3.8-27B-MTP-4bit}"
PORT="${PORT:-8080}"
WEB_PORT="${WEB_PORT:-8081}"

server_cmd=(.venv/bin/python api_server.py --model "$MODEL")
[[ -n "$DRAFT" ]] && server_cmd+=(--draft-model "$DRAFT")
server_cmd+=(--host 127.0.0.1 --port "$PORT" "$@")

if [[ $MODE == server ]]; then
  [[ -n "$API_KEY" ]] && export MLX_VLM_SERVER_API_KEY="$API_KEY"
  exec "${server_cmd[@]}"
fi

# Fresh key per launch: the model server allows any CORS origin, so the key keeps
# other websites from using it. Only the page served below can read config.js.
export API_KEY="$(openssl rand -hex 24)"
export MLX_VLM_SERVER_API_KEY="$API_KEY"
echo "window.API_KEY = \"$API_KEY\";" > web/config.js

"${server_cmd[@]}" &
SERVER_PID=$!
.venv/bin/python web/server.py "$WEB_PORT" &
WEB_PID=$!
trap 'kill $SERVER_PID $WEB_PID 2>/dev/null; rm -f web/config.js' EXIT
trap 'exit 130' INT TERM

echo "모델 로딩 중…"
until curl -sf -H "Authorization: Bearer $API_KEY" "http://127.0.0.1:$PORT/v1/models" >/dev/null; do
  kill -0 $SERVER_PID 2>/dev/null || { echo "모델 서버 시작 실패"; exit 1; }
  kill -0 $WEB_PID 2>/dev/null || { echo "웹 서버 시작 실패 (포트 $WEB_PORT 사용 중?)"; exit 1; }
  sleep 1
done
echo "준비 완료 → http://127.0.0.1:$WEB_PORT  (종료: Ctrl+C)"
open "http://127.0.0.1:$WEB_PORT"

# Stop everything if either process dies.
while kill -0 $SERVER_PID 2>/dev/null && kill -0 $WEB_PID 2>/dev/null; do
  sleep 2
done
echo "서버 종료됨"
