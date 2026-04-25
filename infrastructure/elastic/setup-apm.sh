#!/bin/bash
set -e

echo "[setup-apm.sh] starting"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

: "${ELASTICSEARCH_USERNAME:?ELASTICSEARCH_USERNAME is required}"
: "${ELASTICSEARCH_PASSWORD:?ELASTICSEARCH_PASSWORD is required}"

# optional envs with defaults
# KIBANA_HOST="${KIBANA_HOST:-http://localhost:5601}"
KIBANA_HOST="http://localhost:5601"
SERVER_BASEPATH="${SERVER_BASEPATH:-}"
ELASTIC_VERSION="${ELASTIC_VERSION:-8.13.0}"

KIBANA_WAIT_ATTEMPTS="${KIBANA_WAIT_ATTEMPTS:-120}"
FLEET_SETUP_ATTEMPTS="${FLEET_SETUP_ATTEMPTS:-60}"
APM_PACKAGE_ATTEMPTS="${APM_PACKAGE_ATTEMPTS:-60}"

CURL_MAX_TIME="${CURL_MAX_TIME:-10}"
CURL_CONNECT_TIMEOUT="${CURL_CONNECT_TIMEOUT:-5}"

KIBANA_URL="${KIBANA_HOST}${SERVER_BASEPATH}"
KIBANA_AUTH="${ELASTICSEARCH_USERNAME}:${ELASTICSEARCH_PASSWORD}"
ES_AUTH="${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}"

echo "[setup-apm.sh] Kibana URL: ${KIBANA_URL}"

# run kibana
/usr/local/bin/kibana-docker &
KIBANA_PID=$!

echo "[setup-apm.sh] waiting for Kibana readiness"

for i in $(seq 1 "$KIBANA_WAIT_ATTEMPTS"); do
  status_code=$(curl -s -o /dev/null -w "%{http_code}" \
  -u "$KIBANA_AUTH" \
  "${KIBANA_URL}/api/status" \
  --max-time "$CURL_MAX_TIME" \
  --connect-timeout "$CURL_CONNECT_TIMEOUT" || echo "000")

  if [ "$status_code" = "200" ]; then
    echo "[setup-apm.sh] Kibana is ready on attempt ${i}/${KIBANA_WAIT_ATTEMPTS}"
    break
  fi

  echo "[setup-apm.sh] waiting for Kibana, HTTP ${status_code} (attempt ${i}/${KIBANA_WAIT_ATTEMPTS})"

  if [ "$i" -eq "$KIBANA_WAIT_ATTEMPTS" ]; then
    echo "[setup-apm.sh] Kibana not ready in time"
    exit 1
  fi

  sleep 1
done

echo "[setup-apm.sh] Kibana ready, waiting additional 5 seconds"
sleep 5

# Fleet setup
for i in $(seq 1 "$FLEET_SETUP_ATTEMPTS"); do
  fleet_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "$ES_AUTH" \
    -X POST "${KIBANA_URL}/api/fleet/setup" \
    -H "kbn-xsrf: true" \
    --max-time 20 \
    --connect-timeout "$CURL_CONNECT_TIMEOUT")

  if [ "$fleet_code" = "200" ] || [ "$fleet_code" = "409" ]; then
    echo -e "${GREEN}[setup-apm.sh] Fleet setup done (HTTP ${fleet_code}) on attempt ${i}/${FLEET_SETUP_ATTEMPTS}${RESET}"
    break
  fi

  echo -e "${YELLOW}[setup-apm.sh] Fleet setup HTTP ${fleet_code}, retrying (attempt ${i}/${FLEET_SETUP_ATTEMPTS})${RESET}"

  if [ "$i" -eq "$FLEET_SETUP_ATTEMPTS" ]; then
    echo -e "${RED}[setup-apm.sh] Fleet setup failed${RESET}"
    exit 1
  fi

  sleep 2
done

# Install APM package
for i in $(seq 1 "$APM_PACKAGE_ATTEMPTS"); do
  pkg_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "$ES_AUTH" \
    -X POST "${KIBANA_URL}/api/fleet/epm/packages/apm/${ELASTIC_VERSION}" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d '{"force":true}' \
    --max-time 20 \
    --connect-timeout "$CURL_CONNECT_TIMEOUT")

  if [ "$pkg_code" = "200" ] || [ "$pkg_code" = "201" ] || [ "$pkg_code" = "409" ]; then
    echo "[setup-apm.sh] APM package installed (HTTP ${pkg_code}) on attempt ${i}/${APM_PACKAGE_ATTEMPTS}"
    break
  fi

  echo "[setup-apm.sh] APM package HTTP ${pkg_code}, retrying (attempt ${i}/${APM_PACKAGE_ATTEMPTS})"

  if [ "$i" -eq "$APM_PACKAGE_ATTEMPTS" ]; then
    echo "[setup-apm.sh] APM package installation failed"
    exit 1
  fi

  sleep 2
done

# add apm policies
for i in $(seq 1 "$APM_PACKAGE_ATTEMPTS"); do
  pkg_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "$ES_AUTH" \
    -X POST "${KIBANA_URL}/api/fleet/epm/packages/apm/${ELASTIC_VERSION}" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d '{"force":true}' \
    --max-time 20 \
    --connect-timeout "$CURL_CONNECT_TIMEOUT")

  if [ "$pkg_code" = "200" ] || [ "$pkg_code" = "201" ] || [ "$pkg_code" = "409" ]; then
    echo "[setup-apm.sh] APM package installed (HTTP ${pkg_code}) on attempt ${i}/${APM_PACKAGE_ATTEMPTS}"
    break
  fi

  echo "[setup-apm.sh] APM package HTTP ${pkg_code}, retrying (attempt ${i}/${APM_PACKAGE_ATTEMPTS})"

  if [ "$i" -eq "$APM_PACKAGE_ATTEMPTS" ]; then
    echo "[setup-apm.sh] APM package installation failed"
    exit 1
  fi

  sleep 2
done




curl -o /dev/null -w "%{http_code}"\
  -u "$ES_AUTH" \
  -X POST "${KIBANA_URL}/api/fleet/package_policies" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "apm-1",
    "description": "APM integration",
    "namespace": "default",
    "policy_id": "YOUR_AGENT_POLICY_ID",
    "package": {
      "name": "apm",
      "version": "'"${ELASTIC_VERSION}"'"
    },
    "inputs": {
      "apm": {
        "enabled": true,
        "vars": {
          "host": {
            "value": "0.0.0.0:8200"
          }
        }
      }
    }
  }'

wait "$KIBANA_PID"