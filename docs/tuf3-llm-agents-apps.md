# tuf3 的 llm-agents.nix 桌面应用

2026-11-24，使用当前 `flake.lock` 锁定的 `numtide/llm-agents.nix` 输入安装四个应用。

| 应用 | 锁定版本 | Nix 包 |
| --- | --- | --- |
| AionUi | 2.2.2 | `aionui` |
| Cindy | 0.1.136 | `cindy` |
| Orca | 1.4.272 | `orca` |
| T3 Code | 0.1.11 | `t3code-desktop` |

- 声明式配置位于 `modules/home/packages.nix`，沿用现有 `llmAgentPackages`，重建 Home Manager 后会持续保留。
- 当前用户 profile 已立即加入四个锁定版本。命令入口已核对，分别是 `aionui`、`cindy`、`orca` 和 `t3code-desktop`。
- `llm-agents.nix` 已从 2026-11-18 的锁定提交更新到 2026-11-24 的 `45e6e554481f962d4134021d3a63c96d8755f395`。更新后 Orca 和 T3 Code 已切换到新包。Cindy 上游正式版已经是 0.1.144，但当前 `llm-agents.nix` 提交仍打包 0.1.136，因此没有把 GitHub Release 混入这套声明式安装。 [llm-agents.nix 当前提交](https://github.com/numtide/llm-agents.nix/commit/45e6e554481f962d4134021d3a63c96d8755f395) · [Cindy v0.1.144](https://github.com/makecindy/cindy/releases/tag/v0.1.144)
- KDE 应用入口已核对。Cindy、Orca 和 T3 Code 有桌面入口。AionUi 当前包提供命令入口但没有导出的 `.desktop` 文件，可从终端运行 `aionui`。
- Magpie 的「添加 Cindy」最初提示没有程序能打开 `cindy://` 链接。Cindy 的桌面文件本身已声明该协议，但桌面索引没有从用户 profile 注册它。已把 `cindy.desktop` 显式导出到用户应用目录，并在 KDE MIME 默认项中声明 `x-scheme-handler/cindy` 和 `x-scheme-handler/xdt-maker`。现在 `magpie cindy add` 和 `xdg-open cindy://...` 都能启动 Cindy。
- 四个包及其依赖从 Numtide 缓存和现有 Nix 缓存获取，未使用 GitHub AppImage，也未自行构建上游源码。构建检查解析到 333.2 MiB 下载、约 5.8 GiB 解包路径，最终包本身从缓存取得。
