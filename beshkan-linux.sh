#!/bin/bash

set -euo pipefail

VERSION="1.0.0"
SCRIPT_NAME="Beshkan"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

show_version() {
    echo -e "${CYAN}${SCRIPT_NAME}${NC} v${VERSION}"
    echo "Linux DNS Switcher"
}

show_help() {
    echo -e "${CYAN}${BOLD}Beshkan${NC} - Fast DNS Switcher for Linux"
    echo ""
    echo -e "${BOLD}Usage:${NC}"
    echo "  beshkan-linux              Launch interactive DNS selector"
    echo "  beshkan-linux --status     Show current DNS settings"
    echo "  beshkan-linux --version    Show version"
    echo "  beshkan-linux --help       Show this help message"
    echo ""
    echo -e "${BOLD}Supported DNS Providers:${NC}"
    echo "  0) Reset to Default DNS    6) Cloudflare"
    echo "  1) Shecan                  7) 403"
    echo "  2) Electro                 8) Radar"
    echo "  3) Begzar                  9) Shelter"
    echo "  4) DNS Pro                10) Pishgaman"
    echo "  5) Google                 11) Shatel"
    echo ""
    echo -e "${BOLD}Requires:${NC} nmcli (NetworkManager) or resolvectl (systemd-resolved)"
}

check_dependencies() {
    if command -v nmcli &>/dev/null; then
        BACKEND="nmcli"
    elif command -v resolvectl &>/dev/null; then
        BACKEND="resolvectl"
    elif [ -f /etc/resolv.conf ]; then
        BACKEND="resolvconf"
    else
        echo -e "${RED}Error: No supported DNS management tool found.${NC}"
        echo "This script requires nmcli, resolvectl, or /etc/resolv.conf."
        exit 1
    fi
}

get_active_connection() {
    if [ "$BACKEND" = "nmcli" ]; then
        nmcli -t -f NAME,DEVICE connection show --active | head -n1 | cut -d: -f1
    fi
}

show_status() {
    echo -e "${CYAN}${BOLD}Current DNS Settings:${NC}"
    echo -e "  ${BOLD}Backend:${NC} ${BACKEND}"
    echo ""

    case $BACKEND in
        nmcli)
            con=$(get_active_connection)
            if [ -n "$con" ]; then
                dns=$(nmcli -f IP4.DNS connection show "$con" 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
                echo -e "  ${BOLD}Connection:${NC} ${con}"
                echo -e "  ${BOLD}DNS:${NC}        ${GREEN}${dns:-DHCP}${NC}"
            else
                echo -e "  ${YELLOW}No active connection found${NC}"
            fi
            ;;
        resolvectl)
            resolvectl status 2>/dev/null | grep -A5 "DNS Servers" || echo "  Could not read DNS status"
            ;;
        resolvconf)
            dns=$(grep nameserver /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
            echo -e "  ${BOLD}DNS:${NC} ${GREEN}${dns:-Not configured}${NC}"
            ;;
    esac
}

select_dns() {
    echo -e "\n${CYAN}${BOLD}Choose a DNS Provider:${NC}"
    echo -e "  ${YELLOW}0)${NC}  Reset to Default DNS"
    echo -e "  ${YELLOW}1)${NC}  Shecan"
    echo -e "  ${YELLOW}2)${NC}  Electro"
    echo -e "  ${YELLOW}3)${NC}  Begzar"
    echo -e "  ${YELLOW}4)${NC}  DNS Pro"
    echo -e "  ${YELLOW}5)${NC}  Google"
    echo -e "  ${YELLOW}6)${NC}  Cloudflare"
    echo -e "  ${YELLOW}7)${NC}  403"
    echo -e "  ${YELLOW}8)${NC}  Radar"
    echo -e "  ${YELLOW}9)${NC}  Shelter"
    echo -e "  ${YELLOW}10)${NC} Pishgaman"
    echo -e "  ${YELLOW}11)${NC} Shatel"
    echo ""
    read -p "Enter the number of the desired DNS: " choice
}

