# v2rayA VPN — Omarchy Bar Widget

A lightweight, modern, and native [Omarchy](https://omarchy.org/) status bar widget to connect and disconnect [v2rayA](https://github.com/v2rayA/v2rayA) VPN directly from your desktop bar, with a searchable server node picker and built-in authentication in the popup panel.

---

## Requirements & Prerequisites

Before installing the widget, ensure your system has:

1. **Omarchy Linux** with Quickshell status bar (`omarchy plugin` / `omarchy bar` CLI available).
2. **`v2rayA` & Proxy Core**:
   * Install `v2rayA` and the `v2ray` core via pacman / AUR:
     ```bash
     sudo pacman -S v2raya v2ray
     # or using Xray core:
     # sudo pacman -S v2raya xray
     ```
   * Enable and start the background service:
     ```bash
     sudo systemctl enable --now v2raya
     ```
   * The web UI / API should be reachable at `http://127.0.0.1:2017`.
3. **`curl`** (standard on Omarchy, used to communicate with the v2rayA API).
4. **Nerd Font** (standard on Omarchy, used for status and action glyphs).

---

## Installation

### Option 1: Using `omarchy plugin` (Recommended)

```bash
omarchy plugin add https://github.com/Rizmi/omarchy-v2raya-plugin.git --enable
```

### Option 2: Manual Installation

1. Clone the repository into your Omarchy plugins directory:
   ```bash
   git clone https://github.com/Rizmi/omarchy-v2raya-plugin.git \
     ~/.config/omarchy/plugins/io.github.rizmi.v2raya-vpn
   ```

2. Validate and enable the plugin on your status bar:
   ```bash
   omarchy plugin validate ~/.config/omarchy/plugins/io.github.rizmi.v2raya-vpn
   omarchy plugin enable io.github.rizmi.v2raya-vpn --section right
   ```

---

## Removal

```bash
omarchy plugin disable io.github.rizmi.v2raya-vpn
rm -rf ~/.config/omarchy/plugins/io.github.rizmi.v2raya-vpn
omarchy-shell shell rescanPlugins
```

---

## Configuration & Settings

Configurable from Omarchy's plugin settings UI or `manifest.json`:

### Settings Reference

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `serverUrl` | string | `"http://127.0.0.1:2017"` | v2rayA daemon listening address. |
| `username` | string | `""` | v2rayA admin username (if authentication is enabled). |
| `password` | string | `""` | v2rayA admin password (if authentication is enabled). |
| `token` | string | `""` | Authorization token (optional). |
| `refreshIntervalSec` | integer | `5` | Polling frequency in seconds (`2 – 60`). |

---

## Usage

* **Left-click** bar icon: Open / close popup panel.
* **Right-click** bar icon: Force refresh status and server nodes.
* **Middle-click** bar icon: Quick toggle connect / disconnect without opening popup.
* **Popup Panel**:
  * **Power Switch**: Starts / stops the v2ray core proxy service.
  * **Server Node**: Searchable dropdown listing all imported servers and subscription nodes.
  * **Authentication**: Expandable section to enter your v2rayA `Username` and `Password` with a **Save & Login** button.

---

## Shell IPC Commands

```bash
# Check status
omarchy-shell io.github.rizmi.v2raya-vpn status

# Refresh status and server nodes
omarchy-shell io.github.rizmi.v2raya-vpn refresh

# Toggle VPN on / off
omarchy-shell io.github.rizmi.v2raya-vpn toggle
```

---

## File Structure

```
~/.config/omarchy/plugins/io.github.rizmi.v2raya-vpn/
├── Panel.qml        # QML widget UI, popup panel & IPC handler
├── Service.qml      # Background service logic & API client
├── Model.js         # Data models and helper functions
├── manifest.json    # Omarchy plugin manifest and settings schema
├── README.md        # Documentation and usage guide
└── LICENSE          # MIT License
```

---

## License

MIT — see [LICENSE](LICENSE).
