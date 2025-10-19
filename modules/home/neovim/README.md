# Neovim 编辑器

基于 [AstroNvim](https://github.com/AstroNvim/AstroNvim) 的 Neovim 配置。更多信息请访问
[AstroNvim 官方网站](https://astronvim.com/)。

本文档说明 Neovim 的配置结构以及常用快捷键/命令，帮助高效使用。

## 截图

![](/_img/astronvim_2023-07-13_00-39.webp) ![](/_img/hyprland_2023-07-29_2.webp)

## 配置结构（Configuration Structure）

| 描述                                                 | 标准位置                                        | 我的位置                                                                    |
| ---------------------------------------------------- | ----------------------------------------------- | --------------------------------------------------------------------------- |
| Neovim 主配置（config）                              | `~/.config/nvim`                               | AstroNvim 的 GitHub 仓库，通过本 flake 的 input 引用（flake input）         |
| AstroNvim 用户配置（user config）                    | `$XDG_CONFIG_HOME/astronvim/lua/user`          | [./astronvim_user/](./astronvim_user/)                                      |
| 插件安装目录（lazy.nvim 插件管理器 | plugin manager） | `~/.local/share/nvim/`                         | 与标准位置相同，由 lazy.nvim 生成并管理                                     |
| LSP、DAP、linters、formatters                        | `~/.local/share/nvim/mason/`（mason.nvim 管理） | [./default.nix](./default.nix) 通过 Nix 安装（installed by Nix）            |

## 更新/清理插件（lazy.nvim）

注意：lazy.nvim 默认不会自动更新插件，需要手动执行更新。

```bash
:Lazy update
```

移除所有未使用的插件：

```bash
:Lazy clean
```

## 测试（Testing）

> 使用仓库根目录的 `Justfile`。

```bash
# 运行测试
just nvim-test

# 清理测试数据
just nvim-clear
```

## 速查表（Cheatsheet）

以下为与本 Neovim 配置相关的速查表。在阅读下文前，建议先阅读通用 Vim 速查表：
[../README.md](../README.md)。

### 增量选择（Incremental Selection）

由 nvim-treesitter 提供。

| 动作               | 快捷键          |
| ------------------ | --------------- |
| 初始化选择         | `<Ctrl-space>`  |
| 节点增量选择       | `<Ctrl-space>`  |
| 作用域增量选择     | `<Alt-Space>`   |
| 节点反向减量选择   | `Backspace`     |

### 搜索与跳转（Search and Jump）

由 [flash.nvim](https://github.com/folke/flash.nvim) 提供，是一个智能搜索与跳转插件（intelligent search & jump）。

1. 增强 Neovim 默认的搜索与跳转行为（使用 `/` 前缀进行搜索）。

| 动作                 | 快捷键                                                                                                       |
| -------------------- | ------------------------------------------------------------------------------------------------------------ |
| 搜索（Search）       | `/`（常规搜索），`s`（关闭代码高亮，仅高亮匹配项）                                                           |
| Treesitter 搜索      | `yR`、`dR`、`cR`、`vR`、`Ctrl+v+R`（在匹配周围标注所有相邻的 Treesitter 节点 | surrounding Treesitter nodes） |
| 远程跳转（Remote）   | `yr`、`dr`、`cr`（在匹配周围标注所有相邻的 Treesitter 节点）                                                  |

### 常用命令与快捷键（Commands & Shortcuts）

| 动作                              | 快捷键         |
| --------------------------------- | -------------- |
| 打开文件树（Neo-tree）            | `<Space> + e`  |
| 聚焦当前文件（Neo-tree focus）    | `<Space> + o`  |
| 切换自动换行                      | `<Space> + uw` |
| 显示当前行诊断信息                | `gl`           |
| 查看函数/变量信息（LSP hover）    | `K`            |
| 查看符号引用（LSP references）    | `gr`           |
| 下一个标签页                      | `]b`           |
| 上一个标签页                      | `[b`           |

### 窗口导航（Window Navigation）

- 窗口间切换：`<Ctrl> + h/j/k/l`
- 调整窗口大小：`<Ctrl> + Up/Down/Left/Right`（等价于 `<Ctrl-w> + -/+/</>`）
  - 提示：在 macOS 上与系统快捷键冲突
  - 可在 系统设置 -> 键盘 -> 快捷键 -> Mission Control 中关闭

### 分屏与缓冲区（Splitting and Buffers）

| 动作             | 快捷键         |
| ---------------- | -------------- |
| 水平分屏         | `\\`          |
| 垂直分屏         | `\\|`         |
| 关闭缓冲区       | `<Space> + c`  |

### 编辑与格式化（Editing and Formatting）

| 动作                                                        | 快捷键         |
| ----------------------------------------------------------- | -------------- |
| 切换缓冲区自动格式化                                        | `<Space> + uf` |
| 格式化文档（LSP format）                                    | `<Space> + lf` |
| 代码操作（Code Actions）                                    | `<Space> + la` |
| 重命名（Rename）                                            | `<Space> + lr` |
| 打开 LSP 符号（Symbols）                                    | `<Space> + lS` |
| 注释当前行/选区（多行支持）                                 | `<Space> + /`  |
| 打开光标处的路径/URL（Neovim 内建命令 gx）                  | `gx`           |
| 按文件名查找（fzf）                                         | `<Space> + ff` |
| 按文件名查找（包含隐藏文件 | include hidden）               | `<Space> + fF` |
| 全局字符串搜索（ripgrep）                                   | `<Space> + fw` |
| 全局字符串搜索（包含隐藏文件 | include hidden）             | `<Space> + fW` |

### Git

| 动作                           | 快捷键          |
| ------------------------------ | --------------- |
| 查看提交（仓库级）             | `:<Space> + gc` |
| 查看提交（当前文件）           | `:<Space> + gC` |
| 分支列表                       | `:<Space> + gb` |
| 仓库状态                       | `:<Space> + gt` |

### 会话（Sessions）

| 动作                               | 快捷键         |
| ---------------------------------- | -------------- |
| 保存会话                           | `<Space> + Ss` |
| 打开上次会话                       | `<Space> + Sl` |
| 删除会话                           | `<Space> + Sd` |
| 搜索会话                           | `<Space> + Sf` |
| 加载当前目录的会话                 | `<Space> + S.` |

### 调试（Debugging）

按下 `<Space> + D` 查看可用按键绑定与选项。

### 全局查找替换（Search and Replace Globally）

| 描述                                          | 快捷键         |
| --------------------------------------------- | -------------- |
| 打开 spectre.nvim 查找替换面板（search/replace） | `<Space> + ss` |

通过 CLI 工具进行查找替换（fd + sad + delta）：

```bash
fd "\\.nix$" . | sad '<pattern>' '<replacement>' | delta
```

### 成对包围字符（Surrounding Characters）

由 mini.surround 插件提供（mini.surround plugin）。

- 前缀使用 `gz`

| 动作                             | 快捷键   | 说明                                                 |
| -------------------------------- | -------- | ---------------------------------------------------- |
| 添加包围字符（add surround）     | `gzaiw'` | 在光标所在单词两侧添加 `'`                            |
| 删除包围字符（delete surround）  | `gzd'`   | 删除光标所在单词两侧的 `'`                           |
| 替换包围字符（replace surround） | `gzr'"`  | 将光标所在单词两侧的 `'` 替换为 `"`                  |
| 高亮包围字符（highlight）        | `gzh'`   | 高亮显示光标所在单词两侧的 `'`                       |

### 文本结构操作（Text Manipulation）

| 动作                                        | 快捷键         |
| ------------------------------------------- | -------------- |
| LSP 语义合并为一行（treesj join）          | `<Space> + j` |
| 拆分为多行（treesj split）                 | `<Space> + s` |

### 杂项（Miscellaneous）

| 动作                            | 快捷键          |
| ------------------------------- | --------------- |
| 显示完整 Yank 历史              | `:<Space> + yh` |
| 显示撤销（undo）历史            | `:<Space> + uh` |
| 显示当前文件路径                | `:!echo $%`     |

## 更多资源（Additional Resources）

了解更多细节与高级用法：

1. [AstroNvim walkthrough](https://astronvim.com/Basic%20Usage/walkthrough)
2. [./astronvim_user/mapping.lua](./astronvim_user/mappings.lua)
3. 各插件的官方文档（plugins' documentations）
