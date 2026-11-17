# ==============================================================================
# Stratégies de groupe (GPO)
# Crée GPO-Blocage-USB et GPO-Verrouillage-Session, liées à OU=Postes,OU=BXJ.
# Exécution : PowerShell en administrateur sur SHADAILAB
# Auteur : LESENGE NGANI Shadai - Projet Module 5 BXJ Technologies
# ==============================================================================
$ErrorActionPreference = "Stop"

Import-Module ActiveDirectory
Import-Module GroupPolicy

$domain = Get-ADDomain
$server = $domain.PDCEmulator
$domainName = $domain.DNSRoot
$parentOU = "OU=BXJ,$($domain.DistinguishedName)"
$OUPostes = "OU=Postes,$parentOU"

# Vérifie que l'OU cible existe.
$ouExistante = Get-ADOrganizationalUnit `
    -Filter "Name -eq 'Postes'" `
    -SearchBase $parentOU `
    -SearchScope OneLevel `
    -Server $server

if (-not $ouExistante) {
    throw "L'OU Postes est introuvable sous BXJ : $OUPostes"
}

# S'assure que les deux GPO existent.
$gpoUSB = Get-GPO -Name "GPO-Blocage-USB" -Domain $domainName -Server $server -ErrorAction SilentlyContinue
if (-not $gpoUSB) {
    $gpoUSB = New-GPO -Name "GPO-Blocage-USB" -Comment "Bloque le stockage USB" -Domain $domainName -Server $server
}

$gpoSession = Get-GPO -Name "GPO-Verrouillage-Session" -Domain $domainName -Server $server -ErrorAction SilentlyContinue
if (-not $gpoSession) {
    $gpoSession = New-GPO -Name "GPO-Verrouillage-Session" -Comment "Verrouillage après 3 minutes" -Domain $domainName -Server $server
}

# Configure le blocage du stockage amovible.
Set-GPRegistryValue `
    -Guid $gpoUSB.Id `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices" `
    -ValueName "Deny_All" `
    -Type DWord `
    -Value 1 `
    -Domain $domainName `
    -Server $server

# Configure le verrouillage après 180 secondes d'inactivité.
Set-GPRegistryValue `
    -Guid $gpoSession.Id `
    -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
    -ValueName "InactivityTimeoutSecs" `
    -Type DWord `
    -Value 180 `
    -Domain $domainName `
    -Server $server

# Lie chaque GPO à l'OU Postes si le lien n'existe pas déjà.
$liensActuels = (Get-GPInheritance `
    -Target $OUPostes `
    -Domain $domainName `
    -Server $server).GpoLinks

foreach ($nomGPO in @("GPO-Blocage-USB", "GPO-Verrouillage-Session")) {
    $lien = $liensActuels | Where-Object { $_.DisplayName -eq $nomGPO }

    if ($lien) {
        Set-GPLink `
            -Name $nomGPO `
            -Target $OUPostes `
            -LinkEnabled Yes `
            -Domain $domainName `
            -Server $server | Out-Null
        Write-Host "Lien activé : $nomGPO"
    }
    else {
        New-GPLink `
            -Name $nomGPO `
            -Target $OUPostes `
            -LinkEnabled Yes `
            -Domain $domainName `
            -Server $server | Out-Null
        Write-Host "Lien créé : $nomGPO"
    }
}

# Vérifie les liens sur l'OU.
Get-GPInheritance -Target $OUPostes -Domain $domainName -Server $server |
    Select-Object -ExpandProperty GpoLinks |
    Select-Object DisplayName, Enabled, Order
