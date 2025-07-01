#!/bin/bash

TOKEN="<replacewithyourkonnecttoken>"
BASE_URL="https://global.api.konghq.com/v2"
CSV_FILE="konnect_services_report.csv"

echo "control_plane_id,control_plane_name,service_name,host,path,protocol" > "$CSV_FILE"

# Fetch control planes with names and IDs
CONTROL_PLANES=$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/control-planes" | jq -c '.data[]')

# Loop through each control plane
echo "$CONTROL_PLANES" | while read -r cp; do
  CP_ID=$(echo "$cp" | jq -r '.id')
  CP_NAME=$(echo "$cp" | jq -r '.name')

  SERVICES=$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/control-planes/$CP_ID/core-entities/services")

  echo "$SERVICES" | jq -r --arg CP_ID "$CP_ID" --arg CP_NAME "$CP_NAME" '
    .data[] |
    [$CP_ID, $CP_NAME, .name, .host, (.path // ""), .protocol] |
    @csv
  ' >> "$CSV_FILE"
done

echo "✅ Services report saved to $CSV_FILE"
