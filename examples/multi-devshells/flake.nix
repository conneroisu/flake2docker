{
  description = "Multi-environment development setup";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells = {
          # Default development shell
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              git
              curl
              jq
            ];
            shellHook = ''
              echo "🔧 Default development environment"
            '';
          };
          
          # Frontend development
          frontend = pkgs.mkShell {
            buildInputs = with pkgs; [
              nodejs_20
              yarn
              typescript
              tailwindcss
            ];
            shellHook = ''
              echo "🎨 Frontend development environment"
              echo "📦 Available: node, yarn, typescript, tailwindcss"
              echo "🚀 Run: yarn install && yarn dev"
            '';
          };
          
          # Backend development
          backend = pkgs.mkShell {
            buildInputs = with pkgs; [
              python3
              python3Packages.pip
              python3Packages.virtualenv
              python3Packages.fastapi
              python3Packages.uvicorn
              postgresql
              redis
            ];
            shellHook = ''
              echo "🔧 Backend development environment"
              echo "📦 Available: python3, pip, fastapi, uvicorn, postgresql, redis"
              echo "🚀 Run: pip install -r requirements.txt && uvicorn main:app --reload"
            '';
          };
          
          # DevOps environment
          devops = pkgs.mkShell {
            buildInputs = with pkgs; [
              docker
              kubernetes
              helm
              kubectl
              terraform
              ansible
            ];
            shellHook = ''
              echo "⚙️ DevOps environment"
              echo "📦 Available: docker, kubernetes, helm, kubectl, terraform, ansible"
            '';
          };
          
          # Database development
          database = pkgs.mkShell {
            buildInputs = with pkgs; [
              postgresql
              mysql80
              redis
              mongodb
              sqlite
            ];
            shellHook = ''
              echo "🗄️ Database development environment"
              echo "📦 Available: postgresql, mysql, redis, mongodb, sqlite"
            '';
          };
        };
      });
}