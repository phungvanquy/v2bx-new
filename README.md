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
wget -N https://raw.githubusercontent.com/phungvanquy/v2bx-script-new/refs/heads/main/install.sh && bash install.sh
```

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
