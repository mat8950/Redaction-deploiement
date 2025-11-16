# 🚀 Guide de Démarrage Ultra-Rapide

## Déploiement Docker (Recommandé)

### En 30 secondes ⚡

```bash
# 1. Aller dans le dossier
cd monitoring

# 2. Tout démarrer
./deploy.sh start

# 3. Accéder à Grafana
# URL: http://localhost:3000
# User: admin / Pass: admin123
```

C'est tout ! La stack complète est déployée et fonctionnelle.

---

## 📦 Contenu du Package

### Fichiers Docker
```
monitoring/
├── docker-compose.yml          ← Configuration principale
├── deploy.sh                   ← Script de déploiement automatique
├── test.sh                     ← Script de test
├── README.md                   ← Documentation complète
├── .env.example                ← Variables d'environnement
│
├── prometheus/
│   ├── prometheus.yml         ← Configuration Prometheus
│   └── alerts.yml            ← Règles d'alertes
│
├── alertmanager/
│   └── alertmanager.yml      ← Configuration Alertmanager
│
└── grafana/
    └── provisioning/
        ├── datasources/
        │   └── prometheus.yml  ← Datasource auto
        └── dashboards/
            └── dashboard.yml   ← Config dashboards
```

### Documentation
- `deploiement-monitoring-docker.md` - Guide détaillé Docker
- `deploiement-monitoring-debian.md` - Guide installation Debian native

---

## 🎯 Commandes Essentielles

```bash
# Démarrer tout
./deploy.sh start

# Arrêter tout
./deploy.sh stop

# Voir les logs
./deploy.sh logs

# Tester l'installation
./test.sh

# Voir les URLs
./deploy.sh urls

# Sauvegarder
./deploy.sh backup
```

---

## 🌐 URLs d'Accès

| Service | URL | Identifiants |
|---------|-----|--------------|
| **Grafana** | http://localhost:3000 | admin / admin123 |
| **Prometheus** | http://localhost:9090 | - |
| **Alertmanager** | http://localhost:9093 | - |
| **Node Exporter** | http://localhost:9100/metrics | - |
| **cAdvisor** | http://localhost:8080 | - |

---

## ⚡ Installation Debian (Sans Docker)

Si vous préférez une installation native sur Debian :

```bash
# Voir le guide complet
cat deploiement-monitoring-debian.md

# En résumé :
# 1. Télécharger et installer Prometheus
# 2. Télécharger et installer Alertmanager  
# 3. Installer Grafana depuis le dépôt APT
# 4. Télécharger et installer Node Exporter
# 5. Configurer les services systemd
```

Guide complet disponible dans `deploiement-monitoring-debian.md`

---

## 📊 Que Surveiller Immédiatement ?

Les métriques suivantes sont déjà configurées :

### Système
- ✅ CPU > 80%
- ✅ Mémoire > 90%
- ✅ Disque > 90%
- ✅ Services down

### Conteneurs (si Docker)
- ✅ CPU conteneurs
- ✅ Mémoire conteneurs
- ✅ Réseau conteneurs

### Monitoring
- ✅ Prometheus targets down
- ✅ Échantillons rejetés

---

## 🔧 Configuration Rapide

### Changer le mot de passe Grafana

Éditez `docker-compose.yml`:
```yaml
environment:
  - GF_SECURITY_ADMIN_PASSWORD=VotreNouveauMDP
```

### Activer les notifications Email

Éditez `alertmanager/alertmanager.yml`:
```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alertmanager@example.com'
  smtp_auth_username: 'votre-email@gmail.com'
  smtp_auth_password: 'votre-app-password'
  smtp_require_tls: true

receivers:
  - name: 'email-alerts'
    email_configs:
      - to: 'admin@example.com'
        send_resolved: true
```

### Ajouter une target à monitorer

Éditez `prometheus/prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'mon-app'
    static_configs:
      - targets: ['mon-app:8080']
```

---

## 🔍 Vérification Rapide

```bash
# Tous les services démarrés ?
docker compose ps

# Tout fonctionne ?
./test.sh

# Voir les targets Prometheus
curl http://localhost:9090/api/v1/targets

# Tester une alerte
curl -X POST http://localhost:9093/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"Test","severity":"warning"}}]'
```

---

## 🆘 Problèmes Courants

### "Port already in use"
```bash
# Trouver ce qui utilise le port
sudo lsof -i :3000
# Ou
docker ps
```

### "Permission denied"
```bash
# Ajuster les permissions
sudo chown -R 472:472 grafana/data
sudo chown -R 65534:65534 prometheus/data alertmanager/data
```

### "Grafana ne se connecte pas à Prometheus"
```bash
# Vérifier le réseau Docker
docker network ls
docker network inspect monitoring_monitoring

# Tester la connexion
docker compose exec grafana wget -O- http://prometheus:9090/-/healthy
```

---

## 🎓 Prochaines Étapes

1. **Créer des dashboards dans Grafana**
   - Explorer les dashboards communautaires
   - Importer depuis grafana.com/dashboards

2. **Configurer les notifications**
   - Email, Slack, PagerDuty, Teams, etc.
   - Tester les alertes

3. **Ajouter vos applications**
   - Exposer des métriques `/metrics`
   - Ajouter les targets dans Prometheus

4. **Sécuriser pour la production**
   - HTTPS avec Nginx/Traefik
   - Authentification renforcée
   - Restriction par IP

---

## 📚 Documentation Complète

- **Docker**: `deploiement-monitoring-docker.md` (70+ pages)
- **Debian**: `deploiement-monitoring-debian.md` (50+ pages)
- **README**: `monitoring/README.md` (guide utilisateur)

---

## ✨ Fonctionnalités Clés

✅ Déploiement en 1 commande
✅ Configuration pré-configurée et validée
✅ Alertes prêtes à l'emploi
✅ Scripts de maintenance
✅ Tests automatiques
✅ Documentation complète
✅ Support Docker et Debian natif
✅ Métriques système et conteneurs
✅ Interface Grafana provisionnée
✅ Sauvegarde automatique

---

## 🔒 Sécurité (Production)

**⚠️ IMPORTANT: Avant la production**

1. Changez TOUS les mots de passe par défaut
2. Configurez HTTPS
3. Restreignez l'accès par IP
4. Activez l'authentification
5. Configurez les backups automatiques

Voir les guides complets pour les détails.

---

## 🤝 Support

- Documentation Docker détaillée : `deploiement-monitoring-docker.md`
- Documentation Debian détaillée : `deploiement-monitoring-debian.md`
- README du projet : `monitoring/README.md`

---

**Bon monitoring! 📊🚀**
