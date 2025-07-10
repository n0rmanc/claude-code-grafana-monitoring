#!/bin/bash

# Claude Code 監控系統部署腳本
# 使用 Kustomize 部署到 Kubernetes

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

# 函數：檢查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_message $RED "錯誤: $1 未安裝或不在 PATH 中"
        exit 1
    fi
}

# 函數：檢查 Kubernetes 連接
check_k8s_connection() {
    print_message $BLUE "檢查 Kubernetes 連接..."
    if ! kubectl cluster-info &> /dev/null; then
        print_message $RED "錯誤: 無法連接到 Kubernetes 集群"
        print_message $YELLOW "請確認 kubectl 已正確配置並可以訪問集群"
        exit 1
    fi
    print_message $GREEN "✓ Kubernetes 連接正常"
}

# 函數：部署到指定環境
deploy_to_env() {
    local env=$1
    local overlay_path="k8s/overlays/${env}"
    
    if [ ! -d "$overlay_path" ]; then
        print_message $RED "錯誤: 環境 '${env}' 不存在"
        print_message $YELLOW "可用環境: dev, prod"
        exit 1
    fi
    
    print_message $BLUE "部署到 ${env} 環境..."
    
    # 使用 Kustomize 構建並應用
    kubectl apply -k "$overlay_path"
    
    print_message $GREEN "✓ 部署完成"
}

# 函數：等待 Pod 就緒
wait_for_pods() {
    local namespace=$1
    print_message $BLUE "等待 Pod 就緒..."
    
    # 等待所有 Deployment 就緒
    local deployments=("otel-collector" "prometheus" "grafana")
    
    for deployment in "${deployments[@]}"; do
        local full_name="${ENV_PREFIX}${deployment}"
        print_message $YELLOW "等待 ${full_name} 就緒..."
        kubectl wait --for=condition=available --timeout=300s deployment/${full_name} -n ${namespace}
        print_message $GREEN "✓ ${full_name} 已就緒"
    done
}

# 函數：顯示訪問信息
show_access_info() {
    local namespace=$1
    local env=$2
    
    print_message $GREEN "\n=========================================="
    print_message $GREEN "部署完成！訪問信息如下："
    print_message $GREEN "=========================================="
    
    if [ "$env" = "dev" ]; then
        print_message $BLUE "Grafana (NodePort): http://localhost:30000"
        print_message $YELLOW "用戶名: admin, 密碼: admin"
    else
        print_message $BLUE "使用以下命令進行端口轉發："
        print_message $YELLOW "kubectl port-forward -n ${namespace} svc/${ENV_PREFIX}grafana 3000:3000"
        print_message $YELLOW "kubectl port-forward -n ${namespace} svc/${ENV_PREFIX}prometheus 9090:9090"
        print_message $YELLOW "kubectl port-forward -n ${namespace} svc/${ENV_PREFIX}otel-collector 4317:4317"
    fi
    
    print_message $GREEN "\n訪問地址："
    print_message $BLUE "- Grafana: http://localhost:3000 (admin/admin)"
    print_message $BLUE "- Prometheus: http://localhost:9090"
    print_message $BLUE "- OTEL Collector: http://localhost:4317 (gRPC), http://localhost:4318 (HTTP)"
}

# 函數：顯示幫助信息
show_help() {
    echo "Claude Code 監控系統部署腳本"
    echo ""
    echo "使用方法:"
    echo "  $0 [選項] <環境>"
    echo ""
    echo "環境:"
    echo "  dev     部署到開發環境"
    echo "  prod    部署到生產環境"
    echo ""
    echo "選項:"
    echo "  -h, --help     顯示此幫助信息"
    echo "  -w, --wait     等待 Pod 就緒"
    echo "  -i, --info     顯示訪問信息"
    echo ""
    echo "範例:"
    echo "  $0 dev                 # 部署到開發環境"
    echo "  $0 prod --wait         # 部署到生產環境並等待就緒"
    echo "  $0 dev --wait --info   # 部署到開發環境，等待就緒並顯示訪問信息"
}

# 主函數
main() {
    local env=""
    local wait_pods=false
    local show_info=false
    
    # 解析命令行參數
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -w|--wait)
                wait_pods=true
                shift
                ;;
            -i|--info)
                show_info=true
                shift
                ;;
            dev|prod)
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
        print_message $RED "錯誤: 請指定環境 (dev 或 prod)"
        show_help
        exit 1
    fi
    
    # 設定環境變數
    if [ "$env" = "dev" ]; then
        ENV_PREFIX="dev-"
        NAMESPACE="claude-monitoring-dev"
    else
        ENV_PREFIX="prod-"
        NAMESPACE="claude-monitoring-prod"
    fi
    
    print_message $GREEN "Claude Code 監控系統部署腳本"
    print_message $BLUE "目標環境: $env"
    
    # 檢查必要命令
    check_command "kubectl"
    check_command "kustomize"
    
    # 檢查 Kubernetes 連接
    check_k8s_connection
    
    # 部署
    deploy_to_env "$env"
    
    # 等待 Pod 就緒
    if [ "$wait_pods" = true ]; then
        wait_for_pods "$NAMESPACE"
    fi
    
    # 顯示訪問信息
    if [ "$show_info" = true ]; then
        show_access_info "$NAMESPACE" "$env"
    fi
    
    print_message $GREEN "\n部署腳本執行完成！"
}

# 執行主函數
main "$@"