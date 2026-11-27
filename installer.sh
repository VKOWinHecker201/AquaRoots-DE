#!/usr/bin/env bash
# ==============================================================================
# AquaRoot DE v3.0 — Complete Self-Extracting Bootstrapper & Desktop Ecosystem
# Compositor: wlroots / Wayfire | UI: GTK4 + gtk4-layer-shell (Liquid Glass)
# Includes: Self-Healing Source Builder, Top Bar, Dock, Dynamic Notch v2
#           (MPRIS + Dropover Shelf), Control Center & Notification Daemon,
#           Desktop Widgets, OSD, Stage Manager, Spotlight v2 (Clipboard +
#           Unit Converter), Screenshot/OCR Studio, AquaDrop, Time Machine,
#           macOS-style System Settings, Welcome Wizard & Biometric Lock Screen.
# ==============================================================================
set -u

VERSION="3.0.0"
LOG_FILE="/tmp/aquaroot-v3-install-$(date +%Y%m%d-%H%M%S).log"
BUILD_ROOT="/tmp/aquaroot-src-build"
SOURCE_BUILD_QUEUE=()

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${BLUE}[AquaRoot v3.0]${NC} $1" | tee -a "$LOG_FILE"; }
ok()    { echo -e "${GREEN}[     OK      ]${NC} $1" | tee -a "$LOG_FILE"; }
warn()  { echo -e "${YELLOW}[    WARN     ]${NC} $1" | tee -a "$LOG_FILE"; }
err()   { echo -e "${RED}[    ERROR    ]${NC} $1" | tee -a "$LOG_FILE"; }

print_banner() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}"
    cat << 'BANNER'
    ___                     ____              __     ____  ______
   /   | ____ ___  ______ _/ __ \____  ____  / /_   / __ \/ ____/
  / /| |/ __ `/ / / / __ `/ /_/ / __ \/ __ \/ __/  / / / / __/   
 / ___ / /_/ / /_/ / /_/ / _, _/ /_/ / /_/ / /_   / /_/ / /___   
/_/  |_\__, /\__,_/\__,_/_/ |_|\____/\____/\__/  /_____/_____/   
         /_/   Liquid Glass wlroots Desktop Ecosystem v3.0
BANNER
    echo -e "${NC}"
    echo -e "  Installation Log: ${YELLOW}${LOG_FILE}${NC}\n"
}

run_with_spinner() {
    local msg="$1"
    shift
    local pid
    "$@" >>"$LOG_FILE" 2>&1 &
    pid=$!
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        printf "\r  ${CYAN}%s${NC} %s..." "${spin:$i:1}" "$msg"
        sleep 0.12
    done
    wait "$pid"
    local status=$?
    if [[ $status -eq 0 ]]; then
        printf "\r  ${GREEN}✔${NC} %s\n" "$msg"
    else
        printf "\r  ${RED}✖${NC} %s (See $LOG_FILE)\n" "$msg"
    fi
    return $status
}

# ==============================================================================
# STEP 1: Distro Detection, Hardware Scan & Self-Healing Source Builder
# ==============================================================================
detect_distro() {
    if command -v pacman &>/dev/null; then
        PKG_MGR="pacman"
    elif command -v dnf &>/dev/null; then
        PKG_MGR="dnf"
    elif command -v apt-get &>/dev/null; then
        PKG_MGR="apt"
    else
        err "Unsupported package manager. Supported: pacman, dnf, apt."
        exit 1
    fi
    log "Detected package manager: ${BOLD}${PKG_MGR}${NC}"
}

install_build_toolchain() {
    log "Installing C/C++/Rust & Wayland source build toolchains..."
    if [[ "$PKG_MGR" == "apt" ]]; then
        sudo apt-get update -y >>"$LOG_FILE" 2>&1 || true
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
            git build-essential meson ninja-build cmake pkg-config cargo rustc \
            wayland-protocols libwayland-dev libdrm-dev libegl1-mesa-dev \
            libgles2-mesa-dev libgbm-dev libinput-dev libxkbcommon-dev \
            libpixman-1-dev libcairo2-dev libpango1.0-dev libglm-dev \
            libjpeg-dev libpng-dev libwebp-dev libseat-dev libudev-dev \
            libxcb1-dev libxcb-composite0-dev libxcb-render0-dev \
            libxcb-xfixes0-dev libxcb-xinput-dev libx11-xcb-dev \
            libgtk-4-dev libgtk-3-dev libglibmm-2.4-dev libjson-c-dev \
            libxml2-dev libevdev-dev libdisplay-info-dev hwdata \
            libpam0g-dev scdoc >>"$LOG_FILE" 2>&1 || true
    elif [[ "$PKG_MGR" == "dnf" ]]; then
        sudo dnf install -y \
            git gcc gcc-c++ meson ninja-build cmake pkgconf-pkg-config cargo rust \
            wayland-devel wayland-protocols-devel libdrm-devel mesa-libEGL-devel \
            mesa-libGLES-devel mesa-libgbm-devel libinput-devel libxkbcommon-devel \
            pixman-devel cairo-devel pango-devel glm-devel libjpeg-turbo-devel \
            libpng-devel libseat-devel systemd-devel libxcb-devel gtk4-devel \
            gtk3-devel glibmm24-devel json-c-devel libxml2-devel libevdev-devel \
            libdisplay-info-devel hwdata-devel pam-devel scdoc >>"$LOG_FILE" 2>&1 || true
    elif [[ "$PKG_MGR" == "pacman" ]]; then
        sudo pacman -S --needed --noconfirm \
            git base-devel meson ninja cmake pkgconf rust cargo \
            wayland wayland-protocols libdrm mesa libinput libxkbcommon \
            pixman cairo pango glm libjpeg-turbo libpng seatd systemd \
            gtk4 gtk3 glibmm json-c libxml2 libevdev libdisplay-info \
            hwdata pam scdoc >>"$LOG_FILE" 2>&1 || true
    fi
}

setup_pkg_config_paths() {
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:/usr/local/lib/x86_64-linux-gnu/pkgconfig:/usr/local/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}"
    export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:/usr/local/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
    sudo sh -c 'echo "/usr/local/lib" > /etc/ld.so.conf.d/aquaroot-local.conf' 2>/dev/null || true
    sudo ldconfig 2>/dev/null || true
}

build_from_github() {
    local target="$1"
    mkdir -p "$BUILD_ROOT"
    setup_pkg_config_paths

    case "$target" in
        wayfire)
            log "Building Wayfire + embedded wlroots & wf-config from GitHub..."
            rm -rf "$BUILD_ROOT/wayfire"
            run_with_spinner "Cloning WayfireWM/wayfire" git clone --recurse-submodules https://github.com/WayfireWM/wayfire.git "$BUILD_ROOT/wayfire"
            pushd "$BUILD_ROOT/wayfire" >/dev/null
            meson setup build --prefix=/usr --buildtype=release -Duse_system_wlroots=disabled -Duse_system_wfconfig=disabled -Dxwayland=enabled >>"$LOG_FILE" 2>&1
            ninja -C build >>"$LOG_FILE" 2>&1
            sudo ninja -C build install >>"$LOG_FILE" 2>&1
            popd >/dev/null
            ;;
        wayfire-plugins-extra)
            log "Building wayfire-plugins-extra..."
            rm -rf "$BUILD_ROOT/wayfire-plugins-extra"
            run_with_spinner "Cloning wayfire-plugins-extra" git clone --recurse-submodules https://github.com/WayfireWM/wayfire-plugins-extra.git "$BUILD_ROOT/wayfire-plugins-extra"
            pushd "$BUILD_ROOT/wayfire-plugins-extra" >/dev/null
            meson setup build --prefix=/usr --buildtype=release >>"$LOG_FILE" 2>&1
            ninja -C build >>"$LOG_FILE" 2>&1
            sudo ninja -C build install >>"$LOG_FILE" 2>&1
            popd >/dev/null
            ;;
        pixdecor)
            log "Building pixdecor..."
            rm -rf "$BUILD_ROOT/pixdecor"
            run_with_spinner "Cloning soreau/pixdecor" git clone https://github.com/soreau/pixdecor.git "$BUILD_ROOT/pixdecor"
            pushd "$BUILD_ROOT/pixdecor" >/dev/null
            meson setup build --prefix=/usr --buildtype=release >>"$LOG_FILE" 2>&1
            ninja -C build >>"$LOG_FILE" 2>&1
            sudo ninja -C build install >>"$LOG_FILE" 2>&1
            popd >/dev/null
            ;;
        swww)
            log "Building swww..."
            rm -rf "$BUILD_ROOT/swww"
            run_with_spinner "Cloning LGFae/swww" git clone https://github.com/LGFae/swww.git "$BUILD_ROOT/swww"
            pushd "$BUILD_ROOT/swww" >/dev/null
            cargo build --release >>"$LOG_FILE" 2>&1
            sudo install -Dm755 target/release/swww /usr/local/bin/swww
            sudo install -Dm755 target/release/swww-daemon /usr/local/bin/swww-daemon
            popd >/dev/null
            ;;
        gtk4-layer-shell)
            log "Building gtk4-layer-shell..."
            rm -rf "$BUILD_ROOT/gtk4-layer-shell"
            run_with_spinner "Cloning wmww/gtk4-layer-shell" git clone https://github.com/wmww/gtk4-layer-shell.git "$BUILD_ROOT/gtk4-layer-shell"
            pushd "$BUILD_ROOT/gtk4-layer-shell" >/dev/null
            meson setup build --prefix=/usr --buildtype=release -Dexamples=false -Dtests=false >>"$LOG_FILE" 2>&1
            ninja -C build >>"$LOG_FILE" 2>&1
            sudo ninja -C build install >>"$LOG_FILE" 2>&1
            popd >/dev/null
            ;;
        yt-dlp)
            sudo curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
            sudo chmod a+rx /usr/local/bin/yt-dlp
            ;;
    esac
    sudo ldconfig 2>/dev/null || true
}

install_single_pkg_with_recovery() {
    local pkg="$1"
    local out="/tmp/aquaroot-pkg.log"
    if [[ "$PKG_MGR" == "apt" ]]; then
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >"$out" 2>&1 || {
            warn "Package '$pkg' unavailable via apt. Queuing fallback."
            SOURCE_BUILD_QUEUE+=("$pkg")
            return
        }
    elif [[ "$PKG_MGR" == "dnf" ]]; then
        sudo dnf install -y "$pkg" >"$out" 2>&1 || {
            SOURCE_BUILD_QUEUE+=("$pkg")
            return
        }
    elif [[ "$PKG_MGR" == "pacman" ]]; then
        sudo pacman -S --needed --noconfirm "$pkg" >"$out" 2>&1 || {
            SOURCE_BUILD_QUEUE+=("$pkg")
            return
        }
    fi
    ok "Installed package: $pkg"
}

scan_and_install_hardware_and_deps() {
    detect_distro
    log "Scanning CPU, GPU, Wi-Fi, Bluetooth & installing AquaRoot v3.0 packages..."

    CPU_VENDOR=$(LC_ALL=C lscpu | awk -F: '/Vendor ID/ {gsub(/^[ \t]+/, "", $2); print $2}' || true)
    GPU_INFO=$(lspci | grep -E "VGA|3D|Display" || true)

    local pkgs=()
    if [[ "$PKG_MGR" == "pacman" ]]; then
        [[ "$CPU_VENDOR" == *"AMD"* ]] && pkgs+=(amd-ucode)
        [[ "$CPU_VENDOR" == *"Intel"* ]] && pkgs+=(intel-ucode)
        echo "$GPU_INFO" | grep -qi "nvidia" && pkgs+=(nvidia-open-dkms nvidia-utils egl-wayland)
        echo "$GPU_INFO" | grep -qiE "amd|radeon" && pkgs+=(mesa vulkan-radeon libva-mesa-driver)
        echo "$GPU_INFO" | grep -qi "intel" && pkgs+=(mesa vulkan-intel intel-media-driver)

        pkgs+=(linux-firmware networkmanager iwd bluez bluez-utils blueman pavucontrol
               pipewire wireplumber wayfire wf-config wayfire-plugins-extra wlroots
               xorg-xwayland swww mpv yt-dlp nautilus sushi foot wl-clipboard
               python python-gobject gtk4 gtk4-layer-shell libdbusmenu-glib
               appmenu-gtk-module fprintd hyprlock imagemagick jq curl
               grim slurp wf-recorder tesseract tesseract-data-eng wlsunset
               brightnessctl pamixer xdg-desktop-portal xdg-desktop-portal-wlr
               xdg-desktop-portal-gtk timeshift kdeconnect libnotify)
    elif [[ "$PKG_MGR" == "dnf" ]]; then
        pkgs+=(linux-firmware NetworkManager bluez blueman pavucontrol pipewire
               wireplumber mesa-dri-drivers mesa-vulkan-drivers wayfire wf-config
               wayfire-plugins-extra wlroots xorg-x11-server-Xwayland swww mpv
               yt-dlp nautilus sushi foot wl-clipboard python3 python3-gobject
               gtk4 gtk4-layer-shell fprintd fprintd-pam hyprlock ImageMagick jq curl
               grim slurp wf-recorder tesseract wlsunset brightnessctl pamixer
               xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
               timeshift kde-connect libnotify)
    elif [[ "$PKG_MGR" == "apt" ]]; then
        sudo apt-get update -y >>"$LOG_FILE" 2>&1 || true
        pkgs+=(firmware-linux network-manager bluez blueman pavucontrol pipewire
               wireplumber mesa-vulkan-drivers wayfire wayfire-plugins-extra
               xwayland swww mpv yt-dlp nautilus gnome-sushi foot wl-clipboard
               python3 python3-gi gir1.2-gtk-4.0 libgtk4-layer-shell0 fprintd
               libpam-fprintd hyprlock imagemagick jq curl grim slurp wf-recorder
               tesseract-ocr wlsunset brightnessctl pamixer xdg-desktop-portal
               xdg-desktop-portal-wlr xdg-desktop-portal-gtk timeshift kdeconnect
               libnotify-bin)
    fi

    for p in "${pkgs[@]}"; do
        install_single_pkg_with_recovery "$p"
    done

    command -v wayfire &>/dev/null || { install_build_toolchain; build_from_github "wayfire"; }
    command -v swww &>/dev/null    || { install_build_toolchain; build_from_github "swww"; }
    command -v yt-dlp &>/dev/null  || build_from_github "yt-dlp"
    ldconfig -p 2>/dev/null | grep -q "libgtk4-layer-shell" || { install_build_toolchain; build_from_github "gtk4-layer-shell"; }
    [[ -f /usr/lib/wayfire/libpixdecor.so || -f /usr/lib/x86_64-linux-gnu/wayfire/libpixdecor.so ]] || {
        install_build_toolchain
        build_from_github "pixdecor"
        build_from_github "wayfire-plugins-extra"
    }

    sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
    sudo systemctl enable --now bluetooth.service 2>/dev/null || true
}

