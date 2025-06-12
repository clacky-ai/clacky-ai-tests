#!/bin/bash

# Btrfs 快照服务快速压测脚本
# 适合快速验证服务性能和功能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 配置
SERVER_URL="http://localhost:8080"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查环境
check_environment() {
    print_info "检查测试环境..."
    
    # 检查wrk
    if ! command -v wrk &> /dev/null; then
        print_error "wrk 未安装，请先安装 wrk"
        echo "安装命令："
        echo "  Ubuntu/Debian: sudo apt-get install wrk"
        echo "  macOS: brew install wrk"
        exit 1
    fi
    
    # 检查服务
    if ! curl -s --connect-timeout 5 "$SERVER_URL/api/v1/snapshots" > /dev/null; then
        print_error "Btrfs 快照服务未运行"
        print_info "请先启动服务: cd clack-ai-btrfs-test && ./run.sh start"
        exit 1
    fi
    
    print_success "环境检查通过"
}

# 清理测试数据
cleanup() {
    print_info "清理测试数据..."
    curl -s -X DELETE "$SERVER_URL/api/v1/snapshots/all" > /dev/null
    print_success "清理完成"
}

# 快速功能测试
quick_function_test() {
    print_info "执行快速功能测试..."
    
    # 测试创建快照
    print_info "测试创建快照..."
    response=$(curl -s -X POST "$SERVER_URL/api/v1/snapshots/create")
    if echo "$response" | grep -q '"success":true'; then
        print_success "创建快照成功"
        snapshot_uuid=$(echo "$response" | grep -o '"uuid":"[^"]*"' | cut -d'"' -f4)
        print_info "快照UUID: $snapshot_uuid"
    else
        print_error "创建快照失败: $response"
        return 1
    fi
    
    # 测试查询快照
    print_info "测试查询快照..."
    response=$(curl -s "$SERVER_URL/api/v1/snapshots")
    if echo "$response" | grep -q '"success":true'; then
        snapshot_count=$(echo "$response" | grep -o '"count":[0-9]*' | cut -d':' -f2)
        print_success "查询快照成功，共 $snapshot_count 个快照"
    else
        print_error "查询快照失败: $response"
        return 1
    fi
    
    # 测试删除快照
    print_info "测试删除快照..."
    response=$(curl -s -X DELETE "$SERVER_URL/api/v1/snapshots/all")
    if echo "$response" | grep -q '"success":true'; then
        deleted_count=$(echo "$response" | grep -o '"count":[0-9]*' | cut -d':' -f2)
        print_success "删除快照成功，删除了 $deleted_count 个快照"
    else
        print_error "删除快照失败: $response"
        return 1
    fi
    
    print_success "功能测试通过"
}

# 快速性能测试
quick_performance_test() {
    print_info "执行快速性能测试..."
    
    # 创建快照性能测试
    print_info "测试创建快照性能 (10连接, 10秒)..."
    wrk -t2 -c10 -d10s --latency -s "$SCRIPT_DIR/create_snapshot.lua" "$SERVER_URL"
    
    sleep 2
    
    # 查询快照性能测试
    print_info "测试查询快照性能 (20连接, 10秒)..."
    wrk -t2 -c20 -d10s --latency "$SERVER_URL/api/v1/snapshots"
    
    sleep 2
    
    # 清理数据
    cleanup
    
    print_success "性能测试完成"
}

# 中等强度性能测试
medium_performance_test() {
    print_info "执行中等强度性能测试..."
    
    cleanup
    
    # 创建快照测试
    print_info "创建快照测试 (50连接, 30秒)..."
    wrk -t4 -c50 -d30s --latency -s "$SCRIPT_DIR/create_snapshot.lua" "$SERVER_URL" | tee create_test_result.txt
    
    sleep 3
    
    # 查询快照测试
    print_info "查询快照测试 (100连接, 20秒)..."
    wrk -t4 -c100 -d20s --latency "$SERVER_URL/api/v1/snapshots" | tee query_test_result.txt
    
    sleep 3
    
    # 删除快照测试
    print_info "删除快照测试 (10连接, 5秒)..."
    wrk -t2 -c10 -d5s --latency -s "$SCRIPT_DIR/delete_all.lua" "$SERVER_URL" | tee delete_test_result.txt
    
    print_success "中等强度测试完成"
    print_info "结果已保存到 *_test_result.txt 文件"
}

# 压力测试
stress_test() {
    print_info "执行压力测试 (高并发)..."
    print_warning "这将产生高负载，请确保系统有足够资源"
    
    read -p "确认继续压力测试？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "取消压力测试"
        return
    fi
    
    cleanup
    
    # 高并发创建快照测试
    print_info "高并发创建快照测试 (200连接, 60秒)..."
    wrk -t8 -c200 -d60s --latency -s "$SCRIPT_DIR/create_snapshot.lua" "$SERVER_URL" | tee stress_create_result.txt
    
    sleep 5
    
    # 高并发查询测试
    print_info "高并发查询测试 (500连接, 30秒)..."
    wrk -t12 -c500 -d30s --latency "$SERVER_URL/api/v1/snapshots" | tee stress_query_result.txt
    
    sleep 5
    
    # 清理
    cleanup
    
    print_success "压力测试完成"
    print_info "结果已保存到 stress_*_result.txt 文件"
}

# 显示系统信息
show_system_info() {
    print_info "系统信息:"
    echo "操作系统: $(uname -s)"
    echo "内核版本: $(uname -r)"
    echo "CPU核心数: $(nproc 2>/dev/null || echo "未知")"
    echo "内存信息: $(free -h 2>/dev/null | grep Mem || echo "未知")"
    
    if command -v btrfs &> /dev/null; then
        echo "Btrfs版本: $(btrfs --version 2>/dev/null || echo "未知")"
        if [[ -d "/data" ]]; then
            echo "Btrfs使用情况:"
            sudo btrfs filesystem usage /data 2>/dev/null || echo "无法获取Btrfs使用情况"
        fi
    fi
    
    echo "wrk版本: $(wrk --version 2>&1 | head -1 || echo "未知")"
}

# 显示帮助
show_help() {
    echo "Btrfs 快照服务快速压测工具"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  function      快速功能测试 (验证API功能)"
    echo "  quick         快速性能测试 (轻量级)"
    echo "  medium        中等强度测试 (推荐)"
    echo "  stress        压力测试 (高负载)"
    echo "  all           执行所有测试"
    echo "  info          显示系统信息"
    echo "  clean         清理测试数据"
    echo "  check         检查环境"
    echo "  help          显示此帮助"
    echo ""
    echo "示例:"
    echo "  $0 function   # 功能测试"
    echo "  $0 medium     # 中等强度测试"
    echo "  $0 all        # 完整测试"
}

# 执行所有测试
run_all_tests() {
    print_info "开始完整测试流程..."
    
    # 功能测试
    quick_function_test
    echo ""
    
    # 快速性能测试
    quick_performance_test
    echo ""
    
    # 中等强度测试
    medium_performance_test
    echo ""
    
    print_success "所有测试完成！"
    print_info "建议查看生成的结果文件了解详细性能数据"
}

# 主函数
main() {
    case "${1:-quick}" in
        "function")
            check_environment
            quick_function_test
            ;;
        "quick")
            check_environment
            quick_performance_test
            ;;
        "medium")
            check_environment
            medium_performance_test
            ;;
        "stress")
            check_environment
            stress_test
            ;;
        "all")
            check_environment
            run_all_tests
            ;;
        "info")
            show_system_info
            ;;
        "clean")
            cleanup
            ;;
        "check")
            check_environment
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 脚本入口
main "$@" 