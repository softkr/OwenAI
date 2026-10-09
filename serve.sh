#!/bin/zsh
# Qwen3.8-27B MLX server with image support, OpenAI + Anthropic API formats (http://localhost:8080/v1)
# OpenAI: /v1/chat/completions (Authorization: Bearer KEY) · Anthropic: /v1/messages (x-api-key: KEY)
# Listens on HOST (default 0.0.0.0) but only answers loopback / LAN clients.
# Set API_KEY to require "Authorization: Bearer $API_KEY" on requests.
# MTP speculative decoding is on by default (~1.9x faster); DRAFT= disables it.
cd "${0:A:h}"
export HF_HOME="$PWD/hf-cache"
[[ -n "$API_KEY" ]] && export MLX_VLM_SERVER_API_KEY="$API_KEY"
# Automatic prefix cache: follow-up turns reuse the KV cache of the conversation so far,
# so only the new tokens get prefilled. Memory-only (no disk tier).
export APC_ENABLED="${APC_ENABLED:-1}" APC_DISK_ENABLED="${APC_DISK_ENABLED:-0}"
MODEL="${MODEL:-mlx-community/Qwen3.8-27B-4bit}"
DRAFT="${DRAFT-mlx-community/Qwen3.8-27B-MTP-4bit}"
draft_args=()
[[ -n "$DRAFT" ]] && draft_args=(--draft-model "$DRAFT")
exec .venv/bin/python api_server.py --model "$MODEL" "${draft_args[@]}" \
  --host "${HOST:-0.0.0.0}" --port "${PORT:-8080}" "$@"
