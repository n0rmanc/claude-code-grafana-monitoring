#!/bin/bash

# Dashboard deployment script for Claude Code monitoring
# Usage: ./deploy-dashboard.sh
# Environment variables:
#   GRAFANA_URL (required): Grafana server URL
#   GRAFANA_API_KEY (optional): Grafana API key for authentication
#   METRICS_NAMESPACE (optional): Metrics namespace prefix (default: claude_code)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_FILE="${SCRIPT_DIR}/claude-code-dashboard.json"
METRICS_NAMESPACE="${METRICS_NAMESPACE:-claude_code}"
TEMP_DASHBOARD_FILE=""

# Check required environment variables
if [[ -z "${GRAFANA_URL:-}" ]]; then
    echo "❌ Error: GRAFANA_URL environment variable must be set"
    exit 1
fi

echo "🚀 Deploying dashboard to $GRAFANA_URL..."
echo "📊 Using metrics namespace: $METRICS_NAMESPACE"

# Check if dashboard file exists
if [[ ! -f "$DASHBOARD_FILE" ]]; then
    echo "❌ Error: Dashboard file not found: $DASHBOARD_FILE"
    exit 1
fi

# Function to check if Grafana is ready
wait_for_grafana() {
    echo "⏳ Waiting for Grafana to be ready..."
    echo "✅ Using Grafana at: $GRAFANA_URL"
    
    # Wait for Grafana to respond
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if curl -s -f "$GRAFANA_URL/api/health" > /dev/null 2>&1; then
            echo "✅ Grafana is ready!"
            return 0
        fi
        
        echo "   Attempt $((attempt + 1))/$max_attempts - waiting for Grafana..."
        sleep 5
        ((attempt++))
    done
    
    echo "❌ Error: Grafana did not become ready within timeout"
    exit 1
}

# Function to prepare dashboard with correct namespace
prepare_dashboard() {
    echo "🔧 Preparing dashboard with namespace: $METRICS_NAMESPACE"
    
    # Create temporary file
    TEMP_DASHBOARD_FILE=$(mktemp)
    
    # Check if dashboard already has the correct namespace
    if grep -q "${METRICS_NAMESPACE}_claude_code_" "$DASHBOARD_FILE"; then
        echo "   Dashboard already uses ${METRICS_NAMESPACE} namespace"
        cp "$DASHBOARD_FILE" "$TEMP_DASHBOARD_FILE"
    else
        # Replace metrics namespace
        if [[ "$METRICS_NAMESPACE" != "claude_code" ]]; then
            echo "   Replacing claude_code_claude_code_ with ${METRICS_NAMESPACE}_claude_code_"
            sed "s/claude_code_claude_code_/${METRICS_NAMESPACE}_claude_code_/g" \
                "$DASHBOARD_FILE" > "$TEMP_DASHBOARD_FILE"
        else
            # Use original file if namespace is default
            cp "$DASHBOARD_FILE" "$TEMP_DASHBOARD_FILE"
        fi
    fi
}

# Function to deploy dashboard
deploy_dashboard() {
    echo "📊 Deploying dashboard..."
    
    local response
    local dashboard_to_deploy="${TEMP_DASHBOARD_FILE:-$DASHBOARD_FILE}"
    
    # Create the API payload with the dashboard wrapped properly
    local payload=$(jq -n \
        --arg message "Updated by API" \
        --slurpfile dashboard "$dashboard_to_deploy" \
        '{
            dashboard: $dashboard[0],
            overwrite: true,
            folderUid: "",
            message: $message
        }')
    
    # Use API key if provided, otherwise fall back to basic auth
    if [[ -n "${GRAFANA_API_KEY:-}" ]]; then
        response=$(curl -s -w "\n%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $GRAFANA_API_KEY" \
            -d "$payload" \
            "$GRAFANA_URL/api/dashboards/db")
    else
        response=$(curl -s -w "\n%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -u admin:admin \
            -d "$payload" \
            "$GRAFANA_URL/api/dashboards/db")
    fi
    
    local body=$(echo "$response" | sed '$d')
    local status_code=$(echo "$response" | tail -n1)
    
    if [[ "$status_code" == "200" ]]; then
        local dashboard_uid=$(echo "$body" | grep -o '"uid":"[^"]*"' | cut -d'"' -f4)
        local dashboard_url="$GRAFANA_URL/d/$dashboard_uid"
        
        echo "✅ Dashboard deployed successfully!"
        echo "🌐 Dashboard URL: $dashboard_url"
        echo "📋 Dashboard UID: $dashboard_uid"
    else
        echo "❌ Error: Dashboard deployment failed (HTTP $status_code)"
        echo "Response: $body"
        exit 1
    fi
}

# Function to verify deployment
verify_dashboard() {
    echo "🔍 Verifying dashboard deployment..."
    
    local response
    # Use API key if provided, otherwise fall back to basic auth
    if [[ -n "${GRAFANA_API_KEY:-}" ]]; then
        response=$(curl -s -w "\n%{http_code}" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $GRAFANA_API_KEY" \
            "$GRAFANA_URL/api/dashboards/uid/claude-code-monitoring-api")
    else
        response=$(curl -s -w "\n%{http_code}" \
            -H "Content-Type: application/json" \
            -u admin:admin \
            "$GRAFANA_URL/api/dashboards/uid/claude-code-monitoring-api")
    fi
    
    local status_code=$(echo "$response" | tail -n1)
    
    if [[ "$status_code" == "200" ]]; then
        echo "✅ Dashboard verification successful!"
    else
        echo "⚠️  Warning: Dashboard verification failed (HTTP $status_code)"
    fi
}


# Cleanup function
cleanup() {
    if [[ -n "$TEMP_DASHBOARD_FILE" ]] && [[ -f "$TEMP_DASHBOARD_FILE" ]]; then
        rm -f "$TEMP_DASHBOARD_FILE"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Main execution
main() {
    echo "🎯 Grafana URL: $GRAFANA_URL"
    echo "📄 Dashboard file: $DASHBOARD_FILE"
    echo "📊 Metrics namespace: $METRICS_NAMESPACE"
    echo
    
    wait_for_grafana
    prepare_dashboard
    deploy_dashboard
    verify_dashboard
    
    echo
    echo "🎉 Dashboard deployment completed successfully!"
    echo "💡 Access the dashboard at: $GRAFANA_URL/d/claude-code-monitoring-api"
    echo "👤 Login: Use API key or admin credentials"
}

# Run main function
main