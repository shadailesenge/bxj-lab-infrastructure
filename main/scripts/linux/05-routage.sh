#!/bin/bash
# ==============================================================================
# Script de configuration du routeur AlmaLinux
# Auteur : LESENGE NGANI Shadai
# Interfaces : ens160 (172.16.0.20/24) & ens224 (192.168.100.20/24)
# ==============================================================================

set -e

echo "=== 1. Configuration des interfaces réseau en statique ==="
# Configuration ens160 (Réseau 172.16.0.0/24)
sudo nmcli connection modify ens160 ipv4.addresses 172.16.0.20/24 ipv4.gateway 172.16.0.1 ipv4.dns "8.8.8.8" ipv4.method manual
sudo nmcli connection up ens160

# Configuration ens224 (Réseau 192.168.100.0/24)
sudo nmcli connection modify ens224 ipv4.addresses 192.168.100.20/24 ipv4.method manual
sudo nmcli connection up ens224

echo "=== 2. Activation permanente du routage IPv4 ==="
# Activation à chaud
sudo sysctl -w net.ipv4.ip_forward=1

# Persistance au redémarrage
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
fi
sudo sysctl -p

echo "=== 3. Configuration du pare-feu (Firewalld / NAT) ==="
sudo firewall-cmd --zone=public --add-masquerade --permanent
sudo firewall-cmd --reload

echo "=== Configuration terminée avec succès ! ==="
