#!/bin/bash

# Claude Code 監控系統清理腳本
# 用於清理 Kubernetes 資源

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

# 函數：確認操作
confirm_action() {
    local message=$1
    print_message $YELLOW "$message"
    read -p "請輸入 'yes' 確認: " confirmation
    if [ "$confirmation" != "yes" ]; then
        print_message $BLUE "操作已取消"
        exit 0
    fi
}

# 函數：清理環境
cleanup_env() {
    local env=$1
    local overlay_path="k8s/overlays/${env}"
    
    if [ ! -d "$overlay_path" ]; then
        print_message $RED "錯誤: 環境 '${env}' 不存在"
        print_message $YELLOW "可用環境: dev, prod"
        exit 1
    fi
    
    print_message $BLUE "清理 ${env} 環境..."
    
    # 使用 Kustomize 構建並刪除
    kubectl delete -k "$overlay_path" --ignore-not-found=true
    
    print_message $GREEN "✓ ${env} 環境清理完成"
}

# 函數：清理所有環境
cleanup_all() {
    confirm_action "這將清理所有環境的 Claude Code 監控資源，是否繼續？"
    
    cleanup_env "dev"
    cleanup_env "prod"
    
    print_message $GREEN "✓ 所有環境清理完成"
}

# 函數：清理 namespace
cleanup_namespace() {
    local namespace=$1
    
    confirm_action "這將刪除整個 namespace '${namespace}' 及其所有資源，是否繼續？"
    
    kubectl delete namespace "$namespace" --ignore-not-found=true
    
    print_message $GREEN "✓ Namespace ${namespace} 已刪除"
}

# 函數：顯示幫助信息
show_help() {
    echo "Claude Code 監控系統清理腳本"
    echo ""
    echo "使用方法:"
    echo "  $0 [選項] [環境]"
    echo ""
    echo "環境:"
    echo "  dev     清理開發環境"
    echo "  prod    清理生產環境"
    echo "  all     清理所有環境"
    echo ""
    echo "選項:"
    echo "  -h, --help              顯示此幫助信息"
    echo "  -n, --namespace <name>  刪除指定的 namespace"
    echo ""
    echo "範例:"
    echo "  $0 dev                           # 清理開發環境"
    echo "  $0 all                           # 清理所有環境"
    echo "  $0 --namespace claude-monitoring-dev  # 刪除開發環境的 namespace"
}

# 主函數
main() {
    local env=""
    local namespace=""
    
    # 解析命令行參數
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -n|--namespace)
                namespace=$2
                shift 2
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
    
    print_message $GREEN "Claude Code 監控系統清理腳本"
    
    # 如果指定了 namespace，則刪除 namespace
    if [ -n "$namespace" ]; then
        cleanup_namespace "$namespace"
        return
    fi
    
    # 檢查環境參數
    if [ -z "$env" ]; then
        print_message $RED "錯誤: 請指定環境 (dev, prod, 或 all)"
        show_help
        exit 1
    fi
    
    # 執行清理
    if [ "$env" = "all" ]; then
        cleanup_all
    else
        cleanup_env "$env"
    fi
    
    print_message $GREEN "\n清理腳本執行完成！"
}

# 執行主函數
main "$@"