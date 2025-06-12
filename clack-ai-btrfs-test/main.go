package main

import (
	"log"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"btrfs-test/btrfs"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func main() {
	// 初始化Gin路由
	r := gin.Default()

	// 添加中间件
	r.Use(gin.Logger())
	r.Use(gin.Recovery())

	// 注册路由
	api := r.Group("/api/v1")
	{
		// 根据子卷创建快照，快照路径为：/data/@data/test/@{uuid}
		api.POST("/snapshots/create", createSnapshotFromMeta)
		// 列出所有创建的快照，以/data/@data/test开头的
		api.GET("/snapshots", listTestSnapshots)
		// 删除所有的快照
		api.DELETE("/snapshots/all", deleteAllTestSnapshots)
	}

	// 配置HTTP服务器
	srv := &http.Server{
		Addr:         ":8080",
		Handler:      r,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// 启动服务器
	log.Println("正在启动 Btrfs 快照压测服务，监听端口 :8080")
	log.Println("API 接口:")
	log.Println("  POST /api/v1/snapshots/create - 从 /data/@meta 创建快照")
	log.Println("  GET  /api/v1/snapshots - 列出所有测试快照")
	log.Println("  DELETE /api/v1/snapshots/all - 删除所有测试快照")
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("服务器错误: %v", err)
	}
}

// 响应结构体
type CreateSnapshotResponse struct {
	Success      bool   `json:"success"`
	SnapshotPath string `json:"snapshot_path,omitempty"`
	UUID         string `json:"uuid,omitempty"`
	ErrorMessage string `json:"error_message,omitempty"`
}

type ListSnapshotsResponse struct {
	Success      bool     `json:"success"`
	Snapshots    []string `json:"snapshots,omitempty"`
	Count        int      `json:"count"`
	ErrorMessage string   `json:"error_message,omitempty"`
}

type DeleteAllResponse struct {
	Success      bool     `json:"success"`
	Deleted      []string `json:"deleted,omitempty"`
	Count        int      `json:"count"`
	ErrorMessage string   `json:"error_message,omitempty"`
}

// 接口1: 根据子卷创建快照，快照路径为：/data/@data/test/@{uuid}
func createSnapshotFromMeta(c *gin.Context) {
	// 生成UUID
	snapshotUUID := uuid.New().String()
	sourcePath := "/data/@meta"
	destPath := filepath.Join("/data/@data/test", "@"+snapshotUUID)

	log.Printf("正在创建快照: %s -> %s", sourcePath, destPath)

	// 创建快照
	if err := btrfs.SubvolumeSnapshot(sourcePath, destPath); err != nil {
		log.Printf("创建快照失败: %v", err)
		c.JSON(http.StatusInternalServerError, CreateSnapshotResponse{
			Success:      false,
			ErrorMessage: err.Error(),
		})
		return
	}

	log.Printf("快照创建成功: %s", destPath)
	c.JSON(http.StatusCreated, CreateSnapshotResponse{
		Success:      true,
		SnapshotPath: destPath,
		UUID:         snapshotUUID,
	})
}

// 接口2: 列出所有创建的快照，以/data/@data/test开头的
func listTestSnapshots(c *gin.Context) {
	log.Println("正在列出测试快照...")

	// 获取所有子卷
	allSubvolumes, err := btrfs.SubvolumeList("/data")
	if err != nil {
		log.Printf("列出子卷失败: %v", err)
		c.JSON(http.StatusInternalServerError, ListSnapshotsResponse{
			Success:      false,
			ErrorMessage: err.Error(),
		})
		return
	}

	// 过滤出以 /data/@data/test 开头的快照
	var testSnapshots []string
	prefix := "@data/test/"

	for _, subvolume := range allSubvolumes {
		// btrfs subvolume list 返回的路径格式可能是相对路径
		if strings.Contains(subvolume, prefix) {
			// 构造完整路径
			fullPath := filepath.Join("/data", subvolume)
			testSnapshots = append(testSnapshots, fullPath)
		}
	}

	log.Printf("找到 %d 个测试快照", len(testSnapshots))
	c.JSON(http.StatusOK, ListSnapshotsResponse{
		Success:   true,
		Snapshots: testSnapshots,
		Count:     len(testSnapshots),
	})
}

// 接口3: 删除所有的快照
func deleteAllTestSnapshots(c *gin.Context) {
	log.Println("正在删除所有测试快照...")

	// 先获取所有测试快照
	allSubvolumes, err := btrfs.SubvolumeList("/data")
	if err != nil {
		log.Printf("列出子卷失败: %v", err)
		c.JSON(http.StatusInternalServerError, DeleteAllResponse{
			Success:      false,
			ErrorMessage: err.Error(),
		})
		return
	}

	// 过滤出以 /data/@data/test 开头的快照
	var testSnapshots []string
	prefix := "@data/test/"

	for _, subvolume := range allSubvolumes {
		if strings.Contains(subvolume, prefix) {
			fullPath := filepath.Join("/data", subvolume)
			testSnapshots = append(testSnapshots, fullPath)
		}
	}

	log.Printf("找到 %d 个测试快照需要删除", len(testSnapshots))

	// 删除每个快照
	var deletedSnapshots []string
	var failedDeletions []string

	for _, snapshotPath := range testSnapshots {
		log.Printf("正在删除快照: %s", snapshotPath)
		if err := btrfs.SubvolumeDelete(snapshotPath); err != nil {
			log.Printf("删除快照失败 %s: %v", snapshotPath, err)
			failedDeletions = append(failedDeletions, snapshotPath)
		} else {
			log.Printf("成功删除快照: %s", snapshotPath)
			deletedSnapshots = append(deletedSnapshots, snapshotPath)
		}
	}

	if len(failedDeletions) > 0 {
		errorMsg := "部分快照删除失败: " + strings.Join(failedDeletions, ", ")
		c.JSON(http.StatusPartialContent, DeleteAllResponse{
			Success:      false,
			Deleted:      deletedSnapshots,
			Count:        len(deletedSnapshots),
			ErrorMessage: errorMsg,
		})
		return
	}

	log.Printf("成功删除 %d 个测试快照", len(deletedSnapshots))
	c.JSON(http.StatusOK, DeleteAllResponse{
		Success: true,
		Deleted: deletedSnapshots,
		Count:   len(deletedSnapshots),
	})
}
