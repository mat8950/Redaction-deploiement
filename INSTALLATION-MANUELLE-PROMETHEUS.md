# Installation Manuelle de Prometheus + Alertmanager

Guide d'installation pas à pas pour **Rocky Linux 8/9** et **CentOS 8/9** avec les mêmes options que `docker-compose-complete.yml`.

> **Versions installées:**
> - **Prometheus 3.7.3** (dernière version stable - 2025)
> - **Alertmanager 0.29.0** (dernière version stable - 2025)
> - Installation depuis les binaires officiels GitHub

---

## 📋 Prérequis

- Rocky Linux 8/9 ou CentOS 8/9
- Accès root (sudo)
- Connexion internet

---

## 🔧 Étape 1: Préparation du système

### 1.1 Mise à jour du système

```bash
sudo dnf update -y
# ou pour CentOS 8
sudo yum update -y
```

### 1.2 Installation des dépendances

```bash
sudo dnf install -y wget curl tar gzip
```

### 1.3 Activation du dépôt EPEL

```bash
sudo dnf install -y epel-release
```

### 1.4 Vérification du dépôt

```bash
dnf repolist | grep epel
```

---

## 📦 Étape 2: Installation des binaires officiels

> **Note**: Installation depuis les binaires officiels GitHub pour avoir les dernières versions (Prometheus 3.7.3, Alertmanager 0.29.0)

### 2.1 Définir les versions

```bash
PROM_VERSION="3.7.3"
ALERT_VERSION="0.29.0"
```

### 2.2 Création des utilisateurs système

```bash
# Utilisateur Prometheus
sudo useradd --no-create-home --shell /bin/false prometheus

# Utilisateur Alertmanager
sudo useradd --no-create-home --shell /bin/false alertmanager
```

### 2.3 Création des répertoires

```bash
# Prometheus
sudo mkdir -p /etc/prometheus/{alerts,rules,targets}
sudo mkdir -p /var/lib/prometheus

# Alertmanager
sudo mkdir -p /etc/alertmanager
sudo mkdir -p /var/lib/alertmanager
```

### 2.4 Téléchargement et installation de Prometheus

```bash
# Aller dans /tmp
cd /tmp

# Téléchargement
wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz

# Extraction
tar xvf prometheus-${PROM_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROM_VERSION}.linux-amd64

# Installation des binaires
sudo cp prometheus promtool /usr/local/bin/

# Note: Prometheus 3.x n'inclut plus les consoles (interface React native)
# Copier le fichier de configuration exemple (optionnel)
sudo cp prometheus.yml /etc/prometheus/prometheus.yml.example

# Nettoyage
cd /tmp
rm -rf prometheus-${PROM_VERSION}.linux-amd64*
```

### 2.5 Téléchargement et installation d'Alertmanager

```bash
# Aller dans /tmp
cd /tmp

# Téléchargement
wget https://github.com/prometheus/alertmanager/releases/download/v${ALERT_VERSION}/alertmanager-${ALERT_VERSION}.linux-amd64.tar.gz

# Extraction
tar xvf alertmanager-${ALERT_VERSION}.linux-amd64.tar.gz
cd alertmanager-${ALERT_VERSION}.linux-amd64

# Installation des binaires
sudo cp alertmanager amtool /usr/local/bin/

# Nettoyage
cd /tmp
rm -rf alertmanager-${ALERT_VERSION}.linux-amd64*
```

### 2.6 Configuration des permissions

```bash
# Prometheus
sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown -R prometheus:prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool

# Alertmanager
sudo chown -R alertmanager:alertmanager /etc/alertmanager
sudo chown -R alertmanager:alertmanager /var/lib/alertmanager
sudo chown alertmanager:alertmanager /usr/local/bin/alertmanager
sudo chown alertmanager:alertmanager /usr/local/bin/amtool
```

### 2.7 Vérification des versions installées

