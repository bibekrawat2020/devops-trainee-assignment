#!/bin/bash
set -uo pipefail

LOG_FILE="/var/log/infra_health.log"
APP_CONTAINER="task2-docker-setup-app-1"
DISK_THRESHOLD=85

mkdir -p /var/log

CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'.' -f1)
CPU_USAGE=$((100 - CPU_IDLE))

RAM_INFO=$(free | grep Mem)
RAM_TOTAL=$(echo $RAM_INFO | awk '{print $2}')
RAM_USED=$(echo $RAM_INFO | awk '{print $3}')
RAM_USAGE_PCT=$(( 100 * RAM_USED / RAM_TOTAL ))

DISK_USAGE_PCT=$(df / | grep / | awk '{print $5}' | sed 's/%//g')
DISK_USAGE_PCT=${DISK_USAGE_PCT:-0}

echo "--- Health Check at $(date) ---"
echo "CPU Usage: ~${CPU_USAGE}% | RAM Usage: ${RAM_USAGE_PCT}% | Root Disk Usage: ${DISK_USAGE_PCT}%"

# Docker is running and verify web application container status
DOCKER_RUNNING=true
if ! systemctl is-active --quiet docker 2>/dev/null; then
    CONTAINER_RUNNING=false
    DOCKER_DOWN_MSG=" (Docker service is not running)"
else
    DOCKER_DOWN_MSG=""
    if [ "$(docker inspect -f '{{.State.Running}}' "$APP_CONTAINER" 2>/dev/null)" = "true" ]; then
        CONTAINER_RUNNING=true
    else
        CONTAINER_RUNNING=false
    fi
fi

# Conditions (Disk usage > 85% or application container stopped)
TRIGGER_WARNING=false
WARNING_MSG=""

if [ "$DISK_USAGE_PCT" -gt "$DISK_THRESHOLD" ]; then
    TRIGGER_WARNING=true
    WARNING_MSG="[WARNING] Root disk usage has exceeded ${DISK_THRESHOLD}% (Current: ${DISK_USAGE_PCT}%)."
fi

if [ "$CONTAINER_RUNNING" = false ]; then
    TRIGGER_WARNING=true
    if [ -n "$WARNING_MSG" ]; then
        WARNING_MSG="$WARNING_MSG | [WARNING] Application container '$APP_CONTAINER' is stopped or Docker is down."
    else
        WARNING_MSG="[WARNING] Application container '$APP_CONTAINER' is stopped or Docker is down."
    fi
fi

# Alerts
if [ "$TRIGGER_WARNING" = true ]; then
    echo "$WARNING_MSG"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $WARNING_MSG" >> "$LOG_FILE"
fi
