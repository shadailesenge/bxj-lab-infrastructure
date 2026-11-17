# ==============================================================================
# Synchronisation de l'heure
# Déclare le contrôleur de domaine comme source de temps fiable (Kerberos).
# Exécution : PowerShell en administrateur sur SHADAILAB
# Auteur : LESENGE NGANI Shadai - Projet Module 5 BXJ Technologies
# ==============================================================================
w32tm /config /manualpeerlist:131.107.13.100,0x8 /syncfromflags:manual /reliable:yes /update
Restart-Service w32time
w32tm /resync /rediscover
w32tm /query /source
w32tm /query /status
