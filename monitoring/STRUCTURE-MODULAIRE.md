# Structure Modulaire Prometheus - Guide de Mise en Place

## Vue d'Ensemble

La configuration Prometheus a été **restructurée de manière modulaire** pour faciliter la gestion de nombreux exporters et alertes.

## Structure Créée

```
monitoring/prometheus/
├── prometheus.yml              # ✅ Configuration principale (mise à jour)
├── alerts.yml                  # ⚠️  Ancien fichier (compatibilité)
│
├── alerts/                     # 📁 Alertes par catégorie
│   ├── availability.yml        # Disponibilité des services
│   ├── resources.yml           # Ressources système (CPU, RAM, Disque)
│   ├── prometheus.yml          # Monitoring de Prometheus
│   ├── containers.yml          # Conteneurs Docker
│   └── databases.yml           # Bases de données
│
└── targets/                    # 📁 Targets par type (file-based SD)
    ├── monitoring-stack.yml    # Prometheus, Grafana, Alertmanager
    ├── exporters.yml           # Node Exporter, cAdvisor, etc.
    ├── hosts.yml               # Serveurs, machines
    ├── applications.yml        # APIs, microservices
    └── databases.yml           # Exporters PostgreSQL, MySQL, etc.
```

## Statut du Déploiement

### ✅ Configuration Testée

- Prometheus redémarré avec succès
- Health check : **OK** ✅
- Fichiers montés dans le conteneur Docker

### 📊 Alertes Chargées

Les alertes des fichiers modulaires sont chargées :
- `availability.yml` - Alertes de disponibilité
- `resources.yml` - Alertes ressources système
- `prometheus.yml` - Alertes Prometheus
- `containers.yml` - Alertes conteneurs
- `databases.yml` - Alertes bases de données

## Comment Utiliser

### 1. Ajouter un Nouveau Host à Surveiller

**Fichier :** `prometheus/targets/hosts.yml`

```yaml
# Ajouter ces lignes
- targets:
    - 'my-server-01:9100'
    - 'my-server-02:9100'
  labels:
    job: 'web-servers'
    env: 'production'
    datacenter: 'dc1'
    role: 'web'
```

**Rechargement :** Automatique (1 minute max)

### 2. Ajouter un Nouvel Exporter

**Fichier :** `prometheus/targets/exporters.yml`

```yaml
# Exemple: PostgreSQL Exporter
- targets:
    - 'postgres-exporter:9187'
  labels:
    job: 'postgresql-exporter'
    instance: 'postgres-prod-01'
    env: 'production'
    type: 'database'
```

**Rechargement :** Automatique (30 secondes max)

### 3. Ajouter une Application

**Fichier :** `prometheus/targets/applications.yml`

```yaml
# Exemple: API Backend
- targets:
    - 'api-backend:8080'
  labels:
    job: 'api-backend'
    env: 'production'
    team: 'backend'
    version: 'v2.1.0'
```

**Rechargement :** Automatique (30 secondes max)

### 4. Ajouter une Alerte Personnalisée

**Fichier :** Créez ou éditez un fichier dans `prometheus/alerts/`

```yaml
# prometheus/alerts/custom.yml
groups:
  - name: custom_alerts
    interval: 30s
    rules:
      - alert: MyCustomAlert
        expr: my_metric > 100
        for: 5m
        labels:
          severity: warning
          category: custom
        annotations:
          summary: "Mon alerte personnalisée"
          description: "La métrique est à {{ $value }}"
```

**Puis ajoutez dans `prometheus.yml` :**

```yaml
rule_files:
  - '/etc/prometheus/alerts/custom.yml'
```

**Rechargement :** Nécessite un reload Prometheus

```bash
curl -X POST http://localhost:9090/-/reload
# ou
docker compose restart prometheus
```

## Exemples de Cas d'Usage

### Cas 1 : Monitoring Multi-Environnement

**Fichier :** `prometheus/targets/hosts.yml`

```yaml
# Production
- targets: ['prod-web-01:9100', 'prod-web-02:9100']
  labels:
    job: 'web-servers'
    env: 'production'
    datacenter: 'dc1'

# Staging
- targets: ['staging-web-01:9100']
  labels:
    job: 'web-servers'
    env: 'staging'
    datacenter: 'dc1'

# Development
- targets: ['dev-web-01:9100']
  labels:
    job: 'web-servers'
    env: 'development'
    datacenter: 'dc2'
```

### Cas 2 : Monitoring de Plusieurs Exporters

**Fichier :** `prometheus/targets/exporters.yml`

```yaml
# Node Exporter (Linux)
- targets: ['node-exporter:9100']
  labels:
    job: 'node-exporter'
    type: 'system'

# cAdvisor (conteneurs)
- targets: ['cadvisor:8080']
  labels:
    job: 'cadvisor'
    type: 'containers'

# Blackbox Exporter (réseau)
- targets: ['blackbox-exporter:9115']
  labels:
    job: 'blackbox'
    type: 'network'

# SNMP Exporter (équipements réseau)
- targets: ['snmp-exporter:9116']
  labels:
    job: 'snmp'
    type: 'network-devices'
```

### Cas 3 : Monitoring de Microservices

**Fichier :** `prometheus/targets/applications.yml`

