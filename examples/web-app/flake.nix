{
  description = "Web application development environment";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Node.js ecosystem
            nodejs_20
            yarn
            pnpm
            
            # Build tools
            esbuild
            
            # Development tools
            git
            curl
            jq
            
            # Database tools
            postgresql
            sqlite
            
            # Process management
            overmind
            
            # Linting and formatting
            nodePackages.eslint
            nodePackages.prettier
            
            # Testing
            playwright
          ];
          
          shellHook = ''
            export NODE_ENV=development
            export PORT=3000
            export API_PORT=8080
            
            echo "🌐 Web Application Development Environment"
            echo "================================"
            echo "🚀 Node.js: $(node --version)"
            echo "📦 Package managers: yarn, pnpm"
            echo "🔧 Build tools: esbuild"
            echo "🗄️ Databases: postgresql, sqlite"
            echo "🧪 Testing: playwright"
            echo ""
            echo "Common commands:"
            echo "  yarn install     - Install dependencies"
            echo "  yarn dev         - Start development server"
            echo "  yarn build       - Build for production"
            echo "  yarn test        - Run tests"
            echo "  yarn lint        - Run linting"
            echo "  yarn format      - Format code"
            echo ""
            echo "🐳 To containerize this environment:"
            echo "  flake2docker-advanced --port 3000 --port 8080 --load"
            echo "  docker run -it --rm -p 3000:3000 -p 8080:8080 -v \$(pwd):/workspace flake-devshell:latest"
          '';
          
          # Environment variables
          NIX_SHELL_PRESERVE_PROMPT = 1;
        };
      });
}