#!/bin/bash
cd /tmp  # ensure valid working directory from the start
set +H  # отключаем history expansion (для токенов со спецсимволами)

# ============================================================
#  MTG AdminPanel — Install Script
#  https://github.com/win64exe/mtg-adminpanel-rev
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'

INSTALL_DIR="/opt/mtg-adminpanel"

print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}      🔒  MTG AdminPanel — Installer             ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${DIM}      https://github.com/win64exe/mtg-adminpanel-rev ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}▶ $1${NC}"
}

print_ok() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# ── Проверка root ────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    print_error "Запусти скрипт от root: sudo bash install.sh"
    exit 1
fi

print_header

# ── Сбор переменных ──────────────────────────────────────────
echo -e "${WHITE}Настройка MTG AdminPanel${NC}"
echo -e "${DIM}Ответь на несколько вопросов для установки.${NC}"
echo ""

# AUTH_TOKEN
while true; do
    DEFAULT_AUTH=$(openssl rand -hex 12)
    echo -ne "${WHITE}Токен авторизации${NC} ${DIM}(пароль для входа)${NC} [${CYAN}${DEFAULT_AUTH}${NC}]: "
    IFS= read -r AUTH_INPUT < /dev/tty
    AUTH_TOKEN=${AUTH_INPUT:-$DEFAULT_AUTH}
    if [ ${#AUTH_TOKEN} -ge 6 ]; then
        break
    else
        print_warn "Токен должен быть минимум 6 символов"
    fi
done

# PORT
echo -ne "${WHITE}Порт панели${NC} ${DIM}[3000]${NC}: "
IFS= read -r PORT_INPUT < /dev/tty
PORT=${PORT_INPUT:-3000}

# SSL
echo ""
echo -e "${WHITE}Нужен ли SSL?${NC}"
echo -e "  ${CYAN}[1]${NC} Нет — только HTTP (http://IP:$PORT)"
echo -e "  ${CYAN}[2]${NC} Да — через Caddy (авто-HTTPS, нужен домен)"
echo -ne "  Выбор ${DIM}[1]${NC}: "
IFS= read -r SSL_CHOICE < /dev/tty
SSL_CHOICE=${SSL_CHOICE:-1}

DOMAIN=""
EMAIL=""
if [ "$SSL_CHOICE" == "2" ]; then
    echo -ne "${WHITE}Домен${NC} ${DIM}(например proxy.yourdomain.com)${NC}: "
    IFS= read -r DOMAIN < /dev/tty
    echo -ne "${WHITE}Email${NC} ${DIM}(для Let's Encrypt)${NC}: "
    IFS= read -r EMAIL < /dev/tty
fi

# ── Подтверждение ────────────────────────────────────────────
echo ""
echo -e "${DIM}────────────────────────────────────────────────────${NC}"
echo -e "${WHITE}Параметры установки:${NC}"
echo -e "  Директория:  ${CYAN}$INSTALL_DIR${NC}"
echo -e "  Порт:        ${CYAN}$PORT${NC}"
echo -e "  Auth Token:  ${CYAN}$AUTH_TOKEN${NC}"
if [ "$SSL_CHOICE" == "2" ]; then
    echo -e "  Домен:       ${CYAN}$DOMAIN${NC}"
    echo -e "  Email:       ${CYAN}$EMAIL${NC}"
fi
echo -e "${DIM}────────────────────────────────────────────────────${NC}"
echo ""
echo -ne "${WHITE}Начать установку? (y/N)${NC}: "
IFS= read -r CONFIRM < /dev/tty
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo -e "${DIM}Отменено.${NC}"
    exit 0
fi

echo ""

# ── Обновление системы ───────────────────────────────────────
print_step "Обновление системы..."
apt-get update -qq && apt-get upgrade -y -qq
print_ok "Система обновлена"

# ── Установка зависимостей ───────────────────────────────────
print_step "Установка зависимостей..."
apt-get install -y -qq curl wget git unzip
print_ok "Зависимости установлены"

# ── Установка Docker ─────────────────────────────────────────
if ! command -v docker &> /dev/null; then
    print_step "Установка Docker..."
    curl -fsSL https://get.docker.com | sh
    print_ok "Docker установлен"
else
    print_ok "Docker уже установлен ($(docker --version | cut -d' ' -f3 | tr -d ','))"
fi

# ── Клонирование репозитория ─────────────────────────────────
print_step "Загрузка MTG AdminPanel..."
if [ -d "$INSTALL_DIR" ]; then
    print_warn "Директория $INSTALL_DIR уже существует — полная переустановка..."
    cd "$INSTALL_DIR" && docker compose down &>/dev/null || true
    # Удаляем всё кроме папок с данными, если они нужны, но для "чистой" лучше удалить всё
    # Чтобы сохранить данные (БД и ключи), можно не удалять папки data и ssh_keys
    # Но пользователь просил "все очищалось и удалялось"
    cd /tmp && rm -rf "$INSTALL_DIR"
fi

git clone -q https://github.com/win64exe/mtg-adminpanel-rev.git "$INSTALL_DIR"
print_ok "Репозиторий загружен"

# ── Создание .env ────────────────────────────────────────────
print_step "Создание конфигурации..."
mkdir -p "$INSTALL_DIR/data" "$INSTALL_DIR/ssh_keys"

# Генерация AGENT_TOKEN если его нет
AGENT_TOKEN=$(openssl rand -hex 32)

cat > "$INSTALL_DIR/.env" << EOF
AUTH_TOKEN=$AUTH_TOKEN
AGENT_TOKEN=$AGENT_TOKEN
PORT=$PORT
DATA_DIR=/data
EOF

print_ok "Конфигурация создана"

# ── Запуск Docker Compose ────────────────────────────────────
print_step "Запуск панели..."
cd "$INSTALL_DIR"
docker compose up -d --build 2>&1 | tail -5
sleep 3

if docker ps | grep -q mtg-panel; then
    print_ok "Панель запущена"
else
    print_error "Ошибка запуска! Проверь: docker logs mtg-panel"
    exit 1
fi

# ── Настройка SSL (Caddy) ────────────────────────────────────
if [ "$SSL_CHOICE" == "2" ] && [ -n "$DOMAIN" ]; then
    print_step "Настройка Caddy..."
    
    cat > "$INSTALL_DIR/Caddyfile" << EOF
{
    email $EMAIL
}

$DOMAIN {
    reverse_proxy mtg-panel:3000
}
EOF

    # Обновляем docker-compose.yml для работы с Caddy
    cat > "$INSTALL_DIR/docker-compose.yml" << EOF
name: mtg-panel

services:
  mtg-panel:
    build: .
    container_name: mtg-panel
    restart: unless-stopped
    volumes:
      - ./data:/data
      - ./ssh_keys:/ssh_keys:ro
    environment:
      - PORT=3000
      - DATA_DIR=/data
      - AUTH_TOKEN=$AUTH_TOKEN
      - AGENT_TOKEN=$AGENT_TOKEN
      - SECRET_DOMAIN=$DOMAIN

  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data

volumes:
  caddy_data:
EOF
    
    cd "$INSTALL_DIR"
    docker compose up -d --build caddy
    print_ok "Caddy настроен и запущен"
fi

# ── Автозапуск ───────────────────────────────────────────────
print_step "Настройка автозапуска..."
cat > /etc/systemd/system/mtg-adminpanel.service << EOF
[Unit]
Description=MTG AdminPanel
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/docker compose up
ExecStop=/usr/bin/docker compose down
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mtg-adminpanel -q
print_ok "Автозапуск настроен"

# ── Итог ─────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${GREEN}           ✅  Установка завершена!              ${NC}${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$SSL_CHOICE" == "2" ] && [ -n "$DOMAIN" ]; then
    echo -e "  🌐 Панель:  ${CYAN}https://$DOMAIN${NC}"
else
    IP=$(curl -s -4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    echo -e "  🌐 Панель:  ${CYAN}http://$IP:$PORT${NC}"
fi

echo -e "  🔑 Токен:   ${CYAN}$AUTH_TOKEN${NC}"
echo ""
echo -e "${DIM}  Управление:${NC}"
echo -e "  ${DIM}docker logs mtg-panel -f     — логи${NC}"
echo -e "  ${DIM}docker restart mtg-panel     — перезапуск${NC}"
echo -e "  ${DIM}cd $INSTALL_DIR && docker compose down  — остановка${NC}"
echo ""
