#!/bin/bash

# Script de déploiement pour la stack de monitoring
# Grafana + Prometheus + Alertmanager

set -e  # Arrêter en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fonction pour vérifier les prérequis
check_prerequisites() {
    print_info "Vérification des prérequis..."

    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker n'est pas installé"
        exit 1
    fi

    # Vérifier Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose n'est pas installé"
        exit 1
    fi

    print_success "Tous les prérequis sont installés"
}

# Fonction pour créer les répertoires nécessaires
create_directories() {
    print_info "Création des répertoires de données..."

    mkdir -p prometheus/data
    mkdir -p alertmanager/data
    mkdir -p grafana/data

    print_success "Répertoires créés"
}

# Fonction pour ajuster les permissions
set_permissions() {
    print_info "Ajustement des permissions..."

    # Permissions pour Grafana (user 472)
    if [ -d "grafana/data" ]; then
        sudo chown -R 472:472 grafana/data 2>/dev/null || true
    fi

    # Permissions pour Prometheus et Alertmanager (user nobody = 65534)
    if [ -d "prometheus/data" ]; then
        sudo chown -R 65534:65534 prometheus/data 2>/dev/null || true
    fi

    if [ -d "alertmanager/data" ]; then
        sudo chown -R 65534:65534 alertmanager/data 2>/dev/null || true
    fi

    print_success "Permissions ajustées"
}

# Fonction pour valider les configurations
validate_configs() {
    print_info "Validation des configurations..."

    # Valider Prometheus
    docker run --rm -v $(pwd)/prometheus:/etc/prometheus prom/prometheus:latest \
        promtool check config /etc/prometheus/prometheus.yml &> /dev/null

    if [ $? -eq 0 ]; then
        print_success "Configuration Prometheus valide"
    else
        print_error "Configuration Prometheus invalide"
        docker run --rm -v $(pwd)/prometheus:/etc/prometheus prom/prometheus:latest \
            promtool check config /etc/prometheus/prometheus.yml
        exit 1
    fi

    # Valider les règles d'alertes
    if [ -f "prometheus/alerts.yml" ]; then
        docker run --rm -v $(pwd)/prometheus:/etc/prometheus prom/prometheus:latest \
            promtool check rules /etc/prometheus/alerts.yml &> /dev/null

        if [ $? -eq 0 ]; then
            print_success "Règles d'alertes valides"
        else
            print_error "Règles d'alertes invalides"
            docker run --rm -v $(pwd)/prometheus:/etc/prometheus prom/prometheus:latest \
                promtool check rules /etc/prometheus/alerts.yml
            exit 1
        fi
    fi

    # Valider Alertmanager
    docker run --rm -v $(pwd)/alertmanager:/etc/alertmanager prom/alertmanager:latest \
        amtool check-config /etc/alertmanager/alertmanager.yml &> /dev/null

    if [ $? -eq 0 ]; then
        print_success "Configuration Alertmanager valide"
    else
        print_error "Configuration Alertmanager invalide"
        docker run --rm -v $(pwd)/alertmanager:/etc/alertmanager prom/alertmanager:latest \
            amtool check-config /etc/alertmanager/alertmanager.yml
        exit 1
    fi
}

# Fonction pour démarrer les services
start_services() {
    print_info "Démarrage des services..."

    docker compose up -d

    print_success "Services démarrés"
}

# Fonction pour arrêter les services
stop_services() {
    print_info "Arrêt des services..."

    docker compose down

    print_success "Services arrêtés"
}

# Fonction pour redémarrer les services
restart_services() {
    print_info "Redémarrage des services..."

    docker compose restart

    print_success "Services redémarrés"
}

# Fonction pour afficher le statut
show_status() {
    print_info "Statut des services:"
    docker compose ps
}

# Fonction pour afficher les logs
show_logs() {
    if [ -n "$2" ]; then
        docker compose logs -f "$2"
    else
        docker compose logs -f
    fi
}

# Fonction pour afficher les URLs
show_urls() {
    echo ""
    print_info "URLs d'accès:"
    echo ""
    echo "  Grafana:       http://localhost:3000"
    echo "                 User: admin / Pass: admin123"
    echo ""
    echo "  Prometheus:    http://localhost:9090"
    echo ""
    echo "  Alertmanager:  http://localhost:9093"
    echo ""
    echo "  Node Exporter: http://localhost:9100/metrics"
    echo ""
    echo "  cAdvisor:      http://localhost:8080"
    echo ""
}

# Fonction pour sauvegarder les données
backup_data() {
    print_info "Sauvegarde des données..."

    BACKUP_DIR="backups"
    DATE=$(date +%Y%m%d_%H%M%S)

    mkdir -p ${BACKUP_DIR}

    # Sauvegarder les volumes Docker
    docker run --rm \
        -v monitoring_prometheus-data:/data \
        -v $(pwd)/${BACKUP_DIR}:/backup \
        alpine tar czf /backup/prometheus_${DATE}.tar.gz -C /data . 2>/dev/null || true

    docker run --rm \
        -v monitoring_grafana-data:/data \
        -v $(pwd)/${BACKUP_DIR}:/backup \
        alpine tar czf /backup/grafana_${DATE}.tar.gz -C /data . 2>/dev/null || true

    docker run --rm \
        -v monitoring_alertmanager-data:/data \
        -v $(pwd)/${BACKUP_DIR}:/backup \
        alpine tar czf /backup/alertmanager_${DATE}.tar.gz -C /data . 2>/dev/null || true

    # Sauvegarder les configurations
    tar czf ${BACKUP_DIR}/configs_${DATE}.tar.gz \
        prometheus/ alertmanager/ grafana/provisioning/ 2>/dev/null || true

    print_success "Sauvegarde terminée dans ${BACKUP_DIR}/"
}

# Fonction pour mettre à jour les images
update_images() {
    print_info "Mise à jour des images Docker..."

    docker compose pull
    docker compose up -d

    print_success "Images mises à jour"
}

# Fonction d'aide
show_help() {
    echo "Usage: ./deploy.sh [COMMAND]"
    echo ""
    echo "Commandes disponibles:"
    echo "  start       - Démarrer tous les services"
    echo "  stop        - Arrêter tous les services"
    echo "  restart     - Redémarrer tous les services"
    echo "  status      - Afficher le statut des services"
    echo "  logs [service] - Afficher les logs (optionnel: service spécifique)"
    echo "  urls        - Afficher les URLs d'accès"
    echo "  validate    - Valider les configurations"
    echo "  backup      - Sauvegarder les données"
    echo "  update      - Mettre à jour les images"
    echo "  help        - Afficher cette aide"
    echo ""
}

# Menu principal
case "${1:-help}" in
    start)
        check_prerequisites
        create_directories
        set_permissions
        validate_configs
        start_services
        echo ""
        show_urls
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$@"
        ;;
    urls)
        show_urls
        ;;
    validate)
        validate_configs
        ;;
    backup)
        backup_data
        ;;
    update)
        update_images
        ;;
    help|*)
        show_help
        ;;
esac
