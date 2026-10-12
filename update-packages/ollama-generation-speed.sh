#!/usr/bin/env bash

set -u

API="http://127.0.0.1:11434/api/generate"
RESULTS="ollama_benchmark_results.csv"

MODELS=(
    "qwen2.5-coder:7b"
    "qwen3:8b"
    "deepseek-r1:8b"
    "gemma3:12b"
    "qwen2.5:14b"
    "qwen3:14b"
)

PROMPT="Explain what a Linux process is in exactly three short sentences."

# Check dependencies
for CMD in curl python3 ollama; do
    if ! command -v "$CMD" >/dev/null 2>&1; then
        echo "ERROR: Required command not found: $CMD"
        exit 1
    fi
done

# Verify Ollama API using GET on the correct endpoint
echo "Checking Ollama server..."

if ! curl -fsS \
    "http://127.0.0.1:11434/api/tags" >/dev/null; then
    echo "ERROR: Ollama server is not responding."
    echo "Start it with: ollama serve"
    exit 1
fi

echo "Ollama server is available."
echo

# Initialize CSV
echo 'Model,Output_Tokens,Load_Seconds,Prompt_Seconds,Generation_Seconds,Tokens_Per_Second,Total_Seconds' > "$RESULTS"

for MODEL in "${MODELS[@]}"; do
    echo "========================================"
    echo "Testing: $MODEL"
    echo "========================================"

    # Confirm model is installed
    if ! ollama show "$MODEL" >/dev/null 2>&1; then
        echo "SKIPPED: Model is not installed."
        echo
        continue
    fi

    # Send an explicit POST request.
    # -f makes HTTP errors fail.
    # -sS suppresses progress but displays errors.
    RESPONSE=$(curl -fsS \
        --max-time 600 \
        --request POST \
        "$API" \
        -H "Content-Type: application/json" \
        --data-binary @- <<EOF
{
  "model": "$MODEL",
  "prompt": "$PROMPT",
  "stream": false
}
EOF
    ) || {
        echo "ERROR: API request failed for $MODEL"
        echo "Check that Ollama is running and inspect its logs."
        echo
        continue
    }

    # Parse JSON and append the metrics
    if ! printf '%s' "$RESPONSE" | MODEL="$MODEL" RESULTS="$RESULTS" python3 -c '
import csv
import json
import os
import sys

try:
    data = json.load(sys.stdin)

    if "error" in data:
        raise ValueError(data["error"])

    model = os.environ["MODEL"]
    output_tokens = data.get("eval_count", 0)

    load_seconds = data.get("load_duration", 0) / 1e9
    prompt_seconds = data.get("prompt_eval_duration", 0) / 1e9
    generation_seconds = data.get("eval_duration", 0) / 1e9
    total_seconds = data.get("total_duration", 0) / 1e9

    tokens_per_second = (
        output_tokens / generation_seconds
        if generation_seconds > 0 else 0
    )

    with open(os.environ["RESULTS"], "a", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            model,
            output_tokens,
            round(load_seconds, 3),
            round(prompt_seconds, 3),
            round(generation_seconds, 3),
            round(tokens_per_second, 2),
            round(total_seconds, 3)
        ])

    print(f"Model:              {model}")
    print(f"Output tokens:      {output_tokens}")
    print(f"Model load:         {load_seconds:.2f} seconds")
    print(f"Prompt processing:  {prompt_seconds:.2f} seconds")
    print(f"Generation:         {generation_seconds:.2f} seconds")
    print(f"Generation speed:   {tokens_per_second:.2f} tokens/sec")
    print(f"Total duration:     {total_seconds:.2f} seconds")

except Exception as e:
    print(f"ERROR parsing response: {e}", file=sys.stderr)
    sys.exit(1)
' ; then
        echo "ERROR: Could not process response for $MODEL"
    fi

    echo
done

# Display results sorted by generation speed
python3 - "$RESULTS" <<'PY'
import csv
import sys

with open(sys.argv[1], newline="") as f:
    rows = list(csv.DictReader(f))

rows.sort(
    key=lambda row: float(row["Tokens_Per_Second"]),
    reverse=True
)

print("\n========== BENCHMARK RANKING ==========\n")
print(
    f"{'Rank':<5}"
    f"{'Model':<23}"
    f"{'Tokens/s':>10}"
    f"{'Load(s)':>10}"
    f"{'Gen(s)':>10}"
    f"{'Total(s)':>11}"
)
print("-" * 69)

for rank, row in enumerate(rows, 1):
    print(
        f"{rank:<5}"
        f"{row['Model']:<23}"
        f"{float(row['Tokens_Per_Second']):>10.2f}"
        f"{float(row['Load_Seconds']):>10.2f}"
        f"{float(row['Generation_Seconds']):>10.2f}"
        f"{float(row['Total_Seconds']):>11.2f}"
    )

print("\nFull results saved to:", sys.argv[1])
PY
