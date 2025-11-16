# Déploiement Grafana, Prometheus et Alertmanager sur Debian

## Guide d'installation native (sans Docker)

Ce guide détaille l'installation de la stack de monitoring directement sur un serveur Debian, sans utiliser Docker.

---

## Table des matières

1. [Prérequis](#prérequis)
2. [Installation de Prometheus](#installation-de-prometheus)
3. [Installation d'Alertmanager](#installation-dalertmanager)
4. [Installation de Grafana](#installation-de-grafana)
5. [Installation de Node Exporter](#installation-de-node-exporter)
6. [Configuration des services systemd](#configuration-des-services-systemd)
7. [Configuration des pare-feu](#configuration-des-pare-feu)
8. [Vérification](#vérification)
9. [Maintenance](#maintenance)

---

## Prérequis

### Système
- **OS**: Debian 11 (Bullseye) ou Debian 12 (Bookworm)
- **RAM**: Minimum 2 GB
- **Espace disque**: Minimum 20 GB
- **Accès**: root ou sudo

### Mise à jour du système

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y wget curl tar
```

### Créer un utilisateur pour les services

```bash
# Créer un utilisateur système pour Prometheus
sudo useradd --no-create-home --shell /bin/false prometheus

# Créer un utilisateur système pour Alertmanager
sudo useradd --no-create-home --shell /bin/false alertmanager

# Créer un utilisateur système pour Node Exporter
sudo useradd --no-create-home --shell /bin/false node_exporter
```

---

## Installation de Prometheus

### 1. Télécharger Prometheus

```bash
# Version à jour au moment de l'écriture
PROMETHEUS_VERSION="2.47.2"

cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz

# Extraire
tar xvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROMETHEUS_VERSION}.linux-amd64
```

### 2. Installer les binaires

```bash
# Copier les binaires
sudo cp prometheus /usr/local/bin/
sudo cp promtool /usr/local/bin/

# Définir les permissions
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool
```

### 3. Créer les répertoires

```bash
# Répertoires de configuration
sudo mkdir -p /etc/prometheus
sudo mkdir -p /var/lib/prometheus

# Copier les consoles et librairies
sudo cp -r consoles /etc/prometheus
sudo cp -r console_libraries /etc/prometheus

# Permissions
sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown -R prometheus:prometheus /var/lib/prometheus
```

### 4. Configuration Prometheus

Créer `/etc/prometheus/prometheus.yml`:

```bash
sudo nano /etc/prometheus/prometheus.yml
```

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'debian-monitoring'
    environment: 'production'

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - localhost:9093

rule_files:
  - '/etc/prometheus/alerts.yml'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          instance: 'prometheus-server'

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          instance: 'debian-server'

  - job_name: 'alertmanager'
    static_configs:
      - targets: ['localhost:9093']
        labels:
          instance: 'alertmanager-server'
```

### 5. Créer le fichier des alertes

```bash
sudo nano /etc/prometheus/alerts.yml
```

```yaml
groups:
  - name: service_availability
    interval: 30s
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} est down"
          description: "L'instance {{ $labels.instance }} est inaccessible depuis 2 minutes."

  - name: system_resources
    interval: 30s
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "CPU élevé sur {{ $labels.instance }}"
          description: "Utilisation CPU à {{ $value | humanize }}%."

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Mémoire élevée sur {{ $labels.instance }}"
          description: "Utilisation mémoire à {{ $value | humanize }}%."

      - alert: DiskSpaceLow
        expr: (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Espace disque faible"
          description: "Le disque {{ $labels.mountpoint }} est utilisé à {{ $value | humanize }}%."
```

### 6. Permissions

```bash
sudo chown -R prometheus:prometheus /etc/prometheus
```

### 7. Service systemd pour Prometheus

```bash
sudo nano /etc/systemd/system/prometheus.service
```

```ini
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/ \
  --storage.tsdb.retention.time=15d \
  --storage.tsdb.retention.size=10GB \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.enable-lifecycle \
  --web.enable-admin-api

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 8. Démarrer Prometheus

```bash
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl status prometheus
```

---

## Installation d'Alertmanager

### 1. Télécharger Alertmanager

```bash
ALERTMANAGER_VERSION="0.26.0"

cd /tmp
wget https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz

tar xvf alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz
cd alertmanager-${ALERTMANAGER_VERSION}.linux-amd64
```

### 2. Installer les binaires

```bash
sudo cp alertmanager /usr/local/bin/
sudo cp amtool /usr/local/bin/

sudo chown alertmanager:alertmanager /usr/local/bin/alertmanager
sudo chown alertmanager:alertmanager /usr/local/bin/amtool
```

### 3. Créer les répertoires

```bash
sudo mkdir -p /etc/alertmanager
sudo mkdir -p /var/lib/alertmanager

sudo chown -R alertmanager:alertmanager /etc/alertmanager
sudo chown -R alertmanager:alertmanager /var/lib/alertmanager
```

### 4. Configuration Alertmanager

```bash
sudo nano /etc/alertmanager/alertmanager.yml
```

```yaml
global:
  resolve_timeout: 5m
  # Configuration SMTP (à personnaliser)
  # smtp_smarthost: 'smtp.gmail.com:587'
  # smtp_from: 'alertmanager@example.com'
  # smtp_auth_username: 'your-email@gmail.com'
  # smtp_auth_password: 'your-app-password'
  # smtp_require_tls: true

route:
  receiver: 'default-receiver'
  group_by: ['alertname', 'cluster']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  
  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'
      repeat_interval: 3h
    
    - match:
        severity: warning
      receiver: 'warning-alerts'
      repeat_interval: 12h

receivers:
  - name: 'default-receiver'
    webhook_configs:
      - url: 'http://localhost:5001/webhook'

  - name: 'critical-alerts'
    # email_configs:
    #   - to: 'admin@example.com'
    #     send_resolved: true
    webhook_configs:
      - url: 'http://localhost:5001/critical'

  - name: 'warning-alerts'
    webhook_configs:
      - url: 'http://localhost:5001/warning'
```

### 5. Permissions

```bash
sudo chown -R alertmanager:alertmanager /etc/alertmanager
```

### 6. Service systemd pour Alertmanager

```bash
sudo nano /etc/systemd/system/alertmanager.service
```

```ini
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=alertmanager
Group=alertmanager
Type=simple
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager/ \
  --web.external-url=http://localhost:9093

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 7. Démarrer Alertmanager

```bash
sudo systemctl daemon-reload
sudo systemctl enable alertmanager
sudo systemctl start alertmanager
sudo systemctl status alertmanager
```

---

## Installation de Grafana

### 1. Ajouter le dépôt Grafana

```bash
# Ajouter la clé GPG
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

# Ajouter le dépôt
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
```

### 2. Installer Grafana

```bash
sudo apt update
sudo apt install grafana -y
```

### 3. Configuration Grafana

Le fichier de configuration principal est `/etc/grafana/grafana.ini`:

```bash
sudo nano /etc/grafana/grafana.ini
```

Paramètres importants à modifier:

```ini
[server]
http_port = 3000
domain = localhost
root_url = http://localhost:3000

[security]
admin_user = admin
admin_password = admin123

[users]
allow_sign_up = false

[auth.anonymous]
enabled = false
```

### 4. Provisionner la datasource Prometheus

```bash
sudo mkdir -p /etc/grafana/provisioning/datasources
sudo nano /etc/grafana/provisioning/datasources/prometheus.yml
```

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: '15s'
      httpMethod: 'POST'
```

### 5. Démarrer Grafana

```bash
sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
sudo systemctl status grafana-server
```

---

## Installation de Node Exporter

### 1. Télécharger Node Exporter

```bash
NODE_EXPORTER_VERSION="1.7.0"

cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz

tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
cd node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64
```

### 2. Installer le binaire

```bash
sudo cp node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
```

### 3. Service systemd pour Node Exporter

```bash
sudo nano /etc/systemd/system/node_exporter.service
```

```ini
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
  --collector.filesystem.mount-points-exclude='^/(sys|proc|dev|host|etc)($$|/)'

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 4. Démarrer Node Exporter

```bash
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter
```

---

## Configuration des pare-feu

### Avec UFW

```bash
# Installer UFW si nécessaire
sudo apt install ufw -y

# Autoriser SSH
sudo ufw allow 22/tcp

# Autoriser les ports de monitoring
sudo ufw allow 9090/tcp  # Prometheus
sudo ufw allow 9093/tcp  # Alertmanager
sudo ufw allow 3000/tcp  # Grafana
sudo ufw allow 9100/tcp  # Node Exporter

# Activer le pare-feu
sudo ufw enable
sudo ufw status
```

### Avec iptables

```bash
# Prometheus
sudo iptables -A INPUT -p tcp --dport 9090 -j ACCEPT

# Alertmanager
sudo iptables -A INPUT -p tcp --dport 9093 -j ACCEPT

# Grafana
sudo iptables -A INPUT -p tcp --dport 3000 -j ACCEPT

# Node Exporter
sudo iptables -A INPUT -p tcp --dport 9100 -j ACCEPT

# Sauvegarder les règles
sudo apt install iptables-persistent -y
sudo netfilter-persistent save
```

---

## Vérification

### 1. Vérifier tous les services

```bash
# Status de tous les services
sudo systemctl status prometheus
sudo systemctl status alertmanager
sudo systemctl status grafana-server
sudo systemctl status node_exporter
```

### 2. Vérifier les ports

```bash
sudo ss -tlnp | grep -E ':(9090|9093|3000|9100)'
```

### 3. Tester les APIs

```bash
# Prometheus
curl http://localhost:9090/-/healthy
curl http://localhost:9090/api/v1/targets

# Alertmanager
curl http://localhost:9093/-/healthy

# Grafana
curl http://localhost:3000/api/health

# Node Exporter
curl http://localhost:9100/metrics | head -20
```

### 4. Vérifier les logs

```bash
# Prometheus
sudo journalctl -u prometheus -f

# Alertmanager
sudo journalctl -u alertmanager -f

# Grafana
sudo journalctl -u grafana-server -f

# Node Exporter
sudo journalctl -u node_exporter -f
```

### 5. Accéder aux interfaces web

- **Grafana**: http://votre-ip:3000 (admin/admin123)
- **Prometheus**: http://votre-ip:9090
- **Alertmanager**: http://votre-ip:9093

---

## Maintenance

### Mise à jour de Prometheus

```bash
# Arrêter le service
sudo systemctl stop prometheus

# Télécharger la nouvelle version
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/vX.Y.Z/prometheus-X.Y.Z.linux-amd64.tar.gz
tar xvf prometheus-X.Y.Z.linux-amd64.tar.gz

# Remplacer les binaires
sudo cp prometheus-X.Y.Z.linux-amd64/prometheus /usr/local/bin/
sudo cp prometheus-X.Y.Z.linux-amd64/promtool /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool

# Redémarrer
sudo systemctl start prometheus
```

### Validation de la configuration

```bash
# Valider prometheus.yml
promtool check config /etc/prometheus/prometheus.yml

# Valider alerts.yml
promtool check rules /etc/prometheus/alerts.yml

# Valider alertmanager.yml
amtool check-config /etc/alertmanager/alertmanager.yml
```

### Reload des configurations

```bash
# Prometheus (reload à chaud)
sudo systemctl reload prometheus
# OU
curl -X POST http://localhost:9090/-/reload

# Alertmanager (reload à chaud)
sudo systemctl reload alertmanager
# OU
curl -X POST http://localhost:9093/-/reload

# Grafana (redémarrage nécessaire)
sudo systemctl restart grafana-server
```

### Sauvegarde

```bash
# Script de backup
#!/bin/bash
BACKUP_DIR="/backup/monitoring"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p ${BACKUP_DIR}

# Backup des configurations
tar czf ${BACKUP_DIR}/configs_${DATE}.tar.gz \
  /etc/prometheus \
  /etc/alertmanager \
  /etc/grafana

# Backup des données Prometheus
tar czf ${BACKUP_DIR}/prometheus_data_${DATE}.tar.gz \
  /var/lib/prometheus

# Backup des données Grafana
tar czf ${BACKUP_DIR}/grafana_data_${DATE}.tar.gz \
  /var/lib/grafana
```

### Nettoyage

```bash
# Nettoyer les anciennes données Prometheus (manuel)
# Les données sont dans /var/lib/prometheus
# Prometheus gère automatiquement la rétention selon la config

# Voir l'espace utilisé
du -sh /var/lib/prometheus
du -sh /var/lib/grafana
```

---

## Dépannage

### Prometheus ne démarre pas

```bash
# Vérifier les logs
sudo journalctl -u prometheus -n 50 --no-pager

# Vérifier la config
promtool check config /etc/prometheus/prometheus.yml

# Vérifier les permissions
ls -la /etc/prometheus
ls -la /var/lib/prometheus
```

### Port déjà utilisé

```bash
# Trouver quel processus utilise le port
sudo lsof -i :9090
sudo ss -tlnp | grep :9090

# Tuer le processus si nécessaire
sudo kill -9 PID
```

### Grafana ne peut pas se connecter à Prometheus

```bash
# Vérifier que Prometheus est accessible
curl http://localhost:9090/-/healthy

# Vérifier les logs Grafana
sudo journalctl -u grafana-server -f

# Tester la datasource manuellement
curl -X POST http://admin:admin123@localhost:3000/api/datasources/1/health
```

---

## Sécurisation (Production)

### 1. HTTPS avec Nginx

```bash
# Installer Nginx et Certbot
sudo apt install nginx certbot python3-certbot-nginx -y

# Configuration Nginx pour Grafana
sudo nano /etc/nginx/sites-available/grafana
```

```nginx
server {
    listen 80;
    server_name grafana.example.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

```bash
# Activer le site
sudo ln -s /etc/nginx/sites-available/grafana /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Obtenir un certificat SSL
sudo certbot --nginx -d grafana.example.com
```

### 2. Authentification basic pour Prometheus

Créer `/etc/prometheus/web.yml`:

```yaml
basic_auth_users:
  admin: $2y$10$...  # Hash bcrypt du mot de passe
```

Générer le hash:

```bash
sudo apt install apache2-utils -y
htpasswd -nBC 10 "" | tr -d ':\n'
```

Modifier le service:

```ini
ExecStart=/usr/local/bin/prometheus \
  --web.config.file=/etc/prometheus/web.yml \
  ...
```

### 3. Restreindre l'accès par IP

Dans `/etc/nginx/sites-available/prometheus`:

```nginx
server {
    listen 80;
    server_name prometheus.example.com;
    
    # Restreindre à certaines IPs
    allow 192.168.1.0/24;
    deny all;
    
    location / {
        proxy_pass http://localhost:9090;
    }
}
```

---

## Commandes utiles

```bash
# Redémarrer tous les services
sudo systemctl restart prometheus alertmanager grafana-server node_exporter

# Voir les logs en temps réel
sudo journalctl -f -u prometheus -u alertmanager -u grafana-server

# Vérifier l'utilisation des ressources
sudo systemctl status prometheus --no-pager -l
ps aux | grep prometheus

# Tester une alerte
curl -X POST http://localhost:9093/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"Test"}}]'
```

---

## Conclusion

Vous avez maintenant une stack de monitoring complète installée nativement sur Debian. Pour la production:

- ✅ Configurez HTTPS
- ✅ Changez tous les mots de passe par défaut
- ✅ Mettez en place des sauvegardes régulières
- ✅ Configurez les notifications (email, Slack, etc.)
- ✅ Surveillez l'espace disque et la rétention
- ✅ Documentez votre configuration spécifique

Bon monitoring! 📊
