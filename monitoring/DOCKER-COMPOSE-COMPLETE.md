# Docker Compose Complet - Guide Ultime

> Configuration Docker Compose unifiée avec toutes les fonctionnalités : Standalone, Fédération, TLS, Rétention optimisée

## Vue d'Ensemble

Le fichier `docker-compose-complete.yml` est une configuration **ALL-IN-ONE** qui inclut :

✅ **Prometheus Standalone** - Configuration standard
✅ **Fédération Prometheus** - Central + Edge (avec profiles)
✅ **Options Command complètes** - Toutes les options de rétention, performance, logging
✅ **TLS/SSL** - Certificats auto-signés + Nginx reverse proxy
✅ **Configuration réseau avancée** - Sous-réseau dédié avec IPs statiques
✅ **Limites de ressources** - CPU/RAM configurées
✅ **Healthchecks** - Tous les services
✅ **Labels** - Pour organisation et monitoring

## Architecture Complète

```
                        ┌─────────────────┐
                        │  NGINX (TLS)    │
                        │  Port 443       │
                        └────────┬────────┘
                                 │
            ┌────────────────────┼────────────────────┐
            │                    │                    │
            ▼                    ▼                    ▼
    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
    │  Grafana     │    │  Prometheus  │    │ Alertmanager │
    │  Port 3000   │    │  Port 9090   │    │  Port 9093   │
    └──────────────┘    └──────┬───────┘    └──────────────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
                ▼              ▼              ▼
        ┌──────────┐   ┌──────────┐   ┌──────────┐
        │  Node    │   │ cAdvisor │   │ Targets  │
        │ Exporter │   │          │   │  Custom  │
        └──────────┘   └──────────┘   └──────────┘

        Mode Fédération (profiles: federation)
        ┌──────────────────┐
        │ Prometheus       │
        │ Central          │
        │ Port 9095        │
        └────────┬─────────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
  ┌──────────┐     ┌──────────┐
  │Prometheus│     │Prometheus│
  │  Edge    │     │  Site 2  │
  │ Port9091 │     │ Port9092 │
  └──────────┘     └──────────┘
```

## Démarrage Rapide

### Mode Standard (Prometheus Standalone)

```bash
cd monitoring

# Démarrer la stack standard
docker compose -f docker-compose-complete.yml up -d

# Services actifs:
# - Prometheus (9090)
# - Grafana (3000)
# - Alertmanager (9093)
# - cAdvisor (8080)
```

### Mode Fédération

```bash
# Démarrer avec la fédération
docker compose -f docker-compose-complete.yml --profile federation up -d

# Services actifs:
# - Tous les services standard
# + Prometheus Central (9095)
# + Prometheus Edge (9091)
```

### Mode TLS (Nginx Reverse Proxy)

```bash
# 1. Générer les certificats
./generate-certs.sh

# 2. Démarrer avec TLS
docker compose -f docker-compose-complete.yml --profile tls up -d

# Accès via HTTPS:
# - https://grafana.local
# - https://prometheus.local
# - https://alertmanager.local
```

### Mode Complet (Tout activé)

```bash
# Générer les certificats
./generate-certs.sh

# Démarrer TOUT
docker compose -f docker-compose-complete.yml --profile federation --profile tls up -d
```

## Services Inclus

### Services Principaux (Toujours actifs)

| Service | Port | Description | IP Statique |
|---------|------|-------------|-------------|
| **prometheus** | 9090 | Prometheus standalone | 172.20.0.10 |
| **grafana** | 3000 | Interface dashboards | 172.20.0.30 |
| **alertmanager** | 9093, 9094 | Gestion alertes | 172.20.0.20 |
| **cadvisor** | 8080 | Métriques conteneurs | 172.20.0.41 |

### Services avec Profiles

| Service | Profile | Port | Description |
|---------|---------|------|-------------|
| **prometheus-central** | `federation` | 9095 | Hub fédération | |
| **prometheus-edge** | `federation` | 9091 | Collecteur edge |
| **node-exporter** | `linux` | 9100 | Métriques système Linux |
| **nginx** | `tls` | 80, 443 | Reverse proxy TLS |

## Options de Command Avancées

### Prometheus - Toutes les Options

```yaml
command:
  # ===== Configuration =====
  - '--config.file=/etc/prometheus/prometheus.yml'

  # ===== Stockage TSDB =====
  - '--storage.tsdb.path=/prometheus'
  - '--storage.tsdb.retention.time=30d'           # Rétention temporelle
  - '--storage.tsdb.retention.size=15GB'          # Rétention par taille
  - '--storage.tsdb.min-block-duration=2h'        # Durée min blocs
  - '--storage.tsdb.max-block-duration=36h'       # Durée max blocs
  - '--storage.tsdb.wal-compression'              # Compression WAL

  # ===== Interface Web =====
  - '--web.listen-address=:9090'                  # Adresse écoute
  - '--web.enable-lifecycle'                      # Hot reload
  - '--web.enable-admin-api'                      # API admin
  - '--web.page-title=Prometheus'                 # Titre page
  - '--web.cors.origin=.*'                        # CORS

  # ===== Query =====
  - '--query.timeout=2m'                          # Timeout requêtes
  - '--query.max-concurrency=20'                  # Requêtes simultanées
  - '--query.max-samples=50000000'                # Échantillons max
  - '--query.lookback-delta=5m'                   # Lookback

  # ===== Logging =====
  - '--log.level=info'                            # Level: debug|info|warn|error
  - '--log.format=logfmt'                         # Format: logfmt|json
```

