# V2bX

[![Telegram: Unofficial V2Board](https://img.shields.io/badge/Telegram-Unofficial_V2Board-green)](https://t.me/unofficialV2board)
[![Telegram: Yuzuki Projects](https://img.shields.io/badge/Telegram-Yuzuki_Projects-blue)](https://t.me/YuzukiProjects)

A multi-core V2Board node server based on XrayR, with support for V2Ray,
Trojan, Shadowsocks, and Hysteria protocols.

**Note: This project requires the [modified V2Board](https://github.com/wyx2685/v2board).**

## Features

* Permanently open source and free to use.
* Supports VMess/VLESS, Trojan, Shadowsocks, and Hysteria 1/2.
* Supports newer features such as VLESS and XTLS.
* Connects one instance to multiple nodes without running duplicate processes.
* Limits the number of online IP addresses and TCP connections.
* Supports per-node-port and per-user rate limits.
* Provides clear, straightforward configuration.
* Automatically restarts instances when their configuration changes.
* Supports multiple extensible cores.
* Supports build tags so only the required cores need to be compiled.

## Feature Support

| Feature | V2Ray | Trojan | Shadowsocks | Hysteria 1/2 |
|---|---|---|---|---|
| Automatic TLS certificate issuance | ✓ | ✓ | ✓ | ✓ |
| Automatic TLS certificate renewal | ✓ | ✓ | ✓ | ✓ |
| Online user statistics | ✓ | ✓ | ✓ | ✓ |
| Audit rules | ✓ | ✓ | ✓ | ✓ |
| Custom DNS | ✓ | ✓ | ✓ | ✓ |
| Online IP limit | ✓ | ✓ | ✓ | ✓ |
| Connection limit | ✓ | ✓ | ✓ | ✓ |
| Cross-node IP limit | ✓ | ✓ | ✓ | ✓ |
| Per-user rate limit | ✓ | ✓ | ✓ | ✓ |
| Dynamic rate limiting (untested) | ✓ | ✓ | ✓ | ✓ |

## TODO

- [ ] Reimplement dynamic rate limiting
- [ ] Improve the documentation

## Installation

### One-Click Installation

```bash
wget -N https://raw.githubusercontent.com/phungvanquy/v2bx-new/refs/heads/main/scripts/install.sh && bash install.sh
```

The installer, management script, configuration wizard, and systemd service
file are maintained in [`scripts/`](scripts/). The original root-level
`install.sh` URL remains available for existing one-click commands. The
installer downloads release archives from this repository and verifies their
SHA-256 digest before installing them.

### Elise Rust core for VLESS, VMess, AnyTLS, and Hysteria 1/2

The [Elise Rust source](rust/elise) lives in this repository. A V2bX release publishes the Go archives and the Elise Linux amd64/arm64 archives together. Elise runs as a separate systemd service for each panel node. Remove a node from `Nodes` in `/etc/V2bX/config.json` before assigning it to Elise, so one process owns its listener and panel reports.

```bash
v2bx elise install
v2bx elise add vless 123
v2bx elise add vmess 456
v2bx elise add anytls 789
v2bx elise add hysteria 101
v2bx elise add hysteria2 102
v2bx elise list
v2bx elise status vless-123
v2bx elise log vless-123
```

The installer downloads Elise from the same V2bX release and verifies its SHA-256 checksum. `v2bx elise install vX.Y.Z` selects a specific V2bX release; the V2bX release tag and Rust binary version are independent. It keeps the Rust binary in `/usr/local/libexec/V2bX` and per-node configuration in `/etc/v2bx-elise`. Linux amd64 and arm64 are supported. If Python 3 is missing, the Elise helper installs it with apt-get, dnf, or yum. The node wizard checks the panel port and security mode. REALITY keys must be configured in the panel. The selected V2bX release must contain Elise assets.

For TLS nodes (including AnyTLS and Hysteria 1/2), the wizard offers three certificate modes:

| Mode | Required input | Renewal |
| --- | --- | --- |
| Existing files (default) | Absolute paths to a PEM full chain and matching, unencrypted private key | Your certificate tool renews them; configure its deploy hook to run `v2bx elise restart <instance>` |
| Automatic Let's Encrypt (HTTP-01) | DNS hostname and account email | Elise checks every 12 hours, renews within 30 days of expiry, and reloads the listener |
| Self-signed | TLS hostname | Generates a persistent certificate valid for 365 days; trust it explicitly in the client and replace it before expiry |

Automatic mode requires the domain's A/AAAA records to point to this server and public inbound **TCP port 80** to remain available for issuance and renewal. The wizard checks local availability and DNS resolution; it cannot verify external firewall or NAT rules. Use a different TCP port for the proxy listener. HTTP-01 cannot issue wildcard certificates. See [Let's Encrypt HTTP-01 requirements](https://letsencrypt.org/docs/challenge-types/#http-01-challenge). DNS-01 issuance is not built into this wizard; certificates obtained with an external DNS client work with existing-file mode.

Automatic and self-signed files are stored in `/etc/v2bx-elise/<instance>/cert/`. Automatic issuance gets up to five minutes during startup. Failed startup preserves configuration and certificates and prints a recovery command. Automatic renewal reloads the listener and may interrupt active sessions; a renewal failure keeps a still-valid certificate for the next retry. Self-signed mode installs OpenSSL if necessary and prints the certificate's SHA-256 fingerprint. The Rust renewal changes require an Elise binary built from this revision; updating only the shell script does not update an older release binary.

AnyTLS and both Hysteria versions require a TLS certificate and private key. Hysteria listeners use UDP; the installer checks UDP port availability and startup. `hysteria1`/`hy1` are aliases for `hysteria`, and `hy2` is an alias for `hysteria2`. Instances use the canonical panel type, for example `hysteria-101` or `hysteria2-102`. A panel using `node_type=hysteria` with `version=2` selects the Hysteria 2 inbound automatically.

The Elise source retains its [PolyForm Noncommercial 1.0.0 license](rust/elise/LICENSE), separate from the V2bX Go source license.

### Manual Installation

[Manual installation guide](https://v2bx.v-50.me/v2bx/v2bx-xia-zai-he-an-zhuang/install/manual)

## Build

Requires Go 1.26 or newer (the pinned toolchain is Go 1.26.8).
See the [core update plan and compatibility notes](docs/core-updates.md) for the
embedded core versions and fork requirements.

```bash
# Select the cores to compile with -tags. Available cores: xray, sing, hysteria2.
GOEXPERIMENT=jsonv2 go build -v -o build_assets/V2bX -tags "sing xray hysteria2 with_quic with_grpc with_utls with_wireguard with_acme with_gvisor" -trimpath -ldflags "-X 'github.com/InazumaV/V2bX/cmd.version=$version' -s -w -buildid="
```

## Configuration and Usage

[Detailed usage guide](https://v2bx.v-50.me/)

## Disclaimer

* This project was created for personal use, so backward compatibility is not guaranteed.
* Not every feature is guaranteed to work. Please report problems through GitHub Issues.
* The maintainers are not responsible for any consequences arising from use of this project.
* The project structure and code may change substantially without notice. Do not use this
  project if that level of change is unacceptable.

## Sponsor

[Sponsor this project](https://v-50.me/)

## Thanks

* [Project X](https://github.com/XTLS/)
* [V2Fly](https://github.com/v2fly)
* [VNet-V2ray](https://github.com/ProxyPanel/VNet-V2ray)
* [Air-Universe](https://github.com/crossfw/Air-Universe)
* [XrayR](https://github.com/XrayR/XrayR)
* [sing-box](https://github.com/SagerNet/sing-box)

## Star History

[![Stargazers over time](https://starchart.cc/phungvanquy/v2bx-new.svg)](https://starchart.cc/phungvanquy/v2bx-new)
