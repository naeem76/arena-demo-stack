#!/bin/sh
set -eu
export API_BASE_URL="${API_BASE_URL:-http://localhost:18080}"
export AUTH_ISSUER_URL="${AUTH_ISSUER_URL:-$API_BASE_URL}"
envsubst '${API_BASE_URL} ${AUTH_ISSUER_URL}' < /opt/arena/config.template.json > /usr/share/nginx/html/config.json
