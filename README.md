# Claude Code 監控系統

這是一個使用 Kubernetes 和 Kustomize 部署的 Claude Code 監控解決方案，基於 OpenTelemetry、Prometheus 和 Grafana 技術棧。

## 功能特色

- **OpenTelemetry 集成**: 收集 Claude Code 的指標、日誌和追蹤數據
- **Prometheus 監控**: 存儲和查詢時間序列數據
- **Grafana 儀表板**: 可視化監控數據和指標
- **Kubernetes 原生**: 使用 Kustomize 進行多環境部署
- **多環境支持**: 支持開發和生產環境配置

## 架構圖

```
Claude Code Client
    ↓ (OTLP)
OpenTelemetry Collector
    ↓ (Prometheus 格式)
Prometheus
    ↓ (查詢)
Grafana Dashboard
```

## 監控指標

系統收集以下 Claude Code 使用指標：

- **會話指標**: 會話數量、會話時長
- **程式碼指標**: 修改的程式碼行數、創建的檔案數
- **API 使用**: 請求數量、Token 使用量、API 成本
- **工具使用**: 程式碼編輯工具使用統計
- **Pull Request**: 創建的 PR 數量
- **提交數量**: Git 提交統計

## 快速開始

### 先決條件

- Kubernetes 集群 (本地或雲端)
- kubectl 已配置並可訪問集群
- kustomize 命令行工具

### 1. 部署到開發環境

```bash
# 部署到開發環境並等待就緒
./scripts/deploy.sh dev --wait --info

# 或者使用 kubectl 直接部署
kubectl apply -k k8s/overlays/dev
```

### 2. 訪問服務

開發環境使用 NodePort，可直接訪問：

- **Grafana**: http://localhost:30000 (admin/admin)

生產環境需要端口轉發：

```bash
# Grafana
kubectl port-forward -n claude-monitoring-prod svc/prod-grafana 3000:3000

# Prometheus  
kubectl port-forward -n claude-monitoring-prod svc/prod-prometheus 9090:9090

# OTEL Collector
kubectl port-forward -n claude-monitoring-prod svc/prod-otel-collector 4317:4317
```

### 3. 配置 Claude Code

設置環境變數啟用監控：

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
```

詳細配置請參考：[Claude Code 環境變數設置指南](claude-code-env-setup.md)

## 目錄結構

```
claude-monitoring/
├── k8s/                           # Kubernetes 資源
│   ├── base/                      # 基礎配置
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── otel-collector/        # OpenTelemetry Collector
│   │   ├── prometheus/            # Prometheus 監控
│   │   └── grafana/               # Grafana 儀表板
│   └── overlays/                  # 環境特定配置
│       ├── dev/                   # 開發環境
│       └── prod/                  # 生產環境
├── scripts/                       # 管理腳本
│   ├── deploy.sh                  # 部署腳本
│   ├── cleanup.sh                 # 清理腳本
│   └── status.sh                  # 狀態檢查腳本
├── config/                        # 配置檔案
├── claude-code-env-setup.md       # 環境變數設置指南
└── README.md                      # 本檔案
```

## 管理腳本

### 部署腳本

```bash
# 基本部署
./scripts/deploy.sh dev

# 部署並等待就緒，顯示訪問信息
./scripts/deploy.sh prod --wait --info

# 顯示幫助
./scripts/deploy.sh --help
```

### 狀態檢查

```bash
# 檢查開發環境狀態
./scripts/status.sh dev

# 檢查所有環境
./scripts/status.sh all

# 檢查並顯示端口轉發命令
./scripts/status.sh dev --ports
```

### 清理資源

```bash
# 清理開發環境
./scripts/cleanup.sh dev

# 清理所有環境
./scripts/cleanup.sh all

# 刪除整個 namespace
./scripts/cleanup.sh --namespace claude-monitoring-dev
```

## 環境配置

### 開發環境 (dev)

- Namespace: `claude-monitoring-dev`
- 資源前綴: `dev-`
- Grafana 使用 NodePort (端口 30000)
- 較小的資源限制

### 生產環境 (prod)

- Namespace: `claude-monitoring-prod`
- 資源前綴: `prod-`
- 所有服務使用 ClusterIP
- OTEL Collector 運行 2 個副本
- 較高的資源限制

## 存儲配置

系統使用 PersistentVolumeClaim 來持久化數據：

- **Prometheus**: 10Gi 存儲空間
- **Grafana**: 5Gi 存儲空間

> 注意: PVC 的 `storageClassName` 設為空字符串，將使用集群的默認存儲類別。根據你的 Kubernetes 環境調整此設置。

## 安全考慮

1. **預設密碼**: Grafana 默認使用 admin/admin，生產環境請修改
2. **網路政策**: 考慮實施 Kubernetes NetworkPolicy 限制流量
3. **RBAC**: 為服務帳戶設置適當的權限
4. **TLS**: 生產環境建議啟用 TLS 加密

## 監控數據保留

- **Prometheus**: 數據保留 200 小時 (約 8.3 天)
- **OpenTelemetry**: 指標過期時間 180 分鐘

## 故障排除

### 常見問題

1. **Pod 無法啟動**
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   kubectl logs <pod-name> -n <namespace>
   ```

2. **PVC 無法綁定**
   ```bash
   kubectl get pv
   kubectl describe pvc <pvc-name> -n <namespace>
   ```

3. **服務無法訪問**
   ```bash
   kubectl get svc -n <namespace>
   kubectl port-forward svc/<service-name> <local-port>:<service-port> -n <namespace>
   ```

### 檢查服務健康狀態

```bash
# 使用狀態檢查腳本
./scripts/status.sh all

# 或手動檢查
kubectl get all -n claude-monitoring-dev
kubectl get all -n claude-monitoring-prod
```

## 自定義配置

### 修改 Grafana 儀表板

1. 編輯 `k8s/base/grafana/configmap.yaml`
2. 更新 `claude-code-dashboard.json` 部分
3. 重新部署：`kubectl apply -k k8s/overlays/<env>`

### 調整 Prometheus 配置

1. 編輯 `k8s/base/prometheus/configmap.yaml`
2. 修改 `prometheus.yml` 配置
3. 重新部署並重載配置

### 修改 OTEL Collector 配置

1. 編輯 `k8s/base/otel-collector/configmap.yaml`
2. 調整接收器、處理器或導出器配置
3. 重新部署服務

## 擴展和優化

### 生產環境建議

1. **高可用性**: 為 Prometheus 和 Grafana 配置多副本
2. **持久化存儲**: 使用適當的存儲類別和備份策略
3. **監控告警**: 配置 AlertManager 進行告警通知
4. **資源限制**: 根據實際使用調整 CPU 和內存限制
5. **網路安全**: 實施適當的網路隔離和安全策略

### 性能調優

1. **OTEL Collector**: 調整批次處理和記憶體限制
2. **Prometheus**: 配置適當的抓取間隔和保留策略
3. **Grafana**: 優化查詢和儀表板載入時間

## 貢獻

歡迎提交 Issue 和 Pull Request 來改進這個監控系統。

## 授權

此專案使用 MIT 授權。