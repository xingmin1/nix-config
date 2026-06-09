{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib stdenv;

    system = stdenv.hostPlatform.system;
    codexCargoToml = builtins.fromTOML (builtins.readFile "${inputs.codex-src}/codex-rs/Cargo.toml");
    workspaceVersion = codexCargoToml.workspace.package.version;
    version =
      if workspaceVersion == "0.0.0"
      then "0.0.0-dev"
      else workspaceVersion;

    cargoHash = "sha256-Il3BZfsu0tWqNX9k1ZoBOmlT0OjKszA71/H7u3aHlFw=";

    librustyV8 = pkgs.fetchurl {
      name = "librusty_v8-149.2.0";
      url = "https://github.com/denoland/rusty_v8/releases/download/v149.2.0/librusty_v8_release_${stdenv.hostPlatform.rust.rustcTarget}.a.gz";
      hash =
        {
          x86_64-linux = "sha256-iu2YY323533Iv7i7R1nsW95HLQv3lD9Y4OYqNQlFxVk=";
          aarch64-linux = "sha256-+XdRJ8pk3MSjZi0BpSGizvuluY+DOUOog9hHc7Kv88U=";
          x86_64-darwin = "sha256-eUlAo4o/ZrfvUqXwA8awlPdDrQQKZK+z082frUlADwc=";
          aarch64-darwin = "sha256-+rsuyNO6Wm3qY9uaNalg3FypheujLzQrm6Sqocc0sv4=";
        }
        .${
          system
        };
      meta.sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };

    livekitWebrtcTriple =
      {
        x86_64-darwin = "mac-x64";
        aarch64-darwin = "mac-arm64";
      }
      .${
        system
      }
      or null;

    livekitWebrtc =
      if livekitWebrtcTriple == null
      then null
      else
        pkgs.fetchzip {
          name = "livekit-webrtc-webrtc-24f6822-2-${livekitWebrtcTriple}";
          url = "https://github.com/livekit/rust-sdks/releases/download/webrtc-24f6822-2/webrtc-${livekitWebrtcTriple}-release.zip";
          hash =
            {
              x86_64-darwin = "sha256-XapngujlXtcDEGd2hacmP3nHFycEVZRybO/ORHPc6Og=";
              aarch64-darwin = "sha256-4IwJM6EzTFgQd2AdX+Hj9NWzmyqXrSioRax2L6GKL1U=";
            }
            .${
              system
            };
          meta.sourceProvenance = [lib.sourceTypes.binaryNativeCode];
        };
  in {
    packages.codex = pkgs.rustPlatform.buildRustPackage {
      pname = "codex";
      inherit version;

      src = inputs.codex-src;
      inherit cargoHash;

      sourceRoot = "source/codex-rs";

      cargoBuildFlags = [
        "--package"
        "codex-cli"
      ];

      nativeBuildInputs = with pkgs; [
        installShellFiles
        makeWrapper
        pkg-config
      ];

      buildInputs =
        [pkgs.openssl]
        ++ lib.optionals stdenv.hostPlatform.isLinux [pkgs.libcap];

      env =
        {
          RUSTY_V8_ARCHIVE = librustyV8;
          CARGO_BUILD_JOBS = "2";
          CARGO_PROFILE_RELEASE_DEBUG = "false";
          CARGO_PROFILE_RELEASE_STRIP = "symbols";
        }
        // lib.optionalAttrs (livekitWebrtc != null) {
          LK_CUSTOM_WEBRTC = livekitWebrtc;
        };

      preBuild = ''
        substituteInPlace Cargo.toml \
          --replace-fail 'codegen-units = 1' 'codegen-units = 16'
      '';

      postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
        wrapProgram $out/bin/codex \
          --prefix PATH : ${lib.makeBinPath [pkgs.bubblewrap]}
      '';

      doCheck = false;

      postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
        installShellCompletion --cmd codex \
          --bash <($out/bin/codex completion bash) \
          --fish <($out/bin/codex completion fish) \
          --zsh <($out/bin/codex completion zsh)
      '';

      passthru.category = "AI Coding Agents";

      meta = {
        description = "OpenAI Codex CLI，使用 xingmin1/codex fork 构建";
        homepage = "https://github.com/xingmin1/codex";
        license = lib.licenses.asl20;
        mainProgram = "codex";
        platforms = lib.platforms.unix;
        sourceProvenance = with lib.sourceTypes; [
          fromSource
          binaryNativeCode
        ];
      };
    };

  };
}
