{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      utils,
      git-hooks,
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
          # Run with `nix develop -c pre-commit run -a`, or on commit once
          # `nix develop` has installed the hooks
          pre-commit = git-hooks.lib.${system}.run {
            src = self;
            hooks =
              let
                # Everything `make` installs or tests, plus Makefile.PL
                files = "^(Makefile\\.PL|bin/normalo|lib/.*\\.pm|t/.*\\.t)$";
              in
              {
                # The formatters, nixfmt and perltidy (through -b in
                # .perltidyrc), rewrite files in place, which fails the hook
                nixfmt.enable = true;
                perltidy = rec {
                  enable = true;
                  package = pkgs.perlPackages.PerlTidy;
                  entry = "${pkgs.lib.getExe package}";
                  inherit files;
                };
                perlcritic = rec {
                  enable = true;
                  package = pkgs.perlcritic;
                  entry = "${pkgs.lib.getExe package}";
                  inherit files;
                };
              };
          };
        };
        devShell =
          let
            inherit (self.checks.${system}.pre-commit) config shellHook enabledPackages;
          in
          pkgs.mkShell {
            inputsFrom = [ pkgs.perlPackages.AppNormalo ];
            # Install the hooks from a script, so that the exported shellHook
            # is a store path: the hook's own text has \' escapes, which break
            # tools that re-source `direnv export bash` output
            shellHook = "${pkgs.writeShellScript "install-git-hooks" shellHook}";
            # pre-commit, perltidy, perlcritic, and nixfmt
            packages = [ config.package ] ++ enabledPackages;
          };
      }
    );
}
