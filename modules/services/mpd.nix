{ config, lib, pkgs, ... }:

with lib;

let

  name = "mpd";

  cfg = config.services.mpd;

  mpdConf = cfg: pkgs.writeText "mpd.conf" ''
    music_directory     "${cfg.musicDirectory}"
    playlist_directory  "${cfg.playlistDirectory}"
    ${lib.optionalString (cfg.dbFile != null) ''
      db_file             "${cfg.dbFile}"
    ''}
    state_file          "${cfg.dataDir}/state"
    sticker_file        "${cfg.dataDir}/sticker.sql"

    ${optionalString (cfg.network.listenAddress != "any")
      ''bind_to_address "${cfg.network.listenAddress}"''}
    ${optionalString (cfg.network.port != 6600)
      ''port "${toString cfg.network.port}"''}

    ${cfg.extraConfig}
  '';

  mpdOptions = cfg: {

  };

in {

  ###### interface

  options = {

    services.mpd = {

      enable = mkEnableOption "MPD, the music player daemon";

      package = mkOption {
        type = types.package;
        default = pkgs.mpd;
        defaultText = "pkgs.mpd";
        description = "MPD package to install.";
        example =  literalExample ''
          pkgs.mpd.override {
            alsaSupport = false;
            jackSupport = false;
          }
        '';
      };

      musicDirectory = mkOption {
        type = types.either types.path (types.strMatching "(http|https|nfs|smb)://.+");
        default = "${config.home.homeDirectory}/music";
        defaultText = "$HOME/music";
        apply = toString;       # Prevent copies to Nix store.
        description = ''
          The directory where mpd reads music from.
        '';
      };

      playlistDirectory = mkOption {
        type = types.either types.path types.str;
        default = "${cfg.dataDir}/playlists";
        defaultText = ''''${dataDir}/playlists'';
        apply = toString;       # Prevent copies to Nix store.
        description = ''
          The directory where mpd stores playlists.
        '';
      };

      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Extra directives added to to the end of MPD's configuration
          file, <filename>mpd.conf</filename>. Basic configuration
          like file location and uid/gid is added automatically to the
          beginning of the file. For available options see
          <citerefentry>
            <refentrytitle>mpd.conf</refentrytitle>
            <manvolnum>5</manvolnum>
          </citerefentry>.
        '';
      };

      dataDir = mkOption {
        type = types.either types.path types.str;
        default = "${config.xdg.dataHome}/${name}";
        defaultText = "$XDG_DATA_HOME/mpd";
        apply = toString;       # Prevent copies to Nix store.
        description = ''
          The directory where MPD stores its state, tag cache,
          playlists etc.
        '';
      };

      network = {

        listenAddress = mkOption {
          type = types.str;
          default = "127.0.0.1";
          example = "any";
          description = ''
            The address for the daemon to listen on.
            Use <literal>any</literal> to listen on all addresses.
          '';
        };

        port = mkOption {
          type = types.port;
          default = 6600;
          description = ''
            The TCP port on which the the daemon will listen.
          '';
        };

      };

      dbFile = mkOption {
        type = types.nullOr types.str;
        default = "${cfg.dataDir}/tag_cache";
        defaultText = ''''${dataDir}/tag_cache'';
        description = ''
          The path to MPD's database. If set to
          <literal>null</literal> the parameter is omitted from the
          configuration.
        '';
      };

    } // mpdOptions cfg;

  };


  ###### implementation

  config = mkIf cfg.enable {

    systemd.user.services.mpd = {
      Unit = {
        After = [ "network.target" "sound.target" ];
        Description = "Music Player Daemon";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };

      Service = {
        Environment = "PATH=${config.home.profileDirectory}/bin";
        ExecStart = "${cfg.package}/bin/mpd --no-daemon ${mpdConf cfg}";
        Type = "notify";
        ExecStartPre = ''${pkgs.bash}/bin/bash -c "${pkgs.coreutils}/bin/mkdir -p '${cfg.dataDir}' '${cfg.playlistDirectory}'"'';
      };
    };
  };

}
