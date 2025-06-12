# Clacky AI Btrfs 快照压测服务

这是一个基于 Go 和 Gin 框架开发的 Btrfs 文件系统快照压测服务，提供 HTTP API 接口用于创建、查询和删除 Btrfs 快照。

## 功能特性

- 🚀 高性能的 HTTP API 服务
- 📸 支持从源子卷 `/data/@meta` 创建快照
- 📋 支持列出所有测试快照
- 🗑️ 支持批量删除测试快照
- 🔧 内置压测工具和环境检查
- 📊 支持 wrk 等第三方压测工具

## 系统要求

- Go 1.19+
- Btrfs 文件系统
- btrfs-progs 工具包
- Root 权限（用于 Btrfs 操作）

## 安装与配置

### 1. 环境准备

```bash
# 检查 Btrfs 支持
sudo btrfs --version

# 创建必要的目录和子卷
sudo mkdir -p /data
sudo btrfs subvolume create /data/@meta
sudo mkdir -p /data/@data/test
```

### 2. 项目构建

```bash
# 构建项目
./run.sh build

# 或者直接构建
go build -o btrfs-server main.go
go build -o benchmark-tool cmd/benchmark/main.go
```

### 3. 启动服务

```bash
# 启动服务（包含环境检查和构建）
./run.sh start

# 或者直接启动
sudo ./btrfs-server
```

服务默认监听 `http://localhost:8080`

## API 接口

### 创建快照

```bash
POST /api/v1/snapshots/create
```

**响应示例：**
```json
{
    "success": true,
    "snapshot_path": "/data/@data/test/@12345678-1234-1234-1234-123456789abc",
    "uuid": "12345678-1234-1234-1234-123456789abc"
}
```

### 列出快照

```bash
GET /api/v1/snapshots
```

**响应示例：**
```json
{
    "success": true,
    "snapshots": [
        "/data/@data/test/@12345678-1234-1234-1234-123456789abc",
        "/data/@data/test/@87654321-4321-4321-4321-cba987654321"
    ],
    "count": 2
}
```

### 删除所有快照

```bash
DELETE /api/v1/snapshots/all
```

**响应示例：**
```json
{
    "success": true,
    "deleted": [
        "/data/@data/test/@12345678-1234-1234-1234-123456789abc",
        "/data/@data/test/@87654321-4321-4321-4321-cba987654321"
    ],
    "count": 2
}
```

## wrk 压测使用指南

### 1. 安装 wrk

**Ubuntu/Debian:**
```bash
sudo apt-get install wrk
```

**CentOS/RHEL:**
```bash
sudo yum install wrk
```

**macOS:**
```bash
brew install wrk
```

**编译安装:**
```bash
git clone https://github.com/wg/wrk.git
cd wrk
make
sudo cp wrk /usr/local/bin/
```

### 2. 基本压测命令

#### 创建快照压测

```bash
# 基本压测：10个连接，持续30秒
wrk -t4 -c10 -d30s -s scripts/create_snapshot.lua http://localhost:8080

# 高并发压测：100个连接，持续60秒
wrk -t8 -c100 -d60s -s scripts/create_snapshot.lua http://localhost:8080

# 极限压测：500个连接，持续120秒
wrk -t12 -c500 -d120s -s scripts/create_snapshot.lua http://localhost:8080
```

#### 查询快照压测

```bash
# 查询快照列表压测
wrk -t4 -c50 -d30s http://localhost:8080/api/v1/snapshots

# 高并发查询压测
wrk -t8 -c200 -d60s http://localhost:8080/api/v1/snapshots
```

### 3. wrk 脚本配置

创建 `scripts/create_snapshot.lua` 文件：

