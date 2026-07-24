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

      from aiohttp import ClientSession, ClientTimeout, web


      UPSTREAM = ${builtins.toJSON cfg.upstream}
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


      def forwarded_headers(headers):
          """移除不能由代理逐跳转发的 HTTP 头。"""
          return {
              name: value
              for name, value in headers.items()
              if name.lower() not in HOP_BY_HOP_HEADERS and name.lower() != "host"
          }


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


      async def stream_chat_response(request, upstream):
          """逐行转发并修补 Chat Completions SSE 响应。"""
          response = web.StreamResponse(
              status=upstream.status,
              headers=forwarded_headers(upstream.headers),
          )
          await response.prepare(request)

          pending = b""
          async for chunk in upstream.content.iter_any():
              pending += chunk
              while b"\n" in pending:
                  line, pending = pending.split(b"\n", 1)
                  await response.write(rewrite_sse_line(line) + b"\n")

          if pending:
              await response.write(rewrite_sse_line(pending))

          await response.write_eof()
          return response


      async def proxy_request(request):
          """将请求转发到 Codex2API，并仅修补 Grok 不兼容的 SSE。"""
          target = f"{UPSTREAM}{request.rel_url}"
          timeout = ClientTimeout(total=None, sock_connect=10, sock_read=900)

          async with ClientSession(timeout=timeout, auto_decompress=False) as session:
              async with session.request(
                  request.method,
                  target,
                  headers=forwarded_headers(request.headers),
                  data=await request.read(),
              ) as upstream:
                  content_type = upstream.headers.get("Content-Type", "")
                  if (
                      request.path == "/v1/chat/completions"
                      and "text/event-stream" in content_type
                  ):
                      return await stream_chat_response(request, upstream)

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
        Description = "修补 Grok Build 所需的 OpenAI 流式响应字段";
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