```bash
prometheus --version
promtool --version
alertmanager --version
amtool --version
```

Résultat attendu:
```
prometheus, version 3.7.3 ...
promtool, version 3.7.3 ...
alertmanager, version 0.29.0 ...
amtool, version 0.29.0 ...
```

---

## 📁 Étape 3: Configuration de Prometheus

### 3.1 Création du fichier de configuration principal

Éditez `/etc/prometheus/prometheus.yml`:

```bash
sudo nano /etc/prometheus/prometheus.yml
```

Contenu:

```yaml
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
```

### 3.2 Création des fichiers d'alertes

**Alertes de disponibilité** (`/etc/prometheus/alerts/availability.yml`):

```bash
sudo nano /etc/prometheus/alerts/availability.yml
```

```yaml
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
```

**Alertes de ressources** (`/etc/prometheus/alerts/resources.yml`):

```bash
sudo nano /etc/prometheus/alerts/resources.yml
```

```yaml
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
```

### 3.3 Création des fichiers de targets

**Stack de monitoring** (`/etc/prometheus/targets/monitoring-stack.yml`):

```bash
sudo nano /etc/prometheus/targets/monitoring-stack.yml
```

```yaml
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
```

**Serveurs** (`/etc/prometheus/targets/hosts.yml`):

```bash
sudo nano /etc/prometheus/targets/hosts.yml
```

```yaml
# Serveurs à monitorer (exemples - à adapter)
# - targets:
#     - 'server1.example.com:9100'
#   labels:
#     env: 'production'
#     role: 'web'
#     datacenter: 'dc1'
#
# - targets:
#     - 'server2.example.com:9100'
#   labels:
#     env: 'production'
#     role: 'database'
#     datacenter: 'dc1'
```

**Exporters** (`/etc/prometheus/targets/exporters.yml`):

```bash
sudo nano /etc/prometheus/targets/exporters.yml
```

```yaml
# Exporters supplémentaires (exemples - à adapter)
# - targets:
#     - 'localhost:9100'
#   labels:
#     exporter: 'node'
#     env: 'production'
#
# - targets:
#     - 'db-server:9187'
#   labels:
#     exporter: 'postgres'
#     env: 'production'
```

### 3.4 Permissions finales

```bash
sudo chmod 644 /etc/prometheus/prometheus.yml
sudo chmod 644 /etc/prometheus/alerts/*.yml
sudo chmod 644 /etc/prometheus/targets/*.yml
sudo chown -R prometheus:prometheus /etc/prometheus
```

---

## 🚨 Étape 4: Configuration d'Alertmanager

### 4.1 Configuration d'Alertmanager

Éditez `/etc/alertmanager/alertmanager.yml`:

```bash
sudo nano /etc/alertmanager/alertmanager.yml
```

Contenu:

```yaml
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
    # À configurer selon vos besoins
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
```

### 4.2 Permissions

```bash
sudo chmod 644 /etc/alertmanager/alertmanager.yml
sudo chown -R alertmanager:alertmanager /etc/alertmanager
```

---

## ⚙️ Étape 5: Configuration des services systemd

### 5.1 Configuration du service Prometheus

Éditez `/etc/systemd/system/prometheus.service`:

```bash
sudo nano /etc/systemd/system/prometheus.service
```

Contenu (avec **toutes les options** du docker-compose):

```ini
[Unit]
Description=Prometheus Monitoring System
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
Restart=on-failure
RestartSec=5s

# Variables d'environnement
Environment="TZ=Europe/Paris"

# Commande avec toutes les options (identique à docker-compose-complete.yml)
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=30d \
  --storage.tsdb.retention.size=15GB \
  --storage.tsdb.min-block-duration=2h \
  --storage.tsdb.max-block-duration=36h \
  --storage.tsdb.wal-compression \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.console.templates=/etc/prometheus/consoles \
  --web.listen-address=:9090 \
  --web.enable-lifecycle \
  --web.enable-admin-api \
  --web.page-title='Prometheus Monitoring' \
  --web.cors.origin='.*' \
  --query.timeout=2m \
  --query.max-concurrency=20 \
  --query.max-samples=50000000 \
  --query.lookback-delta=5m \
  --log.level=info \
  --log.format=logfmt

ExecReload=/bin/kill -HUP $MAINPID

# Limites de ressources
LimitNOFILE=65536
LimitNPROC=65536

# Sécurité
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/prometheus

[Install]
WantedBy=multi-user.target
```

