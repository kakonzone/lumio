#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <url-file> [concurrency]"
  exit 1
fi

URL_FILE="$1"
CONCURRENCY="${2:-100}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ ! -f "$URL_FILE" ]]; then
  echo "URL file not found: $URL_FILE"
  exit 1
fi

mapfile -t URLS < <(awk '!/^\s*(#|$)/ {gsub(/^ +| +$/, "", $0); if(length($0)>0) print $0}' "$URL_FILE")
if [[ ${#URLS[@]} -eq 0 ]]; then
  echo "No URLs found in $URL_FILE"
  exit 1
fi

run_for_url() {
  local url="$1"
  local out_file="$2"
  : > "$out_file"
  for _ in $(seq 1 "$CONCURRENCY"); do
    (
      result="$(curl -L -s -o /dev/null --connect-timeout 5 --max-time 20 -w "%{http_code} %{time_total}" "$url" || true)"
      if [[ -z "$result" ]]; then
        echo "000 20.000"
      else
        echo "$result" | awk 'NF{last=$0} END{print last}'
      fi
    ) >> "$out_file" &
  done
  wait
}

summarize() {
  local url="$1"
  local out_file="$2"
  python3 - "$url" "$out_file" <<'PY'
import sys
url, path = sys.argv[1], sys.argv[2]
rows=[]
with open(path) as f:
    for line in f:
        p=line.strip().split()
        if len(p)!=2:
            continue
        try:
            rows.append((p[0], float(p[1])))
        except:
            pass
if not rows:
    print(f"{url} | no data")
    raise SystemExit(0)
total=len(rows)
ok=sum(1 for c,_ in rows if c.startswith('2'))
fail=total-ok
net000=sum(1 for c,_ in rows if c=='000')
times=sorted(t for _,t in rows)
idx=max(0, int(len(times)*0.95)-1)
p95=times[idx]
avg=sum(times)/len(times)
print(f"{url} | req={total} ok={ok} fail={fail} net000={net000} avg={avg:.3f}s p95={p95:.3f}s")
PY
}

echo "=== Stream stress test (concurrency=$CONCURRENCY) ==="
for idx in "${!URLS[@]}"; do
  url="${URLS[$idx]}"
  out="$TMP_DIR/$idx.txt"
  run_for_url "$url" "$out"
  summarize "$url" "$out"
done
