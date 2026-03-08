#!/bin/bash
# zeroclaw-init.sh — First-boot configuration for ZeroClaw.
# Run once to set API key and (optionally) change model/provider.
# Usage: zeroclaw-init.sh <api_key> [model] [provider]

set -euo pipefail

CONFIG="/root/.zeroclaw/config.toml"

if [ $# -lt 1 ]; then
    echo "Usage: zeroclaw-init.sh <api_key> [model] [provider]"
    echo ""
    echo "Examples:"
    echo "  zeroclaw-init.sh sk-xxx"
    echo "  zeroclaw-init.sh sk-xxx anthropic/claude-sonnet-4-6"
    echo "  zeroclaw-init.sh sk-xxx openai/gpt-4o openrouter"
    exit 1
fi

API_KEY="$1"
MODEL="${2:-}"
PROVIDER="${3:-}"

if [ ! -f "$CONFIG" ]; then
    echo "Error: config not found at $CONFIG"
    exit 1
fi

# Set API key
sed -i "s|^api_key = .*|api_key = \"${API_KEY}\"|" "$CONFIG"
echo "API key configured."

# Optionally set model
if [ -n "$MODEL" ]; then
    sed -i "s|^default_model = .*|default_model = \"${MODEL}\"|" "$CONFIG"
    echo "Model set to: $MODEL"
fi

# Optionally set provider
if [ -n "$PROVIDER" ]; then
    sed -i "s|^default_provider = .*|default_provider = \"${PROVIDER}\"|" "$CONFIG"
    echo "Provider set to: $PROVIDER"
fi

# Restart zeroclaw to pick up changes
if systemctl is-active --quiet zeroclaw; then
    systemctl restart zeroclaw
    echo "ZeroClaw restarted."
else
    systemctl start zeroclaw
    echo "ZeroClaw started."
fi

echo "Done. ZeroClaw gateway is running on port 42617."
