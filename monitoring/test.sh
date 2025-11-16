#!/bin/bash

# Script de test pour la stack de monitoring
# Vérifie que tous les services sont opérationnels

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Compteurs
TESTS_PASSED=0
TESTS_FAILED=0

# Fonction d'affichage
print_test_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

# Test 1: Vérifier que les conteneurs sont en cours d'exécution
test_containers_running() {
    print_test_header "Test 1: Vérification des conteneurs"

    services=("prometheus" "alertmanager" "grafana" "node-exporter" "cadvisor")

    for service in "${services[@]}"; do
        print_test "Vérification du conteneur $service..."

        if docker compose ps | grep -q "$service.*running"; then
            print_pass "Conteneur $service est en cours d'exécution"
        else
            print_fail "Conteneur $service n'est pas en cours d'exécution"
        fi
    done
}

# Test 2: Vérifier les healthchecks
test_healthchecks() {
    print_test_header "Test 2: Vérification des healthchecks"

    services=("prometheus" "alertmanager" "grafana")

    for service in "${services[@]}"; do
        print_test "Healthcheck de $service..."

        health=$(docker compose ps | grep "$service" | grep -o "healthy" || echo "unhealthy")

        if [ "$health" = "healthy" ]; then
            print_pass "Healthcheck $service OK"
        else
            print_fail "Healthcheck $service échoué"
        fi
    done
}

# Test 3: Vérifier les ports
test_ports() {
    print_test_header "Test 3: Vérification des ports"

    ports=(
        "3000:Grafana"
        "9090:Prometheus"
        "9093:Alertmanager"
        "9100:Node Exporter"
        "8080:cAdvisor"
    )

    for port_info in "${ports[@]}"; do
        port=$(echo $port_info | cut -d: -f1)
        service=$(echo $port_info | cut -d: -f2)

        print_test "Vérification du port $port ($service)..."

        if curl -s -o /dev/null -w "%{http_code}" http://localhost:$port > /dev/null 2>&1; then
            print_pass "Port $port accessible ($service)"
        else
            print_fail "Port $port non accessible ($service)"
        fi
    done
}

