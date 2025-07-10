# Claude Code 監控系統

這是一個使用 Kubernetes 和 Kustomize 部署的 Claude Code 監控解決方案，基於 OpenTelemetry、Prometheus 和 Grafana 技術棧。

## 功能特色

- **OpenTelemetry 集成**: 收集 Claude Code 的指標、日誌和追蹤數據
- **Prometheus 監控**: 存儲和查詢時間序列數據
- **Grafana 儀表板**: 視覺化監控數據和成本分析
- **Kubernetes 原生**: 使用 Kustomize 進行環境管理
- **自動化部署**: 提供完整的部署和管理腳本

## 架構概覽

```
Claude Code → OpenTelemetry Collector → Prometheus → Grafana
```

### 組件說明

1. **OpenTelemetry Collector**: 接收來自 Claude Code 的遙測數據
2. **Prometheus**: 存儲時間序列指標數據
3. **Grafana**: 提供數據視覺化和儀表板

## 快速開始

### 先決條件

- Kubernetes 集群 (本地或雲端)
- kubectl 已配置並可存取集群
- 具有 `local-path` StorageClass (或修改為你的 StorageClass)

### 部署步驟

1. **克隆 repository**:
   ```bash
   git clone https://github.com/n0rmanc/claude-code-grafana-monitoring.git
   cd claude-code-grafana-monitoring
   ```

2. **部署到開發環境**:
   ```bash
   ./scripts/deploy.sh dev
   ```

3. **檢查部署狀態**:
   ```bash
   ./scripts/status.sh
   ```

4. **配置 Claude Code**:
   - 複製 `.claude/settings.local.json` 到 `~/.claude/settings.json`
   - 或參考 `claude-code-env-setup.md` 文檔

5. **訪問 Grafana**:
   ```bash
   kubectl port-forward -n claude-monitoring-dev svc/dev-grafana 3000:80
   ```
   - URL: http://localhost:3000
   - 帳號: admin
   - 密碼: admin

## 監控指標

### Claude Code 指標

- `claude_code_session_count_total`: 會話總數
- `claude_code_lines_of_code_count_total`: 修改的代碼行數
- `claude_code_cost_usage_USD_total`: API 使用成本
- `claude_code_token_usage_tokens_total`: Token 使用量
- `claude_code_active_time_seconds_total`: 活躍時間
- `claude_code_code_edit_tool_decision_total`: 工具使用決策
- `claude_code_git_commit_count_total`: Git commit 數量
- `claude_code_pull_request_count_total`: Pull request 數量

### Grafana 儀表板

儀表板包含以下面板:
- 會話統計
- 代碼修改量
- 成本分析 (包含每日成本追蹤)
- Token 使用趨勢
- 工具使用分布
- 錯誤率監控
- API 性能分析
- Git 活動統計

## 管理腳本

### 部署腳本
```bash
./scripts/deploy.sh [dev|prod]
```

### 狀態檢查
```bash
./scripts/status.sh
```

### 清理資源
```bash
./scripts/cleanup.sh [dev|prod]
```

## 故障排除

### 常見問題

1. **PVC Pending 狀態**:
   - 檢查 StorageClass: `kubectl get storageclass`
   - 修改 PVC 配置中的 `storageClassName`

2. **OpenTelemetry Collector 無法啟動**:
   - 檢查配置語法: `kubectl logs -n claude-monitoring-dev deployment/dev-otel-collector`
   - 驗證端口配置

3. **Prometheus 無法抓取指標**:
   - 檢查服務發現: `kubectl get endpoints -n claude-monitoring-dev`
   - 驗證 OTEL Collector 指標端點: `kubectl port-forward -n claude-monitoring-dev svc/dev-otel-collector 8888:8888`

4. **Grafana 無數據**:
   - 檢查 Prometheus 資料源配置
   - 驗證指標名稱和查詢語法

## 安全考量

### 開發環境
- 使用預設的 admin/admin 憑證
- 所有服務在集群內部通信

### 生產環境建議
- 更改預設密碼
- 配置 HTTPS/TLS
- 實施網路隔離 (NetworkPolicy)
- 設置適當的 RBAC 權限
- 使用 Secrets 管理敏感資料

## 貢獻

歡迎提交 Issue 和 Pull Request 來改進這個監控系統。

## 授權

此專案使用 MIT 授權。