#!/bin/bash

# Btrfs 快照服务混合压测脚本
# 包含创建、查询、删除快照的完整测试流程

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印彩色信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 配置参数
SERVER_URL="http://localhost:8080"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="reports"

# 检查服务状态
check_server() {
    print_info "检查服务状态..."
    if curl -s --connect-timeout 5 "$SERVER_URL/api/v1/snapshots" > /dev/null; then
        print_success "服务运行正常"
        return 0
    else
        print_error "服务未运行或无法连接到 $SERVER_URL"
        return 1
    fi
}

# 检查wrk是否安装
check_wrk() {
    if ! command -v wrk &> /dev/null; then
        print_error "wrk 未安装，请先安装 wrk"
        print_info "Ubuntu/Debian: sudo apt-get install wrk"
        print_info "macOS: brew install wrk"
        exit 1
    fi
    print_success "wrk 已安装"
}

# 清理环境
cleanup_environment() {
    print_info "清理测试环境..."
    response=$(curl -s -X DELETE "$SERVER_URL/api/v1/snapshots/all")
    if echo "$response" | grep -q '"success":true'; then
        deleted_count=$(echo "$response" | grep -o '"count":[0-9]*' | cut -d':' -f2)
        print_success "清理完成，删除了 $deleted_count 个快照"
    else
        print_warning "清理过程中出现问题，但继续测试"
    fi
}

# 创建报告目录
create_report_dir() {
    mkdir -p "$REPORT_DIR"
    timestamp=$(date '+%Y%m%d_%H%M%S')
    export REPORT_PREFIX="$REPORT_DIR/mixed_test_$timestamp"
}

# 运行混合压测
run_mixed_test() {
    local connections=${1:-20}
    local duration=${2:-30}
    
    print_info "开始混合压测 - 连接数: $connections, 持续时间: ${duration}秒"
    
    create_report_dir
    
    # 阶段1: 创建快照压测
    print_info "阶段1: 创建快照压测 (${duration}秒)"
    wrk -t4 -c$connections -d${duration}s --latency \
        -s "$SCRIPT_DIR/create_snapshot.lua" \
        "$SERVER_URL" > "${REPORT_PREFIX}_create.txt" 2>&1
    
    # 等待系统稳定
    sleep 3
    
    # 阶段2: 查询快照压测
    print_info "阶段2: 查询快照压测 (${duration}秒)"
    wrk -t4 -c$((connections * 2)) -d${duration}s --latency \
        "$SERVER_URL/api/v1/snapshots" > "${REPORT_PREFIX}_query.txt" 2>&1
    
    # 等待系统稳定
    sleep 3
    
    # 阶段3: 删除快照压测
    print_info "阶段3: 删除快照压测 (10秒)"
    wrk -t2 -c5 -d10s --latency \
        -s "$SCRIPT_DIR/delete_all.lua" \
        "$SERVER_URL" > "${REPORT_PREFIX}_delete.txt" 2>&1
    
    # 生成综合报告
    generate_summary_report "$REPORT_PREFIX"
    
    print_success "混合压测完成"
    print_info "报告文件已保存到 $REPORT_DIR 目录"
}

# 生成综合报告
generate_summary_report() {
    local prefix="$1"
    local summary_file="${prefix}_summary.txt"
    
    cat > "$summary_file" << EOF
Btrfs 快照服务混合压测综合报告
==================================
测试时间: $(date '+%Y-%m-%d %H:%M:%S')
测试参数: 连接数=$connections, 持续时间=${duration}秒

阶段1: 创建快照压测结果
----------------------
EOF
    
    if [[ -f "${prefix}_create.txt" ]]; then
        grep -E "Requests/sec|Latency|requests in" "${prefix}_create.txt" >> "$summary_file" || true
    fi
    
    cat >> "$summary_file" << EOF

阶段2: 查询快照压测结果
----------------------
EOF
    
    if [[ -f "${prefix}_query.txt" ]]; then
        grep -E "Requests/sec|Latency|requests in" "${prefix}_query.txt" >> "$summary_file" || true
    fi
    
    cat >> "$summary_file" << EOF

阶段3: 删除快照压测结果
----------------------
EOF
    
    if [[ -f "${prefix}_delete.txt" ]]; then
        grep -E "Requests/sec|Latency|requests in" "${prefix}_delete.txt" >> "$summary_file" || true
    fi
    
    echo "" >> "$summary_file"
    echo "详细报告文件:" >> "$summary_file"
    echo "- 创建快照: ${prefix}_create.txt" >> "$summary_file"
    echo "- 查询快照: ${prefix}_query.txt" >> "$summary_file"
    echo "- 删除快照: ${prefix}_delete.txt" >> "$summary_file"
    
    print_success "综合报告已生成: $summary_file"
}

