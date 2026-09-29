package panel

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/InazumaV/V2bX/conf"
)

func TestClient_GetNodeInfoCachesOnlyValidResponses(t *testing.T) {
	const validNode = `{"server_port":12345,"network":"tcp","tls":0,"base_config":{"push_interval":60,"pull_interval":60}}`
	call := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		call++
		switch call {
		case 1, 2:
			if got := r.Header.Get("If-None-Match"); got != "" {
				t.Errorf("failed response changed ETag to %q", got)
			}
			w.WriteHeader(http.StatusForbidden)
			_, _ = w.Write([]byte("forbidden"))
		case 3, 4:
			if got := r.Header.Get("If-None-Match"); got != "" {
				t.Errorf("invalid node changed ETag to %q", got)
			}
			w.Header().Set("ETag", `"invalid"`)
			_, _ = w.Write([]byte("{invalid"))
		case 5:
			w.Header().Set("ETag", `"valid"`)
			_, _ = w.Write([]byte(validNode))
		case 6:
			if got := r.Header.Get("If-None-Match"); got != `"valid"` {
				t.Errorf("expected valid ETag, got %q", got)
			}
			w.Header().Set("ETag", `"new"`)
			_, _ = w.Write([]byte(validNode))
		case 7:
			if got := r.Header.Get("If-None-Match"); got != `"new"` {
				t.Errorf("expected refreshed ETag, got %q", got)
			}
			w.WriteHeader(http.StatusNotModified)
		default:
			t.Errorf("unexpected request %d", call)
			w.WriteHeader(http.StatusInternalServerError)
		}
	}))
	defer server.Close()

	c, err := New(&conf.ApiConfig{APIHost: server.URL, Key: "fixture", NodeType: "vmess", NodeID: 9})
	if err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 4; i++ {
		if node, err := c.GetNodeInfo(); err == nil || node != nil {
			t.Fatalf("request %d: expected an error and no node, got %v, %v", i+1, node, err)
		}
		if c.responseBodyHash != "" || c.nodeEtag != "" {
			t.Fatalf("request %d: invalid response modified cache", i+1)
		}
	}

	node, err := c.GetNodeInfo()
	if err != nil || node == nil || node.VAllss.ServerPort != 12345 {
		t.Fatalf("valid response: node=%v error=%v", node, err)
	}
	if c.responseBodyHash == "" || c.nodeEtag != `"valid"` {
		t.Fatalf("valid response was not cached")
	}
	for _, expectedETag := range []string{`"new"`, `"new"`} {
		if node, err := c.GetNodeInfo(); err != nil || node != nil {
			t.Fatalf("unchanged response: node=%v error=%v", node, err)
		}
		if c.nodeEtag != expectedETag {
			t.Fatalf("expected ETag %q, got %q", expectedETag, c.nodeEtag)
		}
	}
	if call != 7 {
		t.Fatalf("expected seven requests, got %d", call)
	}
}
