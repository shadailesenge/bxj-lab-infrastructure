#!/usr/bin/env bash
# backup_bxj.sh — archive BXJ et restauration ciblée d'un fichier du partage.
# AlmaLinux 9. Usage : backup_bxj.sh {backup|list|restore ARCHIVE /data/entreprise/FICHIER}
set -Eeuo pipefail
umask 077

DEST="/backup"
LOG="/var/log/backup_bxj.log"
RETENTION_DAYS=7

log() {
  printf '%s - %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"
}

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Exécutez ce script avec sudo." >&2
    exit 1
  fi
}

backup() {
  require_root
  [[ -d /data/entreprise ]] || { log "ERREUR : /data/entreprise est absent"; exit 2; }
  install -d -o root -g root -m 0700 "$DEST"
  local stamp archive tmp
  stamp="$(date '+%Y-%m-%d_%H-%M-%S')"
  archive="$DEST/backup_${stamp}.tar.gz"
  tmp="${archive}.tmp"

  log "Début de la sauvegarde vers $archive"
  tar -czpf "$tmp" -C / \
    data/entreprise \
    etc/samba \
    etc/ssh \
    etc/hosts \
    etc/fstab 2>>"$LOG"
  mv -- "$tmp" "$archive"
  chmod 0600 "$archive"
  tar -tzf "$archive" >/dev/null
  log "Sauvegarde vérifiée : $(du -h "$archive" | cut -f1)"

  find "$DEST" -maxdepth 1 -type f -name 'backup_*.tar.gz' \
    -mtime "+$RETENTION_DAYS" -print -delete |
    while IFS= read -r file; do log "Ancienne archive supprimée : $file"; done
  printf '%s\n' "$archive"
}

list_backups() {
  require_root
  ls -lh "$DEST"/backup_*.tar.gz 2>/dev/null || {
    echo "Aucune archive trouvée dans $DEST."
    return 1
  }
}

restore_file() {
  require_root
  local archive="${1:-}" requested member
  requested="${2:-}"
  [[ -f "$archive" ]] || { echo "Archive introuvable : $archive" >&2; exit 2; }
  [[ "$requested" == /data/entreprise/* ]] || {
    echo "Pour cette démonstration, le fichier à restaurer doit être sous /data/entreprise/." >&2
    exit 2
  }
  [[ "$requested" != *'/../'* && "$requested" != */.. ]] || {
    echo "Chemin de restauration invalide." >&2
    exit 2
  }
  member="${requested#/}"
  tar -tzf "$archive" "$member" >/dev/null 2>&1 || {
    echo "Le fichier $requested ne figure pas dans cette archive." >&2
    exit 2
  }
  log "Restauration de $requested depuis $archive"
  tar -xzpf "$archive" -C / -- "$member"
  log "Restauration terminée : $requested"
}

case "${1:-}" in
  backup)
    backup
    ;;
  list)
    list_backups
    ;;
  restore)
    shift
    restore_file "${1:-}" "${2:-}"
    ;;
  *)
    echo "Usage : $0 {backup|list|restore ARCHIVE /data/entreprise/FICHIER}" >&2
    exit 2
    ;;
esac
