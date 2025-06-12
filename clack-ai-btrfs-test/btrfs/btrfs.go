package btrfs

import (
	"fmt"
	"os/exec"
	"strings"
)

// BtrfsError 表示Btrfs操作错误
type BtrfsError struct {
	Command string
	Err     error
	Output  string
}

func (e *BtrfsError) Error() string {
	return fmt.Sprintf("btrfs command %q failed: %v\nOutput: %s",
		e.Command, e.Err, e.Output)
}

// SubvolumeCreate 创建Btrfs子卷
func SubvolumeCreate(path string) error {
	cmd := exec.Command("btrfs", "subvolume", "create", path)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return &BtrfsError{
			Command: fmt.Sprintf("create %s", path),
			Err:     err,
			Output:  string(output),
		}
	}
	return nil
}

// SubvolumeSnapshot 创建Btrfs子卷快照
func SubvolumeSnapshot(source, dest string) error {
	cmd := exec.Command("btrfs", "subvolume", "snapshot", source, dest)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return &BtrfsError{
			Command: fmt.Sprintf("snapshot %s %s", source, dest),
			Err:     err,
			Output:  string(output),
		}
	}
	return nil
}

// SubvolumeDelete 删除Btrfs子卷
func SubvolumeDelete(path string) error {
	cmd := exec.Command("btrfs", "subvolume", "delete", path)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return &BtrfsError{
			Command: fmt.Sprintf("delete %s", path),
			Err:     err,
			Output:  string(output),
		}
	}
	return nil
}

// SubvolumeList 列出Btrfs子卷
func SubvolumeList(path string) ([]string, error) {
	cmd := exec.Command("btrfs", "subvolume", "list", path)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, &BtrfsError{
			Command: fmt.Sprintf("list %s", path),
			Err:     err,
			Output:  string(output),
		}
	}

	// 解析输出，提取子卷路径
	lines := strings.Split(string(output), "\n")
	var subvolumes []string
	for _, line := range lines {
		if line == "" {
			continue
		}
		// 示例行: "ID 256 gen 10 top level 5 path @home"
		parts := strings.Split(line, "path ")
		if len(parts) > 1 {
			subvolumes = append(subvolumes, parts[1])
		}
	}
	return subvolumes, nil
}
