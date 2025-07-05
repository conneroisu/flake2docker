{
  description = "Basic development environment example";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: {
      devShells.default = nixpkgs.legacyPackages.${system}.mkShell {
        buildInputs = with nixpkgs.legacyPackages.${system}; [
          # Basic tools
          git
          curl
          wget
          jq
          
          # Development tools
          nodejs_20
          python3
          go
          
          # Fun tools for demonstration
          hello
          cowsay
          lolcat
        ];
        
        shellHook = ''
          echo "🚀 Welcome to the basic development environment!"
          echo "📦 Available tools: git, curl, wget, jq, node, python3, go"
          echo "🎉 Fun tools: hello, cowsay, lolcat"
          echo ""
          echo "Try: hello | cowsay | lolcat"
        '';
      };
    });
}