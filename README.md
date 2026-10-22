# AquaRoot DE 🌊✨

> **⚠️ WARNING: EARLY DEVELOPMENT STAGE**
> AquaRoot DE is currently in its **very first development stage (alpha/experimental)**. It is a hobbyist, from-scratch conceptual project combining multiple Wayland and GTK components. Expect bugs, missing edge-case handling, and API changes. It will take a considerable amount of time and community contribution to mature into a daily-driver production-ready desktop environment. Use at your own risk!

---

## Overview

**AquaRoot DE** is a modern, macOS-inspired desktop environment built from scratch for Linux, powered by the modular **wlroots** / **Wayfire** compositor stack. It powerful Wayland protocols and lightweight native Python/GTK4 daemons.

---

## Core Features

- **Liquid Glass Aesthetics & Readability Engine**: Real-time background blur (Kawase algorithm via Wayfire), translucent capsule containers, and a dynamic readability controller (`aquaroot-glass-ctl.py`) that lets users adjust opacity, contrast, and tinting on the fly.
- **Genie (Squeezimize) Animations**: Authentic macOS-style magic-lamp window minimization and spring zoom effects powered by Wayfire's extra-animations plugin.
- **Dynamic Top Bar**: 
  - Distro-branded system menu (adapting to `/etc/os-release`).
  - D-Bus Global Menu integration.
  - Built-in headless **YouTube Audio Streamer** (`yt-dlp` + `mpv`).
  - Live **System Telemetry Widget** monitoring CPU usage, RAM consumption, and thermal sensor temperatures.
  - Integrated system clock and Spotlight trigger.
- **Magnification Dock**: Parabolic Gaussian hover magnification effect with application launch indicators and foreign-toplevel management.
- **macOS-Style Spotlight (`Super + Space`)**: Fast overlay launcher supporting app lookup, file searches, and inline math calculations.
- **QuickLook (`Spacebar`)**: Instant file previews for images, code, and documents using GNOME Sushi and Nautilus integration.
- **Native PC Settings App & First-Boot Wizard**: A customized control center for tweaking glass settings, network/audio, wallpapers, and biometrics, accompanied by a polished macOS Setup Assistant on first login.
- **Dynamic Lock Screen & Biometrics**: Secure session locking (`hyprlock` / `gtklock`) supporting parallel **Face ID** (`howdy`) and **Fingerprint** (`fprintd`) authentication.
- **Online Wallpaper Integration**: Automated background fetching from online wallpaper services (Wallhaven/Unsplash APIs) paired with smooth `swww` wave transitions.

---

## Dependencies & Architecture

AquaRoot DE is built on top of robust, battle-tested Wayland and Linux ecosystem projects:

| Subsystem | Underlying Technology | Purpose in AquaRoot DE |
| :--- | :--- | :--- |
| **Compositor Core** | [Wayfire](https://github.com/WayfireWM/wayfire) / [wlroots](https://gitlab.freedesktop.org/wlroots/wlroots) | Scene graph, input handling, Xwayland, and window management. |
| **Window Decorations** | [pixdecor](https://github.com/soreau/pixdecor) | Client/Server-side window borders, rounded corners, drop shadows, and macOS traffic lights. |
| **Genie Animations** | [wayfire-plugins-extra](https://github.com/WayfireWM/wayfire-plugins-extra) | Squeezimize magic-lamp window minimize/restore warp shaders. |
| **UI & Styling Toolkit** | [GTK4](https://www.gtk.org/) & [gtk4-layer-shell](https://github.com/wmww/gtk4-layer-shell) | Layer-shell surface placement for Top Bar, Dock, Spotlight, and Welcome apps. |
| **Wallpaper Daemon** | [swww](https://github.com/LGFae/swww) | GPU-accelerated animated wallpaper transitions and synchronization. |
| **Screen Locker** | [hyprlock](https://github.com/hyprwm/hyprlock) / [gtklock](https://github.com/jovanlanik/gtklock) | Secure Wayland session locking via `ext-session-lock-v1`. |
| **Audio & Media** | [mpv](https://mpv.io/) & [yt-dlp](https://github.com/yt-dlp/yt-dlp) | Headless audio streaming pipeline for the Top Bar music widget. |
| **File Manager & Preview** | [Nautilus](https://wiki.gnome.org/Apps/Files) & [GNOME Sushi](https://gitlab.gnome.org/GNOME/sushi) | File navigation and Spacebar QuickLook file previewing. |
| **Biometric Auth** | [Howdy](https://github.com/boltgolt/howdy) & [fprintd](https://gitlab.freedesktop.org/libfprint/fprintd) | Facial recognition (Face ID) and fingerprint sensor PAM integration. |
| **System Utilities** | `curl`, `jq`, `ImageMagick`, `python-gobject` | Wallpaper fetching, JSON parsing, image processing, and GTK Python bindings. |

---

## Special Thanks & Acknowledgments

AquaRoot DE would not be possible without the incredible dedication of the open-source Linux and Wayland communities. We extend our deepest gratitude to:
- **The Wayfire & wlroots Teams** (and all contributors) for providing a modular, hackable, and high-performance compositor foundation.
- **Soreau** for creating `pixdecor`, enabling gorgeous rounded window geometry and traffic light controls.
- **William W. (wmww)** and contributors for `gtk4-layer-shell`, bridging GTK4 with Wayland layer surfaces.
- **LGFae and the swww contributors** for smooth, GPU-powered animated wallpaper rendering.
- **The GNOME Project** for Nautilus and Sushi, delivering an exceptional file manager and preview architecture.
- **The maintainers of yt-dlp, mpv, howdy, fprintd, and hyprlock** for empowering media playback and security subsystems.

---

## License & Contributing

AquaRoot DE is released under the MIT License. Contributions, bug reports, and pull requests to help mature the project are warmly welcomed!
