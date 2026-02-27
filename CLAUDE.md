# CLAUDE.md

本文件为 Claude Code（claude.ai/code）在此仓库中工作时提供指导。

## 项目概述

本仓库是 clacky-ai 平台的性能与压力测试仓库，包含多个微服务的 JMeter 测试计划，以及一个基于 Go 的 BTRFS 快照压测服务。

## 运行测试

### JMeter 测试（主测试入口）

```sh
./run.sh <project_name> <test_name> <threads> <rampup>
```

该脚本以非 GUI 模式运行 JMeter，JVM 堆内存为 12–16 GB，结果以 CSV 格式写入 `<project_name>/results/`，HTML 报告写入 `<project_name>/reports/`，并自动将报告目录打包为 tar 文件。

**常用测试命令：**
```sh
# 单测（2025-05-24 起最新脚本，含同步计数器）
./run.sh clacky-ai-single-test clacky-ai-single-test-v2 10 0

# 系统测试
./run.sh clacky-ai-system-test clackyai_system_test 10 0

# Issue 线程测试
./run.sh clacky-ai-issue-thread-test clackyai_issue_thread_test 50 50

# 从零到一线程测试
./run.sh clacky-ai-zerotoone-test clackyai_zerotoone_test 10 30
```

`-Jthreads` 和 `-Jrampup` 参数传递给 JMeter，测试计划通过 `${__P(threads, 1)}` 和 `${__P(rampup, 0)}` 读取。

### BTRFS 快照服务（clack-ai-btrfs-test/）

```sh
# 构建并启动 HTTP 服务器（需要 root 权限、Go 1.21+、btrfs-progs）
./run.sh start

# 运行内置压测（5 并发，20 个快照）
./run.sh test

# 自定义压测参数
./benchmark-tool -c 10 -n 100
./benchmark-tool -cleanup-only

# 仅构建
./run.sh build
go build -o btrfs-server main.go
go build -o benchmark-tool cmd/benchmark/main.go
```

服务默认监听 `http://localhost:8080`，需要 `/data/@meta` btrfs 子卷及 root 权限。

### WRK 压测（针对 BTRFS 服务）

```sh
wrk -t4 -c10 -d30s -s scripts/create_snapshot.lua http://localhost:8080
wrk -t4 -c50 -d30s http://localhost:8080/api/v1/snapshots
```

脚本文件：`scripts/create_snapshot.lua`、`scripts/delete_all.lua`。综合场景脚本：`scripts/mixed_test.sh`、`scripts/step_test.sh`、`scripts/quick_test.sh`。

## 架构说明

### 项目目录结构

每个 `clacky-ai-*-test/` 目录都是独立的测试套件：
- `tests/` — JMeter `.jmx` 测试计划
- `results/` — 原始 CSV 测试结果
- `reports/` — 生成的 HTML 报告 + `.tar` 归档包

| 目录 | 用途 |
|------|------|
| `clacky-ai-single-test/` | 单用户 API 测试；v2 版本添加同步计数器以提升准确性 |
| `clacky-ai-system-test/` | 全系统集成压测 |
| `clacky-ai-issue-thread-test/` | Issue/线程处理压测（包含多工程师变体版本） |
| `clacky-ai-root-thread-test/` | Root 线程流程压测 |
| `clacky-ai-zerotoone-test/` | 从零到一线程创建流程压测 |
| `clacky-ai-backend/` | 后端 API 单测 |
| `clacky-ai-paas-manager/` | PaaS 管理器单测 |
| `clack-ai-btrfs-test/` | Go HTTP 服务 + BTRFS 快照压测工具 |

### JMeter 测试计划结构

所有 `.jmx` 文件遵循统一模式：
- 线程组通过 `${__P(threads, 1)}` 和 `${__P(rampup, 0)}` 参数化
- 用户自定义变量指定目标域名（`PAAS_DOMAIN`、`BACKEND_DOMAIN`），分别对应 `staging.clackypaas.com` / `staging.api.clackyai.com`
- 每个线程随机生成连接 ID 和会话 Token
- HTTP 采样器包含 AI 任务线程的 SSE/WebSocket 流

### BTRFS 服务架构（`clack-ai-btrfs-test/`）

- `main.go` — Gin HTTP 服务器，提供快照 CRUD 路由
- `btrfs/btrfs.go` — 底层 BTRFS 子卷操作（需要 root 权限）
- `benchmark.go` — 内置工具使用的并发压测逻辑
- `cmd/benchmark/main.go` — 压测工具 CLI 入口

REST API：
- `POST /api/v1/snapshots/create` — 从 `/data/@meta` 创建快照
- `GET /api/v1/snapshots` — 列出 `/data/@data/test/` 下的测试快照
- `DELETE /api/v1/snapshots/all` — 删除所有测试快照

## 报告分发

将生成的 HTML 报告复制到 Nginx 供团队访问：
```sh
cp -RP <project>/reports/<report_dir> /var/www/html/reports/
cp -RP jmeter /var/www/html/logs/jmeter-<name>.log
```

Nginx 以 `autoindex on` 方式托管 `/var/www/html`，支持目录浏览。

## 注意事项

- 单测请优先使用 `clacky-ai-single-test-v2` 脚本（2025-05-24 新增），相比 v1 增加了同步计数器，可消除测量误差。
- JMeter 需安装并加入 `$PATH`。运行脚本设置了 `JVM_ARGS="-Xms12g -Xmx16g"`，请确保压测机器有足够内存。
- BTRFS 服务需要 Linux 系统及 btrfs-progs，在 macOS 上无法运行。
