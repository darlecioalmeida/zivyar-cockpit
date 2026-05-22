#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:3000}"

echo "Checking ${BASE_URL}/graphify"
status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/graphify")
if [ "$status" != "200" ]; then
  echo "FAIL: /graphify returned $status" >&2
  exit 1
fi

echo "Checking ${BASE_URL}/workspaces/3/graphify.json"
status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/workspaces/3/graphify.json")
if [ "$status" != "200" ]; then
  echo "FAIL: /workspaces/3/graphify.json returned $status" >&2
  exit 1
fi

echo "Graphify endpoints OK"
