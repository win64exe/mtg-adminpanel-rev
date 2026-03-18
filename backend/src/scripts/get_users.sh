#!/bin/sh

BASE=$1

# Ensure BASE exists
[ -d "$BASE" ] || exit 0

for DIR in "$BASE"/*/; do
  # Check if directory is actually a proxy user directory (must contain config.toml)
  [ -f "$DIR/config.toml" ] || continue
  
  NAME=$(basename "$DIR")
  SECRET=$(grep "secret" "$DIR/config.toml" 2>/dev/null | sed -E "s/.*['\"]([^'\"]+)['\"].*/\1/")
  PORT=$(grep -oE "[0-9]+:3128" "$DIR/docker-compose.yml" 2>/dev/null | cut -d: -f1)
  STATUS=$(docker ps --filter "name=mtg-$NAME" --format '{{.Status}}' 2>/dev/null)
  PID=$(docker inspect --format '{{.State.Pid}}' "mtg-$NAME" 2>/dev/null)
  CONNS=0
  if [ -n "$PID" ] && [ "$PID" != "0" ]; then
    CONNS=$(awk 'NR>1 && $4=="01" && substr($2,index($2,":")+1)=="0C38"{c++} END{print c+0}' /proc/$PID/net/tcp /proc/$PID/net/tcp6 2>/dev/null || echo 0)
  fi
  echo "USER|$NAME|$PORT|$SECRET|${STATUS:-stopped}|$CONNS"
done