# 阶梯式压测
run_step_test() {
    print_info "开始阶梯式压测..."
    
    create_report_dir
    local step_report="${REPORT_PREFIX}_step_test.txt"
    
    echo "Btrfs 快照服务阶梯式压测报告" > "$step_report"
    echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$step_report"
    echo "======================================" >> "$step_report"
    
    for connections in 10 25 50 100 200; do
        print_info "测试并发数: $connections"
        echo "" >> "$step_report"
        echo "并发数: $connections" >> "$step_report"
        echo "-------------------" >> "$step_report"
        
        # 清理环境
        cleanup_environment
        
        # 运行创建快照压测
        print_info "运行创建快照压测 (30秒)"
        wrk -t8 -c$connections -d30s --latency \
            -s "$SCRIPT_DIR/create_snapshot.lua" \
            "$SERVER_URL" | tee -a "$step_report"
        
        # 等待系统稳定
        sleep 5
    done
    
    print_success "阶梯式压测完成"
    print_info "报告文件: $step_report"
}

# 性能监控测试
run_monitor_test() {
    print_info "开始性能监控测试..."
    
    # 启动系统监控
    monitor_pid=""
    if command -v iostat &> /dev/null; then
        iostat -x 2 > "${REPORT_PREFIX}_iostat.log" &
        monitor_pid="$!"
        print_info "已启动磁盘IO监控"
    fi
    
    # 运行压测
    run_mixed_test 50 60
    
    # 停止监控
    if [[ -n "$monitor_pid" ]]; then
        kill "$monitor_pid" 2>/dev/null || true
        print_info "已停止系统监控"
    fi
    
    # 收集Btrfs统计信息
    if command -v btrfs &> /dev/null; then
        print_info "收集Btrfs统计信息..."
        {
            echo "Btrfs 文件系统使用情况:"
            sudo btrfs filesystem usage /data 2>/dev/null || echo "无法获取Btrfs使用情况"
            echo ""
            echo "Btrfs 子卷列表:"
            sudo btrfs subvolume list /data 2>/dev/null || echo "无法获取子卷列表"
        } > "${REPORT_PREFIX}_btrfs_stats.txt"
    fi
}

# 显示帮助信息
show_help() {
    echo "Btrfs 快照服务 wrk 压测脚本"
    echo ""
    echo "用法: $0 [选项] [参数]"
    echo ""
    echo "选项:"
    echo "  mixed [连接数] [持续时间]  运行混合压测 (默认: 20 30)"
    echo "  step                      运行阶梯式压测"
    echo "  monitor                   运行带性能监控的压测"
    echo "  check                     检查环境和服务状态"
    echo "  clean                     清理测试数据"
    echo "  help                      显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 mixed                  # 默认混合压测"
    echo "  $0 mixed 50 60           # 50连接，60秒混合压测"
    echo "  $0 step                  # 阶梯式压测"
    echo "  $0 monitor               # 带监控的压测"
}

# 主函数
main() {
    case "${1:-mixed}" in
        "mixed")
            check_wrk
            check_server || exit 1
            cleanup_environment
            run_mixed_test "${2:-20}" "${3:-30}"
            ;;
        "step")
            check_wrk
            check_server || exit 1
            run_step_test
            ;;
        "monitor")
            check_wrk
            check_server || exit 1
            run_monitor_test
            ;;
        "check")
            check_wrk
            check_server
            ;;
        "clean")
            cleanup_environment
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 脚本入口
main "$@" 