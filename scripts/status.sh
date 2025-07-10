#!/bin/bash

# Claude Code 監控系統狀態檢查腳本

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函數：打印彩色消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 函數：檢查 Deployment 狀態
check_deployment_status() {
    local namespace=$1
    local deployment=$2
    
    if kubectl get deployment "$deployment" -n "$namespace" &> /dev/null; then
        local ready_replicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired_replicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.spec.replicas}')
        
        if [ "$ready_replicas" = "$desired_replicas" ] && [ "$ready_replicas" != "0" ]; then
            print_message $GREEN "✓ $deployment: $ready_replicas/$desired_replicas 就緒"
            return 0
        else
            print_message $RED "✗ $deployment: $ready_replicas/$desired_replicas 就緒"
            return 1
        fi
    else
        print_message $RED "✗ $deployment: 未找到"
        return 1
    fi
}

# 函數：檢查 Service 狀態
check_service_status() {
    local namespace=$1
    local service=$2
    
    if kubectl get service "$service" -n "$namespace" &> /dev/null; then
        local cluster_ip=$(kubectl get service "$service" -n "$namespace" -o jsonpath='{.spec.clusterIP}')
        local ports=$(kubectl get service "$service" -n "$namespace" -o jsonpath='{.spec.ports[*].port}' | tr ' ' ',')
        print_message $GREEN "✓ $service: $cluster_ip:$ports"
        return 0
    else
        print_message $RED "✗ $service: 未找到"
        return 1
    fi
}

# 函數：檢查 PVC 狀態
check_pvc_status() {
    local namespace=$1
    local pvc=$2
    
    if kubectl get pvc "$pvc" -n "$namespace" &> /dev/null; then
        local status=$(kubectl get pvc "$pvc" -n "$namespace" -o jsonpath='{.status.phase}')
        local size=$(kubectl get pvc "$pvc" -n "$namespace" -o jsonpath='{.status.capacity.storage}')
        
        if [ "$status" = "Bound" ]; then
            print_message $GREEN "✓ $pvc: $status ($size)"
            return 0
        else
            print_message $RED "✗ $pvc: $status"
            return 1
        fi
    else
        print_message $RED "✗ $pvc: 未找到"
        return 1
    fi
}

# 函數：檢查環境狀態
check_env_status() {
    local env=$1
    
    if [ "$env" = "dev" ]; then
        ENV_PREFIX="dev-"
        NAMESPACE="claude-monitoring-dev"
    else
        ENV_PREFIX="prod-"
        NAMESPACE="claude-monitoring-prod"
    fi
    
    print_message $BLUE "\n=========================================="
    print_message $BLUE "檢查 $env 環境狀態"
    print_message $BLUE "=========================================="
    
    # 檢查 namespace
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_message $GREEN "✓ Namespace: $NAMESPACE"
    else
        print_message $RED "✗ Namespace: $NAMESPACE 不存在"
        return 1
    fi
    
    # 檢查 Deployments
    print_message $YELLOW "\nDeployments:"
    local deployments=("${ENV_PREFIX}otel-collector" "${ENV_PREFIX}prometheus" "${ENV_PREFIX}grafana")
    local deployment_status=0
    
    for deployment in "${deployments[@]}"; do
        check_deployment_status "$NAMESPACE" "$deployment" || deployment_status=1
    done
    
    # 檢查 Services
    print_message $YELLOW "\nServices:"
    local services=("${ENV_PREFIX}otel-collector" "${ENV_PREFIX}prometheus" "${ENV_PREFIX}grafana")
    local service_status=0
    
    for service in "${services[@]}"; do
        check_service_status "$NAMESPACE" "$service" || service_status=1
    done
    
    # 檢查 PVCs
    print_message $YELLOW "\nPersistent Volume Claims:"
    local pvcs=("${ENV_PREFIX}prometheus-storage" "${ENV_PREFIX}grafana-storage")
    local pvc_status=0
    
    for pvc in "${pvcs[@]}"; do
        check_pvc_status "$NAMESPACE" "$pvc" || pvc_status=1
    done
    
    # 總結狀態
    if [ $deployment_status -eq 0 ] && [ $service_status -eq 0 ] && [ $pvc_status -eq 0 ]; then
        print_message $GREEN "\n✓ $env 環境狀態正常"
        return 0
    else
        print_message $RED "\n✗ $env 環境存在問題"
        return 1
    fi
}

# 函數：顯示端口轉發命令
show_port_forward_commands() {
    local env=$1
    
    if [ "$env" = "dev" ]; then
        NAMESPACE="claude-monitoring-dev"
        ENV_PREFIX="dev-"
    else
        NAMESPACE="claude-monitoring-prod"
        ENV_PREFIX="prod-"
    fi
    
    print_message $BLUE "\n端口轉發命令："
    print_message $YELLOW "kubectl port-forward -n $NAMESPACE svc/${ENV_PREFIX}grafana 3000:3000"
    print_message $YELLOW "kubectl port-forward -n $NAMESPACE svc/${ENV_PREFIX}prometheus 9090:9090"
    print_message $YELLOW "kubectl port-forward -n $NAMESPACE svc/${ENV_PREFIX}otel-collector 4317:4317"
}

# 函數：顯示幫助信息
show_help() {
    echo "Claude Code 監控系統狀態檢查腳本"
    echo ""
    echo "使用方法:"
    echo "  $0 [選項] [環境]"
    echo ""
    echo "環境:"
    echo "  dev     檢查開發環境"
    echo "  prod    檢查生產環境"
    echo "  all     檢查所有環境"
    echo ""
    echo "選項:"
    echo "  -h, --help     顯示此幫助信息"
    echo "  -p, --ports    顯示端口轉發命令"
    echo ""
    echo "範例:"
    echo "  $0 dev                 # 檢查開發環境狀態"
    echo "  $0 all                 # 檢查所有環境狀態"
    echo "  $0 dev --ports         # 檢查開發環境並顯示端口轉發命令"
}

# 主函數
main() {
    local env=""
    local show_ports=false
    
    # 解析命令行參數
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -p|--ports)
                show_ports=true
                shift
                ;;
            dev|prod|all)
                env=$1
                shift
                ;;
            *)
                print_message $RED "未知參數: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 檢查環境參數
    if [ -z "$env" ]; then
        print_message $RED "錯誤: 請指定環境 (dev, prod, 或 all)"
        show_help
        exit 1
    fi
    
    print_message $GREEN "Claude Code 監控系統狀態檢查"
    
    # 檢查 kubectl 連接
    if ! kubectl cluster-info &> /dev/null; then
        print_message $RED "錯誤: 無法連接到 Kubernetes 集群"
        exit 1
    fi
    
    # 執行狀態檢查
    local overall_status=0
    
    if [ "$env" = "all" ]; then
        check_env_status "dev" || overall_status=1
        check_env_status "prod" || overall_status=1
    else
        check_env_status "$env" || overall_status=1
        
        if [ "$show_ports" = true ]; then
            show_port_forward_commands "$env"
        fi
    fi
    
    # 顯示總結
    print_message $BLUE "\n=========================================="
    if [ $overall_status -eq 0 ]; then
        print_message $GREEN "所有檢查的環境狀態正常！"
    else
        print_message $RED "部分環境存在問題，請檢查上述錯誤信息"
    fi
    print_message $BLUE "=========================================="
    
    exit $overall_status
}

# 執行主函數
main "$@"