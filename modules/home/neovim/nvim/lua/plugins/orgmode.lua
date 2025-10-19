return {
  'nvim-orgmode/orgmode',
  event = 'VeryLazy',
  ft = { 'org' },
  config = function()
    -- Setup orgmode
    require('orgmode').setup({
      org_agenda_files = "~/org/**/*",
      org_default_notes_file = "~/org/refile.org",
    })

    -- 注意：不再强制 `ensure_installed = 'all'`，避免拉取所有语法解析器并导致少数解析器安装失败
    -- 如果你确实要用 'all'，请在 treesitter.lua 中统一设置，并在此添加 ignore_install = { 'org' }
    -- 这里不重复设置，使用主 treesitter 配置（lua/plugins/treesitter.lua）的 ensure_installed 列表
  end,
}
