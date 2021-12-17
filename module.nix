# NixOS module for the `focusmate-notify` service, that sends a phone
# notification when a FocusMate session is about to start.
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.focusmate-notify;
in
{
  #
  # Configuration options
  #
  options.services.focusmate-notify = {
    enable = mkEnableOption "Monitor a FocusMate account for imminent sessions";

    interval = mkOption {
      type = types.str;
      default = "minutely";
      example = "hourly";
      description = ''
        How long to wait between polling the FocusMate account.
      '';
    };

    focusmate-email = mkOption {
      type = types.str;
      example = "me@example.com";
      description = ''
        Email address of the FocusMate account to monitor.
      '';
    };

    focusmate-password = mkOption {
      type = types.str;
      example = "hunter2";
      description = ''
        Password of the FocusMate account to monitor.
        Note: this is globally readable in the nix store.
      '';
    };

    pushover-app-token = mkOption {
      type = types.str;
      example = "u8qgdt9afs5jp2yy9ruw1g3juylp1n";
      description = ''
        Pushover app token to use.
        Note: this is globally readable in the nix store.
      '';
    };

    pushover-user-token = mkOption {
      type = types.str;
      example = "y82q8aofzkbfsbtp41sw65vuueiqy0";
      description = ''
        Pushover user token to use.
        Note: this is globally readable in the nix store.
      '';
    };

    # These two options should hopefully go away at some point.
    user = mkOption {
      type = types.str;
      default = "simon";
      description = ''
        User to use - nushell doesn't work yet with system users.
      '';
    };
    group = mkOption {
      type = types.str;
      default = "simon";
      description = ''
        Group to use - nushell doesn't work yet with system users.
      '';
    };
  };

  #
  # Implementation - use cron rather than systemd for now, to get easy emails
  # if something goes squiffy.
  #
  config =
    let
      secret-file-contents = {
        focusmate_auth = {
          email = cfg.focusmate-email;
          password = cfg.focusmate-password;
        };
        pushover_tokens = {
          app_token = cfg.pushover-app-token;
          user_token = cfg.pushover-user-token;
        };
      };
      secret-file = pkgs.writeText "secrets.json" (builtins.toJSON secret-file-contents);
    in
    mkIf cfg.enable {
      # Database directory
      # See below for why `simon` :(
      systemd.tmpfiles.rules = [
        "d /var/lib/focusmate-notify 0755 simon"
      ];

      # Service
      systemd.services.focusmate-notify = {
        description = "Notify user about imminent FocusMate sessions";
        after = [ "network-online.target" ];
        startAt = cfg.interval;
        # Have to use an environment variable to pass in the secrets file, since
        # nushell doesn't support scripting arguments yet(!)
        # https://github.com/nushell/nushell/issues/3762#issuecomment-887697324
        environment = {
          SECRETS_FILE = secret-file;
          STATE_DIR = "/var/lib/focusmate-notify";
        };
        serviceConfig = {
          ExecStart = "${pkgs.focusmate-notify}/bin/focusmate-notify";
          User = cfg.user;
          Group = cfg.group;
        };
      };
    };
}
