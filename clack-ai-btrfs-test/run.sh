#!/bin/bash

# Btrfs 快照压测服务启动脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 检查是否是 root 用户（Btrfs 操作通常需要 root 权限）
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        print_warning "注意：Btrfs 操作通常需要 root 权限"
        print_warning "如果遇到权限问题，请使用 sudo 运行此脚本"
    fi
}

# 检查依赖
check_dependencies() {
    print_info "检查依赖项..."
    
    # 检查 Go
    if ! command -v go &> /dev/null; then
        print_error "Go 未安装或不在 PATH 中"
        exit 1
    fi
    
    # 检查 btrfs 命令
    if ! command -v btrfs &> /dev/null; then
        print_error "btrfs 命令未找到，请安装 btrfs-progs"
        exit 1
    fi
    
    print_success "依赖检查通过"
}

# 检查必要的目录和子卷
check_btrfs_setup() {
    print_info "检查 Btrfs 设置..."
    
    # 检查源子卷是否存在
    if ! btrfs subvolume show /data/@meta &> /dev/null; then
        print_warning "源子卷 /data/@meta 不存在"
        print_info "请运行以下命令创建："
        print_info "  sudo btrfs subvolume create /data/@meta"
        
        read -p "是否现在创建源子卷？(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo mkdir -p /data
            sudo btrfs subvolume create /data/@meta
            print_success "源子卷创建成功"
        else
            print_error "需要源子卷才能运行服务"
            exit 1
        fi
    else
        print_success "源子卷 /data/@meta 存在"
    fi
    
    # 检查测试目录
    if [[ ! -d "/data/@data/test" ]]; then
        print_info "创建测试目录 /data/@data/test"
        sudo mkdir -p /data/@data/test
    fi
    
    print_success "Btrfs 设置检查完成"
}

# 构建项目
build_project() {
    print_info "构建项目..."
    
    # 构建主服务
    if go build -o btrfs-server main.go; then
        print_success "主服务构建成功"
    else
        print_error "主服务构建失败"
        exit 1
    fi
    
    # 构建压测工具
    if go build -o benchmark-tool cmd/benchmark/main.go; then
        print_success "压测工具构建成功"
    else
        print_error "压测工具构建失败"
        exit 1
    fi
}

# 启动服务
start_server() {
    print_info "启动 Btrfs 快照压测服务..."
    print_info "服务将在 http://localhost:8080 启动"
    print_info "按 Ctrl+C 停止服务"
    echo
    
    ./btrfs-server
}

# 显示使用帮助
show_help() {
    echo "Btrfs 快照压测服务启动脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  start     启动服务 (默认)"
    echo "  build     仅构建项目"
    echo "  check     仅检查环境"
    echo "  test      运行简单的压测"
    echo "  help      显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0              # 启动服务"
    echo "  $0 start        # 启动服务"
    echo "  $0 build        # 仅构建"
    echo "  $0 test         # 运行测试"
}

# 运行简单测试
run_test() {
    print_info "运行简单的压测测试..."
    
    # 启动服务（后台运行）
    ./btrfs-server &
    SERVER_PID=$!
    
    # 等待服务启动
    sleep 3
    
    # 运行测试
    print_info "运行测试: 5个并发，创建20个快照"
    ./benchmark-tool -c 5 -n 20
    
    # 清理快照
    print_info "清理测试快照"
    ./benchmark-tool -cleanup-only
    
    # 停止服务
    kill $SERVER_PID
    print_success "测试完成"
}

# 主函数
main() {
    print_info "Btrfs 快照压测服务"
    print_info "===================="
    
    case "${1:-start}" in
        "start")
            check_permissions
            check_dependencies
            check_btrfs_setup
            build_project
            start_server
            ;;
        "build")
            check_dependencies
            build_project
            ;;
        "check")
            check_permissions
            check_dependencies
            check_btrfs_setup
            ;;
        "test")
            check_permissions
            check_dependencies
            check_btrfs_setup
            build_project
            run_test
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

# 运行主函数
main "$@" 