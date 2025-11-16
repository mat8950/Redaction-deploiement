#!/bin/bash

# Script de déploiement pour la Fédération Prometheus
# 2 instances Prometheus: Central + Edge

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Fonction pour démarrer la fédération
start_federation() {
    print_info "Démarrage de la stack de fédération Prometheus..."

    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker n'est pas installé"
        exit 1
    fi

    # Créer les répertoires
    print_info "Création des répertoires de données..."
    mkdir -p prometheus/data alertmanager/data grafana/data

    # Démarrer avec le fichier federation
    print_info "Démarrage des services..."
    docker compose -f docker-compose-federation.yml up -d

    if [ $? -eq 0 ]; then
        print_success "Services démarrés avec succès!"
        echo ""
        show_urls
    else
        print_error "Erreur lors du démarrage"
        exit 1
    fi
}

# Fonction pour arrêter
stop_federation() {
    print_info "Arrêt de la fédération..."
    docker compose -f docker-compose-federation.yml down
    print_success "Services arrêtés"
}

# Fonction pour afficher le statut
show_status() {
    print_info "Statut des services:"
    docker compose -f docker-compose-federation.yml ps
}

# Fonction pour afficher les URLs
show_urls() {
    echo ""
    print_info "URLs d'accès:"
    echo ""
    echo "  Prometheus CENTRAL:    http://localhost:9090"
    echo "                         (Vue globale agrégée)"
    echo ""
    echo "  Prometheus EDGE Site1: http://localhost:9091"
    echo "                         (Métriques détaillées Site 1)"
    echo ""
    echo "  Grafana:               http://localhost:3000"
    echo "                         User: admin / Pass: admin123"
    echo "                         (Connecté au Prometheus Central)"
    echo ""
    echo "  Alertmanager:          http://localhost:9093"
    echo ""
}

# Fonction pour tester la fédération
test_federation() {
    print_info "Test de la configuration fédération..."
    echo ""

    # Test Prometheus Central
    print_info "Test Prometheus Central (9090)..."
    if curl -s http://localhost:9090/-/healthy | grep -q "Healthy"; then
        print_success "Prometheus Central OK"
    else
        print_error "Prometheus Central KO"
    fi

    # Test Prometheus Edge
    print_info "Test Prometheus Edge Site 1 (9091)..."
    if curl -s http://localhost:9091/-/healthy | grep -q "Healthy"; then
        print_success "Prometheus Edge Site 1 OK"
    else
        print_error "Prometheus Edge Site 1 KO"
    fi

    # Test fédération
    print_info "Test de l'endpoint de fédération..."
    if curl -s http://localhost:9091/federate | grep -q "up"; then
        print_success "Endpoint /federate accessible"
    else
        print_warning "Endpoint /federate non accessible ou vide"
    fi

    # Vérifier les targets fédérés
    print_info "Vérification des targets fédérés..."
    targets=$(curl -s http://localhost:9090/api/v1/targets | grep -c "federate" || true)
    if [ $targets -gt 0 ]; then
        print_success "$targets job(s) de fédération configuré(s)"
    else
        print_warning "Aucun job de fédération trouvé"
    fi

    echo ""
    print_info "Résumé:"
    docker compose -f docker-compose-federation.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
}

# Fonction pour voir les logs
show_logs() {
    if [ -n "$2" ]; then
        docker compose -f docker-compose-federation.yml logs -f "$2"
    else
        docker compose -f docker-compose-federation.yml logs -f
    fi
}

# Fonction d'aide
show_help() {
    echo "Usage: ./deploy-federation.sh [COMMAND]"
    echo ""
    echo "Commandes disponibles:"
    echo "  start       - Démarrer la stack de fédération"
    echo "  stop        - Arrêter tous les services"
    echo "  restart     - Redémarrer tous les services"
    echo "  status      - Afficher le statut des services"
    echo "  urls        - Afficher les URLs d'accès"
    echo "  test        - Tester la configuration fédération"
    echo "  logs [svc]  - Afficher les logs"
    echo "  help        - Afficher cette aide"
    echo ""
    echo "Services disponibles pour les logs:"
    echo "  prometheus-central, prometheus-site1, grafana, alertmanager"
    echo ""
}

# Menu principal
case "${1:-help}" in
    start)
        start_federation
        ;;
    stop)
        stop_federation
        ;;
    restart)
        stop_federation
        sleep 2
        start_federation
        ;;
    status)
        show_status
        ;;
    urls)
        show_urls
        ;;
    test)
        test_federation
        ;;
    logs)
        show_logs "$@"
        ;;
    help|*)
        show_help
        ;;
esac
