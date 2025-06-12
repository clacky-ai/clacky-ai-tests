#!/bin/bash

# Btrfs 快照服务阶梯式压测脚本
# 用于测试不同并发数下的性能表现

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

# 默认测试参数
DEFAULT_CONNECTIONS=(10 25 50 100 200 500)
DEFAULT_DURATION=30
DEFAULT_THREADS=8

# 检查环境
check_environment() {
    # 检查wrk
    if ! command -v wrk &> /dev/null; then
        print_error "wrk 未安装"
        exit 1
    fi
    
    # 检查服务
    if ! curl -s --connect-timeout 5 "$SERVER_URL/api/v1/snapshots" > /dev/null; then
        print_error "服务未运行，请先启动 Btrfs 快照服务"
        exit 1
    fi
    
    print_success "环境检查通过"
}

# 清理测试环境
cleanup_snapshots() {
    print_info "清理测试快照..."
    curl -s -X DELETE "$SERVER_URL/api/v1/snapshots/all" > /dev/null
}

# 运行单个连接数测试
run_single_test() {
    local connections=$1
    local duration=$2
    local threads=$3
    local test_type=$4
    local output_file=$5
    
    print_info "测试并发数: $connections, 持续时间: ${duration}秒, 线程数: $threads"
    
    case "$test_type" in
        "create")
            wrk -t$threads -c$connections -d${duration}s --latency \
                -s "$SCRIPT_DIR/create_snapshot.lua" \
                "$SERVER_URL" > "$output_file" 2>&1
            ;;
        "query")
            wrk -t$threads -c$connections -d${duration}s --latency \
                "$SERVER_URL/api/v1/snapshots" > "$output_file" 2>&1
            ;;
        "delete")
            wrk -t$threads -c$connections -d${duration}s --latency \
                -s "$SCRIPT_DIR/delete_all.lua" \
                "$SERVER_URL" > "$output_file" 2>&1
            ;;
    esac
}

# 提取性能指标
extract_metrics() {
    local file=$1
    local connections=$2
    
    if [[ ! -f "$file" ]]; then
        echo "$connections,0,0,0,0,0,0,0"
        return
    fi
    
    local requests_sec=$(grep "Requests/sec:" "$file" | awk '{print $2}' | head -1)
    local avg_latency=$(grep "Latency" "$file" | awk '{print $2}' | head -1 | sed 's/ms//')
    local p50_latency=$(grep "50%" "$file" | awk '{print $2}' | sed 's/ms//')
    local p90_latency=$(grep "90%" "$file" | awk '{print $2}' | sed 's/ms//')
    local p99_latency=$(grep "99%" "$file" | awk '{print $2}' | sed 's/ms//')
    local max_latency=$(grep "Latency" "$file" | awk '{print $4}' | head -1 | sed 's/ms//')
    local total_requests=$(grep "requests in" "$file" | awk '{print $1}')
    
    # 处理空值
    requests_sec=${requests_sec:-0}
    avg_latency=${avg_latency:-0}
    p50_latency=${p50_latency:-0}
    p90_latency=${p90_latency:-0}
    p99_latency=${p99_latency:-0}
    max_latency=${max_latency:-0}
    total_requests=${total_requests:-0}
    
    echo "$connections,$requests_sec,$avg_latency,$p50_latency,$p90_latency,$p99_latency,$max_latency,$total_requests"
}

# 生成CSV报告
generate_csv_report() {
    local test_type=$1
    local csv_file="$2"
    local temp_dir="$3"
    
    # CSV头部
    echo "Connections,QPS,AvgLatency(ms),P50(ms),P90(ms),P99(ms),MaxLatency(ms),TotalRequests" > "$csv_file"
    
    # 提取每个测试的数据
    for connections in "${DEFAULT_CONNECTIONS[@]}"; do
        local output_file="$temp_dir/${test_type}_${connections}.txt"
        extract_metrics "$output_file" "$connections" >> "$csv_file"
    done
    
    print_success "CSV报告已生成: $csv_file"
}

# 生成性能对比图表数据
generate_chart_data() {
    local csv_file="$1"
    local chart_file="${csv_file%.csv}_chart.txt"
    
    print_info "生成图表数据文件: $chart_file"
    
    cat > "$chart_file" << 'EOF'
# 使用以下数据在图表工具中创建性能对比图表
# 
# 建议使用的图表类型:
# 1. QPS vs 并发数 - 折线图
# 2. 延迟 vs 并发数 - 多条线图表 (P50, P90, P99)
# 3. 延迟分布 - 箱线图
#
# 数据格式: 并发数,QPS,平均延迟,P50,P90,P99,最大延迟,总请求数

EOF
    
    cat "$csv_file" >> "$chart_file"
    
    cat >> "$chart_file" << 'EOF'

# Excel/Google Sheets 导入说明:
# 1. 复制上述CSV数据
# 2. 粘贴到电子表格中
# 3. 创建折线图，X轴为Connections，Y轴为QPS
# 4. 创建第二个图表显示延迟指标

# Python matplotlib 示例代码:
"""
import pandas as pd
import matplotlib.pyplot as plt

# 读取数据
df = pd.read_csv('chart_file.csv')

# 创建QPS图表
plt.figure(figsize=(12, 6))
plt.subplot(1, 2, 1)
plt.plot(df['Connections'], df['QPS'], marker='o')
plt.title('QPS vs Connections')
plt.xlabel('Connections')
plt.ylabel('QPS')

# 创建延迟图表
plt.subplot(1, 2, 2)
plt.plot(df['Connections'], df['P50(ms)'], label='P50', marker='o')
plt.plot(df['Connections'], df['P90(ms)'], label='P90', marker='s')
plt.plot(df['Connections'], df['P99(ms)'], label='P99', marker='^')
plt.title('Latency vs Connections')
plt.xlabel('Connections')
plt.ylabel('Latency (ms)')
plt.legend()

plt.tight_layout()
plt.savefig('performance_comparison.png')
plt.show()
"""
EOF
    
    print_success "图表数据文件已生成: $chart_file"
}

