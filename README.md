# PixelFirewall

A root-native per-app firewall for Android using Magisk. PixelFirewall provides per-app network policy control for IPv4 and IPv6 through its own firewall chains, with a lightweight local WebUI.

## Features

- **Per-App Network Control** — Control network access on a per-app basis
- **Multiple Profiles** — Supports Android owner and secondary user profiles
- **4G / Wi-Fi / LAN** — Separate policy controls for mobile, Wi-Fi, and LAN traffic
- **IPv4 / IPv6** — Supports both IP protocols
- **System & User Apps** — Filter applications by type
- **Policy Persistence** — PixelFirewall policies survive service refreshes and reloads
- **Backup / Restore** — Export and restore PixelFirewall policy data
- **Local WebUI** — Magisk-compatible WebUI served locally on the device
- **App Cache** — Application inventory is cached and refreshed explicitly rather than enumerated on every WebUI request

## Installation

1. Flash the PixelFirewall Magisk module.
2. Reboot the device.
3. Open the PixelFirewall WebUI.
4. Select an application and configure its network policy.

## WebUI

The WebUI provides:

| Control | Description |
|---|---|
| **APPLICATION** | Application and package information |
| **4G** | Mobile-data policy |
| **WIFI** | Wi-Fi policy |
| **LAN** | Local-network policy |
| **ALL / USER / SYSTEM** | Application filtering |
| **Profile** | Select an Android user profile |
| **Search** | Search applications by name or package |
| **Refresh** | Refresh PixelFirewall state |

## Architecture

PixelFirewall maintains and manages only its own firewall policy chains. The WebUI does not directly modify or flush native Android firewall chains.

PixelFirewall-owned chains include:

- `PIXELFW`
- `PIXELFW-MOBILE`
- `PIXELFW-WIFI`
- `PIXELFW-LAN`
- IPv6 equivalents

The WebUI communicates with PixelFirewall through its local CGI interface and policy state. Firewall operations are performed by the PixelFirewall service.

## Development

Repository:

https://github.com/Heclalava/PixelFirewall

## License

See the repository for licensing information.
