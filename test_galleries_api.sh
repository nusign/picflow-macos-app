#!/bin/bash

# API Testing Script for Galleries Endpoint
# This uses your test token from Constants.swift

# Read token and tenant from Constants.swift
TOKEN=$(grep "hardcodedToken =" Picflow/App/Constants.swift | cut -d'"' -f2)
TENANT_ID=$(grep "tenantId =" Picflow/App/Constants.swift | cut -d'"' -f2)

echo "🧪 Testing Galleries API"
echo "========================"
echo ""

# Test 1: Minimal request (what your app currently uses)
echo "📋 Test 1: Minimal Request (Current App Behavior)"
echo "---------------------------------------------------"
curl -s "https://api.picflow.io/v1/galleries" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-API-Version: 2023-01-01" \
  -H "picflow-tenant: $TENANT_ID" \
  -H "Accept: application/json" | jq '{
    total_galleries: (.data | length),
    galleries: [.data[] | {id, name: (.title // .name), path, section, folder}]
  }'

echo ""
echo ""

# Test 2: With limit
echo "📋 Test 2: With Limit=5"
echo "---------------------------------------------------"
curl -s "https://api.picflow.io/v1/galleries?limit=5" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-API-Version: 2023-01-01" \
  -H "picflow-tenant: $TENANT_ID" | jq '{
    count: (.data | length),
    names: [.data[].name // .data[].title]
  }'

echo ""
echo ""

# Test 3: With sorting by last changed
echo "📋 Test 3: Sorted by Last Changed (Recent First)"
echo "---------------------------------------------------"
curl -s "https://api.picflow.io/v1/galleries?sort[]=-last_changed_at&limit=5" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-API-Version: 2023-01-01" \
  -H "picflow-tenant: $TENANT_ID" | jq '[.data[] | {
    name: (.title // .name),
    updated_at,
    last_changed_at
  }]'

echo ""
echo ""

# Test 4: With includes removed (simpler response)
echo "📋 Test 4: No Includes (Simpler Response)"
echo "---------------------------------------------------"
echo "Query: /v1/galleries?limit=3"
curl -s "https://api.picflow.io/v1/galleries?limit=3" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-API-Version: 2023-01-01" \
  -H "picflow-tenant: $TENANT_ID" | jq '[.data[] | {
    id,
    name: (.title // .name),
    section,
    folder,
    has_teaser: (.teaser != null),
    has_cover: (.cover != null)
  }]'

echo ""
echo ""

# Test 5: Full response for one gallery
echo "📋 Test 5: Full Response Structure (First Gallery)"
echo "---------------------------------------------------"
curl -s "https://api.picflow.io/v1/galleries?limit=1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-API-Version: 2023-01-01" \
  -H "picflow-tenant: $TENANT_ID" | jq '.data[0] | keys'

echo ""
echo ""
echo "✅ Testing complete!"
echo ""
echo "💡 Your app now uses:"
echo "   GET /v1/galleries?limit=24"
echo "   This matches the web app pagination"