# 主要的阶梯式测试函数
run_step_test_main() {
    local test_type=${1:-"create"}
    local duration=${2:-$DEFAULT_DURATION}
    local threads=${3:-$DEFAULT_THREADS}
    
    print_info "开始阶梯式压测"
    print_info "测试类型: $test_type, 持续时间: ${duration}秒, 线程数: $threads"
    
    # 创建报告目录
    mkdir -p "$REPORT_DIR"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local temp_dir="$REPORT_DIR/step_test_${test_type}_${timestamp}"
    mkdir -p "$temp_dir"
    
    local summary_file="$temp_dir/summary.txt"
    local csv_file="$temp_dir/performance_${test_type}.csv"
    
    # 创建测试摘要
    cat > "$summary_file" << EOF
Btrfs 快照服务阶梯式压测报告
==============================
测试时间: $(date '+%Y-%m-%d %H:%M:%S')
测试类型: $test_type
持续时间: ${duration}秒
线程数: $threads
测试并发数: ${DEFAULT_CONNECTIONS[*]}

详细结果:
EOF
    
    # 逐个测试不同并发数
    for connections in "${DEFAULT_CONNECTIONS[@]}"; do
        print_info "正在测试并发数: $connections"
        
        # 在创建快照测试前清理环境
        if [[ "$test_type" == "create" ]]; then
            cleanup_snapshots
            sleep 2
        fi
        
        local output_file="$temp_dir/${test_type}_${connections}.txt"
        
        # 运行测试
        run_single_test "$connections" "$duration" "$threads" "$test_type" "$output_file"
        
        # 提取关键指标并添加到摘要
        echo "" >> "$summary_file"
        echo "并发数: $connections" >> "$summary_file"
        echo "------------------------" >> "$summary_file"
        if [[ -f "$output_file" ]]; then
            grep -E "Requests/sec|Latency|requests in" "$output_file" >> "$summary_file" 2>/dev/null || echo "无法提取指标" >> "$summary_file"
        fi
        
        # 等待系统稳定
        sleep 3
    done
    
    # 生成CSV报告
    generate_csv_report "$test_type" "$csv_file" "$temp_dir"
    
    # 生成图表数据
    generate_chart_data "$csv_file"
    
    # 清理测试数据
    cleanup_snapshots
    
    print_success "阶梯式压测完成"
    print_info "报告目录: $temp_dir"
    print_info "摘要文件: $summary_file"
    print_info "CSV文件: $csv_file"
}

# 运行完整测试套件
run_full_suite() {
    local duration=${1:-$DEFAULT_DURATION}
    local threads=${2:-$DEFAULT_THREADS}
    
    print_info "开始完整测试套件"
    
    # 测试创建快照
    print_info "1/3 测试创建快照性能"
    run_step_test_main "create" "$duration" "$threads"
    
    # 等待系统稳定
    sleep 10
    
    # 创建一些快照用于查询测试
    print_info "准备查询测试数据..."
    for i in {1..50}; do
        curl -s -X POST "$SERVER_URL/api/v1/snapshots/create" > /dev/null
    done
    
    # 测试查询快照
    print_info "2/3 测试查询快照性能"
    run_step_test_main "query" "$duration" "$threads"
    
    # 等待系统稳定
    sleep 10
    
    # 测试删除快照（使用较少的并发数）
    print_info "3/3 测试删除快照性能"
    DEFAULT_CONNECTIONS=(5 10 15 20 25)
    run_step_test_main "delete" 10 4
    
    print_success "完整测试套件完成"
}

# 显示帮助信息
show_help() {
    echo "Btrfs 快照服务阶梯式压测脚本"
    echo ""
    echo "用法: $0 [命令] [参数...]"
    echo ""
    echo "命令:"
    echo "  create [持续时间] [线程数]    测试创建快照性能 (默认: 30秒, 8线程)"
    echo "  query [持续时间] [线程数]     测试查询快照性能"
    echo "  delete [持续时间] [线程数]    测试删除快照性能"
    echo "  full [持续时间] [线程数]      运行完整测试套件"
    echo "  check                        检查环境"
    echo "  clean                        清理测试数据"
    echo "  help                         显示此帮助"
    echo ""
    echo "示例:"
    echo "  $0 create                    # 默认创建快照测试"
    echo "  $0 create 60 12             # 60秒持续时间，12线程"
    echo "  $0 query 30 8               # 查询测试"
    echo "  $0 full 45 10               # 完整测试套件"
    echo ""
    echo "测试并发数: ${DEFAULT_CONNECTIONS[*]}"
}

# 主函数
main() {
    case "${1:-create}" in
        "create"|"query"|"delete")
            check_environment
            run_step_test_main "$1" "${2:-$DEFAULT_DURATION}" "${3:-$DEFAULT_THREADS}"
            ;;
        "full")
            check_environment
            run_full_suite "${2:-$DEFAULT_DURATION}" "${3:-$DEFAULT_THREADS}"
            ;;
        "check")
            check_environment
            ;;
        "clean")
            cleanup_snapshots
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