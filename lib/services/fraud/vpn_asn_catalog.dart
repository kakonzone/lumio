/// Top VPN / privacy-hosting ASNs (hardcoded reference for server-side IP lookup).
///
/// Client cannot resolve ASN without a network API; [VpnDetector] uses
/// [knownVpnPackagePrefixes] on Android as an on-device proxy signal.
class VpnAsnCatalog {
  VpnAsnCatalog._();

  /// Curated ASNs used by major commercial VPN and privacy VPN hosts.
  static const Set<int> top50 = {
    9009, // M247 / NordVPN infrastructure
    16247, // M247 Ltd
    212238, // Datacamp Limited
    60068, // Datacamp / CDN77
    396356, // Latitude.sh
    20473, // Choopa / Vultr
    16276, // OVH
    14061, // DigitalOcean
    24940, // Hetzner
    51167, // Contabo
    63949, // Linode / Akamai
    16509, // Amazon (some VPN exit)
    15169, // Google (some VPN over GCP)
    8075, // Microsoft Azure exits
    13335, // Cloudflare WARP
    209242, // Cloudflare
    397213, // Voxility
    60011, // HostHatch
    25369, // Hydra Communications / Surfshark
    202425, // IP Volume / VPN resellers
    136787, // Tefincom (Nord)
    43513, // Supernova (Nord)
    397630, // Torguard
    396982, // Google One VPN
    36351, // SoftLayer
    32934, // Meta infra (some VPN)
    55286, // B2 Net
    46844, // Sharktech
    62240, // Clouvider
    12876, // Online.net / Scaleway
    29169, // Giganet / VPN exits
    43350, // NForce
    60117, // Hostinger
    47583, // Hostinger International
    35916, // MULTACOM
    40676, // Psychz
    26496, // GoDaddy VPN landing
    54600, // PEG TECH
    31898, // Oracle VPN exits
    398101, // Cogent VPN
    208323, // HostRoyale
    141039, // Regional VPN resellers
    203020, // HostRoyale Technologies
    396190, // Leaseweb USA
    60781, // LeaseWeb
    58065, // Packet Host
    398395, // Netprotect / IPVanish-related
    36352, // ColoCrossing
    46606, // Unified Layer
    9002, // RETN (transit for VPN hosts)
    2914, // NTT (exit mix)
  };

  /// Package name prefixes for known VPN clients (Android installed-app proxy).
  static const List<String> knownVpnPackagePrefixes = [
    'com.nordvpn',
    'com.expressvpn',
    'net.openvpn',
    'de.blinkt',
    'com.surfshark',
    'com.privateinternetaccess',
    'ch.protonvpn',
    'com.hotspotshield',
    'com.tunnelbear',
    'com.cyberghost',
    'com.ipvanish',
    'com.windscribe',
    'com.purevpn',
    'com.vyprvpn',
    'com.cloudflare.onedotonedotonedotone',
  ];

  static bool isKnownAsn(int asn) => top50.contains(asn);
}
