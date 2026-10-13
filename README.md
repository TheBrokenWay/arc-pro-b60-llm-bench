# Intel Arc Pro B60 LLM bench: open-weight uncensored models, standard harness

Measured results for local LLMs on Intel Arc Pro B60 (24 GB) cards, using the standard
EleutherAI lm-evaluation-harness tasks (MMLU-Pro, IFEval) against llama.cpp's OpenAI-compatible server.
Published so other people with the same hardware do not have to repeat the same work.

## Equipment

| Part | Value |
|---|---|
| GPU | 2 x Intel Arc Pro B60, 24 GB each (Vulkan0 and Vulkan1 in llama.cpp) |
| CPU | AMD Ryzen Threadripper PRO 5955WX |
| RAM | 256 GB |
| OS | Windows 11 (the server runs natively on Windows; WSL is not in the request path) |
| GPU driver | not yet recorded in this repo; to be added before results are quoted |

## Software

- llama.cpp `b11588` (Windows Vulkan build), `llama-server.exe`
- EleutherAI lm-evaluation-harness `0.4.13`, with `langdetect`, `nltk`, `immutabledict`
- Server flags: `-c 16384 -ngl 99`, one model per card, host `127.0.0.1`, port `8080`

## Method

- Harness: `local-chat-completions` against `/v1/chat/completions`, chat template applied.
- MMLU-Pro: 5-shot, exact match, **10 questions per subject (140 total)**. The full set is about 12,000 questions; this is a sample.
- IFEval (`leaderboard_ifeval`): **100 prompts**. Reported prompt-level and instruction-level, strict and loose.
- Harness settings: `num_concurrent=4`, `max_gen_toks=2048`.
- One run per model per card. No repeats yet, so the stderr values below are the only uncertainty figure we have.
- Each model is run alone on the server; the server is stopped between models.
- Response cache: lm-eval caches responses by request, not by model name. Each model uses its own cache file (`--use_cache` with the model label). A shared cache path corrupted one run in this bench (see Lessons).

## Results

### Huihui-Qwen3.8-27B abliterated, Q4_K_M (UD-DW), card 0 (Vulkan0)

| Task | Metric | Value | Stderr |
|---|---|---|---|
| MMLU-Pro (140-question sample) | exact match | 0.3786 | 0.0406 |
| IFEval (100 prompts) | prompt-level strict | 0.6900 | 0.0465 |
| IFEval (100 prompts) | prompt-level loose | 0.7000 | 0.0461 |
| IFEval (100 prompts) | instruction-level strict | 0.6748 | n/a |
| IFEval (100 prompts) | instruction-level loose | 0.6871 | n/a |

Raw output: `results/huihui-qwen3.8-27b-abliterated-q4km/`.

The model card publishes no sampling settings; the harness defaults were used.

### Qwen3.8-27B Heretic, Q4_K_M, card 0 (Vulkan0)

| Task | Metric | Value | Stderr |
|---|---|---|---|
| MMLU-Pro (140-question sample) | exact match | 0.3357 | 0.0402 |
| IFEval (100 prompts) | prompt-level strict | 0.7200 | 0.0451 |
| IFEval (100 prompts) | prompt-level loose | 0.7300 | 0.0446 |
| IFEval (100 prompts) | instruction-level strict | 0.7055 | n/a |
| IFEval (100 prompts) | instruction-level loose | 0.7117 | n/a |

Raw output: `results/qwen3.8-27b-heretic-q4km/`.

### Pending

- Two-card (split) runs and the remaining downloaded models: not yet run.

## Lessons (from this bench)

1. **Cache paths must be per model.** A runner bug wrote every model's responses to one shared cache file. The second model then read the first model's answers and produced identical scores. The fix is in `bench-scripts/run_industry.sh`.
2. **Non-ASCII output crashes lm-eval on Windows** unless `PYTHONUTF8=1` is set. The runner sets it.
3. **Small samples give wide error bars.** The MMLU-Pro stderr is about 0.04 at 140 questions; do not rank models that differ by less than that.

## Reproduce

1. Put the GGUF file on disk and check its SHA-256 against the source.
2. `bench-scripts/start_server.ps1` starts `llama-server` detached (WMI), on `127.0.0.1:8080`.
3. `bench-scripts/run_industry.sh <label> <model path> <Vulkan0|Vulkan1> -c 16384 -ngl 99` runs MMLU-Pro and IFEval and writes into `results/<label>/`.

Set `LIMIT_MMLU` and `LIMIT_IFEVAL` to change the sample sizes.
