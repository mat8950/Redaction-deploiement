#!/bin/bash

# Script de génération de certificats auto-signés pour la stack de monitoring
# Pour la PRODUCTION, utilisez Let's Encrypt ou des certificats d'une CA

set -e

CERT_DIR="./certs"
VALIDITY_DAYS=3650  # 10 ans

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Génération des Certificats TLS ===${NC}"
echo ""

# Créer le répertoire
mkdir -p ${CERT_DIR}

# ============================================
# 1. Certificat Racine (CA)
# ============================================
echo -e "${BLUE}[1/6]${NC} Génération du certificat racine (CA)..."

openssl genrsa -out ${CERT_DIR}/ca.key 4096

openssl req -new -x509 -days ${VALIDITY_DAYS} -key ${CERT_DIR}/ca.key -out ${CERT_DIR}/ca.crt \
  -subj "/C=FR/ST=France/L=Paris/O=Monitoring/OU=Infrastructure/CN=Monitoring CA"

echo -e "${GREEN}✓${NC} CA créé"

# ============================================
# 2. Certificat Prometheus
# ============================================
echo -e "${BLUE}[2/6]${NC} Génération du certificat Prometheus..."

openssl genrsa -out ${CERT_DIR}/prometheus.key 2048

openssl req -new -key ${CERT_DIR}/prometheus.key -out ${CERT_DIR}/prometheus.csr \
  -subj "/C=FR/ST=France/L=Paris/O=Monitoring/OU=Prometheus/CN=prometheus"

# Extensions SAN
cat > ${CERT_DIR}/prometheus.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = prometheus
DNS.2 = prometheus.local
DNS.3 = localhost
IP.1 = 127.0.0.1
IP.2 = 172.20.0.10
EOF

openssl x509 -req -in ${CERT_DIR}/prometheus.csr -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key \
  -CAcreateserial -out ${CERT_DIR}/prometheus.crt -days ${VALIDITY_DAYS} \
  -extfile ${CERT_DIR}/prometheus.ext

echo -e "${GREEN}✓${NC} Certificat Prometheus créé"

# ============================================
# 3. Certificat Grafana
# ============================================
echo -e "${BLUE}[3/6]${NC} Génération du certificat Grafana..."

openssl genrsa -out ${CERT_DIR}/grafana.key 2048

openssl req -new -key ${CERT_DIR}/grafana.key -out ${CERT_DIR}/grafana.csr \
  -subj "/C=FR/ST=France/L=Paris/O=Monitoring/OU=Grafana/CN=grafana"

cat > ${CERT_DIR}/grafana.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = grafana
DNS.2 = grafana.local
DNS.3 = localhost
IP.1 = 127.0.0.1
IP.2 = 172.20.0.30
EOF

openssl x509 -req -in ${CERT_DIR}/grafana.csr -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key \
  -CAcreateserial -out ${CERT_DIR}/grafana.crt -days ${VALIDITY_DAYS} \
  -extfile ${CERT_DIR}/grafana.ext

echo -e "${GREEN}✓${NC} Certificat Grafana créé"

# ============================================
# 4. Certificat Alertmanager
# ============================================
echo -e "${BLUE}[4/6]${NC} Génération du certificat Alertmanager..."

openssl genrsa -out ${CERT_DIR}/alertmanager.key 2048

openssl req -new -key ${CERT_DIR}/alertmanager.key -out ${CERT_DIR}/alertmanager.csr \
  -subj "/C=FR/ST=France/L=Paris/O=Monitoring/OU=Alertmanager/CN=alertmanager"

cat > ${CERT_DIR}/alertmanager.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = alertmanager
DNS.2 = alertmanager.local
DNS.3 = localhost
IP.1 = 127.0.0.1
IP.2 = 172.20.0.20
EOF

openssl x509 -req -in ${CERT_DIR}/alertmanager.csr -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key \
  -CAcreateserial -out ${CERT_DIR}/alertmanager.crt -days ${VALIDITY_DAYS} \
  -extfile ${CERT_DIR}/alertmanager.ext

echo -e "${GREEN}✓${NC} Certificat Alertmanager créé"

# ============================================
# 5. Certificat Nginx (Reverse Proxy)
# ============================================
echo -e "${BLUE}[5/6]${NC} Génération du certificat Nginx..."

openssl genrsa -out ${CERT_DIR}/nginx.key 2048

openssl req -new -key ${CERT_DIR}/nginx.key -out ${CERT_DIR}/nginx.csr \
  -subj "/C=FR/ST=France/L=Paris/O=Monitoring/OU=Proxy/CN=monitoring.local"

cat > ${CERT_DIR}/nginx.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = monitoring.local
DNS.2 = prometheus.local
DNS.3 = grafana.local
DNS.4 = localhost
IP.1 = 127.0.0.1
IP.2 = 172.20.0.50
EOF

openssl x509 -req -in ${CERT_DIR}/nginx.csr -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key \
  -CAcreateserial -out ${CERT_DIR}/nginx.crt -days ${VALIDITY_DAYS} \
  -extfile ${CERT_DIR}/nginx.ext

echo -e "${GREEN}✓${NC} Certificat Nginx créé"

# ============================================
# 6. Nettoyage et permissions
# ============================================
echo -e "${BLUE}[6/6]${NC} Nettoyage et ajustement des permissions..."

# Supprimer les fichiers temporaires
rm -f ${CERT_DIR}/*.csr ${CERT_DIR}/*.ext ${CERT_DIR}/*.srl

# Permissions restrictives sur les clés privées
chmod 600 ${CERT_DIR}/*.key
chmod 644 ${CERT_DIR}/*.crt

echo -e "${GREEN}✓${NC} Nettoyage terminé"

# ============================================
# Résumé
# ============================================
echo ""
echo -e "${GREEN}=== Certificats générés avec succès! ===${NC}"
echo ""
echo "Certificats créés dans: ${CERT_DIR}/"
echo ""
echo "Fichiers:"
echo "  • ca.crt / ca.key                    - Autorité de certification"
echo "  • prometheus.crt / prometheus.key    - Prometheus"
echo "  • grafana.crt / grafana.key          - Grafana"
echo "  • alertmanager.crt / alertmanager.key - Alertmanager"
echo "  • nginx.crt / nginx.key              - Nginx (reverse proxy)"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT:${NC}"
echo "  • Ces certificats sont AUTO-SIGNÉS (pour DEV/TEST uniquement)"
echo "  • Pour la PRODUCTION, utilisez Let's Encrypt ou une CA reconnue"
echo "  • Ajoutez ca.crt dans les certificats de confiance de votre système"
echo ""
echo "Pour installer le CA:"
echo "  Linux:   sudo cp ${CERT_DIR}/ca.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates"
echo "  macOS:   sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ${CERT_DIR}/ca.crt"
echo "  Windows: Importer ca.crt dans 'Autorités de certification racines de confiance'"
echo ""

# Afficher les infos des certificats
echo "Vérification des certificats:"
echo ""
for cert in prometheus grafana alertmanager nginx; do
    echo -e "${BLUE}${cert}:${NC}"
    openssl x509 -in ${CERT_DIR}/${cert}.crt -noout -subject -dates -ext subjectAltName | sed 's/^/  /'
    echo ""
done
