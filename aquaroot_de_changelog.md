# Changelog

All notable changes to **AquaRoot DE** will be documented in this file.

---

## [2.0.0] - 2026-10-22
### Added
- **macOS-Style System Settings App**: Completely redesigned `aquaroot-settings.py` featuring a translucent glass sidebar, left-aligned window traffic-light controls, macOS Apple ID profile card, searchable categories, and grouped Liquid Glass preference cards.
- **Dynamic Top-Center Notch**: Introduced `aquaroot-notch.py`, a dynamic island anchored via `gtk4-layer-shell` that dynamically shifts based on system state:
  - **Idle State**: Displays battery percentage and estimated time remaining.
  - **Active Media State**: Automatically fetches track metadata and playback status via the **MPRIS D-Bus Protocol**, displaying playback controls and a live seek bar in the compact notch.
  - **Hover Expansion**: Smoothly expands on mouse hover to reveal a 3-card Liquid Glass dashboard containing full Media controls, live local Weather (via wttr.in), and Battery power telemetry.
- **Advanced Optional Software Installer**: Added an extensive modular software selection menu to the installation script covering:
  - **Graphics & Layout**: GIMP, Inkscape, Darktable, MyPaint.
  - **System & Administration**: GParted, Timeshift, Flatseal, Warehouse, Baobab (Disk Usage Analyzer).
  - **Audio & Video**: HandBrake, Lollypop, Amberol, Parabolic, Pitivi.
  - **Productivity & Communication**: LibreOffice, Evolution, Geary, Fragments, Transmission.
  - **Development & Text Editing**: GNOME Builder, Geany, Meld.
  - **Flatpak & App Ecosystem**: Automated Flatpak installation alongside GNOME Software integration.
- **Smart Self-Healing Installer & GitHub Source Builder**: Enhanced `install-aquaroot-complete.sh` with automated error parsing, dpkg/pacman lock healing, and fallback source compilation (Meson/Ninja and Cargo) for systems missing precompiled binary packages (such as Wayfire, pixdecor, swww, and gtk4-layer-shell).

---

## [1.5.0] - 2026-10-21
### Added
- **QuickLook File Previewer**: Integrated GNOME Sushi with Nautilus to allow instant spacebar previews for images, PDFs, audio, video, and code files inside a floating Liquid Glass window.
- **Custom Liquid Glass Readability & Settings Engine**: Added `aquaroot-glass-ctl.py` to allow real-time adjustment of glass opacity, Kawase blur passes, refraction offset, specular rim intensity, and high-contrast readability modes.
- **Hardware Telemetry Widget**: Added a zero-dependency system telemetry monitor inside the top bar displaying live CPU usage, RAM utilization, and thermal sensor temperatures.
- **macOS Spotlight Clone**: Implemented `aquaroot-spotlight.py` (`Super + Space`) for fast application launching, file searching, and live math evaluation.
- **First-Boot Onboarding Assistant**: Created `aquaroot-welcome.py`, a macOS-inspired setup wizard that runs on first login to guide users through initial Liquid Glass preferences and wallpaper selection.

---

## [1.0.0] - 2026-10-21
### Added
- **Initial Release of AquaRoot DE**
- **Compositor Core**: Built on Wayfire / wlroots with support for 2D/3D mesh deformations, Kawase/Bokeh background blur, and `squeezimize` Genie minimize/restore animations.
- **Liquid Glass Aesthetic Engine**: Custom GTK4 CSS theme featuring specular inner bevels, chromatic frost tinting, and dynamic drop shadows across panels and windows.
- **Dynamic Top Bar**: Custom Python top bar featuring the distribution logo system menu, D-Bus Global Menu registrar support (`com.canonical.AppMenu.Registrar`), clock, and built-in headless `yt-dlp` + `mpv` YouTube Audio player plugin.
- **Parabolic Magnification Dock**: Custom layer-shell dock featuring Gaussian hover icon magnification and foreign-toplevel integration.
- **Wallpaper & Biometric Lock Screen**: Integrated `swww` for fluid animated wallpaper transitions, online wallpaper fetching from Wallhaven, and a dynamic lock screen supporting parallel Face ID (`howdy`) and Touch ID (`fprintd`) PAM authentication.
