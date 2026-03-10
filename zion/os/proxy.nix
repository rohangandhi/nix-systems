{ ... }: {
  # Keep the web proxy loopback-only on the host. The VM reaches it through an
  # explicit QEMU guest forwarding rule instead of broad host networking.
  services.squid = {
    enable = true;
    proxyAddress = "127.0.0.1";
    proxyPort = 3128;
    extraConfig = ''
      # Do not let the guest pivot back into the host or home network via the
      # proxy. The VM should only use this proxy for public internet access.
      acl private_dst dst 10.0.0.0/8
      acl private_dst dst 172.16.0.0/12
      acl private_dst dst 192.168.0.0/16
      acl private_dst dst 169.254.0.0/16
      acl private_dst dst fc00::/7
      acl private_dst dst fe80::/10
      http_access deny private_dst

      # Block the obvious video/audio platforms first. This is domain-based
      # because HTTPS CONNECT traffic exposes the destination host but not the
      # full URL without enabling ssl_bump.
      acl media_domains dstdomain .youtube.com .youtu.be .youtube-nocookie.com .googlevideo.com .ytimg.com
      acl media_domains dstdomain .netflix.com .netflix.net .nflxext.com .nflximg.net .nflxvideo.net .nflxso.net
      acl media_domains dstdomain .spotify.com .scdn.co
      acl media_domains dstdomain .soundcloud.com .sndcdn.com
      acl media_domains dstdomain .twitch.tv .ttvnw.net .jtvnw.net
      acl media_domains dstdomain .vimeo.com .vimeocdn.com
      acl media_domains dstdomain .tiktok.com .tiktokv.com .tiktokcdn.com
      acl media_domains dstdomain music.apple.com podcasts.apple.com
      http_access deny media_domains

      # Catch direct media file fetches over plain HTTP.
      acl media_paths urlpath_regex -i \\.(aac|avi|flac|m4a|m4v|mkv|mov|mp3|mp4|mpeg|mpg|oga|ogg|ogv|opus|wav|webm)([?#].*)?$
      http_access deny media_paths

      # Catch media responses Squid can actually inspect. This applies to plain
      # HTTP today and also becomes useful for HTTPS if ssl_bump is added later.
      acl media_replies rep_mime_type -i ^audio/
      acl media_replies rep_mime_type -i ^video/
      acl media_replies rep_mime_type -i application/dash+xml
      acl media_replies rep_mime_type -i application/vnd.apple.mpegurl
      http_reply_access deny media_replies
    '';
  };
}
