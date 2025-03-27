{ pkgs,  ... }: {
  environment.systemPackages = [
    pkgs.distrobox
  ];
}
#distrobox create --name fedora --image quay.io/fedora/fedora:41 --home /p-home/distrobox/fedora
#distrobox create --name fedora --image fedora:latest --home /p-home/distrobox/fedora --unshare-all --init

#distrobox create --name course_a --image fedora:latest --home /p-home/distrobox/course_a --unshare-all --init
#distrobox enter course_a
#sudo chown -R ephemeral:devs ~/.config
#sudo chown -R ephemeral:devs ~/.local