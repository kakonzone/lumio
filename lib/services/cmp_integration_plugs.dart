// TODO(TCF-CMP): Integrate licensed CMP (e.g. Google UMP, Sourcepoint) here.
// Requirements before implementation:
// - Vendor selection for UK/US/EEA traffic
// - Wire TC string into IabConsentBridge.saveTcString()
// - Call LevelPlay privacy flags after CMP updates
// - Do NOT load ad WebViews until consent resolved

/// Placeholder for future CMP initialization (v2.2).
class CmpIntegrationPlugs {
  CmpIntegrationPlugs._();

  static Future<void> initializeIfNeeded() async {
    // TODO(TCF-CMP): initialize CMP SDK when vendor chosen.
  }

  static Future<void> showPrivacyFormIfRequired() async {
    // TODO(TCF-CMP): present CMP UI on first launch / region change.
  }
}