### Configurations par Type

#### Prometheus Standard
- Rétention: **30 jours** ou **15 GB**
- Ressources: **2 CPU** / **2 GB RAM**
- Blocs: 2h - 36h

#### Prometheus Central (Fédération)
- Rétention: **90 jours** ou **50 GB** (longue durée)
- Ressources: **3 CPU** / **4 GB RAM** (plus puissant)
- Query timeout: **5 minutes** (requêtes complexes)

#### Prometheus Edge
- Rétention: **15 jours** ou **10 GB** (courte durée)
- Ressources: **2 CPU** / **2 GB RAM**
- Blocs plus courts: 2h - 24h

### Alertmanager - Options

```yaml
command:
  - '--config.file=/etc/alertmanager/alertmanager.yml'
  - '--storage.path=/alertmanager'
  - '--cluster.listen-address=0.0.0.0:9094'       # Clustering HA
  - '--cluster.advertise-address=IP:9094'         # IP annoncée
  # - '--cluster.peer=autre-alertmanager:9094'    # Peer HA
  - '--web.listen-address=:9093'
  - '--web.external-url=http://localhost:9093'
  - '--alerts.gc-interval=30m'                    # Nettoyage alertes
  - '--log.level=info'
```

### Node Exporter - Collecteurs

```yaml
command:
  # Chemins
  - '--path.procfs=/host/proc'
  - '--path.sysfs=/host/sys'
  - '--path.rootfs=/rootfs'

  # Exclusions
  - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
  - '--collector.netdev.device-exclude=^(veth.*|docker.*|br-.*|lo)$$'

  # Collecteurs optionnels (décommenter si besoin)
  # - '--collector.systemd'                       # Métriques systemd
  # - '--collector.processes'                     # Processus
  # - '--collector.tcpstat'                       # Stats TCP

  # Web
  - '--web.listen-address=:9100'
  - '--web.max-requests=40'
```

## Configuration TLS/SSL

### 1. Génération des Certificats

```bash
# Générer tous les certificats auto-signés
cd monitoring
./generate-certs.sh
```

**Certificats créés** :
- `certs/ca.crt` / `ca.key` - Autorité de certification
- `certs/prometheus.crt` / `prometheus.key`
- `certs/grafana.crt` / `grafana.key`
- `certs/alertmanager.crt` / `alertmanager.key`
- `certs/nginx.crt` / `nginx.key`

### 2. Configuration Prometheus TLS

**Fichier** : `prometheus/web-config.yml`

```yaml
tls_server_config:
  cert_file: /etc/prometheus/certs/prometheus.crt
  key_file: /etc/prometheus/certs/prometheus.key
  min_version: TLS12
  cipher_suites:
    - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
    - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384

# Authentification Basic Auth (optionnel)
basic_auth_users:
  admin: $2y$10$...bcrypt_hash...
```

**Activer dans docker-compose** :
```yaml
command:
  - '--web.config.file=/etc/prometheus/web-config.yml'  # Décommenter
```

### 3. Configuration Grafana HTTPS

**Variables d'environnement** :
```yaml
environment:
  - GF_SERVER_PROTOCOL=https
  - GF_SERVER_CERT_FILE=/etc/grafana/certs/grafana.crt
  - GF_SERVER_CERT_KEY=/etc/grafana/certs/grafana.key
```

### 4. Nginx Reverse Proxy

**Démarrer avec le profile TLS** :
```bash
docker compose -f docker-compose-complete.yml --profile tls up -d
```

**URLs HTTPS** :
- https://grafana.local
- https://prometheus.local
- https://alertmanager.local

**Configurer /etc/hosts** :
```
127.0.0.1 grafana.local
127.0.0.1 prometheus.local
127.0.0.1 alertmanager.local
127.0.0.1 monitoring.local
```

### 5. Installer le Certificat CA

#### Linux
```bash
sudo cp certs/ca.crt /usr/local/share/ca-certificates/monitoring-ca.crt
sudo update-ca-certificates
```

#### macOS
```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain certs/ca.crt
```

#### Windows
1. Double-cliquer sur `certs/ca.crt`
2. "Installer le certificat"
3. "Ordinateur local"
4. "Placer tous les certificats dans le magasin suivant"
5. "Autorités de certification racines de confiance"

## Variables d'Environnement Grafana

### Sécurité
```yaml
- GF_SECURITY_ADMIN_USER=admin
- GF_SECURITY_ADMIN_PASSWORD=admin123          # ⚠️ CHANGER EN PROD
- GF_SECURITY_SECRET_KEY=...                   # openssl rand -base64 32
- GF_SECURITY_COOKIE_SECURE=true               # Si HTTPS
```

