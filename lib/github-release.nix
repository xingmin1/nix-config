{
  lib,
  fetchurl,
  metadata,
}: let
  release = builtins.fromJSON (builtins.readFile metadata);
in {
  tag = release.tag_name;
  version = lib.removePrefix "v" release.tag_name;
  asset = name: let
    entry = lib.findFirst (item: item.name == name) (throw "GitHub release ${release.html_url} has no ${name}") release.assets;
  in
    fetchurl {
      url = entry.browser_download_url;
      hash = builtins.convertHash {
        hash = lib.removePrefix "sha256:" entry.digest;
        hashAlgo = "sha256";
        toHashFormat = "sri";
      };
    };
}
