# Stack de Monitoring - Grafana + Prometheus + Alertmanager

> Projet de déploiement d'une stack complète de monitoring avec configuration modulaire pour une gestion facilitée de nombreux exporters.

[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=flat&logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-F46800?style=flat&logo=grafana&logoColor=white)](https://grafana.com/)

## Vue d'Ensemble

Ce projet fournit une stack complète de monitoring prête à l'emploi, avec une **configuration modulaire** optimisée pour gérer facilement de nombreux exporters et services.

### Composants

- **Prometheus 3.5 LTS** - Collecte et stockage des métriques
- **Grafana 12.0** - Visualisation et dashboards
- **Alertmanager** - Gestion des alertes et notifications
- **Node Exporter** - Métriques système (Linux)
- **cAdvisor** - Métriques des conteneurs Docker

### Fonctionnalités

✅ Configuration modulaire (fichiers séparés par catégorie)
✅ Auto-rechargement des targets (file-based service discovery)
✅ 25 alertes pré-configurées
✅ Scripts de déploiement automatisés (Linux/Windows)
✅ Documentation complète
✅ Support Docker et installation native (Debian)

## Démarrage Rapide

### Prérequis

- Docker Engine 20.10+
- Docker Compose 2.0+
- 2 GB RAM minimum
- 10 GB espace disque

### Installation en 30 secondes

```bash
# Cloner le dépôt
git clone https://github.com/VOTRE-USERNAME/monitoring-stack.git
cd monitoring-stack

# Démarrer la stack
cd monitoring
./deploy.sh start

# Ou sur Windows
deploy.bat start
```

Accédez à **Grafana** : http://localhost:3000 (admin/admin123)

## Structure du Projet

```
.
├── monitoring/                         # Stack de monitoring
│   ├── docker-compose.yml              # Configuration Docker
│   ├── deploy.sh / deploy.bat          # Scripts de déploiement
│   ├── test.sh                         # Tests automatiques
│   │
│   ├── prometheus/                     # Configuration Prometheus
│   │   ├── prometheus.yml              # Config principale
│   │   ├── alerts/                     # 📂 Alertes par catégorie
│   │   │   ├── availability.yml        # Disponibilité (3 alertes)
│   │   │   ├── resources.yml           # Ressources (7 alertes)
│   │   │   ├── prometheus.yml          # Prometheus (5 alertes)
│   │   │   ├── containers.yml          # Conteneurs (4 alertes)
│   │   │   └── databases.yml           # Bases de données (6 alertes)
│   │   │
│   │   └── targets/                    # 📂 Targets (auto-rechargement)
│   │       ├── monitoring-stack.yml    # Stack de monitoring
│   │       ├── exporters.yml           # Exporters de métriques
│   │       ├── hosts.yml               # Serveurs à surveiller
│   │       ├── applications.yml        # Applications métier
│   │       └── databases.yml           # Exporters de BDD
│   │
│   ├── alertmanager/                   # Configuration Alertmanager
│   │   └── alertmanager.yml            # Routage des alertes
│   │
│   └── grafana/                        # Configuration Grafana
│       └── provisioning/               # Auto-provisioning
│           ├── datasources/            # Datasources
│           └── dashboards/             # Dashboards
│
├── deploiement-monitoring-docker.md    # Guide Docker complet (70+ pages)
├── deploiement-monitoring-debian.md    # Guide Debian natif (50+ pages)
└── DEMARRAGE-RAPIDE.md                 # Guide de démarrage rapide
```

## Configuration Modulaire

### Avantages de la Structure

Cette stack utilise une **architecture modulaire** pour faciliter la maintenance :

- **Fichiers de targets séparés** - Un fichier par type de service
- **Alertes par catégorie** - Organisation claire des règles
- **Auto-rechargement** - Pas besoin de redémarrer Prometheus
- **Scalable** - Supporte des dizaines d'exporters facilement

### Ajouter un Nouveau Host

```yaml
# Éditer: monitoring/prometheus/targets/hosts.yml
- targets: ['my-server:9100']
  labels:
    job: 'web-servers'
    env: 'production'
    datacenter: 'dc1'
```

⏱️ Auto-rechargé en ~1 minute

### Ajouter un Exporter

```yaml
# Éditer: monitoring/prometheus/targets/exporters.yml
- targets: ['postgres-exporter:9187']
  labels:
    job: 'postgresql'
    type: 'database'
```

⏱️ Auto-rechargé en ~30 secondes

## URLs d'Accès

| Service | URL | Identifiants |
|---------|-----|--------------|
| **Grafana** | http://localhost:3000 | admin / admin123 |
| **Prometheus** | http://localhost:9090 | - |
| **Alertmanager** | http://localhost:9093 | - |
| **Node Exporter** | http://localhost:9100/metrics | - |
| **cAdvisor** | http://localhost:8080 | - |

## Commandes Essentielles

### Gestion de la Stack

```bash
# Démarrer tous les services
./deploy.sh start

# Arrêter tous les services
./deploy.sh stop

# Voir le statut
./deploy.sh status

# Voir les logs
./deploy.sh logs

# Afficher les URLs
./deploy.sh urls

# Tester l'installation
./test.sh

# Sauvegarder les données
./deploy.sh backup
```

### Docker Compose Direct

```bash
# Démarrer
docker compose up -d

# Voir le statut
docker compose ps

# Voir les logs
docker compose logs -f

# Arrêter
docker compose down
```

## Alertes Pré-configurées

### 25 Alertes Organisées par Catégorie

#### Disponibilité (3 alertes)
- InstanceDown - Service inaccessible > 2 min
- CriticalServiceDown - Service critique down
- MultipleInstancesDown - Plusieurs instances down

#### Ressources Système (7 alertes)
- HighCPUUsage / CriticalCPUUsage
- HighMemoryUsage / CriticalMemoryUsage
- DiskSpaceLow / CriticalDiskSpace
- HighLoadAverage

#### Prometheus (5 alertes)
- PrometheusTargetDown
- PrometheusHighRejectedSamples
- PrometheusTSDBFull
- PrometheusSlowScrape
- PrometheusConfigReloadFailed

#### Conteneurs (4 alertes)
- ContainerHighCPU / ContainerHighMemory
- ContainerFrequentRestarts / ContainerDown

#### Bases de Données (6 alertes)
- PostgreSQL, MySQL, Redis, MongoDB

## Documentation

### Guides Disponibles

- **[DEMARRAGE-RAPIDE.md](DEMARRAGE-RAPIDE.md)** - Installation en 30 secondes
- **[monitoring/README.md](monitoring/README.md)** - Guide utilisateur complet
- **[monitoring/QUICK-REFERENCE.md](monitoring/QUICK-REFERENCE.md)** - Référence rapide
- **[monitoring/STRUCTURE-MODULAIRE.md](monitoring/STRUCTURE-MODULAIRE.md)** - Configuration modulaire
- **[monitoring/prometheus/README.md](monitoring/prometheus/README.md)** - Documentation Prometheus
- **[deploiement-monitoring-docker.md](deploiement-monitoring-docker.md)** - Guide Docker détaillé
- **[deploiement-monitoring-debian.md](deploiement-monitoring-debian.md)** - Installation Debian native

### Support Windows

- **[monitoring/WINDOWS-DEPLOYMENT.md](monitoring/WINDOWS-DEPLOYMENT.md)** - Déploiement Windows
- Script batch inclus : `deploy.bat`

## Exemples d'Usage

### Monitoring Multi-Environnements

```yaml
# Production
- targets: ['prod-web-01:9100', 'prod-web-02:9100']
  labels:
    job: 'web-servers'
    env: 'production'

# Staging
- targets: ['staging-web-01:9100']
  labels:
    job: 'web-servers'
    env: 'staging'
```

### Monitoring de Microservices

```yaml
- targets: ['user-service:8081', 'auth-service:8082', 'payment-service:8083']
  labels:
    job: 'microservices'
    team: 'backend'
    env: 'production'
```

### Monitoring de Bases de Données

```yaml
- targets: ['postgres-exporter:9187']
  labels:
    job: 'postgresql'
    instance: 'postgres-prod-01'

- targets: ['mysql-exporter:9104']
  labels:
    job: 'mysql'
    instance: 'mysql-prod-01'
```

## Configuration Avancée

### Modifier les Alertes

Les alertes sont organisées par catégorie dans `monitoring/prometheus/alerts/` :

```bash
# Éditer une catégorie d'alertes
vim monitoring/prometheus/alerts/resources.yml

# Recharger Prometheus
curl -X POST http://localhost:9090/-/reload
```

### Configurer les Notifications

Éditez `monitoring/alertmanager/alertmanager.yml` pour configurer :
- Email (SMTP)
- Slack
- PagerDuty
- Microsoft Teams
- Webhooks

### Dashboards Grafana

Dashboards recommandés (à importer) :

| Dashboard | ID | Description |
|-----------|----|----|
| Node Exporter Full | 1860 | Métriques système complètes |
| Docker Container & Host | 10619 | Métriques conteneurs |
| Prometheus Stats | 2 | Statistiques Prometheus |

## Sécurité

### Recommandations pour la Production

⚠️ **Avant de déployer en production :**

1. Changez **tous** les mots de passe par défaut
2. Configurez **HTTPS** avec certificats SSL
3. Restreignez l'accès par **IP**
4. Activez **l'authentification** sur Prometheus
5. Configurez des **sauvegardes automatiques**

## Tests

### Script de Test Automatique

```bash
cd monitoring
./test.sh
```

Le script vérifie :
- ✅ Conteneurs en cours d'exécution
- ✅ Healthchecks
- ✅ Connectivité des services
- ✅ Collecte de métriques
- ✅ Chargement des alertes

## Dépannage

### Problèmes Courants

#### Port déjà utilisé
```bash
# Trouver le processus
lsof -i :3000

# Changer le port dans docker-compose.yml
ports:
  - "3001:3000"
```

#### Prometheus ne collecte pas
```bash
# Vérifier les targets
curl http://localhost:9090/api/v1/targets

# Voir les logs
docker compose logs prometheus
```

#### Grafana ne se connecte pas
```bash
# Tester la connexion
docker compose exec grafana wget -O- http://prometheus:9090/-/healthy
```

## Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :

1. Fork le projet
2. Créer une branche (`git checkout -b feature/amazing-feature`)
3. Commiter vos changements (`git commit -m 'Add amazing feature'`)
4. Pousser vers la branche (`git push origin feature/amazing-feature`)
5. Ouvrir une Pull Request

## Versions

- **Prometheus** : 3.5 LTS
- **Grafana** : 12.0
- **Alertmanager** : latest
- **Node Exporter** : latest
- **cAdvisor** : latest

## Licence

Ce projet est fourni à des fins éducatives et de démonstration.

## Auteur

Projet créé dans le cadre d'une analyse comparative entre Zabbix et Grafana/Prometheus pour le monitoring d'entreprise.

## Ressources

### Documentation Officielle

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)

### Outils Utiles

- [PromQL Tutorial](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [PromLens](https://promlens.com/) - Constructeur de requêtes PromQL

---

**Bon monitoring !** 📊🚀

Pour commencer : `cd monitoring && ./deploy.sh start`
