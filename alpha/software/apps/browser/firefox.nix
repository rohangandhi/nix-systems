{ my-options, ... }: {

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    programs.firefox.enable = true;
    programs.firefox.package = pkgs.firefox;

    /* ---- POLICIES ---- */
    # Check about:policies#documentation for options.
    programs.firefox.policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
      DisablePocket = true;
      DisableAccounts = true;
      DisableFirefoxAccounts = true;
      DisableFirefoxScreenshots = true;
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      DontCheckDefaultBrowser = true;
      DisplayBookmarksToolbar = "never"; # alternatives: "always" or "newtab"
      DisplayMenuBar = "default-off"; # alternatives: "always", "never" or "default-on"
      SearchBar = "unified"; # alternative: "separate"

      Permissions.Location.BlockNewRequests = true;
      Permissions.Notifications.BlockNewRequests = true;
      # Permissions.Camera.BlockNewRequests = true;
      # Permissions.Microphone.BlockNewRequests = true;

      /* ---- PREFERENCES ---- */
      # Check about:config for options.
      Preferences =
        let
          lock-false = { Value = false; Status = "locked"; };
          lock-true = { Value = true; Status = "locked"; };
          lock-strict = { Value = "strict"; Status = "locked"; };
        in
        {
          "browser.uiCustomization.state" = ''{"placements":{"widget-overflow-fixed-list":[],"unified-extensions-area":[],"nav-bar":["back-button","forward-button","_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action","stop-reload-button","urlbar-container","save-to-pocket-button","downloads-button","fxa-toolbar-menu-button","ublock0_raymondhill_net-browser-action","unified-extensions-button"],"toolbar-menubar":["menubar-items"],"TabsToolbar":["firefox-view-button","tabbrowser-tabs","new-tab-button","alltabs-button"],"PersonalToolbar":["import-button","personal-bookmarks"]},"seen":["developer-button","ublock0_raymondhill_net-browser-action","_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action"],"dirtyAreaCache":["nav-bar","PersonalToolbar","unified-extensions-area","toolbar-menubar","TabsToolbar"],"currentVersion":20,"newElementCount":3}'';

          "browser.contentblocking.category" = lock-strict;
          "browser.topsites.contile.enabled" = lock-false;
          "browser.formfill.enable" = lock-false;
          "browser.search.suggest.enabled" = lock-false;
          "browser.search.suggest.enabled.private" = lock-false;
          "browser.urlbar.suggest.searches" = lock-false;
          "browser.urlbar.showSearchSuggestionsFirst" = lock-false;
          "browser.newtabpage.activity-stream.feeds.section.topstories" = lock-false;
          "browser.newtabpage.activity-stream.feeds.snippets" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includePocket" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includeBookmarks" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includeDownloads" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includeVisited" = lock-false;
          "browser.newtabpage.activity-stream.showSponsored" = lock-false;
          "browser.newtabpage.activity-stream.system.showSponsored" = lock-false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = lock-false;
          "privacy.sanitize.sanitizeOnShutdown" = lock-true;

          # Disable Form autofill
          # https://wiki.mozilla.org/Firefox/Features/Form_Autofill
          "extensions.formautofill.addresses.enabled" = false;
          "extensions.formautofill.available" = "off";
          "extensions.formautofill.creditCards.available" = false;
          "extensions.formautofill.creditCards.enabled" = false;
          "extensions.formautofill.heuristics.enabled" = false;

          # "extensions.pocket.enabled" = lock-false;
          # "extensions.screenshots.disabled" = lock-true;

          "signon.rememberSignons" = false;
          "signon.autofillForms" = false;
          "signon.formlessCapture.enabled" = false;

          ## DNS over HTTPS (DoH)
          ## https://wiki.mozilla.org/Trusted_Recursive_Resolver
          "network.trr.mode" = 3;
          "network.trr.uri" = "https://dns.mullvad.net/dns-query";
        };

      /* ---- EXTENSIONS ---- */
      # Check about:support for extension/add-on ID strings.
      # Valid strings for installation_mode are "allowed", "blocked",
      # "force_installed" and "normal_installed".
      ExtensionSettings = {
        "*".installation_mode = "blocked"; # blocks all addons except the ones specified below
        # uBlock Origin:
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
          installation_mode = "force_installed";
        };
      };

      "3rdparty".Extensions = {
        # https://github.com/gorhill/uBlock/blob/master/platform/common/managed_storage.json
        "uBlock0@raymondhill.net".adminSettings = {
          userSettings = {
            importedLists = [ ];
          };
          selectedFilterLists = [
            "user-filters"
            "ublock-filters"
            "ublock-badware"
            "ublock-privacy"
            "ublock-quick-fixes"
            "ublock-unbreak"
            "easylist"
            "easyprivacy"
            "urlhaus-1"
            "plowe-0"
            "fanboy-cookiemonster"
            "ublock-cookies-easylist"
            "fanboy-social"
            "easylist-chat"
            "easylist-newsletters"
            "easylist-notifications"
            "easylist-annoyances"
            "ublock-annoyances"
          ];
          userFilters = "||accounts.google.com/gsi/*$xhr,script,3p\n||ogs.google.com/widget/callout";
        };
      };
    };
  };
}
