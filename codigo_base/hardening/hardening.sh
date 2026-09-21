#!/usr/bin/env bash
set -Eeuo pipefail

MODE="${1:-}"
ROOT="${TP2_ROOT:-}"
STATE_DIR="${TP2_STATE_DIR:-${ROOT}/var/lib/tp2-hardening}"
LOG_FILE="${TP2_LOG_FILE:-${ROOT}/var/log/tp2-hardening.log}"
APPLIED=0
SKIPPED=0
CHECKED=0
ERRORS=0

usage() {
  cat <<'USAGE'
Uso: sudo ./hardening.sh --check | --apply | --restore

Variables para pruebas aisladas:
  TP2_ROOT=/ruta/raiz-ficticia
  TP2_STATE_DIR=/ruta/estado
  TP2_LOG_FILE=/ruta/log
USAGE
}

if [[ "$MODE" != "--check" && "$MODE" != "--apply" && "$MODE" != "--restore" ]]; then
  usage
  exit 2
fi

if [[ -z "$ROOT" && ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Error: para modificar el sistema real debe ejecutar el script con sudo." >&2
  exit 3
fi

path() { printf '%s%s' "$ROOT" "$1"; }

mkdir -p "$STATE_DIR" "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 0600 "$LOG_FILE" 2>/dev/null || true

log() {
  local level="$1" control="$2" message="$3"
  printf '%s [%s] [%s] %s\n' "$(date -Iseconds)" "$level" "$control" "$message" | tee -a "$LOG_FILE"
}

mark_applied() { APPLIED=$((APPLIED + 1)); log "APPLIED" "$1" "$2"; }
mark_skipped() { SKIPPED=$((SKIPPED + 1)); log "SKIPPED" "$1" "$2"; }
mark_checked() { CHECKED=$((CHECKED + 1)); log "CHECK" "$1" "$2"; }
mark_error() { ERRORS=$((ERRORS + 1)); log "ERROR" "$1" "$2"; }

backup_key() { printf '%s' "$1" | sed 's#/#__#g'; }

backup_file() {
  local target="$1" real key
  real="$(path "$target")"
  key="$(backup_key "$target")"
  if [[ -e "$real" && ! -e "$STATE_DIR/$key.existed" ]]; then
    cp -a "$real" "$STATE_DIR/$key.backup"
    : > "$STATE_DIR/$key.existed"
  elif [[ ! -e "$real" && ! -e "$STATE_DIR/$key.absent" ]]; then
    : > "$STATE_DIR/$key.absent"
  fi
}

restore_file() {
  local target="$1" real key
  real="$(path "$target")"
  key="$(backup_key "$target")"
  if [[ -e "$STATE_DIR/$key.existed" ]]; then
    mkdir -p "$(dirname "$real")"
    cp -a "$STATE_DIR/$key.backup" "$real"
    mark_applied "RESTORE" "Restaurado $target"
  elif [[ -e "$STATE_DIR/$key.absent" ]]; then
    rm -f "$real"
    mark_applied "RESTORE" "Eliminado $target porque no existia antes del TP"
  else
    mark_skipped "RESTORE" "Sin respaldo registrado para $target"
  fi
}

write_file() {
  local target="$1" mode="$2" content="$3" real tmp
  real="$(path "$target")"
  mkdir -p "$(dirname "$real")"
  tmp="$(mktemp "$(dirname "$real")/.tp2.XXXXXX")"
  printf '%s' "$content" > "$tmp"
  chmod "$mode" "$tmp"
  mv "$tmp" "$real"
}

SSH_FRAGMENT=/etc/ssh/sshd_config.d/99-tp2-hardening.conf
PWQUALITY_FRAGMENT=/etc/security/pwquality.conf.d/99-tp2-hardening.conf
UMASK_FRAGMENT=/etc/profile.d/99-tp2-hardening.sh
SYSCTL_FRAGMENT=/etc/sysctl.d/99-tp2-hardening.conf

SSH_CONTENT=$'# Configuracion TP2: impedir el acceso directo de root por SSH.\nPermitRootLogin no\n'
PWQUALITY_CONTENT=$'# Politica acotada de calidad de contrasenas para el TP2.\nminlen = 12\nminclass = 3\nmaxrepeat = 3\n'
UMASK_CONTENT=$'# Configuracion TP2 para nuevas sesiones.\numask 027\n'
SYSCTL_CONTENT=$'# Proteccion contra ataques de hardlinks y symlinks.\nfs.protected_hardlinks = 1\nfs.protected_symlinks = 1\n'

restore_file_silent() {
  local target="$1" real key
  real="$(path "$target")"
  key="$(backup_key "$target")"
  if [[ -e "$STATE_DIR/$key.existed" ]]; then
    mkdir -p "$(dirname "$real")"
    cp -a "$STATE_DIR/$key.backup" "$real"
  elif [[ -e "$STATE_DIR/$key.absent" ]]; then
    rm -f "$real"
  else
    return 1
  fi
}

backup_registered() {
  local target="$1" key
  key="$(backup_key "$target")"
  [[ -e "$STATE_DIR/$key.existed" || -e "$STATE_DIR/$key.absent" ]]
}

ssh_fragment_matches() {
  local file
  file="$(path "$SSH_FRAGMENT")"
  [[ -f "$file" ]] || return 1
  awk '
    /^[[:space:]]*#/ { next }
    $1 == "PermitRootLogin" {
      found = 1
      if ($2 != "no") bad = 1
    }
    END { exit !(found && !bad) }
  ' "$file"
}

sshd_effective_matches() {
  local output value
  [[ -z "$ROOT" ]] || return 0
  command -v sshd >/dev/null 2>&1 || return 1
  if ! output="$(sshd -T 2>/dev/null)"; then
    return 1
  fi
  value="$(awk '$1 == "permitrootlogin" { print $2; exit }' <<< "$output")"
  [[ "$value" == "no" ]]
}

validate_sshd_configuration() {
  sshd_syntax_valid || return 1
  sshd_effective_matches
}

sshd_syntax_valid() {
  [[ -z "$ROOT" ]] || return 0
  command -v sshd >/dev/null 2>&1 || return 1
  sshd -t >/dev/null 2>&1
}

reload_sshd() {
  [[ -z "$ROOT" ]] || return 0
  command -v systemctl >/dev/null 2>&1 || return 1
  systemctl reload ssh.service >/dev/null 2>&1 || systemctl reload ssh >/dev/null 2>&1
}

pam_pwquality_active() {
  local pam_dir file
  pam_dir="$(path /etc/pam.d)"
  [[ -d "$pam_dir" ]] || return 1

  while IFS= read -r -d '' file; do
    if awk '
      /^[[:space:]]*#/ { next }
      /(^|[[:space:]])pam_pwquality[.]so([[:space:]]|$)/ { found = 1 }
      END { exit !found }
    ' "$file"; then
      return 0
    fi
  done < <(find "$pam_dir" -maxdepth 1 -type f -print0 2>/dev/null)

  return 1
}

pwquality_setting_is() {
  local file="$1" key="$2" expected="$3"
  [[ -f "$file" ]] || return 1
  awk -F= -v wanted_key="$key" -v wanted_value="$expected" '
    /^[[:space:]]*#/ { next }
    {
      lhs = $1
      rhs = $2
      gsub(/[[:space:]]/, "", lhs)
      sub(/[[:space:]]*#.*/, "", rhs)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", rhs)
      if (lhs == wanted_key) {
        found = 1
        if (rhs != wanted_value) bad = 1
      }
    }
    END { exit !(found && !bad) }
  ' "$file"
}

pwquality_fragment_matches() {
  local file
  file="$(path "$PWQUALITY_FRAGMENT")"
  pwquality_setting_is "$file" minlen 12 || return 1
  pwquality_setting_is "$file" minclass 3 || return 1
  pwquality_setting_is "$file" maxrepeat 3
}

umask_fragment_matches() {
  local file actual
  file="$(path "$UMASK_FRAGMENT")"
  [[ -f "$file" ]] || return 1
  bash -n "$file" >/dev/null 2>&1 || return 1
  awk '
    /^[[:space:]]*#/ { next }
    $1 == "umask" {
      found = 1
      if ($2 != "027") bad = 1
    }
    END { exit !(found && !bad) }
  ' "$file" || return 1

  if ! actual="$(bash -c 'umask 022; . "$1"; umask' bash "$file" 2>/dev/null)"; then
    return 1
  fi
  [[ "$actual" == "0027" || "$actual" == "027" ]]
}

sysctl_setting_is() {
  local file="$1" key="$2" expected="$3"
  [[ -f "$file" ]] || return 1
  awk -F= -v wanted_key="$key" -v wanted_value="$expected" '
    /^[[:space:]]*#/ { next }
    {
      lhs = $1
      rhs = $2
      gsub(/[[:space:]]/, "", lhs)
      sub(/[[:space:]]*#.*/, "", rhs)
      gsub(/[[:space:]]/, "", rhs)
      if (lhs == wanted_key) {
        found = 1
        if (rhs != wanted_value) bad = 1
      }
    }
    END { exit !(found && !bad) }
  ' "$file"
}

sysctl_fragment_matches() {
  local file
  file="$(path "$SYSCTL_FRAGMENT")"
  sysctl_setting_is "$file" fs.protected_hardlinks 1 || return 1
  sysctl_setting_is "$file" fs.protected_symlinks 1
}

sysctl_effective_matches() {
  local hardlinks symlinks
  [[ -z "$ROOT" ]] || return 0
  command -v sysctl >/dev/null 2>&1 || return 1
  if ! hardlinks="$(sysctl -n fs.protected_hardlinks 2>/dev/null)"; then
    return 1
  fi
  if ! symlinks="$(sysctl -n fs.protected_symlinks 2>/dev/null)"; then
    return 1
  fi
  [[ "$hardlinks" == "1" && "$symlinks" == "1" ]]
}

apply_sysctl_fragment() {
  local file
  [[ -z "$ROOT" ]] || return 0
  command -v sysctl >/dev/null 2>&1 || return 1
  file="$(path "$SYSCTL_FRAGMENT")"
  sysctl -p "$file" >/dev/null 2>&1
}

control_uid0() {
  local passwd_file
  passwd_file="$(path /etc/passwd)"
  if [[ ! -r "$passwd_file" ]]; then
    mark_error "UID0" "No se puede leer /etc/passwd"
    return
  fi
  local extra
  extra="$(awk -F: '$3 == 0 && $1 != "root" {print $1}' "$passwd_file" | paste -sd, -)"
  if [[ -n "$extra" ]]; then
    mark_error "UID0" "Cuentas adicionales con UID 0: $extra. No se corrigen automaticamente."
  else
    mark_checked "UID0" "Solo root posee UID 0"
  fi
}

control_ssh() {
  local target="$SSH_FRAGMENT" had_backup

  case "$MODE" in
    --check)
      if ! ssh_fragment_matches; then
        mark_error "SSH" "Falta el fragmento $target o no fija PermitRootLogin no"
      elif [[ -n "$ROOT" ]]; then
        mark_checked "SSH" "El fragmento fija PermitRootLogin no (validacion aislada)"
      elif ! validate_sshd_configuration; then
        mark_error "SSH" "sshd -t o la configuracion efectiva no confirma PermitRootLogin no"
      else
        mark_checked "SSH" "Fragmento valido y configuracion efectiva con PermitRootLogin no"
      fi
      ;;
    --apply)
      if ssh_fragment_matches; then
        if [[ -n "$ROOT" ]] || validate_sshd_configuration; then
          mark_skipped "SSH" "El fragmento ya fija PermitRootLogin no"
        else
          mark_error "SSH" "El fragmento existe pero sshd no confirma la configuracion efectiva"
        fi
        return
      fi

      if ! backup_file "$target"; then
        mark_error "SSH" "No se pudo respaldar $target"
        return
      fi
      if ! write_file "$target" 0644 "$SSH_CONTENT"; then
        mark_error "SSH" "No se pudo escribir $target"
        return
      fi

      if ! validate_sshd_configuration; then
        restore_file_silent "$target" || true
        mark_error "SSH" "sshd rechazo la configuracion o no confirma PermitRootLogin no"
        return
      fi
      if ! reload_sshd; then
        restore_file_silent "$target" || true
        mark_error "SSH" "No se pudo recargar el servicio SSH; se restauro el archivo"
        return
      fi
      mark_applied "SSH" "Aplicado PermitRootLogin no en $target"
      ;;
    --restore)
      had_backup=0
      backup_registered "$target" && had_backup=1
      restore_file "$target"
      if (( had_backup )) && [[ -z "$ROOT" ]]; then
        if ! sshd_syntax_valid || ! reload_sshd; then
          mark_error "SSH" "Se restauro $target pero no se pudo validar o recargar SSH"
        fi
      fi
      ;;
  esac
}

control_pwquality() {
  local target="$PWQUALITY_FRAGMENT"

  case "$MODE" in
    --check)
      if ! pwquality_fragment_matches; then
        mark_error "PWQUALITY" "Falta $target o no coincide con la politica definida"
      elif ! pam_pwquality_active; then
        mark_error "PWQUALITY" "pam_pwquality.so no esta activo en la configuracion PAM"
      else
        mark_checked "PWQUALITY" "Politica definida y pam_pwquality.so activo"
      fi
      ;;
    --apply)
      if ! pam_pwquality_active; then
        mark_error "PWQUALITY" "No se aplica la politica: pam_pwquality.so no esta activo"
        return
      fi
      if pwquality_fragment_matches; then
        mark_skipped "PWQUALITY" "La politica ya coincide con $target"
        return
      fi
      if ! backup_file "$target"; then
        mark_error "PWQUALITY" "No se pudo respaldar $target"
        return
      fi
      if ! write_file "$target" 0644 "$PWQUALITY_CONTENT"; then
        mark_error "PWQUALITY" "No se pudo escribir $target"
        return
      fi
      mark_applied "PWQUALITY" "Aplicada politica minlen=12, minclass=3 y maxrepeat=3"
      ;;
    --restore)
      restore_file "$target"
      ;;
  esac
}

