{
  description = "A CLI tool to build Docker containers from Nix flake devShells";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # The main CLI tool
        flake2docker = pkgs.writeShellApplication {
          name = "flake2docker";
          runtimeInputs = with pkgs; [ nix docker jq ];
          text = builtins.readFile ./src/flake2docker.sh;
        };

        # Advanced CLI with more features
        flake2docker-advanced = pkgs.writeShellApplication {
          name = "flake2docker-advanced";
          runtimeInputs = with pkgs; [ nix docker jq coreutils ];
          text = builtins.readFile ./src/flake2docker-advanced.sh;
        };

        # Nix-based Docker builder function
        mkDockerFromFlake = flakePath: system: let
          flake = builtins.getFlake flakePath;
          devShell = flake.devShells.${system}.default or flake.devShell.${system};
        in pkgs.dockerTools.buildImage {
          name = "flake-devshell";
          tag = "latest";
          
          contents = with pkgs; [
            bashInteractive
            coreutils
            findutils
            gnugrep
            gnused
          ] ++ (devShell.buildInputs or []);
          
          config = {
            Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
            WorkingDir = "/workspace";
            Env = [
              "PATH=${pkgs.lib.makeBinPath (devShell.buildInputs or [])}"
            ] ++ (devShell.shellHook or []);
          };
        };

        # Example Docker image for testing (commented out to avoid path issues)
        # example-docker = mkDockerFromFlake ./examples/basic-devenv.nix system;

        # Test helper function
        testFlake = pkgs.writeText "test-flake.nix" ''
          {
            description = "Test flake for flake2docker";
            inputs = {
              nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
              flake-utils.url = "github:numtide/flake-utils";
            };
            outputs = { self, nixpkgs, flake-utils }:
              flake-utils.lib.eachDefaultSystem (system: {
                devShells.default = nixpkgs.legacyPackages.''${system}.mkShell {
                  buildInputs = with nixpkgs.legacyPackages.''${system}; [
                    hello
                    cowsay
                    lolcat
                  ];
                  shellHook = '''
                    echo "Welcome to the test development environment!"
                    echo "Available commands: hello, cowsay, lolcat"
                  ''';
                };
              });
          }
        '';

      in {
        packages = {
          default = flake2docker;
          flake2docker = flake2docker;
          flake2docker-advanced = flake2docker-advanced;
        };

        apps = {
          default = flake-utils.lib.mkApp {
            drv = flake2docker;
          };
          flake2docker = flake-utils.lib.mkApp {
            drv = flake2docker;
          };
          flake2docker-advanced = flake-utils.lib.mkApp {
            drv = flake2docker-advanced;
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nix
            docker
            jq
            shellcheck
            flake2docker
            flake2docker-advanced
          ];
          
          shellHook = ''
            echo "🐋 flake2docker development environment"
            echo "Available commands:"
            echo "  flake2docker        - Basic CLI tool"
            echo "  flake2docker-advanced - Advanced CLI with more features"
            echo "  nix run .#flake2docker -- --help"
            echo ""
            echo "Run 'make test' to test the implementation"
          '';
        };

        # Formatter for the project
        formatter = pkgs.nixpkgs-fmt;

        # Library functions
        lib = {
          mkDockerFromFlake = mkDockerFromFlake;
        };
      });
}