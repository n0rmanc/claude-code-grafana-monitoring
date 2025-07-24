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
                                                      ↑
                                                 API 管理
                                                Dashboard
```

### 組件說明

1. **OpenTelemetry Collector**: 接收來自 Claude Code 的遙測數據
2. **Prometheus**: 存儲時間序列指標數據
3. **Grafana**: 提供數據視覺化和儀表板
4. **API 管理**: 使用 Grafana API 動態管理儀表板

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

2. **完整部署 (推薦)**:
   ```bash
   ./scripts/deploy.sh dev --wait --info
   ```
   此命令會：
   - 部署基礎設施 (OTEL Collector, Prometheus, Grafana)
   - 等待所有服務就緒
   - 自動部署儀表板
   - 顯示訪問信息

3. **分步部署**:
   ```bash
   # 僅部署基礎設施
   ./scripts/deploy.sh dev
   
   # 單獨部署儀表板到本地開發環境
   GRAFANA_URL="http://localhost:30000" ./scripts/dashboard/deploy-dashboard.sh
   ```

4. **檢查部署狀態**:
   ```bash
   ./scripts/status.sh
   ```

5. **配置 Claude Code**:
   - 複製 `.claude/settings.local.json` 到 `~/.claude/settings.json`
   - 或參考 `claude-code-env-setup.md` 文檔

6. **訪問服務**:
   - **Grafana**: http://localhost:30000 (dev 環境 NodePort)
   - **儀表板**: http://localhost:30000/d/claude-code-monitoring-api
   - **帳號**: admin / admin

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

儀表板採用 **API 管理方式**，包含以下面板:

#### 💰 成本概覽
- 每日成本 (從午夜開始)
- 過去 24 小時滾動成本
- 活躍 sessions 成本
- API 請求成本趨勢

#### 📈 成本分析
- 成本按模型分佈 (圓餅圖)
- 每小時成本趨勢
- 成本效率指標 ($/行, $/commit, tokens/$)
- 成本累積趨勢

#### 📊 使用統計
- 每日 tokens 使用量
- 每日程式碼行數
- 每日 commits 數量
- 活躍 sessions 數量

#### 📈 即時活動
- 程式碼修改速度
- Token 使用率
- 按類型分類的 token 使用

## 管理腳本

### 主要部署腳本
```bash
./scripts/deploy.sh [dev|prod] [選項]

選項:
  -w, --wait     等待 Pod 就緒並自動部署儀表板
  -i, --info     顯示訪問信息
  -h, --help     顯示幫助信息

範例:
  ./scripts/deploy.sh dev --wait --info   # 完整部署 (推薦)
  ./scripts/deploy.sh prod --wait         # 生產環境部署
```

### 儀表板管理腳本
```bash
./scripts/dashboard/deploy-dashboard.sh

功能:
  - 使用 Grafana API 部署/更新儀表板
  - 支援遠端 Grafana 實例部署
  - 支援 API Key 認證
  - 自動驗證部署結果

環境變數:
  - GRAFANA_URL: Grafana 服務的完整 URL (必需)
  - GRAFANA_API_KEY: Grafana API Key (建議使用)

範例:
  # 使用 API Key 部署到遠端 Grafana
  GRAFANA_URL="https://monitoring.example.com" \
  GRAFANA_API_KEY="your-api-key" \
  ./scripts/dashboard/deploy-dashboard.sh
  
  # 使用基本認證 (admin/admin)
  GRAFANA_URL="https://monitoring.example.com" \
  ./scripts/dashboard/deploy-dashboard.sh
```

### 其他腳本
```bash
./scripts/status.sh                    # 狀態檢查
./scripts/cleanup.sh [dev|prod]        # 清理資源
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

5. **儀表板部署失敗**:
   - 檢查 Grafana 服務狀態: `kubectl get pods -n claude-monitoring-dev`
   - 驗證 API 連接: `curl -u admin:admin http://localhost:30000/api/health`
   - 重新部署儀表板: `GRAFANA_URL="http://localhost:30000" ./scripts/dashboard/deploy-dashboard.sh`

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

## 進階文檔

- [Dashboard API 管理指南](docs/dashboard-api-management.md) - 詳細說明 API 管理架構和開發工作流
- Claude Code 環境設定文檔 (TBD)
- 生產環境部署指南 (TBD)

## 更新日誌

### v2.0 - API 管理架構
- 🚀 將儀表板管理從 ConfigMap 遷移至 Grafana API
- ⚡ 支援動態儀表板更新，無需重啟 Pod
- 📝 改善版本控制和 CI/CD 整合
- 🔧 新增專用的儀表板部署腳本
- 📊 優化成本分析面板和查詢語法

### v1.0 - 初始版本
- 基本的 OpenTelemetry + Prometheus + Grafana 監控棧
- ConfigMap 基礎的儀表板管理
- Kustomize 多環境支援

## 貢獻

歡迎提交 Issue 和 Pull Request 來改進這個監控系統。

### 開發指南
1. Fork 此 repository
2. 建立功能分支
3. 在 dev 環境測試變更
4. 提交 Pull Request

## 授權

此專案使用 MIT 授權。