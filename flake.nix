{

description = "Podsync";

inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs";
  flake-utils.url = "github:numtide/flake-utils";
};

outputs = { self, nixpkgs, flake-utils }:
  flake-utils.lib.eachDefaultSystem (system:
    let pkgs = nixpkgs.legacyPackages.${system}; in
    {
      packages = rec {
        default = podsync;
        podsync = pkgs.buildGoModule rec {
          pname = "podsync";
          version = "v2.7.0";

          src = pkgs.fetchFromGitHub {
            owner = "mxpv";
            repo = "podsync";
            rev = "${version}";
            hash = "sha256-JfMHIvx6BwHsVOPFXXcfcXNEVd9c6+kmtabHzmDOz5E=";
          };

          vendorHash = "sha256-YgyNJoIC86dqIphZsgSM+Z5oNMLi3Lzol/9AVDQ++7I=";
          
          subPackages = [ "cmd/podsync" ];

          meta = with pkgs.lib; {
            description = "A Program to turn Youtube channels or playlist into rss feeds";
            platforms = platforms.linux;
            license = licenses.mit;
          };
        };
      };})
      // 
      {
      nixosModules.podsync = { lib, pkgs, config, ... }: 
        with lib;                      
        let
          inherit (pkgs.stdenv.hostPlatform) system;
          package = self.packages.${system}.podsync;
          cfg = config.services.podsync;
          tomlFormat = pkgs.formats.toml { };
          configFile = tomlFormat.generate "podsync.toml" cfg.config;
        in {
          options.services.podsync = {
            enable = mkEnableOption "enable podsync";
            config = mkOption {
              type = tomlFormat.type;
              default = {};
            };
          };

          config = mkIf cfg.enable {

            users = {
              users.podsync = { 
                isSystemUser = true;
                group = "podsync";
              };
              groups.podsync = {}; 
            };

            systemd.services.podsync = {
              path = with pkgs; [ 
                yt-dlp
                (pkgs.writeShellScriptBin "youtube-dl" "exec -a $0 ${yt-dlp}/bin/yt-dlp $@")
                go
                ffmpeg
                package
              ];
              serviceConfig = {
                ExecStart = "${package}/bin/podsync --debug --config ${configFile}";
                User = "podsync";
              };
              wantedBy = [ "multi-user.target" ];
              };
            };
        };
      };
}
