package cmd

import (
	"os"
	"path/filepath"
	"testing"
)

func TestUninstallCancellationDoesNotRunSystemctl(t *testing.T) {
	dir := t.TempDir()
	marker := filepath.Join(dir, "systemctl-called")
	fake := filepath.Join(dir, "systemctl")
	if err := os.WriteFile(fake, []byte("#!/bin/sh\ntouch \""+marker+"\"\nexit 1\n"), 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir+string(os.PathListSeparator)+os.Getenv("PATH"))
	input := filepath.Join(dir, "input")
	if err := os.WriteFile(input, []byte("n\n"), 0600); err != nil {
		t.Fatal(err)
	}
	file, err := os.Open(input)
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	oldStdin := os.Stdin
	os.Stdin = file
	defer func() { os.Stdin = oldStdin }()

	uninstallHandle(nil, nil)
	if _, err := os.Stat(marker); !os.IsNotExist(err) {
		t.Fatalf("uninstall ran systemctl after cancellation: %v", err)
	}
}