```yaml
# Service utilisateurs
- targets: ['user-service:8081']
  labels:
    job: 'user-service'
    team: 'backend'
    env: 'production'

# Service authentification
- targets: ['auth-service:8082']
  labels:
    job: 'auth-service'
    team: 'security'
    env: 'production'

# Service paiement
- targets: ['payment-service:8083']
  labels:
    job: 'payment-service'
    team: 'finance'
    env: 'production'
```

## Vérifications

### Vérifier les Targets Découvertes

1. **Via l'interface web :**
   - Accédez à http://localhost:9090/targets
   - Vérifiez que tous vos targets apparaissent

2. **Via l'API :**
```bash
curl http://localhost:9090/api/v1/targets
```

### Vérifier les Règles d'Alertes Chargées

1. **Via l'interface web :**
   - Accédez à http://localhost:9090/alerts
   - Vérifiez les groupes d'alertes

2. **Via l'API :**
```bash
curl http://localhost:9090/api/v1/rules
```

### Vérifier la Configuration

```bash
# Voir la configuration active
curl http://localhost:9090/api/v1/status/config
```

## Rechargement de la Configuration

### Rechargement Automatique (Targets)

Les fichiers `targets/*.yml` sont rechargés automatiquement :
- **Aucune action nécessaire**
- Délai maximum selon `refresh_interval` configuré

### Rechargement Manuel (Config / Alertes)

Pour les changements dans `prometheus.yml` ou ajout de nouveaux fichiers d'alertes :

```bash
# Méthode 1: Hot reload (sans perte de données)
curl -X POST http://localhost:9090/-/reload

# Méthode 2: Redémarrage du conteneur
docker compose restart prometheus
```

## Validation

### Avant de Recharger

Validez toujours vos fichiers :

```bash
# Valider prometheus.yml (sur Windows)
docker run --rm -v "%cd%/prometheus:/etc/prometheus" ^
  --entrypoint=promtool prom/prometheus:latest ^
  check config /etc/prometheus/prometheus.yml

# Valider les alertes
docker run --rm -v "%cd%/prometheus:/etc/prometheus" ^
  --entrypoint=promtool prom/prometheus:latest ^
  check rules /etc/prometheus/alerts/availability.yml
```

## Migration Progressive

Si vous voulez migrer progressivement :

1. ✅ **Les nouveaux fichiers sont en place**
2. ✅ **L'ancien fichier `alerts.yml` est toujours chargé** (compatibilité)
3. Vous pouvez :
   - Continuer à utiliser l'ancienne méthode
   - Migrer progressivement vers les fichiers modulaires
   - Utiliser les deux en parallèle

### Pour Finaliser la Migration

Une fois que vous avez migré toutes vos alertes vers les fichiers modulaires :

1. Commentez ou supprimez dans `prometheus.yml` :
```yaml
rule_files:
  # - '/etc/prometheus/alerts.yml'  # Ancien fichier - désactivé
```

2. Rechargez Prometheus :
```bash
curl -X POST http://localhost:9090/-/reload
```

## Avantages de cette Structure

### 1. Facilité de Maintenance

- ✅ Ajouter un host : éditer un seul fichier de targets
- ✅ Modifier une alerte : fichier dédié par catégorie
- ✅ Pas besoin de toucher à la config principale

### 2. Rechargement Automatique

- ✅ Les targets sont rechargées sans redémarrage
- ✅ Changements appliqués en 30s-1min
- ✅ Pas d'interruption de service

### 3. Organisation Claire

- ✅ Un fichier par type de service
- ✅ Facile de trouver où est configuré un élément
- ✅ Documentation intégrée

### 4. Scalabilité

- ✅ Supporte de nombreux exporters
- ✅ Peut gérer des centaines de targets
- ✅ Organisation par équipe/datacenter/environnement

### 5. Collaboration

- ✅ Chaque équipe peut gérer son fichier
- ✅ Moins de conflits Git
- ✅ Revue de code plus facile

## Bonnes Pratiques

1. **Labels cohérents :**
   - Utilisez toujours `env`, `job`, `instance`
   - Ajoutez `team`, `datacenter` si pertinent

2. **Nommage clair :**
   - Noms de jobs explicites
   - Catégories d'alertes claires

3. **Documentation :**
   - Commentez vos fichiers
   - Documentez les labels personnalisés

4. **Validation :**
   - Testez avant de déployer
   - Utilisez `promtool check`

5. **Versionnement :**
   - Committez vos changements
   - Utilisez des messages de commit clairs

## Dépannage

### Les targets ne sont pas rechargées

```bash
# Vérifier les logs
docker compose logs prometheus

# Vérifier que les fichiers sont montés
docker compose exec prometheus ls -la /etc/prometheus/targets/

# Vérifier le format YAML
cat prometheus/targets/hosts.yml
```

### Les alertes ne se déclenchent pas

```bash
# Vérifier les règles chargées
curl http://localhost:9090/api/v1/rules

# Vérifier les erreurs
docker compose logs prometheus | grep -i error

# Valider le fichier
docker run --rm -v "%cd%/prometheus:/etc/prometheus" ^
  --entrypoint=promtool prom/prometheus:latest ^
  check rules /etc/prometheus/alerts/availability.yml
```

## Ressources

- [Documentation complète](prometheus/README.md)
- [Prometheus File-based SD](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#file_sd_config)
- [Guide d'alerting](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)

---

**Structure modulaire créée et testée avec succès !** 🎯

Prête pour la gestion de nombreux exporters et une maintenance facile.
