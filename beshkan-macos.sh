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
    echo "macOS DNS Switcher"
}

show_help() {
    echo -e "${CYAN}${BOLD}Beshkan${NC} - Fast DNS Switcher for macOS"
    echo ""
    echo -e "${BOLD}Usage:${NC}"
    echo "  beshkan              Launch interactive DNS selector"
    echo "  beshkan --status     Show current DNS settings"
    echo "  beshkan --version    Show version"
    echo "  beshkan --help       Show this help message"
    echo ""
    echo -e "${BOLD}Supported DNS Providers:${NC}"
    echo "  0) Reset to macOS Default DNS"
    echo "  1) Shecan       7) 403"
    echo "  2) Electro      8) Radar"
    echo "  3) Begzar       9) Shelter"
    echo "  4) DNS Pro     10) Pishgaman"
    echo "  5) Google      11) Shatel"
    echo "  6) Cloudflare"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  beshkan                    # Interactive mode"
    echo "  beshkan --status           # Check current DNS"
    echo ""
    echo -e "${BOLD}Requires:${NC} macOS with networksetup (built-in)"
}

show_status() {
    echo -e "${CYAN}${BOLD}Current DNS Settings:${NC}"
    echo ""
    services=$(networksetup -listallnetworkservices | tail -n +2)
    for service in $services; do
        dns=$(networksetup -getdnsservers "$service" 2>/dev/null)
        if echo "$dns" | grep -q "There aren't any DNS Servers"; then
            dns="Default (DHCP)"
        fi
        echo -e "  ${BOLD}${service}:${NC}"
        echo -e "    ${GREEN}${dns}${NC}"
    done
}

select_dns() {
    echo -e "\n${CYAN}${BOLD}Choose a DNS Provider:${NC}"
    echo -e "  ${YELLOW}0)${NC}  Reset to macOS Default DNS"
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
        0) name="Default"; dns="reset" ;;
        1) name="Shecan"; dns="178.22.122.100 185.51.200.2" ;;
        2) name="Electro"; dns="78.157.42.100 78.157.42.101" ;;
        3) name="Begzar"; dns="185.55.226.26 185.55.226.25" ;;
        4) name="DNS Pro"; dns="87.107.110.109 87.107.110.110" ;;
        5) name="Google"; dns="8.8.8.8 8.8.4.4" ;;
        6) name="Cloudflare"; dns="1.1.1.1 1.0.0.1" ;;
        7) name="403"; dns="10.202.10.202 10.202.10.102" ;;
        8) name="Radar"; dns="10.202.10.10 10.202.10.11" ;;
        9) name="Shelter"; dns="94.103.125.157 94.103.125.158" ;;
        10) name="Pishgaman"; dns="5.202.100.100 5.202.100.101" ;;
        11) name="Shatel"; dns="85.15.1.14 85.15.1.15" ;;
        *) echo -e "${RED}Invalid selection.${NC}"; exit 1 ;;
    esac

    services=$(networksetup -listallnetworkservices | tail -n +2)

    echo -e "\n${CYAN}Applying DNS settings...${NC}\n"

    success=0
    fail=0

    for service in $services; do
        echo -n "  ${service}: "
        if [ "$dns" == "reset" ]; then
            if networksetup -setdnsservers "$service" "Empty" 2>/dev/null; then
                echo -e "${GREEN}Reset to default${NC}"
                ((success++))
            else
                echo -e "${RED}Failed${NC}"
                ((fail++))
            fi
        else
            if networksetup -setdnsservers "$service" $dns 2>/dev/null; then
                echo -e "${GREEN}Set to ${name}${NC}"
                ((success++))
            else
                echo -e "${RED}Failed${NC}"
                ((fail++))
            fi
        fi
    done

    echo ""
    echo -e "${GREEN}${BOLD}Done!${NC} ${success} service(s) updated, ${fail} failed."
}

main() {
    case "${1:-}" in
        --version|-v) show_version; exit 0 ;;
        --help|-h) show_help; exit 0 ;;
        --status|-s) show_status; exit 0 ;;
    esac

    select_dns
    apply_dns
}

main "$@"
