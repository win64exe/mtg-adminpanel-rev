#!/bin/bash
cd /tmp  # ensure valid working directory before we delete install dir
set +H

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
    echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${WHITE}      🗑️   MTG AdminPanel — Uninstall            ${NC}${RED}║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Запусти скрипт от root: sudo bash uninstall.sh${NC}"
    exit 1
fi

print_header

echo -e "${YELLOW}⚠️  Это удалит:${NC}"
echo -e "  • Контейнер mtg-panel"
echo -e "  • Директории ${CYAN}$INSTALL_DIR, /opt/mtg, /opt/mtg-agent${NC}"
echo -e "  • Nginx конфиг mtg-panel (если есть)"
echo -e "  • Systemd сервис mtg-adminpanel"
echo ""
echo -ne "${RED}Ты уверен? Все данные будут удалены! (y/N)${NC}: "
IFS= read -r CONFIRM < /dev/tty
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo -e "${DIM}Отменено.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Хочешь выполнить ПОЛНУЮ очистку Docker?${NC}"
echo -e "  (удалит ВСЕ контейнеры, образы и volumes на сервере)"
echo -ne "${WHITE}Очистить всё? (y/N)${NC}: "
IFS= read -r FULL_PRUNE < /dev/tty

echo ""

# Останавливаем и удаляем контейнер
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${CYAN}▶ Останавливаем панель...${NC}"
    cd "$INSTALL_DIR" && docker compose down 2>/dev/null
    echo -e "${GREEN}✅ Панель остановлена${NC}"
fi

if [[ "$FULL_PRUNE" == "y" || "$FULL_PRUNE" == "Y" ]]; then
    echo -e "${CYAN}▶ Полная очистка Docker...${NC}"
    docker stop $(docker ps -aq) 2>/dev/null
    docker rm $(docker ps -aq) 2>/dev/null
    docker system prune -a --volumes -f
    echo -e "${GREEN}✅ Docker полностью очищен${NC}"
fi

# Удаляем директории
echo -e "${CYAN}▶ Удаляем файлы и директории...${NC}"
rm -rf "$INSTALL_DIR"
rm -rf "/opt/mtg"
rm -rf "/opt/mtg-agent"
echo -e "${GREEN}✅ Директории удалены${NC}"

# Удаляем systemd сервис
if [ -f "/etc/systemd/system/mtg-adminpanel.service" ]; then
    echo -e "${CYAN}▶ Удаляем systemd сервис...${NC}"
    systemctl disable mtg-adminpanel 2>/dev/null
    rm -f /etc/systemd/system/mtg-adminpanel.service
    systemctl daemon-reload
    echo -e "${GREEN}✅ Сервис удалён${NC}"
fi

# Удаляем Nginx конфиг
if [ -f "/etc/nginx/sites-available/mtg-panel" ]; then
    echo -e "${CYAN}▶ Удаляем Nginx конфиг...${NC}"
    rm -f /etc/nginx/sites-available/mtg-panel
    rm -f /etc/nginx/sites-enabled/mtg-panel
    systemctl reload nginx 2>/dev/null
    echo -e "${GREEN}✅ Nginx конфиг удалён${NC}"
fi

# Удаляем Docker образ
echo -e "${CYAN}▶ Удаляем Docker образ...${NC}"
docker rmi mtg-adminpanel-mtg-panel 2>/dev/null || true
echo -e "${GREEN}✅ Образ удалён${NC}"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${WHITE}        ✅  MTG AdminPanel удалён!               ${NC}${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
