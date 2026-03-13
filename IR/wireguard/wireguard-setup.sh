#!/bin/bash
# WireGuard Setup Script for 2-host peer configuration
# Run this script on BOTH hosts. Each host will generate its config,
# then you'll need to exchange public keys and set up the peer.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}"
echo "================================================"
echo "        WireGuard 2-Host Setup Script           "
echo "================================================"
echo -e "${NC}"

# Must be root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR] This script must be run as root (sudo).${NC}"
    exit 1
fi

# ─── Gather Input ────────────────────────────────────────────────────────────

echo -e "${YELLOW}[INPUT] Enter this host's public IP address (used as the WireGuard endpoint):${NC}"
read -rp "  Host public IP: " HOST_IP

echo -e "${YELLOW}[INPUT] Enter this host's WireGuard tunnel IP (e.g. 10.0.0.1):${NC}"
read -rp "  WireGuard IP: " WG_IP

echo -e "${YELLOW}[INPUT] Enter the WireGuard subnet CIDR (e.g. 24 for /24):${NC}"
read -rp "  CIDR: " CIDR

echo -e "${YELLOW}[INPUT] Enter the WireGuard listen port (default: 51820):${NC}"
read -rp "  Port [51820]: " WG_PORT
WG_PORT=${WG_PORT:-51820}

# ─── Install WireGuard ────────────────────────────────────────────────────────

echo -e "\n${GREEN}[1/5] Installing WireGuard...${NC}"
apt-get update -qq
apt-get install -y wireguard

# ─── Generate Keys ────────────────────────────────────────────────────────────

echo -e "${GREEN}[2/5] Generating keys...${NC}"
PRIVATE_KEY=$(wg genkey)
PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)

echo -e "  Private key saved (not displayed for security)"
echo -e "  ${CYAN}Public key: ${PUBLIC_KEY}${NC}"

# ─── Configure Interface ──────────────────────────────────────────────────────

echo -e "${GREEN}[3/5] Configuring WireGuard interface (wg0)...${NC}"

ip link add dev wg0 type wireguard 2>/dev/null || echo "  (wg0 already exists, reconfiguring)"
ip address flush dev wg0 2>/dev/null || true
ip address add dev wg0 "${WG_IP}/${CIDR}"
echo "$PRIVATE_KEY" | wg set wg0 private-key /dev/stdin
wg set wg0 listen-port "$WG_PORT"
ip link set wg0 up

echo -e "  Interface wg0 is UP at ${WG_IP}/${CIDR} on port ${WG_PORT}"

# ─── Save Config File ─────────────────────────────────────────────────────────

echo -e "${GREEN}[4/5] Saving config to /etc/wireguard/wg0.conf...${NC}"

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = ${WG_IP}/${CIDR}
ListenPort = ${WG_PORT}
PrivateKey = ${PRIVATE_KEY}

# Peer section will be added below after exchanging public keys
# [Peer]
# PublicKey = <peer_public_key>
# AllowedIPs = <peer_wireguard_ip>/32
# Endpoint = <peer_host_ip>:<peer_port>
EOF

chmod 600 /etc/wireguard/wg0.conf
echo -e "  Config saved to /etc/wireguard/wg0.conf"

# ─── Peer Setup ───────────────────────────────────────────────────────────────

echo -e "${GREEN}[5/5] Peer configuration...${NC}"
echo ""
echo -e "${YELLOW}  Share the following with the OTHER host:${NC}"
echo -e "  ┌─────────────────────────────────────────────┐"
echo -e "  │  Public Key : ${PUBLIC_KEY}"
echo -e "  │  Endpoint   : ${HOST_IP}:${WG_PORT}"
echo -e "  │  WireGuard IP: ${WG_IP}"
echo -e "  └─────────────────────────────────────────────┘"
echo ""

read -rp "  Once you have the OTHER host's details, add the peer now? [y/N]: " ADD_PEER
if [[ "$ADD_PEER" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[INPUT] Enter the peer's WireGuard public key:${NC}"
    read -rp "  Peer public key: " PEER_PUBLIC_KEY

    echo -e "${YELLOW}[INPUT] Enter the peer's WireGuard tunnel IP (e.g. 10.0.0.2):${NC}"
    read -rp "  Peer WireGuard IP: " PEER_WG_IP

    echo -e "${YELLOW}[INPUT] Enter the peer's public host IP:${NC}"
    read -rp "  Peer host IP: " PEER_HOST_IP

    echo -e "${YELLOW}[INPUT] Enter the peer's WireGuard listen port (default: 51820):${NC}"
    read -rp "  Peer port [51820]: " PEER_PORT
    PEER_PORT=${PEER_PORT:-51820}

    # Apply peer to running interface
    wg set wg0 peer "$PEER_PUBLIC_KEY" \
        allowed-ips "${PEER_WG_IP}/32" \
        endpoint "${PEER_HOST_IP}:${PEER_PORT}"

    # Append peer to config file
    cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
PublicKey = ${PEER_PUBLIC_KEY}
AllowedIPs = ${PEER_WG_IP}/32
Endpoint = ${PEER_HOST_IP}:${PEER_PORT}
EOF

    echo -e "\n${GREEN}  Peer added successfully!${NC}"
    echo -e "  Testing connectivity to ${PEER_WG_IP}..."
    if ping -c 3 -W 2 "$PEER_WG_IP" &>/dev/null; then
        echo -e "  ${GREEN}SUCCESS: Peer is reachable at ${PEER_WG_IP}${NC}"
    else
        echo -e "  ${YELLOW}WARNING: Peer not yet reachable. Ensure the other host has also added this host as a peer.${NC}"
    fi
else
    echo -e "  ${YELLOW}Skipping peer setup. Run the following manually when ready:${NC}"
    echo ""
    echo "    wg set wg0 peer <peer_public_key> \\"
    echo "        allowed-ips <peer_wireguard_ip>/32 \\"
    echo "        endpoint <peer_host_ip>:<peer_port>"
    echo ""
    echo "  Then append a [Peer] block to /etc/wireguard/wg0.conf"
fi

# ─── Enable on Boot ───────────────────────────────────────────────────────────

read -rp "  Enable wg0 to start on boot with systemd? [y/N]: " ENABLE_BOOT
if [[ "$ENABLE_BOOT" =~ ^[Yy]$ ]]; then
    systemctl enable wg-quick@wg0
    echo -e "  ${GREEN}wg-quick@wg0 enabled on boot.${NC}"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}================================================"
echo -e "              Setup Complete!"
echo -e "================================================${NC}"
echo ""
echo -e "  Interface   : wg0"
echo -e "  WireGuard IP: ${WG_IP}/${CIDR}"
echo -e "  Listen port : ${WG_PORT}"
echo -e "  Public key  : ${PUBLIC_KEY}"
echo ""
echo -e "  Run ${YELLOW}wg${NC} to view current status."
echo -e "  Config file : /etc/wireguard/wg0.conf"
echo ""