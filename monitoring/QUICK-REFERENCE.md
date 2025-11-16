# Guide de Référence Rapide - Structure Modulaire

## 📋 Résumé des Fichiers Créés

### Fichiers de Targets (Auto-rechargement)

| Fichier | Description | Utilisation |
|---------|-------------|-------------|
| `targets/monitoring-stack.yml` | Prometheus, Grafana, Alertmanager | Stack de monitoring |
| `targets/exporters.yml` | Node Exporter, cAdvisor, etc. | Exporters de métriques |
| `targets/hosts.yml` | Serveurs, machines | Hosts à surveiller |
| `targets/applications.yml` | APIs, microservices | Applications métier |
| `targets/databases.yml` | PostgreSQL, MySQL, Redis, etc. | Bases de données |

### Fichiers d'Alertes (Par catégorie)

| Fichier | Alertes Incluses | Nombre |
|---------|------------------|--------|
| `alerts/availability.yml` | InstanceDown, CriticalServiceDown, MultipleInstancesDown | 3 alertes |
| `alerts/resources.yml` | CPU, Mémoire, Disque, Load Average | 7 alertes |
| `alerts/prometheus.yml` | TargetDown, TSDB, Scraping, Config | 5 alertes |
| `alerts/containers.yml` | CPU, Mémoire, Restarts, Down | 4 alertes |
| `alerts/databases.yml` | PostgreSQL, MySQL, Redis, MongoDB | 6 alertes |

**Total : 25 alertes pré-configurées** 🎯

## 🚀 Actions Rapides

### Ajouter un Nouveau Host

```yaml
# Éditer: prometheus/targets/hosts.yml
- targets: ['my-server:9100']
  labels:
    job: 'my-servers'
    env: 'production'
```
⏱️ Rechargement automatique en ~1 minute

### Ajouter un Exporter

```yaml
# Éditer: prometheus/targets/exporters.yml
- targets: ['postgres-exporter:9187']
  labels:
    job: 'postgresql'
    type: 'database'
```
⏱️ Rechargement automatique en ~30 secondes

### Ajouter une Application

```yaml
# Éditer: prometheus/targets/applications.yml
- targets: ['my-api:8080']
  labels:
    job: 'my-api'
    team: 'backend'
    env: 'production'
```
⏱️ Rechargement automatique en ~30 secondes

### Ajouter une Alerte

1. Éditer le fichier approprié dans `prometheus/alerts/`
2. Ajouter votre règle
3. Recharger :
```bash
curl -X POST http://localhost:9090/-/reload
```

## 📊 Vérifications Rapides

### Voir les Targets

```bash
# Interface web
http://localhost:9090/targets

# API
curl http://localhost:9090/api/v1/targets | grep job
```

### Voir les Alertes

```bash
# Interface web
http://localhost:9090/alerts

# API
curl http://localhost:9090/api/v1/rules
```

### Voir les Jobs Actifs

```bash
curl -s http://localhost:9090/api/v1/targets | \
  grep -o '"job":"[^"]*"' | sort -u
```

## 🔄 Intervalles de Rechargement

| Type | Fichiers | Intervalle | Action |
|------|----------|------------|--------|
| Monitoring Stack | `monitoring-stack.yml` | 30s | Automatique |
| Exporters | `exporters.yml` | 30s | Automatique |
| Hosts | `hosts.yml` | 1m | Automatique |
| Applications | `applications.yml` | 30s | Automatique |
| Databases | `databases.yml` | 1m | Automatique |
| Alertes | `alerts/*.yml` | - | Reload manuel |
| Config principale | `prometheus.yml` | - | Reload manuel |

## 🎯 Labels Recommandés

### Labels Obligatoires

- `job` : Type de service (toujours présent)
- `instance` : Nom de l'instance (auto-généré ou manuel)

### Labels Recommandés

- `env` : Environnement (production, staging, dev)
- `team` : Équipe responsable
- `datacenter` / `region` : Localisation
- `role` : Rôle (web, database, cache, etc.)
- `version` : Version de l'application

### Exemple Complet

```yaml
- targets: ['server-01:9100']
  labels:
    job: 'web-servers'           # Obligatoire
    instance: 'web-01'            # Recommandé
    env: 'production'             # Environnement
    team: 'backend'               # Équipe
    datacenter: 'dc1'             # Datacenter
    region: 'eu-west-1'           # Région
    role: 'web'                   # Rôle
```

## 📁 Structure Complète

