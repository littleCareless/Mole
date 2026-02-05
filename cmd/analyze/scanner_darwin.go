//go:build darwin

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
	// macOS uses Atimespec
	return time.Unix(stat.Atimespec.Sec, stat.Atimespec.Nsec)
}
