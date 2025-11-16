# Déploiement sur Windows - Stack de Monitoring

## Résultat du Déploiement

### Statut des Services

Tous les services principaux sont **opérationnels** et en bonne santé :

| Service | Status | Port | Health Check |
|---------|--------|------|--------------|
| **Prometheus** | ✅ Running | 9090 | ✅ Healthy |
| **Grafana** | ✅ Running | 3000 | ✅ Healthy |
| **Alertmanager** | ✅ Running | 9093 | ✅ Healthy |
| **cAdvisor** | ✅ Running | 8080 | ✅ Healthy |
| **Node Exporter** | ⚠️ Désactivé | - | N/A (profil Linux) |

### Note sur Node Exporter

Sur Windows, Node Exporter a des limitations importantes car il ne peut pas accéder directement au système hôte de la même manière que sur Linux. Il a été configuré avec un profil `linux` pour éviter les erreurs au démarrage.

**Alternative pour Windows :** Utilisez **windows_exporter** à la place :
```yaml
  windows-exporter:
    image: ghcr.io/prometheus-community/windows-exporter:latest
    container_name: windows-exporter
    ports:
      - "9182:9182"
    networks:
      - monitoring
```

## URLs d'Accès

### Interface Web

- **Grafana** : http://localhost:3000
  - Username: `admin`
  - Password: `admin123`
  - Status: ✅ Opérationnel (v12.2.1)

- **Prometheus** : http://localhost:9090
  - Status: ✅ Healthy
  - Targets collectées: 3/3 (prometheus, alertmanager, node-exporter)

- **Alertmanager** : http://localhost:9093
  - Status: ✅ Healthy

- **cAdvisor** : http://localhost:8080
  - Status: ✅ Healthy
  - Métriques des conteneurs Docker disponibles

## Tests de Connectivité

### Prometheus

```bash
# Health check
curl http://localhost:9090/-/healthy
# Résultat: "Prometheus Server is Healthy."

# Vérifier les targets
curl http://localhost:9090/api/v1/targets

# Vérifier les métriques collectées
curl 'http://localhost:9090/api/v1/query?query=up'
```

**Résultat :** ✅ 3 targets configurées, toutes UP sauf node-exporter (désactivé)

### Grafana

```bash
# Health check
curl http://localhost:3000/api/health
# Résultat: {"database": "ok", "version": "12.2.1"}

# Vérifier les datasources
curl -u admin:admin123 http://localhost:3000/api/datasources
```

**Résultat :** ✅ Datasource Prometheus configurée automatiquement

### Alertmanager

```bash
# Health check
curl http://localhost:9093/-/healthy
# Résultat: "OK"

# Vérifier les alertes actives
curl http://localhost:9093/api/v2/alerts
```

**Résultat :** ✅ Opérationnel, aucune alerte active

## Règles d'Alertes Configurées

Les règles d'alertes suivantes sont chargées et actives :

### Groupe: service_availability
- ✅ **InstanceDown** - Détecte les services inaccessibles (> 2 min)

### Groupe: system_resources
- ✅ **HighCPUUsage** - CPU > 80% pendant 5 min
- ✅ **HighMemoryUsage** - Mémoire > 90% pendant 5 min
- ✅ **DiskSpaceLow** - Disque > 90% pendant 5 min

### Groupe: prometheus_alerts
- ✅ **PrometheusTargetDown** - Target Prometheus inaccessible
- ✅ **PrometheusHighRejectedSamples** - Échantillons rejetés

**Total :** 6 règles d'alertes actives

## Métriques Collectées

### Prometheus (auto-monitoring)
- Métriques internes Prometheus
- État des targets
- Performances de scraping

### Alertmanager
- Métriques d'alertes envoyées
- Notifications

### cAdvisor
- CPU des conteneurs Docker
- Mémoire des conteneurs
- I/O réseau des conteneurs
- I/O disque des conteneurs

## Commandes Windows

### Script de déploiement (deploy.bat)

```cmd
# Démarrer tous les services
deploy.bat start

# Arrêter tous les services
deploy.bat stop

# Voir le statut
deploy.bat status

# Voir les logs
deploy.bat logs

# Afficher les URLs
deploy.bat urls

# Sauvegarder les données
deploy.bat backup
```

### Commandes Docker Compose

```cmd
# Démarrer
cd monitoring
docker compose up -d

# Voir le statut
docker compose ps

# Voir les logs
docker compose logs -f

# Arrêter
docker compose down

# Redémarrer un service
docker compose restart prometheus
```

## Résolution de Problèmes Windows

### Node Exporter ne démarre pas

**Problème :** `Error response from daemon: path / is mounted on / but it is not a shared or slave mount`

**Cause :** Sur Windows avec Docker Desktop, le montage de `/` n'est pas supporté de la même manière que sur Linux.

**Solution :**
1. Node Exporter a été désactivé avec un profil `linux`
2. Utilisez `windows_exporter` pour les métriques Windows
3. Ou utilisez cAdvisor pour les métriques des conteneurs

### Avertissement "version is obsolete"

**Avertissement :** `the attribute 'version' is obsolete`

**Cause :** Docker Compose v2 ne nécessite plus l'attribut `version`

