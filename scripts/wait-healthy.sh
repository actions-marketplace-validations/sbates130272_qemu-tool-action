#!/usr/bin/env bash
# Poll compose services until all report healthy or TIMEOUT seconds elapse.
set -euo pipefail

STACK="$1"
TIMEOUT="${2:-120}"
elapsed=0

echo "Waiting for compose stack '$STACK' (timeout ${TIMEOUT}s)..."

while [ "$elapsed" -lt "$TIMEOUT" ]; do
  services=$(qemu-tool compose --stack "$STACK" ps --services 2>/dev/null || true)

  if [ -z "$services" ]; then
    echo "  No services found yet (${elapsed}s elapsed)"
    sleep 5
    elapsed=$((elapsed + 5))
    continue
  fi

  all_healthy=true
  for svc in $services; do
    health=$(qemu-tool compose --stack "$STACK" ps --format json "$svc" \
      | python3 -c "
import sys, json
data = json.load(sys.stdin)
if isinstance(data, list):
    healths = [d.get('Health', '') for d in data]
    print('healthy' if healths and all(h == 'healthy' for h in healths) else (healths[0] if healths else 'unknown'))
else:
    print(data.get('Health', 'unknown'))
" 2>/dev/null || echo "unknown")
    printf "  %-20s %s\n" "$svc" "$health"
    [ "$health" = "healthy" ] || all_healthy=false
  done

  if [ "$all_healthy" = "true" ]; then
    echo "All services healthy after ${elapsed}s"
    exit 0
  fi

  sleep 5
  elapsed=$((elapsed + 5))
done

echo "::error::Timed out waiting for healthy services after ${TIMEOUT}s"
qemu-tool compose --stack "$STACK" ps || true
exit 1
