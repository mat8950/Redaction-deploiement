#!/bin/bash

################################################################################
# Script d'installation Prometheus + Alertmanager
# Compatible: Rocky Linux 8/9, CentOS 8/9
# Installation via gestionnaire de packages (DNF/YUM)
# Options identiques à docker-compose-complete.yml
################################################################################

set -e  # Arrêt en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérification des privilèges root
if [ "$EUID" -ne 0 ]; then
    log_error "Ce script doit être exécuté en tant que root (utilisez sudo)"
    exit 1
fi

# Détection de la distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    log_error "Impossible de détecter la distribution"
    exit 1
fi

log_info "Distribution détectée: $OS $VER"

# Vérification compatibilité
case "$OS" in
    "Rocky Linux"|"CentOS Linux"|"Red Hat Enterprise Linux")
        log_success "Distribution compatible"
        ;;
    *)
        log_error "Distribution non supportée: $OS"
        exit 1
        ;;
esac

################################################################################
# CONFIGURATION
################################################################################

# Versions (dernières versions stables)
PROM_VERSION="3.7.3"
ALERT_VERSION="0.29.0"

# Répertoires
PROMETHEUS_DIR="/etc/prometheus"
PROMETHEUS_DATA_DIR="/var/lib/prometheus"
ALERTMANAGER_DIR="/etc/alertmanager"
ALERTMANAGER_DATA_DIR="/var/lib/alertmanager"

# Binaires
PROMETHEUS_BIN="/usr/local/bin/prometheus"
PROMTOOL_BIN="/usr/local/bin/promtool"
ALERTMANAGER_BIN="/usr/local/bin/alertmanager"
AMTOOL_BIN="/usr/local/bin/amtool"

# Utilisateurs
PROMETHEUS_USER="prometheus"
ALERTMANAGER_USER="alertmanager"

# Ports
PROMETHEUS_PORT=9090
ALERTMANAGER_PORT=9093
ALERTMANAGER_CLUSTER_PORT=9094

# Options Prometheus (identiques au docker-compose)
PROMETHEUS_RETENTION_TIME="30d"
PROMETHEUS_RETENTION_SIZE="15GB"
PROMETHEUS_MIN_BLOCK_DURATION="2h"
PROMETHEUS_MAX_BLOCK_DURATION="36h"
PROMETHEUS_QUERY_TIMEOUT="2m"
PROMETHEUS_QUERY_MAX_CONCURRENCY="20"
PROMETHEUS_QUERY_MAX_SAMPLES="50000000"
PROMETHEUS_LOG_LEVEL="info"

# Timezone
TIMEZONE="Europe/Paris"

################################################################################
# INSTALLATION DES BINAIRES
################################################################################

log_info "Mise à jour du système..."
dnf update -y || yum update -y

log_info "Installation des dépendances..."
dnf install -y wget curl tar gzip firewalld || yum install -y wget curl tar gzip firewalld

log_info "Création des utilisateurs système..."

# Utilisateur Prometheus
if ! id "$PROMETHEUS_USER" &>/dev/null; then
    useradd --no-create-home --shell /bin/false $PROMETHEUS_USER
    log_success "Utilisateur $PROMETHEUS_USER créé"
else
    log_warning "Utilisateur $PROMETHEUS_USER existe déjà"
fi

# Utilisateur Alertmanager
if ! id "$ALERTMANAGER_USER" &>/dev/null; then
    useradd --no-create-home --shell /bin/false $ALERTMANAGER_USER
    log_success "Utilisateur $ALERTMANAGER_USER créé"
else
    log_warning "Utilisateur $ALERTMANAGER_USER existe déjà"
fi

log_info "Téléchargement et installation de Prometheus $PROM_VERSION..."
cd /tmp

# Téléchargement Prometheus
wget -q --show-progress https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz

# Extraction
tar xzf prometheus-${PROM_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROM_VERSION}.linux-amd64

# Installation des binaires
cp prometheus /usr/local/bin/
cp promtool /usr/local/bin/

# Note: Prometheus 3.x n'inclut plus les consoles (interface React native)
# Création des répertoires de configuration
mkdir -p $PROMETHEUS_DIR

# Nettoyage
cd /tmp
rm -rf prometheus-${PROM_VERSION}.linux-amd64*

log_success "Prometheus $PROM_VERSION installé"

log_info "Téléchargement et installation d'Alertmanager $ALERT_VERSION..."
cd /tmp

# Téléchargement Alertmanager
wget -q --show-progress https://github.com/prometheus/alertmanager/releases/download/v${ALERT_VERSION}/alertmanager-${ALERT_VERSION}.linux-amd64.tar.gz

# Extraction
tar xzf alertmanager-${ALERT_VERSION}.linux-amd64.tar.gz
cd alertmanager-${ALERT_VERSION}.linux-amd64

