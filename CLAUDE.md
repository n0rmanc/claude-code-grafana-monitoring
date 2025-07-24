# Claude Code Monitoring System

## 項目概述

這是一個基於 Kubernetes 的 Claude Code 使用監控系統，使用 OpenTelemetry、Prometheus 和 Grafana 來收集、存儲和視覺化 Claude Code 的使用數據。

## 系統架構

- **OpenTelemetry Collector**: 接收 Claude Code 的 telemetry 數據
- **Prometheus**: 存儲時間序列 metrics 數據
- **Grafana**: 視覺化和 dashboard

## OrbStack 環境特性

### 無需 Port-Forward 的服務訪問

在 OrbStack 環境下，可以**直接使用完整的 Kubernetes service DNS 名稱**來訪問集群內的服務，而無需執行 `kubectl port-forward` 命令。

#### 服務訪問格式
```
<service-name>.<namespace>.svc.cluster.local:<port>
```

#### 本項目中的服務訪問示例

```bash
# Prometheus (無需 port-forward)
http://dev-prometheus.claude-monitoring-dev.svc.cluster.local:9090

# Grafana (無需 port-forward)  
http://dev-grafana.claude-monitoring-dev.svc.cluster.local:3000

# OpenTelemetry Collector metrics endpoint
http://dev-otel-collector.claude-monitoring-dev.svc.cluster.local:8889/metrics
```

#### 對比傳統方式

**傳統方式 (需要 port-forward):**
```bash
kubectl port-forward svc/dev-prometheus 9090:9090 -n claude-monitoring-dev &
# 然後訪問 http://localhost:9090
```

**OrbStack 方式 (直接訪問):**
```bash
# 直接在瀏覽器或 curl 中訪問
http://dev-prometheus.claude-monitoring-dev.svc.cluster.local:9090
```

#### 優勢
- 簡化開發流程，無需管理 port-forward 進程
- 避免端口衝突
- 更直觀的服務發現
- 適合自動化腳本和 CI/CD 流程

## Recording Rules 實現

### 跨 Session 累積追蹤

本系統實現了 Prometheus Recording Rules 來解決 Claude Code metrics 的 per-session 特性：

```yaml
# 成本累積追蹤
- record: claude_code:cost_cumulative_total
  expr: |
    (
      claude_code:cost_cumulative_total offset 1m or vector(0)
    ) + 
    (
      sum(increase(claude_code_claude_code_cost_usage_USD_total[1m]))
    )
```

### 可用的 Recording Rules

- `claude_code:cost_cumulative_total` - 跨 session 累積總成本
- `claude_code:tokens_cumulative_total` - 跨 session 累積 token 數
- `claude_code:lines_cumulative_total` - 跨 session 累積代碼行數
- `claude_code:commits_cumulative_total` - 跨 session 累積 commit 數
- `claude_code:cost_today_total` - 今日累積成本
- `claude_code:cost_rate_per_minute` - 每分鐘成本消耗率
- `claude_code:active_sessions_count` - 活躍 sessions 數量

## Dashboard 結構

### 兩種 Metrics 類型

1. **活躍 Sessions Metrics**: 顯示當前活躍 sessions 的即時數據
   - Session 結束時數值會重置為 0
   - 例如: "Active Sessions - Current Cost"

2. **累積歷史 Metrics**: 使用 Recording Rules 的跨 session 累積數據
   - 數值持續累加，不會因 session 結束而重置
   - 例如: "Cumulative Total Cost", "Today's Cumulative Cost"

### 重要面板說明

- **Active Sessions - Current Cost**: 目前活躍 sessions 的即時成本
- **Cumulative Total Cost**: 使用 Recording Rules 的歷史累積成本
- **Today's Cumulative Cost**: 今日午夜以來的累積成本
- **Burn Rate**: 基於目前消耗率的成本預估

## 部署和操作

### 部署命令
```bash
# 部署到 dev 環境
kubectl apply -k k8s/overlays/dev/

# 檢查狀態
kubectl get pods -n claude-monitoring-dev
```

### 服務訪問 (OrbStack)
```bash
# Grafana Dashboard
open http://dev-grafana.claude-monitoring-dev.svc.cluster.local:3000

# Prometheus UI
open http://dev-prometheus.claude-monitoring-dev.svc.cluster.local:9090
```

### Dashboard 部署

#### 部署到遠端 Grafana

Dashboard 可以部署到任何 Grafana 實例，使用更新後的部署腳本：

```bash
# 設定環境變數
export GRAFANA_URL="https://monitoring.example.com"
export GRAFANA_API_KEY="your-grafana-api-key"

# 執行部署
./scripts/dashboard/deploy-dashboard.sh
```

部署腳本功能：
- 支援 API Key 認證（建議）或基本認證（admin/admin）
- 自動檢查 Grafana 健康狀態
- 部署 dashboard 並驗證結果
- 提供 dashboard URL 供直接訪問

#### 已部署實例

Dashboard 已成功部署到：
- URL: https://monitoring.hohsiang.com.tw/d/claude-code-monitoring-api
- Dashboard UID: claude-code-monitoring-api

### 故障排除

1. **檢查 Recording Rules 是否載入**:
   訪問 Prometheus UI → Status → Rules

2. **檢查 metrics 是否正常收集**:
   檢查 OTel Collector logs 和 Prometheus targets

3. **Dashboard 無數據**:
   確認 Prometheus datasource 配置正確，服務能正常通訊

## 技術細節

### Claude Code Metrics 特性
- 原始 metrics 是 per-session counters，會在 session 結束時重置
- 使用 Recording Rules 實現真正的累積追蹤
- `increase()` 函數會進行外插，可能導致數值不準確

### 配置文件位置
- Prometheus: `k8s/base/prometheus/configmap.yaml`
- Recording Rules: `k8s/base/prometheus/rules-configmap.yaml`  
- Grafana Dashboard: `k8s/base/grafana/configmap.yaml`
- OTel Collector: `k8s/base/otel-collector/configmap.yaml`