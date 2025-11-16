# Configuration Prometheus Modulaire

Cette configuration Prometheus utilise une **structure modulaire** avec des fichiers séparés pour faciliter la maintenance et l'organisation, particulièrement lorsque vous utilisez de nombreux exporters différents.

## Structure des Dossiers

```
prometheus/
├── prometheus.yml              # Configuration principale
├── alerts.yml                  # Ancien fichier d'alertes (compatibilité)
│
├── alerts/                     # Alertes par catégorie
│   ├── availability.yml        # Alertes de disponibilité (InstanceDown, etc.)
│   ├── resources.yml           # Alertes ressources (CPU, RAM, Disque)
│   ├── prometheus.yml          # Alertes pour Prometheus lui-même
│   ├── containers.yml          # Alertes pour les conteneurs Docker
│   └── databases.yml           # Alertes pour les bases de données
│
├── targets/                    # Targets à surveiller (file-based service discovery)
│   ├── monitoring-stack.yml    # Prometheus, Grafana, Alertmanager
│   ├── exporters.yml           # Node Exporter, cAdvisor, etc.
│   ├── hosts.yml               # Serveurs, machines à monitorer
│   ├── applications.yml        # Applications, APIs, microservices
│   └── databases.yml           # Exporters de bases de données
│
└── data/                       # Données TSDB (géré par Docker)
```

## Avantages de cette Structure

### 1. Séparation des Préoccupations

Chaque fichier a une responsabilité claire :
- **Alertes** : Un fichier par catégorie d'alertes
- **Targets** : Un fichier par type de service

### 2. Facilité de Maintenance

- ✅ Ajouter un nouveau host : éditer uniquement `targets/hosts.yml`
- ✅ Ajouter une alerte : éditer le fichier de la bonne catégorie
- ✅ Pas besoin de toucher à `prometheus.yml` principal

### 3. File-Based Service Discovery

Prometheus recharge automatiquement les fichiers de targets :
- Pas besoin de redémarrer Prometheus
- Les changements sont appliqués selon `refresh_interval`

### 4. Organisation Claire

Avec de nombreux exporters, vous pouvez facilement :
- Trouver où est configuré un service
- Désactiver temporairement un groupe
- Documenter chaque catégorie

## Fichiers de Targets

### Format des Fichiers

Les fichiers de targets utilisent le format **file_sd_configs** :

```yaml
# Exemple: targets/hosts.yml
- targets:
    - 'server-01:9100'
    - 'server-02:9100'
  labels:
    job: 'web-servers'
    env: 'production'
    datacenter: 'dc1'
    role: 'web'

- targets:
    - 'db-01:9100'
  labels:
    job: 'database-servers'
    env: 'production'
    datacenter: 'dc1'
    role: 'database'
```

### Fichiers Disponibles

#### 1. monitoring-stack.yml
Targets de la stack de monitoring elle-même :
- Prometheus (auto-monitoring)
- Alertmanager
- Grafana

#### 2. exporters.yml
Exporters de métriques :
- Node Exporter (Linux)
- Windows Exporter (Windows)
- cAdvisor (conteneurs Docker)
- Blackbox Exporter (monitoring réseau)

#### 3. hosts.yml
Serveurs et machines à monitorer :
- Serveurs web
- Serveurs d'applications
- Serveurs de base de données
- Serveurs de staging/dev

#### 4. applications.yml
Applications et services métier :
- APIs backend
- Frontend applications
- Microservices
- Services internes

#### 5. databases.yml
Exporters de bases de données :
- PostgreSQL Exporter
- MySQL Exporter
- MongoDB Exporter
- Redis Exporter

## Fichiers d'Alertes

### Catégories d'Alertes

#### 1. availability.yml
Alertes de disponibilité des services :
- `InstanceDown` - Service inaccessible > 2 min
- `CriticalServiceDown` - Service critique down > 1 min
- `MultipleInstancesDown` - Plusieurs instances d'un job down

#### 2. resources.yml
Alertes de ressources système :
- `HighCPUUsage` - CPU > 80% pendant 5 min
- `CriticalCPUUsage` - CPU > 95% pendant 2 min
- `HighMemoryUsage` - Mémoire > 90%
- `CriticalMemoryUsage` - Mémoire > 95%
- `DiskSpaceLow` - Disque > 90%
- `CriticalDiskSpace` - Disque > 95%
- `HighLoadAverage` - Load average élevé

