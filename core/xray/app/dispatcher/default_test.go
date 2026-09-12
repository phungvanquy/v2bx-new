package dispatcher

import (
	"context"
	"testing"

	"github.com/xtls/xray-core/common/geodata"
	"github.com/xtls/xray-core/common/net"
	"github.com/xtls/xray-core/common/session"
)

type testSniffResult string

func (r testSniffResult) Protocol() string { return "tls" }
func (r testSniffResult) Domain() string   { return string(r) }

func TestSniffDomainExclusions(t *testing.T) {
	matcher, err := geodata.DomainReg.BuildDomainMatcher([]*geodata.DomainRule{
		{Value: &geodata.DomainRule_Custom{Custom: &geodata.Domain{Type: geodata.Domain_Full, Value: "excluded.example"}}},
		{Value: &geodata.DomainRule_Custom{Custom: &geodata.Domain{Type: geodata.Domain_Regex, Value: `^private\.`}}},
	})
	if err != nil {
		t.Fatal(err)
	}
	request := session.SniffingRequest{
		ExcludeForDomain:               matcher,
		OverrideDestinationForProtocol: []string{"tls"},
	}
	dispatcher := &DefaultDispatcher{}
	for _, tc := range []struct {
		domain string
		want   bool
	}{
		{"excluded.example", false},
		{"EXCLUDED.EXAMPLE", false},
		{"private.example", false},
		{"public.example", true},
		{"", false},
	} {
		t.Run(tc.domain, func(t *testing.T) {
			got := dispatcher.shouldOverride(context.Background(), testSniffResult(tc.domain), request, net.Destination{})
			if got != tc.want {
				t.Fatalf("shouldOverride(%q) = %v, want %v", tc.domain, got, tc.want)
			}
		})
	}
	request.ExcludeForDomain = nil
	if !dispatcher.shouldOverride(context.Background(), testSniffResult("public.example"), request, net.Destination{}) {
		t.Fatal("nil exclusions should allow a matching protocol")
	}
}

func TestSniffIPExclusions(t *testing.T) {
	rules, err := geodata.ParseIPRules([]string{"203.0.113.0/24"})
	if err != nil {
		t.Fatal(err)
	}
	matcher, err := geodata.IPReg.BuildIPMatcher(rules)
	if err != nil {
		t.Fatal(err)
	}
	request := session.SniffingRequest{
		ExcludeForIP:                   matcher,
		OverrideDestinationForProtocol: []string{"tls"},
	}
	dispatcher := &DefaultDispatcher{}
	for _, tc := range []struct {
		ip   string
		want bool
	}{
		{"203.0.113.7", false},
		{"198.51.100.7", true},
	} {
		t.Run(tc.ip, func(t *testing.T) {
			destination := net.TCPDestination(net.ParseAddress(tc.ip), 443)
			got := dispatcher.shouldOverride(context.Background(), testSniffResult("public.example"), request, destination)
			if got != tc.want {
				t.Fatalf("shouldOverride(%q) = %v, want %v", tc.ip, got, tc.want)
			}
		})
	}
}
