#!/usr/bin/env bash
set -euo pipefail

# 本地开发一键启动脚本。
# 保留简短注释和用法说明，方便开发者直接在终端执行。
# 更完整文档见 /docs；这里的说明用于快速上手。
# 用法：./scripts/run_local_compose.sh [docker-compose.local.yml]

COMPOSE_FILE=${1:-docker-compose.local.yml}
LOG_DIR="data/docker-logs"
mkdir -p "$LOG_DIR"

echo "使用的 compose 文件: $COMPOSE_FILE"

if ! command -v docker >/dev/null 2>&1; then
  echo "错误：未找到 docker 命令。请先安装 Docker Desktop 或 Docker Engine。" >&2
  exit 2
fi

# 快速检查 Docker daemon 是否可连接
if ! docker info >/dev/null 2>&1; then
  echo "错误：无法连接到 Docker daemon。请确认 Docker Desktop / daemon 已启动；若使用 WSL，请确认该发行版已启用集成。" >&2
  echo "你也可以在远程 Docker 引擎可用时设置 DOCKER_HOST。" >&2
  exit 3
fi

echo "开始构建镜像（不使用缓存）..."
# 同时兼容 `docker compose` 与 `docker-compose`
if docker compose version >/dev/null 2>&1; then
  docker compose -f "$COMPOSE_FILE" build --no-cache
else
  docker-compose -f "$COMPOSE_FILE" build --no-cache
fi

echo "启动容器（后台运行，强制重建）..."
if docker compose version >/dev/null 2>&1; then
  docker compose -f "$COMPOSE_FILE" up -d --force-recreate --remove-orphans
else
  docker-compose -f "$COMPOSE_FILE" up -d --force-recreate --remove-orphans
fi

echo "收集主要服务状态与日志..."
SERVICES=(backend redis postgres qdrant mcp frontend playwright-mcp)

if docker compose version >/dev/null 2>&1; then
  docker compose -f "$COMPOSE_FILE" ps
else
  docker-compose -f "$COMPOSE_FILE" ps
fi

for svc in "${SERVICES[@]}"; do
  echo "--- 日志: $svc（最近 200 行）---"
  if docker compose version >/dev/null 2>&1; then
    docker compose -f "$COMPOSE_FILE" logs --tail 200 "$svc" | tee "$LOG_DIR/$svc.log" || true
  else
    docker-compose -f "$COMPOSE_FILE" logs --tail 200 "$svc" | tee "$LOG_DIR/$svc.log" || true
  fi
done

echo "日志已保存到 $LOG_DIR/*.log"
echo "如果服务启动失败，请先查看日志，并检查端口占用与宿主机挂载文件是否可用。"

cat <<'EOF'
说明:
- 请在 Docker daemon 已启动且可访问的环境中执行本脚本。
- 在 WSL2 下，请先启动 Windows Docker Desktop 并开启该发行版的 WSL 集成；或在 WSL 内自行运行 Docker Engine。
- 若在 CI 无交互执行，请设置 DOCKER_BUILDKIT=1，并配置私有镜像仓库凭据。
EOF

exit 0
