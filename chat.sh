#!/bin/zsh
# Interactive terminal chat with Qwen3.8-27B (MLX)
cd "${0:A:h}"
export HF_HOME="$PWD/hf-cache"
MODEL="${MODEL:-mlx-community/Qwen3.8-27B-4bit}"
exec .venv/bin/mlx_lm.chat --model "$MODEL" --max-tokens "${MAX_TOKENS:-4096}" "$@"
