{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.programs.texlive;

  texlive = cfg.packageSet;
  texlivePkgs = cfg.extraPackages texlive;

in

{
  meta.maintainers = [ maintainers.rycee ];

  options = {
    programs.texlive = {
      enable = mkEnableOption "Texlive";

      packageSet = mkOption {
        default = pkgs.texlive;
        defaultText = ''pkgs.texlive'';
        description = "TeX Live package set.";
      };

      extraPackages = mkOption {
        default = tpkgs: { inherit (tpkgs) collection-basic; };
        defaultText = "tpkgs: { inherit (tpkgs) collection-basic; }";
        example = literalExample ''
          tpkgs: { inherit (tpkgs) collection-fontsrecommended algorithms; }
        '';
        description = "Extra packages available to Texlive.";
      };

      package = mkOption {
        type = types.package;
        description = "Resulting customized Texlive package.";
        readOnly = true;
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = texlivePkgs != {};
        message = "Must provide at least one extra package in"
          + " 'programs.texlive.extraPackages'.";
      }
    ];

    home.packages = [ cfg.package ];

    programs.texlive.package = texlive.combine texlivePkgs;
  };
}
