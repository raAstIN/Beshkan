#!/bin/bash

set -euo pipefail

VERSION="1.0.0"
SCRIPT_NAME="Beshkan"
CUSTOM_DNS_FILE="${HOME}/.beshkan_dns"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PROVIDER_NAMES=("Shecan" "Electro" "Begzar" "DNS Pro" "Google" "Cloudflare" "403" "Radar" "Shelter" "Pishgaman" "Shatel")
PROVIDER_PRIMARY=("178.22.122.100" "78.157.42.100" "185.55.226.26" "87.107.110.109" "8.8.8.8" "1.1.1.1" "10.202.10.202" "10.202.10.10" "94.103.125.157" "5.202.100.100" "85.15.1.14")
PROVIDER_SECONDARY=("185.51.200.2" "78.157.42.101" "185.55.226.25" "87.107.110.110" "8.8.4.4" "1.0.0.1" "10.202.10.102" "10.202.10.11" "94.103.125.158" "5.202.100.101" "85.15.1.15")

show_version() {
    echo -e "${CYAN}${SCRIPT_NAME}${NC} v${VERSION}"
    echo "Linux DNS Switcher"
}

show_help() {
    echo -e "${CYAN}${BOLD}Beshkan${NC} - Fast DNS Switcher for Linux"
    echo ""
    echo -e "${BOLD}Usage:${NC}"
    echo "  beshkan              Launch interactive DNS selector"
    echo "  beshkan --status     Show current DNS settings"
    echo "  beshkan --version    Show version"
    echo "  beshkan --help       Show this help message"
    echo ""
    echo -e "${BOLD}Supported DNS Providers:${NC}"
    echo "  0) Reset to Default DNS"
    echo "  1-11) Built-in DNS providers"
    echo "  a) Add a custom DNS provider"
    echo ""
    echo -e "${BOLD}Requires:${NC} nmcli (NetworkManager) or resolvectl (systemd-resolved)"
}

is_valid_ipv4() {
    local ip="$1" part
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r -a parts <<< "$ip"
    for part in "${parts[@]}"; do
        ((10#$part >= 0 && 10#$part <= 255)) || return 1
    done
}

sanitize_title() {
    local title="$1"
    title="${title//|/ }"
    title="${title//$'\n'/ }"
    echo "$title"
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

print_provider_menu() {
    echo -e "\n${CYAN}${BOLD}Choose a DNS Provider:${NC}"
    echo -e "  ${YELLOW}0)${NC}  Reset to Default DNS"

    local i number
    for i in "${!PROVIDER_NAMES[@]}"; do
        number=$((i + 1))
        printf "  ${YELLOW}%s)${NC}  %s\n" "$number" "${PROVIDER_NAMES[$i]}"
    done

    if [ -f "$CUSTOM_DNS_FILE" ]; then
        number=12
        while IFS='|' read -r title primary secondary; do
            [ -n "${title:-}" ] || continue
            printf "  ${YELLOW}%s)${NC}  %s (%s, %s)\n" "$number" "$title" "$primary" "$secondary"
            number=$((number + 1))
        done < "$CUSTOM_DNS_FILE"
    fi

    echo -e "  ${YELLOW}a)${NC}  Add custom DNS"
    echo ""
}

add_custom_dns() {
    local title primary secondary

    read -r -p "Title for this DNS provider: " title
    read -r -p "Primary DNS address: " primary
    read -r -p "Secondary DNS address: " secondary

    title=$(sanitize_title "$title")
    if [ -z "$title" ]; then
        echo -e "${RED}Title cannot be empty.${NC}"
        return 1
    fi
    if ! is_valid_ipv4 "$primary" || ! is_valid_ipv4 "$secondary"; then
        echo -e "${RED}Invalid IPv4 address.${NC}"
        return 1
    fi

    printf "%s|%s|%s\n" "$title" "$primary" "$secondary" >> "$CUSTOM_DNS_FILE"
    choice=$(wc -l < "$CUSTOM_DNS_FILE" | tr -d ' ')
    choice=$((choice + 11))
    echo -e "${GREEN}Added ${title} to the end of the list.${NC}"
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
    while true; do
        print_provider_menu
        read -r -p "Enter the number of the desired DNS: " choice

        if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
            add_custom_dns && return
        else
            return
        fi
    done
}

resolve_choice() {
    local custom_index custom_line

    case "$choice" in
        0) name="Default"; dns=(); return 0 ;;
        ''|*[!0-9]*) echo -e "${RED}Invalid selection.${NC}"; exit 1 ;;
    esac

    if ((choice >= 1 && choice <= ${#PROVIDER_NAMES[@]})); then
        local index=$((choice - 1))
        name="${PROVIDER_NAMES[$index]}"
        dns=("${PROVIDER_PRIMARY[$index]}" "${PROVIDER_SECONDARY[$index]}")
        return 0
    fi

    custom_index=$((choice - 11))
    if ((custom_index >= 1)) && [ -f "$CUSTOM_DNS_FILE" ]; then
        custom_line=$(sed -n "${custom_index}p" "$CUSTOM_DNS_FILE")
        if [ -n "$custom_line" ]; then
            IFS='|' read -r name primary secondary <<< "$custom_line"
            dns=("$primary" "$secondary")
            return 0
        fi
    fi

    echo -e "${RED}Invalid selection.${NC}"
    exit 1
}

apply_dns() {
    resolve_choice

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
                    nmcli connection up "$con" &>/dev/null || true
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
                if resolvectl revert "$iface" 2>/dev/null; then
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