#### 3. prometheus.yml
Alertes pour Prometheus lui-même :
- `PrometheusTargetDown` - Target inaccessible
- `PrometheusHighRejectedSamples` - Échantillons rejetés
- `PrometheusTSDBFull` - Stockage TSDB plein
- `PrometheusSlowScrape` - Scraping lent
- `PrometheusConfigReloadFailed` - Erreur de rechargement config

#### 4. containers.yml
Alertes pour les conteneurs Docker :
- `ContainerHighCPU` - Conteneur utilise > 80% CPU
- `ContainerHighMemory` - Conteneur utilise > 90% mémoire
- `ContainerFrequentRestarts` - Redémarrages fréquents
- `ContainerDown` - Conteneur arrêté

#### 5. databases.yml
Alertes pour les bases de données :
- PostgreSQL : connexions, réplication
- MySQL : connexions, slow queries
- Redis : mémoire
- MongoDB : connexions

## Comment Ajouter...

### Ajouter un Nouveau Host

1. Éditez `targets/hosts.yml` :

```yaml
- targets:
    - 'new-server:9100'
  labels:
    job: 'web-servers'
    env: 'production'
    datacenter: 'dc2'
    role: 'web'
```

2. Attendez le rechargement (1 minute par défaut)
3. Vérifiez dans Prometheus : Status → Targets

### Ajouter un Nouvel Exporter

1. Créez un nouveau fichier de targets (optionnel) :

```bash
# Exemple: targets/custom-exporters.yml
```

2. Ou ajoutez dans `targets/exporters.yml` :

```yaml
- targets:
    - 'nginx-exporter:9113'
  labels:
    job: 'nginx-exporter'
    instance: 'nginx-01'
    env: 'production'
```

3. Ajoutez le job dans `prometheus.yml` si nouveau fichier :

```yaml
scrape_configs:
  - job_name: 'custom-exporters'
    file_sd_configs:
      - files:
          - '/etc/prometheus/targets/custom-exporters.yml'
```

### Ajouter une Nouvelle Alerte

1. Choisissez la catégorie appropriée (ou créez-en une)
2. Éditez le fichier d'alertes correspondant :

```yaml
# alerts/custom.yml
groups:
  - name: custom_alerts
    interval: 30s
    rules:
      - alert: CustomAlert
        expr: my_metric > 100
        for: 5m
        labels:
          severity: warning
          category: custom
        annotations:
          summary: "Custom alert fired"
          description: "My metric is {{ $value }}"
```

3. Ajoutez le fichier dans `prometheus.yml` :

```yaml
rule_files:
  - '/etc/prometheus/alerts/custom.yml'
```

4. Rechargez Prometheus :

```bash
curl -X POST http://localhost:9090/-/reload
# ou
docker compose restart prometheus
```

### Créer une Nouvelle Catégorie de Targets

1. Créez le fichier :

```bash
# targets/network-devices.yml
- targets:
    - 'switch-01:9116'
    - 'router-01:9116'
  labels:
    job: 'snmp-devices'
    env: 'production'
    type: 'network'
```

2. Ajoutez le job dans `prometheus.yml` :

```yaml
scrape_configs:
  - job_name: 'network-devices'
    file_sd_configs:
      - files:
          - '/etc/prometheus/targets/network-devices.yml'
        refresh_interval: 2m
```

3. Redémarrez Prometheus pour appliquer la config principale :

```bash
docker compose restart prometheus
```

## Rechargement de la Configuration

### Rechargement Automatique (Targets)

Les fichiers de targets sont rechargés automatiquement selon `refresh_interval` :
- `monitoring-stack.yml` : 30s
- `exporters.yml` : 30s
- `hosts.yml` : 1m
- `applications.yml` : 30s
- `databases.yml` : 1m

**Aucun redémarrage nécessaire** pour les changements de targets !

### Rechargement Manuel (Config Principale)

Pour les changements dans `prometheus.yml` ou `alerts/*.yml` :

```bash
# Méthode 1: Hot reload (recommandé)
curl -X POST http://localhost:9090/-/reload

# Méthode 2: Redémarrage complet
docker compose restart prometheus
```

## Validation de la Configuration

### Valider avant le déploiement

```bash
# Valider prometheus.yml
docker run --rm -v "$(pwd):/etc/prometheus" \
  --entrypoint=promtool prom/prometheus:latest \
  check config /etc/prometheus/prometheus.yml

# Valider les alertes
docker run --rm -v "$(pwd):/etc/prometheus" \
  --entrypoint=promtool prom/prometheus:latest \
  check rules /etc/prometheus/alerts/*.yml
```