```lua
-- create_snapshot.lua
wrk.method = "POST"
wrk.body   = ""
wrk.headers["Content-Type"] = "application/json"

request = function()
    path = "/api/v1/snapshots/create"
    return wrk.format(wrk.method, path)
end

response = function(status, headers, body)
    if status ~= 201 then
        print("Error response: " .. status .. " " .. body)
    end
end

done = function(summary, latency, requests)
    io.write("------------------------------\n")
    io.write("压测结果统计:\n")
    io.write(string.format("请求总数: %d\n", summary.requests))
    io.write(string.format("总耗时: %.2f秒\n", summary.duration/1000000))
    io.write(string.format("QPS: %.2f\n", summary.requests/(summary.duration/1000000)))
    io.write(string.format("平均延迟: %.2fms\n", latency.mean/1000))
    io.write(string.format("最大延迟: %.2fms\n", latency.max/1000))
    io.write("------------------------------\n")
end
```

创建 `scripts/delete_all.lua` 文件：

```lua
-- delete_all.lua
wrk.method = "DELETE"
wrk.headers["Content-Type"] = "application/json"

request = function()
    path = "/api/v1/snapshots/all"
    return wrk.format(wrk.method, path)
end

response = function(status, headers, body)
    if status ~= 200 then
        print("Error response: " .. status .. " " .. body)
    end
end
```

### 4. 综合压测场景

#### 场景1：混合读写压测

```bash
#!/bin/bash
# mixed_test.sh

echo "开始混合压测..."

# 1. 清理环境
curl -X DELETE http://localhost:8080/api/v1/snapshots/all

# 2. 创建快照压测 (30秒)
echo "阶段1: 创建快照压测"
wrk -t4 -c20 -d30s -s scripts/create_snapshot.lua http://localhost:8080

# 3. 查询压测 (20秒)
echo "阶段2: 查询快照压测"
wrk -t4 -c50 -d20s http://localhost:8080/api/v1/snapshots

# 4. 删除压测 (10秒)
echo "阶段3: 删除快照压测"
wrk -t2 -c5 -d10s -s scripts/delete_all.lua http://localhost:8080

echo "混合压测完成"
```

#### 场景2：阶梯式压测

```bash
#!/bin/bash
# step_test.sh

echo "开始阶梯式压测..."

for connections in 10 50 100 200 500; do
    echo "测试并发数: $connections"
    
    # 清理环境
    curl -X DELETE http://localhost:8080/api/v1/snapshots/all
    
    # 运行压测
    wrk -t8 -c$connections -d30s -s scripts/create_snapshot.lua http://localhost:8080
    
    # 等待系统稳定
    sleep 5
done

echo "阶梯式压测完成"
```

### 5. 压测参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| -t | 线程数 | -t4 (4个线程) |
| -c | 连接数 | -c100 (100个连接) |
| -d | 持续时间 | -d30s (30秒) |
| -s | Lua脚本 | -s script.lua |
| --timeout | 超时时间 | --timeout 30s |
| --latency | 显示延迟统计 | --latency |

### 6. 性能监控

在压测过程中，建议同时监控系统性能：

```bash
# 监控系统资源
htop

# 监控磁盘IO
iostat -x 1

# 监控Btrfs特定信息
sudo btrfs filesystem usage /data
sudo btrfs subvolume list /data

# 监控网络连接
ss -tuln | grep 8080
```

### 7. 压测最佳实践

1. **渐进式压测**：从低并发开始，逐步增加
2. **环境预热**：正式压测前先进行预热
3. **监控指标**：关注CPU、内存、磁盘IO和网络
4. **清理数据**：每次压测前清理旧的快照数据
5. **多次测试**：进行多轮测试取平均值
6. **记录结果**：保存压测结果用于对比分析

## 内置压测工具

除了 wrk，项目还提供了内置的压测工具：

```bash
# 运行内置压测（5个并发，20个快照）
./run.sh test

# 自定义参数运行
./benchmark-tool -c 10 -n 100

# 仅清理快照
./benchmark-tool -cleanup-only
```

## 故障排除

### 常见问题

1. **权限错误**：确保使用 sudo 运行服务
2. **子卷不存在**：检查 `/data/@meta` 是否存在
3. **端口占用**：检查 8080 端口是否被占用
4. **磁盘空间不足**：清理旧快照释放空间

### 日志查看

```bash
# 查看服务日志
journalctl -f -u btrfs-server

# 查看系统日志
dmesg | grep btrfs
```

## 贡献指南

欢迎提交 Issues 和 Pull Requests 来改进项目。

## 许可证

MIT License 