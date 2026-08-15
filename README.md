# v2rayA VPN — Omarchy Bar Widget

A bar-widget plugin for [Omarchy](https://omarchy.org/) that connects and disconnects [v2rayA](https://github.com/v2rayA/v2rayA) VPN directly from the top bar, with a searchable server node picker and built-in authentication in the popup panel.

![v2rayA VPN widget popup](preview.png)

---

## 📋 Requirements & Prerequisites

Before installing the widget, ensure your system has:

1. **Omarchy Linux** with Quickshell status bar (`omarchy plugin` / `omarchy bar` CLI available).
2. **v2rayA & Proxy Core**:
   * Install v2rayA and the v2ray core via pacman / AUR:
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
4. **Nerd Font** (standard on Omarchy, used for the status glyphs).

---

## 🚀 Installation

### Option 1: Using `omarchy plugin` (Recommended)

```bash
omarchy plugin add https://github.com/Rizmi/omarchy-v2raya-plugin.git --enable
```

### Option 2: Manual Installation

```bash
git clone https://github.com/Rizmi/omarchy-v2raya-plugin.git \
  ~/.config/omarchy/plugins/io.github.rizmi.v2raya-vpn
omarchy plugin validate ~/.config/omarchy/plugins/io.github.rizmi.v2raya-vpn
omarchy plugin enable io.github.rizmi.v2raya-vpn --section right
```

---

## 🗑️ Removal

```bash
omarchy plugin disable io.github.rizmi.v2raya-vpn
rm -rf ~/.config/omarchy/plugins/io.github.rizmi.v2raya-vpn
omarchy-shell shell rescanPlugins
```

---

## 🖱️ Usage

* **Left-click** the bar icon: Open / close the popup panel.
* **Right-click** the bar icon: Force a status and server node refresh.
* **Middle-click** the bar icon: Quick connect / disconnect without opening the popup.
* **Popup Panel Controls**:
  * **Power Switch**: Starts / stops the v2ray core proxy service.
  * **Server Node**: Searchable dropdown listing all imported servers and subscription nodes.
  * **Authentication**: Expandable section to enter your v2rayA `Username` and `Password` with a **Save & Login** button.

---

## ⚙️ Settings

Configurable from Omarchy's plugin settings UI or `manifest.json`:

* `serverUrl` (default `"http://127.0.0.1:2017"`): v2rayA daemon listening address.
* `username` (default `""`): v2rayA admin username (if auth is enabled).
* `password` (default `""`): v2rayA admin password (if auth is enabled).
* `token` (default `""`): Authorization token (optional).
* `refreshIntervalSec` (2–60, default `5`): How often the widget polls v2rayA for status and node list.

---

## 📄 License

MIT — see [LICENSE](LICENSE).
