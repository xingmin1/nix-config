{
  lib,
  rustPlatform,
  makeWrapper,
  pkg-config,
  procps,
  sqlite,
  zstd,
  src,
}: let
  workspace = builtins.fromTOML (builtins.readFile "${src}/Cargo.toml");
in
  rustPlatform.buildRustPackage {
    pname = "weflow";
    version = "${workspace.workspace.package.version}-unstable-${src.shortRev}";
    inherit src;
    nativeBuildInputs = [makeWrapper pkg-config];
    buildInputs = [sqlite zstd];

    cargoLock = {
      lockFile = "${src}/Cargo.lock";
      # 直接使用上游锁文件中的 Git 依赖，让 Flake 更新时同步跟进。
      allowBuiltinFetchGit = true;
    };
    cargoBuildFlags = ["-p" "weflow-cli"];
    cargoTestFlags = ["-p" "weflow-core" "--test" "image_keys_e2e"];

    postInstall = ''
      install -Dm644 LICENSE "$out/share/licenses/weflow/LICENSE"
    '';

    postFixup = ''
      wrapProgram "$out/bin/weflow" --prefix PATH : "${lib.makeBinPath [procps]}"
    '';

    meta = {
      description = "WeChat local archive tool";
      homepage = "https://github.com/334456777/WeFlow";
      license = lib.licenses.unlicense;
      mainProgram = "weflow";
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  }
