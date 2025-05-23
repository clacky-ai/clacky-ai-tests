# clacky-ai-tests

## Usage
./run.sh <project_name> <test_name> <threads>

## Example
./run.sh clacky-ai-backend single 1

## single test

cd /home/ubuntu/clacky-ai-tests && ./run.sh clacky-ai-single-test clacky-ai-single-test 10

## system test

cd /home/ubuntu/clacky-ai-tests && ./run.sh clacky-ai-system-test clackyai_system_test 10

## 复制报告到 nginx 服务器
cp -RP /home/ubuntu/clacky-ai-tests/clacky-ai-single-test/reports/clacky-ai-single-test_20250523_072118_20 /var/www/html/reports/



