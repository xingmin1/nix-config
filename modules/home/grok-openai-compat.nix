{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.grokOpenAICompat;

  inherit (lib) mkEnableOption mkIf mkOption types;

  python = pkgs.python3.withPackages (packages: [packages.aiohttp]);
  adapter = pkgs.writeTextFile {
    name = "grok-openai-compat.py";
    executable = true;
    text = ''
      #!${python}/bin/python
      import json
      from pathlib import Path

      from aiohttp import ClientSession, ClientTimeout, web


      UPSTREAM = ${builtins.toJSON cfg.upstream}
      CREDENTIAL_FILE = Path(${builtins.toJSON cfg.credentialFile})
      HOP_BY_HOP_HEADERS = {
          "connection",
          "content-length",
          "keep-alive",
          "proxy-authenticate",
          "proxy-authorization",
          "te",
          "trailer",
          "transfer-encoding",
          "upgrade",
      }
      ENTITY_INTEGRITY_HEADERS = {
          "content-md5",
          "digest",
          "etag",
      }


      def forwarded_headers(headers, entity_modified=False):
          """移除不能由代理逐跳转发的 HTTP 头。"""
          return {
              name: value
              for name, value in headers.items()
              if name.lower() not in HOP_BY_HOP_HEADERS
              and name.lower() != "host"
              and (not entity_modified or name.lower() not in ENTITY_INTEGRITY_HEADERS)
          }


      def authenticated_request_headers(headers):
          """读取私有凭据并覆盖发往 Codex2API 的认证头。"""
          try:
              api_key = CREDENTIAL_FILE.read_text(encoding="utf-8").strip()
          except OSError as error:
              raise web.HTTPServiceUnavailable(
                  reason=f"无法读取 Grok API 凭据: {error}",
              ) from error

          if not api_key:
              raise web.HTTPServiceUnavailable(reason="Grok API 凭据为空")

          request_headers = forwarded_headers(headers)
          request_headers["Authorization"] = f"Bearer {api_key}"
          return request_headers


      def rewrite_sse_line(line):
          """为非标准 Chat Completions 尾块补齐空 delta。"""
          if not line.startswith(b"data: "):
              return line

          payload = line[6:]
          if payload == b"[DONE]":
              return line

          try:
              event = json.loads(payload)
          except json.JSONDecodeError:
              return line

          changed = False
          for choice in event.get("choices", []):
              if "delta" not in choice:
                  choice["delta"] = {}
                  changed = True

          if not changed:
              return line

          return b"data: " + json.dumps(
              event,
              ensure_ascii=False,
              separators=(",", ":"),
          ).encode()


      def remove_x_search_tool(response):
          """从一个 Responses 响应对象的能力声明中移除 x_search。"""
          if not isinstance(response, dict):
              return False

          tools = response.get("tools")
          if not isinstance(tools, list):
              return False

          supported_tools = [
              tool
              for tool in tools
              if not isinstance(tool, dict) or tool.get("type") != "x_search"
          ]
          if len(supported_tools) == len(tools):
              return False

          response["tools"] = supported_tools
          return True


      def remove_unsupported_x_search(event):
          """仅修补 Responses 顶层或 SSE response 对象的工具声明。"""
          if not isinstance(event, dict):
              return False

          return remove_x_search_tool(event) or remove_x_search_tool(event.get("response"))


      def rewrite_responses_sse_line(line):
          """修补 Responses SSE 事件中的不兼容工具声明。"""
          if not line.startswith(b"data: "):
              return line

          payload = line[6:]
          if payload == b"[DONE]":
              return line

          try:
              event = json.loads(payload)
          except json.JSONDecodeError:
              return line

          if not remove_unsupported_x_search(event):
              return line

          return b"data: " + json.dumps(
              event,
              ensure_ascii=False,
              separators=(",", ":"),
          ).encode()


      def rewrite_responses_body(body):
          """修补非流式 Responses JSON 响应。"""
          try:
              response = json.loads(body)
          except json.JSONDecodeError:
              return body

          if not remove_unsupported_x_search(response):
              return body

          return json.dumps(
              response,
              ensure_ascii=False,
              separators=(",", ":"),
          ).encode()


      async def stream_response(request, upstream, rewrite_line):
          """逐行转发并修补 SSE 响应。"""
          response = web.StreamResponse(
              status=upstream.status,
              headers=forwarded_headers(upstream.headers, entity_modified=True),
          )
          await response.prepare(request)

          pending = b""
          async for chunk in upstream.content.iter_any():
              pending += chunk
              while b"\n" in pending:
                  line, pending = pending.split(b"\n", 1)
                  await response.write(rewrite_line(line) + b"\n")

          if pending:
              await response.write(rewrite_line(pending))

          await response.write_eof()
          return response


      async def proxy_request(request):
          """将请求转发到 Codex2API，并仅修补 Grok 不兼容的 SSE。"""
          target = f"{UPSTREAM}{request.rel_url}"
          timeout = ClientTimeout(total=None, sock_connect=10, sock_read=900)
          request_headers = authenticated_request_headers(request.headers)
          if request.path == "/v1/responses":
              request_headers.pop("Accept-Encoding", None)
              request_headers.pop("accept-encoding", None)

          async with ClientSession(
              timeout=timeout,
              auto_decompress=False,
              skip_auto_headers={"Accept-Encoding"},
          ) as session:
              async with session.request(
                  request.method,
                  target,
                  headers=request_headers,
                  data=await request.read(),
              ) as upstream:
                  content_type = upstream.headers.get("Content-Type", "")
                  if (
                      request.path == "/v1/chat/completions"
                      and "text/event-stream" in content_type
                  ):
                      return await stream_response(request, upstream, rewrite_sse_line)

                  if request.path == "/v1/responses":
                      if "text/event-stream" in content_type:
                          return await stream_response(
                              request,
                              upstream,
                              rewrite_responses_sse_line,
                          )

                      return web.Response(
                          body=rewrite_responses_body(await upstream.read()),
                          status=upstream.status,
                          headers=forwarded_headers(
                              upstream.headers,
                              entity_modified=True,
                          ),
                      )

                  return web.Response(
                      body=await upstream.read(),
                      status=upstream.status,
                      headers=forwarded_headers(upstream.headers),
                  )


      def main():
          """启动仅监听本机地址的 Grok OpenAI 兼容服务。"""
          application = web.Application(client_max_size=64 * 1024 * 1024)
          application.router.add_route("*", "/{path:.*}", proxy_request)
          web.run_app(
              application,
              host=${builtins.toJSON cfg.host},
              port=${toString cfg.port},
              print=None,
          )


      if __name__ == "__main__":
          main()
    '';
  };
in {
  options.services.grokOpenAICompat = {
    enable = mkEnableOption "Grok Build OpenAI 流式响应兼容服务";

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "兼容服务监听地址。";
    };

    port = mkOption {
      type = types.port;
      default = 8411;
      description = "兼容服务监听端口。";
    };

    upstream = mkOption {
      type = types.str;
      default = "http://127.0.0.1:8080";
      description = "需要转发到的 OpenAI-compatible 上游地址，不包含 /v1。";
    };

    credentialFile = mkOption {
      type = types.str;
      default = "${config.xdg.configHome}/ai-gateways/grok.key";
      description = "转发请求时读取的 Codex2API 凭据文件。";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isLinux;
        message = "services.grokOpenAICompat 依赖 systemd user services，只能在 Linux 上启用。";
      }
    ];

    systemd.user.startServices = "sd-switch";
    systemd.user.services.grok-openai-compat = {
      Unit = {
        Description = "修补 Grok Build 所需的 OpenAI 响应字段";
        Requires = ["codex2api.service"];
        After = ["codex2api.service"];
      };

      Service = {
        Type = "simple";
        ExecStart = adapter;
        Restart = "always";
        RestartSec = 2;
      };

      Install.WantedBy = ["default.target"];
    };
  };
}
