#!/bin/bash
SUPA_URL="https://kyvbnntoxslrtrsiejzc.supabase.co"
SUPA_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt5dmJubnRveHNscnRyc2llanpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NjQ1NDcsImV4cCI6MjA5MTQ0MDU0N30.Dx-9SKxWfAoxXg3gzx3NpzJD1taZgkQCCjwDXlY9J6I"

check() {
  local email="$1"
  local pass="$2"
  echo "=== $email ==="
  local token
  token=$(curl -s -X POST "$SUPA_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $SUPA_KEY" -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$pass\"}" \
    | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).access_token||'')}catch(e){console.log('')}})")
  if [ -z "$token" ]; then
    echo "  LOGIN FAIL"
    return
  fi
  for q in \
    "properties?select=id,nome&limit=5" \
    "satellite_readings?select=id&limit=1" \
    "alerts?select=id&limit=1" \
    "field_logs?select=id&limit=1" \
    "inventory_items?select=id&limit=1" \
    "property_managers?select=id&limit=1" ; do
    local label="${q%%\?*}"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" "$SUPA_URL/rest/v1/$q" \
      -H "apikey: $SUPA_KEY" -H "Authorization: Bearer $token")
    local count
    count=$(curl -s "$SUPA_URL/rest/v1/$q" \
      -H "apikey: $SUPA_KEY" -H "Authorization: Bearer $token" \
      | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{const a=JSON.parse(d);console.log(Array.isArray(a)?a.length:'err')}catch(e){console.log('-')}})")
    printf "  %-22s  HTTP %s  rows=%s\n" "$label" "$code" "$count"
  done
  echo
}

check "teste@agruai.com" "gestor2026"
check "fazendeiro.teste@agruai.com" "AgrUAI2026!"
