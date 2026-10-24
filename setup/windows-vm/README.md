# Windows build VM (optional)

Only needed if you want a desktop browser for interactive sign-in and MFA — every script itself runs on
Linux. `setup/windows-vm/` runs Windows 11 in Docker ([dockur/windows](https://github.com/dockur/windows),
QEMU/KVM) and installs the whole toolchain on first boot. It always runs on the **host's** Docker; the dev
container only drives it.

| Host | Needs |
|---|---|
| Linux | Docker Engine + Compose v2; CPU virtualization on in BIOS; `/dev/kvm` present (`sudo kvm-ok`) |
| Windows 11 | Docker Desktop, WSL 2 backend, **Linux containers** mode; nested virtualization (on by default) |

Not supported: Windows 10 hosts and macOS. Budget 8 GB RAM, 4 cores, 64 GB disk.

```bash
docker run --rm --device /dev/kvm alpine ls -l /dev/kvm       # check KVM first; prints a /dev/kvm line
echo "WINVM_PASSWORD=<a password>" >> setup/windows-vm/.env   # the VM user's: required, gitignored
docker compose -f setup/windows-vm/compose.yaml up -d         # start, from the repo root
docker compose -f setup/windows-vm/compose.yaml stop          # shut down, keep the disk
docker compose -f setup/windows-vm/compose.yaml down -v       # delete the VM and its disk
```

Watch the install at http://localhost:8006 or RDP to `localhost:3389` (user `halcourt`, password: the
`WINVM_PASSWORD` in `setup/windows-vm/.env`; there is no default, since the repo is public) — both bound to
localhost only. Every compose command reads that file, `stop` and `down` included, and stops if the password
isn't there. A VM installed before 2026-10-24 keeps the password it was installed with. The first start downloads Windows 11 Enterprise
evaluation (~7 GB, 90 days) and installs it unattended: allow 20–40 minutes, then
`setup/windows-vm/oem/bootstrap.ps1` installs the toolchain and logs to `C:\OEM\bootstrap.log`. Re-run it
from an elevated prompt if it failed (usually network).

The repo is drive `Z:`. Sign-in state lives in the Windows user profile, separate from the dev container's
`.azure/` and `.pac/`, so sign in to the lab tenant again inside the VM; `azd` environments live in the
repo's `.azure/` and are shared. Override `WINVM_RAM_SIZE`, `WINVM_CPU_CORES`, `WINVM_DISK_SIZE`,
`WINVM_USERNAME`, `WINVM_PASSWORD` or `WINVM_VERSION` in `setup/windows-vm/.env` before the first start.