### 5.2 Configuration du service Alertmanager

Éditez `/etc/systemd/system/alertmanager.service`:

```bash
sudo nano /etc/systemd/system/alertmanager.service
```

Contenu (avec **toutes les options** du docker-compose):

```ini
[Unit]
Description=Prometheus Alertmanager
Documentation=https://prometheus.io/docs/alerting/alertmanager/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=alertmanager
Group=alertmanager
Restart=on-failure
RestartSec=5s

# Variables d'environnement
Environment="TZ=Europe/Paris"

# Commande avec toutes les options (identique à docker-compose-complete.yml)
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager \
  --cluster.listen-address=0.0.0.0:9094 \
  --web.listen-address=:9093 \
  --web.external-url=http://localhost:9093 \
  --web.route-prefix=/ \
  --log.level=info \
  --log.format=logfmt \
  --alerts.gc-interval=30m

ExecReload=/bin/kill -HUP $MAINPID

# Limites de ressources
LimitNOFILE=65536

# Sécurité
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/alertmanager

[Install]
WantedBy=multi-user.target
```

### 5.3 Rechargement de systemd

```bash
sudo systemctl daemon-reload
```

---

## 🔥 Étape 6: Configuration du firewall

### 6.1 Activation du firewall

```bash
sudo systemctl enable --now firewalld
```

### 6.2 Ouverture des ports

```bash
# Prometheus
sudo firewall-cmd --permanent --add-port=9090/tcp

# Alertmanager
sudo firewall-cmd --permanent --add-port=9093/tcp
sudo firewall-cmd --permanent --add-port=9094/tcp

# Rechargement
sudo firewall-cmd --reload
```

### 6.3 Vérification

```bash
sudo firewall-cmd --list-ports
```

Résultat attendu:
```
9090/tcp 9093/tcp 9094/tcp
```

---

## 🕐 Étape 7: Configuration du fuseau horaire

```bash
sudo timedatectl set-timezone Europe/Paris
sudo timedatectl status
```

---

## 🚀 Étape 8: Démarrage des services

### 8.1 Activation au démarrage

```bash
sudo systemctl enable prometheus
sudo systemctl enable alertmanager
```

### 8.2 Démarrage des services

```bash
# Démarrage de Prometheus
sudo systemctl start prometheus

# Attendre 2 secondes
sleep 2

# Démarrage d'Alertmanager
sudo systemctl start alertmanager
```

---

## ✅ Étape 9: Vérification

### 9.1 Vérification du statut des services

```bash
# Prometheus
sudo systemctl status prometheus

# Alertmanager
sudo systemctl status alertmanager
```

### 9.2 Vérification des logs

```bash
# Logs Prometheus
sudo journalctl -u prometheus -n 50 --no-pager

# Logs Alertmanager
sudo journalctl -u alertmanager -n 50 --no-pager
```

### 9.3 Test de connectivité

```bash
# Prometheus
curl http://localhost:9090/-/healthy

# Alertmanager
curl http://localhost:9093/-/healthy
```

### 9.4 Vérification des versions

```bash
# Version Prometheus
curl -s http://localhost:9090/api/v1/status/buildinfo | grep version

# Version Alertmanager
curl -s http://localhost:9093/api/v1/status | grep version
```

### 9.5 Vérification des targets

```bash
curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"[^"]*"'
```

### 9.6 Vérification des règles d'alertes