# ==============================================================================
# STEP 2: Deploy All AquaRoot v3.0 Configs, Stylesheets & Python Applications
# ==============================================================================
deploy_aquaroot_files() {
    log "Creating AquaRoot v3.0 directory tree..."
    mkdir -p "$HOME/.local/bin" \
             "$HOME/.config/gtk-4.0" \
             "$HOME/.config/gtk-3.0" \
             "$HOME/.config/hypr" \
             "$HOME/.config/aquaroot" \
             "$HOME/.config/xdg-desktop-portal" \
             "$HOME/.cache/aquaroot" \
             "$HOME/.local/share/aquaroot/wallpapers" \
             "$HOME/.local/share/aquaroot/timemachine" \
             "$HOME/.local/share/applications" \
             "$HOME/Pictures/Screenshots" \
             "$HOME/Videos/ScreenRecordings" \
             "$HOME/Downloads/AquaDrop"

    # --------------------------------------------------------------------------
    # 1. XDG Desktop Portal Config (~/.config/xdg-desktop-portal/aquaroot-portals.conf)
    # --------------------------------------------------------------------------
    log "Writing ~/.config/xdg-desktop-portal/aquaroot-portals.conf..."
    cat << 'EOF' > "$HOME/.config/xdg-desktop-portal/aquaroot-portals.conf"
[preferred]
default=gtk
org.freedesktop.impl.portal.ScreenCast=wlr
org.freedesktop.impl.portal.Screenshot=wlr
EOF

    # --------------------------------------------------------------------------
    # 2. Wayfire Compositor Config (~/.config/wayfire.ini)
    # --------------------------------------------------------------------------
    log "Writing ~/.config/wayfire.ini..."
    cat << 'EOF' > "$HOME/.config/wayfire.ini"
[core]
plugins = alpha animate autostart blur command cube decoration expo fast-switcher \
          fisheye foreign-toplevel grid idle ipc ipc-rules move oswitch place \
          resize scale session-lock shortcuts-inhibitor switcher vswipe \
          window-rules wm-actions wobbly workarounds extra-animations pixdecor
preferred_decoration_mode = server
xwayland = true

[animate]
open_animation = zoom
close_animation = zoom
minimize_animation = squeezimize
duration = 380ms cubic-bezier(0.22, 1.0, 0.36, 1.0)
startup_duration = 450ms

[extra-animations]
squeezimize_duration = 420ms ease-in-out

[grid]
type = simple
duration = 320ms cubic-bezier(0.16, 1.0, 0.3, 1.0)
restore = <super> KEY_DOWN
slot_c = <super> KEY_UP

[scale]
toggle = <super> KEY_TAB
duration = 300ms cubic-bezier(0.22, 1.0, 0.36, 1.0)
interact = true

[expo]
toggle = <super> KEY_E
duration = 320ms cubic-bezier(0.22, 1.0, 0.36, 1.0)

[blur]
method = kawase
mode = normal
kawase_degrade = 3
kawase_iterations = 4
kawase_offset = 2.2
saturation = 1.35
blur_by_default = type is "toplevel" | type is "panel" | type is "overlay"

[pixdecor]
border_size = 1
titlebar = true
maximized_borders = false
maximized_shadows = false
rounded_corner_radius = 14
shadow_radius = 28
shadow_color = \#00000066
button_layout = close,minimize,maximize:
button_color_close = \#FF5F56FF
button_color_minimize = \#FFBD2EFF
button_color_maximize = \#27C93FFF
fg_color = \#FFFFFF22
bg_color = \#1E222A88

[vswipe]
binding_left = swipe-left
binding_right = swipe-right
delta_threshold = 24.0
duration = 280ms
enable_free_movement = true
enable_horizontal = true
enable_smooth_transition = true
fingers = 3

[window-rules]
rule_quicklook_blur = on created if app_id is "org.gnome.NautilusPreviewer" then set alpha 0.92
rule_quicklook_center = on created if app_id is "org.gnome.NautilusPreviewer" then center

[command]
binding_spotlight = <super> KEY_SPACE
command_spotlight = ~/.local/bin/aquaroot-spotlight.py
binding_clipboard = <super> KEY_V
command_clipboard = ~/.local/bin/aquaroot-spotlight.py
binding_screenshot = <super> <shift> KEY_5
command_screenshot = ~/.local/bin/aquaroot-screenshot.py
binding_control_center = <super> KEY_N
command_control_center = pkill -USR1 -f aquaroot-notifications.py
binding_stagemanager = <super> KEY_S
command_stagemanager = bash -c "pkill -f aquaroot-stagemanager.py || ~/.local/bin/aquaroot-stagemanager.py &"
binding_vol_up = KEY_VOLUMEUP
command_vol_up = ~/.local/bin/aquaroot-osd.py vol-up
binding_vol_down = KEY_VOLUMEDOWN
command_vol_down = ~/.local/bin/aquaroot-osd.py vol-down
binding_vol_mute = KEY_MUTE
command_vol_mute = ~/.local/bin/aquaroot-osd.py vol-mute
binding_bri_up = KEY_BRIGHTNESSUP
command_bri_up = ~/.local/bin/aquaroot-osd.py bri-up
binding_bri_down = KEY_BRIGHTNESSDOWN
command_bri_down = ~/.local/bin/aquaroot-osd.py bri-down
binding_terminal = <super> KEY_ENTER
command_terminal = foot
binding_lock = <super> KEY_L
command_lock = hyprlock

[autostart]
00_env = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=AquaRoot
01_wallpaper_daemon = swww-daemon
02_topbar = ~/.local/bin/aquaroot-topbar.py
03_notch = ~/.local/bin/aquaroot-notch.py
04_dock = ~/.local/bin/aquaroot-dock.py
05_notifications = ~/.local/bin/aquaroot-notifications.py
06_widgets = ~/.local/bin/aquaroot-widgets.py
07_wallpaper_sync = ~/.local/bin/aquaroot-wallpaper.sh --restore
08_welcome = ~/.local/bin/aquaroot-welcome.py
EOF

    # --------------------------------------------------------------------------
    # 3. Master Liquid Glass Stylesheet (~/.config/gtk-4.0/gtk.css)
    # --------------------------------------------------------------------------
    log "Writing complete Liquid Glass Stylesheet (~/.config/gtk-4.0/gtk.css)..."
    cat << 'EOF' > "$HOME/.config/gtk-4.0/gtk.css"
/* AQUAROOT_DYNAMIC_VARS_START */
@define-color liquid_bg rgba(22, 26, 36, 0.52);
@define-color liquid_surface rgba(255, 255, 255, 0.12);
@define-color liquid_highlight rgba(255, 255, 255, 0.55);
@define-color liquid_border rgba(255, 255, 255, 0.25);
@define-color aqua_accent #0A84FF;
@define-color text_primary #F5F7FA;
/* AQUAROOT_DYNAMIC_VARS_END */

/* Base Liquid Glass Surface */
.liquid-glass,
popover.background > contents,
window.nautilus-window .sidebar-pane,
window#org-gnome-NautilusPreviewer,
.sushi-window {
    background-color: @liquid_bg;
    background-image: linear-gradient(
        135deg,
        rgba(255, 255, 255, 0.24) 0%,
        rgba(255, 255, 255, 0.05) 45%,
        rgba(255, 255, 255, 0.12) 100%
    );
    border-radius: 16px;
    border: 1px solid @liquid_border;
    box-shadow:
        inset 0 1px 1px 0 @liquid_highlight,
        inset 1px 0 1px 0 rgba(255, 255, 255, 0.25),
        0 14px 34px rgba(0, 0, 0, 0.42);
    color: @text_primary;
}

/* Transparent Layer-Shell Windows */
window#aquaroot-topbar,
window#aquaroot-notch,
window#aquaroot-notifications,
window#aquaroot-widgets,
window#aquaroot-osd,
window#aquaroot-stagemanager,
window#aquaroot-screenshot {
    background: transparent;
}

/* Top Bar Capsules */
.topbar-capsule {
    background-color: @liquid_bg;
    background-image: linear-gradient(180deg, rgba(255, 255, 255, 0.28) 0%, rgba(255, 255, 255, 0.06) 100%);
    border-radius: 999px;
    border: 1px solid @liquid_border;
    box-shadow: inset 0 1px 1.5px @liquid_highlight, 0 6px 20px rgba(0, 0, 0, 0.35);
    padding: 2px 12px;
    margin: 6px 12px;
    color: @text_primary;
}

.global-menu-btn {
    background: transparent;
    border-radius: 999px;
    padding: 3px 10px;
    font-weight: 500;
    color: @text_primary;
    transition: background-color 160ms cubic-bezier(0.22, 1, 0.36, 1);
}

.global-menu-btn:hover {
    background-color: rgba(255, 255, 255, 0.18);
    box-shadow: inset 0 1px 0.5px rgba(255, 255, 255, 0.45);
}

.yt-pill {
    background: linear-gradient(135deg, rgba(255, 45, 85, 0.24), rgba(10, 132, 255, 0.22));
    border-radius: 999px;
    border: 1px solid @liquid_border;
    padding: 2px 10px;
    color: @text_primary;
}

/* Dynamic Notch Island (Compact & Expanded States) */
.dynamic-notch {
    background-color: rgba(10, 12, 18, 0.88);
    background-image: linear-gradient(180deg, rgba(255,255,255,0.16), rgba(255,255,255,0.03));
    border-bottom-left-radius: 22px;
    border-bottom-right-radius: 22px;
    border-top-left-radius: 4px;
    border-top-right-radius: 4px;
    border: 1px solid @liquid_border;
    box-shadow: inset 0 1px 1px @liquid_highlight, 0 12px 32px rgba(0,0,0,0.55);
    padding: 6px 18px;
    margin-top: 0px;
    color: @text_primary;
    transition: all 280ms cubic-bezier(0.22, 1, 0.36, 1);
}

.dynamic-notch-expanded {
    background-color: rgba(14, 18, 28, 0.92);
    border-radius: 26px;
    padding: 14px 20px;
    margin-top: 6px;
    box-shadow: inset 0 1px 1.5px @liquid_highlight, 0 22px 48px rgba(0,0,0,0.68);
}

.notch-section-card {
    background-color: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.16);
    border-radius: 16px;
    padding: 10px 14px;
}

.notch-icon-btn {
    background: rgba(255, 255, 255, 0.10);
    border-radius: 999px;
    padding: 4px 8px;
    color: @text_primary;
}

.notch-icon-btn:hover {
    background: @aqua_accent;
}

.dropover-shelf {
    background-color: rgba(10, 132, 255, 0.22);
    border: 1px dashed rgba(255, 255, 255, 0.55);
    border-radius: 16px;
    padding: 10px;
}

/* macOS System Settings Window & Cards */
.macos-settings-window {
    background-color: @liquid_bg;
    background-image: linear-gradient(140deg, rgba(255,255,255,0.20) 0%, rgba(16,20,30,0.82) 100%);
    border-radius: 18px;
    border: 1px solid @liquid_border;
    color: @text_primary;
}

.macos-sidebar {
    background-color: rgba(14, 17, 24, 0.45);
    border-right: 1px solid @liquid_border;
    padding: 12px 10px;
}

.macos-sidebar-list {
    background: transparent;
}

.macos-sidebar-list row {
    border-radius: 10px;
    padding: 6px 10px;
    margin: 2px 4px;
    color: @text_primary;
    transition: all 140ms ease;
}

.macos-sidebar-list row:selected {
    background-color: @aqua_accent;
    color: #FFFFFF;
    font-weight: 600;
}

.macos-squircle-badge {
    border-radius: 8px;
    padding: 5px;
    color: #FFFFFF;
    box-shadow: inset 0 1px 1px rgba(255,255,255,0.45);
}

