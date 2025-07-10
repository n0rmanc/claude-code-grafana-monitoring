# Claude Code 環境變數設置指南

## 基本設定

要啟用 Claude Code 的 OpenTelemetry 監控功能，需要設置以下環境變數：

### 必要環境變數

```bash
# 啟用 Claude Code 的 OpenTelemetry 功能
export CLAUDE_CODE_ENABLE_TELEMETRY=1

# 設定 OpenTelemetry 指標導出器
export OTEL_METRICS_EXPORTER=otlp

# 設定 OTLP 導出端點（根據你的 Kubernetes 設定調整）
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317

# 設定 OTLP 協議（可選，默認為 grpc）
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
```

### 可選環境變數

```bash
# 設定指標導出間隔（秒）
export OTEL_METRIC_EXPORT_INTERVAL=30

# 設定服務名稱
export OTEL_SERVICE_NAME=claude-code

# 設定服務版本
export OTEL_SERVICE_VERSION=1.0.0

# 設定資源屬性（可添加自定義標籤）
export OTEL_RESOURCE_ATTRIBUTES=team=engineering,department=product,environment=production
```

## Kubernetes 環境設定

如果你在 Kubernetes 環境中運行 Claude Code，可以通過以下方式設置環境變數：

### 方法 1: 在 Pod 中直接設定環境變數

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: claude-code-client
spec:
  containers:
  - name: claude-code
    image: your-image
    env:
    - name: CLAUDE_CODE_ENABLE_TELEMETRY
      value: "1"
    - name: OTEL_METRICS_EXPORTER
      value: "otlp"
    - name: OTEL_EXPORTER_OTLP_ENDPOINT
      value: "http://otel-collector:4317"
    - name: OTEL_EXPORTER_OTLP_PROTOCOL
      value: "grpc"
```

### 方法 2: 使用 ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: claude-code-env
data:
  CLAUDE_CODE_ENABLE_TELEMETRY: "1"
  OTEL_METRICS_EXPORTER: "otlp"
  OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector:4317"
  OTEL_EXPORTER_OTLP_PROTOCOL: "grpc"
  OTEL_SERVICE_NAME: "claude-code"
  OTEL_RESOURCE_ATTRIBUTES: "team=engineering,department=product"
```

然後在 Pod 中引用：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: claude-code-client
spec:
  containers:
  - name: claude-code
    image: your-image
    envFrom:
    - configMapRef:
        name: claude-code-env
```

## 本地開發環境設定

在本地開發環境中，你可以：

### 1. 使用 Port Forward 連接到 Kubernetes 集群

```bash
# 轉發 OTEL Collector 端口
kubectl port-forward -n claude-monitoring svc/otel-collector 4317:4317

# 然後設定環境變數
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
```

### 2. 使用 .env 文件

創建 `.env` 文件：

```
CLAUDE_CODE_ENABLE_TELEMETRY=1
OTEL_METRICS_EXPORTER=otlp
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
OTEL_SERVICE_NAME=claude-code
OTEL_RESOURCE_ATTRIBUTES=team=engineering,environment=development
```

### 3. 使用 Shell Script

創建 `setup-claude-monitoring.sh`：

```bash
#!/bin/bash

# 設定 Claude Code 監控環境變數
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_SERVICE_NAME=claude-code
export OTEL_RESOURCE_ATTRIBUTES=team=engineering,environment=development

echo "Claude Code 監控環境變數已設定"
echo "OTLP 端點: $OTEL_EXPORTER_OTLP_ENDPOINT"
echo "請確保 OTEL Collector 正在運行"

# 可選：啟動 Claude Code
# claude-code
```

使用方式：

```bash
chmod +x setup-claude-monitoring.sh
source ./setup-claude-monitoring.sh
```

## 驗證設定

設定完成後，你可以通過以下方式驗證：

1. **檢查環境變數**：
   ```bash
   echo $CLAUDE_CODE_ENABLE_TELEMETRY
   echo $OTEL_EXPORTER_OTLP_ENDPOINT
   ```

2. **檢查 OTEL Collector 日誌**：
   ```bash
   kubectl logs -n claude-monitoring deployment/otel-collector
   ```

3. **檢查 Prometheus 指標**：
   ```bash
   kubectl port-forward -n claude-monitoring svc/prometheus 9090:9090
   # 然後訪問 http://localhost:9090 查看指標
   ```

4. **檢查 Grafana 儀表板**：
   ```bash
   kubectl port-forward -n claude-monitoring svc/grafana 3000:3000
   # 然後訪問 http://localhost:3000 (admin/admin)
   ```

## 常見問題

### Q: 為什麼沒有看到監控數據？
A: 請確認：
- 環境變數正確設定
- OTEL Collector 正在運行且可訪問
- Claude Code 正在產生活動
- 防火牆沒有阻擋端口 4317/4318

### Q: 如何添加自定義標籤？
A: 通過 `OTEL_RESOURCE_ATTRIBUTES` 環境變數添加：
```bash
export OTEL_RESOURCE_ATTRIBUTES=team=engineering,department=product,user=john
```

### Q: 如何在生產環境中安全地設定環境變數？
A: 建議使用 Kubernetes Secrets 或 ConfigMaps，並通過 RBAC 控制訪問權限。