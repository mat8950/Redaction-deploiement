# Stack de Monitoring - Grafana + Prometheus + Alertmanager

Stack complète de monitoring basée sur Docker pour la supervision d'infrastructures et d'applications.

## Vue d'ensemble

Cette stack fournit une solution complète de monitoring incluant :

- **Prometheus** - Collecte et stockage des métriques
- **Grafana** - Visualisation et dashboards
- **Alertmanager** - Gestion des alertes et notifications
- **Node Exporter** - Métriques système (CPU, mémoire, disque, réseau)
- **cAdvisor** - Métriques des conteneurs Docker

## Démarrage rapide

### Prérequis

- Docker Engine 20.10+
- Docker Compose 2.0+
- Au moins 2 GB de RAM disponible
- 10 GB d'espace disque

### Installation en 30 secondes

```bash
# Démarrer la stack complète
./deploy.sh start

# Accéder à Grafana
# URL: http://localhost:3000
# User: admin / Pass: admin123
```

C'est tout ! La stack est opérationnelle.

## Structure du projet

```
monitoring/
├── docker-compose.yml          # Configuration Docker Compose
├── deploy.sh                   # Script de déploiement
├── test.sh                     # Script de tests
├── README.md                   # Ce fichier
│
├── prometheus/
│   ├── prometheus.yml         # Configuration Prometheus
│   ├── alerts.yml            # Règles d'alertes
│   └── data/                 # Données (volume Docker)
│
├── alertmanager/
│   ├── alertmanager.yml      # Configuration Alertmanager
│   └── data/                 # Données (volume Docker)
│
└── grafana/
    ├── provisioning/
    │   ├── datasources/
    │   │   └── prometheus.yml  # Datasource auto-provisionnée
    │   └── dashboards/
    │       └── dashboard.yml   # Configuration dashboards
    └── data/                   # Données (volume Docker)
```

## Commandes disponibles

### Script de déploiement (deploy.sh)

```bash
./deploy.sh start       # Démarrer tous les services
./deploy.sh stop        # Arrêter tous les services
./deploy.sh restart     # Redémarrer tous les services
./deploy.sh status      # Afficher le statut
./deploy.sh logs        # Afficher les logs
./deploy.sh urls        # Afficher les URLs d'accès
./deploy.sh validate    # Valider les configurations
./deploy.sh backup      # Sauvegarder les données
./deploy.sh update      # Mettre à jour les images
./deploy.sh help        # Afficher l'aide
```

### Script de test (test.sh)

```bash
./test.sh               # Exécuter tous les tests
```

Le script de test vérifie :
- Les conteneurs sont en cours d'exécution
- Les healthchecks sont OK
- Les ports sont accessibles
- Prometheus collecte les métriques
- Alertmanager est opérationnel
- Grafana est connecté à Prometheus
- Les exporters fonctionnent
- Les volumes et le réseau sont corrects

## URLs d'accès

| Service | URL | Identifiants |
|---------|-----|--------------|
| **Grafana** | http://localhost:3000 | admin / admin123 |
| **Prometheus** | http://localhost:9090 | - |
| **Alertmanager** | http://localhost:9093 | - |
| **Node Exporter** | http://localhost:9100/metrics | - |
| **cAdvisor** | http://localhost:8080 | - |

## Configuration

### Modifier le mot de passe Grafana

Éditez [docker-compose.yml](../docker-compose.yml):

```yaml
environment:
  - GF_SECURITY_ADMIN_PASSWORD=VotreNouveauMDP
```

### Ajouter une target à monitorer

Éditez [prometheus/prometheus.yml](prometheus/prometheus.yml):

```yaml
scrape_configs:
  - job_name: 'mon-application'
    static_configs:
      - targets: ['mon-app:8080']
        labels:
          app: 'mon-app'
          env: 'production'
```

Puis rechargez la configuration :

```bash
curl -X POST http://localhost:9090/-/reload
# ou
./deploy.sh restart prometheus
```

### Configurer les notifications email

Éditez [alertmanager/alertmanager.yml](alertmanager/alertmanager.yml):

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alertmanager@example.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'
  smtp_require_tls: true

receivers:
  - name: 'email-alerts'
    email_configs:
      - to: 'admin@example.com'
        send_resolved: true
```

### Ajouter des règles d'alertes

Éditez [prometheus/alerts.yml](prometheus/alerts.yml):

```yaml
groups:
  - name: custom_alerts
    interval: 30s
    rules:
      - alert: MyCustomAlert
        expr: my_metric > 100
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Description courte"
          description: "Description détaillée"
