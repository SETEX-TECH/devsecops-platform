#!/usr/bin/env bash
# Vérifie les ressources de la VM et recommande les composants à installer.
CPU=$(nproc)
RAM_MB=$(free -m | awk '/Mem:/{print $2}')
DISK_GB=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
echo "Cœurs CPU : $CPU"
echo "RAM       : ${RAM_MB} Mo"
echo "Disque libre : ${DISK_GB} Go"
echo
if [ "$RAM_MB" -lt 5500 ] || [ "$CPU" -lt 2 ]; then
  echo "=> INSUFFISANT : visez au moins 2 cœurs et 6 Go de RAM (idéal : 4 cœurs, 8 Go)."
elif [ "$RAM_MB" -lt 9000 ]; then
  echo "=> MINIMUM : installez k3s, ArgoCD, Kyverno, Prometheus et Grafana."
  echo "   Laissez de côté : INSTALL_LOKI=false INSTALL_FALCO=false (valeurs par défaut)."
else
  echo "=> CONFORTABLE : vous pouvez aussi activer Loki et Falco :"
  echo "   INSTALL_LOKI=true INSTALL_FALCO=true ./scripts/04-install-platform.sh"
fi
[ "$DISK_GB" -lt 40 ] && echo "ATTENTION : moins de 40 Go libres, agrandissez le disque dans Proxmox."
exit 0
