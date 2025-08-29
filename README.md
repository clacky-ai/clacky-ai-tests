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

## nginx配置文件
```
server {
        listen 80 default_server;
        listen [::]:80 default_server;

        root /var/www/html;

        # Add index.php to the list if you are using PHP
        index index.html index.htm index.nginx-debian.html;

        server_name _;

        # 全局 MIME 设置
            include /etc/nginx/mime.types;
                default_type text/html;  # 默认设为 HTML（优先级低于 mime.types）
        location / {
                # First attempt to serve request as file, then
                # as directory, then fall back to displaying a 404.
                autoindex on;               # 启用目录列表
                autoindex_exact_size off;   # 人性化显示文件大小
                autoindex_localtime on;     # 显示本地时间
                try_files $uri $uri/ =404;
        }


        location ~* \.log$ {
                    add_header Content-Type "text/plain; charset=utf-8";
                        # 可选：禁用缓存（方便实时查看日志）
                        add_header Cache-Control "no-store";
        }
        # 手动添加 .log 文件的 MIME 类型
            types {
                 text/plain log;
            }
}
```

## 压测文档
https://www.notion.so/dao42/25aa0f931022806f9972cbbfeb7ed6d7