```

## Métriques et alertes pré-configurées

### Alertes système disponibles

- **InstanceDown** - Une instance est inaccessible (critique)
- **HighCPUUsage** - CPU > 80% pendant 5 min (warning)
- **HighMemoryUsage** - Mémoire > 90% pendant 5 min (warning)
- **DiskSpaceLow** - Disque > 90% pendant 5 min (warning)
- **PrometheusTargetDown** - Une target est down (critique)
- **PrometheusHighRejectedSamples** - Échantillons rejetés (warning)

### Métriques collectées

#### Système (Node Exporter)
- CPU : `node_cpu_seconds_total`
- Mémoire : `node_memory_*`
- Disque : `node_filesystem_*`
- Réseau : `node_network_*`
- Load : `node_load*`

#### Conteneurs (cAdvisor)
- CPU conteneurs : `container_cpu_*`
- Mémoire conteneurs : `container_memory_*`
- Réseau conteneurs : `container_network_*`
- I/O disque : `container_fs_*`

#### Prometheus
- Métriques internes : `prometheus_*`
- Métriques de scraping : `up`, `scrape_duration_seconds`

## Dashboards Grafana

### Importer des dashboards communautaires

1. Accédez à Grafana : http://localhost:3000
2. Menu : Dashboards > Import
3. Entrez un ID de dashboard (exemples ci-dessous)
4. Sélectionnez la datasource Prometheus
5. Cliquez sur Import

### Dashboards recommandés

| Dashboard | ID | Description |
|-----------|----|----|
| Node Exporter Full | 1860 | Métriques système complètes |
| Docker Container & Host Metrics | 10619 | Métriques des conteneurs |
| Prometheus Stats | 2 | Statistiques Prometheus |
| Alertmanager | 9578 | Monitoring Alertmanager |

## Maintenance

### Sauvegarder les données

```bash
./deploy.sh backup
```

Sauvegarde dans le dossier `backups/` :
- `prometheus_YYYYMMDD_HHMMSS.tar.gz`
- `grafana_YYYYMMDD_HHMMSS.tar.gz`
- `alertmanager_YYYYMMDD_HHMMSS.tar.gz`
- `configs_YYYYMMDD_HHMMSS.tar.gz`

### Restaurer une sauvegarde

```bash
# Arrêter les services
./deploy.sh stop

# Restaurer Prometheus
docker run --rm \
  -v monitoring_prometheus-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar xzf /backup/prometheus_20240101_120000.tar.gz -C /data

# Restaurer Grafana
docker run --rm \
  -v monitoring_grafana-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar xzf /backup/grafana_20240101_120000.tar.gz -C /data

# Redémarrer
./deploy.sh start
```

### Mettre à jour les images

```bash
./deploy.sh update
```

### Nettoyer les anciennes données

```bash
# Nettoyer les images Docker inutilisées
docker image prune -a -f

# Voir l'utilisation des volumes
docker system df -v
```

## Résolution de problèmes

### Les conteneurs ne démarrent pas

```bash
# Voir les logs
./deploy.sh logs

# Vérifier les erreurs
docker compose logs prometheus | grep -i error
docker compose logs grafana | grep -i error
```

### Prometheus ne collecte pas les métriques

```bash
# Vérifier les targets
curl http://localhost:9090/api/v1/targets

# Vérifier la configuration
./deploy.sh validate

# Redémarrer Prometheus
docker compose restart prometheus
```

### Grafana ne se connecte pas à Prometheus

```bash
# Tester la connexion depuis Grafana
docker compose exec grafana wget -O- http://prometheus:9090/-/healthy

# Vérifier la datasource
curl -u admin:admin123 http://localhost:3000/api/datasources
```

### Port déjà utilisé

```bash
# Trouver ce qui utilise le port
lsof -i :3000

# Ou modifier le port dans docker-compose.yml
ports:
  - "3001:3000"  # Utiliser le port 3001 au lieu de 3000
```

### Problèmes de permissions

```bash
# Ajuster les permissions
sudo chown -R 472:472 grafana/data
sudo chown -R 65534:65534 prometheus/data alertmanager/data
```

## Sécurité

### Recommandations pour la production

1. **Changer tous les mots de passe par défaut**
   ```yaml
   - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
   ```

2. **Activer HTTPS**
   - Utiliser un reverse proxy (Nginx, Traefik)
   - Configurer les certificats SSL/TLS

3. **Restreindre l'accès réseau**
   ```yaml
   ports:
     - "127.0.0.1:9090:9090"  # Accessible uniquement en local
   ```

4. **Activer l'authentification Prometheus**
   ```yaml
   command:
     - '--web.config.file=/etc/prometheus/web.yml'
   ```

5. **Configurer les sauvegardes automatiques**
   - Utiliser un cron job
   - Stocker les backups sur un stockage externe

6. **Limiter les ressources**
   - Les limites sont déjà configurées dans docker-compose.yml
   - Ajuster selon vos besoins

## Monitoring de la stack elle-même

```bash
# Voir l'utilisation des ressources
docker stats

# Vérifier l'espace disque des volumes
docker system df -v | grep monitoring

# Voir les métriques de Prometheus sur lui-même
curl 'http://localhost:9090/api/v1/query?query=prometheus_tsdb_storage_blocks_bytes'
```

## Ressources utiles

### Documentation officielle

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)

### Guides et tutoriels

- [PromQL Tutorial](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Alerting Best Practices](https://prometheus.io/docs/practices/alerting/)

### Outils

- [PromLens](https://promlens.com/) - Constructeur de requêtes PromQL
- [Prometheus Playground](https://demo.promlabs.com/) - Environnement de test

## Support et contribution

Pour plus de détails, consultez :
- [Guide de déploiement Docker complet](../deploiement-monitoring-docker.md)
- [Guide de déploiement Debian](../deploiement-monitoring-debian.md)
- [Guide de démarrage rapide](../DEMARRAGE-RAPIDE.md)

## Licence

Ce projet est fourni à des fins éducatives et de démonstration.

---

**Bon monitoring!** 📊
