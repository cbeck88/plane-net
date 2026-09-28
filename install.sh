#!/usr/bin/env bash
# Install plane-net: script on PATH, SSH config Include, TCP MTU probing sysctl.
# Safe to rerun.
set -eu
DIR=$(cd "$(dirname "$0")" && pwd)

mkdir -p ~/bin
ln -sf "$DIR/plane-net" ~/bin/plane-net
echo "linked ~/bin/plane-net"

# Prepended, because OpenSSH takes the first value it finds for each option.
INCLUDE="Include $DIR/ssh-config-github"
[ -d ~/.ssh ] || mkdir -m 700 ~/.ssh
touch ~/.ssh/config
if grep -qxF "$INCLUDE" ~/.ssh/config; then
  echo "$HOME/.ssh/config already includes ssh-config-github"
else
  tmp=$(mktemp)
  { echo "$INCLUDE"; cat ~/.ssh/config; } > "$tmp"
  # Writing through the existing file keeps its permissions, and a symlinked config stays a symlink.
  cat "$tmp" > ~/.ssh/config
  rm "$tmp"
  echo "added '$INCLUDE' to the top of $HOME/.ssh/config"
fi

if grep -qsx "net.ipv4.tcp_mtu_probing=1" /etc/sysctl.d/99-mtu.conf; then
  echo "/etc/sysctl.d/99-mtu.conf already installed"
else
  sudo install -m 644 "$DIR/99-mtu.conf" /etc/sysctl.d/99-mtu.conf
  sudo sysctl -q --system
  echo "installed /etc/sysctl.d/99-mtu.conf"
fi

case ":$PATH:" in
  *":$HOME/bin:"*) ;;
  *) echo "note: ~/bin is not on PATH yet; log in again, or run ~/bin/plane-net" ;;
esac
