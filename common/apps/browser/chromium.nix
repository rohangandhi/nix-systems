{ my-options, ... }: {

  # NixOS writes these policies for both Chromium and Google Chrome.
  programs.chromium = {
    enable = true;
    extensions = [
      "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite (Manifest V3)
      "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
    ];
    extraOpts = {
      # Reduce tracking and unsolicited background requests.
      BlockThirdPartyCookies = true;
      MetricsReportingEnabled = false;
      UrlKeyedAnonymizedDataCollectionEnabled = false;
      SearchSuggestEnabled = false;
      NetworkPredictionOptions = 2;
      AlternateErrorPagesEnabled = false;
      SpellCheckServiceEnabled = false;
      BrowserSignin = 0;
      SyncDisabled = true;

      HttpsOnlyMode = "force_enabled";
      # Prefer encrypted DNS, allowing system DNS when the provider is unavailable.
      DnsOverHttpsMode = "automatic";
      DnsOverHttpsTemplates = "https://dns.mullvad.net/dns-query";

      # Keep malware/phishing protection without enhanced browsing-data reporting.
      SafeBrowsingProtectionLevel = 1;
      SafeBrowsingExtendedReportingEnabled = false;

      # Use Bitwarden for new credentials and form filling.
      PasswordManagerEnabled = false;
      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;
      DefaultGeolocationSetting = 2;
      DefaultNotificationsSetting = 2;

      # Disable cloud AI integrations that can send page contents or code to Google.
      HelpMeWriteSettings = 2;
      HistorySearchSettings = 2;
      DevToolsGenAiSettings = 2;
      AIModeSettings = 1;
      SearchContentSharingSettings = 1;

      # https://github.com/uBlockOrigin/uBOL-home/wiki/Managed-settings
      "3rdparty".extensions.ddkjiahejlhfcafbddmgiahcphecmpfh = {
        defaultFiltering = "optimal";
        rulesets = [
          "+default"
          "+adguard-spyware-url"
          "+annoyances-cookies"
        ];
      };
    };
  };

  home-manager.users.${my-options.user.name} = { pkgs, ... }: {
    programs.chromium.enable = true;
    programs.chromium.package = pkgs.chromium;
    programs.chromium.commandLineArgs = [ "--ozone-platform-hint=auto" ];
  };
}
