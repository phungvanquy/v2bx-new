//go:build with_quic

package imports

import (
	"testing"

	"github.com/InazumaV/V2bX/api/panel"
	"github.com/InazumaV/V2bX/conf"
	"github.com/InazumaV/V2bX/core"
)

// Both QUIC implementations must still support dynamic panel users after their
// shared HTTP/3 dependencies change. The certificate is a repository test fixture.
func TestQUICNodeLifecycle(t *testing.T) {
	for _, name := range core.RegisteredCore() {
		if name != "sing" && name != "hysteria2" {
			continue
		}
		t.Run(name, func(t *testing.T) {
			t.Setenv("SING_DNS_PATH", "")
			instance, err := core.NewCore([]conf.CoreConfig{{
				Type:            name,
				SingConfig:      conf.NewSingConfig(),
				Hysteria2Config: conf.NewHysteria2Config(),
			}})
			if err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() {
				if err := instance.Close(); err != nil {
					t.Error(err)
				}
			})
			if err := instance.Start(); err != nil {
				t.Fatal(err)
			}
			info := &panel.NodeInfo{
				Type:      "hysteria2",
				Security:  panel.Tls,
				Common:    &panel.CommonNode{},
				Hysteria2: &panel.Hysteria2Node{},
			}
			options := &conf.Options{
				ListenIP:    "127.0.0.1",
				SingOptions: conf.NewSingOptions(),
				CertConfig: &conf.CertConfig{
					CertMode: "file",
					CertFile: "../../test_data/1.pem",
					KeyFile:  "../../test_data/1.key",
				},
			}
			const tag = "quic-core-update-test"
			if err := instance.AddNode(tag, info, options); err != nil {
				t.Fatal(err)
			}
			users := []panel.UserInfo{{Id: 1, Uuid: "d342d11e-d424-4583-b36e-524ab1f0afa4"}}
			for i := 0; i < 2; i++ {
				added, err := instance.AddUsers(&core.AddUsersParams{Tag: tag, Users: users, NodeInfo: info})
				if err != nil || added != len(users) {
					t.Fatalf("add users: added=%d, err=%v", added, err)
				}
				if err := instance.DelUsers(users, tag, info); err != nil {
					t.Fatal(err)
				}
			}
			if err := instance.DelNode(tag); err != nil {
				t.Fatal(err)
			}
		})
	}
}