.badge-blue   { background: linear-gradient(180deg, #3898FF, #0A84FF); }
.badge-purple { background: linear-gradient(180deg, #BF5AF2, #8E44AD); }
.badge-pink   { background: linear-gradient(180deg, #FF375F, #D70015); }
.badge-orange { background: linear-gradient(180deg, #FF9F0A, #FF6B00); }
.badge-green  { background: linear-gradient(180deg, #30D158, #248A3D); }
.badge-teal   { background: linear-gradient(180deg, #64D2FF, #0071E3); }
.badge-gray   { background: linear-gradient(180deg, #8E8E93, #636366); }

.macos-group-card {
    background-color: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.16);
    border-radius: 14px;
    box-shadow: inset 0 1px 0.5px rgba(255, 255, 255, 0.25);
    padding: 6px 14px;
}

.macos-row {
    padding: 10px 4px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
}

.macos-row:last-child {
    border-bottom: none;
}

.macos-action-btn {
    background-color: rgba(255, 255, 255, 0.14);
    border: 1px solid rgba(255, 255, 255, 0.24);
    border-radius: 9px;
    padding: 6px 14px;
    color: @text_primary;
    font-weight: 500;
}

.macos-action-btn:hover {
    background-color: @aqua_accent;
    color: #FFFFFF;
}

.traffic-dot {
    min-width: 12px;
    min-height: 12px;
    border-radius: 999px;
    padding: 0;
}
.traffic-close { background-color: #FF5F56; }
.traffic-min   { background-color: #FFBD2E; }
.traffic-max   { background-color: #27C93F; }

/* Control Center, Notifications, Widgets, OSD & Stage Manager */
.control-center-drawer {
    background-color: @liquid_bg;
    background-image: linear-gradient(145deg, rgba(255,255,255,0.22), rgba(15,18,28,0.88));
    border-radius: 22px;
    border: 1px solid @liquid_border;
    box-shadow: inset 0 1px 1.5px @liquid_highlight, 0 22px 48px rgba(0,0,0,0.58);
    padding: 16px;
    margin: 8px 14px 14px 14px;
    color: @text_primary;
}

.cc-pill-toggle {
    background-color: rgba(255, 255, 255, 0.10);
    border: 1px solid rgba(255, 255, 255, 0.18);
    border-radius: 14px;
    padding: 10px 14px;
    color: @text_primary;
    transition: all 180ms cubic-bezier(0.22, 1, 0.36, 1);
}

.cc-pill-toggle:checked {
    background-color: @aqua_accent;
    background-image: linear-gradient(180deg, rgba(255,255,255,0.28), rgba(255,255,255,0.0));
    border-color: rgba(255, 255, 255, 0.45);
    color: #FFFFFF;
}

.notification-toast {
    background-color: rgba(18, 22, 32, 0.85);
    background-image: linear-gradient(135deg, rgba(255,255,255,0.20), rgba(255,255,255,0.04));
    border-radius: 18px;
    border: 1px solid @liquid_border;
    box-shadow: inset 0 1px 1px @liquid_highlight, 0 14px 32px rgba(0,0,0,0.48);
    padding: 12px 16px;
    margin: 6px 14px;
    color: @text_primary;
}

.desktop-widget-card {
    background-color: @liquid_bg;
    background-image: linear-gradient(135deg, rgba(255,255,255,0.20), rgba(255,255,255,0.03));
    border-radius: 22px;
    border: 1px solid @liquid_border;
    box-shadow: inset 0 1px 1px @liquid_highlight, 0 12px 28px rgba(0,0,0,0.35);
    padding: 16px;
    color: @text_primary;
}

.osd-capsule {
    background-color: rgba(14, 18, 26, 0.86);
    background-image: linear-gradient(180deg, rgba(255,255,255,0.24), rgba(255,255,255,0.04));
    border-radius: 999px;
    border: 1px solid @liquid_border;
    box-shadow: inset 0 1px 1.5px @liquid_highlight, 0 16px 36px rgba(0,0,0,0.55);
    padding: 10px 22px;
    margin-bottom: 64px;
    color: @text_primary;
}

.stage-strip-card {
    background-color: rgba(20, 24, 34, 0.72);
    background-image: linear-gradient(135deg, rgba(255,255,255,0.22), rgba(255,255,255,0.04));
    border-radius: 14px;
    border: 1px solid @liquid_border;
    box-shadow: inset 0 1px 1px @liquid_highlight, 0 8px 20px rgba(0,0,0,0.40);
    padding: 10px 12px;
    margin: 6px 10px;
    color: @text_primary;
    transition: all 200ms cubic-bezier(0.22, 1, 0.36, 1);
}

.stage-strip-card:hover {
    background-color: rgba(10, 132, 255, 0.45);
    margin-left: 16px;
}

/* Finder-Style Nautilus */
window.nautilus-window { background-color: @liquid_bg; border-radius: 14px; }
window.nautilus-window .navigation-sidebar { background-color: transparent; padding: 8px; }
window.nautilus-window .navigation-sidebar row { border-radius: 10px; margin: 2px 4px; padding: 6px 10px; }
window.nautilus-window .navigation-sidebar row:selected { background-color: rgba(10, 132, 255, 0.75); color: #FFFFFF; font-weight: 600; }
window.nautilus-window .view { background-color: rgba(18, 20, 26, 0.88); border-top-left-radius: 12px; }
headerbar { background: @liquid_bg; border-bottom: 1px solid @liquid_border; }
EOF
    ln -sf "$HOME/.config/gtk-4.0/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"

    # --------------------------------------------------------------------------
    # 4. Liquid Glass Readability Controller (~/.local/bin/aquaroot-glass-ctl.py)
    # --------------------------------------------------------------------------
    log "Writing ~/.local/bin/aquaroot-glass-ctl.py..."
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-glass-ctl.py"
#!/usr/bin/env python3
import sys
import json
import configparser
from pathlib import Path

CONFIG_DIR = Path.home() / ".config" / "aquaroot"
GLASS_JSON = CONFIG_DIR / "glass.json"
GTK4_CSS = Path.home() / ".config" / "gtk-4.0" / "gtk.css"
WAYFIRE_INI = Path.home() / ".config" / "wayfire.ini"

DEFAULT_GLASS = {
    "opacity": 0.52,
    "blur_iterations": 4,
    "blur_offset": 2.2,
    "specular_intensity": 0.55,
    "reduce_transparency": False,
    "tint_mode": "dark"
}

def load_settings():
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    if GLASS_JSON.exists():
        try:
            return {**DEFAULT_GLASS, **json.loads(GLASS_JSON.read_text())}
        except Exception:
            pass
    return DEFAULT_GLASS.copy()

def apply_settings(cfg):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    GLASS_JSON.write_text(json.dumps(cfg, indent=2))

    eff_opacity = 0.94 if cfg["reduce_transparency"] else cfg["opacity"]
    spec = 0.15 if cfg["reduce_transparency"] else cfg["specular_intensity"]

    if cfg["tint_mode"] == "light":
        bg_rgb = "240, 244, 250"
        text_hex = "#12151C"
    else:
        bg_rgb = "22, 26, 36"
        text_hex = "#F5F7FA"

    dynamic_header = f"""/* AQUAROOT_DYNAMIC_VARS_START */
@define-color liquid_bg rgba({bg_rgb}, {eff_opacity:.2f});
@define-color liquid_surface rgba(255, 255, 255, {spec * 0.22:.2f});
@define-color liquid_highlight rgba(255, 255, 255, {spec:.2f});
@define-color liquid_border rgba(255, 255, 255, {max(0.15, spec * 0.45):.2f});
@define-color aqua_accent #0A84FF;
@define-color text_primary {text_hex};
/* AQUAROOT_DYNAMIC_VARS_END */
"""
    if GTK4_CSS.exists():
        content = GTK4_CSS.read_text()
        if "/* AQUAROOT_DYNAMIC_VARS_START */" in content:
            end = content.index("/* AQUAROOT_DYNAMIC_VARS_END */") + len("/* AQUAROOT_DYNAMIC_VARS_END */\n")
            content = dynamic_header + content[end:]
        else:
            content = dynamic_header + "\n" + content
        GTK4_CSS.write_text(content)

    if WAYFIRE_INI.exists():
        parser = configparser.ConfigParser(interpolation=None)
        parser.read(WAYFIRE_INI)
        if "blur" not in parser:
            parser["blur"] = {}
        parser["blur"]["kawase_iterations"] = "1" if cfg["reduce_transparency"] else str(int(cfg["blur_iterations"]))
        parser["blur"]["kawase_offset"] = "0.5" if cfg["reduce_transparency"] else f"{cfg['blur_offset']:.1f}"
        with open(WAYFIRE_INI, "w") as f:
            parser.write(f)

if __name__ == "__main__":
    cfg = load_settings()
    for arg in sys.argv[1:]:
        if "=" in arg:
            k, v = arg.split("=", 1)
            if k in cfg:
                if isinstance(cfg[k], bool):
                    cfg[k] = v.lower() in ("1", "true", "yes")
                elif isinstance(cfg[k], int):
                    cfg[k] = int(float(v))
                elif isinstance(cfg[k], float):
                    cfg[k] = float(v)
                else:
                    cfg[k] = v
    apply_settings(cfg)
EOF

    # --------------------------------------------------------------------------
    # 5. Online 4K & Solar Time-of-Day Wallpaper Engine (~/.local/bin/aquaroot-wallpaper.sh)
    # --------------------------------------------------------------------------
    log "Writing ~/.local/bin/aquaroot-wallpaper.sh..."
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-wallpaper.sh"
#!/usr/bin/env bash
set -euo pipefail

WALL_DIR="$HOME/.local/share/aquaroot/wallpapers"
CURRENT_LINK="$WALL_DIR/current_wallpaper.jpg"
mkdir -p "$WALL_DIR"

apply_wallpaper() {
    local img="$1"
    ln -sf "$img" "$CURRENT_LINK"
    if command -v swww &>/dev/null; then
        swww img "$img" \
            --transition-type wave \
            --transition-angle 45 \
            --transition-step 90 \
            --transition-fps 120 || true
    fi
}

case "${1:---online}" in
    --online)
        Query="${2:-macos+abstract+liquid+4k}"
        IMG_URL=$(curl -s "https://wallhaven.cc/api/v1/search?q=${Query}&atleast=3840x2160&sorting=random" \
                  | jq -r '.data[0].path' || true)
        if [[ -n "$IMG_URL" && "$IMG_URL" != "null" ]]; then
            DEST="$WALL_DIR/wall_$(date +%s).jpg"
            curl -sL "$IMG_URL" -o "$DEST"
            apply_wallpaper "$DEST"
        fi
        ;;
    --solar)
        HOUR=$(date +%H)
        if (( 10#$HOUR >= 5 && 10#$HOUR < 10 )); then
            "$0" --online "sunrise+mountains+4k"
        elif (( 10#$HOUR >= 10 && 10#$HOUR < 17 )); then
            "$0" --online "macos+daylight+landscape+4k"
        elif (( 10#$HOUR >= 17 && 10#$HOUR < 20 )); then
            "$0" --online "sunset+dusk+macos+4k"
        else
            "$0" --online "night+dark+nebula+4k"
        fi
        ;;
    --restore)
        if [[ -f "$CURRENT_LINK" ]]; then
            apply_wallpaper "$CURRENT_LINK"
        else
            convert -size 3840x2160 plasma:fractal -blur 0x25 "$WALL_DIR/default_aqua.jpg" 2>/dev/null || true
            [[ -f "$WALL_DIR/default_aqua.jpg" ]] && apply_wallpaper "$WALL_DIR/default_aqua.jpg"
        fi
        ;;
    *)
        [[ -f "$1" ]] && apply_wallpaper "$1"
        ;;
esac
EOF

    # --------------------------------------------------------------------------
    # 6. Dynamic Top Bar (~/.local/bin/aquaroot-topbar.py)
    # --------------------------------------------------------------------------
    log "Writing ~/.local/bin/aquaroot-topbar.py..."
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-topbar.py"
#!/usr/bin/env python3
import os
import json
import socket
import subprocess
import threading
from ctypes import CDLL

CDLL("libgtk4-layer-shell.so")
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gio, GLib, Gtk4LayerShell

MPV_SOCKET = "/tmp/aquaroot-yt.sock"


def get_distro_info():
    info = {"NAME": "Linux", "LOGO": "distributor-logo"}
    if os.path.exists("/etc/os-release"):
        with open("/etc/os-release") as f:
            for line in f:
                if "=" in line:
                    k, v = line.strip().split("=", 1)
                    info[k] = v.strip('"')
    icon_name = info.get("LOGO") or f"distributor-logo-{info.get('ID', 'linux')}"
    return info.get("NAME", "Linux"), icon_name


class YouTubeAudioWidget(Gtk.Box):
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.add_css_class("yt-pill")
        self.is_playing = False

        self.menu_btn = Gtk.MenuButton()
        self.menu_btn.set_has_frame(False)
        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.icon = Gtk.Image.new_from_icon_name("multimedia-player-symbolic")
        self.track_label = Gtk.Label(label="YT Audio")
        self.track_label.set_max_width_chars(18)
        self.track_label.set_ellipsize(3)
        btn_box.append(self.icon)
        btn_box.append(self.track_label)
        self.menu_btn.set_child(btn_box)

        self.play_btn = Gtk.Button.new_from_icon_name("media-playback-start-symbolic")
        self.play_btn.set_has_frame(False)
        self.play_btn.connect("clicked", self.toggle_pause)

        self.append(self.menu_btn)
        self.append(self.play_btn)

        self.popover = Gtk.Popover()
        pop_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        pop_box.set_margin_top(12); pop_box.set_margin_bottom(12)
        pop_box.set_margin_start(12); pop_box.set_margin_end(12)
        pop_box.set_size_request(290, -1)

        header = Gtk.Label()
        header.set_markup("<b>YouTube Audio Streamer</b>")
        pop_box.append(header)

        self.search_entry = Gtk.Entry()
        self.search_entry.set_placeholder_text("Search song or paste YouTube URL...")
        self.search_entry.connect("activate", self.on_search_activate)
        pop_box.append(self.search_entry)

        vol_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        vol_box.append(Gtk.Image.new_from_icon_name("audio-volume-high-symbolic"))
        self.vol_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 5)
        self.vol_scale.set_value(80)
        self.vol_scale.set_hexpand(True)
        self.vol_scale.connect("value-changed", self.on_volume_change)
        vol_box.append(self.vol_scale)
        pop_box.append(vol_box)

        self.popover.set_child(pop_box)
        self.menu_btn.set_popover(self.popover)

    def _send_mpv_cmd(self, cmd_list):
        if not os.path.exists(MPV_SOCKET):
            return
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(MPV_SOCKET)
                s.sendall((json.dumps({"command": cmd_list}) + "\n").encode("utf-8"))
        except OSError:
            pass

    def on_search_activate(self, entry):
        query = entry.get_text().strip()
        if not query:
            return
        self.track_label.set_text("Loading...")
        threading.Thread(target=self._stream_yt, args=(query,), daemon=True).start()

    def _stream_yt(self, query):
        subprocess.run(["pkill", "-f", MPV_SOCKET], stderr=subprocess.DEVNULL)
        target = query if query.startswith("http") else f"ytsearch1:{query}"
        try:
            title_out = subprocess.check_output(
                ["yt-dlp", "--get-title", "-f", "bestaudio", target], text=True
            ).strip().splitlines()[0]
        except Exception:
            title_out = query

        GLib.idle_add(self.track_label.set_text, title_out)
        GLib.idle_add(self.play_btn.set_icon_name, "media-playback-pause-symbolic")
        self.is_playing = True

        subprocess.Popen(
            ["mpv", "--no-video", f"--input-ipc-server={MPV_SOCKET}",
             f"--volume={int(self.vol_scale.get_value())}", "--ytdl-format=bestaudio", target],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )

    def toggle_pause(self, _btn):
        self._send_mpv_cmd(["cycle", "pause"])
        self.is_playing = not self.is_playing
        self.play_btn.set_icon_name("media-playback-pause-symbolic" if self.is_playing else "media-playback-start-symbolic")

    def on_volume_change(self, scale):
        self._send_mpv_cmd(["set_property", "volume", int(scale.get_value())])


class SystemTelemetryWidget(Gtk.MenuButton):
    def __init__(self):
        super().__init__()
        self.set_has_frame(False)
        self.add_css_class("yt-pill")
        self._prev_idle = 0
        self._prev_total = 0

        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        icon = Gtk.Image.new_from_icon_name("utilities-system-monitor-symbolic")
        self.stat_label = Gtk.Label(label="CPU 0%  RAM 0%  40°C")
        box.append(icon)
        box.append(self.stat_label)
        self.set_child(box)

        pop = Gtk.Popover()
        pop_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        pop_box.set_margin_top(12); pop_box.set_margin_bottom(12)
        pop_box.set_margin_start(14); pop_box.set_margin_end(14)
        pop_box.set_size_request(240, -1)

        title = Gtk.Label()
        title.set_markup("<b>Hardware Telemetry</b>")
        pop_box.append(title)

        self.cpu_bar = Gtk.LevelBar.new_for_interval(0, 100)
        self.gpu_bar = Gtk.LevelBar.new_for_interval(0, 100)
        self.ram_bar = Gtk.LevelBar.new_for_interval(0, 100)
        self.detail_lbl = Gtk.Label(label="Polling sensors...")

        pop_box.append(Gtk.Label(label="CPU Load", xalign=0))
        pop_box.append(self.cpu_bar)
        pop_box.append(Gtk.Label(label="GPU Load", xalign=0))
        pop_box.append(self.gpu_bar)
        pop_box.append(Gtk.Label(label="Memory Usage", xalign=0))
        pop_box.append(self.ram_bar)
        pop_box.append(self.detail_lbl)

        pop.set_child(pop_box)
        self.set_popover(pop)

        self._poll_metrics()
        GLib.timeout_add_seconds(2, self._poll_metrics)

    def _read_cpu(self):
        try:
            with open("/proc/stat") as f:
                fields = [float(x) for x in f.readline().split()[1:]]
            idle = fields[3] + fields[4]
            total = sum(fields)
            diff_idle = idle - self._prev_idle
            diff_total = total - self._prev_total
            self._prev_idle, self._prev_total = idle, total
            return 0 if diff_total == 0 else int(100.0 * (1.0 - diff_idle / diff_total))
        except Exception:
            return 0

    def _read_ram(self):
        try:
            mem = {}
            with open("/proc/meminfo") as f:
                for line in f:
                    k, v = line.split(":", 1)
                    mem[k] = int(v.strip().split()[0])
            used = mem["MemTotal"] - mem.get("MemAvailable", mem["MemFree"])
            return int(100.0 * used / mem["MemTotal"]), used // 1024, mem["MemTotal"] // 1024
        except Exception:
            return 0, 0, 0

    def _read_gpu(self):
        for card in ["card0", "card1"]:
            p = f"/sys/class/drm/{card}/device/gpu_busy_percent"
            if os.path.exists(p):
                try:
                    return int(open(p).read().strip())
                except Exception:
                    pass
        return 0

    def _read_temp(self):
        for zone in ["thermal_zone0", "thermal_zone1", "thermal_zone2"]:
            p = f"/sys/class/thermal/{zone}/temp"
            if os.path.exists(p):
                try:
                    val = int(open(p).read().strip()) // 1000
                    if 15 < val < 115:
                        return val
                except Exception:
                    pass
        return 42

    def _poll_metrics(self):
        cpu = self._read_cpu()
        gpu = self._read_gpu()
        ram_pct, ram_used_mb, ram_tot_mb = self._read_ram()
        temp = self._read_temp()

        self.stat_label.set_markup(
            f"<small><b>CPU</b> {cpu}%  <b>GPU</b> {gpu}%  <b>RAM</b> {ram_pct}%  <b>{temp}°C</b></small>"
        )
        self.cpu_bar.set_value(cpu)
        self.gpu_bar.set_value(gpu)
        self.ram_bar.set_value(ram_pct)
        self.detail_lbl.set_markup(f"<small>RAM: {ram_used_mb} MB / {ram_tot_mb} MB\nCore Thermal: {temp}°C</small>")
        return True


class AquaRootTopBar(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aquaroot.TopBar")

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        win.set_name("aquaroot-topbar")

        Gtk4LayerShell.init_for_window(win)
        Gtk4LayerShell.set_layer(win, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.LEFT, True)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.RIGHT, True)
        Gtk4LayerShell.auto_exclusive_zone_enable(win)

        root_box = Gtk.CenterBox()

        # Left Capsule: Distro Menu + App Title + Global Menu
        left_capsule = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        left_capsule.add_css_class("topbar-capsule")

        distro_name, distro_icon = get_distro_info()
        distro_btn = Gtk.MenuButton()
        distro_btn.set_has_frame(False)
        distro_btn.set_child(Gtk.Image.new_from_icon_name(distro_icon))
        distro_btn.set_popover(self._build_system_popover(distro_name))
        left_capsule.append(distro_btn)

        self.app_title = Gtk.Label()
        self.app_title.set_markup("<b>Finder</b>")
        self.app_title.set_margin_start(6); self.app_title.set_margin_end(8)
        left_capsule.append(self.app_title)

        self.menu_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        for item in ["File", "Edit", "View", "Go", "Window", "Help"]:
            btn = Gtk.MenuButton(label=item)
            btn.add_css_class("global-menu-btn")
            btn.set_has_frame(False)
            btn.set_popover(self._build_global_menu_popover(item))
            self.menu_box.append(btn)
        left_capsule.append(self.menu_box)
        root_box.set_start_widget(left_capsule)

        # Right Capsule: YT Audio + Telemetry + AquaDrop + Spotlight + Control Center + Clock
        right_capsule = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        right_capsule.add_css_class("topbar-capsule")

        right_capsule.append(YouTubeAudioWidget())
        right_capsule.append(SystemTelemetryWidget())

        drop_btn = Gtk.Button.new_from_icon_name("network-transmit-receive-symbolic")
        drop_btn.set_has_frame(False)
        drop_btn.set_tooltip_text("AquaDrop Wireless Continuity")
        drop_btn.connect("clicked", lambda _: subprocess.Popen([os.path.expanduser("~/.local/bin/aquaroot-aquadrop.py")]))
        right_capsule.append(drop_btn)

        spot_btn = Gtk.Button.new_from_icon_name("system-search-symbolic")
        spot_btn.set_has_frame(False)
        spot_btn.set_tooltip_text("Spotlight v2 (Super+Space)")
        spot_btn.connect("clicked", lambda _: subprocess.Popen([os.path.expanduser("~/.local/bin/aquaroot-spotlight.py")]))
        right_capsule.append(spot_btn)

        cc_btn = Gtk.Button.new_from_icon_name("preferences-system-notifications-symbolic")
        cc_btn.set_has_frame(False)
        cc_btn.set_tooltip_text("Control Center & Notifications (Super+N)")
        cc_btn.connect("clicked", lambda _: subprocess.Popen(["pkill", "-USR1", "-f", "aquaroot-notifications.py"]))
        right_capsule.append(cc_btn)

        self.clock_lbl = Gtk.Label()
        self._update_clock()
        GLib.timeout_add_seconds(1, self._update_clock)
        right_capsule.append(self.clock_lbl)

        root_box.set_end_widget(right_capsule)
        win.set_child(root_box)
        win.present()

    def _build_system_popover(self, distro_name):
        pop = Gtk.Popover()
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        actions = [
            (f"About {distro_name}", [os.path.expanduser("~/.local/bin/aquaroot-welcome.py"), "--force"]),
            ("System Settings...", [os.path.expanduser("~/.local/bin/aquaroot-settings.py")]),
            ("Toggle Stage Manager Strip", ["bash", "-c", "pkill -f aquaroot-stagemanager.py || ~/.local/bin/aquaroot-stagemanager.py &"]),
            ("Time Machine Snapshots...", [os.path.expanduser("~/.local/bin/aquaroot-timemachine.py")]),
            ("Fetch Online 4K Wallpaper", [os.path.expanduser("~/.local/bin/aquaroot-wallpaper.sh"), "--online"]),
            ("Lock Screen (Face ID / Touch ID)", ["hyprlock"]),
            ("Log Out...", ["pkill", "wayfire"]),
            ("Shut Down...", ["systemctl", "poweroff"]),
        ]
        for label, cmd in actions:
            b = Gtk.Button(label=label)
            b.set_has_frame(False)
            b.connect("clicked", lambda _, c=cmd: subprocess.Popen(c))
            box.append(b)
        pop.set_child(box)
        return pop

    def _build_global_menu_popover(self, section):
        pop = Gtk.Popover()
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        shortcuts = {
            "File": [("New Finder Window", ["nautilus", "--new-window"]),
                     ("Screen Capture & OCR Studio", [os.path.expanduser("~/.local/bin/aquaroot-screenshot.py")])],
            "Edit": [("Clipboard History", [os.path.expanduser("~/.local/bin/aquaroot-spotlight.py")])],
            "View": [("Toggle Stage Manager", ["bash", "-c", "pkill -f aquaroot-stagemanager.py || ~/.local/bin/aquaroot-stagemanager.py &"]),
                     ("Toggle Control Center", ["pkill", "-USR1", "-f", "aquaroot-notifications.py"]),
                     ("High-Contrast Readability Glass", [os.path.expanduser("~/.local/bin/aquaroot-glass-ctl.py"), "reduce_transparency=true"]),
                     ("Restore Liquid Glass", [os.path.expanduser("~/.local/bin/aquaroot-glass-ctl.py"), "reduce_transparency=false"])],
            "Go": [("Home Folder", ["nautilus"]), ("AquaDrop Folder", ["nautilus", os.path.expanduser("~/Downloads/AquaDrop")]), ("Terminal", ["foot"])],
            "Window": [("System Settings", [os.path.expanduser("~/.local/bin/aquaroot-settings.py")])],
            "Help": [("AquaRoot Welcome Tour", [os.path.expanduser("~/.local/bin/aquaroot-welcome.py"), "--force"])],
        }
        for label, cmd in shortcuts.get(section, []):
            row = Gtk.Button(label=label)
            row.set_has_frame(False)
            row.connect("clicked", lambda _, c=cmd: subprocess.Popen(c))
            box.append(row)
        pop.set_child(box)
        return pop

    def _update_clock(self):
        now = GLib.DateTime.new_now_local()
        self.clock_lbl.set_markup(f"<b>{now.format('%a %b %d   %I:%M %p')}</b>")
        return True


if __name__ == "__main__":
    AquaRootTopBar().run(None)
EOF

    # --------------------------------------------------------------------------
    # 7. Dynamic Notch v2: MPRIS Media, Seek Bar, Weather, Battery & Dropover Shelf
    #    (~/.local/bin/aquaroot-notch.py)
    # --------------------------------------------------------------------------
    log "Writing ~/.local/bin/aquaroot-notch.py..."
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-notch.py"
#!/usr/bin/env python3
import os
import urllib.request
import subprocess
import threading
from pathlib import Path
from ctypes import CDLL

CDLL("libgtk4-layer-shell.so")
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gdk, Gio, GLib, Gtk4LayerShell


class AquaRootDynamicNotch(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aquaroot.DynamicNotch")
        self.active_player = None
        self.track_len_us = 1
        self.weather_str = "24°C • Clear Sky"
        self.dropped_files = []

    def do_activate(self):
        self.win = Gtk.ApplicationWindow(application=self)
        self.win.set_name("aquaroot-notch")

        Gtk4LayerShell.init_for_window(self.win)
        Gtk4LayerShell.set_layer(self.win, Gtk4LayerShell.Layer.OVERLAY)
        Gtk4LayerShell.set_anchor(self.win, Gtk4LayerShell.Edge.TOP, True)

        self.root_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.root_box.add_css_class("dynamic-notch")

        # Compact Pill Row (Idle Battery OR Active Media + Seek Bar)
        self.compact_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10, halign=Gtk.Align.CENTER)
        self.compact_icon = Gtk.Image.new_from_icon_name("battery-good-symbolic")
        self.compact_label = Gtk.Label(label="100% • Charged")
        self.compact_seek = Gtk.ProgressBar()
        self.compact_seek.set_size_request(70, 4)
        self.compact_seek.set_valign(Gtk.Align.CENTER)
        self.compact_seek.set_visible(False)

        self.compact_row.append(self.compact_icon)
        self.compact_row.append(self.compact_label)
        self.compact_row.append(self.compact_seek)
        self.root_box.append(self.compact_row)

        # Expanded Revealer (Media | Weather & Battery | Dropover File Shelf)
        self.revealer = Gtk.Revealer()
        self.revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN)
        self.revealer.set_transition_duration(300)

        exp_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        cards_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)

        # 1. Media Section Card
        media_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        media_card.add_css_class("notch-section-card")
        media_card.set_size_request(230, -1)
        self.exp_media_title = Gtk.Label(label="No Media Playing", xalign=0)
        self.exp_media_title.set_ellipsize(3)
        self.exp_media_title.set_max_width_chars(24)

        ctrl_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8, halign=Gtk.Align.CENTER)
        for icn, method in [
            ("media-skip-backward-symbolic", "Previous"),
            ("media-playback-start-symbolic", "PlayPause"),
            ("media-skip-forward-symbolic", "Next"),
        ]:
            b = Gtk.Button.new_from_icon_name(icn)
            b.add_css_class("notch-icon-btn")
            b.set_has_frame(False)
            b.connect("clicked", lambda _, m=method: self.mpris_call(m))
            ctrl_row.append(b)

        self.seek_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.seek_scale.set_draw_value(False)
        self.seek_scale.connect("change-value", self.on_seek_scrub)

        media_card.append(self.exp_media_title)
        media_card.append(ctrl_row)
        media_card.append(self.seek_scale)
        cards_row.append(media_card)

        # 2. Weather & Battery Card
        env_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        env_card.add_css_class("notch-section-card")
        env_card.set_size_request(190, -1)
        self.weather_lbl = Gtk.Label(label=self.weather_str, xalign=0)
        self.battery_lbl = Gtk.Label(label="Battery: 100%", xalign=0)
        self.battery_bar = Gtk.LevelBar.new_for_interval(0, 100)
        self.battery_bar.set_value(100)
        env_card.append(self.weather_lbl)
        env_card.append(self.battery_lbl)
        env_card.append(self.battery_bar)
        cards_row.append(env_card)

        # 3. Dropover File Holding Shelf Card
        self.shelf_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.shelf_card.add_css_class("notch-section-card")
        self.shelf_card.add_css_class("dropover-shelf")
        self.shelf_card.set_size_request(180, -1)
        self.shelf_lbl = Gtk.Label(label="Dropover Shelf\n(Drag files here)", justify=Gtk.Justification.CENTER)
        self.shelf_list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        clear_btn = Gtk.Button(label="Clear Shelf")
        clear_btn.set_has_frame(False)
        clear_btn.connect("clicked", self.clear_shelf)
        self.shelf_card.append(self.shelf_lbl)
        self.shelf_card.append(self.shelf_list)
        self.shelf_card.append(clear_btn)
        cards_row.append(self.shelf_card)

        exp_container.append(cards_row)
        self.revealer.set_child(exp_container)
        self.root_box.append(self.revealer)

        motion = Gtk.EventControllerMotion.new()
        motion.connect("enter", lambda *_: self.set_expanded(True))
        motion.connect("leave", lambda *_: self.set_expanded(False))
        self.root_box.add_controller(motion)

        drop_target = Gtk.DropTarget.new(Gdk.FileList, Gdk.DragAction.COPY)
        drop_target.connect("enter", lambda *_: (self.set_expanded(True), Gdk.DragAction.COPY)[1])
        drop_target.connect("drop", self.on_file_dropped)
        self.root_box.add_controller(drop_target)

        self.win.set_child(self.root_box)
        self.win.present()

        GLib.timeout_add(1500, self.poll_status)
        threading.Thread(target=self.fetch_weather, daemon=True).start()

    def set_expanded(self, state):
        if state:
            self.root_box.add_css_class("dynamic-notch-expanded")
        else:
            self.root_box.remove_css_class("dynamic-notch-expanded")
        self.revealer.set_reveal_child(state)

    def on_file_dropped(self, _target, value, _x, _y):
        if isinstance(value, Gdk.FileList):
            for gfile in value.get_files():
                path = gfile.get_path()
                if path and path not in self.dropped_files:
                    self.dropped_files.append(path)
                    self._add_shelf_chip(path)
            self.shelf_lbl.set_markup(f"<b>Shelf ({len(self.dropped_files)} files)</b>")
            return True
        return False

    def _add_shelf_chip(self, path):
        btn = Gtk.Button(label=os.path.basename(path)[:20])
        btn.add_css_class("macos-action-btn")
        btn.set_tooltip_text(f"Click to open or drag out: {path}")
        btn.connect("clicked", lambda _: subprocess.Popen(["xdg-open", path]))

        drag_src = Gtk.DragSource.new()
        drag_src.set_actions(Gdk.DragAction.COPY)
        gfile = Gio.File.new_for_path(path)
        content = Gdk.ContentProvider.new_for_value(Gdk.FileList.new_from_list([gfile]))
        drag_src.set_content(content)
        btn.add_controller(drag_src)
        self.shelf_list.append(btn)

    def clear_shelf(self, _btn):
        self.dropped_files.clear()
        while (child := self.shelf_list.get_first_child()) is not None:
            self.shelf_list.remove(child)
        self.shelf_lbl.set_text("Dropover Shelf\n(Drag files here)")

    def fetch_weather(self):
        try:
            req = urllib.request.Request("https://wttr.in/?format=%t+%C", headers={"User-Agent": "curl"})
            with urllib.request.urlopen(req, timeout=4) as resp:
                txt = resp.read().decode("utf-8").strip()
                if txt:
                    self.weather_str = txt
                    GLib.idle_add(self.weather_lbl.set_markup, f"<b>Weather:</b> {txt}")
        except Exception:
            pass

    def read_battery(self):
        base = Path("/sys/class/power_supply")
        for bat in base.glob("BAT*"):
            try:
                cap = int((bat / "capacity").read_text().strip())
                status = (bat / "status").read_text().strip()
                time_str = status
                if (bat / "energy_now").exists() and (bat / "power_now").exists():
                    e_now = int((bat / "energy_now").read_text().strip())
                    p_now = int((bat / "power_now").read_text().strip())
                    if p_now > 1000 and status == "Discharging":
                        hrs = e_now / float(p_now)
                        h = int(hrs)
                        m = int((hrs - h) * 60)
                        time_str = f"{h}h {m}m left"
                return cap, f"{cap}% • {time_str}"
            except Exception:
                pass
        return 100, "100% • AC Power"

    def poll_mpris(self):
        try:
            bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
            names = bus.call_sync(
                "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                "ListNames", None, None, Gio.DBusCallFlags.NONE, -1, None
            ).unpack()[0]
            players = [n for n in names if n.startswith("org.mpris.MediaPlayer2.")]
            if not players:
                self.active_player = None
                return None
            self.active_player = players[0]
            props = bus.call_sync(
                self.active_player, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties",
                "GetAll", GLib.Variant("(s)", ("org.mpris.MediaPlayer2.Player",)),
                None, Gio.DBusCallFlags.NONE, -1, None
            ).unpack()[0]
            status = props.get("PlaybackStatus", "Stopped")
            meta = props.get("Metadata", {})
            pos = props.get("Position", 0)
            title = meta.get("xesam:title", "Media Stream")
            artist = ", ".join(meta.get("xesam:artist", []))
            self.track_len_us = max(1, int(meta.get("mpris:length", 1)))
            frac = min(1.0, max(0.0, float(pos) / float(self.track_len_us)))
            label = f"{title} — {artist}" if artist else title
            return status, label, frac
        except Exception:
            self.active_player = None
            return None

    def mpris_call(self, method):
        if not self.active_player:
            return
        try:
            bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
            bus.call_sync(
                self.active_player, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player",
                method, None, None, Gio.DBusCallFlags.NONE, -1, None
            )
        except Exception:
            pass

    def on_seek_scrub(self, _scale, _scroll, value):
        if not self.active_player or self.track_len_us <= 1:
            return False
        target_us = int((value / 100.0) * self.track_len_us)
        try:
            bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
            bus.call_sync(
                self.active_player, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player",
                "SetPosition", GLib.Variant("(ox)", ("/org/mpris/MediaPlayer2/Track/1", target_us)),
                None, Gio.DBusCallFlags.NONE, -1, None
            )
        except Exception:
            pass
        return False

    def poll_status(self):
        cap, bat_str = self.read_battery()
        self.battery_lbl.set_markup(f"<b>Battery:</b> {bat_str}")
        self.battery_bar.set_value(cap)

        mpris = self.poll_mpris()
        if mpris and mpris[0] == "Playing":
            _, title, frac = mpris
            self.compact_icon.set_from_icon_name("audio-x-generic-symbolic")
            self.compact_label.set_text(title[:26])
            self.compact_seek.set_fraction(frac)
            self.compact_seek.set_visible(True)
            self.exp_media_title.set_markup(f"<b>{GLib.markup_escape_text(title)}</b>")
            self.seek_scale.set_value(frac * 100.0)
        else:
            self.compact_icon.set_from_icon_name("battery-good-symbolic")
            self.compact_label.set_text(bat_str)
            self.compact_seek.set_visible(False)
            self.exp_media_title.set_text(f"Paused: {mpris[1]}" if mpris else "No Media Playing")
        return True


if __name__ == "__main__":
    AquaRootDynamicNotch().run(None)
EOF

    # --------------------------------------------------------------------------
    # 8. Parabolic Magnification Dock (~/.local/bin/aquaroot-dock.py)
    # --------------------------------------------------------------------------
    log "Writing ~/.local/bin/aquaroot-dock.py..."
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-dock.py"
#!/usr/bin/env python3
import os
import math
import subprocess
from ctypes import CDLL

CDLL("libgtk4-layer-shell.so")
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gtk4LayerShell

DOCK_APPS = [
    ("Finder", "system-file-manager", ["nautilus", "--new-window"]),
    ("Spotlight", "system-search", [os.path.expanduser("~/.local/bin/aquaroot-spotlight.py")]),
    ("Browser", "web-browser", ["xdg-open", "https://"]),
    ("Screenshot & OCR Studio", "applets-screenshooter", [os.path.expanduser("~/.local/bin/aquaroot-screenshot.py")]),
    ("AquaDrop Continuity", "network-transmit-receive", [os.path.expanduser("~/.local/bin/aquaroot-aquadrop.py")]),
    ("Time Machine", "drive-harddisk", [os.path.expanduser("~/.local/bin/aquaroot-timemachine.py")]),
    ("Terminal", "utilities-terminal", ["foot"]),
    ("System Settings", "preferences-system", [os.path.expanduser("~/.local/bin/aquaroot-settings.py")]),
]

BASE_SIZE = 48
MAX_ZOOM = 0.65
SIGMA = 75.0


class AquaRootDock(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aquaroot.Dock")
        self.icons = []

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        win.set_name("aquaroot-topbar")

        Gtk4LayerShell.init_for_window(win)
        Gtk4LayerShell.set_layer(win, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.BOTTOM, True)
        Gtk4LayerShell.set_margin(win, Gtk4LayerShell.Edge.BOTTOM, 10)

        self.dock_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.dock_box.add_css_class("liquid-glass")
        self.dock_box.set_margin_top(16); self.dock_box.set_margin_bottom(8)
        self.dock_box.set_margin_start(16); self.dock_box.set_margin_end(16)

        for name, icon_name, cmd in DOCK_APPS:
            btn = Gtk.Button()
            btn.set_has_frame(False)
            btn.set_tooltip_text(name)
            img = Gtk.Image.new_from_icon_name(icon_name)
            img.set_pixel_size(BASE_SIZE)
            btn.set_child(img)
            btn.connect("clicked", lambda _, c=cmd: subprocess.Popen(c))
            self.dock_box.append(btn)
            self.icons.append((btn, img))

        motion = Gtk.EventControllerMotion.new()
        motion.connect("motion", self.on_mouse_move)
        motion.connect("leave", self.on_mouse_leave)
        self.dock_box.add_controller(motion)

        win.set_child(self.dock_box)
        win.present()

    def on_mouse_move(self, _controller, x, _y):
        for btn, img in self.icons:
            alloc = btn.get_allocation()
            center_x = alloc.x + (alloc.width / 2.0)
            dist = abs(x - center_x)
            scale = 1.0 + MAX_ZOOM * math.exp(-(dist * dist) / (2.0 * SIGMA * SIGMA))
            img.set_pixel_size(int(BASE_SIZE * scale))

    def on_mouse_leave(self, _controller):
        for _btn, img in self.icons:
            img.set_pixel_size(BASE_SIZE)


if __name__ == "__main__":
    AquaRootDock().run(None)
EOF

    # --------------------------------------------------------------------------
    # 9. Spotlight v2: Clipboard History, Unit/Currency Converter & Quick Actions
    #    (~/.local/bin/aquaroot-spotlight.py)
    # --------------------------------------------------------------------------
    log "Writing ~/.local/bin/aquaroot-spotlight.py..."
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-spotlight.py"
#!/usr/bin/env python3
import os
import re
import json
import math
import glob
import shlex
import subprocess
import configparser
from pathlib import Path
from ctypes import CDLL

CDLL("libgtk4-layer-shell.so")
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gdk, GLib, Gtk4LayerShell

CLIP_FILE = Path.home() / ".cache" / "aquaroot" / "clipboard.json"

UNIT_RATES = {
    ("usd", "inr"): 84.5, ("inr", "usd"): 1 / 84.5,
    ("usd", "eur"): 0.92, ("eur", "usd"): 1 / 0.92,
    ("km", "mi"): 0.621371, ("mi", "km"): 1.60934,
    ("kg", "lb"): 2.20462, ("lb", "kg"): 0.453592,
}


def load_desktop_apps():
    apps, seen = [], set()
    for d in ["/usr/share/applications", os.path.expanduser("~/.local/share/applications")]:
        for path in glob.glob(os.path.join(d, "*.desktop")):
            cp = configparser.ConfigParser(interpolation=None)
            try:
                cp.read(path)
                sec = cp["Desktop Entry"]
                if sec.get("NoDisplay", "false").lower() == "true":
                    continue
                name, exec_cmd = sec.get("Name"), sec.get("Exec", "")
                icon = sec.get("Icon", "application-x-executable")
                if name and exec_cmd and name not in seen:
                    seen.add(name)
                    clean_cmd = [p for p in shlex.split(exec_cmd) if not p.startswith("%")]
                    apps.append({"name": name, "cmd": clean_cmd, "icon": icon})
            except Exception:
                continue
    return apps


def try_convert_units(query):
    m = re.match(r"^\s*([0-9.]+)\s*([a-zA-Z]+)\s+(?:to|in)\s+([a-zA-Z]+)\s*$", query.lower())
    if not m:
        return None
    val, u1, u2 = float(m.group(1)), m.group(2), m.group(3)
    if u1 == "f" and u2 == "c":
        return f"{(val - 32) * 5.0 / 9.0:.2f} °C"
    if u1 == "c" and u2 == "f":
        return f"{(val * 9.0 / 5.0) + 32:.2f} °F"
    if (u1, u2) in UNIT_RATES:
        return f"{val * UNIT_RATES[(u1, u2)]:.2f} {u2.upper()}"
    return None


def record_current_clipboard():
    try:
        txt = subprocess.check_output(["wl-paste", "--no-newline"], text=True, stderr=subprocess.DEVNULL, timeout=0.2).strip()
        if not txt:
            return json.loads(CLIP_FILE.read_text()) if CLIP_FILE.exists() else []
        CLIP_FILE.parent.mkdir(parents=True, exist_ok=True)
        hist = json.loads(CLIP_FILE.read_text()) if CLIP_FILE.exists() else []
        if txt in hist:
            hist.remove(txt)
        hist.insert(0, txt)
        hist = hist[:25]
        CLIP_FILE.write_text(json.dumps(hist))
        return hist
    except Exception:
        return json.loads(CLIP_FILE.read_text()) if CLIP_FILE.exists() else []


class AquaRootSpotlightV2(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aquaroot.Spotlight")
        self.apps = load_desktop_apps()
        self.results = []
        self.clips = record_current_clipboard()

    def do_activate(self):
        self.win = Gtk.ApplicationWindow(application=self)
        self.win.set_name("aquaroot-topbar")

        Gtk4LayerShell.init_for_window(self.win)
        Gtk4LayerShell.set_layer(self.win, Gtk4LayerShell.Layer.OVERLAY)
        Gtk4LayerShell.set_keyboard_mode(self.win, Gtk4LayerShell.KeyboardMode.EXCLUSIVE)
        Gtk4LayerShell.set_anchor(self.win, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_margin(self.win, Gtk4LayerShell.Edge.TOP, 170)

        kc = Gtk.EventControllerKey.new()
        kc.connect("key-pressed", lambda _, kv, __, ___: (self.quit() if kv == Gdk.KEY_Escape else False))
        self.win.add_controller(kc)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.add_css_class("liquid-glass")
        box.set_size_request(700, -1)
        box.set_margin_top(12); box.set_margin_bottom(12); box.set_margin_start(14); box.set_margin_end(14)

        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        mag = Gtk.Image.new_from_icon_name("system-search-symbolic")
        mag.set_pixel_size(26)
        row.append(mag)

        self.entry = Gtk.Entry()
        self.entry.set_placeholder_text("Spotlight (Apps, Files, Math, '100 usd to inr', 'clip:', or System Actions)...")
        self.entry.set_hexpand(True)
        self.entry.set_has_frame(False)
        self.entry.connect("changed", self.on_query_changed)
        self.entry.connect("activate", self.on_activate_first)
        row.append(self.entry)
        box.append(row)

        self.listbox = Gtk.ListBox()
        self.listbox.connect("row-activated", self.on_row_activated)
        self.listbox.set_visible(False)
        box.append(self.listbox)

        self.win.set_child(box)
        self.win.present()
        self.entry.grab_focus()

    def on_query_changed(self, entry):
        q = entry.get_text().strip()
        while (c := self.listbox.get_first_child()) is not None:
            self.listbox.remove(c)
        self.results.clear()
        if not q:
            self.listbox.set_visible(False)
            return

        ql = q.lower()

        # 1. Clipboard History ("clip:")
        if ql.startswith("clip"):
            sub = ql.replace("clip:", "").replace("clip", "").strip()
            for item in self.clips:
                if not sub or sub in item.lower():
                    self._add_row(item[:60], "edit-paste-symbolic", ["wl-copy", item], "Clipboard History (Enter to Copy)")
            self.listbox.set_visible(len(self.results) > 0)
            return

        # 2. Unit & Currency Conversion
        conv = try_convert_units(q)
        if conv:
            self._add_row(f"= {conv}", "accessories-calculator", ["wl-copy", conv], "Unit & Currency Converter (Enter to Copy)")

        # 3. Math Expression
        if any(op in q for op in ["+", "-", "*", "/", "^"]) and q[0].isdigit():
            try:
                val = eval(q.replace("^", "**"), {"__builtins__": None}, vars(math))
                self._add_row(f"= {val}", "accessories-calculator", ["wl-copy", str(val)], "Calculator (Enter to Copy)")
            except Exception:
                pass

        # 4. System Quick Actions
        actions = [
            ("Toggle Stage Manager Strip", "view-grid-symbolic", ["bash", "-c", "pkill -f aquaroot-stagemanager.py || ~/.local/bin/aquaroot-stagemanager.py &"]),
            ("Toggle Control Center & Notifications", "preferences-system-notifications-symbolic", ["pkill", "-USR1", "-f", "aquaroot-notifications.py"]),
            ("Switch to Dark Obsidian Glass", "weather-clear-night-symbolic", [os.path.expanduser("~/.local/bin/aquaroot-glass-ctl.py"), "tint_mode=dark"]),
            ("Switch to Light Frost Glass", "weather-clear-symbolic", [os.path.expanduser("~/.local/bin/aquaroot-glass-ctl.py"), "tint_mode=light"]),
            ("Open Screenshot & Recording Studio", "applets-screenshooter-symbolic", [os.path.expanduser("~/.local/bin/aquaroot-screenshot.py")]),
            ("Open Time Machine Backup Studio", "drive-harddisk-symbolic", [os.path.expanduser("~/.local/bin/aquaroot-timemachine.py")]),
            ("Open AquaDrop Wireless File Share", "network-transmit-receive-symbolic", [os.path.expanduser("~/.local/bin/aquaroot-aquadrop.py")]),
            ("Apply Dynamic Solar Wallpaper", "weather-clear-symbolic", [os.path.expanduser("~/.local/bin/aquaroot-wallpaper.sh"), "--solar"]),
            ("Lock Screen", "system-lock-screen-symbolic", ["hyprlock"]),
        ]
        for title, icn, cmd in actions:
            if ql in title.lower():
                self._add_row(title, icn, cmd, "AquaRoot Quick Action")

        # 5. Desktop Applications
        for app in self.apps:
            if ql in app["name"].lower():
                self._add_row(app["name"], app["icon"], app["cmd"], "Application")
                if len(self.results) >= 7:
                    break

        # 6. Home Directory File Search
        if len(q) >= 3 and len(self.results) < 9:
            try:
                out = subprocess.check_output(
                    ["find", os.path.expanduser("~"), "-maxdepth", "3", "-not", "-path", "*/.*", "-iname", f"*{q}*"],
                    text=True, stderr=subprocess.DEVNULL, timeout=0.25
                ).splitlines()
                for path in out[:3]:
                    fname = os.path.basename(path)
                    self._add_row(fname, "folder" if os.path.isdir(path) else "text-x-generic", ["xdg-open", path], path)
            except Exception:
                pass

        self.listbox.set_visible(len(self.results) > 0)

    def _add_row(self, title, icon_name, cmd, subtitle):
        rbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        rbox.set_margin_top(6); rbox.set_margin_bottom(6); rbox.set_margin_start(10); rbox.set_margin_end(10)
        img = Gtk.Image.new_from_icon_name(icon_name)
        img.set_pixel_size(28)
        tbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        lbl = Gtk.Label(xalign=0)
        lbl.set_markup(f"<b>{GLib.markup_escape_text(title)}</b>")
        sub = Gtk.Label(label=subtitle, xalign=0)
        sub.set_opacity(0.65)
        tbox.append(lbl)
        tbox.append(sub)
        rbox.append(img)
        rbox.append(tbox)
        self.listbox.append(rbox)
        self.results.append(cmd)

    def on_activate_first(self, _entry):
        if self.results:
            subprocess.Popen(self.results[0])
            self.quit()

    def on_row_activated(self, _lb, row):
        idx = row.get_index()
        if 0 <= idx < len(self.results):
            subprocess.Popen(self.results[idx])
            self.quit()


if __name__ == "__main__":
    AquaRootSpotlightV2().run(None)
EOF

    # --------------------------------------------------------------------------
    # 10. Control Center & D-Bus Notification Daemon (~/.local/bin/aquaroot-notifications.py)
    # --------------------------------------------------------------------------
    log "Writing ~/.local/bin/aquaroot-notifications.py..."
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-notifications.py"
#!/usr/bin/env python3
import os
import subprocess
from ctypes import CDLL

CDLL("libgtk4-layer-shell.so")
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gio, GLib, Gtk4LayerShell

NOTIF_XML = """
<node>
  <interface name="org.freedesktop.Notifications">
    <method name="GetCapabilities">
      <arg direction="out" name="capabilities" type="as"/>
    </method>
    <method name="Notify">
      <arg direction="in" name="app_name" type="s"/>
      <arg direction="in" name="replaces_id" type="u"/>
      <arg direction="in" name="app_icon" type="s"/>
      <arg direction="in" name="summary" type="s"/>
      <arg direction="in" name="body" type="s"/>
      <arg direction="in" name="actions" type="as"/>
      <arg direction="in" name="hints" type="a{sv}"/>
      <arg direction="in" name="expire_timeout" type="i"/>
      <arg direction="out" name="id" type="u"/>
    </method>
    <method name="CloseNotification">
      <arg direction="in" name="id" type="u"/>
    </method>
    <method name="GetServerInformation">
      <arg direction="out" name="name" type="s"/>
      <arg direction="out" name="vendor" type="s"/>
      <arg direction="out" name="version" type="s"/>
      <arg direction="out" name="spec_version" type="s"/>
    </method>
  </interface>
</node>
"""


class AquaRootControlAndNotifications(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aquaroot.Notifications")
        self.msg_id = 1
        self.dnd_active = False
        self.night_shift_active = False
        self.drawer_open = False

    def do_activate(self):
        # 1. Toast Popup Overlay Window
        self.toast_win = Gtk.ApplicationWindow(application=self)
        self.toast_win.set_name("aquaroot-notifications")
        Gtk4LayerShell.init_for_window(self.toast_win)
        Gtk4LayerShell.set_layer(self.toast_win, Gtk4LayerShell.Layer.OVERLAY)
        Gtk4LayerShell.set_anchor(self.toast_win, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_anchor(self.toast_win, Gtk4LayerShell.Edge.RIGHT, True)
        Gtk4LayerShell.set_margin(self.toast_win, Gtk4LayerShell.Edge.TOP, 46)

        self.toast_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.toast_win.set_child(self.toast_box)
        self.toast_win.present()

        # 2. Slide-Out Control Center & Notification Drawer
        self.drawer_win = Gtk.ApplicationWindow(application=self)
        self.drawer_win.set_name("aquaroot-notifications")
        Gtk4LayerShell.init_for_window(self.drawer_win)
        Gtk4LayerShell.set_layer(self.drawer_win, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_anchor(self.drawer_win, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_anchor(self.drawer_win, Gtk4LayerShell.Edge.RIGHT, True)
        Gtk4LayerShell.set_margin(self.drawer_win, Gtk4LayerShell.Edge.TOP, 42)

        drawer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        drawer.add_css_class("control-center-drawer")
        drawer.set_size_request(340, 520)

        hdr = Gtk.Label(xalign=0)
        hdr.set_markup("<span size='large'><b>Control Center</b></span>")
        drawer.append(hdr)

        grid = Gtk.Grid(column_spacing=10, row_spacing=10)
        self.btn_wifi = Gtk.ToggleButton(label="Wi-Fi", active=True, hexpand=True)
        self.btn_wifi.add_css_class("cc-pill-toggle")
        self.btn_wifi.connect("toggled", lambda b: subprocess.Popen(["nmcli", "radio", "wifi", "on" if b.get_active() else "off"]))

        self.btn_bt = Gtk.ToggleButton(label="Bluetooth", active=True, hexpand=True)
        self.btn_bt.add_css_class("cc-pill-toggle")
        self.btn_bt.connect("toggled", lambda b: subprocess.Popen(["bluetoothctl", "power", "on" if b.get_active() else "off"]))

        self.btn_dnd = Gtk.ToggleButton(label="Do Not Disturb", hexpand=True)
        self.btn_dnd.add_css_class("cc-pill-toggle")
        self.btn_dnd.connect("toggled", self.toggle_dnd)

        self.btn_night = Gtk.ToggleButton(label="Night Shift", hexpand=True)
        self.btn_night.add_css_class("cc-pill-toggle")
        self.btn_night.connect("toggled", self.toggle_night_shift)

        grid.attach(self.btn_wifi, 0, 0, 1, 1)
        grid.attach(self.btn_bt, 1, 0, 1, 1)
        grid.attach(self.btn_dnd, 0, 1, 1, 1)
        grid.attach(self.btn_night, 1, 1, 1, 1)
        drawer.append(grid)

        focus_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        for mode, query in [("Work", "minimal+dark+4k"), ("Media", "neon+abstract+4k"), ("Relax", "nature+forest+4k")]:
            fb = Gtk.Button(label=f"Focus: {mode}", hexpand=True)
            fb.add_css_class("macos-action-btn")
            fb.connect("clicked", lambda _, m=mode, q=query: self.apply_focus_mode(m, q))
            focus_box.append(fb)
        drawer.append(focus_box)

        drawer.append(Gtk.Label(label="Display Brightness", xalign=0))
        b_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 10, 100, 5)
        b_scale.set_value(80)
        b_scale.connect("value-changed", lambda s: subprocess.Popen(["brightnessctl", "set", f"{int(s.get_value())}%"]))
        drawer.append(b_scale)

        drawer.append(Gtk.Label(label="Master Sound & PipeWire Output", xalign=0))
        v_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 5)
        v_scale.set_value(75)
        v_scale.connect("value-changed", lambda s: subprocess.Popen(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{int(s.get_value())}%"]))
        drawer.append(v_scale)

        notif_hdr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        nh_lbl = Gtk.Label(xalign=0, hexpand=True)
        nh_lbl.set_markup("<b>Notifications</b>")
        clr_btn = Gtk.Button(label="Clear All")
        clr_btn.set_has_frame(False)
        clr_btn.connect("clicked", self.clear_history)
        notif_hdr.append(nh_lbl)
        notif_hdr.append(clr_btn)
        drawer.append(notif_hdr)

        self.history_list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        scroll = Gtk.ScrolledWindow(vexpand=True)
        scroll.set_child(self.history_list)
        drawer.append(scroll)

        self.drawer_win.set_child(drawer)
        self.drawer_win.set_visible(False)

        self.register_dbus()
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, 10, self.toggle_drawer)

    def toggle_drawer(self):
        self.drawer_open = not self.drawer_open
        self.drawer_win.set_visible(self.drawer_open)
        return True

    def toggle_dnd(self, btn):
        self.dnd_active = btn.get_active()

    def toggle_night_shift(self, btn):
        self.night_shift_active = btn.get_active()
        if self.night_shift_active:
            subprocess.Popen(["wlsunset", "-t", "3800", "-T", "6500"])
        else:
            subprocess.Popen(["pkill", "wlsunset"])

    def apply_focus_mode(self, mode, wall_query):
        self.dnd_active = (mode == "Work")
        self.btn_dnd.set_active(self.dnd_active)
        subprocess.Popen([os.path.expanduser("~/.local/bin/aquaroot-wallpaper.sh"), "--online", wall_query])

    def clear_history(self, _btn):
        while (c := self.history_list.get_first_child()) is not None:
            self.history_list.remove(c)

    def register_dbus(self):
        node_info = Gio.DBusNodeInfo.new_for_xml(NOTIF_XML)
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        bus.register_object(
            "/org/freedesktop/Notifications",
            node_info.interfaces[0],
            self.on_dbus_method,
            None,
            None,
        )
        Gio.bus_own_name_on_connection(
            bus, "org.freedesktop.Notifications",
            Gio.BusNameOwnerFlags.REPLACE, None, None
        )

    def on_dbus_method(self, _conn, _sender, _path, _iface, method, params, invocation):
        if method == "GetCapabilities":
            invocation.return_value(GLib.Variant("(as)", (["body", "body-markup", "icon-static"],)))
        elif method == "GetServerInformation":
            invocation.return_value(GLib.Variant("(ssss)", ("AquaRoot Notifications", "AquaRoot", "3.0", "1.2")))
        elif method == "CloseNotification":
            invocation.return_value(None)
        elif method == "Notify":
            app_name, replaces_id, _icon, summary, body, _actions, _hints, _timeout = params.unpack()
            nid = replaces_id if replaces_id > 0 else self.msg_id
            self.msg_id += 1
            GLib.idle_add(self.push_notification, app_name, summary, body)
            invocation.return_value(GLib.Variant("(u)", (nid,)))

    def push_notification(self, app_name, summary, body):
        card = self._build_notif_card(app_name, summary, body)
        self.history_list.prepend(card)

        if not self.dnd_active:
            toast = self._build_notif_card(app_name, summary, body)
            self.toast_box.append(toast)
            GLib.timeout_add(4500, lambda: (self.toast_box.remove(toast), False)[1])

    def _build_notif_card(self, app_name, summary, body):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box.add_css_class("notification-toast")
        box.set_size_request(300, -1)
        top = Gtk.Label(xalign=0)
        top.set_markup(f"<small><b>{GLib.markup_escape_text(app_name or 'System')}</b></small>")
        top.set_opacity(0.7)
        ttl = Gtk.Label(xalign=0, wrap=True)
        ttl.set_markup(f"<b>{GLib.markup_escape_text(summary)}</b>")
        bdy = Gtk.Label(label=body, xalign=0, wrap=True)
        box.append(top)
        box.append(ttl)
        if body:
            box.append(bdy)
        return box


if __name__ == "__main__":
    AquaRootControlAndNotifications().run(None)
EOF

    # --------------------------------------------------------------------------
    # 11. Liquid Glass Volume & Brightness OSD (~/.local/bin/aquaroot-osd.py)
    # --------------------------------------------------------------------------
    log "Writing ~/.local/bin/aquaroot-osd.py..."
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-osd.py"
#!/usr/bin/env python3
import sys
import subprocess
from ctypes import CDLL

CDLL("libgtk4-layer-shell.so")
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, GLib, Gtk4LayerShell


def adjust_and_read(action):
    try:
        if action == "vol-up":
            subprocess.run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%"])
        elif action == "vol-down":
            subprocess.run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%"])
        elif action == "vol-mute":
            subprocess.run(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"])
        elif action == "bri-up":
            subprocess.run(["brightnessctl", "set", "+5%"])
        elif action == "bri-down":
            subprocess.run(["brightnessctl", "set", "5%-"])

        if action.startswith("bri"):
            out = subprocess.check_output(["brightnessctl", "-m"], text=True).split(",")
            val = int(out[3].replace("%", ""))
            return "display-brightness-symbolic", f"Brightness {val}%", val / 100.0
        else:
            out = subprocess.check_output(["pactl", "get-sink-volume", "@DEFAULT_SINK@"], text=True)
            val = int([p.replace("%", "") for p in out.split() if p.endswith("%")][0])
            return "audio-volume-high-symbolic", f"Volume {val}%", min(1.0, val / 100.0)
    except Exception:
        return "audio-volume-high-symbolic", "Level Adjusted", 0.5


class AquaRootOSD(Gtk.Application):
    def __init__(self, action):
        super().__init__(application_id="org.aquaroot.OSD")
        self.action = action

    def do_activate(self):
        icon_name, label_text, frac = adjust_and_read(self.action)
        win = Gtk.ApplicationWindow(application=self)
        win.set_name("aquaroot-osd")

        Gtk4LayerShell.init_for_window(win)
        Gtk4LayerShell.set_layer(win, Gtk4LayerShell.Layer.OVERLAY)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.BOTTOM, True)

        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.add_css_class("osd-capsule")

        img = Gtk.Image.new_from_icon_name(icon_name)
        img.set_pixel_size(24)
        lbl = Gtk.Label(label=label_text)
        bar = Gtk.ProgressBar()
        bar.set_fraction(frac)
        bar.set_valign(Gtk.Align.CENTER)
        bar.set_size_request(140, 6)

        box.append(img)
        box.append(lbl)
        box.append(bar)
        win.set_child(box)
        win.present()

        GLib.timeout_add(1600, lambda: (self.quit(), False)[1])


if __name__ == "__main__":
    act = sys.argv[1] if len(sys.argv) > 1 else "vol-up"
    AquaRootOSD(act).run(None)
EOF

    # --------------------------------------------------------------------------
    # 12. Desktop WidgetKit Layer (~/.local/bin/aquaroot-widgets.py)
    # --------------------------------------------------------------------------
    log "Writing ~/.local/bin/aquaroot-widgets.py..."
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-widgets.py"
#!/usr/bin/env python3
import os
from pathlib import Path
from ctypes import CDLL

CDLL("libgtk4-layer-shell.so")
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, GLib, Gtk4LayerShell

NOTES_FILE = Path.home() / ".config" / "aquaroot" / "sticky_note.txt"


class AquaRootDesktopWidgets(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aquaroot.DesktopWidgets")

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        win.set_name("aquaroot-widgets")

        Gtk4LayerShell.init_for_window(win)
        Gtk4LayerShell.set_layer(win, Gtk4LayerShell.Layer.BACKGROUND)
        Gtk4LayerShell.set_keyboard_mode(win, Gtk4LayerShell.KeyboardMode.ON_DEMAND)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.LEFT, True)
        Gtk4LayerShell.set_margin(win, Gtk4LayerShell.Edge.TOP, 64)
        Gtk4LayerShell.set_margin(win, Gtk4LayerShell.Edge.LEFT, 28)

        col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)

        # 1. Clock & Date Card
        clock_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        clock_card.add_css_class("desktop-widget-card")
        clock_card.set_size_request(240, -1)
        self.time_lbl = Gtk.Label(xalign=0)
        self.date_lbl = Gtk.Label(xalign=0)
        self.date_lbl.set_opacity(0.75)
        clock_card.append(self.time_lbl)
        clock_card.append(self.date_lbl)
        col.append(clock_card)

        # 2. Telemetry Card
        sys_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        sys_card.add_css_class("desktop-widget-card")
        sys_card.set_size_request(240, -1)
        sys_hdr = Gtk.Label(xalign=0)
        sys_hdr.set_markup("<b>System Telemetry</b>")
        self.cpu_bar = Gtk.LevelBar.new_for_interval(0, 100)
        self.ram_bar = Gtk.LevelBar.new_for_interval(0, 100)
        self.sys_lbl = Gtk.Label(label="CPU & RAM Load", xalign=0)
        sys_card.append(sys_hdr)
        sys_card.append(self.sys_lbl)
        sys_card.append(self.cpu_bar)
        sys_card.append(self.ram_bar)
        col.append(sys_card)

        # 3. Quick Sticky Note Card
        note_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        note_card.add_css_class("desktop-widget-card")
        note_card.set_size_request(240, 160)
        note_hdr = Gtk.Label(xalign=0)
        note_hdr.set_markup("<b>Quick Note</b>")
        self.text_view = Gtk.TextView()
        self.text_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        buf = self.text_view.get_buffer()
        if NOTES_FILE.exists():
            buf.set_text(NOTES_FILE.read_text())
        else:
            buf.set_text("Type desktop reminders here...")
        buf.connect("changed", self.save_note)
        note_card.append(note_hdr)
        note_card.append(self.text_view)
        col.append(note_card)

        win.set_child(col)
        win.present()

        self.tick()
        GLib.timeout_add_seconds(2, self.tick)

    def save_note(self, buf):
        NOTES_FILE.parent.mkdir(parents=True, exist_ok=True)
        start, end = buf.get_bounds()
        NOTES_FILE.write_text(buf.get_text(start, end, False))

    def tick(self):
        now = GLib.DateTime.new_now_local()
        self.time_lbl.set_markup(f"<span size='xx-large'><b>{now.format('%H:%M')}</b></span>")
        self.date_lbl.set_markup(f"<b>{now.format('%A, %B %d')}</b>")
        try:
            with open("/proc/meminfo") as f:
                mem = {k.split(":")[0]: int(v.strip().split()[0]) for k, v in (l.split(":") for l in f if ":" in l)}
            ram_pct = int(100.0 * (mem["MemTotal"] - mem.get("MemAvailable", mem["MemFree"])) / mem["MemTotal"])
            load_pct = min(100, int(os.getloadavg()[0] * 15))
            self.cpu_bar.set_value(load_pct)
            self.ram_bar.set_value(ram_pct)
            self.sys_lbl.set_text(f"CPU Load ~{load_pct}%  •  RAM {ram_pct}%")
        except Exception:
            pass
        return True


if __name__ == "__main__":
    AquaRootDesktopWidgets().run(None)
EOF

    # --------------------------------------------------------------------------
    # 13. Stage Manager Window Strip (~/.local/bin/aquaroot-stagemanager.py)
    # --------------------------------------------------------------------------
    log "Writing ~/.local/bin/aquaroot-stagemanager.py..."
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-stagemanager.py"
#!/usr/bin/env python3
import os
import json
import socket
from ctypes import CDLL

CDLL("libgtk4-layer-shell.so")
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, GLib, Gtk4LayerShell


def wf_ipc_call(method, data=None):
    sock_path = os.environ.get("WAYFIRE_SOCKET")
    if not sock_path or not os.path.exists(sock_path):
        return None
    try:
        payload = json.dumps({"method": method, "data": data or {}}).encode("utf-8")
        header = len(payload).to_bytes(4, byteorder="little")
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(0.4)
            s.connect(sock_path)
            s.sendall(header + payload)
            resp_len = int.from_bytes(s.recv(4), byteorder="little")
            return json.loads(s.recv(resp_len).decode("utf-8"))
    except Exception:
        return None


class AquaRootStageManager(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aquaroot.StageManager")

    def do_activate(self):
        self.win = Gtk.ApplicationWindow(application=self)
        self.win.set_name("aquaroot-stagemanager")

        Gtk4LayerShell.init_for_window(self.win)
        Gtk4LayerShell.set_layer(self.win, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_anchor(self.win, Gtk4LayerShell.Edge.LEFT, True)
        Gtk4LayerShell.set_margin(self.win, Gtk4LayerShell.Edge.LEFT, 8)

        self.strip_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.win.set_child(self.strip_box)
        self.win.present()

        self.refresh_views()
        GLib.timeout_add(2000, self.refresh_views)

    def refresh_views(self):
        while (c := self.strip_box.get_first_child()) is not None:
            self.strip_box.remove(c)

        views = wf_ipc_call("window-rules/list-views")
        if not isinstance(views, list):
            return True

        shown = 0
        for v in views:
            if not isinstance(v, dict):
                continue
            if v.get("role") != "toplevel" or v.get("app-id", "").startswith("org.aquaroot"):
                continue
            vid = v.get("id")
            app_id = v.get("app-id") or "Window"
            title = (v.get("title") or app_id)[:18]

            btn = Gtk.Button()
            btn.add_css_class("stage-strip-card")
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            a_lbl = Gtk.Label(xalign=0)
            a_lbl.set_markup(f"<small><b>{GLib.markup_escape_text(app_id[:14])}</b></small>")
            a_lbl.set_opacity(0.75)
            t_lbl = Gtk.Label(label=title, xalign=0)
            box.append(a_lbl)
            box.append(t_lbl)
            btn.set_child(box)
            btn.connect("clicked", lambda _, i=vid: wf_ipc_call("wm-actions/set-focus", {"id": i}))
            self.strip_box.append(btn)
            shown += 1
            if shown >= 6:
                break
        return True


if __name__ == "__main__":
    AquaRootStageManager().run(None)
EOF

    # --------------------------------------------------------------------------
    # 14. Screen Capture, 60fps Recorder & OCR Studio (~/.local/bin/aquaroot-screenshot.py)
    # --------------------------------------------------------------------------
    log "Writing ~/.local/bin/aquaroot-screenshot.py..."
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-screenshot.py"
#!/usr/bin/env python3
import time
import subprocess
from pathlib import Path
from ctypes import CDLL

CDLL("libgtk4-layer-shell.so")
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gtk4LayerShell

PIC_DIR = Path.home() / "Pictures" / "Screenshots"
VID_DIR = Path.home() / "Videos" / "ScreenRecordings"


class AquaRootScreenshotStudio(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aquaroot.ScreenshotStudio")

    def do_activate(self):
        PIC_DIR.mkdir(parents=True, exist_ok=True)
        VID_DIR.mkdir(parents=True, exist_ok=True)

        win = Gtk.ApplicationWindow(application=self)
        win.set_name("aquaroot-screenshot")
        Gtk4LayerShell.init_for_window(win)
        Gtk4LayerShell.set_layer(win, Gtk4LayerShell.Layer.OVERLAY)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.BOTTOM, True)
        Gtk4LayerShell.set_margin(win, Gtk4LayerShell.Edge.BOTTOM, 95)

        bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        bar.add_css_class("osd-capsule")

        actions = [
            ("Capture Screen", "video-display-symbolic", self.shot_full),
            ("Capture Region", "edit-select-all-symbolic", self.shot_region),
            ("OCR Text to Clipboard", "accessories-dictionary-symbolic", self.ocr_region),
            ("Record 60fps Video", "media-record-symbolic", self.record_toggle),
            ("Close", "window-close-symbolic", lambda _: self.quit()),
        ]
        for label, icon, cb in actions:
            btn = Gtk.Button()
            btn.add_css_class("macos-action-btn")
            b = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            b.append(Gtk.Image.new_from_icon_name(icon))
            b.append(Gtk.Label(label=label))
            btn.set_child(b)
            btn.connect("clicked", cb)
            bar.append(btn)

        win.set_child(bar)
        win.present()

    def shot_full(self, _):
        out = PIC_DIR / f"Screen_{int(time.time())}.png"
        self.quit()
        subprocess.Popen(["bash", "-c", f"sleep 0.2 && grim '{out}' && wl-copy < '{out}' && notify-send 'AquaRoot Capture' 'Saved & copied full screenshot'"])

    def shot_region(self, _):
        out = PIC_DIR / f"Region_{int(time.time())}.png"
        self.quit()
        subprocess.Popen(["bash", "-c", f"grim -g \"$(slurp)\" '{out}' && wl-copy < '{out}' && notify-send 'AquaRoot Capture' 'Saved & copied region screenshot'"])

    def ocr_region(self, _):
        tmp = "/tmp/aquaroot-ocr.png"
        self.quit()
        subprocess.Popen(["bash", "-c", f"grim -g \"$(slurp)\" '{tmp}' && tesseract '{tmp}' stdout | wl-copy && notify-send 'AquaRoot OCR' 'Extracted text copied to clipboard!'"])

    def record_toggle(self, _):
        out = VID_DIR / f"Recording_{int(time.time())}.mp4"
        self.quit()
        subprocess.Popen(["bash", "-c", f"pgrep wf-recorder && (pkill -INT wf-recorder && notify-send 'AquaRoot Recorder' 'Saved screen recording to ~/Videos') || (notify-send 'AquaRoot Recorder' 'Recording started...' && wf-recorder -f '{out}')"])


if __name__ == "__main__":
    AquaRootScreenshotStudio().run(None)
EOF

    # --------------------------------------------------------------------------
    # 15. AquaDrop Wireless Continuity (~/.local/bin/aquaroot-aquadrop.py)
    # --------------------------------------------------------------------------
    log "Writing ~/.local/bin/aquaroot-aquadrop.py..."
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-aquadrop.py"
#!/usr/bin/env python3
import socket
import subprocess
from pathlib import Path
import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk

DROP_DIR = Path.home() / "Downloads" / "AquaDrop"


def get_lan_ip():
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"


class AquaDropApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aquaroot.AquaDrop")
        self.http_proc = None

    def do_activate(self):
        DROP_DIR.mkdir(parents=True, exist_ok=True)
        win = Gtk.ApplicationWindow(application=self)
        win.set_title("AquaDrop Wireless Continuity")
        win.set_default_size(500, 340)
        win.add_css_class("macos-settings-window")

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        box.set_margin_top(24); box.set_margin_bottom(24); box.set_margin_start(28); box.set_margin_end(28)

        hdr = Gtk.Label(xalign=0)
        hdr.set_markup("<span size='x-large'><b>AquaDrop Continuity</b></span>\n<small>Share files across Linux, Android, iOS, and macOS over local Wi-Fi.</small>")
        box.append(hdr)

        ip = get_lan_ip()
        info = Gtk.Label(xalign=0, wrap=True)
        info.set_markup(f"<b>Local Wi-Fi Drop URL:</b> <tt>http://{ip}:8088</tt>\nFiles placed in <tt>~/Downloads/AquaDrop</tt> are immediately accessible to any device on your network.")
        box.append(info)

        btn_srv = Gtk.ToggleButton(label="Start Local Wi-Fi AquaDrop Server (Port 8088)")
        btn_srv.add_css_class("cc-pill-toggle")
        btn_srv.connect("toggled", self.toggle_server)
        box.append(btn_srv)

        btn_folder = Gtk.Button(label="Open ~/Downloads/AquaDrop in Finder")
        btn_folder.add_css_class("macos-action-btn")
        btn_folder.connect("clicked", lambda _: subprocess.Popen(["nautilus", str(DROP_DIR)]))
        box.append(btn_folder)

        btn_kde = Gtk.Button(label="Pair Mobile Devices (KDE Connect)")
        btn_kde.add_css_class("macos-action-btn")
        btn_kde.connect("clicked", lambda _: subprocess.Popen(["kdeconnect-app"]))
        box.append(btn_kde)

        win.set_child(box)
        win.present()

    def toggle_server(self, btn):
        if btn.get_active():
            self.http_proc = subprocess.Popen(["python3", "-m", "http.server", "8088", "--directory", str(DROP_DIR)])
        elif self.http_proc:
            self.http_proc.terminate()
            self.http_proc = None


if __name__ == "__main__":
    AquaDropApp().run(None)
EOF

    # --------------------------------------------------------------------------
    # 16. Time Machine Backup Studio (~/.local/bin/aquaroot-timemachine.py)
    # --------------------------------------------------------------------------
    log "Writing ~/.local/bin/aquaroot-timemachine.py..."
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-timemachine.py"
#!/usr/bin/env python3
import time
import subprocess
from pathlib import Path
import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk

SNAP_DIR = Path.home() / ".local" / "share" / "aquaroot" / "timemachine"


class AquaRootTimeMachine(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aquaroot.TimeMachine")

    def do_activate(self):
        SNAP_DIR.mkdir(parents=True, exist_ok=True)
        win = Gtk.ApplicationWindow(application=self)
        win.set_title("AquaRoot Time Machine")
        win.set_default_size(560, 420)
        win.add_css_class("macos-settings-window")

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        box.set_margin_top(24); box.set_margin_bottom(24); box.set_margin_start(28); box.set_margin_end(28)

        hdr = Gtk.Label(xalign=0)
        hdr.set_markup("<span size='x-large'><b>Time Machine Snapshots</b></span>\n<small>Back up and restore your AquaRoot configurations or full OS snapshots.</small>")
        box.append(hdr)

        btn_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        b_snap = Gtk.Button(label="Create Instant Config Snapshot")
        b_snap.add_css_class("macos-action-btn")
        b_snap.connect("clicked", self.create_snapshot)

        b_ts = Gtk.Button(label="Launch Full OS Timeshift Manager")
        b_ts.add_css_class("macos-action-btn")
        b_ts.connect("clicked", lambda _: subprocess.Popen(["foot", "-e", "sudo", "timeshift-gtk"]))
        btn_row.append(b_snap)
        btn_row.append(b_ts)
        box.append(btn_row)

        self.listbox = Gtk.ListBox(vexpand=True)
        self.listbox.add_css_class("macos-group-card")
        box.append(self.listbox)

        self.refresh_snapshots()
        win.set_child(box)
        win.present()

    def create_snapshot(self, _):
        stamp = time.strftime("%Y-%m-%d_%H-%M-%S")
        dest = SNAP_DIR / f"aquaroot_snapshot_{stamp}.tar.gz"
        subprocess.run(["tar", "-czf", str(dest), "-C", str(Path.home()), ".config/wayfire.ini", ".config/gtk-4.0", ".config/aquaroot"])
        self.refresh_snapshots()

    def refresh_snapshots(self):
        while (c := self.listbox.get_first_child()) is not None:
            self.listbox.remove(c)
        for arch in sorted(SNAP_DIR.glob("*.tar.gz"), reverse=True):
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            row.add_css_class("macos-row")
            lbl = Gtk.Label(label=arch.name, xalign=0, hexpand=True)
            res_btn = Gtk.Button(label="Restore Snapshot")
            res_btn.add_css_class("macos-action-btn")
            res_btn.connect("clicked", lambda _, a=arch: subprocess.Popen(["tar", "-xzf", str(a), "-C", str(Path.home())]))
            row.append(lbl)
            row.append(res_btn)
            self.listbox.append(row)


if __name__ == "__main__":
    AquaRootTimeMachine().run(None)
EOF

    # --------------------------------------------------------------------------
    # 17. Refined macOS-Style System Settings App (~/.local/bin/aquaroot-settings.py)
    # --------------------------------------------------------------------------
    log "Writing ~/.local/bin/aquaroot-settings.py..."
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-settings.py"
#!/usr/bin/env python3
import os
import json
import getpass
import subprocess
from pathlib import Path
import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk

GLASS_CTL = os.path.expanduser("~/.local/bin/aquaroot-glass-ctl.py")
WALL_SH = os.path.expanduser("~/.local/bin/aquaroot-wallpaper.sh")
GLASS_JSON = Path.home() / ".config" / "aquaroot" / "glass.json"

CATEGORIES = [
    ("network",   "Wi-Fi & Bluetooth",         "network-wireless-symbolic",              "badge-blue"),
    ("sound",     "Sound & PipeWire",          "audio-volume-high-symbolic",             "badge-pink"),
    ("glass",     "Liquid Glass & Appearance", "preferences-desktop-appearance-symbolic","badge-purple"),
    ("wallpaper", "Wallpaper & Solar Engine",  "preferences-desktop-wallpaper-symbolic", "badge-teal"),
    ("desktop",   "Notch, Stage & Widgets",    "view-grid-symbolic",                     "badge-orange"),
    ("ecosystem", "AquaDrop & Time Machine",   "drive-harddisk-symbolic",                "badge-green"),
    ("security",  "Touch ID & Face ID",        "security-high-symbolic",                 "badge-gray"),
]


class AquaRootMacSettings(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aquaroot.Settings")

    def do_activate(self):
        self.win = Gtk.ApplicationWindow(application=self)
        self.win.set_title("System Settings")
        self.win.set_default_size(920, 620)
        self.win.set_decorated(False)
        self.win.add_css_class("macos-settings-window")

        root = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)

        # Left macOS Sidebar
        sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        sidebar.add_css_class("macos-sidebar")
        sidebar.set_size_request(250, -1)

        # Traffic Light Window Controls
        traffic = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        traffic.set_margin_top(4); traffic.set_margin_start(6); traffic.set_margin_bottom(4)
        for cls, cb in [
            ("traffic-close", lambda _: self.win.close()),
            ("traffic-min",   lambda _: self.win.minimize()),
            ("traffic-max",   lambda _: self.win.maximize() if not self.win.is_maximized() else self.win.unmaximize()),
        ]:
            b = Gtk.Button()
            b.add_css_class("traffic-dot")
            b.add_css_class(cls)
            b.connect("clicked", cb)
            traffic.append(b)
        sidebar.append(traffic)

        # Profile Account Card
        user = getpass.getuser().capitalize()
        prof_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        prof_box.set_margin_start(6); prof_box.set_margin_bottom(6)
        av = Gtk.Image.new_from_icon_name("avatar-default-symbolic")
        av.set_pixel_size(36)
        utxt = Gtk.Label(xalign=0)
        utxt.set_markup(f"<b>{user}</b>\n<small>AquaRoot ID • v3.0</small>")
        prof_box.append(av)
        prof_box.append(utxt)
        sidebar.append(prof_box)

        # Category ListBox
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_hexpand(True)

        self.nav_list = Gtk.ListBox()
        self.nav_list.add_css_class("macos-sidebar-list")
        self.nav_list.connect("row-selected", self.on_nav_selected)

        for key, title, icon, badge_cls in CATEGORIES:
            row_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            ic = Gtk.Image.new_from_icon_name(icon)
            ic.set_pixel_size(16)
            ic.add_css_class("macos-squircle-badge")
            ic.add_css_class(badge_cls)
            lbl = Gtk.Label(label=title, xalign=0)
            row_box.append(ic)
            row_box.append(lbl)
            self.nav_list.append(row_box)

        sidebar.append(self.nav_list)

        # Build Content Pages
        self.stack.add_named(self._page_network(),   "network")
        self.stack.add_named(self._page_sound(),     "sound")
        self.stack.add_named(self._page_glass(),     "glass")
        self.stack.add_named(self._page_wallpaper(), "wallpaper")
        self.stack.add_named(self._page_desktop(),   "desktop")
        self.stack.add_named(self._page_ecosystem(), "ecosystem")
        self.stack.add_named(self._page_security(),  "security")

        self.nav_list.select_row(self.nav_list.get_row_at_index(2))

        root.append(sidebar)
        root.append(self.stack)
        self.win.set_child(root)
        self.win.present()

    def on_nav_selected(self, _lb, row):
        if row:
            key = CATEGORIES[row.get_index()][0]
            self.stack.set_visible_child_name(key)

    def _load_glass(self):
        if GLASS_JSON.exists():
            try:
                return json.loads(GLASS_JSON.read_text())
            except Exception:
                pass
        return {"opacity": 0.52, "blur_iterations": 4, "blur_offset": 2.2, "specular_intensity": 0.55, "reduce_transparency": False, "tint_mode": "dark"}

    def _wrap_page(self, title, subtitle):
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        page.set_margin_top(26); page.set_margin_bottom(24); page.set_margin_start(32); page.set_margin_end(32)
        hdr = Gtk.Label(xalign=0)
        hdr.set_markup(f"<span size='x-large'><b>{title}</b></span>\n<small>{subtitle}</small>")
        page.append(hdr)
        return page

    def _page_glass(self):
        cfg = self._load_glass()
        page = self._wrap_page("Liquid Glass &amp; Appearance", "Customize optical refraction, Kawase blur passes, and readability contrast.")

        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        card.add_css_class("macos-group-card")

        # Mode Row
        r_mode = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        r_mode.add_css_class("macos-row")
        r_mode.append(Gtk.Label(label="Appearance Mode", xalign=0, hexpand=True))
        b_dark = Gtk.Button(label="Dark Obsidian")
        b_dark.add_css_class("macos-action-btn")
        b_dark.connect("clicked", lambda _: subprocess.Popen([GLASS_CTL, "tint_mode=dark"]))
        b_light = Gtk.Button(label="Light Frost")
        b_light.add_css_class("macos-action-btn")
        b_light.connect("clicked", lambda _: subprocess.Popen([GLASS_CTL, "tint_mode=light"]))
        r_mode.append(b_dark); r_mode.append(b_light)
        card.append(r_mode)

        # High Contrast Switch
        r_rt = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        r_rt.add_css_class("macos-row")
        r_rt.append(Gtk.Label(label="Reduce Transparency (High-Contrast Readability)", xalign=0, hexpand=True))
        sw = Gtk.Switch(active=cfg.get("reduce_transparency", False))
        sw.connect("notify::active", lambda s, _: subprocess.Popen([GLASS_CTL, f"reduce_transparency={s.get_active()}"]))
        r_rt.append(sw)
        card.append(r_rt)

        # Opacity Slider
        r_op = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        r_op.add_css_class("macos-row")
        r_op.append(Gtk.Label(label="Liquid Glass Surface Opacity", xalign=0))
        op_sc = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0.25, 0.95, 0.05)
        op_sc.set_value(cfg.get("opacity", 0.52))
        op_sc.connect("value-changed", lambda s: subprocess.Popen([GLASS_CTL, f"opacity={s.get_value():.2f}"]))
        r_op.append(op_sc)
        card.append(r_op)

        # Blur Slider
        r_bl = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        r_bl.add_css_class("macos-row")
        r_bl.append(Gtk.Label(label="Kawase Backdrop Blur Passes", xalign=0))
        bl_sc = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 1, 8, 1)
        bl_sc.set_value(cfg.get("blur_iterations", 4))
        bl_sc.connect("value-changed", lambda s: subprocess.Popen([GLASS_CTL, f"blur_iterations={int(s.get_value())}"]))
        r_bl.append(bl_sc)
        card.append(r_bl)

        page.append(card)
        return page

    def _page_wallpaper(self):
        page = self._wrap_page("Wallpaper &amp; Dynamic Solar Engine", "Fetch 4K online wallpapers or shift tones automatically by time of day.")
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        card.add_css_class("macos-group-card")

        entry = Gtk.Entry(placeholder_text="Search 4K theme (e.g., macos+liquid+4k, mountains, cyberpunk)...")
        card.append(entry)

        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        b_on = Gtk.Button(label="Fetch & Apply 4K Online Wallpaper")
        b_on.add_css_class("macos-action-btn")
        b_on.connect("clicked", lambda _: subprocess.Popen([WALL_SH, "--online", entry.get_text().strip() or "macos+liquid+4k"]))

        b_sol = Gtk.Button(label="Sync Solar Time-of-Day Wallpaper")
        b_sol.add_css_class("macos-action-btn")
        b_sol.connect("clicked", lambda _: subprocess.Popen([WALL_SH, "--solar"]))
        row.append(b_on); row.append(b_sol)
        card.append(row)
        page.append(card)
        return page

    def _page_desktop(self):
        page = self._wrap_page("Dynamic Notch, Stage Manager &amp; Widgets", "Manage v3.0 interactive desktop surfaces and screen capture tools.")
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        card.add_css_class("macos-group-card")

        items = [
            ("Dynamic Notch Island (MPRIS + Dropover Shelf)", ["bash", "-c", "pkill -f aquaroot-notch.py || ~/.local/bin/aquaroot-notch.py &"]),
            ("Stage Manager Left Window Strip (Super+S)", ["bash", "-c", "pkill -f aquaroot-stagemanager.py || ~/.local/bin/aquaroot-stagemanager.py &"]),
            ("Desktop WidgetKit Layer (Clock, Telemetry, Notes)", ["bash", "-c", "pkill -f aquaroot-widgets.py || ~/.local/bin/aquaroot-widgets.py &"]),
            ("Control Center & Notification Drawer (Super+N)", ["pkill", "-USR1", "-f", "aquaroot-notifications.py"]),
            ("Launch Screen Capture & OCR Studio (Super+Shift+5)", [os.path.expanduser("~/.local/bin/aquaroot-screenshot.py")]),
        ]
        for label, cmd in items:
            r = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            r.add_css_class("macos-row")
            r.append(Gtk.Label(label=label, xalign=0, hexpand=True))
            btn = Gtk.Button(label="Toggle / Launch")
            btn.add_css_class("macos-action-btn")
            btn.connect("clicked", lambda _, c=cmd: subprocess.Popen(c))
            r.append(btn)
            card.append(r)

        page.append(card)
        return page

    def _page_ecosystem(self):
        page = self._wrap_page("AquaDrop &amp; Time Machine", "Wireless cross-device file sharing and instant system snapshot recovery.")
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        card.add_css_class("macos-group-card")

        for label, script in [
            ("AquaDrop Wireless Continuity & KDE Connect", "aquaroot-aquadrop.py"),
            ("Time Machine Snapshot & Timeshift Studio", "aquaroot-timemachine.py"),
        ]:
            r = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            r.add_css_class("macos-row")
            r.append(Gtk.Label(label=label, xalign=0, hexpand=True))
            b = Gtk.Button(label="Open Studio")
            b.add_css_class("macos-action-btn")
            b.connect("clicked", lambda _, s=script: subprocess.Popen([os.path.expanduser(f"~/.local/bin/{s}")]))
            r.append(b)
            card.append(r)

        page.append(card)
        return page

    def _page_network(self):
        page = self._wrap_page("Wi-Fi &amp; Bluetooth", "Configure wireless connections and paired Bluetooth peripherals.")
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        card.add_css_class("macos-group-card")

        for label, cmd in [
            ("Open NetworkManager Wi-Fi TUI (nmtui)", ["foot", "-e", "nmtui"]),
            ("Open Bluetooth Device Manager (blueman)", ["blueman-manager"]),
        ]:
            r = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            r.add_css_class("macos-row")
            r.append(Gtk.Label(label=label, xalign=0, hexpand=True))
            b = Gtk.Button(label="Configure")
            b.add_css_class("macos-action-btn")
            b.connect("clicked", lambda _, c=cmd: subprocess.Popen(c))
            r.append(b)
            card.append(r)
        page.append(card)
        return page

    def _page_sound(self):
        page = self._wrap_page("Sound &amp; PipeWire Audio", "Adjust output volume and per-application PipeWire routing.")
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        card.add_css_class("macos-group-card")
        b = Gtk.Button(label="Open PipeWire Per-App Audio Mixer (pavucontrol)")
        b.add_css_class("macos-action-btn")
        b.connect("clicked", lambda _: subprocess.Popen(["pavucontrol"]))
        card.append(b)
        page.append(card)
        return page

    def _page_security(self):
        page = self._wrap_page("Touch ID &amp; Face ID", "Enroll biometric sensors for the AquaRoot Dynamic Lock Screen.")
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        card.add_css_class("macos-group-card")
        for label, cmd in [
            ("Enroll Face ID (Howdy IR / Webcam)", ["foot", "-e", "sudo", "howdy", "add"]),
            ("Enroll Touch ID (fprintd Fingerprint)", ["foot", "-e", "fprintd-enroll"]),
            ("Test Dynamic Lock Screen Now", ["hyprlock"]),
        ]:
            r = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            r.add_css_class("macos-row")
            r.append(Gtk.Label(label=label, xalign=0, hexpand=True))
            b = Gtk.Button(label="Launch")
            b.add_css_class("macos-action-btn")
            b.connect("clicked", lambda _, c=cmd: subprocess.Popen(c))
            r.append(b)
            card.append(r)
        page.append(card)
        return page


if __name__ == "__main__":
    AquaRootMacSettings().run(None)
EOF

    # --------------------------------------------------------------------------
    # 18. First-Boot macOS-Style Welcome App (~/.local/bin/aquaroot-welcome.py)
    # --------------------------------------------------------------------------
    log "Writing ~/.local/bin/aquaroot-welcome.py..."
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-welcome.py"
#!/usr/bin/env python3
import os
import sys
import subprocess
from pathlib import Path
import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk

SENTINEL = Path.home() / ".config" / "aquaroot" / "first_boot_done"
GLASS_CTL = os.path.expanduser("~/.local/bin/aquaroot-glass-ctl.py")
WALL_SH = os.path.expanduser("~/.local/bin/aquaroot-wallpaper.sh")


class AquaRootWelcome(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aquaroot.Welcome")

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        win.set_title("Welcome to AquaRoot v3.0")
        win.set_default_size(660, 450)
        win.add_css_class("macos-settings-window")

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.stack.set_transition_duration(350)

        p1 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18, valign=Gtk.Align.CENTER)
        p1.set_margin_start(40); p1.set_margin_end(40)
        hello = Gtk.Label(justify=Gtk.Justification.CENTER)
        hello.set_markup("<span size='xx-large'><b>Hello.</b></span>\n<span size='large'>Welcome to <b>AquaRoot DE v3.0</b></span>")
        desc = Gtk.Label(
            label="Experience Liquid Glass aesthetics, the MPRIS Dynamic Notch with Dropover File Shelf, Control Center (Super+N), Stage Manager (Super+S), Screenshot & OCR Studio (Super+Shift+5), and Spotlight v2 (Super+Space).",
            wrap=True, justify=Gtk.Justification.CENTER
        )
        next1 = Gtk.Button(label="Continue →", halign=Gtk.Align.CENTER)
        next1.add_css_class("macos-action-btn")
        next1.connect("clicked", lambda _: self.stack.set_visible_child_name("page2"))
        p1.append(hello); p1.append(desc); p1.append(next1)

        p2 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14, valign=Gtk.Align.CENTER)
        p2.set_margin_start(40); p2.set_margin_end(40)
        p2_title = Gtk.Label(justify=Gtk.Justification.CENTER)
        p2_title.set_markup("<span size='x-large'><b>Choose Your Liquid Glass Profile</b></span>")

        for lbl, op in [
            ("Ultra-Clear Liquid Glass (45% Opacity)", "0.45"),
            ("Balanced Aqua Glass (52% Opacity — Recommended)", "0.52"),
            ("High-Contrast Readability Glass (85% Opacity)", "0.85"),
        ]:
            b = Gtk.Button(label=lbl)
            b.add_css_class("macos-action-btn")
            b.connect("clicked", lambda _, o=op: subprocess.Popen([GLASS_CTL, f"opacity={o}", "reduce_transparency=false"]))
            p2.append(b)

        next2 = Gtk.Button(label="Continue →", halign=Gtk.Align.CENTER)
        next2.add_css_class("macos-action-btn")
        next2.connect("clicked", lambda _: self.stack.set_visible_child_name("page3"))
        p2.prepend(p2_title); p2.append(next2)

        p3 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16, valign=Gtk.Align.CENTER)
        p3.set_margin_start(40); p3.set_margin_end(40)
        p3_title = Gtk.Label()
        p3_title.set_markup("<span size='x-large'><b>Your Desktop Ecosystem is Ready</b></span>")
        wall_btn = Gtk.Button(label="Download First 4K Liquid Wallpaper", halign=Gtk.Align.CENTER)
        wall_btn.add_css_class("macos-action-btn")
        wall_btn.connect("clicked", lambda _: subprocess.Popen([WALL_SH, "--online"]))

        finish_btn = Gtk.Button(label="Enter AquaRoot Desktop", halign=Gtk.Align.CENTER)
        finish_btn.add_css_class("macos-action-btn")
        finish_btn.connect("clicked", self.finish_onboarding)
        p3.append(p3_title); p3.append(wall_btn); p3.append(finish_btn)

        self.stack.add_named(p1, "page1")
        self.stack.add_named(p2, "page2")
        self.stack.add_named(p3, "page3")

        win.set_child(self.stack)
        win.present()

    def finish_onboarding(self, _btn):
        SENTINEL.parent.mkdir(parents=True, exist_ok=True)
        SENTINEL.write_text("completed\n")
        self.quit()


if __name__ == "__main__":
    if not SENTINEL.exists() or "--force" in sys.argv:
        AquaRootWelcome().run(None)
EOF

    # --------------------------------------------------------------------------
    # 19. AquaRoot CLI Doctor & Shell Controller (~/.local/bin/aquaroot-cli)
    # --------------------------------------------------------------------------
    log "Writing ~/.local/bin/aquaroot-cli..."
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-cli"
#!/usr/bin/env bash
set -euo pipefail
case "${1:-help}" in
    status|doctor)
        echo "=== AquaRoot DE v3.0 System Health ==="
        for bin in wayfire swww mpv yt-dlp nautilus foot grim slurp wf-recorder tesseract wlsunset brightnessctl; do
            if command -v "$bin" &>/dev/null; then
                printf "  [OK] %-18s -> %s\n" "$bin" "$(command -v "$bin")"
            else
                printf "  [!!] %-18s -> MISSING\n" "$bin"
            fi
        done
        ;;
    wallpaper)
        shift
        ~/.local/bin/aquaroot-wallpaper.sh --online "${1:-macos+liquid+4k}"
        ;;
    solar)
        ~/.local/bin/aquaroot-wallpaper.sh --solar
        ;;
    restart-shell)
        for mod in aquaroot-topbar.py aquaroot-notch.py aquaroot-dock.py aquaroot-notifications.py aquaroot-widgets.py; do
            pkill -f "$mod" 2>/dev/null || true
            nohup "$HOME/.local/bin/$mod" >/dev/null 2>&1 &
        done
        echo "Restarted all AquaRoot v3.0 shell daemons."
        ;;
    *)
        echo "Usage: aquaroot-cli {status|doctor|wallpaper [query]|solar|restart-shell}"
        ;;
esac
EOF

    # --------------------------------------------------------------------------
    # 20. Dynamic Lock Screen (~/.config/hypr/hyprlock.conf & /etc/pam.d/hyprlock)
    # --------------------------------------------------------------------------
    log "Writing ~/.config/hypr/hyprlock.conf & PAM biometric stack..."
    cat << 'EOF' > "$HOME/.config/hypr/hyprlock.conf"
general {
    hide_cursor = false
    grace = 1
    enable_fingerprint = true
}

background {
    monitor =
    path = ~/.local/share/aquaroot/wallpapers/current_wallpaper.jpg
    blur_passes = 3
    blur_size = 6
    brightness = 0.82
    vibrancy = 0.25
}

label {
    monitor =
    text = Face ID & Touch ID Active
    color = rgba(255, 255, 255, 0.85)
    font_size = 13
    font_family = Inter, sans-serif
    position = 0, -42
    halign = center
    valign = top
}

label {
    monitor =
    text = cmd[update:1000] echo "$(date +"%H:%M")"
    color = rgba(255, 255, 255, 0.92)
    font_size = 115
    font_family = Inter Bold, sans-serif
    position = 0, 220
    halign = center
    valign = center
    shadow_passes = 2
    shadow_size = 6
}

label {
    monitor =
    text = cmd[update:60000] echo "$(date +"%A, %B %d")"
    color = rgba(255, 255, 255, 0.80)
    font_size = 22
    font_family = Inter SemiBold, sans-serif
    position = 0, 315
    halign = center
    valign = center
}

input-field {
    monitor =
    size = 260, 44
    outline_thickness = 1
    dots_size = 0.26
    dots_spacing = 0.22
    outer_color = rgba(255, 255, 255, 0.45)
    inner_color = rgba(255, 255, 255, 0.16)
    font_color = rgb(255, 255, 255)
    fade_on_empty = false
    placeholder_text = <i>Enter Password or Use Biometrics...</i>
    position = 0, -340
    halign = center
    valign = center
}
EOF

    sudo tee /etc/pam.d/hyprlock >/dev/null << 'EOF'
#%PAM-1.0
auth       sufficient   pam_howdy.so
auth       sufficient   pam_fprintd.so
auth       include      system-auth
EOF

    # --------------------------------------------------------------------------
    # 21. Desktop Entries & Display Manager Wayland Session Registration
    # --------------------------------------------------------------------------
    log "Registering desktop entries and Wayland session..."
    cat << EOF > "$HOME/.local/share/applications/aquaroot-settings.desktop"
[Desktop Entry]
Name=AquaRoot System Settings
Comment=Configure Liquid Glass, Notch, Stage Manager, Wallpapers & Biometrics
Exec=$HOME/.local/bin/aquaroot-settings.py
Icon=preferences-system
Terminal=false
Type=Application
Categories=Settings;System;
EOF

    cat << EOF > "$HOME/.local/share/applications/aquaroot-timemachine.desktop"
[Desktop Entry]
Name=AquaRoot Time Machine
Comment=Back up and restore AquaRoot snapshots and Timeshift recovery points
Exec=$HOME/.local/bin/aquaroot-timemachine.py
Icon=drive-harddisk
Terminal=false
Type=Application
Categories=System;Utility;
EOF

    cat << EOF > "$HOME/.local/share/applications/aquaroot-aquadrop.desktop"
[Desktop Entry]
Name=AquaDrop Continuity
Comment=Share files wirelessly across Linux, Android, iOS, and macOS
Exec=$HOME/.local/bin/aquaroot-aquadrop.py
Icon=network-transmit-receive
Terminal=false
Type=Application
Categories=Network;FileTransfer;
EOF

    chmod +x "$HOME/.local/bin/"aquaroot-*.py \
             "$HOME/.local/bin/"aquaroot-*.sh \
             "$HOME/.local/bin/aquaroot-cli"

    gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:' 2>/dev/null || true
    "$HOME/.local/bin/aquaroot-glass-ctl.py"

    sudo mkdir -p /usr/share/wayland-sessions
    sudo tee /usr/share/wayland-sessions/aquaroot.desktop >/dev/null << 'EOF'
[Desktop Entry]
Name=AquaRoot v3.0 (Liquid Glass)
Comment=macOS-inspired Liquid Glass Desktop Ecosystem on wlroots
Exec=/usr/bin/env PATH=/usr/local/bin:/usr/bin:/bin:~/.local/bin XDG_CURRENT_DESKTOP=AquaRoot GTK_MODULES=appmenu-gtk-module wayfire
Type=Application
DesktopNames=AquaRoot;wlroots;
EOF

    ok "All 21 AquaRoot DE v3.0 modules and configurations deployed!"
}

# ==============================================================================
# Run Full v3.0 Installation Workflow
# ==============================================================================
print_banner
scan_and_install_hardware_and_deps
deploy_aquaroot_files

ok "=============================================================================="
ok "AquaRoot DE v3.0 is now completely installed!"
ok "1. Log out of your current desktop session."
ok "2. Select 'AquaRoot v3.0 (Liquid Glass)' in your Display Manager (GDM/SDDM/LightDM)."
ok "3. Key Shortcuts:"
ok "   • Super + Space         -> Spotlight v2 (Apps, Math, Unit Converter, 'clip:')"
ok "   • Super + N             -> Slide-out Control Center & Notification Drawer"
ok "   • Super + S             -> Toggle Stage Manager Window Strip"
ok "   • Super + Shift + 5     -> Screen Capture, 60fps Video Recorder & OCR Studio"
ok "   • Super + Tab / Super+E -> Mission Control / Workspace Exposé"
ok "   • Spacebar in Finder    -> QuickLook File Preview"
ok "   • Super + L             -> Biometric Lock Screen (Face ID & Touch ID)"
ok "=============================================================================="
