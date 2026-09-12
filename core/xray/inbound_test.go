package xray

import (
	"testing"

	"github.com/InazumaV/V2bX/api/panel"
	"github.com/InazumaV/V2bX/conf"
)

func TestShadowsocksCoreCompatibility(t *testing.T) {
	for _, method := range []string{"aes-128-gcm", "aes-256-gcm", "chacha20-ietf-poly1305", "xchacha20-ietf-poly1305", "none", "plain"} {
		t.Run(method, func(t *testing.T) {
			options := &conf.Options{ListenIP: "127.0.0.1", XrayOptions: conf.NewXrayOptions()}
			info := &panel.NodeInfo{
				Type:        "shadowsocks",
				Common:      &panel.CommonNode{ServerPort: 12345},
				Shadowsocks: &panel.ShadowsocksNode{Cipher: method},
			}
			_, err := buildInbound(options, info, "test")
			if method == "none" || method == "plain" {
				if err == nil {
					t.Fatal("Xray must reject removed plaintext cipher methods")
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			user := buildSSUser("test", &panel.UserInfo{Id: 1, Uuid: "test-password"}, method, "")
			if _, err := user.ToMemoryUser(); err != nil {
				t.Fatalf("core cannot load panel user for %s: %v", method, err)
			}
			options.XrayOptions.DisableIVCheck = true
			if _, err := buildInbound(options, info, "test"); err == nil {
				t.Fatal("unsupported DisableIVCheck must not be silently ignored")
			}
		})
	}
}