apply_dns() {
    case $choice in
        0) name="Default"; dns=() ;;
        1) name="Shecan"; dns=("178.22.122.100" "185.51.200.2") ;;
        2) name="Electro"; dns=("78.157.42.100" "78.157.42.101") ;;
        3) name="Begzar"; dns=("185.55.226.26" "185.55.226.25") ;;
        4) name="DNS Pro"; dns=("87.107.110.109" "87.107.110.110") ;;
        5) name="Google"; dns=("8.8.8.8" "8.8.4.4") ;;
        6) name="Cloudflare"; dns=("1.1.1.1" "1.0.0.1") ;;
        7) name="403"; dns=("10.202.10.202" "10.202.10.102") ;;
        8) name="Radar"; dns=("10.202.10.10" "10.202.10.11") ;;
        9) name="Shelter"; dns=("94.103.125.157" "94.103.125.158") ;;
        10) name="Pishgaman"; dns=("5.202.100.100" "5.202.100.101") ;;
        11) name="Shatel"; dns=("85.15.1.14" "85.15.1.15") ;;
        *) echo -e "${RED}Invalid selection.${NC}"; exit 1 ;;
    esac

    echo -e "\n${CYAN}Applying DNS settings via ${BACKEND}...${NC}\n"

    case $BACKEND in
        nmcli)
            con=$(get_active_connection)
            if [ -z "$con" ]; then
                echo -e "${RED}Error: No active NetworkManager connection found.${NC}"
                exit 1
            fi
            if [ "$choice" -eq 0 ]; then
                if nmcli connection modify "$con" ipv4.dns "" 2>/dev/null && \
                   nmcli connection modify "$con" ipv4.ignore-auto-dns no 2>/dev/null; then
                    echo -e "  ${GREEN}DNS reset to DHCP default for ${con}${NC}"
                else
                    echo -e "  ${RED}Failed to reset DNS${NC}"
                    exit 1
                fi
            else
                dns_str="${dns[0]} ${dns[1]}"
                if nmcli connection modify "$con" ipv4.dns "$dns_str" 2>/dev/null && \
                   nmcli connection modify "$con" ipv4.ignore-auto-dns yes 2>/dev/null; then
                    nmcli connection up "$con" &>/dev/null || true
                    echo -e "  ${GREEN}${name} (${dns_str}) applied to ${con}${NC}"
                else
                    echo -e "  ${RED}Failed to set DNS${NC}"
                    exit 1
                fi
            fi
            ;;
        resolvectl)
            iface=$(ip route show default | awk '{print $5}' | head -n1)
            if [ -z "$iface" ]; then
                echo -e "${RED}Error: Could not detect default network interface.${NC}"
                exit 1
            fi
            if [ "$choice" -eq 0 ]; then
                if resolvectl dns "$iface" --reset 2>/dev/null; then
                    echo -e "  ${GREEN}DNS reset to default for ${iface}${NC}"
                else
                    echo -e "  ${RED}Failed to reset DNS${NC}"
                    exit 1
                fi
            else
                if resolvectl dns "$iface" "${dns[@]}" 2>/dev/null; then
                    echo -e "  ${GREEN}${name} applied to ${iface}${NC}"
                else
                    echo -e "  ${RED}Failed to set DNS${NC}"
                    exit 1
                fi
            fi
            ;;
        resolvconf)
            echo -e "${YELLOW}Warning: resolv.conf editing requires root and may be overwritten by DHCP.${NC}"
            if [ "$choice" -eq 0 ]; then
                echo -e "  ${YELLOW}Please restart your network manager to reset DNS.${NC}"
            else
                echo -e "  ${YELLOW}DNS servers: ${dns[*]}${NC}"
                echo -e "  ${YELLOW}Add to /etc/resolv.conf or configure via your network manager.${NC}"
            fi
            ;;
    esac

    echo -e "\n${GREEN}${BOLD}Done!${NC} DNS configuration updated."
}

main() {
    case "${1:-}" in
        --version|-v) show_version; exit 0 ;;
        --help|-h) show_help; exit 0 ;;
        --status|-s)
            check_dependencies
            show_status
            exit 0
            ;;
    esac

    check_dependencies
    select_dns
    apply_dns
}

main "$@"
