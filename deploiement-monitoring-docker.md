# Déploiement Simplifié de Grafana, Prometheus et Alertmanager sur Docker

## Table des matières
1. [Prérequis](#prérequis)
2. [Architecture](#architecture)
3. [Structure du projet](#structure-du-projet)
4. [Configuration Prometheus](#configuration-prometheus)
5. [Configuration Alertmanager](#configuration-alertmanager)
6. [Configuration Grafana](#configuration-grafana)
7. [Docker Compose](#docker-compose)
8. [Déploiement](#déploiement)
9. [Vérification](#vérification)
10. [Maintenance](#maintenance)

---

## Prérequis

### Logiciels nécessaires
- Docker Engine 20.10+
- Docker Compose 2.0+
- Au moins 2 GB de RAM disponible
- 10 GB d'espace disque

### Installation de Docker (si nécessaire)
```bash
# Mise à jour du système
sudo apt update && sudo apt upgrade -y

# Installation de Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER

# Installation de Docker Compose
sudo apt install docker-compose-plugin -y

# Vérification
docker --version
docker compose version
```

---

## Architecture

```
┌─────────────────┐
│   Grafana       │
│   Port: 3000    │
└────────┬────────┘
         │
         │ Récupère les métriques
         ▼
┌─────────────────┐      ┌─────────────────┐
│  Prometheus     │◄────►│ Alertmanager    │
│  Port: 9090     │      │ Port: 9093      │
└────────┬────────┘      └─────────────────┘
         │
         │ Scrape les métriques
         ▼
┌─────────────────┐
│   Exporters     │
│   (node, etc.)  │
└─────────────────┘
```

### Ports utilisés
- **Grafana**: 3000
- **Prometheus**: 9090
- **Alertmanager**: 9093
- **Node Exporter**: 9100 (optionnel)

---

## Structure du projet

```
monitoring/
├── docker-compose.yml
├── prometheus/
│   ├── prometheus.yml
│   ├── alerts.yml
│   └── data/          (créé automatiquement)
├── alertmanager/
│   ├── alertmanager.yml
│   └── data/          (créé automatiquement)
└── grafana/
    ├── provisioning/
    │   ├── datasources/
    │   │   └── prometheus.yml
    │   └── dashboards/
    │       ├── dashboard.yml
    │       └── node-exporter.json
    └── data/          (créé automatiquement)
```

### Création de la structure
```bash
mkdir -p monitoring/{prometheus,alertmanager,grafana/provisioning/{datasources,dashboards}}
cd monitoring
```

---

## Configuration Prometheus

### Fichier: `prometheus/prometheus.yml`

Ce fichier définit la configuration principale de Prometheus.

```yaml
# Configuration globale
global:
  scrape_interval: 15s              # Fréquence de collecte des métriques
  evaluation_interval: 15s          # Fréquence d'évaluation des règles
  external_labels:
    cluster: 'docker-monitoring'    # Label pour identifier le cluster
    environment: 'production'

# Configuration Alertmanager
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093     # Nom du service Docker

# Chargement des règles d'alertes
rule_files:
  - '/etc/prometheus/alerts.yml'

# Configuration des targets à monitorer
scrape_configs:
  # Prometheus lui-même
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          instance: 'prometheus-server'

  # Alertmanager
  - job_name: 'alertmanager'
    static_configs:
      - targets: ['alertmanager:9093']
        labels:
          instance: 'alertmanager-server'

  # Node Exporter (métriques système)
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          instance: 'docker-host'

  # Ajoutez ici vos autres targets
  # Exemple pour une application
  # - job_name: 'mon-application'
  #   static_configs:
  #     - targets: ['mon-app:8080']
  #       labels:
  #         app: 'mon-app'
  #         env: 'prod'
```

#### Explication des paramètres clés

| Paramètre | Description | Valeur recommandée |
|-----------|-------------|-------------------|
| `scrape_interval` | Intervalle entre chaque collecte | 15s (ajuster selon la charge) |
| `evaluation_interval` | Intervalle d'évaluation des alertes | 15s (même que scrape_interval) |
| `external_labels` | Labels ajoutés à toutes les métriques | Selon votre environnement |
| `scrape_timeout` | Timeout pour la collecte | 10s (non défini = scrape_interval) |

### Fichier: `prometheus/alerts.yml`

Définit les règles d'alertes.

```yaml
groups:
  # Groupe d'alertes pour la disponibilité des services
  - name: service_availability
    interval: 30s
    rules:
      # Alerte si une instance est down
      - alert: InstanceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
          category: availability
        annotations:
          summary: "Instance {{ $labels.instance }} est down"
          description: "L'instance {{ $labels.instance }} du job {{ $labels.job }} est inaccessible depuis plus de 2 minutes."

  # Groupe d'alertes pour les ressources système
  - name: system_resources
    interval: 30s
    rules:
      # Alerte si CPU > 80%
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
          category: resources
        annotations:
          summary: "CPU élevé sur {{ $labels.instance }}"
          description: "L'utilisation CPU est à {{ $value | humanize }}% sur {{ $labels.instance }}."

      # Alerte si mémoire disponible < 10%
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: warning
          category: resources
        annotations:
          summary: "Mémoire élevée sur {{ $labels.instance }}"
          description: "L'utilisation mémoire est à {{ $value | humanize }}% sur {{ $labels.instance }}."

      # Alerte si disque disponible < 10%
      - alert: DiskSpaceLow
        expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 90
        for: 5m
        labels:
          severity: warning
          category: resources
        annotations:
          summary: "Espace disque faible sur {{ $labels.instance }}"
          description: "Le disque {{ $labels.mountpoint }} sur {{ $labels.instance }} est utilisé à {{ $value | humanize }}%."

  # Groupe d'alertes Prometheus
  - name: prometheus_alerts
    interval: 30s
    rules:
      # Alerte si Prometheus ne peut pas scraper une target
      - alert: PrometheusTargetDown
        expr: up{job!="prometheus"} == 0
        for: 2m
        labels:
          severity: critical
          category: monitoring
        annotations:
          summary: "Target Prometheus down"
          description: "La target {{ $labels.job }} ({{ $labels.instance }}) est inaccessible."

      # Alerte si trop d'échantillons sont rejetés
      - alert: PrometheusHighRejectedSamples
        expr: rate(prometheus_target_scrapes_sample_out_of_order_total[5m]) > 0
        for: 5m
        labels:
          severity: warning
          category: monitoring
        annotations:
          summary: "Prometheus rejette des échantillons"
          description: "Prometheus rejette {{ $value | humanize }} échantillons/sec de {{ $labels.instance }}."
```

#### Structure d'une règle d'alerte

```yaml
- alert: NomDeLAlerte              # Nom unique de l'alerte
  expr: expression_promql          # Expression PromQL à évaluer
  for: 5m                          # Durée avant déclenchement
  labels:                          # Labels personnalisés
    severity: warning|critical     # Niveau de sévérité
    category: custom               # Catégorie personnalisée
  annotations:                     # Informations supplémentaires
    summary: "Description courte"  # Résumé de l'alerte
    description: "Description détaillée avec {{ $labels.variable }}"
```

---

## Configuration Alertmanager

### Fichier: `alertmanager/alertmanager.yml`

Configure le routage et les notifications des alertes.

```yaml
# Configuration globale
global:
  resolve_timeout: 5m              # Temps avant de considérer une alerte résolue
  
  # Configuration SMTP (pour les emails)
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alertmanager@example.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'
  smtp_require_tls: true

# Templates personnalisés (optionnel)
templates:
  - '/etc/alertmanager/templates/*.tmpl'

# Configuration du routage des alertes
route:
  # Receveur par défaut
  receiver: 'default-receiver'
  
  # Groupement des alertes
  group_by: ['alertname', 'cluster', 'service']
  
  # Temps d'attente avant d'envoyer la première notification
  group_wait: 10s
  
  # Temps d'attente avant d'envoyer des alertes supplémentaires pour le même groupe
  group_interval: 10s
  
  # Temps minimum entre deux notifications pour la même alerte
  repeat_interval: 12h
  
  # Routes spécifiques
  routes:
    # Alertes critiques
    - match:
        severity: critical
      receiver: 'critical-alerts'
      group_wait: 10s
      group_interval: 5m
      repeat_interval: 3h
    
    # Alertes de warning
    - match:
        severity: warning
      receiver: 'warning-alerts'
      group_wait: 30s
      group_interval: 10m
      repeat_interval: 12h
    
    # Alertes de disponibilité
    - match:
        category: availability
      receiver: 'availability-alerts'
      group_wait: 5s

# Configuration des inhibitions (empêcher certaines alertes)
inhibit_rules:
  # Si une instance est down, ne pas alerter sur ses métriques
  - source_match:
      severity: 'critical'
      alertname: 'InstanceDown'
    target_match:
      severity: 'warning'
    equal: ['instance']

# Configuration des receveurs
receivers:
  # Receveur par défaut (webhook ou autre)
  - name: 'default-receiver'
    webhook_configs:
      - url: 'http://localhost:5001/webhook'
        send_resolved: true

  # Alertes critiques - Email + Webhook
  - name: 'critical-alerts'
    email_configs:
      - to: 'admin@example.com'
        headers:
          Subject: '🚨 [CRITIQUE] {{ .GroupLabels.alertname }}'
        html: |
          <h2>Alerte Critique</h2>
          <p><strong>Alert:</strong> {{ .GroupLabels.alertname }}</p>
          <p><strong>Severity:</strong> {{ .CommonLabels.severity }}</p>
          <p><strong>Summary:</strong> {{ .CommonAnnotations.summary }}</p>
          <p><strong>Description:</strong> {{ .CommonAnnotations.description }}</p>
        send_resolved: true
    
    # Exemple: Slack
    # slack_configs:
    #   - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
    #     channel: '#alerts-critical'
    #     title: '🚨 {{ .GroupLabels.alertname }}'
    #     text: '{{ .CommonAnnotations.summary }}'
    #     send_resolved: true

  # Alertes warning - Email uniquement
  - name: 'warning-alerts'
    email_configs:
      - to: 'team@example.com'
        headers:
          Subject: '⚠️ [WARNING] {{ .GroupLabels.alertname }}'
        html: |
          <h2>Alerte Warning</h2>
          <p><strong>Alert:</strong> {{ .GroupLabels.alertname }}</p>
          <p><strong>Summary:</strong> {{ .CommonAnnotations.summary }}</p>
        send_resolved: true

  # Alertes de disponibilité
  - name: 'availability-alerts'
    email_configs:
      - to: 'oncall@example.com'
        headers:
          Subject: '🔴 [DISPONIBILITÉ] {{ .GroupLabels.alertname }}'
        send_resolved: true
```

#### Paramètres clés d'Alertmanager

| Paramètre | Description | Valeur recommandée |
|-----------|-------------|-------------------|
| `group_wait` | Attente avant première notification | 10s (critique), 30s (warning) |
| `group_interval` | Intervalle entre notifications groupées | 5m (critique), 10m (warning) |
| `repeat_interval` | Intervalle de répétition | 3h (critique), 12h (warning) |
| `resolve_timeout` | Timeout de résolution | 5m |

#### Configuration pour différents canaux

**Pour Slack:**
```yaml
slack_configs:
  - api_url: 'https://hooks.slack.com/services/XXX/YYY/ZZZ'
    channel: '#alerts'
    username: 'Alertmanager'
    icon_emoji: ':bell:'
    title: '{{ .GroupLabels.alertname }}'
    text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
    send_resolved: true
```

**Pour PagerDuty:**
```yaml
pagerduty_configs:
  - service_key: 'YOUR_SERVICE_KEY'
    description: '{{ .GroupLabels.alertname }}'
    severity: '{{ .CommonLabels.severity }}'
```

**Pour Webhook personnalisé:**
```yaml
webhook_configs:
  - url: 'http://your-service:5000/webhook'
    send_resolved: true
    http_config:
      basic_auth:
        username: 'user'
        password: 'pass'
```

---

## Configuration Grafana

### Fichier: `grafana/provisioning/datasources/prometheus.yml`

Provisionne automatiquement Prometheus comme source de données.

```yaml
apiVersion: 1

# Liste des datasources à provisionner
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy                    # proxy = via serveur Grafana
    url: http://prometheus:9090      # URL du service Prometheus
    isDefault: true                  # Source de données par défaut
    editable: true                   # Modifiable dans l'UI
    jsonData:
      timeInterval: '15s'            # Intervalle de temps minimum
      httpMethod: 'POST'             # Méthode HTTP (POST recommandé)
      exemplarTraceIdDestinations:   # Pour les traces (optionnel)
        - name: traceID
          datasourceUid: tempo
```

### Fichier: `grafana/provisioning/dashboards/dashboard.yml`

Configure le provisionnement des dashboards.

```yaml
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: ''                       # Dossier racine
    type: file
    disableDeletion: false           # Permet la suppression dans l'UI
    updateIntervalSeconds: 30        # Intervalle de vérification
    allowUiUpdates: true             # Permet les modifications UI
    options:
      path: /etc/grafana/provisioning/dashboards
      foldersFromFilesStructure: true
```

### Variables d'environnement Grafana

Dans le docker-compose.yml, vous pouvez configurer:

```yaml
environment:
  # Configuration de base
  - GF_SECURITY_ADMIN_USER=admin
  - GF_SECURITY_ADMIN_PASSWORD=admin123
  
  # Configuration du serveur
  - GF_SERVER_ROOT_URL=http://localhost:3000
  - GF_SERVER_DOMAIN=localhost
  
  # Configuration des utilisateurs
  - GF_USERS_ALLOW_SIGN_UP=false
  - GF_USERS_ALLOW_ORG_CREATE=false
  - GF_USERS_AUTO_ASSIGN_ORG=true
  - GF_USERS_AUTO_ASSIGN_ORG_ROLE=Viewer
  
  # Configuration de la sécurité
  - GF_AUTH_ANONYMOUS_ENABLED=false
  - GF_AUTH_DISABLE_LOGIN_FORM=false
  
  # Configuration SMTP (pour les alertes)
  - GF_SMTP_ENABLED=true
  - GF_SMTP_HOST=smtp.gmail.com:587
  - GF_SMTP_USER=your-email@gmail.com
  - GF_SMTP_PASSWORD=your-app-password
  - GF_SMTP_FROM_ADDRESS=grafana@example.com
  
  # Configuration des logs
  - GF_LOG_MODE=console
  - GF_LOG_LEVEL=info
```

---

## Docker Compose

### Fichier: `docker-compose.yml`

Configuration complète du déploiement.

```yaml
version: '3.8'

# Définition des volumes
volumes:
  prometheus-data:
    driver: local
  grafana-data:
    driver: local
  alertmanager-data:
    driver: local

# Définition du réseau
networks:
  monitoring:
    driver: bridge

services:
  # Prometheus
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    
    # Configuration des volumes
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/alerts.yml:/etc/prometheus/alerts.yml:ro
      - prometheus-data:/prometheus
    
    # Arguments de démarrage
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'           # Rétention des données
      - '--storage.tsdb.retention.size=10GB'          # Taille max des données
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
      - '--web.enable-lifecycle'                       # Permet le reload à chaud
      - '--web.enable-admin-api'                       # Active l'API admin
    
    # Exposition des ports
    ports:
      - "9090:9090"
    
    # Configuration réseau
    networks:
      - monitoring
    
    # Healthcheck
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    
    # Limites de ressources
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M

  # Alertmanager
  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    restart: unless-stopped
    
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager-data:/alertmanager
    
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=http://localhost:9093'
      - '--cluster.advertise-address=0.0.0.0:9093'
    
    ports:
      - "9093:9093"
    
    networks:
      - monitoring
    
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9093/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
    
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        reservations:
          cpus: '0.25'
          memory: 128M

  # Grafana
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    
    # Utilisateur (pour éviter les problèmes de permissions)
    user: "472"
    
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    
    environment:
      # Identifiants par défaut (À CHANGER EN PRODUCTION!)
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      
      # Configuration serveur
      - GF_SERVER_ROOT_URL=http://localhost:3000
      - GF_SERVER_DOMAIN=localhost
      
      # Désactiver l'inscription
      - GF_USERS_ALLOW_SIGN_UP=false
      
      # Configuration logs
      - GF_LOG_MODE=console
      - GF_LOG_LEVEL=info
      
      # Configuration des plugins
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource,grafana-piechart-panel
    
    ports:
      - "3000:3000"
    
    networks:
      - monitoring
    
    # Dépendances
    depends_on:
      prometheus:
        condition: service_healthy
    
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M

  # Node Exporter (métriques système)
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    
    command:
      - '--path.rootfs=/host'
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    
    volumes:
      - /:/host:ro,rslave
    
    ports:
      - "9100:9100"
    
    networks:
      - monitoring
    
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 128M
        reservations:
          cpus: '0.1'
          memory: 64M

  # cAdvisor (métriques conteneurs) - Optionnel
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    
    ports:
      - "8080:8080"
    
    networks:
      - monitoring
    
    privileged: true
    
    devices:
      - /dev/kmsg
    
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        reservations:
          cpus: '0.25'
          memory: 128M
```

#### Explication des paramètres Docker Compose

**Volumes:**
- Persistent storage pour les données
- `:ro` = read-only
- `:rslave` = montage en mode slave pour les sous-montages

**Networks:**
- `bridge`: réseau par défaut, isolation entre conteneurs
- Les services peuvent communiquer par leur nom

**Restart policies:**
- `unless-stopped`: redémarre sauf si arrêté manuellement
- `always`: redémarre toujours
- `on-failure`: redémarre seulement en cas d'erreur

**Healthchecks:**
- Vérifie que le service est opérationnel
- Permet à Docker de gérer les dépendances

---

## Déploiement

### Étape 1: Préparation des fichiers

```bash
# Créer tous les fichiers de configuration
cd monitoring

# Vérifier que tous les fichiers sont présents
tree
```

### Étape 2: Ajuster les permissions

```bash
# Créer les répertoires de données
mkdir -p prometheus/data alertmanager/data grafana/data

# Ajuster les permissions pour Grafana
sudo chown -R 472:472 grafana/data

# Permissions pour Prometheus et Alertmanager
sudo chown -R 65534:65534 prometheus/data alertmanager/data
```

### Étape 3: Validation des configurations

```bash
# Valider la config Prometheus (nécessite prometheus en local ou docker)
docker run --rm -v $(pwd)/prometheus:/etc/prometheus prom/prometheus:latest \
  promtool check config /etc/prometheus/prometheus.yml

# Valider les règles d'alertes
docker run --rm -v $(pwd)/prometheus:/etc/prometheus prom/prometheus:latest \
  promtool check rules /etc/prometheus/alerts.yml

# Valider la config Alertmanager
docker run --rm -v $(pwd)/alertmanager:/etc/alertmanager prom/alertmanager:latest \
  amtool check-config /etc/alertmanager/alertmanager.yml
```

### Étape 4: Démarrage des services

```bash
# Démarrer tous les services
docker compose up -d

# Vérifier les logs
docker compose logs -f

# Vérifier le statut des conteneurs
docker compose ps
```

### Étape 5: Commandes utiles

```bash
# Arrêter tous les services
docker compose down

# Redémarrer un service spécifique
docker compose restart prometheus

# Voir les logs d'un service
docker compose logs -f grafana

# Recharger la config Prometheus sans redémarrage
curl -X POST http://localhost:9090/-/reload

# Mettre à jour les images
docker compose pull
docker compose up -d

# Nettoyer les volumes (ATTENTION: perte de données!)
docker compose down -v
```

---

## Vérification

### 1. Vérifier Prometheus

```bash
# Via navigateur
http://localhost:9090

# Vérifier les targets
http://localhost:9090/targets

# Vérifier les alertes
http://localhost:9090/alerts

# Via ligne de commande
curl http://localhost:9090/-/healthy
curl http://localhost:9090/-/ready

# Tester une requête PromQL
curl 'http://localhost:9090/api/v1/query?query=up'
```

**Points à vérifier:**
- ✅ Tous les targets sont "UP"
- ✅ Pas d'erreur dans les logs
- ✅ Les alertes sont chargées
- ✅ Les métriques sont collectées

### 2. Vérifier Alertmanager

```bash
# Via navigateur
http://localhost:9093

# Vérifier le statut
curl http://localhost:9093/-/healthy

# Voir les alertes actives
curl http://localhost:9093/api/v2/alerts

# Tester l'envoi d'une alerte
curl -X POST http://localhost:9093/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[{
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning"
    },
    "annotations": {
      "summary": "Test alert"
    }
  }]'
```

**Points à vérifier:**
- ✅ Interface accessible
- ✅ Configuration chargée sans erreur
- ✅ Routing configuré correctement

### 3. Vérifier Grafana

```bash
# Via navigateur
http://localhost:3000

# Identifiants par défaut
# Username: admin
# Password: admin123

# Vérifier l'API
curl http://localhost:3000/api/health
```

**Points à vérifier:**
- ✅ Connexion possible avec les identifiants
- ✅ Prometheus configuré comme datasource
- ✅ Les dashboards sont provisionnés
- ✅ Les requêtes vers Prometheus fonctionnent

### 4. Vérifier Node Exporter

```bash
# Via navigateur
http://localhost:9100/metrics

# Via ligne de commande
curl http://localhost:9100/metrics | grep node_cpu
```

### 5. Tests d'intégration

**Test 1: Déclencher une alerte**
```bash
# Arrêter un service pour déclencher InstanceDown
docker compose stop node-exporter

# Attendre 2 minutes puis vérifier
http://localhost:9090/alerts
http://localhost:9093

# Redémarrer le service
docker compose start node-exporter
```

**Test 2: Vérifier la collecte de métriques**
```bash
# Dans Grafana, créer un panel avec la requête
up{job="prometheus"}

# Ou via PromQL
curl 'http://localhost:9090/api/v1/query?query=up{job="prometheus"}'
```

**Test 3: Vérifier les notifications**
```bash
# Vérifier les logs d'Alertmanager pour les notifications
docker compose logs alertmanager | grep -i "notify"
```

---

## Maintenance

### Sauvegarde

```bash
# Script de sauvegarde
#!/bin/bash
BACKUP_DIR="/backup/monitoring"
DATE=$(date +%Y%m%d_%H%M%S)

# Créer le répertoire de backup
mkdir -p ${BACKUP_DIR}

# Sauvegarder les données Prometheus
docker run --rm \
  -v monitoring_prometheus-data:/data \
  -v ${BACKUP_DIR}:/backup \
  alpine tar czf /backup/prometheus_${DATE}.tar.gz -C /data .

# Sauvegarder les données Grafana
docker run --rm \
  -v monitoring_grafana-data:/data \
  -v ${BACKUP_DIR}:/backup \
  alpine tar czf /backup/grafana_${DATE}.tar.gz -C /data .

# Sauvegarder les configurations
tar czf ${BACKUP_DIR}/configs_${DATE}.tar.gz \
  prometheus/ alertmanager/ grafana/provisioning/

echo "Backup completed: ${BACKUP_DIR}"
```

### Restauration

```bash
# Restaurer Prometheus
docker run --rm \
  -v monitoring_prometheus-data:/data \
  -v /backup/monitoring:/backup \
  alpine tar xzf /backup/prometheus_20240101_120000.tar.gz -C /data

# Restaurer Grafana
docker run --rm \
  -v monitoring_grafana-data:/data \
  -v /backup/monitoring:/backup \
  alpine tar xzf /backup/grafana_20240101_120000.tar.gz -C /data

# Redémarrer les services
docker compose restart
```

### Mise à jour

```bash
# Mettre à jour les images
docker compose pull

# Redémarrer avec les nouvelles images
docker compose up -d

# Vérifier les versions
docker compose exec prometheus prometheus --version
docker compose exec grafana grafana-cli --version
docker compose exec alertmanager alertmanager --version
```

### Nettoyage

```bash
# Nettoyer les anciennes données Prometheus (dans le conteneur)
docker compose exec prometheus \
  prometheus --storage.tsdb.retention.time=7d

# Nettoyer les images Docker inutilisées
docker image prune -a -f

# Voir l'utilisation des volumes
docker system df -v
```

### Monitoring de la stack elle-même

```bash
# Vérifier l'utilisation des ressources
docker stats

# Vérifier les logs d'erreur
docker compose logs --tail=100 | grep -i error

# Vérifier la taille des volumes
docker system df -v | grep monitoring
```

### Dépannage

**Problème: Prometheus ne démarre pas**
```bash
# Vérifier les logs
docker compose logs prometheus

# Vérifier la config
docker compose exec prometheus cat /etc/prometheus/prometheus.yml

# Vérifier les permissions
ls -la prometheus/data
```

**Problème: Grafana ne peut pas se connecter à Prometheus**
```bash
# Vérifier la résolution DNS
docker compose exec grafana nslookup prometheus

# Vérifier la connexion réseau
docker compose exec grafana wget -O- http://prometheus:9090/-/healthy

# Vérifier la config de la datasource
docker compose exec grafana cat /etc/grafana/provisioning/datasources/prometheus.yml
```

**Problème: Alertmanager ne reçoit pas les alertes**
```bash
# Vérifier que Prometheus peut joindre Alertmanager
docker compose exec prometheus wget -O- http://alertmanager:9093/-/healthy

# Vérifier la config Prometheus
curl http://localhost:9090/api/v1/status/config | jq .data.yaml | grep -A5 alerting

# Tester manuellement une alerte
curl -X POST http://localhost:9093/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"Test"}}]'
```

---

## Sécurisation (Production)

### 1. Changer les mots de passe par défaut

```yaml
# Dans docker-compose.yml
environment:
  - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
```

```bash
# Créer un fichier .env
echo "GRAFANA_PASSWORD=$(openssl rand -base64 32)" > .env
```

### 2. Activer HTTPS avec Traefik ou Nginx

```yaml
# Exemple avec labels Traefik
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.grafana.rule=Host(`grafana.example.com`)"
  - "traefik.http.routers.grafana.tls=true"
  - "traefik.http.routers.grafana.tls.certresolver=letsencrypt"
```

### 3. Restreindre l'accès réseau

```yaml
# Limiter les ports exposés uniquement au nécessaire
ports:
  - "127.0.0.1:9090:9090"  # Prometheus accessible que localement
```

### 4. Configurer l'authentification

```yaml
# Prometheus avec basic auth
command:
  - '--web.config.file=/etc/prometheus/web.yml'

# Fichier web.yml
basic_auth_users:
  admin: $2y$10$... # bcrypt hash
```

---

## Ressources supplémentaires

- Documentation Prometheus: https://prometheus.io/docs/
- Documentation Grafana: https://grafana.com/docs/
- Documentation Alertmanager: https://prometheus.io/docs/alerting/latest/alertmanager/
- PromQL Tutorial: https://prometheus.io/docs/prometheus/latest/querying/basics/
- Dashboards Grafana: https://grafana.com/grafana/dashboards/

---

## Conclusion

Cette configuration fournit un système de monitoring complet et fonctionnel. Pour la production, pensez à:

1. ✅ Changer tous les mots de passe par défaut
2. ✅ Configurer HTTPS
3. ✅ Mettre en place des sauvegardes régulières
4. ✅ Configurer les notifications (email, Slack, PagerDuty)
5. ✅ Ajuster la rétention des données selon vos besoins
6. ✅ Monitorer les performances de la stack elle-même
7. ✅ Documenter votre configuration spécifique

Bon monitoring! 📊
