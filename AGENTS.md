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
