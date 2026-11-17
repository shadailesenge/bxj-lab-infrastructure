# ==============================================================================
# Unités d'organisation, groupes et comptes
# Crée l'OU BXJ, 6 sous-OU, 5 groupes GRP-<service> et 10 comptes (script idempotent).
# Exécution : PowerShell en administrateur sur SHADAILAB (contrôleur de domaine)
# Auteur : LESENGE NGANI Shadai - Projet Module 5 BXJ Technologies
# ==============================================================================
$ErrorActionPreference = "Stop"

try {
    Import-Module ActiveDirectory -ErrorAction Stop

    # Détecte le domaine et le contrôleur de domaine.
    $domain = Get-ADDomain -ErrorAction Stop
    $server = $domain.PDCEmulator
    $racine = $domain.DistinguishedName
    $base = "OU=BXJ,$racine"

    # Un même mot de passe temporaire sera demandé pour les dix comptes.
    $motDePasse = Read-Host `
        -Prompt "Saisissez le mot de passe temporaire commun aux dix comptes" `
        -AsSecureString

    if ($motDePasse.Length -eq 0) {
        throw "Le mot de passe ne peut pas être vide."
    }

    # Crée BXJ si cette OU n'existe pas déjà sous la racine du domaine.
    $ouBXJ = Get-ADOrganizationalUnit `
        -Filter "Name -eq 'BXJ'" `
        -SearchBase $racine `
        -SearchScope OneLevel `
        -Server $server `
        -ErrorAction SilentlyContinue

    if (-not $ouBXJ) {
        New-ADOrganizationalUnit `
            -Name "BXJ" `
            -Path $racine `
            -Server $server `
            -ProtectedFromAccidentalDeletion $true `
            -ErrorAction Stop | Out-Null

        Write-Host "OU créée : BXJ"
    }

    # Crée les sous-OU si elles n'existent pas.
    $ous = @(
        "Direction",
        "Administration",
        "Informatique",
        "Comptabilite",
        "Utilisateurs",
        "Postes"
    )

    foreach ($nomOU in $ous) {
        $ouExistante = Get-ADOrganizationalUnit `
            -Filter "Name -eq '$nomOU'" `
            -SearchBase $base `
            -SearchScope OneLevel `
            -Server $server `
            -ErrorAction SilentlyContinue

        if (-not $ouExistante) {
            New-ADOrganizationalUnit `
                -Name $nomOU `
                -Path $base `
                -Server $server `
                -ProtectedFromAccidentalDeletion $true `
                -ErrorAction Stop | Out-Null

            Write-Host "OU créée : $nomOU"
        }
    }

    # Données des dix utilisateurs.
    $utilisateurs = @(
        [PSCustomObject]@{ Prenom="Jean";    Nom="Mukendi";   Login="jmukendi";   OU="Direction" },
        [PSCustomObject]@{ Prenom="Marie";   Nom="Kabongo";   Login="mkabongo";   OU="Direction" },
        [PSCustomObject]@{ Prenom="Patrick"; Nom="Tshimanga"; Login="ptshimanga"; OU="Administration" },
        [PSCustomObject]@{ Prenom="Grace";   Nom="Mbuyi";     Login="gmbuyi";     OU="Administration" },
        [PSCustomObject]@{ Prenom="David";   Nom="Kalala";    Login="dkalala";    OU="Informatique" },
        [PSCustomObject]@{ Prenom="Sarah";   Nom="Ilunga";    Login="silunga";    OU="Informatique" },
        [PSCustomObject]@{ Prenom="Joel";    Nom="Nkulu";     Login="jnkulu";     OU="Comptabilite" },
        [PSCustomObject]@{ Prenom="Ruth";    Nom="Kasongo";   Login="rkasongo";   OU="Comptabilite" },
        [PSCustomObject]@{ Prenom="Eric";    Nom="Mwamba";    Login="emwamba";    OU="Utilisateurs" },
        [PSCustomObject]@{ Prenom="Esther";  Nom="Lukusa";    Login="elukusa";    OU="Utilisateurs" }
    )

    # Crée les groupes de sécurité dans leurs OU.
    $ousAvecGroupes = @(
        "Direction",
        "Administration",
        "Informatique",
        "Comptabilite",
        "Utilisateurs"
    )

    foreach ($nomOU in $ousAvecGroupes) {
        $nomGroupe = "GRP-$nomOU"
        $cheminOU = "OU=$nomOU,$base"

        $groupe = Get-ADGroup `
            -Filter "SamAccountName -eq '$nomGroupe'" `
            -SearchBase $racine `
            -SearchScope Subtree `
            -Server $server `
            -ErrorAction SilentlyContinue

        if (-not $groupe) {
            $groupe = New-ADGroup `
                -Name $nomGroupe `
                -SamAccountName $nomGroupe `
                -GroupScope Global `
                -GroupCategory Security `
                -Path $cheminOU `
                -Server $server `
                -PassThru `
                -ErrorAction Stop

            Write-Host "Groupe créé : $nomGroupe"
        }
        elseif ($groupe.DistinguishedName -notlike "*,$cheminOU") {
            # Replace le groupe dans son OU de service si nécessaire.
            Move-ADObject `
                -Identity $groupe.ObjectGUID `
                -TargetPath $cheminOU `
                -Server $server `
                -ErrorAction Stop

            $groupe = Get-ADGroup `
                -Filter "SamAccountName -eq '$nomGroupe'" `
                -SearchBase $racine `
                -SearchScope Subtree `
                -Server $server `
                -ErrorAction Stop
        }
    }

    # Crée ou met à jour les comptes, puis les ajoute à leurs groupes.
    foreach ($u in $utilisateurs) {
        $nomComplet = "$($u.Prenom) $($u.Nom)"
        $upn = "$($u.Login)@$($domain.DNSRoot)"
        $cheminOU = "OU=$($u.OU),$base"
        $nomGroupe = "GRP-$($u.OU)"

        # Recherche dans le domaine par identifiant SAM.
        $compte = Get-ADUser `
            -Filter "SamAccountName -eq '$($u.Login)'" `
            -SearchBase $racine `
            -SearchScope Subtree `
            -Server $server `
            -Properties SID `
            -ErrorAction SilentlyContinue

        if ($compte) {
            # Évite de déplacer automatiquement un compte situé hors de BXJ.
            if ($compte.DistinguishedName -notlike "*,$base") {
                throw "Le compte $($u.Login) existe hors de BXJ : $($compte.DistinguishedName)"
            }

            # Replace le compte dans son OU de service si nécessaire.
            if ($compte.DistinguishedName -notlike "*,$cheminOU") {
                Move-ADObject `
                    -Identity $compte.ObjectGUID `
                    -TargetPath $cheminOU `
                    -Server $server `
                    -ErrorAction Stop
            }

            $compte = Get-ADUser `
                -Filter "SamAccountName -eq '$($u.Login)'" `
                -SearchBase $racine `
                -SearchScope Subtree `
                -Server $server `
                -Properties SID `
                -ErrorAction Stop

            Set-ADUser `
                -Identity $compte.ObjectGUID `
                -GivenName $u.Prenom `
                -Surname $u.Nom `
                -DisplayName $nomComplet `
                -UserPrincipalName $upn `
                -Server $server `
                -ErrorAction Stop

            Set-ADAccountPassword `
                -Identity $compte.ObjectGUID `
                -Reset `
                -NewPassword $motDePasse `
                -Server $server `
                -ErrorAction Stop

            Enable-ADAccount `
                -Identity $compte.ObjectGUID `
                -Server $server `
                -ErrorAction Stop

            Set-ADUser `
                -Identity $compte.ObjectGUID `
                -ChangePasswordAtLogon $true `
                -Server $server `
                -ErrorAction Stop

            Write-Host "Compte mis à jour : $($u.Login)"
        }
        else {
            $compte = New-ADUser `
                -Name $nomComplet `
                -GivenName $u.Prenom `
                -Surname $u.Nom `
                -DisplayName $nomComplet `
                -SamAccountName $u.Login `
                -UserPrincipalName $upn `
                -Path $cheminOU `
                -AccountPassword $motDePasse `
                -Enabled $true `
                -ChangePasswordAtLogon $true `
                -Server $server `
                -PassThru `
                -ErrorAction Stop

            Write-Host "Compte créé : $($u.Login)"
        }

        # Ajoute le compte au groupe de service s'il n'en est pas déjà membre.
        $groupe = Get-ADGroup `
            -Filter "SamAccountName -eq '$nomGroupe'" `
            -SearchBase $racine `
            -SearchScope Subtree `
            -Server $server `
            -ErrorAction Stop

        $membres = Get-ADGroupMember `
            -Identity $groupe `
            -Server $server `
            -ErrorAction Stop

        $dejaMembre = $membres | Where-Object {
            $_.SID.Value -eq $compte.SID.Value
        }

        if (-not $dejaMembre) {
            Add-ADGroupMember `
                -Identity $groupe `
                -Members $compte `
                -Server $server `
                -ErrorAction Stop
        }

        Write-Host "Vérifié : $($u.Login) dans $nomGroupe"
    }

    Write-Host ""
    Write-Host "SUCCÈS : OU, groupes et comptes traités dans le domaine $($domain.DNSRoot)."
}
catch {
    $erreur = $_
    Write-Host ""
    Write-Host "ÉCHEC à la ligne $($erreur.InvocationInfo.ScriptLineNumber) :" -ForegroundColor Red
    Write-Host $erreur.Exception.Message -ForegroundColor Red
    Write-Host $erreur.InvocationInfo.Line -ForegroundColor Red
    exit 1
}