```bash
curl -s http://localhost:9090/api/v1/rules | grep -o '"name":"[^"]*"'
```

---

## 🌐 Étape 10: Accès aux interfaces web

### 10.1 URLs

- **Prometheus**: http://VOTRE_IP:9090
- **Alertmanager**: http://VOTRE_IP:9093

### 10.2 Si accès distant nécessaire

```bash
# Remplacez VOTRE_IP par l'IP de votre serveur
echo "Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
echo "Alertmanager: http://$(hostname -I | awk '{print $1}'):9093"
```

---

## 📊 Étape 11: (Optionnel) Installation de Node Exporter

Pour monitorer le serveur local avec des métriques système détaillées:

### 11.1 Installation

```bash
sudo dnf install -y golang-github-prometheus-node-exporter
```

### 11.2 Démarrage

```bash
sudo systemctl enable --now node_exporter
```

### 11.3 Ouverture du port

```bash
sudo firewall-cmd --permanent --add-port=9100/tcp
sudo firewall-cmd --reload
```

### 11.4 Vérification

```bash
curl http://localhost:9100/metrics
```

### 11.5 Hot reload de Prometheus

```bash
curl -X POST http://localhost:9090/-/reload
```

---

## 🔧 Commandes utiles

### Gestion des services

```bash
# Redémarrer Prometheus
sudo systemctl restart prometheus

# Redémarrer Alertmanager
sudo systemctl restart alertmanager

# Arrêter
sudo systemctl stop prometheus
sudo systemctl stop alertmanager

# Statut
sudo systemctl status prometheus
sudo systemctl status alertmanager
```

### Logs en temps réel

```bash
# Prometheus
sudo journalctl -u prometheus -f

# Alertmanager
sudo journalctl -u alertmanager -f
```

### Hot reload (sans redémarrage)

```bash
# Prometheus (recharge la config)
curl -X POST http://localhost:9090/-/reload

# Alertmanager (recharge la config)
curl -X POST http://localhost:9093/-/reload
```

### Vérification de la configuration

```bash
# Vérifier la config Prometheus
promtool check config /etc/prometheus/prometheus.yml

# Vérifier les règles d'alertes
promtool check rules /etc/prometheus/alerts/*.yml

# Vérifier la config Alertmanager
amtool check-config /etc/alertmanager/alertmanager.yml
```

### Surveillance des ressources

```bash
# Taille des données TSDB
du -sh /var/lib/prometheus

# Nombre de séries temporelles
curl -s http://localhost:9090/api/v1/status/tsdb | grep numSeries

# Utilisation mémoire
ps aux | grep prometheus
```

---

## 🎯 Options de ligne de commande (référence)

### Options Prometheus identiques au docker-compose

| Option | Valeur | Description |
|--------|--------|-------------|
| `--storage.tsdb.retention.time` | `30d` | Rétention temporelle (30 jours) |
| `--storage.tsdb.retention.size` | `15GB` | Rétention par taille (15 Go) |
| `--storage.tsdb.min-block-duration` | `2h` | Durée minimale des blocs TSDB |
| `--storage.tsdb.max-block-duration` | `36h` | Durée maximale des blocs TSDB |
| `--storage.tsdb.wal-compression` | - | Compression du WAL (Write-Ahead Log) |
| `--web.enable-lifecycle` | - | Hot reload avec `/-/reload` |
| `--web.enable-admin-api` | - | API admin (attention en prod!) |
| `--web.page-title` | `'Prometheus Monitoring'` | Titre de la page web |
| `--web.cors.origin` | `'.*'` | CORS (à restreindre en prod) |
| `--query.timeout` | `2m` | Timeout des requêtes PromQL |
| `--query.max-concurrency` | `20` | Requêtes simultanées max |
| `--query.max-samples` | `50000000` | Échantillons max par requête |
| `--query.lookback-delta` | `5m` | Lookback par défaut |
| `--log.level` | `info` | Niveau de logs |
| `--log.format` | `logfmt` | Format des logs |

