{
  description = "OCI Game Server Provisioning and Deployment Shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true; # Allows proprietary packages like HashiCorp Terraform
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Infrastructure Provisioning
            opentofu
            terraform
            oci-cli

            # Configuration Management
            ansible
            ansible-lint
            ansible-python-supplements

            # Container & Stack Management
            docker
            docker-compose

            # Network Utilities & Inspection
            openssh
            bind          # Provides `dig`
            curl
            jq
          ];

          shellHook = ''
            echo "=== OCI Game Server Infrastructure Shell ==="
            echo "Terraform: $(terraform --version | head -n 1)"
            echo "Ansible:   $(ansible --version | head -n 1)"
            echo "Docker:    $(docker compose version)"
            echo "==========================================="
          '';
        };
      }
    );
}