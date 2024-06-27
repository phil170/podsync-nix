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
            description = "Turn YouTube or Vimeo channels, users, or playlists into podcast feeds";
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
          command = "${cfg.package}/bin/podsync --debug -c <(cat ${configFile} ${cfg.tokenFile})";
        in {
          options.services.podsync = {

            enable = mkEnableOption "enable podsync";

            package = mkOption {
              type = types.package;
              default = package;
              defaultText = literalExpression "pkgs.podsync";
              description = "The podsync package to use";
            };

            config = mkOption {
              type = tomlFormat.type;
              description =
                "Podsync configuration. See https://github.com/mxpv/podsync#configuration for more information.";
              default = { };
            };

            tokenFile = mkOption {
              type = types.str;
              default = "";
              description = "Path (as string) to a file containing the [tokens] section of the configuration";
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
                (writeShellScriptBin "youtube-dl" "exec -a $0 ${yt-dlp}/bin/yt-dlp $@") # workaround, youtube-dl fails if used
                ffmpeg
              ];
              serviceConfig = {
                  ExecStart = "${pkgs.bash}/bin/bash -c '${command}'";
                  User = "podsync";
              };
              wantedBy = [ "multi-user.target" ];
            };
          };
        };
      };
}
