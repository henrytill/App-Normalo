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
      overlay = final: prev: {
        perlPackages = prev.perlPackages.overrideScope (
          perlFinal: perlPrev: {
            AppNormalo = perlFinal.buildPerlPackage {
              pname = "App-Normalo";
              version = "0.03";
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
