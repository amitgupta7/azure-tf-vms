#!/usr/bin/sh
set -a && source `pwd`/.env && set +a
[ $# -eq 0 ] && { echo "Usage: $0 <sai_appliance_id>"; exit 1; }
curl -s -X 'DELETE' \
  'https://app.securiti.ai/core/v1/admin/appliance/'$1 \
  -H 'accept: application/json' \
  -H 'X-API-Secret:  '$X_API_Secret \
  -H 'X-API-Key:  '$X_API_Key \
  -H 'X-TIDENT:  '$X_TIDENT | jq 
