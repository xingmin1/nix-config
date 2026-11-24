# tuf3 WeFlow 升级记录

2026-11-23，NixOS，x86_64。旧的终端命令是 `6.0.0-unstable-d4a8fe4`，网页进程也是旧版，由 Konsole 中的管理员会话在 `127.0.0.1:18108` 启动。

## CLI 7.0.0

- `configurations/nixos/tuf3/weflow.nix` 固定官方稳定版 7.0.0 的 Linux x64 和 arm64 预编译包。下载的 x64 包 SHA-256 与官方清单和 GitHub 发行资产的 digest 相符，两个架构的校验值均写入 Nix 表达式。使用 `autoPatchelfHook` 接入 NixOS 的动态库。 [WeFlow v7.0.0](https://github.com/334456777/WeFlow/releases/tag/v7.0.0)
- `nix flake check` 和 tuf3 系统构建通过。将新包加入当前用户的 Nix profile，Bash 和 fish 均优先解析到该版本。`weflow --version` 输出 `weflow 7.0.0 (f292b7c 2026-11-21 13:29Z)`。本次未切换系统代次，避免一并启用工作区中其他配置改动。arm64 未实际构建。

## WebUI 0.6.0

- WebUI 单独安装。用临时配置目录运行新版 `weflow web install 0.6.0`，核对 UI 元数据中的 `minBackendVersion=7.0.0`、`apiVersion=3`，再在回环端口 18109 启动测试。请求 `/ui/` 返回 HTTP 200，入口脚本是 `index-C4GqihRK.js`。
- 首次切换因 `upgrade-weflow: 行 21: /run/current-system/sw/bin/jq: 没有那个文件或目录` 提前中止，旧服务继续运行。重试直接使用 `weflow web install 0.6.0` 的退出状态作前置校验，成功后才停止旧进程。在原工作目录及原配置路径下运行 `weflow serve --no-browser --host 127.0.0.1 --port 18108 --web-version 0.6.0`。
- 核对 18108 的监听进程使用新版二进制，访问 `/ui/` 返回新版入口脚本。该进程仍随用于启动服务的 Konsole 窗口运行。测试仅检查了版本、启动与页面响应，未执行实际导出。
