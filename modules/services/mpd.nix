{ config, lib, pkgs, ... }:

with lib;

let

  name = "mpd";

  cfg = config.services.mpd;

  mpdConf = dcfg: pkgs.writeText "mpd.conf" ''
    music_directory     "${dcfg.musicDirectory}"
    playlist_directory  "${dcfg.playlistDirectory}"
    ${lib.optionalString (dcfg.dbFile != null) ''
      db_file             "${dcfg.dbFile}"
    ''}
    state_file          "${dcfg.dataDir}/state"
    sticker_file        "${dcfg.dataDir}/sticker.sql"
    log_file            "syslog"

    ${optionalString (dcfg.network.listenAddress != "any")
      ''bind_to_address "${dcfg.network.listenAddress}"''}
    ${optionalString (dcfg.network.port != 6600)
      ''port "${toString dcfg.network.port}"''}

    ${dcfg.extraConfig}
  '';

  mpdService = dcfg: {
    Unit = {
      After = [ "network.target" "sound.target" ];
      Description = "Music Player Daemon";
    };

    ${if dcfg.autoStart then "Install" else null} = {
      WantedBy = [ "default.target" ];
    };

    Service = {
      Environment = "PATH=${config.home.profileDirectory}/bin";
      ExecStart = "${dcfg.package}/bin/mpd --no-daemon ${mpdConf dcfg}";
      Type = "notify";
      ExecStartPre = ''${pkgs.bash}/bin/bash -c "${pkgs.coreutils}/bin/mkdir -p '${dcfg.dataDir}' '${dcfg.playlistDirectory}'"'';
    };
  };

in {

  ###### interface

  options = {
    services.mpd = {

      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to enable MPD, the music player daemon.
        '';
      };

      daemons = mkOption {
        description = ''
          Each attribute of this option defines a systemd user service that runs
          an MPD instance. All options default to the primary configuration. The
          name of each systemd service is
          <literal>mpd-<replaceable>name</replaceable>.service</literal>,
          where <replaceable>name</replaceable> is the corresponding attribute
          name, except for up to one attribute that may have the
          <literal>default</literal> option set and is named
          <literal>mpd.service</literal>.
        
          For most setups, configuring <literal>daemons.default</literal> is all
          that's needed.
        '';
        default = {};
        example = literalExample ''
          {
            default = {
              extraConfig = '''
                audio_output {
                  type "pulse"
                  name "PulseAudio"
                }
              ''';
            };
          }
        '';
        type = let mainConfig = config;
        in types.attrsOf (types.submodule ({ config, name, ... }: {
          options = {

            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to enable this instance of MPD.";
            };

            name = mkOption {
              type = types.str;
              default = name;
              example = "nas";
              description = ''
                The name of this instance. Defaults to the attribute name.
              '';
            };

            default = mkOption {
              type = types.bool;
              default = config.name == "default";
              description = ''
                Whether this instance is the default, and thus uses a service
                named just <literal>mpd.service</literal>. Defaults to
                <literal>true</literal> if <literal>name</literal> is
                <literal>"default"</literal>.
              '';
            };

            package = mkOption {
              type = types.package;
              default = pkgs.mpd;
              defaultText = "pkgs.mpd";
              description = "MPD package to install and use.";
              example = literalExample ''
                pkgs.mpd.override {
                  alsaSupport = false;
                  jackSupport = false;
                }
              '';
            };

            autoStart = mkOption {
              type = types.bool;
              default = true;
              description = ''
                Whether this MPD instance should be started automatically.
              '';
            };

            musicDirectory = mkOption {
              type = with types; either path (strMatching "(http|https|nfs|smb)://.+");
              default = "${mainConfig.home.homeDirectory}/music";
              defaultText = "$HOME/music";
              apply = toString; # Prevent copies to Nix store.
              description = "The directory where MPD reads music from.";
            };

            playlistDirectory = mkOption {
              type = with types; either path str;
              default = "${config.dataDir}/playlists";
              defaultText = ''''${dataDir}/playlists'';
              apply = toString; # Prevent copies to Nix store.
              description = "The directory where MPD stores playlists.";
            };

            extraConfig = mkOption {
              type = types.lines;
              default = "";
              description = ''
                Extra directives added to to the end of MPD's configuration
                file, <filename>mpd.conf</filename>. Basic configuration like
                file location and uid/gid is added automatically to the
                beginning of the file. For available options see
                <citerefentry>
                  <refentrytitle>mpd.conf</refentrytitle>
                  <manvolnum>5</manvolnum>
                </citerefentry>.
              '';
            };

            dataDir = mkOption {
              type = with types; either path str;
              default = "${mainConfig.xdg.dataHome}/${name}" +
                optionalString config.default "/${config.name}";
              defaultText = "$XDG_DATA_HOME/mpd\${/$name if not default}";
              apply = toString; # Prevent copies to Nix store.
              description = ''
                The directory where MPD stores its state, tag cache, playlists,
                etc.
              '';
            };

            network = {
              listenAddress = mkOption {
                type = types.str;
                default = "127.0.0.1";
                example = "any";
                description = ''
                  The address for the daemon to listen on. Use
                  <literal>any</literal> to listen on all addresses.
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
              type = with types; nullOr (either path str);
              default = "${config.dataDir}/tag_cache";
              defaultText = ''''${dataDir}/tag_cache'';
              apply = toString; # Prevent copies to Nix store.
              description = ''
                The path to MPD's database. If set to <literal>null</literal>
                the parameter is omitted from the configuration.
              '';
            };

          };
        }));
      };

    };
  };


  ###### implementation

  config = mkIf cfg.enable {

    assertions = [
      (let defaultCount =
        count (dcfg: dcfg.default) (lib.attrValues cfg.daemons) <= 1;
      in {
        assertion = defaultCount;
        message = ''
          At most 1 MPD instance can be the default, but ${defaultCount} are
          specified.
        '';
      })
    ];

    systemd.user.services = flip lib.mapAttrs' cfg.daemons (_: dcfg: {
      name = if dcfg.default then "mpd" else "mpd-" + dcfg.name;
      value = mpdService dcfg;
    });

  };

}
