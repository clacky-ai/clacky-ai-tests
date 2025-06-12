package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"
)

type BenchmarkResult struct {
	TotalSnapshots int           `json:"total_snapshots"`
	SuccessCount   int           `json:"success_count"`
	FailureCount   int           `json:"failure_count"`
	TotalTime      time.Duration `json:"total_time"`
	AvgTime        time.Duration `json:"avg_time"`
	MinTime        time.Duration `json:"min_time"`
	MaxTime        time.Duration `json:"max_time"`
}

// 压测函数 - 并发创建快照
func BenchmarkSnapshotCreation(serverURL string, concurrency int, totalSnapshots int) *BenchmarkResult {
	fmt.Printf("开始压测: 并发数=%d, 总快照数=%d\n", concurrency, totalSnapshots)

	var wg sync.WaitGroup
	results := make(chan time.Duration, totalSnapshots)
	errors := make(chan error, totalSnapshots)

	// 创建信号量来控制并发数
	semaphore := make(chan struct{}, concurrency)

	startTime := time.Now()

	// 启动goroutines
	for i := 0; i < totalSnapshots; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()

			// 获取信号量
			semaphore <- struct{}{}
			defer func() { <-semaphore }()

			// 创建快照
			reqStart := time.Now()
			err := createSnapshot(serverURL)
			reqDuration := time.Since(reqStart)

			if err != nil {
				errors <- err
			} else {
				results <- reqDuration
			}
		}()
	}

	// 等待所有goroutines完成
	wg.Wait()
	close(results)
	close(errors)

	totalTime := time.Since(startTime)

	// 统计结果
	var durations []time.Duration
	for duration := range results {
		durations = append(durations, duration)
	}

	var errorCount int
	for range errors {
		errorCount++
	}

	result := &BenchmarkResult{
		TotalSnapshots: totalSnapshots,
		SuccessCount:   len(durations),
		FailureCount:   errorCount,
		TotalTime:      totalTime,
	}

	// 计算平均、最小、最大时间
	if len(durations) > 0 {
		var sum time.Duration
		minTime := durations[0]
		maxTime := durations[0]

		for _, d := range durations {
			sum += d
			if d < minTime {
				minTime = d
			}
			if d > maxTime {
				maxTime = d
			}
		}

		result.AvgTime = sum / time.Duration(len(durations))
		result.MinTime = minTime
		result.MaxTime = maxTime
	}

	return result
}

// 创建单个快照的函数
func createSnapshot(serverURL string) error {
	url := fmt.Sprintf("%s/api/v1/snapshots/create", serverURL)

	resp, err := http.Post(url, "application/json", nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		return fmt.Errorf("HTTP状态码: %d", resp.StatusCode)
	}

	return nil
}

// 清理所有快照
func CleanupSnapshots(serverURL string) error {
	url := fmt.Sprintf("%s/api/v1/snapshots/all", serverURL)

	req, err := http.NewRequest("DELETE", url, nil)
	if err != nil {
		return err
	}

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("清理失败，HTTP状态码: %d", resp.StatusCode)
	}

	return nil
}

// 获取快照列表
func GetSnapshotList(serverURL string) ([]string, error) {
	url := fmt.Sprintf("%s/api/v1/snapshots", serverURL)

	resp, err := http.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("获取快照列表失败，HTTP状态码: %d", resp.StatusCode)
	}

	var response ListSnapshotsResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, err
	}

	return response.Snapshots, nil
}

// 打印压测结果
func PrintBenchmarkResult(result *BenchmarkResult) {
	fmt.Println("\n=== 压测结果 ===")
	fmt.Printf("总快照数: %d\n", result.TotalSnapshots)
	fmt.Printf("成功数: %d\n", result.SuccessCount)
	fmt.Printf("失败数: %d\n", result.FailureCount)
	fmt.Printf("成功率: %.2f%%\n", float64(result.SuccessCount)/float64(result.TotalSnapshots)*100)
	fmt.Printf("总耗时: %v\n", result.TotalTime)
	fmt.Printf("平均耗时: %v\n", result.AvgTime)
	fmt.Printf("最小耗时: %v\n", result.MinTime)
	fmt.Printf("最大耗时: %v\n", result.MaxTime)
	fmt.Printf("QPS: %.2f\n", float64(result.SuccessCount)/result.TotalTime.Seconds())
	fmt.Println("==================")
}
