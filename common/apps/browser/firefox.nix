{ my-options, ... }: {

  xdg.mime.defaultApplications = {
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
    "x-scheme-handler/mailto" = "firefox.desktop";
    "text/html" = "firefox.desktop";
    "message/rfc822" = "firefox.desktop";
    "application/xhtml+xml" = "firefox.desktop";
    "application/x-extension-eml" = "firefox.desktop";
  };

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    programs.firefox.enable = true;
    programs.firefox.package = pkgs.firefox;
    # Keep the existing profile and persisted data when Home Manager defaults change.
    programs.firefox.configPath = ".mozilla/firefox";

    # Prefer supported policies over internal preferences. Verify applied values
    # and errors in about:policies after rebuilding and restarting Firefox.
    # https://firefox-admin-docs.mozilla.org/reference/policies/
    programs.firefox.policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisableAccounts = true;

      # Strict includes cookie partitioning, known/suspected fingerprinting,
      # email tracking, bounce tracking, and tracking-parameter protection.
      # Keep Firefox's strict-mode compatibility exceptions and per-site controls.
      EnableTrackingProtection = {
        Category = "strict";
        Locked = true;
      };
      HttpsOnlyMode = "force_enabled";

      # Prefer Mullvad DNS, but fall back to the system resolver when it is
      # unavailable while a private DNS service is being prepared.
      DNSOverHTTPS = {
        Enabled = true;
        ProviderURL = "https://dns.mullvad.net/dns-query";
        Fallback = true;
        Locked = true;
      };
      NetworkPrediction = false;

      # Keep typed searches and the new-tab page free of remote suggestions,
      # sponsored content, stories, and widgets that make background requests.
      SearchSuggestEnabled = false;
      FirefoxSuggest = {
        WebSuggestions = false;
        SponsoredSuggestions = false;
        OnlineEnabled = false;
        Locked = true;
      };
      FirefoxHome = {
        SponsoredTopSites = false;
        Highlights = false;
        Stories = false;
        SponsoredStories = false;
        Weather = false;
        Widgets.Enabled = false;
        Locked = true;
      };
      UserMessaging = {
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        MoreFromMozilla = false;
        Locked = true;
      };

      # Disable browser-integrated chat/assistant features; leave local tools
      # such as translation and PDF accessibility available.
      AIControls = {
        SidebarChatbot = { Value = "blocked"; Locked = true; };
        SmartWindow = { Value = "blocked"; Locked = true; };
      };

      # Bitwarden handles saved credentials and autofill.
      DisableFormHistory = true;
      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;
      OfferToSaveLogins = false;

      DisableFirefoxScreenshots = true;
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      DontCheckDefaultBrowser = true;
      DisplayBookmarksToolbar = "never"; # alternatives: "always" or "newtab"
      DisplayMenuBar = "default-off"; # alternatives: "always", "never" or "default-on"
      SearchBar = "unified"; # alternative: "separate"

      Permissions.Location.BlockNewRequests = true;
      Permissions.Notifications.BlockNewRequests = true;

      # Only use Preferences for values supported by its allowlist. In
      # particular, most privacy.* preferences need their dedicated policy.
      Preferences =
        let
          lock-false = { Value = false; Status = "locked"; };
          lock-true = { Value = true; Status = "locked"; };
        in
        {
          "privacy.globalprivacycontrol.enabled" = lock-true;
          "browser.topsites.contile.enabled" = lock-false;
          "browser.search.suggest.enabled.private" = lock-false;
          "browser.discovery.enabled" = lock-false;
          "browser.uitour.enabled" = lock-false;
          "signon.autofillForms" = lock-false;
          "signon.formlessCapture.enabled" = lock-false;

          # Avoid speculative page fetches/connections before following links.
          "network.prefetch-next" = lock-false;
          "network.http.speculative-parallel-limit" = {
            Value = 0;
            Type = "number";
            Status = "locked";
          };
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
          userFilters = ''
            ||accounts.google.com/gsi/*$xhr,script,3p
            ||ogs.google.com/widget/callout
            www.youtube.com##ytd-rich-section-renderer.ytd-rich-grid-renderer.style-scope:nth-of-type(1)
            www.youtube.com##ytd-rich-section-renderer.ytd-rich-grid-renderer.style-scope:nth-of-type(2)
            www.youtube.com##ytd-rich-section-renderer.ytd-rich-grid-renderer.style-scope:nth-of-type(3)
          '';
        };
      };
    };
  };
}
