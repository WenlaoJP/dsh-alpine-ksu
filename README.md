# DSH Alpine KSU

A KernelSU module that runs a lightweight **Alpine Linux chroot** on Android arm64 and starts **DeepSeek Harness (DSH)** plus a browser terminal.

## Features

- Alpine Linux chroot, running as **UID 1**
- Node.js, npm, pnpm
- DeepSeek Harness with manual upstream updates
- `ttyd` + `tmux` + `bash` web terminal
- DSH workspace on `/sdcard/DSH/workspace`
- Full `/sdcard` bind mount inside the chroot
- Non-blocking boot startup with watchdog restart
- `dsh-url.txt` token link and terminal password in the module WebUI
- 16 KB page-size checks for Alpine/Node/native modules

## Requirements

- Android 16 arm64
- KernelSU / LKM (ReSukiSU also tested)
- 2 GB free space recommended
- 16 KB page-size compatible device

## Build

Build on an aarch64 Linux host as root:

```sh
PROFILE=full scripts/build-rootfs.sh
scripts/build-module.sh
```

The build downloads Alpine, installs Node/npm/pnpm/DSH, prunes non-runtime files, and creates:

```text
dist/dsh_alpine-<version>.zip
```

## Install

Install the ZIP with KernelSU Manager.

> **You must reboot after installation.** The installer is intentionally fast; the first boot extracts Alpine and DSH in the background.

Progress:

```sh
cat /data/adb/dsh/logs/bootstrap.log
```

## Usage

DSH:

```sh
cat /data/adb/dsh/state/dsh-url.txt
```

Terminal:

```text
http://127.0.0.1:7681/
user: dsh
password: /data/adb/dsh/state/ttyd-auth.txt
```

Update DSH manually:

```sh
dsh-update check
dsh-update next
dsh-update rollback
```

## Notes

- DSH is an Agent framework; it does not include a local model. An API key is required.
- The bare `http://127.0.0.1:3080/` URL returns `401` by design. Use the token URL.
- Chroot + UID 1 + no capabilities is the security boundary.

## License

MIT
