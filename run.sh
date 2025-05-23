#!/bin/sh

# 检查参数
if [ $# -ne 3 ]; then
  echo "Usage: $0 <project_name> <test_name> <threads>"
  exit 1
fi

# 定义变量
PROJECT_NAME=$1
TEST_NAME=$2
THREADS=$3
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TEST_FILE="${PROJECT_NAME}/tests/${TEST_NAME}.jmx"
RESULT_FILE="${PROJECT_NAME}/results/${TEST_NAME}_report_${TIMESTAMP}_${THREADS}.csv"
REPORT_DIR="${PROJECT_NAME}/reports/${TEST_NAME}_report_${TIMESTAMP}_${THREADS}"
TAR_FILE="${PROJECT_NAME}/reports/${TEST_NAME}_report_${TIMESTAMP}_${THREADS}.tar"

# 记录开始时间
START_TIME=$(date +%s)
echo "Test started at: $(date +"%Y-%m-%d %H:%M:%S")"
# 运行 JMeter 测试
jmeter -n -t "${TEST_FILE}" \
       -l "${RESULT_FILE}" \
       -e -o "${REPORT_DIR}" \
       -Jthreads=${THREADS}

# 记录结束时间
END_TIME=$(date +%s)
echo "Test finished at: $(date +"%Y-%m-%d %H:%M:%S")"

# 计算用时
DURATION=$((END_TIME - START_TIME))
echo "Test duration: ${DURATION} seconds"

# 检查报告目录是否存在
if [ -d "${REPORT_DIR}" ]; then
  # 将报告目录打包为 tar 文件，并保存到 reports 目录
  tar -cvf "${TAR_FILE}" -C "${PROJECT_NAME}/reports" "${TEST_NAME}_${TIMESTAMP}"
  echo "Report directory packed into ${TAR_FILE}"
else
  echo "Report directory ${REPORT_DIR} not found."
  exit 1
fi

# 列出 reports 目录中时间最新的一个 tar 文件
echo "Listing the latest tar file in the reports directory:"
LATEST_TAR=$(ls -t "${PROJECT_NAME}/reports"/*.tar | head -n 1)
ls -l "${LATEST_TAR}"