### Vérifier dans Prometheus

1. **Targets** : http://localhost:9090/targets
2. **Alertes** : http://localhost:9090/alerts
3. **Configuration** : http://localhost:9090/config

## Exemples Pratiques

### Monitoring Multi-Environnements

```yaml
# targets/hosts.yml

# Production
- targets:
    - 'prod-web-01:9100'
    - 'prod-web-02:9100'
  labels:
    job: 'web-servers'
    env: 'production'
    datacenter: 'dc1'

# Staging
- targets:
    - 'staging-web-01:9100'
  labels:
    job: 'web-servers'
    env: 'staging'
    datacenter: 'dc1'

# Development
- targets:
    - 'dev-web-01:9100'
  labels:
    job: 'web-servers'
    env: 'development'
    datacenter: 'dc2'
```

### Monitoring Multi-Datacenter

```yaml
# targets/hosts.yml

# Datacenter 1
- targets:
    - 'dc1-server-01:9100'
    - 'dc1-server-02:9100'
  labels:
    job: 'servers'
    datacenter: 'dc1'
    region: 'eu-west-1'

# Datacenter 2
- targets:
    - 'dc2-server-01:9100'
    - 'dc2-server-02:9100'
  labels:
    job: 'servers'
    datacenter: 'dc2'
    region: 'us-east-1'
```

### Monitoring par Équipe

```yaml
# targets/applications.yml

# Team Backend
- targets:
    - 'api-gateway:8080'
    - 'user-service:8081'
  labels:
    job: 'backend-services'
    team: 'backend'
    env: 'production'

# Team Frontend
- targets:
    - 'web-app:3000'
  labels:
    job: 'frontend-apps'
    team: 'frontend'
    env: 'production'

# Team Data
- targets:
    - 'data-pipeline:9200'
  labels:
    job: 'data-services'
    team: 'data'
    env: 'production'
```

## Labels Recommandés

Pour une organisation optimale, utilisez ces labels :

- `job` : Type de service (requis)
- `instance` : Nom de l'instance (auto-généré ou personnalisé)
- `env` : Environnement (production, staging, dev)
- `datacenter` / `region` : Localisation
- `team` : Équipe responsable
- `role` : Rôle du serveur (web, database, cache)
- `version` : Version de l'application

## Dépannage

### Les targets ne sont pas rechargées

```bash
# Vérifier les logs Prometheus
docker compose logs prometheus | grep -i "reload"

# Vérifier les permissions
ls -la prometheus/targets/

# Vérifier le format YAML
docker run --rm -v "$(pwd)/prometheus:/etc/prometheus" \
  alpine sh -c "cat /etc/prometheus/targets/hosts.yml"
```

### Les alertes ne se déclenchent pas

```bash
# Vérifier que les règles sont chargées
curl http://localhost:9090/api/v1/rules

# Vérifier les erreurs
docker compose logs prometheus | grep -i "error"

# Valider les fichiers d'alertes
docker run --rm -v "$(pwd)/prometheus:/etc/prometheus" \
  --entrypoint=promtool prom/prometheus:latest \
  check rules /etc/prometheus/alerts/availability.yml
```

## Migration depuis la Configuration Simple

Si vous aviez une configuration simple, voici comment migrer :

1. **Sauvegarder** l'ancienne configuration
2. **Extraire** les targets dans les fichiers appropriés
3. **Extraire** les alertes par catégorie
4. **Tester** avec `promtool check`
5. **Redémarrer** Prometheus
6. **Vérifier** que tout fonctionne

## Bonnes Pratiques

1. ✅ **Un fichier par type de service** (hosts, applications, databases)
2. ✅ **Une catégorie d'alertes par fichier**
3. ✅ **Labels cohérents** à travers tous les fichiers
4. ✅ **Documenter** les targets complexes
5. ✅ **Versionner** les fichiers de configuration (Git)
6. ✅ **Tester** avant de déployer en production
7. ✅ **Utiliser** des noms explicites pour les jobs

## Ressources

- [Prometheus File-based SD](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#file_sd_config)
- [Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [Recording Rules](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/)
- [Relabeling](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#relabel_config)

---

**Structure créée pour faciliter la gestion de nombreux exporters !** 🎯