### Options Alertmanager identiques au docker-compose

| Option | Valeur | Description |
|--------|--------|-------------|
| `--cluster.listen-address` | `0.0.0.0:9094` | Adresse écoute clustering |
| `--web.listen-address` | `:9093` | Adresse écoute web |
| `--web.external-url` | `http://localhost:9093` | URL externe |
| `--alerts.gc-interval` | `30m` | Nettoyage des vieilles alertes |
| `--log.level` | `info` | Niveau de logs |
| `--log.format` | `logfmt` | Format des logs |

---

## 🔒 Sécurisation (recommandations production)

### 1. Modifier les options CORS

Dans `/etc/systemd/system/prometheus.service`, remplacez:
```
--web.cors.origin='.*'
```
Par:
```
--web.cors.origin='https://grafana.example.com'
```

### 2. Désactiver l'API admin

Supprimez la ligne:
```
--web.enable-admin-api \
```

### 3. Ajouter une authentification

Créez `/etc/prometheus/web-config.yml`:

```yaml
basic_auth_users:
  admin: $2y$10$... # généré avec htpasswd
```

Ajoutez dans le service:
```
--web.config.file=/etc/prometheus/web-config.yml \
```

### 4. Configurer TLS

Générez des certificats et ajoutez dans `web-config.yml`:

```yaml
tls_server_config:
  cert_file: /etc/prometheus/certs/prometheus.crt
  key_file: /etc/prometheus/certs/prometheus.key
  min_version: TLS12
```

### 5. Restreindre le firewall

```bash
# Autoriser uniquement depuis un réseau spécifique
sudo firewall-cmd --permanent --zone=trusted --add-source=192.168.1.0/24
sudo firewall-cmd --permanent --zone=trusted --add-port=9090/tcp
sudo firewall-cmd --reload
```

---

## 🐛 Dépannage

### Prometheus ne démarre pas

```bash
# Vérifier la configuration
promtool check config /etc/prometheus/prometheus.yml

# Vérifier les logs
sudo journalctl -u prometheus -n 100 --no-pager

# Vérifier les permissions
ls -la /var/lib/prometheus
ls -la /etc/prometheus
```

### Alertmanager ne démarre pas

```bash
# Vérifier la configuration
amtool check-config /etc/alertmanager/alertmanager.yml

# Vérifier les logs
sudo journalctl -u alertmanager -n 100 --no-pager

# Vérifier les permissions
ls -la /var/lib/alertmanager
ls -la /etc/alertmanager
```

### Les targets sont "down"

```bash
# Vérifier la connectivité
curl http://localhost:9100/metrics  # Node Exporter

# Vérifier le firewall
sudo firewall-cmd --list-all

# Vérifier la config
curl http://localhost:9090/api/v1/targets
```

### Hot reload ne fonctionne pas

```bash
# Vérifier que l'option est activée
grep "enable-lifecycle" /etc/systemd/system/prometheus.service

# Redémarrer manuellement
sudo systemctl restart prometheus
```

---

## 📚 Ressources

- [Documentation Prometheus](https://prometheus.io/docs/)
- [Documentation Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [PromQL Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Best Practices](https://prometheus.io/docs/practices/)

---

## ✅ Checklist finale

- [ ] Prometheus installé et démarré
- [ ] Alertmanager installé et démarré
- [ ] Firewall configuré (ports 9090, 9093, 9094)
- [ ] Services activés au démarrage
- [ ] Configuration testée avec `promtool`
- [ ] Targets visibles dans Prometheus
- [ ] Alertes chargées
- [ ] Hot reload fonctionnel
- [ ] (Optionnel) Node Exporter installé
- [ ] (Optionnel) Grafana installé et connecté

---

**Installation terminée!** 🎉

Prometheus: http://localhost:9090
Alertmanager: http://localhost:9093