# Installation des binaires
cp alertmanager /usr/local/bin/
cp amtool /usr/local/bin/

# Nettoyage
cd /tmp
rm -rf alertmanager-${ALERT_VERSION}.linux-amd64*

log_success "Alertmanager $ALERT_VERSION installé"

################################################################################
# CONFIGURATION PROMETHEUS
################################################################################

log_info "Configuration de Prometheus..."

# Création des répertoires si nécessaire
mkdir -p "$PROMETHEUS_DIR"/{alerts,rules,targets}
mkdir -p "$PROMETHEUS_DATA_DIR"
chown -R $PROMETHEUS_USER:$PROMETHEUS_USER "$PROMETHEUS_DIR"
chown -R $PROMETHEUS_USER:$PROMETHEUS_USER "$PROMETHEUS_DATA_DIR"

# Configuration principale prometheus.yml
cat > "$PROMETHEUS_DIR/prometheus.yml" <<'EOF'
# Configuration Prometheus
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'prometheus-monitoring'
    env: 'production'

# Alertmanager
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - 'localhost:9093'

# Fichiers de règles
rule_files:
  - '/etc/prometheus/alerts/*.yml'
  - '/etc/prometheus/rules/*.yml'

# Collecte des métriques
scrape_configs:
  # Prometheus lui-même
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          instance: 'prometheus-server'
          env: 'production'

  # Alertmanager
  - job_name: 'alertmanager'
    static_configs:
      - targets: ['localhost:9093']
        labels:
          instance: 'alertmanager'
          env: 'production'

  # Node Exporter (si installé)
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          instance: 'local-server'
          env: 'production'

  # Targets modulaires (file service discovery)
  - job_name: 'monitoring-stack'
    file_sd_configs:
      - files:
          - '/etc/prometheus/targets/monitoring-stack.yml'
        refresh_interval: 1m

  - job_name: 'hosts'
    file_sd_configs:
      - files:
          - '/etc/prometheus/targets/hosts.yml'
        refresh_interval: 1m

  - job_name: 'exporters'
    file_sd_configs:
      - files:
          - '/etc/prometheus/targets/exporters.yml'
        refresh_interval: 30s
EOF

# Alertes de base
cat > "$PROMETHEUS_DIR/alerts/availability.yml" <<'EOF'
groups:
  - name: availability
    interval: 30s
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
          category: availability
        annotations:
          summary: "Instance {{ $labels.instance }} down"
          description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 2 minutes."

      - alert: CriticalServiceDown
        expr: up{job=~"prometheus|alertmanager"} == 0
        for: 1m
        labels:
          severity: critical
          category: availability
        annotations:
          summary: "Critical service {{ $labels.job }} down"
          description: "Critical monitoring service {{ $labels.job }} is down!"
EOF

cat > "$PROMETHEUS_DIR/alerts/resources.yml" <<'EOF'
groups:
  - name: resources
    interval: 1m
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
          category: resources
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% (current: {{ $value | humanize }}%)"

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
          category: resources
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 85% (current: {{ $value | humanize }}%)"

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15
        for: 5m
        labels:
          severity: warning
          category: resources
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Disk space is below 15% (current: {{ $value | humanize }}%)"
EOF

# Fichiers de targets par défaut
cat > "$PROMETHEUS_DIR/targets/monitoring-stack.yml" <<'EOF'
# Stack de monitoring
- targets:
    - 'localhost:9090'
  labels:
    job: 'prometheus'
    instance: 'prometheus-server'
    env: 'production'

- targets:
    - 'localhost:9093'
  labels:
    job: 'alertmanager'
    instance: 'alertmanager'
    env: 'production'
EOF

cat > "$PROMETHEUS_DIR/targets/hosts.yml" <<'EOF'
# Serveurs à monitorer (exemples)
# - targets:
#     - 'server1.example.com:9100'
#   labels:
#     env: 'production'
#     role: 'web'
#     datacenter: 'dc1'
EOF

cat > "$PROMETHEUS_DIR/targets/exporters.yml" <<'EOF'
# Exporters supplémentaires (exemples)
# - targets:
#     - 'localhost:9100'
#   labels:
#     exporter: 'node'
#     env: 'production'
EOF

