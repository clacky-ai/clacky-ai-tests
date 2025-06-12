-- delete_all.lua
-- 用于wrk压测删除所有快照API的Lua脚本

wrk.method = "DELETE"
wrk.headers["Content-Type"] = "application/json"

-- 全局变量用于统计
local success_count = 0
local error_count = 0

request = function()
    path = "/api/v1/snapshots/all"
    return wrk.format(wrk.method, path)
end

response = function(status, headers, body)
    if status == 200 then
        success_count = success_count + 1
        -- 解析响应体获取删除的快照数量
        local delete_count = string.match(body, '"count":(%d+)')
        if delete_count then
            print("成功删除 " .. delete_count .. " 个快照")
        end
    else
        error_count = error_count + 1
        print("错误响应: " .. status .. " " .. body)
    end
end

done = function(summary, latency, requests)
    io.write("==============================\n")
    io.write("Btrfs 快照删除压测结果统计\n")
    io.write("==============================\n")
    io.write(string.format("请求总数: %d\n", summary.requests))
    io.write(string.format("成功请求: %d\n", success_count))
    io.write(string.format("失败请求: %d\n", error_count))
    io.write(string.format("成功率: %.2f%%\n", (success_count / summary.requests) * 100))
    io.write(string.format("总耗时: %.2f秒\n", summary.duration/1000000))
    io.write(string.format("QPS: %.2f\n", summary.requests/(summary.duration/1000000)))
    io.write(string.format("平均延迟: %.2fms\n", latency.mean/1000))
    io.write(string.format("50%% 延迟: %.2fms\n", latency.p50/1000))
    io.write(string.format("90%% 延迟: %.2fms\n", latency.p90/1000))
    io.write(string.format("99%% 延迟: %.2fms\n", latency.p99/1000))
    io.write(string.format("最大延迟: %.2fms\n", latency.max/1000))
    io.write("==============================\n")
    
    -- 生成性能报告文件
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local report_file = "btrfs_snapshot_delete_" .. timestamp .. ".txt"
    local file = io.open(report_file, "w")
    if file then
        file:write("Btrfs 快照删除压测报告\n")
        file:write("测试时间: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
        file:write("请求总数: " .. summary.requests .. "\n")
        file:write("成功请求: " .. success_count .. "\n")
        file:write("失败请求: " .. error_count .. "\n")
        file:write("成功率: " .. string.format("%.2f%%", (success_count / summary.requests) * 100) .. "\n")
        file:write("总耗时: " .. string.format("%.2f秒", summary.duration/1000000) .. "\n")
        file:write("QPS: " .. string.format("%.2f", summary.requests/(summary.duration/1000000)) .. "\n")
        file:write("平均延迟: " .. string.format("%.2fms", latency.mean/1000) .. "\n")
        file:write("最大延迟: " .. string.format("%.2fms", latency.max/1000) .. "\n")
        file:close()
        print("性能报告已保存到: " .. report_file)
    end
end 