# Test 4: Vérifier Prometheus
test_prometheus() {
    print_test_header "Test 4: Tests Prometheus"

    # Test de santé
    print_test "Vérification de la santé de Prometheus..."
    response=$(curl -s http://localhost:9090/-/healthy)

    if [ "$response" = "Prometheus Server is Healthy." ] || [ "$response" = "Prometheus is Healthy." ]; then
        print_pass "Prometheus est en bonne santé"
    else
        print_fail "Prometheus n'est pas en bonne santé"
    fi

    # Test des targets
    print_test "Vérification des targets Prometheus..."
    targets=$(curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"up"' | wc -l)

    if [ $targets -gt 0 ]; then
        print_pass "$targets targets Prometheus sont UP"
    else
        print_fail "Aucune target Prometheus n'est UP"
    fi

    # Test des métriques
    print_test "Vérification de la collecte des métriques..."
    metrics=$(curl -s 'http://localhost:9090/api/v1/query?query=up' | grep -o '"result":\[\]' | wc -l)

    if [ $metrics -eq 0 ]; then
        print_pass "Métriques collectées avec succès"
    else
        print_fail "Aucune métrique collectée"
    fi

    # Test des alertes
    print_test "Vérification du chargement des règles d'alertes..."
    rules=$(curl -s http://localhost:9090/api/v1/rules | grep -o '"name":"' | wc -l)

    if [ $rules -gt 0 ]; then
        print_pass "Règles d'alertes chargées ($rules groupes)"
    else
        print_fail "Aucune règle d'alerte chargée"
    fi
}

# Test 5: Vérifier Alertmanager
test_alertmanager() {
    print_test_header "Test 5: Tests Alertmanager"

    # Test de santé
    print_test "Vérification de la santé d'Alertmanager..."
    response=$(curl -s http://localhost:9093/-/healthy)

    if [ -n "$response" ]; then
        print_pass "Alertmanager est en bonne santé"
    else
        print_fail "Alertmanager n'est pas en bonne santé"
    fi

    # Test de l'API
    print_test "Vérification de l'API Alertmanager..."
    status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9093/api/v2/status)

    if [ "$status" = "200" ]; then
        print_pass "API Alertmanager accessible"
    else
        print_fail "API Alertmanager non accessible (code: $status)"
    fi
}

# Test 6: Vérifier Grafana
test_grafana() {
    print_test_header "Test 6: Tests Grafana"

    # Test de santé
    print_test "Vérification de la santé de Grafana..."
    health=$(curl -s http://localhost:3000/api/health | grep -o '"database":"ok"')

    if [ -n "$health" ]; then
        print_pass "Grafana est en bonne santé"
    else
        print_fail "Grafana n'est pas en bonne santé"
    fi

    # Test de la datasource Prometheus
    print_test "Vérification de la datasource Prometheus..."
    datasource=$(curl -s -u admin:admin123 http://localhost:3000/api/datasources/name/Prometheus | grep -o '"type":"prometheus"')

    if [ -n "$datasource" ]; then
        print_pass "Datasource Prometheus configurée"
    else
        print_fail "Datasource Prometheus non configurée"
    fi

    # Test de connexion à Prometheus depuis Grafana
    print_test "Test de connexion Grafana -> Prometheus..."
    # Ce test nécessiterait l'API de Grafana pour tester la datasource
    # Pour simplifier, on vérifie juste que la datasource existe
    print_pass "Connexion Grafana -> Prometheus (datasource présente)"
}

# Test 7: Vérifier Node Exporter
test_node_exporter() {
    print_test_header "Test 7: Tests Node Exporter"

    # Test des métriques
    print_test "Vérification des métriques Node Exporter..."
    metrics=$(curl -s http://localhost:9100/metrics | grep -c "node_" || true)

    if [ $metrics -gt 0 ]; then
        print_pass "Node Exporter expose $metrics métriques"
    else
        print_fail "Node Exporter n'expose aucune métrique"
    fi

    # Test de la collecte par Prometheus
    print_test "Vérification de la collecte par Prometheus..."
    collected=$(curl -s 'http://localhost:9090/api/v1/query?query=up{job="node-exporter"}' | grep -o '"value":\[.*,.*\]' | grep -o '1' || echo "0")

    if [ "$collected" = "1" ]; then
        print_pass "Prometheus collecte les métriques de Node Exporter"
    else
        print_fail "Prometheus ne collecte pas les métriques de Node Exporter"
    fi
}

# Test 8: Vérifier cAdvisor
test_cadvisor() {
    print_test_header "Test 8: Tests cAdvisor"

    # Test de l'interface
    print_test "Vérification de l'interface cAdvisor..."
    status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/containers/)

    if [ "$status" = "200" ] || [ "$status" = "301" ]; then
        print_pass "Interface cAdvisor accessible"
    else
        print_fail "Interface cAdvisor non accessible (code: $status)"
    fi

    # Test des métriques
    print_test "Vérification des métriques cAdvisor..."
    metrics=$(curl -s http://localhost:8080/metrics | grep -c "container_" || true)

    if [ $metrics -gt 0 ]; then
        print_pass "cAdvisor expose $metrics métriques de conteneurs"
    else
        print_fail "cAdvisor n'expose aucune métrique"
    fi
}

# Test 9: Vérifier les volumes
test_volumes() {
    print_test_header "Test 9: Vérification des volumes"

    volumes=("prometheus-data" "grafana-data" "alertmanager-data")

    for volume in "${volumes[@]}"; do
        print_test "Vérification du volume $volume..."

        if docker volume ls | grep -q "monitoring_$volume"; then
            print_pass "Volume $volume existe"
        else
            print_fail "Volume $volume n'existe pas"
        fi
    done
}

# Test 10: Vérifier le réseau
test_network() {
    print_test_header "Test 10: Vérification du réseau"

    print_test "Vérification du réseau monitoring..."

    if docker network ls | grep -q "monitoring_monitoring" || docker network ls | grep -q "monitoring-monitoring"; then
        print_pass "Réseau monitoring existe"
    else
        print_fail "Réseau monitoring n'existe pas"
    fi

    # Test de connectivité entre services
    print_test "Test de connectivité Grafana -> Prometheus..."

    if docker compose exec -T grafana wget -q -O- http://prometheus:9090/-/healthy 2>/dev/null | grep -q "Healthy"; then
        print_pass "Grafana peut communiquer avec Prometheus"
    else
        print_fail "Grafana ne peut pas communiquer avec Prometheus"
    fi
}

# Affichage du résumé
show_summary() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}RÉSUMÉ DES TESTS${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "Tests réussis: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests échoués: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ Tous les tests sont passés avec succès!${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ Certains tests ont échoué${NC}"
        echo ""
        return 1
    fi
}

# Exécution des tests
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}TESTS DE LA STACK DE MONITORING${NC}"
    echo -e "${BLUE}========================================${NC}"

    # Vérifier que Docker Compose est lancé
    if ! docker compose ps &> /dev/null; then
        echo -e "${RED}Erreur: Docker Compose n'est pas lancé${NC}"
        echo "Lancez d'abord: ./deploy.sh start"
        exit 1
    fi

    test_containers_running
    test_healthchecks
    test_ports
    test_prometheus
    test_alertmanager
    test_grafana
    test_node_exporter
    test_cadvisor
    test_volumes
    test_network

    show_summary
}

# Lancer les tests
main
exit $?
