#!/bin/sh

BASE=$1
NAME=$2
START_PORT=$3
MTG_IMAGE=$4
SECRET_DOMAIN=$5

USER_DIR="$BASE/$NAME"
if [ -d "$USER_DIR" ]; then echo EXISTS; exit 1; fi

MAX_PORT=$(grep -r "[0-9]*:3128" "$BASE" 2>/dev/null | grep -oE "[0-9]+:3128" | cut -d: -f1 | sort -n | tail -1)
[ -z "$MAX_PORT" ] && PORT=$START_PORT || PORT=$((MAX_PORT + 1))

SECRET=\"ee$(openssl rand -hex 16)$(echo -n $SECRET_DOMAIN | xxd -p)\"

mkdir -p "$USER_DIR"

printf 'secret = "%s"\nbind-to = "0.0.0.0:3128"\n' "$SECRET" > "$USER_DIR/config.toml"

printf 'services:\n  mtg-%s:\n    image: %s\n    container_name: mtg-%s\n    restart: unless-stopped\n    ports:\n      - "%s:3128"\n    volumes:\n      - %s/config.toml:/config.toml:ro\n    command: run /config.toml\n' "$NAME" "$MTG_IMAGE" "$NAME" "$PORT" "$USER_DIR" > "$USER_DIR/docker-compose.yml"

cd "$USER_DIR" && docker compose up -d 2>&1

echo "OK|$NAME|$PORT|$SECRET"
