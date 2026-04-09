#!/usr/bin/env bash

set -euo pipefail

COUNT_FILE=".integration-count"
COUNT=0
if [ -f "$COUNT_FILE" ]; then
  COUNT=$(cat "$COUNT_FILE")
fi
COUNT=$((COUNT + 1))
printf "%s\n" "$COUNT" > "$COUNT_FILE"

npx vitest run tests/integration.test.ts

if [ "$COUNT" -ne 1 ]; then
  echo "integration ran $COUNT times" >&2
  exit 1
fi
