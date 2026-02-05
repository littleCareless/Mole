//go:build linux

package main

import (
	"io/fs"
	"syscall"
	"time"
)

func getLastAccessTimeFromInfo(info fs.FileInfo) time.Time {
	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok {
		return time.Time{}
	}
	// Linux uses Atim
	return time.Unix(stat.Atim.Sec, stat.Atim.Nsec)
}
