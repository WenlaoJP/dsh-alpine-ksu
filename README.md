# DSH Alpine KSU

在 Android arm64 上运行 **Alpine Linux chroot**，后台启动 **DeepSeek Harness（DSH）** 和轻量 Web 终端。

> PoC / pre-release。请先在可恢复的设备上测试。

## 主要功能

- Alpine Linux 3.24.2 aarch64 chroot
- Node.js 24 / npm / pnpm
- DeepSeek Harness 0.2.1-rc.2
- ttyd + tmux + bash Web 终端
- DSH、ttyd、supervisor 均以 **UID 1** 运行
- `oom_score_adj=-1000`，普通 App 无法直接杀死
- 非阻塞开机启动 + watchdog 自动重启
- 完整 `/sdcard` bind mount
- DSH 工作区：`/sdcard/DSH/workspace`
- npm/pnpm 缓存：`/sdcard/DSH/npm`
- 16KB page-size 兼容性检查
- 模块 WebUI 显示 UID、DSH token 直链、终端密码、日志和诊断
- 手动跟随上游 DSH 更新

## 架构

```text
KernelSU module
  └─ service.sh / boot-completed.sh (立即返回)
       └─ bin/dsh-service-boot
            ├─ dsh-bootstrap：后台解压 Alpine + DSH
            └─ dsh-watchdog
                 └─ dsh-launch
                      └─ mount + chroot + setpriv
                           └─ dsh-supervisor (UID 1)
                                ├─ dsh web   127.0.0.1:3080
                                └─ ttyd      127.0.0.1:7681
```

安装器只创建目录和脚本，**不会在 KernelSU 安装过程中解压约 800MB 的运行时**。首次开机由 `dsh-bootstrap` 在后台解压，避免管理器卡死。

## 系统要求

- 内核版本 >= 5.10
- 建议至少 2GB 可用空间
- 16KB page-size 兼容设备

## 安装

1. 从 Release 下载模块 ZIP；
2. 在 KernelSU / ReSukiSU 中安装；
3. **必须重启设备**；
4. 首次开机会在后台解压 Alpine 和 DSH，约需 10–60 秒。

查看解压进度：

```sh
cat /data/adb/dsh/logs/bootstrap.log
```

> 首次解压完成前 DSH 端口暂时不可用，这是正常现象。

## 使用

### DSH

DSH 使用 token 认证。裸 `http://127.0.0.1:3080/` 返回 `401` 是正常行为，不要直接打开。

查看完整 token 链接：

```sh
cat /data/adb/dsh/state/dsh-url.txt
```

也可以打开模块 WebUI，查看直链/点击：

```text
从浏览器打开 DSH
```

### 终端

```text
http://127.0.0.1:7681/
用户名：dsh
密码：查看 /data/adb/dsh/state/ttyd-auth.txt
```

模块 WebUI 会直接显示终端密码。

### 状态与诊断

```sh
sh /data/adb/modules/dsh_alpine/action.sh status
sh /data/adb/modules/dsh_alpine/action.sh diag
cat /data/adb/dsh/state/dsh-url.txt
cat /data/adb/dsh/state/ttyd-auth.txt
```


## 更新 DSH

```sh
dsh-update check
dsh-update next       # 跟随 npm next，当前是 0.2.1-rc 线
dsh-update latest     # 跟随 npm latest
dsh-update rollback
```

`dsh-update` 会暂存安装、重建 `node-pty`、修补 koffi musl loader、裁剪运行时并重启 DSH。

注意：npm 的 `latest` 当前可能比 `next` 旧；需要最新 rc 时使用 `dsh-update next`。

不建议用 `npx` 升级正式服务；`npx` 只适合临时测试，不会更新 `/opt/dsh/current`。


## 构建

需要 aarch64 Linux 主机和 root；发布工作流也支持 QEMU 交叉构建。

```sh
sudo env PROFILE=full DSH_VERSION=0.2.1-rc.2 scripts/build-rootfs.sh
scripts/build-module.sh
```

生成：

```text
dist/dsh_alpine-<version>.zip
```

构建产物和 payload 不提交到 Git，见 `.gitignore`。

## 安全说明

- 进程最终以 UID 1 运行，无 capabilities；
- 不使用 root 运行 DSH/终端；
- DSH 和 ttyd 只监听 `127.0.0.1`；
- DSH 使用 token + Cookie + Host/Origin 校验；
- ttyd 使用随机 Basic Auth；
- 安全边界是 chroot + UID 1，不是虚拟机；

## License

MIT
