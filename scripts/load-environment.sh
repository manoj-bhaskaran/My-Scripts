#!/bin/bash

ENV_FILE="$(dirname "$0")/../.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "⚠ .env file not found at: $ENV_FILE"
    echo "Copy .env.example to .env and configure your values"
    return 1
fi

# Load environment variables
set -a
source "$ENV_FILE"
set +a

echo "✓ Environment loaded from $ENV_FILE"
