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
          # Makefile.PL writes a Makefile, so lint a writable copy
          lint =
            pkgs.runCommand "App-Normalo-lint"
              {
                nativeBuildInputs = with pkgs; [
                  perl
                  perlcritic
                  perlPackages.PerlTidy
                ];
              }
              ''
                cp -r --no-preserve=mode ${self} src
                cd src
                perl Makefile.PL
                make lint
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
