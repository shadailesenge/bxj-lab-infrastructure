#!/bin/bash
# ==============================================================================
# Zones et politiques firewalld de SRV-LINUX (AlmaLinux)
# ens160 -> zone internal (LAN-BXJ) | ens224 -> zone external (NAT-LAB)
# Auteur : LESENGE NGANI Shadai - Projet Module 5 BXJ Technologies
# ==============================================================================
# Affectation des interfaces aux zones
sudo firewall-cmd --permanent --zone=external --change-interface=ens224
sudo firewall-cmd --permanent --zone=internal --change-interface=ens160

# Politique LAN-BXJ -> NAT-LAB / Internet, avec traduction d'adresses
sudo firewall-cmd --permanent --new-policy int_to_ext
sudo firewall-cmd --permanent --policy int_to_ext --add-ingress-zone internal
sudo firewall-cmd --permanent --policy int_to_ext --add-egress-zone external
sudo firewall-cmd --permanent --policy int_to_ext --set-target ACCEPT
sudo firewall-cmd --permanent --policy int_to_ext --add-masquerade
sudo firewall-cmd --reload

# Politique NAT-LAB -> LAN-BXJ (VM de test vers le domaine)
sudo firewall-cmd --permanent --new-policy ext_to_int
sudo firewall-cmd --permanent --policy ext_to_int --add-ingress-zone external
sudo firewall-cmd --permanent --policy ext_to_int --add-egress-zone internal
sudo firewall-cmd --permanent --policy ext_to_int --set-target ACCEPT
sudo firewall-cmd --reload
sudo firewall-cmd --info-policy ext_to_int

# Tests depuis une VM de test
ping -c 3 172.16.0.20     # ens160 du routeur
ping -c 3 172.16.0.10     # le DC
ping -c 3 172.16.0.101    # WIN_10
