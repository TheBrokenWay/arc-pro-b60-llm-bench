#!/bin/bash
# Usage: run_industry.sh <label> <windows model path> <device e.g. Vulkan0> [llama-server extra args]
# 1. starts llama-server on 127.0.0.1:8080 for ONE model (stops any other server first)
# 2. waits for /health (done inside one PowerShell call so the loop cannot stall)
# 3. runs EleutherAI lm-evaluation-harness (the standard task family) through the OpenAI chat API
# 4. stops the server and writes E:\LLM\bench\results\<label>\summary.txt
# Limits: --limit N samples per task (see LIMIT). Full runs are not done here because of the 8 h window.
LABEL="$1"; MODEL="$2"; DEV="$3"; shift 3; EXTRA="$*"
LIMIT_MMLU="${LIMIT_MMLU:-10}"; LIMIT_IFEVAL="${LIMIT_IFEVAL:-100}"
RES=/mnt/e/LLM/bench/results/$LABEL
mkdir -p "$RES"
echo "$(date -u +%FT%TZ) start $LABEL dev=$DEV mmlu=$LIMIT_MMLU ifeval=$LIMIT_IFEVAL" >> /mnt/e/LLM/bench/results/runs.log

powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'E:\LLM\bench\start_server.ps1' -Model "$MODEL" -Dev "$DEV" -Label "$LABEL" -Extra "$EXTRA" </dev/null >/dev/null 2>&1
# health: short separate checks (a single long PowerShell loop stalled the runner)
: > "$RES/health.txt"
for i in $(seq 1 120); do
  st=$(powershell.exe -NoProfile -Command "try { (Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 http://127.0.0.1:8080/health).StatusCode } catch { 'down' }" 2>/dev/null | tr -d '\r\n')
  if [ "$st" = "200" ]; then echo HEALTH_OK > "$RES/health.txt"; break; fi
  sleep 5
done
if ! grep -q HEALTH_OK "$RES/health.txt"; then
  echo "$(date -u +%FT%TZ) FAIL health $LABEL" >> /mnt/e/LLM/bench/results/runs.log
  powershell.exe -NoProfile -Command "Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force" >/dev/null 2>&1
  exit 1
fi

MA="model=$LABEL,base_url=http://127.0.0.1:8080/v1/chat/completions,num_concurrent=4,max_retries=3,tokenized_requests=False,tokenizer_backend=None,max_gen_toks=2048"
# MMLU-Pro: LIMIT_MMLU samples per subject (14 subjects); IFEval: LIMIT_IFEVAL samples in total
powershell.exe -NoProfile -Command "\$env:PYTHONUTF8='1'; \$env:PYTHONPATH='E:\LLM\tools\lmeval-site'; python -m lm_eval --model local-chat-completions --model_args '$MA' --tasks mmlu_pro --apply_chat_template --limit $LIMIT_MMLU --output_path 'E:\LLM\bench\results\\$LABEL\lmeval_mmlu' --use_cache 'E:\LLM\bench\cache\\$LABEL' --confirm_run_unsafe_code" > "$RES/lmeval_mmlu.txt" 2>&1
echo "lm_eval mmlu exit=$?" >> "$RES/lmeval_mmlu.txt"
powershell.exe -NoProfile -Command "\$env:PYTHONUTF8='1'; \$env:PYTHONPATH='E:\LLM\tools\lmeval-site'; python -m lm_eval --model local-chat-completions --model_args '$MA' --tasks leaderboard_instruction_following --apply_chat_template --limit $LIMIT_IFEVAL --output_path 'E:\LLM\bench\results\\$LABEL\lmeval_ifeval' --use_cache 'E:\LLM\bench\cache\\$LABEL' --confirm_run_unsafe_code" > "$RES/lmeval_ifeval.txt" 2>&1
echo "lm_eval ifeval exit=$?" >> "$RES/lmeval_ifeval.txt"

powershell.exe -NoProfile -Command "Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force" >/dev/null 2>&1
echo "$(date -u +%FT%TZ) done $LABEL see $RES/lmeval.txt" >> /mnt/e/LLM/bench/results/runs.log
