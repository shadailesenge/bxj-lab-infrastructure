# ==============================================================================
# Serveur DHCP
# Étendue LAN_BXJ, exclusions et options (routeur, DNS, suffixe bxj.lab).
# Exécution : PowerShell en administrateur sur SHADAILAB
# Auteur : LESENGE NGANI Shadai - Projet Module 5 BXJ Technologies
# ==============================================================================
# À exécuter dans PowerShell en tant qu'administrateur sur SHADAILAB.

$Server = "SHADAILAB.bxj.lab"
$ScopeId = "172.16.0.0"
$StartRange = "172.16.0.1"
$EndRange = "172.16.0.50"
$SubnetMask = "255.255.255.0"

# Vérifier que le serveur DHCP est autorisé dans Active Directory.
$AuthorizedServer = Get-DhcpServerInDC |
    Where-Object { $_.IPAddress -eq "172.16.0.10" }

if (-not $AuthorizedServer) {
    throw "Le serveur DHCP 172.16.0.10 n'apparaît pas comme autorisé dans Active Directory."
}

# Créer l'étendue si elle n'existe pas encore.
$Scope = Get-DhcpServerv4Scope -ComputerName $Server -ErrorAction SilentlyContinue |
    Where-Object { $_.ScopeId -eq $ScopeId }

if (-not $Scope) {
    Add-DhcpServerv4Scope `
        -ComputerName $Server `
        -Name "LAN_BXJ" `
        -StartRange $StartRange `
        -EndRange $EndRange `
        -SubnetMask $SubnetMask `
        -State Active

    Write-Host "Étendue LAN_BXJ créée."
}
else {
    Write-Host "L'étendue $ScopeId existe déjà : aucune nouvelle étendue n'a été créée."
}

# Adresses à protéger des attributions automatiques :
# .1 à .20 pour les adresses fixes du réseau, puis .40 à .43 selon la consigne.
$Exclusions = @(
    @{ Start = "172.16.0.1";  End = "172.16.0.20" }
    @{ Start = "172.16.0.40"; End = "172.16.0.43" }
)

$ExistingExclusions = Get-DhcpServerv4ExclusionRange `
    -ComputerName $Server `
    -ScopeId $ScopeId `
    -ErrorAction SilentlyContinue

foreach ($Exclusion in $Exclusions) {
    $AlreadyExists = $ExistingExclusions | Where-Object {
        $_.StartRange.ToString() -eq $Exclusion.Start -and
        $_.EndRange.ToString() -eq $Exclusion.End
    }

    if (-not $AlreadyExists) {
        Add-DhcpServerv4ExclusionRange `
            -ComputerName $Server `
            -ScopeId $ScopeId `
            -StartRange $Exclusion.Start `
            -EndRange $Exclusion.End

        Write-Host "Exclusion ajoutée : $($Exclusion.Start) à $($Exclusion.End)"
    }
}

# Distribuer le DNS du contrôleur et le suffixe du domaine.
Set-DhcpServerv4OptionValue `
    -ComputerName $Server `
    -ScopeId $ScopeId `
    -DnsServer "172.16.0.10" `
    -DnsDomain "bxj.lab"

# Afficher la configuration obtenue.
Get-DhcpServerv4Scope -ComputerName $Server -ScopeId $ScopeId
Get-DhcpServerv4ExclusionRange -ComputerName $Server -ScopeId $ScopeId
Get-DhcpServerv4OptionValue -ComputerName $Server -ScopeId $ScopeId

# Ajout de la passerelle (routeur SRV-LINUX) dans les options de l'étendue.
Get-DhcpServerv4Scope
Get-DhcpServerv4OptionValue -ScopeId 172.16.0.0
Set-DhcpServerv4OptionValue -ScopeId 172.16.0.0 -Router 172.16.0.20 -DnsServer 172.16.0.10 -DnsDomain bxj.lab
