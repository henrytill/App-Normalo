{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      self,
      nixpkgs,
      utils,
    }:
    let
      # Read the version from the module so that it's kept in one place
      version = builtins.head (
        builtins.match ".*our [$]VERSION = '([^']+)';.*" (builtins.readFile ./lib/App/Normalo.pm)
      );
      overlay = final: prev: {
        perlPackages = prev.perlPackages.overrideScope (
          perlFinal: perlPrev: {
            AppNormalo = perlFinal.buildPerlPackage {
              pname = "App-Normalo";
              inherit version;
              src = self;
              propagatedBuildInputs = with perlFinal; [ TextUnidecode ];
            };
          }
        );
      };
    in
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages.default = pkgs.perlPackages.AppNormalo;
        checks = {
          build = pkgs.perlPackages.AppNormalo;
          # perltidy rewrites files in place (-b in .perltidyrc), so lint a
          # writable copy; --assert-tidy fails if anything changed
          lint =
            pkgs.runCommand "App-Normalo-lint"
              {
                nativeBuildInputs = with pkgs; [
                  perlcritic
                  perlPackages.PerlTidy
                ];
              }
              ''
                cp -r ${self} src
                chmod -R u+w src
                cd src
                perlcritic Makefile.PL lib bin t
                if ! perltidy --assert-tidy Makefile.PL lib/App/Normalo.pm bin/normalo t/*.t; then
                  cat ./*.ERR lib/App/*.ERR bin/*.ERR t/*.ERR 2>/dev/null
                  exit 1
                fi
                touch $out
              '';
        };
        devShell = pkgs.mkShell {
          inputsFrom = [ pkgs.perlPackages.AppNormalo ];
          packages = with pkgs; [
            perlcritic
            perlPackages.PerlTidy
          ];
        };
      }
    );
}
