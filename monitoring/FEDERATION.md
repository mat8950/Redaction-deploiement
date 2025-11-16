# Configuration Fédération Prometheus

> Guide complet pour mettre en place une architecture de fédération Prometheus avec un serveur central et des collecteurs edge.

## Table des Matières

1. [Vue d'Ensemble](#vue-densemble)
2. [Architecture](#architecture)
3. [Configuration](#configuration)
4. [Déploiement](#déploiement)
5. [Règles d'Agrégation](#règles-dagrégation)
6. [Alertes Spécifiques](#alertes-spécifiques)
7. [Monitoring de la Fédération](#monitoring-de-la-fédération)
8. [Dépannage](#dépannage)

## Vue d'Ensemble

### Qu'est-ce que la Fédération ?

La fédération Prometheus permet à un serveur Prometheus (central) de récupérer des métriques depuis d'autres serveurs Prometheus (edge/locaux).

### Cas d'Usage

✅ **Multi-sites** - Monitoring de plusieurs datacenters/sites
✅ **Scalabilité** - Répartir la charge de collecte
✅ **Hiérarchie** - Vue globale + vues locales détaillées
✅ **Isolation réseau** - Sites avec connectivité limitée

### Architecture Déployée

```
┌─────────────────────────────────────────────┐
│         PROMETHEUS CENTRAL (Hub)            │
│         Port: 9090                          │
│         Rétention: 90 jours                 │
│         Role: Vue globale agrégée           │
└──────────────┬──────────────────────────────┘
               │
               │ Fédération (/federate)
               │ Scrape toutes les 30s
               │
        ┌──────┴────────┐
        │               │
        ▼               ▼
┌───────────────┐  ┌───────────────┐
│ PROMETHEUS    │  │ PROMETHEUS    │
│ EDGE Site 1   │  │ EDGE Site 2   │
│ Port: 9091    │  │ Port: 9092    │
│ Rétention:15j │  │ Rétention:15j │
└───────┬───────┘  └───────┬───────┘
        │                  │
        │ Scrape local     │ Scrape local
        ▼                  ▼
   ┌─────────┐        ┌─────────┐
   │ Targets │        │ Targets │
   │ Site 1  │        │ Site 2  │
   └─────────┘        └─────────┘
```

## Architecture

### Composants

#### Prometheus Central (Hub)
- **Rôle** : Collecte les métriques agrégées des Prometheus edge
- **Port** : 9090
- **Rétention** : 90 jours (longue durée)
- **Stockage** : 20 GB
- **Scrape** : Endpoints `/federate` des Prometheus edge

#### Prometheus Edge (Collecteur Local)
- **Rôle** : Collecte les métriques locales et les agrège
- **Port** : 9091 (Site 1), 9092 (Site 2)
- **Rétention** : 15 jours (courte durée)
- **Stockage** : 10 GB
- **Scrape** : Targets locaux (exporters, applications)

### Avantages

| Avantage | Description |
|----------|-------------|
| **Scalabilité** | Répartir la charge sur plusieurs Prometheus |
| **Isolation** | Chaque site fonctionne indépendamment |
| **Hiérarchie** | Vue globale + détails locaux |
| **Rétention** | Longue durée au central, courte en edge |
| **Réseau** | Optimise la bande passante (agrégation) |

### Inconvénients

| Inconvénient | Mitigation |
|--------------|------------|
| **Complexité** | Documentation et automation |
| **Latence** | Métriques avec délai de 30s |
| **Pas de temps réel** | Utiliser Prometheus edge pour temps réel |
| **Agrégation** | Bien définir les règles d'agrégation |

## Configuration

### Fichiers Créés

```
monitoring/prometheus/
├── prometheus-central.yml          # Config Prometheus central
├── prometheus-edge.yml             # Config Prometheus edge
├── rules/
│   └── aggregation.yml            # Règles d'agrégation
└── alerts/
    └── federation.yml             # Alertes fédération
```

### Prometheus Central

**Fichier** : `prometheus-central.yml`

**Points clés** :
- `honor_labels: true` - Préserver les labels sources
- `metrics_path: '/federate'` - Endpoint de fédération
- `match[]` - Sélecteur de métriques à fédérer

**Métriques fédérées** :
```yaml
params:
  'match[]':
    - '{job=~".+"}'              # Toutes les métriques up
    - '{__name__=~"node_.*"}'    # Métriques Node Exporter
    - '{__name__=~"http_.*"}'    # Métriques HTTP
    - '{__name__=~"app_.*"}'     # Métriques custom
    - 'ALERTS{alertstate="firing"}' # Alertes actives
```

### Prometheus Edge

**Fichier** : `prometheus-edge.yml`

**Points clés** :
- Collecte locale standard
- Règles d'agrégation activées
- Labels `external_labels` pour identifier le site

**Labels externes** :
```yaml
external_labels:
  site: 'site1'
  datacenter: 'dc1'
  region: 'eu-west-1'
  role: 'edge-collector'
```

## Déploiement

### Option 1 : Docker Compose (Recommandé)

```bash
# Utiliser la configuration fédération
cd monitoring
docker compose -f docker-compose-federation.yml up -d
```

**Services démarrés** :
- Prometheus Central (port 9090)
- Prometheus Site 1 (port 9091)
- Grafana (port 3000) - connecté au Central
- Alertmanager (port 9093)
- cAdvisor (port 8080)

### Option 2 : Déploiement Séparé

#### Site 1 (Edge)
```bash
# Démarrer Prometheus Edge sur Site 1
docker run -d \
  --name prometheus-site1 \
  -p 9091:9090 \
  -v $(pwd)/prometheus/prometheus-edge.yml:/etc/prometheus/prometheus.yml:ro \
  -v $(pwd)/prometheus/rules:/etc/prometheus/rules:ro \
  -v $(pwd)/prometheus/alerts:/etc/prometheus/alerts:ro \
  -v $(pwd)/prometheus/targets:/etc/prometheus/targets:ro \
  prom/prometheus:latest \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.retention.time=15d
```

#### Central (Hub)
```bash
# Démarrer Prometheus Central
docker run -d \
  --name prometheus-central \
  -p 9090:9090 \
  -v $(pwd)/prometheus/prometheus-central.yml:/etc/prometheus/prometheus.yml:ro \
  -v $(pwd)/prometheus/alerts/federation.yml:/etc/prometheus/alerts/federation.yml:ro \
  prom/prometheus:latest \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.retention.time=90d
```

### Vérification

```bash
# Prometheus Central
curl http://localhost:9090/-/healthy

# Prometheus Edge Site 1
curl http://localhost:9091/-/healthy

# Vérifier les targets fédérés
curl http://localhost:9090/api/v1/targets | grep federate
```

## Règles d'Agrégation

### Pourquoi Agréger ?

1. **Réduire la cardinalité** - Moins de séries temporelles
2. **Optimiser la bande passante** - Moins de données à transférer
3. **Accélérer les requêtes** - Pré-calcul des métriques
4. **Faciliter les dashboards** - Métriques prêtes à l'emploi

### Règles Pré-configurées

**Fichier** : `prometheus/rules/aggregation.yml`

#### Agrégations Système
```promql
# CPU moyen par host
instance:node_cpu_utilization:avg

# Mémoire disponible en %
instance:node_memory_available:percent

# Utilisation disque en %
instance:node_filesystem_usage:percent
```

#### Agrégations par Job
```promql
# Nombre d'instances UP
job:up:count

# Taux de disponibilité
job:availability:percent
```

#### Agrégations HTTP
```promql
# Requêtes par seconde
job:http_requests:rate

# Latence P95
job:http_request_duration:p95

# Taux d'erreur
job:http_error_rate:percent
```

#### Agrégations par Site
```promql
# Instances par site
site:instances:count

# CPU moyen par site
site:cpu_utilization:avg
```

### Créer Vos Propres Règles

```yaml
# Dans prometheus/rules/custom.yml
groups:
  - name: custom_aggregations
    interval: 30s
    rules:
      - record: my_custom:metric:avg
        expr: avg by (label) (my_metric)
```

## Alertes Spécifiques

### Alertes Fédération

**Fichier** : `prometheus/alerts/federation.yml`

#### PrometheusEdgeDown
```yaml
- alert: PrometheusEdgeDown
  expr: up{job=~"federate-.*"} == 0
  for: 2m
```
**Signification** : Un Prometheus edge est inaccessible

#### FederationScrapeSlow
```yaml
- alert: FederationScrapeSlow
  expr: scrape_duration_seconds{job=~"federate-.*"} > 15
  for: 5m
```
**Signification** : Le scraping de fédération est lent (> 15s)

#### SiteHighInstancesDown
```yaml
- alert: SiteHighInstancesDown
  expr: (site:up:count / site:instances:count) < 0.8
  for: 5m
```
**Signification** : Plus de 20% des instances d'un site sont down

## Monitoring de la Fédération

### Métriques Clés

#### État de la Fédération
```promql
# Prometheus edge UP/DOWN
up{job=~"federate-.*"}

# Durée du scraping
scrape_duration_seconds{job=~"federate-.*"}

# Nombre d'échantillons
scrape_samples_scraped{job=~"federate-.*"}
```

#### Disponibilité par Site
```promql
# Taux de disponibilité
site:availability:percent

# Instances UP par site
site:up:count / site:instances:count
```

#### Performance
```promql
# CPU moyen par site
site:cpu_utilization:avg

# Mémoire moyenne par site
site:memory_available:avg
```

### Dashboards Recommandés

#### Dashboard Fédération

1. **Vue Globale**
   - Carte des sites (UP/DOWN)
   - Disponibilité globale
   - Nombre total d'instances

2. **Performance Fédération**
   - Durée de scraping par site
   - Nombre d'échantillons par site
   - Lag de fédération

3. **Par Site**
   - Disponibilité du site
   - CPU/Mémoire/Disque moyen
   - Nombre d'instances

## URLs d'Accès

| Service | URL | Description |
|---------|-----|-------------|
| **Prometheus Central** | http://localhost:9090 | Vue globale agrégée |
| **Prometheus Site 1** | http://localhost:9091 | Métriques détaillées Site 1 |
| **Grafana** | http://localhost:3000 | Visualisation (connecté au Central) |
| **Alertmanager** | http://localhost:9093 | Gestion des alertes |

## Exemples de Requêtes

### Vue Globale (Central)

```promql
# Disponibilité globale
(sum(site:up:count) / sum(site:instances:count)) * 100

# CPU moyen de tous les sites
avg(site:cpu_utilization:avg)

# Sites avec problèmes
count by (site) (up{job=~"federate-.*"} == 0)
```

### Vue par Site (Edge)

```promql
# Sur Prometheus Site 1 (9091)
# Instances locales
up{site="site1"}

# CPU détaillé
node_cpu_seconds_total{site="site1"}
```

## Dépannage

### Prometheus Edge Inaccessible

**Symptôme** : `up{job="federate-site1"} == 0`

**Vérifications** :
```bash
# Ping du Prometheus edge
curl http://prometheus-site1:9090/-/healthy

# Vérifier la connectivité réseau
docker compose exec prometheus-central ping prometheus-site1

# Logs
docker compose logs prometheus-site1
```

### Scraping Lent

**Symptôme** : `scrape_duration_seconds > 15`

**Causes** :
- Trop de métriques fédérées
- Bande passante limitée
- Prometheus edge surchargé

**Solutions** :
1. Optimiser les `match[]` dans prometheus-central.yml
2. Ajouter plus de règles d'agrégation
3. Augmenter les ressources du Prometheus edge

### Métriques Manquantes

**Vérifier** :
```bash
# Vérifier les targets sur le central
curl http://localhost:9090/api/v1/targets | grep federate

# Vérifier les métriques disponibles sur edge
curl http://localhost:9091/api/v1/label/__name__/values

# Vérifier les match[] dans la config
```

### Lag Important

**Symptôme** : Métriques avec retard > 2 minutes

**Vérifications** :
```promql
# Calculer le lag
time() - timestamp(up{job=~"federate-.*"})
```

**Solutions** :
- Réduire `scrape_interval` sur le central
- Vérifier la latence réseau
- Augmenter les ressources

## Bonnes Pratiques

### 1. Labels Externes

Toujours définir des labels pour identifier les sites :
```yaml
external_labels:
  site: 'site1'
  datacenter: 'dc1'
  region: 'eu-west-1'
```

### 2. Rétention

- **Edge** : Court terme (7-15 jours)
- **Central** : Long terme (90+ jours)

### 3. Agrégation

Pré-calculer les métriques agrégées sur les Prometheus edge :
- Réduit la charge réseau
- Accélère les requêtes
- Facilite les dashboards

### 4. Alertes

- **Alertes locales** : Sur Prometheus edge
- **Alertes globales** : Sur Prometheus central
- **Alertes fédération** : État de la fédération

### 5. Monitoring

Monitorer la fédération elle-même :
- État des Prometheus edge
- Durée de scraping
- Lag de fédération

## Évolution

### Ajouter un Nouveau Site

1. Créer un nouveau Prometheus edge :
```yaml
# docker-compose-federation.yml
prometheus-site3:
  image: prom/prometheus:latest
  ports:
    - "9093:9090"
  # ...même config que site1/site2
```

2. Ajouter dans prometheus-central.yml :
```yaml
- job_name: 'federate-site3'
  static_configs:
    - targets: ['prometheus-site3:9090']
      labels:
        site: 'site3'
```

### Migration Progressive

1. Démarrer avec 1 edge + 1 central
2. Valider la fédération
3. Ajouter progressivement les autres sites
4. Migrer les dashboards vers le central

## Ressources

- [Documentation Prometheus Federation](https://prometheus.io/docs/prometheus/latest/federation/)
- [Best Practices](https://prometheus.io/docs/practices/federation/)
- [Règles de Recording](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/)

---

**Configuration fédération prête !** 🌐

Deux Prometheus configurés : Central (hub) + Edge (collector)