# Permissions
chown -R $PROMETHEUS_USER:$PROMETHEUS_USER "$PROMETHEUS_DIR"
chmod 644 "$PROMETHEUS_DIR"/*.yml
chmod 644 "$PROMETHEUS_DIR"/alerts/*.yml
chmod 644 "$PROMETHEUS_DIR"/targets/*.yml

################################################################################
# CONFIGURATION ALERTMANAGER
################################################################################

log_info "Configuration d'Alertmanager..."

mkdir -p "$ALERTMANAGER_DIR"
mkdir -p "$ALERTMANAGER_DATA_DIR"
chown -R $ALERTMANAGER_USER:$ALERTMANAGER_USER "$ALERTMANAGER_DIR"
chown -R $ALERTMANAGER_USER:$ALERTMANAGER_USER "$ALERTMANAGER_DATA_DIR"

cat > "$ALERTMANAGER_DIR/alertmanager.yml" <<'EOF'
# Configuration Alertmanager
global:
  resolve_timeout: 5m

# Templates pour les notifications
templates:
  - '/etc/alertmanager/templates/*.tmpl'

# Route par défaut
route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'

  routes:
    # Alertes critiques
    - match:
        severity: critical
      receiver: 'critical'
      group_wait: 0s
      repeat_interval: 5m

    # Alertes warning
    - match:
        severity: warning
      receiver: 'warning'
      repeat_interval: 30m

# Inhibitions (éviter le spam)
inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']

# Receivers (notifications)
receivers:
  - name: 'default'
    # webhook_configs:
    #   - url: 'http://localhost:5001/'

  - name: 'critical'
    # Exemple: envoi par email
    # email_configs:
    #   - to: 'oncall@example.com'
    #     from: 'alertmanager@example.com'
    #     smarthost: 'smtp.example.com:587'
    #     auth_username: 'alertmanager'
    #     auth_password: 'password'
    #     headers:
    #       Subject: '[CRITICAL] {{ .GroupLabels.alertname }}'

  - name: 'warning'
    # webhook_configs:
    #   - url: 'http://localhost:5001/'
EOF

chown -R $ALERTMANAGER_USER:$ALERTMANAGER_USER "$ALERTMANAGER_DIR"
chmod 644 "$ALERTMANAGER_DIR/alertmanager.yml"

################################################################################
# CONFIGURATION SYSTEMD
################################################################################

log_info "Configuration des services systemd..."

# Service Prometheus avec toutes les options
cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus Monitoring System
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$PROMETHEUS_USER
Group=$PROMETHEUS_USER
Restart=on-failure
RestartSec=5s

# Variables d'environnement
Environment="TZ=$TIMEZONE"

# Commande avec toutes les options (identique à docker-compose-complete.yml)
ExecStart=$PROMETHEUS_BIN \\
  --config.file=$PROMETHEUS_DIR/prometheus.yml \\
  --storage.tsdb.path=$PROMETHEUS_DATA_DIR \\
  --storage.tsdb.retention.time=$PROMETHEUS_RETENTION_TIME \\
  --storage.tsdb.retention.size=$PROMETHEUS_RETENTION_SIZE \\
  --storage.tsdb.min-block-duration=$PROMETHEUS_MIN_BLOCK_DURATION \\
  --storage.tsdb.max-block-duration=$PROMETHEUS_MAX_BLOCK_DURATION \\
  --storage.tsdb.wal-compression \\
  --web.listen-address=:$PROMETHEUS_PORT \\
  --web.enable-lifecycle \\
  --web.enable-admin-api \\
  --web.page-title='Prometheus Monitoring' \\
  --web.cors.origin='.*' \\
  --query.timeout=$PROMETHEUS_QUERY_TIMEOUT \\
  --query.max-concurrency=$PROMETHEUS_QUERY_MAX_CONCURRENCY \\
  --query.max-samples=$PROMETHEUS_QUERY_MAX_SAMPLES \\
  --query.lookback-delta=5m \\
  --log.level=$PROMETHEUS_LOG_LEVEL \\
  --log.format=logfmt

ExecReload=/bin/kill -HUP \$MAINPID

# Limites de ressources
LimitNOFILE=65536
LimitNPROC=65536

# Sécurité
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$PROMETHEUS_DATA_DIR

[Install]
WantedBy=multi-user.target
EOF

# Service Alertmanager avec toutes les options
cat > /etc/systemd/system/alertmanager.service <<EOF
[Unit]
Description=Prometheus Alertmanager
Documentation=https://prometheus.io/docs/alerting/alertmanager/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$ALERTMANAGER_USER
Group=$ALERTMANAGER_USER
Restart=on-failure
RestartSec=5s

# Variables d'environnement
Environment="TZ=$TIMEZONE"

# Commande avec toutes les options (identique à docker-compose-complete.yml)
ExecStart=$ALERTMANAGER_BIN \\
  --config.file=$ALERTMANAGER_DIR/alertmanager.yml \\
  --storage.path=$ALERTMANAGER_DATA_DIR \\
  --cluster.listen-address=0.0.0.0:$ALERTMANAGER_CLUSTER_PORT \\
  --web.listen-address=:$ALERTMANAGER_PORT \\
  --web.external-url=http://localhost:$ALERTMANAGER_PORT \\
  --web.route-prefix=/ \\
  --log.level=info \\
  --log.format=logfmt \\
  --alerts.gc-interval=30m

ExecReload=/bin/kill -HUP \$MAINPID

# Limites de ressources
LimitNOFILE=65536

# Sécurité
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$ALERTMANAGER_DATA_DIR

[Install]
WantedBy=multi-user.target
EOF

# Rechargement systemd
systemctl daemon-reload

################################################################################
# CONFIGURATION FIREWALL
################################################################################

log_info "Configuration du firewall..."

systemctl enable --now firewalld

# Prometheus
firewall-cmd --permanent --add-port=$PROMETHEUS_PORT/tcp
log_success "Port Prometheus $PROMETHEUS_PORT/tcp ouvert"

# Alertmanager
firewall-cmd --permanent --add-port=$ALERTMANAGER_PORT/tcp
firewall-cmd --permanent --add-port=$ALERTMANAGER_CLUSTER_PORT/tcp
log_success "Ports Alertmanager $ALERTMANAGER_PORT/tcp et $ALERTMANAGER_CLUSTER_PORT/tcp ouverts"

# Reload firewall
firewall-cmd --reload

################################################################################
# CONFIGURATION TIMEZONE
################################################################################

log_info "Configuration du fuseau horaire: $TIMEZONE"
timedatectl set-timezone $TIMEZONE

################################################################################
# DÉMARRAGE DES SERVICES
################################################################################

log_info "Démarrage des services..."

# Activation au démarrage
systemctl enable prometheus
systemctl enable alertmanager

# Démarrage
systemctl start prometheus
sleep 2
systemctl start alertmanager
sleep 2

################################################################################
# VÉRIFICATION
################################################################################

log_info "Vérification des services..."

# Prometheus
if systemctl is-active --quiet prometheus; then
    log_success "Prometheus est actif"
    PROM_VER_INSTALLED=$(curl -s http://localhost:$PROMETHEUS_PORT/api/v1/status/buildinfo | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    log_info "Version Prometheus: $PROM_VER_INSTALLED"
else
    log_error "Prometheus n'a pas démarré correctement"
    systemctl status prometheus --no-pager
    exit 1
fi

# Alertmanager
if systemctl is-active --quiet alertmanager; then
    log_success "Alertmanager est actif"
    ALERT_VER_INSTALLED=$(curl -s http://localhost:$ALERTMANAGER_PORT/api/v1/status | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    log_info "Version Alertmanager: $ALERT_VER_INSTALLED"
else
    log_error "Alertmanager n'a pas démarré correctement"
    systemctl status alertmanager --no-pager
    exit 1
fi

# Vérification des targets
sleep 3
log_info "Vérification des targets Prometheus..."
TARGETS=$(curl -s http://localhost:$PROMETHEUS_PORT/api/v1/targets | grep -o '"health":"[^"]*"' | wc -l)
log_info "Nombre de targets configurées: $TARGETS"

################################################################################
# RÉCAPITULATIF
################################################################################

echo ""
log_success "====================================="
log_success "Installation terminée avec succès!"
log_success "====================================="
echo ""
echo -e "${GREEN}Prometheus:${NC}"
echo "  - URL: http://localhost:$PROMETHEUS_PORT"
echo "  - Config: $PROMETHEUS_DIR/prometheus.yml"
echo "  - Alertes: $PROMETHEUS_DIR/alerts/"
echo "  - Targets: $PROMETHEUS_DIR/targets/"
echo "  - Données: $PROMETHEUS_DATA_DIR"
echo "  - Rétention: $PROMETHEUS_RETENTION_TIME / $PROMETHEUS_RETENTION_SIZE"
echo ""
echo -e "${GREEN}Alertmanager:${NC}"
echo "  - URL: http://localhost:$ALERTMANAGER_PORT"
echo "  - Config: $ALERTMANAGER_DIR/alertmanager.yml"
echo "  - Données: $ALERTMANAGER_DATA_DIR"
echo ""
echo -e "${YELLOW}Commandes utiles:${NC}"
echo "  - Statut Prometheus:     systemctl status prometheus"
echo "  - Statut Alertmanager:   systemctl status alertmanager"
echo "  - Logs Prometheus:       journalctl -u prometheus -f"
echo "  - Logs Alertmanager:     journalctl -u alertmanager -f"
echo "  - Reload config:         curl -X POST http://localhost:$PROMETHEUS_PORT/-/reload"
echo "  - Vérifier config:       promtool check config $PROMETHEUS_DIR/prometheus.yml"
echo ""
echo -e "${YELLOW}Prochaines étapes:${NC}"
echo "  1. Éditer les fichiers de targets: $PROMETHEUS_DIR/targets/"
echo "  2. Ajouter vos serveurs à monitorer"
echo "  3. Configurer les notifications dans Alertmanager"
echo "  4. Installer Node Exporter sur les serveurs: dnf install -y golang-github-prometheus-node-exporter"
echo ""
log_info "Installation terminée!"
