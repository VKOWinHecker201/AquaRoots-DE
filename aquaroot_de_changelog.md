---

### 2. `CHANGELOG.md`

```markdown
# Changelog — AquaRoot DE

All notable changes to the **AquaRoot Desktop Environment** are documented in this file.

---

## [3.0.0] — Complete Desktop Ecosystem Release

### Added
* **Dynamic Notch v2 (`aquaroot-notch.py`):** Added a drag-and-drop **Dropover File Holding Shelf** (`Gtk.DropTarget` + `Gtk.DragSource`) inside the expanded notch alongside MPRIS media playback, interactive seek bar, live `wttr.in` weather, and battery time-remaining telemetry.
* **Control Center & Notification Daemon (`aquaroot-notifications.py`):** Implemented an `org.freedesktop.Notifications` D-Bus server with Liquid Glass toast popups and a slide-out Control Center drawer (`Super + N`) featuring Wi-Fi, Bluetooth, Do Not Disturb, Night Shift (`wlsunset`), Focus Modes, and brightness/audio sliders.
* **Interactive Desktop Widgets (`aquaroot-widgets.py`):** Added a `Gtk4LayerShell.Layer.BACKGROUND` widget layer for desktop Clock/Agenda, live CPU/RAM LevelBars, and persistent Quick Notes.
* **Stage Manager Strip (`aquaroot-stagemanager.py`):** Added a toggleable left-side window strip (`Super + S`) communicating with Wayfire's UNIX IPC socket (`WAYFIRE_SOCKET`).
* **Spotlight v2 (`aquaroot-spotlight.py`):** Upgraded Spotlight (`Super + Space` / `Super + V`) with a 25-entry Clipboard History viewer (`clip:`), live Unit & Currency Converter (`100 usd to inr`, `72 f to c`), and system Quick Actions.
* **Screen Capture, 60fps Recorder & OCR Studio (`aquaroot-screenshot.py`):** Added a floating capture bar (`Super + Shift + 5`) wrapping `grim`, `slurp`, `wf-recorder`, and `tesseract` for instant clipboard OCR text extraction.
* **Volume & Brightness OSD (`aquaroot-osd.py`):** Added hardware media key bindings in `wayfire.ini` with auto-dismissing Liquid Glass OSD capsules.
* **AquaDrop Wireless Continuity (`aquaroot-aquadrop.py`):** Added a local Wi-Fi file drop server (`Port 8088`) and KDE Connect pairing utility.
* **Time Machine Backup Studio (`aquaroot-timemachine.py`):** Added one-click `$HOME` configuration snapshot archiving/restoration and Timeshift GUI launcher.
* **Solar Time-of-Day Wallpaper Mode (`aquaroot-wallpaper.sh --solar`):** Automatically selects sunrise, daylight, dusk, or night 4K wallpapers based on the system clock.
* **XDG Desktop Portal Integration:** Configured `xdg-desktop-portal-wlr` and `xdg-desktop-portal-gtk` (`aquaroot-portals.conf`) for native Wayland screen sharing in OBS, Discord, and browsers.

---

## [2.0.0] — Self-Healing Source Builder, Dynamic Notch & macOS Settings

### Added
* **Self-Healing Installer & GitHub Source Compiler:** Added automatic package manager lock/dpkg repair and automated source compilation (`meson`, `ninja`, `cargo`) from GitHub when binary packages (`wayfire`, `pixdecor`, `swww`, `gtk4-layer-shell`, `gtklock`) are missing from distro repositories.
* **Dynamic Notch v1:** Introduced top-center `gtk4-layer-shell` overlay with MPRIS2 D-Bus media integration, hover `Gtk.Revealer` expansion, weather card, and `/sys/class/power_supply/BAT*` discharge time calculation.
* **Refined macOS System Settings (`aquaroot-settings.py`):** Rebuilt Settings with frameless Liquid Glass styling, Traffic Light window controls, user profile card, colorful squircle sidebar icons, and inset grouped cards.
* **AquaRoot CLI (`aquaroot-cli`):** Added command-line doctor (`aquaroot-cli doctor`), live glass tuner, and shell restarter.

---

## [1.0.0] — Initial Liquid Glass Prototype

### Added
* **Core Compositor Setup (`wayfire.ini`):** Configured Wayfire with Kawase blur, `pixdecor` rounded traffic-light titlebars, `squeezimize` Genie minimize animations, and 3-finger trackpad workspace swipes.
* **Master Liquid Glass Stylesheet (`gtk.css`):** Created specular rim-highlighted translucent GTK3/GTK4 theme and Finder-style Nautilus sidebar customization.
* **Dynamic Top Bar (`aquaroot-topbar.py`):** Built top panel with distro logo detection, Global Menu bar, YouTube audio streamer (`yt-dlp` + `mpv` IPC), and `/proc` hardware telemetry widget.
* **Parabolic Dock (`aquaroot-dock.py`):** Implemented bottom launcher dock with Gaussian hover magnification.
* **Spotlight v1 & First-Boot Welcome App (`aquaroot-welcome.py`):** Added initial app/math/file search overlay and first-login onboarding wizard.
* **Biometric Lock Screen (`hyprlock.conf`):** Configured `howdy` (Face ID) and `fprintd` (Touch ID) PAM stack with macOS-style lock screen clock.
