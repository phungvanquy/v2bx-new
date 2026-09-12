package hy2

import (
	"net"
	"testing"
	"time"

	"github.com/InazumaV/V2bX/api/panel"
	"github.com/InazumaV/V2bX/conf"
)

func TestSalamanderPacketRoundTrip(t *testing.T) {
	info := &panel.NodeInfo{
		Common:    &panel.CommonNode{},
		Hysteria2: &panel.Hysteria2Node{ObfsType: "salamander", ObfsPassword: "test-password"},
	}
	options := &conf.Options{ListenIP: "127.0.0.1"}
	var node Hysteria2node
	sender, err := node.getConn(info, options)
	if err != nil {
		t.Fatal(err)
	}
	defer sender.Close()
	receiver, err := node.getConn(info, options)
	if err != nil {
		t.Fatal(err)
	}
	defer receiver.Close()
	if err := receiver.SetReadDeadline(time.Now().Add(3 * time.Second)); err != nil {
		t.Fatal(err)
	}
	const payload = "core update packet"
	if _, err := sender.WriteTo([]byte(payload), receiver.LocalAddr()); err != nil {
		t.Fatal(err)
	}
	buffer := make([]byte, 1500)
	n, _, err := receiver.ReadFrom(buffer)
	if err != nil {
		t.Fatal(err)
	}
	if string(buffer[:n]) != payload {
		t.Fatalf("received %q, want %q", buffer[:n], payload)
	}
}

func TestInvalidObfuscationReleasesSocket(t *testing.T) {
	for _, obfsType := range []string{"salamander", "unsupported"} {
		t.Run(obfsType, func(t *testing.T) {
			probe, err := net.ListenPacket("udp", "127.0.0.1:0")
			if err != nil {
				t.Fatal(err)
			}
			addr := probe.LocalAddr().(*net.UDPAddr)
			probe.Close()
			info := &panel.NodeInfo{
				Common:    &panel.CommonNode{ServerPort: addr.Port},
				Hysteria2: &panel.Hysteria2Node{ObfsType: obfsType, ObfsPassword: "x"},
			}
			var node Hysteria2node
			conn, err := node.getConn(info, &conf.Options{ListenIP: "127.0.0.1"})
			if err == nil {
				conn.Close()
				t.Fatal("expected invalid obfuscation to fail")
			}
			reopened, err := net.ListenPacket("udp", addr.String())
			if err != nil {
				t.Fatalf("socket leaked after invalid obfuscation: %v", err)
			}
			reopened.Close()
		})
	}
}
