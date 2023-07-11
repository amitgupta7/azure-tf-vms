#!/usr/bin/sh
set -a && source .env && set +a
curl -s -X 'POST' \
  'https://app.securiti.ai/core/v1/admin/appliance' \
  -H 'accept: application/json' \
  -H 'X-API-Secret:  '$X_API_Secret \
  -H 'X-API-Key:  '$X_API_Key \
  -H 'X-TIDENT:  '$X_TIDENT \
  -H 'Content-Type: application/json' \
  -d '{
  "owner": "amit.gupta@securiti.ai",
  "co_owners": [],
  "name": "localtest-'$(echo $RANDOM %10000+1 |bc)'",
  "desc": "",
  "send_notification": false
}' | jq '{appliance_name: .data.name, appliance_id: .data.id, license: .data.license}'
curl -s -X 'GET' \
  'https://app.securiti.ai/core/v1/admin/appliance/download_url' \
  -H 'accept: application/json' \
  -H 'X-API-Secret:  '$X_API_Secret \
  -H 'X-API-Key:  '$X_API_Key \
  -H 'X-TIDENT:  '$X_TIDENT | jq 
