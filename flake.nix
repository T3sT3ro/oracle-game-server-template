{
  description = "OCI Game Server Provisioning";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
        tools = with pkgs; [ terraform ansible ansible-lint openssh jq shellcheck oci-cli ];
        toolsEnv = pkgs.buildEnv { name = "oci-game-server-tools"; paths = tools; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = tools;
          # Terraform's licence keeps it out of the binary cache, so nix compiles it (minutes).
          # Mark the tools as in use (a GC root in .direnv/), so garbage collection keeps them.
          shellHook = ''
            root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            mkdir -p "$root/.direnv"
            nix-store --add-root "$root/.direnv/tools" --indirect --realise ${toolsEnv} >/dev/null
          '';
        };
      }
    );
}
