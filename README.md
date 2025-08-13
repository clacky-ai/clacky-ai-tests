# clacky-ai-tests

## Usage
./run.sh <project_name> <test_name> <threads> <rampup>

## Example
./run.sh clacky-ai-backend single 1 0

## single test

cd /home/ubuntu/clacky-ai-tests && ./run.sh clacky-ai-single-test clacky-ai-single-test 10 0

注：2025.05.24 最新单测脚本为 clacky-ai-single-test-v2，添加了同步计数器，避免单测存在误差问题

## system test

cd /home/ubuntu/clacky-ai-tests && ./run.sh clacky-ai-system-test clackyai_system_test 10 0

## issueThread test

cd /home/ubuntu/clacky-ai-tests && ./run.sh  clacky-ai-issue-thread-test  clackyai_issue_thread_test 50 50



## zero to one Thread test

cd /home/ubuntu/clacky-ai-tests && ./run.sh  clacky-ai-zerotoone-test  clackyai_zerotoone_test 10 30

## 复制报告到 nginx 服务器

cp -RP /home/ubuntu/clacky-ai-tests/clacky-ai-single-test/reports/clacky-ai-single-test_20250523_072118_20 /var/www/html/reports/

## 复制日志到 nginx 服务器

cp -RP /home/ubuntu/clacky-ai-tests/jmeter /var/www/html/logs/jmeter-clacky-ai-single-test_20250523_072118_20.log

