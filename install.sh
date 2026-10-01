#!/usr/bin/env bash
# Install eitaas-vdi for the current user (no root needed).
#
#   ./install.sh               install or update
#   ./install.sh --uninstall   remove the program and launcher entry
#   ./install.sh --purge       also remove the imported profile, sign-in browser data and logs
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bin_dir=${XDG_BIN_HOME:-$HOME/.local/bin}
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
app_dir=$data_home/applications

case ${1:-} in
--uninstall | --purge)
  rm -f "$bin_dir/eitaas-vdi" "$app_dir/eitaas-vdi.desktop"
  if [[ $1 == --purge ]]; then
    rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/eitaas-vdi" \
      "$data_home/eitaas-vdi" \
      "${XDG_STATE_HOME:-$HOME/.local/state}/eitaas-vdi"
  fi
  command -v update-desktop-database >/dev/null && update-desktop-database "$app_dir" 2>/dev/null || true
  if [[ $1 == --purge ]]; then
    echo "eitaas-vdi removed, including the profile, sign-in data and logs."
  else
    echo "eitaas-vdi removed. Your profile and logs were kept (use --purge to remove them)."
  fi
  exit 0
  ;;
"") ;;
*)
  echo "usage: $0 [--uninstall | --purge]" >&2
  exit 2
  ;;
esac

install -Dm755 "$here/eitaas-vdi" "$bin_dir/eitaas-vdi"
mkdir -p "$app_dir"
sed "s|@BIN@|$bin_dir/eitaas-vdi|g" "$here/eitaas-vdi.desktop.in" >"$app_dir/eitaas-vdi.desktop"
chmod 644 "$app_dir/eitaas-vdi.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database "$app_dir" 2>/dev/null || true

echo "Installed $bin_dir/eitaas-vdi and the “EITaaS VDI” launcher entry."
echo
echo "System check:"
"$bin_dir/eitaas-vdi" doctor || true
echo
echo "Next: fix anything marked ✗ (see docs/SOP.md), then launch “EITaaS VDI” from your app launcher."