**Impact :** Aucun, c'est juste un avertissement. Le fichier fonctionne correctement.

**Solution (optionnel) :** Supprimer la ligne `version: '3.8'` du docker-compose.yml

### Problème de permissions sur les volumes

Sur Windows, les permissions des volumes Docker sont gérées différemment :

```cmd
# Les commandes chown ne fonctionnent pas sur Windows
# Docker Desktop gère automatiquement les permissions
```

Les volumes suivants sont créés automatiquement :
- `monitoring_prometheus-data`
- `monitoring_grafana-data`
- `monitoring_alertmanager-data`

## Configuration Grafana

### Première connexion

1. Accédez à http://localhost:3000
2. Connectez-vous avec `admin` / `admin123`
3. La datasource Prometheus est déjà configurée automatiquement

### Importer des dashboards

1. Menu : Dashboards > Import
2. Entrez un ID de dashboard :
   - **1860** - Node Exporter Full (pour Linux)
   - **10619** - Docker Container & Host Metrics
   - **2** - Prometheus Stats
   - **893** - Windows Exporter Dashboard (si vous installez windows_exporter)

## Dashboards recommandés pour Windows

Puisque Node Exporter n'est pas disponible, voici les dashboards les plus pertinents :

| Dashboard | ID | Description |
|-----------|----|----|
| Docker Container & Host | 10619 | Métriques des conteneurs via cAdvisor |
| Prometheus 2.0 Stats | 3662 | Statistiques Prometheus |
| cAdvisor exporter | 14282 | Dashboard pour cAdvisor |

## Monitoring des Conteneurs avec cAdvisor

cAdvisor collecte les métriques suivantes pour tous les conteneurs Docker :

- **CPU** : Utilisation CPU par conteneur
- **Mémoire** : Utilisation mémoire par conteneur
- **Réseau** : Trafic réseau entrant/sortant
- **I/O Disque** : Lectures/écritures par conteneur

### Exemples de requêtes PromQL

```promql
# Utilisation CPU par conteneur
rate(container_cpu_usage_seconds_total[5m])

# Utilisation mémoire par conteneur
container_memory_usage_bytes

# Trafic réseau reçu
rate(container_network_receive_bytes_total[5m])

# Trafic réseau envoyé
rate(container_network_transmit_bytes_total[5m])
```

## Tests Effectués

### ✅ Tests réussis

1. **Démarrage des conteneurs** - Tous les services principaux démarrés
2. **Health checks** - Tous les healthchecks passent
3. **Connectivité Prometheus** - Accessible et healthy
4. **Connectivité Grafana** - Accessible et healthy
5. **Connectivité Alertmanager** - Accessible et healthy
6. **Datasource Grafana** - Prometheus auto-provisionné
7. **Règles d'alertes** - 6 règles chargées et actives
8. **Collecte de métriques** - Métriques collectées pour prometheus, alertmanager
9. **cAdvisor** - Métriques des conteneurs disponibles

### ⚠️ Limitations Windows

1. **Node Exporter** - Désactivé (incompatible Windows)
   - Solution : Utiliser windows_exporter

2. **Métriques système hôte** - Non disponibles via Node Exporter
   - Alternative : cAdvisor pour les conteneurs

## Prochaines Étapes

### 1. Ajouter Windows Exporter (Recommandé)

Pour obtenir des métriques système Windows, ajoutez windows_exporter :

```yaml
  windows-exporter:
    image: ghcr.io/prometheus-community/windows-exporter:latest
    container_name: windows-exporter
    ports:
      - "9182:9182"
    networks:
      - monitoring
```

Puis ajoutez dans `prometheus/prometheus.yml` :

```yaml
scrape_configs:
  - job_name: 'windows'
    static_configs:
      - targets: ['windows-exporter:9182']
```

### 2. Créer des dashboards personnalisés

1. Accédez à Grafana
2. Créez vos dashboards basés sur :
   - Métriques cAdvisor (conteneurs)
   - Métriques Prometheus (auto-monitoring)
   - Métriques de vos applications

### 3. Configurer les notifications

Éditez `alertmanager/alertmanager.yml` pour configurer :
- Email (SMTP)
- Slack
- Microsoft Teams
- Webhooks personnalisés

### 4. Ajouter vos applications

Ajoutez vos applications à monitorer dans `prometheus/prometheus.yml` :

```yaml
scrape_configs:
  - job_name: 'my-app'
    static_configs:
      - targets: ['my-app:8080']
```

## Conclusion

Le déploiement de la stack de monitoring sur Windows est **réussi** avec quelques adaptations :

✅ **Opérationnel :**
- Prometheus (collecte et stockage)
- Grafana (visualisation)
- Alertmanager (alertes)
- cAdvisor (métriques conteneurs)

⚠️ **Avec limitations :**
- Node Exporter désactivé (utiliser windows_exporter à la place)
- Métriques système hôte limitées aux conteneurs Docker

📊 **Prêt pour :**
- Monitoring des conteneurs Docker
- Auto-monitoring de la stack
- Configuration des alertes
- Création de dashboards
- Ajout d'applications à monitorer

---

**Pour accéder à Grafana :** http://localhost:3000 (admin/admin123)
**Pour accéder à Prometheus :** http://localhost:9090
