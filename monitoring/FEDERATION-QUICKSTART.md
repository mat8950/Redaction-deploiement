# Fédération Prometheus - Guide de Démarrage Rapide

## Vue d'Ensemble Rapide

Fédération Prometheus configurée avec :
- **1 Prometheus Central** (port 9090) - Vue globale agrégée
- **1 Prometheus Edge** (port 9091) - Collecteur local Site 1
- **Règles d'agrégation** - 30+ métriques pré-calculées
- **Alertes fédération** - 7 alertes spécifiques

## Architecture

```
Prometheus CENTRAL (9090)
    │
    └─── Fédère ────> Prometheus EDGE Site 1 (9091)
                           │
                           └─── Collecte ────> Targets locaux
```

## Démarrage en 30 Secondes

```bash
cd monitoring

# Démarrer la fédération
./deploy-federation.sh start

# Tester la configuration
./deploy-federation.sh test
```

## URLs d'Accès

| Service | URL | Description |
|---------|-----|-------------|
| **Prometheus Central** | http://localhost:9090 | Vue globale agrégée |
| **Prometheus Edge** | http://localhost:9091 | Métriques locales Site 1 |
| **Grafana** | http://localhost:3000 | Connecté au Central |

## Fichiers de Configuration

| Fichier | Description |
|---------|-------------|
| `prometheus-central.yml` | Config Prometheus central (hub) |
| `prometheus-edge.yml` | Config Prometheus edge (collector) |
| `rules/aggregation.yml` | Règles d'agrégation (30+ règles) |
| `alerts/federation.yml` | Alertes spécifiques fédération |
| `docker-compose-federation.yml` | Docker Compose 2 instances |

## Métriques Agrégées Disponibles

### Système
```promql
instance:node_cpu_utilization:avg           # CPU moyen
instance:node_memory_available:percent      # Mémoire disponible %
instance:node_filesystem_usage:percent      # Disque utilisé %
```

### Par Job
```promql
job:up:count                                # Instances UP
job:availability:percent                    # Disponibilité %
```

### Par Site
```promql
site:instances:count                        # Total instances
site:up:count                               # Instances UP
site:cpu_utilization:avg                    # CPU moyen site
```

## Commandes Utiles

```bash
# Démarrer
./deploy-federation.sh start

# Voir le statut
./deploy-federation.sh status

# Tester
./deploy-federation.sh test

# Logs Prometheus Central
./deploy-federation.sh logs prometheus-central

# Logs Prometheus Edge
./deploy-federation.sh logs prometheus-site1

# Arrêter
./deploy-federation.sh stop
```

## Vérifications Rapides

### Prometheus Central collecte-t-il ?

```bash
# Vérifier les targets fédérés
curl http://localhost:9090/api/v1/targets | grep federate

# Vérifier les métriques reçues
curl 'http://localhost:9090/api/v1/query?query=up{job=~"federate-.*"}'
```

### Endpoint Fédération Accessible ?

```bash
# Tester l'endpoint /federate
curl http://localhost:9091/federate?match[]={job=%22prometheus%22}
```

### Règles d'Agrégation Actives ?

```bash
# Sur Prometheus Edge
curl http://localhost:9091/api/v1/rules | grep -o '"name":".*_aggregations"'
```

## Ajouter un Nouveau Site

1. **Copier la config edge** :
```bash
cp prometheus/prometheus-edge.yml prometheus/prometheus-site2.yml
```

2. **Modifier les labels** :
```yaml
external_labels:
  site: 'site2'          # Changer
  datacenter: 'dc2'      # Changer
```

3. **Ajouter dans docker-compose-federation.yml** :
```yaml
prometheus-site2:
  image: prom/prometheus:latest
  ports:
    - "9092:9090"
  volumes:
    - ./prometheus/prometheus-site2.yml:/etc/prometheus/prometheus.yml:ro
```

4. **Ajouter dans prometheus-central.yml** :
```yaml
- job_name: 'federate-site2'
  static_configs:
    - targets: ['prometheus-site2:9090']
      labels:
        site: 'site2'
```

## Dashboards Grafana

### Dashboard Central

**Métriques recommandées** :
```promql
# Vue globale
sum(site:up:count) / sum(site:instances:count)

# Par site
site:availability:percent

# CPU par site
site:cpu_utilization:avg
```

### Dashboard Edge

**Métriques détaillées** :
```promql
# Instances locales
up{site="site1"}

# CPU détaillé
node_cpu_seconds_total{site="site1"}
```

## Alertes Configurées

| Alerte | Condition | Sévérité |
|--------|-----------|----------|
| PrometheusEdgeDown | Edge inaccessible > 2m | Critical |
| FederationScrapeSlow | Scraping > 15s | Warning |
| SiteHighInstancesDown | > 20% instances down | Critical |
| FederationHighSampleCount | > 100k échantillons | Warning |

## Dépannage Rapide

### Edge non accessible

```bash
# Vérifier le service
docker compose -f docker-compose-federation.yml ps prometheus-site1

# Vérifier les logs
docker compose -f docker-compose-federation.yml logs prometheus-site1

# Ping depuis central
docker compose -f docker-compose-federation.yml exec prometheus-central wget -O- http://prometheus-site1:9090/-/healthy
```

### Métriques manquantes

```bash
# Vérifier les match[] dans prometheus-central.yml
# Vérifier les règles d'agrégation sur edge
curl http://localhost:9091/api/v1/rules
```

### Scraping lent

```promql
# Vérifier la durée
scrape_duration_seconds{job=~"federate-.*"}

# Nombre d'échantillons
scrape_samples_scraped{job=~"federate-.*"}
```

## Ressources

- [Documentation complète](FEDERATION.md)
- [Règles d'agrégation](prometheus/rules/aggregation.yml)
- [Alertes fédération](prometheus/alerts/federation.yml)

## Structure Complète

```
monitoring/
├── docker-compose-federation.yml      # Docker 2 Prometheus
├── deploy-federation.sh               # Script déploiement
├── FEDERATION.md                      # Doc complète
├── FEDERATION-QUICKSTART.md           # Ce fichier
│
└── prometheus/
    ├── prometheus-central.yml         # Config central
    ├── prometheus-edge.yml            # Config edge
    ├── rules/
    │   └── aggregation.yml           # 30+ règles
    └── alerts/
        └── federation.yml            # 7 alertes
```

---

**Fédération Prometheus opérationnelle !** 🌐

Pour démarrer : `./deploy-federation.sh start`
