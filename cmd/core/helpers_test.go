package core

import (
	"strings"
	"testing"
)

func TestSanitizeVMName(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"ubuntu:24.04", "cocoon-ubuntu-24.04"},
		{"ghcr.io/foo/ubuntu:24.04", "cocoon-foo-ubuntu-24.04"},
		{"localhost:5000/myimg:latest", "cocoon-myimg"},
		{"library/nginx:1.25", "cocoon-nginx-1.25"},
		// Digest refs: tag/digest should be stripped, only repo kept.
		{"ghcr.io/ns/img@sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "cocoon-ns-img"},
		{"ubuntu@sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "cocoon-ubuntu"},
		// No tag, no digest — "latest" is implicit and omitted.
		{"ghcr.io/org/repo", "cocoon-org-repo"},
		{"alpine", "cocoon-alpine"},
	}
	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got := sanitizeVMName(tt.input)
			if got != tt.want {
				t.Errorf("sanitizeVMName(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

func TestSanitizeVMName_Truncation(t *testing.T) {
	// Build an image ref that would produce a name > 63 chars.
	long := "ghcr.io/" + strings.Repeat("a", 80) + ":latest"
	got := sanitizeVMName(long)
	if len(got) > 63 {
		t.Errorf("name too long (%d chars): %q", len(got), got)
	}
}
