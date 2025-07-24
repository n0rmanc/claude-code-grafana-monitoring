# Dashboard 部署說明

此目錄包含 Claude Code 監控 dashboard 和部署腳本。

## 設定

1. 複製環境設定檔：
   ```bash
   cp .env.example .env
   ```

2. 編輯 `.env` 並設定你的參數：
   ```bash
   # Grafana 設定
   GRAFANA_URL=https://your-grafana-instance.com
   GRAFANA_API_KEY=your-api-key-here

   # Metrics 設定
   METRICS_NAMESPACE=telemetry  # 或 claude_code

   # Dashboard 設定
   DASHBOARD_UID=claude-code-monitoring-api
   ```

## 部署

執行部署腳本即可：
```bash
./scripts/dashboard/deploy-dashboard.sh
```

腳本會自動：
- 從 `.env` 檔案載入設定
- 根據需要替換 metrics namespace
- 部署 dashboard 到你的 Grafana 實例
- 驗證部署結果

## 環境變數說明

| 變數名稱 | 說明 | 預設值 |
|----------|------|--------|
| GRAFANA_URL | Grafana 伺服器網址 | (必填) |
| GRAFANA_API_KEY | API 認證金鑰 | (選填，預設使用 admin:admin) |
| METRICS_NAMESPACE | Prometheus metrics 命名空間前綴 | claude_code |
| DASHBOARD_UID | Dashboard 唯一識別碼 | claude-code-monitoring-api |

## 手動覆蓋設定

你仍然可以透過環境變數覆蓋任何設定：
```bash
METRICS_NAMESPACE=custom ./scripts/dashboard/deploy-dashboard.sh
```

環境變數的優先順序高於 `.env` 檔案中的設定。