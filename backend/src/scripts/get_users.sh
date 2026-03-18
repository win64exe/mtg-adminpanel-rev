#!/bin/sh

BASE=$1

for DIR in $BASE/*/; do
  [ -d "$DIR" ] || continue
  NAME=$(basename "$DIR")
  SECRET=$(grep secret "$DIR/config.toml" 2>/dev/null | awk -F'"' '{print $2}')
  PORT=$(grep -o '[0-9]*:3128' "$DIR/docker-compose.yml" 2>/dev/null | cut -d: -f1)
  STATUS=$(docker ps --filter "name=mtg-$NAME" --format '{{.Status}}' 2>/dev/null)
  PID=$(docker inspect --format '{{.State.Pid}}' "mtg-$NAME" 2>/dev/null)
  CONNS=0
  if [ -n "$PID" ] && [ "$PID" != "0" ]; then
    CONNS=$(awk 'NR>1 && $4=="01" && substr($2,index($2,":")+1)=="0C38"{c++} END{print c+0}' /proc/$PID/net/tcp /proc/$PID/net/tcp6 2>/dev/null || echo 0)
  fi
  echo "USER|$NAME|$PORT|$SECRET|${STATUS:-stopped}|$CONNS"
done
