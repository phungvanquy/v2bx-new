package imports

import (
	"net"
	"testing"

	"github.com/InazumaV/V2bX/api/panel"
	"github.com/InazumaV/V2bX/conf"
	"github.com/InazumaV/V2bX/core"
)

// Exercise runtime feature registration as well as compilation. Core upgrades
// can compile successfully while failing to construct or start an instance.
func TestCoreLifecycle(t *testing.T) {
	for _, name := range core.RegisteredCore() {
		t.Run(name, func(t *testing.T) {
			t.Setenv("XRAY_LOCATION_ASSET", t.TempDir())
			t.Setenv("XRAY_DNS_PATH", "")
			t.Setenv("SING_DNS_PATH", "")
			config := conf.CoreConfig{
				Type:            name,
				XrayConfig:      conf.NewXrayConfig(),
				SingConfig:      conf.NewSingConfig(),
				Hysteria2Config: conf.NewHysteria2Config(),
			}
			config.XrayConfig.AssetPath = t.TempDir()
			instance, err := core.NewCore([]conf.CoreConfig{config})
			if err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() {
				if err := instance.Close(); err != nil {
					t.Error(err)
				}
			})
			if instance.Type() != name {
				t.Fatalf("core type = %q, want %q", instance.Type(), name)
			}
			if err := instance.Start(); err != nil {
				t.Fatal(err)
			}
			if name == "xray" || name == "sing" {
				testLiveUsers(t, instance)
			}
		})
	}
}

func testLiveUsers(t *testing.T, instance core.Core) {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	port := listener.Addr().(*net.TCPAddr).Port
	if err := listener.Close(); err != nil {
		t.Fatal(err)
	}
	info := &panel.NodeInfo{
		Type:   "vmess",
		Common: &panel.CommonNode{ServerPort: port},
		VAllss: &panel.VAllssNode{Network: "tcp"},
	}
	options := &conf.Options{
		ListenIP:    "127.0.0.1",
		XrayOptions: conf.NewXrayOptions(),
		SingOptions: conf.NewSingOptions(),
	}
	const tag = "core-update-test"
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
}