control_umask() {
  local target="$UMASK_FRAGMENT"

  case "$MODE" in
    --check)
      if umask_fragment_matches; then
        mark_checked "UMASK" "Las nuevas sesiones aplicaran umask 027 mediante $target"
      else
        mark_error "UMASK" "Falta $target o no configura umask 027"
      fi
      ;;
    --apply)
      if umask_fragment_matches; then
        mark_skipped "UMASK" "El fragmento ya configura umask 027"
        return
      fi
      if ! backup_file "$target"; then
        mark_error "UMASK" "No se pudo respaldar $target"
        return
      fi
      if ! write_file "$target" 0644 "$UMASK_CONTENT"; then
        mark_error "UMASK" "No se pudo escribir $target"
        return
      fi
      mark_applied "UMASK" "Configurado umask 027 para nuevas sesiones"
      ;;
    --restore)
      restore_file "$target"
      ;;
  esac
}

control_sysctl() {
  local target="$SYSCTL_FRAGMENT" real changed=0 had_backup
  real="$(path "$target")"

  case "$MODE" in
    --check)
      if ! sysctl_fragment_matches; then
        mark_error "SYSCTL" "Falta $target o no define los dos enlaces protegidos"
      elif [[ -n "$ROOT" ]]; then
        mark_checked "SYSCTL" "El archivo define ambos valores (validacion aislada)"
      elif ! sysctl_effective_matches; then
        mark_error "SYSCTL" "Los valores efectivos del kernel no son ambos 1"
      else
        mark_checked "SYSCTL" "Archivo persistente y valores efectivos fs.protected_* = 1"
      fi
      ;;
    --apply)
      if ! sysctl_fragment_matches; then
        if ! backup_file "$target"; then
          mark_error "SYSCTL" "No se pudo respaldar $target"
          return
        fi
        if ! write_file "$target" 0644 "$SYSCTL_CONTENT"; then
          mark_error "SYSCTL" "No se pudo escribir $target"
          return
        fi
        changed=1
      fi

      if ! apply_sysctl_fragment || ! sysctl_effective_matches; then
        if (( changed )); then
          restore_file_silent "$target" || true
        fi
        mark_error "SYSCTL" "No se pudieron aplicar o verificar los valores efectivos del kernel"
        return
      fi

      if (( changed )); then
        mark_applied "SYSCTL" "Persistidos fs.protected_hardlinks=1 y fs.protected_symlinks=1"
      else
        mark_skipped "SYSCTL" "El archivo y los valores efectivos ya son correctos"
      fi
      ;;
    --restore)
      had_backup=0
      backup_registered "$target" && had_backup=1
      restore_file "$target"
      if (( had_backup )) && [[ -z "$ROOT" && -f "$real" ]]; then
        if ! sysctl -p "$real" >/dev/null 2>&1; then
          mark_error "SYSCTL" "Se restauro $target pero no se pudieron aplicar sus valores"
        fi
      fi
      ;;
  esac
}

control_uid0
control_ssh
control_pwquality
control_umask
control_sysctl

log "RESUMEN" "TP2" "Aplicados=$APPLIED Omitidos=$SKIPPED Verificados=$CHECKED Errores=$ERRORS"

if (( ERRORS > 0 )); then
  exit 1
fi
