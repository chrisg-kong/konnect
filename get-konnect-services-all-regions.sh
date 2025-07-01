#!/usr/bin/env bash

TOKEN="<replacewithyourkonnecttoken>"
CSV_FILE="konnect_services_report.csv"

# 1) Print the main header
echo "region,control_plane_name,service_name,host,path,protocol" > "$CSV_FILE"

# 2) Define regions & their endpoints (same index order)
REGIONS=(us eu au me in)
ENDPOINTS=(
  "https://us.api.konghq.com/v2"
  "https://eu.api.konghq.com/v2"
  "https://au.api.konghq.com/v2"
  "https://me.api.konghq.com/v2"
  "https://in.api.konghq.com/v2"
)

# 3) Prepare an array to hold "region,cp_name,service_count" rows
SUMMARY_ROWS=()

# 4) Loop through each region
for i in "${!REGIONS[@]}"; do
  REGION=${REGIONS[$i]}
  ENDPOINT=${ENDPOINTS[$i]}
  echo "🔍 Scanning control planes in region: $REGION"

  # fetch control planes JSON
  CP_JSON=$(curl -s -H "Authorization: Bearer $TOKEN" \
                  "$ENDPOINT/control-planes")

  # if no .data array, skip
  if ! echo "$CP_JSON" | jq -e '.data? | type=="array"' > /dev/null; then
    echo "  ⚠️ No control planes or bad response in $REGION, skipping"
    continue
  fi

  # iterate CPs **without** a subshell so SUMMARY_ROWS persists
  while read -r cp; do
    CP_ID=$(jq -r '.id' <<<"$cp")
    CP_NAME=$(jq -r '.name' <<<"$cp")

    # fetch services for that CP
    SVC_JSON=$(curl -s -H "Authorization: Bearer $TOKEN" \
                   "$ENDPOINT/control-planes/$CP_ID/core-entities/services")

    # if no .data array, skip this CP
    if ! echo "$SVC_JSON" | jq -e '.data? | type=="array"' > /dev/null; then
      echo "    ⚠️ No services for $CP_NAME, skipping"
      continue
    fi

    # count services and record summary row
    SVC_COUNT=$(jq '.data | length' <<<"$SVC_JSON")
    SUMMARY_ROWS+=("$REGION,$CP_NAME,$SVC_COUNT")

    # append each service detail to main CSV
    jq -r --arg R "$REGION" --arg C "$CP_NAME" '
      .data[] |
      [$R, $C, .name, .host, (.path // ""), .protocol] |
      @csv
    ' <<<"$SVC_JSON" >> "$CSV_FILE"

  done < <(jq -c '.data[]' <<<"$CP_JSON")
done

# 5) Append per-control-plane summary
{
  echo
  echo "region,control_plane_name,gateway_service_count"
  for row in "${SUMMARY_ROWS[@]}"; do
    echo "$row"
  done
} >> "$CSV_FILE"

echo "✅ Services report saved to $CSV_FILE"
