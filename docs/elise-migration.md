# Elise has moved

Elise source, releases, and installation tools are maintained in
[phungvanquy/elise](https://github.com/phungvanquy/elise).
V2bX v0.6.8 bundled Elise 1.0.3; standalone releases begin at Elise v1.0.4.
Old V2bX release assets and repository history remain available.

For a server already running `V2bX-elise@` services, install the standalone
tools, inspect the migration, and then migrate:

```bash
curl -fsSL https://raw.githubusercontent.com/phungvanquy/elise/refs/tags/v1.0.4/install.sh -o /tmp/elise-install.sh &&
sudo bash /tmp/elise-install.sh install v1.0.4
sudo elisectl migrate --from-v2bx --dry-run
sudo elisectl migrate --from-v2bx
sudo elisectl list
```

Migration restarts running Elise nodes, briefly interrupting their connections.
Stopped nodes stay stopped, and their boot enable state is preserved.
It backs up configuration, preserves certificate identity, disables and masks
legacy services, and retires the cached `/usr/bin/V2bX-elise` helper only after
the new services pass their startup checks. Failed migrations attempt rollback.

Keep `/etc/v2bx-elise`: migrated nodes explicitly retain their existing traffic
state directories, which normally live beside the old configuration files.
Restoring old traffic snapshots could cause duplicate reports. Update external
certificate renewal hooks to `elisectl restart <instance>`.

The migrator stops before making changes if a configuration or service needs
manual adaptation, including certificates under `/etc/V2bX` or custom runtime
environment overrides. Follow the
[standalone migration and recovery guide](https://github.com/phungvanquy/elise/blob/main/docs/migration.md).

Use `elisectl add`, `status`, `log`, `restart`, and `update` to manage Elise.
The Rust executable remains available as `elise`. The new V2bX manager and
installer operate only on V2bX; the old `v2bx elise` entry points show this move.
Update the V2bX manager before uninstalling V2bX on an unmigrated server:
older cached managers can uninstall legacy Elise as part of V2bX uninstallation.
