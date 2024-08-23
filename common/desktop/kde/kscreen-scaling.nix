{ config, lib, pkgs, ... }:

{
  systemd.services.kscreen-scaling = {
    description = "Apply kscreen scaling on boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "display-manager.service" ];
    script = ''
      # Wait for the display manager to fully start
      sleep 10

      # Get all outputs
      OUTPUTS=$(${pkgs.kscreen}/bin/kscreen-doctor -o | grep 'Output' | awk '{print $3}')
      SCALE_FACTOR=2

      # Apply scaling to each output
      for OUTPUT in $OUTPUTS; do
        echo "Applying scaling factor of $SCALE_FACTOR to output $OUTPUT"
        ${pkgs.kscreen}/bin/kscreen-doctor output.$OUTPUT.scale.$SCALE_FACTOR
      done
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Environment = "DISPLAY=:0";
    };
  };
}