### Base de Données

#### SQLite (par défaut)
```yaml
- GF_DATABASE_TYPE=sqlite3
- GF_DATABASE_PATH=/var/lib/grafana/grafana.db
```

#### PostgreSQL
```yaml
- GF_DATABASE_TYPE=postgres
- GF_DATABASE_HOST=postgres:5432
- GF_DATABASE_NAME=grafana
- GF_DATABASE_USER=grafana
- GF_DATABASE_PASSWORD=secret
```

### OAuth (exemple Google)
```yaml
- GF_AUTH_GOOGLE_ENABLED=true
- GF_AUTH_GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
- GF_AUTH_GOOGLE_CLIENT_SECRET=your-secret
- GF_AUTH_GOOGLE_SCOPES=https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email
- GF_AUTH_GOOGLE_ALLOWED_DOMAINS=example.com
```

### SMTP (Notifications Email)
```yaml
- GF_SMTP_ENABLED=true
- GF_SMTP_HOST=smtp.gmail.com:587
- GF_SMTP_USER=your-email@gmail.com
- GF_SMTP_PASSWORD=your-app-password
- GF_SMTP_FROM_ADDRESS=grafana@example.com
```

## Réseau et IPs Statiques

### Configuration Réseau
```yaml
networks:
  monitoring:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### IPs Assignées
```yaml
prometheus:        172.20.0.10
prometheus-central: 172.20.0.11
prometheus-edge:   172.20.0.12
alertmanager:      172.20.0.20
grafana:           172.20.0.30
node-exporter:     172.20.0.40
cadvisor:          172.20.0.41
nginx:             172.20.0.50
```

## Limites de Ressources

### Prometheus Standard
```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 2G
    reservations:
      cpus: '1'
      memory: 1G
```

### Prometheus Central (Fédération)
```yaml
limits:
  cpus: '3'
  memory: 4G
reservations:
  cpus: '2'
  memory: 2G
```

### Ajuster selon vos besoins
```yaml
# Petite installation
limits:
  cpus: '0.5'
  memory: 512M

# Grosse installation
limits:
  cpus: '4'
  memory: 8G
```

## Commandes Utiles

### Démarrage avec Profiles

```bash
# Standard
docker compose -f docker-compose-complete.yml up -d

# Avec fédération
docker compose -f docker-compose-complete.yml --profile federation up -d

# Avec TLS
docker compose -f docker-compose-complete.yml --profile tls up -d

# Tout ensemble
docker compose -f docker-compose-complete.yml --profile federation --profile tls up -d

# Avec Node Exporter (Linux)
docker compose -f docker-compose-complete.yml --profile linux up -d
```

### Gestion des Services

```bash
# Voir le statut
docker compose -f docker-compose-complete.yml ps

# Logs d'un service
docker compose -f docker-compose-complete.yml logs -f prometheus

# Redémarrer un service
docker compose -f docker-compose-complete.yml restart prometheus

# Arrêter tout
docker compose -f docker-compose-complete.yml down

# Arrêter et supprimer les volumes (⚠️ perte de données)
docker compose -f docker-compose-complete.yml down -v
```

### Hot Reload Prometheus

```bash
# Recharger la config sans redémarrage
curl -X POST http://localhost:9090/-/reload

# Vérifier la config
docker compose -f docker-compose-complete.yml exec prometheus \
  promtool check config /etc/prometheus/prometheus.yml
```

## Checklist de Production

Avant de déployer en production :

- [ ] Changer **tous** les mots de passe par défaut
- [ ] Générer des certificats signés (Let's Encrypt ou CA)
- [ ] Configurer **SMTP** pour les notifications
- [ ] Activer **OAuth/SSO** si nécessaire
- [ ] Restreindre **CORS** et accès réseau
- [ ] Configurer **sauvegardes automatiques**
- [ ] Ajuster **rétention** selon vos besoins
- [ ] Définir **limites de ressources** appropriées
- [ ] Activer **monitoring des logs**
- [ ] Tester **disaster recovery**
- [ ] Documenter **votre configuration**

## Dépannage

### Problème: Service ne démarre pas

```bash
# Voir les logs
docker compose -f docker-compose-complete.yml logs service-name

# Vérifier la config
docker compose -f docker-compose-complete.yml config

# Vérifier les ressources
docker stats
```

### Problème: Certificats TLS invalides

```bash
# Régénérer les certificats
rm -rf certs/*
./generate-certs.sh

# Redémarrer les services
docker compose -f docker-compose-complete.yml --profile tls restart
```

### Problème: Prometheus ne collecte pas

```bash
# Vérifier les targets
curl http://localhost:9090/api/v1/targets

# Vérifier le réseau
docker compose -f docker-compose-complete.yml exec prometheus ping cadvisor
```

## Ressources

- [Documentation Prometheus](https://prometheus.io/docs/)
- [Documentation Grafana](https://grafana.com/docs/)
- [Docker Compose Profiles](https://docs.docker.com/compose/profiles/)

---

**Configuration complète et production-ready !** 🚀

Tous les modes : Standalone, Fédération, TLS, avec toutes les options avancées.
