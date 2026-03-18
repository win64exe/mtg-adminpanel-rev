#!/bin/bash
set +H

# ============================================================
#  MTG AdminPanel — Main Menu
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

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Запусти скрипт от root: sudo bash menu.sh${NC}"
    exit 1
fi

print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}      ⚙️   MTG AdminPanel — Control Menu         ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${DIM}      https://github.com/win64exe/mtg-adminpanel-rev ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    print_header
    echo -e "${WHITE}Выбери действие:${NC}"
    echo -e "  ${CYAN}[1]${NC} Установить панель"
    echo -e "  ${CYAN}[2]${NC} Обновить панель"
    echo -e "  ${CYAN}[3]${NC} Остановить панель"
    echo -e "  ${CYAN}[4]${NC} Запустить панель"
    echo -e "  ${CYAN}[5]${NC} Перезагрузить панель"
    echo -e "  ${CYAN}[6]${NC} Просмотр логов"
    echo -e "  ${CYAN}[7]${NC} ${RED}Полное удаление и очистка Docker${NC}"
    echo -e "  ${CYAN}[0]${NC} Выход"
    echo ""
    echo -ne "${WHITE}Выбор: ${NC}"
    read -r choice
}

install_panel() {
    if [ -f "./install.sh" ]; then
        bash ./install.sh
    else
        echo -e "${CYAN}▶ Загрузка установщика...${NC}"
        curl -fsSL https://raw.githubusercontent.com/win64exe/mtg-adminpanel-rev/main/install.sh -o install.sh
        bash ./install.sh
    fi
    pause
}

update_panel() {
    if [ -d "$INSTALL_DIR" ]; then
        if [ -f "$INSTALL_DIR/update.sh" ]; then
            bash "$INSTALL_DIR/update.sh"
        else
            echo -e "${CYAN}▶ Обновление...${NC}"
            cd "$INSTALL_DIR" && git pull && docker compose up -d --build
        fi
    else
        echo -e "${RED}❌ Панель не установлена!${NC}"
    fi
    pause
}

stop_panel() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${CYAN}▶ Остановка...${NC}"
        cd "$INSTALL_DIR" && docker compose stop
        echo -e "${GREEN}✅ Остановлено${NC}"
    else
        echo -e "${RED}❌ Панель не установлена!${NC}"
    fi
    pause
}

start_panel() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${CYAN}▶ Запуск...${NC}"
        cd "$INSTALL_DIR" && docker compose start
        echo -e "${GREEN}✅ Запущено${NC}"
    else
        echo -e "${RED}❌ Панель не установлена!${NC}"
    fi
    pause
}

restart_panel() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${CYAN}▶ Перезапуск...${NC}"
        cd "$INSTALL_DIR" && docker compose restart
        echo -e "${GREEN}✅ Перезапущено${NC}"
    else
        echo -e "${RED}❌ Панель не установлена!${NC}"
    fi
    pause
}

show_logs() {
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR" && docker compose logs -f --tail=100
    else
        echo -e "${RED}❌ Панель не установлена!${NC}"
        pause
    fi
}

delete_everything() {
    echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║           ВНИМАНИЕ! ПОЛНАЯ ОЧИСТКА!              ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}Это действие удалит:${NC}"
    echo -e "  • ВСЕ Docker контейнеры (не только панель!)"
    echo -e "  • ВСЕ Docker образы, сети и volumes"
    echo -e "  • Директории $INSTALL_DIR, /opt/mtg, /opt/mtg-agent"
    echo -e "  • Системные сервисы и конфиги"
    echo ""
    echo -ne "${RED}Ты уверен? Введи 'yes' для подтверждения: ${NC}"
    read -r confirm
    if [ "$confirm" == "yes" ]; then
        echo -e "${CYAN}▶ Остановка всех контейнеров...${NC}"
        docker stop $(docker ps -aq) 2>/dev/null
        echo -e "${CYAN}▶ Удаление всех контейнеров...${NC}"
        docker rm $(docker ps -aq) 2>/dev/null
        
        echo -e "${CYAN}▶ Полная очистка Docker (system prune)...${NC}"
        docker system prune -a --volumes -f
        
        echo -e "${CYAN}▶ Удаление файлов и директорий...${NC}"
        if [ -f "/etc/systemd/system/mtg-adminpanel.service" ]; then
            systemctl disable mtg-adminpanel 2>/dev/null
            rm -f /etc/systemd/system/mtg-adminpanel.service
            systemctl daemon-reload
        fi
        rm -rf "$INSTALL_DIR"
        rm -rf "/opt/mtg"
        rm -rf "/opt/mtg-agent"
        
        echo -e "${GREEN}✅ Система полностью очищена!${NC}"
    else
        echo -e "${DIM}Отменено.${NC}"
    fi
    pause
}

pause() {
    echo ""
    echo -ne "${DIM}Нажми Enter для продолжения...${NC}"
    read -r
}

while true; do
    show_menu
    case $choice in
        1) install_panel ;;
        2) update_panel ;;
        3) stop_panel ;;
        4) start_panel ;;
        5) restart_panel ;;
        6) show_logs ;;
        7) delete_everything ;;
        0) exit 0 ;;
        *) echo -e "${RED}Неверный выбор!${NC}"; sleep 1 ;;
    esac
done
