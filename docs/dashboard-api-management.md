# Dashboard API 管理指南

本文檔說明如何使用 Grafana API 管理儀表板，以及新的 API 管理架構的優勢和使用方式。

## 架構變更概述

### 原始架構 (ConfigMap)
```
Kubernetes ConfigMap → Grafana Volume Mount → Static Dashboard
```

**問題:**
- 儀表板更新需要重啟 Pod
- JSON 配置混在 YAML 中難以管理
- 無法動態更新儀表板

### 新架構 (API 管理)
```
JSON Files → API Script → Grafana API → Dynamic Dashboard
```

**優勢:**
- ✅ 動態更新，無需重啟 Pod
- ✅ 獨立的 JSON 檔案，易於版本控制
- ✅ 支援 CI/CD 自動化部署
- ✅ 更好的開發體驗

## 檔案結構

```
scripts/
├── dashboard/
│   ├── claude-code-dashboard.json    # 儀表板定義檔案
│   └── deploy-dashboard.sh           # 部署腳本
└── deploy.sh                         # 主部署腳本 (已整合)
```

## API 腳本使用

### 基本使用

```bash
# 部署到開發環境
./scripts/dashboard/deploy-dashboard.sh dev

# 部署到生產環境
./scripts/dashboard/deploy-dashboard.sh prod
```

### 腳本功能

1. **環境自動檢測**
   - dev: 使用 NodePort (localhost:30000)
   - prod: 使用 port-forward (localhost:3000)

2. **健康檢查**
   - 自動等待 Grafana 服務就緒
   - 驗證 API 連接

3. **部署驗證**
   - 自動驗證儀表板部署成功
   - 提供直接訪問 URL

### 整合部署

```bash
# 完整部署 (基礎設施 + 儀表板)
./scripts/deploy.sh dev --wait --info
```

此命令會自動執行:
1. 部署 Kubernetes 資源
2. 等待所有 Pod 就緒
3. 部署儀表板 (使用 API)
4. 顯示訪問信息

## 儀表板開發工作流

### 1. 修改儀表板
編輯 `scripts/dashboard/claude-code-dashboard.json`

### 2. 部署更新
```bash
./scripts/dashboard/deploy-dashboard.sh dev
```

### 3. 測試驗證
訪問 http://localhost:30000/d/claude-code-monitoring-api

### 4. 提交變更
```bash
git add scripts/dashboard/claude-code-dashboard.json
git commit -m "Update dashboard: add new cost analysis panel"
```

## API 詳細說明

### Grafana Dashboard API 端點

- **創建/更新**: `POST /api/dashboards/db`
- **讀取**: `GET /api/dashboards/uid/{uid}`
- **刪除**: `DELETE /api/dashboards/uid/{uid}`

### 請求格式

```json
{
  "dashboard": {
    "uid": "claude-code-monitoring-api",
    "title": "Dashboard Title",
    "panels": [...]
  },
  "overwrite": true,
  "message": "Updated via API"
}
```

### 認證
使用基本認證: `admin:admin`

## 故障排除

### 1. 連接問題
```bash
# 檢查 Grafana 健康狀態
curl -u admin:admin http://localhost:30000/api/health

# 檢查服務狀態
kubectl get pods -n claude-monitoring-dev
```

### 2. 部署失敗
```bash
# 查看詳細錯誤
./scripts/dashboard/deploy-dashboard.sh dev

# 手動測試 API
curl -X POST \
  -H "Content-Type: application/json" \
  -u admin:admin \
  -d @scripts/dashboard/claude-code-dashboard.json \
  http://localhost:30000/api/dashboards/db
```

### 3. 權限問題
- 確認使用正確的 admin 憑證
- 檢查儀表板不是 provisioned 類型

## 最佳實務

### 1. 版本控制
- 儀表板 JSON 檔案獨立提交
- 使用清晰的 commit 訊息
- 避免在 JSON 中硬編碼環境特定設定

### 2. 開發流程
- 在 dev 環境測試變更
- 驗證所有面板正常顯示
- 確認查詢語法正確

### 3. CI/CD 整合
```yaml
# GitHub Actions 範例
- name: Deploy Dashboard
  run: |
    ./scripts/dashboard/deploy-dashboard.sh prod
```

### 4. 監控和警報
- 定期檢查儀表板是否正常運作
- 設定 Grafana API 可用性監控
- 建立儀表板備份機制

## 進階功能

### 多環境管理
可擴展腳本支援更多環境:

```bash
# 自定義環境
GRAFANA_URL="https://grafana.example.com" \
  ./scripts/dashboard/deploy-dashboard.sh custom
```

### 批量部署
```bash
# 部署多個儀表板
for dashboard in scripts/dashboard/*.json; do
  ./scripts/dashboard/deploy-dashboard.sh dev "$dashboard"
done
```

### API 擴展
可基於現有腳本擴展功能:
- 儀表板範本化
- 動態生成面板
- 自動化測試驗證