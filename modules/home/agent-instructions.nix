{config, ...}: let
  sharedAgentsFile = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.codex/AGENTS.md";
in {
  home.file = {
    ".grok/AGENTS.md".source = sharedAgentsFile;
    ".grok/rules/00-tavily-search.md".text = ''
      # Tavily 联网检索规则

      - 所有需要联网搜索或获取实时信息的任务，必须主动优先使用 Tavily MCP。
      - 先用 `search_tool` 查找 Tavily 工具，再用 `use_tool` 调用 `tavily__tavily_search`；提取网页、抓取站点或建立站点地图时，分别调用对应的 Tavily MCP 工具。
      - 不要调用 Grok Build 内置的 `WebSearch` 或 `web_search` 工具及其专用模型；如果 Tavily MCP 不可用或调用失败，应明确报告错误，不得回退到 WebSearch。
      - `WebFetch` 和 `web_fetch` 不受此规则限制；已有明确 URL 且需要读取页面内容时，可以按需使用。
    '';
    ".codex/instructions/subagents.md".source = ../../assets/agent-instructions/codex-subagents.md;
    "AGENTS.md".source = sharedAgentsFile;
  };
}
