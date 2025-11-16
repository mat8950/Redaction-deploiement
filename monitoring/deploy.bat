@echo off
REM Script de deploiement pour Windows
REM Stack de monitoring Grafana + Prometheus + Alertmanager

setlocal enabledelayedexpansion

REM Couleurs (si supporte)
set "INFO=[INFO]"
set "SUCCESS=[SUCCESS]"
set "ERROR=[ERROR]"

REM Fonction principale
if "%1"=="" goto help
if "%1"=="start" goto start
if "%1"=="stop" goto stop
if "%1"=="restart" goto restart
if "%1"=="status" goto status
if "%1"=="logs" goto logs
if "%1"=="urls" goto urls
if "%1"=="validate" goto validate
if "%1"=="backup" goto backup
if "%1"=="update" goto update
if "%1"=="help" goto help
goto help

:start
echo %INFO% Verification de Docker...
docker --version >nul 2>&1
if errorlevel 1 (
    echo %ERROR% Docker n'est pas installe ou n'est pas demarre
    exit /b 1
)

echo %INFO% Creation des repertoires de donnees...
if not exist "prometheus\data" mkdir prometheus\data
if not exist "alertmanager\data" mkdir alertmanager\data
if not exist "grafana\data" mkdir grafana\data

echo %INFO% Demarrage des services...
docker compose up -d

if errorlevel 1 (
    echo %ERROR% Erreur lors du demarrage des services
    exit /b 1
)

echo.
echo %SUCCESS% Services demarres avec succes!
echo.
call :urls
goto :eof

:stop
echo %INFO% Arret des services...
docker compose down
echo %SUCCESS% Services arretes
goto :eof

:restart
echo %INFO% Redemarrage des services...
docker compose restart
echo %SUCCESS% Services redemarres
goto :eof

:status
echo %INFO% Statut des services:
docker compose ps
goto :eof

:logs
if "%2"=="" (
    docker compose logs -f
) else (
    docker compose logs -f %2
)
goto :eof

:urls
echo.
echo %INFO% URLs d'acces:
echo.
echo   Grafana:       http://localhost:3000
echo                  User: admin / Pass: admin123
echo.
echo   Prometheus:    http://localhost:9090
echo.
echo   Alertmanager:  http://localhost:9093
echo.
echo   Node Exporter: http://localhost:9100/metrics
echo.
echo   cAdvisor:      http://localhost:8080
echo.
goto :eof

:validate
echo %INFO% Validation des configurations...

echo %INFO% Validation de Prometheus...
docker run --rm -v "%cd%/prometheus:/etc/prometheus" prom/prometheus:latest promtool check config /etc/prometheus/prometheus.yml
if errorlevel 1 (
    echo %ERROR% Configuration Prometheus invalide
    exit /b 1
)
echo %SUCCESS% Configuration Prometheus valide

echo %INFO% Validation des regles d'alertes...
docker run --rm -v "%cd%/prometheus:/etc/prometheus" prom/prometheus:latest promtool check rules /etc/prometheus/alerts.yml
if errorlevel 1 (
    echo %ERROR% Regles d'alertes invalides
    exit /b 1
)
echo %SUCCESS% Regles d'alertes valides

echo %INFO% Validation d'Alertmanager...
docker run --rm -v "%cd%/alertmanager:/etc/alertmanager" prom/alertmanager:latest amtool check-config /etc/alertmanager/alertmanager.yml
if errorlevel 1 (
    echo %ERROR% Configuration Alertmanager invalide
    exit /b 1
)
echo %SUCCESS% Configuration Alertmanager valide

echo.
echo %SUCCESS% Toutes les configurations sont valides!
goto :eof

:backup
echo %INFO% Sauvegarde des donnees...

if not exist "backups" mkdir backups

for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c%%b%%a)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)
set datetime=%mydate%_%mytime%

echo %INFO% Sauvegarde de Prometheus...
docker run --rm -v monitoring_prometheus-data:/data -v "%cd%/backups:/backup" alpine tar czf /backup/prometheus_%datetime%.tar.gz -C /data .

echo %INFO% Sauvegarde de Grafana...
docker run --rm -v monitoring_grafana-data:/data -v "%cd%/backups:/backup" alpine tar czf /backup/grafana_%datetime%.tar.gz -C /data .

echo %INFO% Sauvegarde d'Alertmanager...
docker run --rm -v monitoring_alertmanager-data:/data -v "%cd%/backups:/backup" alpine tar czf /backup/alertmanager_%datetime%.tar.gz -C /data .

echo %SUCCESS% Sauvegarde terminee dans backups\
goto :eof

:update
echo %INFO% Mise a jour des images Docker...
docker compose pull
docker compose up -d
echo %SUCCESS% Images mises a jour
goto :eof

:help
echo Usage: deploy.bat [COMMAND]
echo.
echo Commandes disponibles:
echo   start       - Demarrer tous les services
echo   stop        - Arreter tous les services
echo   restart     - Redemarrer tous les services
echo   status      - Afficher le statut des services
echo   logs        - Afficher les logs
echo   urls        - Afficher les URLs d'acces
echo   validate    - Valider les configurations
echo   backup      - Sauvegarder les donnees
echo   update      - Mettre a jour les images
echo   help        - Afficher cette aide
echo.
goto :eof

:eof