```
prometheus/
├── prometheus.yml                      # Configuration principale
├── alerts.yml                          # Ancien (compatibilité)
│
├── alerts/                             # 📂 Alertes (25 règles)
│   ├── availability.yml                #    3 alertes
│   ├── resources.yml                   #    7 alertes
│   ├── prometheus.yml                  #    5 alertes
│   ├── containers.yml                  #    4 alertes
│   └── databases.yml                   #    6 alertes
│
├── targets/                            # 📂 Targets (5 fichiers)
│   ├── monitoring-stack.yml            #    Prometheus, Grafana
│   ├── exporters.yml                   #    Exporters système
│   ├── hosts.yml                       #    Serveurs, machines
│   ├── applications.yml                #    APIs, microservices
│   └── databases.yml                   #    BDD exporters
│
└── data/                               # 📂 Données TSDB (Docker volume)
```

## 🛠️ Commandes Utiles

### Recharger Prometheus

```bash
# Hot reload (sans perte de données)
curl -X POST http://localhost:9090/-/reload

# Redémarrage complet
docker compose restart prometheus
```

### Valider la Configuration

```bash
# Valider prometheus.yml
docker run --rm -v "$(pwd)/prometheus:/etc/prometheus" \
  --entrypoint=promtool prom/prometheus:latest \
  check config /etc/prometheus/prometheus.yml

# Valider une alerte
docker run --rm -v "$(pwd)/prometheus:/etc/prometheus" \
  --entrypoint=promtool prom/prometheus:latest \
  check rules /etc/prometheus/alerts/availability.yml
```

### Voir les Logs

```bash
# Tous les logs
docker compose logs prometheus

# Dernières 50 lignes
docker compose logs --tail=50 prometheus

# Suivre en temps réel
docker compose logs -f prometheus

# Filtrer les erreurs
docker compose logs prometheus | grep -i error
```

### Statistiques Prometheus

```bash
# Nombre de séries temporelles
curl -s http://localhost:9090/api/v1/status/tsdb | grep numSeries

# Taille des données
curl -s http://localhost:9090/api/v1/status/tsdb | grep dataSize

# Nombre de targets
curl -s http://localhost:9090/api/v1/targets | grep -c '"job"'
```

## 📝 Exemples de Requêtes PromQL

### Métriques de Base

```promql
# Tous les targets UP
up

# Targets d'un job spécifique
up{job="web-servers"}

# Targets par environnement
up{env="production"}

# Utilisation CPU
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Utilisation mémoire
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Utilisation disque
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100
```

### Requêtes Avancées

```promql
# CPU moyen par datacenter
avg by(datacenter) (rate(node_cpu_seconds_total{mode!="idle"}[5m]))

# Mémoire totale par équipe
sum by(team) (node_memory_MemTotal_bytes)

# Top 5 conteneurs par CPU
topk(5, rate(container_cpu_usage_seconds_total[5m]))

# Alertes actives
ALERTS{alertstate="firing"}
```

## 🔍 Dépannage Rapide

### Targets ne sont pas découvertes

1. Vérifier que le fichier existe dans `targets/`
2. Vérifier le format YAML (indentation !)
3. Vérifier les logs : `docker compose logs prometheus`

### Alertes ne se déclenchent pas

1. Vérifier que les règles sont chargées : http://localhost:9090/alerts
2. Vérifier l'expression PromQL
3. Vérifier le `for` (durée avant déclenchement)

### Prometheus ne redémarre pas

1. Vérifier la syntaxe : `promtool check config`
2. Vérifier les logs : `docker compose logs prometheus`
3. Vérifier les montages de volumes dans `docker-compose.yml`

## 📚 Ressources

### Documentation Créée

- [README.md complet](prometheus/README.md) - Guide détaillé
- [STRUCTURE-MODULAIRE.md](STRUCTURE-MODULAIRE.md) - Guide de mise en place
- [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Ce fichier

### Documentation Officielle

- [Prometheus Configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- [File-based Service Discovery](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#file_sd_config)
- [Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [PromQL](https://prometheus.io/docs/prometheus/latest/querying/basics/)

## ✅ Checklist de Déploiement

- [x] Structure des dossiers créée
- [x] Fichiers de targets créés (5 fichiers)
- [x] Fichiers d'alertes créés (5 fichiers, 25 alertes)
- [x] Configuration principale mise à jour
- [x] docker-compose.yml mis à jour
- [x] Prometheus redémarré et testé
- [x] Documentation complète créée

## 🎯 Prochaines Étapes

1. **Ajouter vos propres targets** dans les fichiers appropriés
2. **Personnaliser les alertes** selon vos besoins
3. **Créer des dashboards Grafana** pour visualiser
4. **Configurer Alertmanager** pour les notifications
5. **Tester les alertes** en conditions réelles

---

**Structure modulaire prête !**
Facile à maintenir, scalable, et organisée pour de nombreux exporters. 🚀
