# Core update plan

## Scope and dependency decisions

Update the embedded cores, reconcile their shared dependencies, adapt V2bX's
integration code, and verify the release build and runtime initialization.

| Component | Previous pin | Selected pin |
| --- | --- | --- |
| Xray fork | `63db1dc9e9e2` (2025-12-02) | `83ad74c46335` (2026-08-28; reports 26.7.28) |
| Hysteria core and extras | `v2.6.4` | `v2.12.2` |
| sing-box fork | `8d054dcd8bfe` | Retained: latest commit on its only branch, `dev-next` |
| Shared sing library | `v0.8.0-beta.6` | `v0.8.0-beta.10` compatibility replacement |
| sing-quic | `v0.6.0-beta.4` | `v0.6.0` |
| SagerNet QUIC | `v0.55.0-sing-box-mod.2` | `v0.59.0-sing-box-mod.2` |
| Go | `1.25.0` | Minimum `1.26.0`, toolchain `1.26.8` |

The `replace` directives select the code actually compiled. The Xray module's
upstream requirement is `v1.260327.0`, but the pinned fork supplies the implementation.
Keep both fork replacements independent of the requested module version so a
transitive upgrade cannot silently bypass them.

The sing-box fork exposes `AddUsers`, `DelUsers`, and router `GetCtx` methods used
by V2bX. Upstream sing-box `v1.14.0` does not provide these APIs. Updating that
core requires porting and maintaining those hooks in a newer fork; changing its
module version alone would break live panel user synchronization. Its existing
pin is retained deliberately.

The updated Xray fork requests sing `v0.8.9`, whose SOCKS handler adds a timeout
argument that the sing-box fork does not supply. A replacement selects
`v0.8.0-beta.10`, the version required by sing-quic `v0.6.0`, while retaining the
older handler signature. This is a compatibility constraint, not an update to
the latest sing library. Revisit it together with the sing-box fork.

The newer Xray and Hysteria dependencies also require QPACK `v0.6.0`. Update
sing-quic and SagerNet QUIC together: the previous QUIC version used the removed
QPACK decoder API, and updating QUIC alone breaks sing-quic's old logging API.

Sources checked on 2026-09-12:

- [Xray fork revision](https://github.com/wyx2685/xray-core/commit/83ad74c463351e01c7cde391abfd9dded9e78300)
- [Hysteria 2.12.2](https://github.com/HyNetworks/hysteria/releases/tag/app/v2.12.2)
- [sing-box fork branch](https://github.com/wyx2685/sing-box_mod/tree/dev-next)
- [Upstream sing-box 1.14.0](https://github.com/SagerNet/sing-box/releases/tag/v1.14.0)

## Implementation and verification sequence

1. Pin the updated Xray fork and matching Hysteria core/extras releases, then run
   `GOEXPERIMENT=jsonv2 go mod tidy` to reconcile and checksum dependencies.
2. Adapt removed or changed core APIs and registrations. Xray removed the legacy
   SRTP, TLS, UTP, WeChat, and WireGuard transport-header packages. Configurations
   using those header types need migration before rollout.
   The updated Xray also rejects plaintext Shadowsocks methods (`none`/`plain`)
   and no longer supports disabling IV checks. Remove `DisableIVCheck: true`.
   V2bX now uses Xray's compiled domain and IP matchers for sniffing exclusions and
   Hysteria's `WrapPacketConnSalamander` API. Failed obfuscation setup closes the
   socket. Stream settings are initialized even when VMess/VLESS transport
   settings are omitted, avoiding a nil-pointer panic during node creation.
3. Align the Docker builder and release workflow with the Go requirement. Retain
   `GOEXPERIMENT=jsonv2`, which V2bX uses directly.
4. Compile every package and test with all release tags. Run local tests and core
   lifecycle smoke tests with a timeout. Avoid the existing panel/ACME integration
   tests and the configuration watcher test, which runs indefinitely.
5. Build each selectable core and the combined release binary. Cross-compile the
   combined binary for the release targets: Linux amd64, arm64, and s390x.

Release tags:

```text
sing xray hysteria2 with_quic with_grpc with_utls with_wireguard with_acme with_gvisor
```

Before production rollout, exercise real panel user changes, traffic reporting,
TLS/REALITY, and any custom transports with a staging node. Local initialization
and build checks do not validate a production panel or remote clients.

## Validation

The core regression tests cover initialization, live VMess user add/delete/re-add
operations in both Xray and sing-box, Hysteria2 node and user lifecycles in both
QUIC implementations, Salamander packet exchange and error cleanup, sniffing
domain and IP exclusions, and Shadowsocks configuration/account compatibility.

The `Test cores` workflow runs those tests and builds each core selection plus
the combined binary. It also compiles every package, runs the bounded local
configuration/utility tests, checks module-graph consistency, and verifies module
checksums. Local verification passed these checks; the arm64 binary's `version`
command and build metadata were also checked. The Docker image was built and its
`version` command was executed successfully. A `.dockerignore` and module-first
copy order keep local artifacts out of the context and cache dependency downloads.
Live panel/ACME tests were not run.

Combined release-style builds passed for Linux amd64, arm64, and s390x with
`CGO_ENABLED=0`, `GOEXPERIMENT=jsonv2`, all release tags, `-trimpath`, and stripped
linker output. Local binaries are in the ignored `build_assets/` directory.
Only the native arm64 binary was executed; amd64 and s390x were cross-compiled.
