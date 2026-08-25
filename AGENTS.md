# Repository Guidelines

## 项目结构与模块组织
- `flake.nix`：入口 Flake；通过 `nixos-unified` 自动装配模块
- `modules/flake/*`：开发环境与打包（如 `formatter`、`neovim` 包）
- `modules/home/*`：home-manager 模块（git、direnv、nh、neovim、jjui 等）
- `modules/nixos/*`：NixOS 通用与 GUI 模块
- `configurations/home/xmin.nix`：用户与版本信息
- `configurations/nixos/<host>/default.nix`：主机级配置（示例：`nixos/`、`xfusion/`）
- `justfile`：常用开发命令

## 构建、测试与开发命令
- 更新依赖：`just update` 或 `nix flake update`
- 代码格式：`just lint` 或 `nix fmt`（Alejandra）
- 健康检查：`just check` 或 `nix flake check`
- 开发环境：`just dev` 或 `nix develop`
- 激活配置：`just run` 或 `nix run`（nixos-unified 提供 `activate`）
- 例：构建定制 Neovim：`nix build .#neovim`

## 代码风格与命名约定
- Nix 文件使用 2 空格缩进；提交前统一运行 `nix fmt`
- 模块按领域拆分与聚合：在目录下以 `default.nix` 自动导入其它模块
- 命名清晰、单一职责；避免魔法数字，提取为 `let` 常量
- 注释聚焦“为什么”与约束；中文注释为主

## 测试指南
- 以 `nix flake check` 作为回归门槛；本地修改需保持通过
- 对新增包/模块做最小构建验证（如 `nix build .#neovim`）
- 新主机放于 `configurations/nixos/<host>/default.nix` 并验证能评估

## 提交与 Pull Request 规范
- 提交信息遵循 conventional commits，使用中文简述：
  - 例：`feat(home): 增加 direnv 与 nh 配置`，并在正文用要点列出变更与动机
- PR 需包含：变更摘要、动机与影响、验证方式（命令/日志/截图），必要时关联 Issue

## 安全与配置提示（可选）
- 请勿提交私钥、令牌等敏感信息；主机私有数据放本地覆盖或私密仓库
- 变更镜像源/证书时标注来源与有效期，避免后续维护困难

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **nix-config** (184 symbols, 176 relationships, 0 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows. For regression review, compare against the default branch: `detect_changes({scope: "compare", base_ref: "main"})`.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `query({search_query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method without first running `impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit changes without running `detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/nix-config/context` | Codebase overview, check index freshness |
| `gitnexus://repo/nix-config/clusters` | All functional areas |
| `gitnexus://repo/nix-config/processes` | All execution flows |
| `gitnexus://repo/nix-config/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
