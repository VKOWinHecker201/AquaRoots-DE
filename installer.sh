#!/usr/bin/env bash
# ==============================================================================
# AquaRoot DE v0.1 — Downloader-Proof Smart Installer & GitHub Source Builder
# Compositor: wlroots / Wayfire | UI: GTK4 + gtk4-layer-shell (Liquid Glass)
# ==============================================================================
set -uo pipefail

# --- Self-Sanitizer: Automatically repairs downloader corruptions (vert{}, \%) ---
if grep -q -e "vert{}" -e '\\%' "$0" 2>/dev/null; then
    sed -i 's/\xc2\xa0/ /g; s/vert{}/|/g; s/\\%/%/g' "$0"
    exec bash "$0" "$@"
fi

# --- ANSI TUI Palette & Formatting ---
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
NC='\033[0m'

LOG_FILE="/tmp/aquaroot-install.log"
BUILD_DIR="/tmp/aquaroot-src-build"
SOURCE_BUILD_QUEUE=()
INSTALL_MODE="interactive"
FORCE_SOURCE="false"

mkdir -p "$BUILD_DIR"
: > "$LOG_FILE"

# ==============================================================================
# TUI ENGINE: Pipe-Free & Modulo-Free Logging, Spinners & Prompts
# ==============================================================================
draw_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'BANNER'
    ╔══════════════════════════════════════════════════════════════════════╗
    ║      ___                     ____              __     ____  ______   ║
    ║     /   | ____ ___  ______ _/ __ \____  ____  / /_   / __ \/ ____/   ║
    ║    / /| |/ __ `/ / / / __ `/ /_/ / __ \/ __ \/ __/  / / / / __/      ║
    ║   / ___ / /_/ / /_/ / /_/ / _, _/ /_/ / /_/ / /_   / /_/ / /___      ║
    ║  /_/  |_\__, /\__,_/\__,_/_/ |_|\____/\____/\__/  /_____/_____/      ║
    ║           /_/   Macintosh Desktop on wlroots • Smart Builder v0.1    ║
    ╚══════════════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
}

log_info() {
    echo -e "  ${BLUE}[INFO]${NC}  $1"
    echo "[INFO]  $1" >> "$LOG_FILE"
}

log_ok() {
    echo -e "  ${GREEN}[ OK ]${NC}  $1"
    echo "[ OK ]  $1" >> "$LOG_FILE"
}

log_warn() {
    echo -e "  ${YELLOW}[WARN]${NC}  $1"
    echo "[WARN]  $1" >> "$LOG_FILE"
}

log_err() {
    echo -e "  ${RED}[FAIL]${NC}  $1"
    echo "[FAIL]  $1" >> "$LOG_FILE"
}

progress_bar() {
    local current="$1"
    local total="$2"
    local label="$3"
    echo -e "\n  ${CYAN}==>${NC} ${BOLD}[Step ${current} of ${total}] ${label}${NC}"
}

run_with_spinner() {
    local msg="$1"
    shift
    local frames=('[-]' '[\]' '[|]' '[/]')
    "$@" >>"$LOG_FILE" 2>&1 &
    local pid=$!
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        echo -ne "\r  ${CYAN}${frames[i]}${NC}  ${msg}..."
        i=$(( i + 1 ))
        if [ "$i" -ge 4 ]; then
            i=0
        fi
        sleep 0.15
    done
    wait "$pid"
    local status=$?
    echo -ne "\r\033[K"
    return "$status"
}

prompt_choice() {
    local title="$1"
    shift
    local options=("$@")
    local count="${#options[@]}"
    echo -e "\n  ${BOLD}${MAGENTA}▸ ${title}${NC}"
    local idx=0
    while [ "$idx" -lt "$count" ]; do
        local num=$(( idx + 1 ))
        echo -e "    ${CYAN}[${num}]${NC} ${options[$idx]}"
        idx=$(( idx + 1 ))
    done

    if [ "$INSTALL_MODE" = "auto" ]; then
        echo -e "    ${DIM}Auto-selecting option [1]${NC}"
        REPLY_INDEX=1
        return 0
    fi

    while true; do
        read -rp "  Select an option [1-${count}] (default: 1): " input
        input="${input:-1}"
        if [ "$input" -ge 1 ] 2>/dev/null && [ "$input" -le "$count" ] 2>/dev/null; then
            REPLY_INDEX="$input"
            return 0
        fi
        echo -e "  ${RED}Please enter a valid number between 1 and ${count}.${NC}"
    done
}

# ==============================================================================
# STEP 0: Interactive CLI Main Menu
# ==============================================================================
show_main_menu() {
    draw_banner
    echo -e "  ${DIM}Log file: ${LOG_FILE}${NC}"
    echo -e "  ${DIM}Source cache: ${BUILD_DIR}${NC}"
    prompt_choice "Choose Installation Mode:" \
        "Express Smart Install (Auto-detect drivers, install repos & compile missing packages)" \
        "Interactive Step-by-Step Install (Confirm source builds & optional modules)" \
        "Force Source Build Mode (Compile Wayfire, wlroots, Pixdecor & swww from GitHub)" \
        "Repair / Diagnose Existing AquaRoot DE Installation" \
        "View Live Installer Log" \
        "Exit"

    case "$REPLY_INDEX" in
        1) INSTALL_MODE="auto"; FORCE_SOURCE="false" ;;
        2) INSTALL_MODE="interactive"; FORCE_SOURCE="false" ;;
        3) INSTALL_MODE="interactive"; FORCE_SOURCE="true" ;;
        4) INSTALL_MODE="repair"; FORCE_SOURCE="false" ;;
        5) less "$LOG_FILE"; show_main_menu; return ;;
        6) exit 0 ;;
    esac
}

# ==============================================================================
# STEP 1: Detect Distro & Package Manager
# ==============================================================================
detect_distro() {
    if command -v pacman &>/dev/null; then
        PKG_MGR="pacman"
    elif command -v dnf &>/dev/null; then
        PKG_MGR="dnf"
    elif command -v apt-get &>/dev/null; then
        PKG_MGR="apt"
    else
        log_err "Unsupported package manager. Requires apt (Debian/Ubuntu), dnf (Fedora), or pacman (Arch)."
        exit 1
    fi
    DISTRO_NAME="Linux"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_NAME="${PRETTY_NAME:-Linux}"
    fi
    log_ok "Detected OS: ${DISTRO_NAME} (${PKG_MGR})"
}

# ==============================================================================
# STEP 2: Smart Package Manager Error Parser & Auto-Healer
# ==============================================================================
heal_pkg_manager_error() {
    local err_file="$1"
    log_warn "Analyzing package manager error output..."

    if grep -qi -e "Could not get lock" -e "dpkg frontend lock" -e "unable to lock database" "$err_file"; then
        log_warn "Package database is locked by another process."
        if [ "$INSTALL_MODE" = "interactive" ]; then
            prompt_choice "Package manager lock detected. How should we proceed?" \
                "Wait 10 seconds for the other process to finish" \
                "Force-clear stale lock files and repair package database"
            if [ "$REPLY_INDEX" -eq 2 ]; then
                sudo rm -f /var/lib/pacman/db.lck /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock
                if [ "$PKG_MGR" = "apt" ]; then
                    sudo dpkg --configure -a
                fi
            else
                sleep 10
            fi
        else
            sleep 5
            sudo rm -f /var/lib/pacman/db.lck
            if [ "$PKG_MGR" = "apt" ]; then
                sudo dpkg --configure -a
            fi
        fi
        return 0
    fi

    if grep -qi -e "Unmet dependencies" -e "broken packages" -e "dpkg was interrupted" -e "404  Not Found" "$err_file"; then
        log_warn "Broken dependency tree or stale repository metadata detected. Running automatic repair..."
        case "$PKG_MGR" in
            apt)
                sudo dpkg --configure -a >>"$LOG_FILE" 2>&1
                sudo apt-get update -y >>"$LOG_FILE" 2>&1
                sudo apt-get --fix-broken install -y >>"$LOG_FILE" 2>&1
                ;;
            dnf)
                sudo dnf clean all >>"$LOG_FILE" 2>&1
                sudo dnf makecache >>"$LOG_FILE" 2>&1
                ;;
            pacman)
                sudo pacman -Syy --noconfirm >>"$LOG_FILE" 2>&1
                ;;
        esac
        return 0
    fi
    return 1
}

queue_source_build() {
    local raw_pkg="$1"
    local canonical=""
    case "$raw_pkg" in
        wayfire*) canonical="wayfire" ;;
        wlroots*) canonical="wayfire" ;;
        wf-config*) canonical="wayfire" ;;
        *plugins-extra*) canonical="wayfire-plugins-extra" ;;
        swww*) canonical="swww" ;;
        *gtk4-layer-shell*) canonical="gtk4-layer-shell" ;;
        hyprlock*) canonical="hyprlock" ;;
        yt-dlp*) canonical="yt-dlp" ;;
        *) canonical="$raw_pkg" ;;
    esac

    local existing
    for existing in "${SOURCE_BUILD_QUEUE[@]:-}"; do
        if [ "$existing" = "$canonical" ]; then
            return 0
        fi
    done
    SOURCE_BUILD_QUEUE+=("$canonical")
    log_info "Queued ${canonical} for GitHub source compilation."
}

smart_install_pkg() {
    local pkg="$1"
    local tmp_err="/tmp/aquaroot-pkg-err.log"
    local cmd=()
    case "$PKG_MGR" in
        apt)    cmd=(sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg") ;;
        dnf)    cmd=(sudo dnf install -y "$pkg") ;;
        pacman) cmd=(sudo pacman -S --needed --noconfirm "$pkg") ;;
    esac

    if "${cmd[@]}" >"$tmp_err" 2>&1; then
        cat "$tmp_err" >> "$LOG_FILE"
        log_ok "Installed package: ${pkg}"
        return 0
    else
        cat "$tmp_err" >> "$LOG_FILE"
        if grep -qi -e "Unable to locate package" -e "has no installation candidate" -e "No match for argument" -e "target not found" -e "nothing provides" "$tmp_err"; then
            log_warn "Package '${pkg}' is not precompiled in ${DISTRO_NAME} repositories."
            queue_source_build "$pkg"
            return 0
        fi

        if heal_pkg_manager_error "$tmp_err"; then
            if "${cmd[@]}" >"$tmp_err" 2>&1; then
                cat "$tmp_err" >> "$LOG_FILE"
                log_ok "Installed package after auto-repair: ${pkg}"
                return 0
            fi
        fi

        log_warn "Could not install '${pkg}' from binary repo — queuing for source build."
        queue_source_build "$pkg"
        return 0
    fi
}

# ==============================================================================
# STEP 3: Install Compiler Toolchain & Dev Headers for Source Builds
# ==============================================================================
install_build_toolchain() {
    log_info "Installing C/C++/Rust compiler toolchain & Wayland development headers..."
    case "$PKG_MGR" in
        apt)
            sudo apt-get update -y >>"$LOG_FILE" 2>&1
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
                git build-essential meson ninja-build cmake pkg-config python3-pip \
                cargo rustc glslang-tools hwdata libwayland-dev wayland-protocols \
                libegl1-mesa-dev libgles2-mesa-dev libgbm-dev libdrm-dev \
                libinput-dev libxkbcommon-dev libpixman-1-dev libcairo2-dev \
                libpango1.0-dev libglm-dev libjpeg-dev libpng-dev libwebp-dev \
                libgtk-4-dev libglib2.0-dev libglibmm-2.4-dev libevdev-dev \
                libseat-dev libudev-dev libdisplay-info-dev libliftoff-dev \
                libxcb1-dev libxcb-composite0-dev libxcb-render0-dev \
                libxcb-xfixes0-dev libxcb-xinput-dev libxcb-icccm4-dev \
                libxcb-res0-dev libx11-xcb-dev libpam0g-dev liblz4-dev \
                gobject-introspection libgirepository1.0-dev valac >>"$LOG_FILE" 2>&1
            ;;
        dnf)
            sudo dnf install -y \
                git gcc gcc-c++ meson ninja-build cmake pkgconf-pkg-config \
                cargo rust glslang hwdata-devel wayland-devel wayland-protocols-devel \
                mesa-libEGL-devel mesa-libGLES-devel mesa-libgbm-devel libdrm-devel \
                libinput-devel libxkbcommon-devel pixman-devel cairo-devel \
                pango-devel glm-devel libjpeg-turbo-devel libpng-devel \
                gtk4-devel glib2-devel glibmm24-devel libevdev-devel \
                libseat-devel systemd-devel libdisplay-info-devel libliftoff-devel \
                libxcb-devel xcb-util-wm-devel xcb-util-renderutil-devel \
                pam-devel lz4-devel gobject-introspection-devel vala >>"$LOG_FILE" 2>&1
            ;;
        pacman)
            sudo pacman -S --needed --noconfirm \
                git base-devel meson ninja cmake pkgconf rust cargo glslang \
                wayland wayland-protocols mesa libdrm libinput libxkbcommon \
                pixman cairo pango glm libjpeg-turbo libpng gtk4 glibmm \
                libevdev seatd systemd libdisplay-info libliftoff libxcb \
                xcb-util-wm xcb-util-renderutil pam lz4 gobject-introspection vala >>"$LOG_FILE" 2>&1
            ;;
    esac

    export PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/share/pkgconfig"
    log_ok "Compiler toolchain and development headers ready."
}

# ==============================================================================
# STEP 4: GitHub Source Builders (Wayfire, Plugins, Pixdecor, swww, Layer-Shell)
# ==============================================================================
build_gtk4_layer_shell_from_source() {
    log_info "Cloning & compiling gtk4-layer-shell from GitHub..."
    rm -rf "$BUILD_DIR/gtk4-layer-shell"
    git clone --depth 1 https://github.com/wmww/gtk4-layer-shell.git "$BUILD_DIR/gtk4-layer-shell" >>"$LOG_FILE" 2>&1
    pushd "$BUILD_DIR/gtk4-layer-shell" >/dev/null
    run_with_spinner "Configuring gtk4-layer-shell (meson)" \
        meson setup build --prefix=/usr --buildtype=release -Dexamples=false -Dtests=false
    run_with_spinner "Compiling gtk4-layer-shell (ninja)" \
        ninja -C build
    sudo ninja -C build install >>"$LOG_FILE" 2>&1
    sudo ldconfig
    popd >/dev/null
    log_ok "Built and installed gtk4-layer-shell."
}

build_wayfire_from_source() {
    log_info "Cloning Wayfire + wlroots + wf-config from GitHub (WayfireWM/wayfire)..."
    rm -rf "$BUILD_DIR/wayfire"
    git clone --recurse-submodules https://github.com/WayfireWM/wayfire.git "$BUILD_DIR/wayfire" >>"$LOG_FILE" 2>&1
    pushd "$BUILD_DIR/wayfire" >/dev/null

    run_with_spinner "Configuring Wayfire + bundled wlroots & wf-config (meson)" \
        meson setup build --prefix=/usr --buildtype=release \
        -Duse_system_wlroots=disabled \
        -Duse_system_wfconfig=disabled \
        -Dxwayland=enabled

    if ! run_with_spinner "Compiling Wayfire & wlroots from source (takes 3-6 minutes)" ninja -C build; then
        log_err "Wayfire compilation failed! Showing last 20 lines of log:"
        tail -n 20 "$LOG_FILE"
        popd >/dev/null
        return 1
    fi

    sudo ninja -C build install >>"$LOG_FILE" 2>&1
    sudo ldconfig
    popd >/dev/null
    log_ok "Successfully built & installed Wayfire + wlroots + wf-config from source."
}

build_wayfire_plugins_extra_from_source() {
    log_info "Cloning wayfire-plugins-extra + pixdecor from GitHub..."
    rm -rf "$BUILD_DIR/wayfire-plugins-extra"
    git clone --recurse-submodules https://github.com/WayfireWM/wayfire-plugins-extra.git "$BUILD_DIR/wayfire-plugins-extra" >>"$LOG_FILE" 2>&1
    pushd "$BUILD_DIR/wayfire-plugins-extra" >/dev/null

    run_with_spinner "Configuring wayfire-plugins-extra + pixdecor (meson)" \
        meson setup build --prefix=/usr --buildtype=release -Dpixdecor=true

    if run_with_spinner "Compiling Genie (squeezimize) & pixdecor plugins (ninja)" ninja -C build; then
        sudo ninja -C build install >>"$LOG_FILE" 2>&1
        sudo ldconfig
        log_ok "Successfully built & installed wayfire-plugins-extra + pixdecor."
    else
        log_warn "Attempting standalone pixdecor build..."
        rm -rf "$BUILD_DIR/pixdecor"
        git clone https://github.com/soreau/pixdecor.git "$BUILD_DIR/pixdecor" >>"$LOG_FILE" 2>&1
        pushd "$BUILD_DIR/pixdecor" >/dev/null
        if meson setup build --prefix=/usr --buildtype=release >>"$LOG_FILE" 2>&1; then
            if ninja -C build >>"$LOG_FILE" 2>&1; then
                sudo ninja -C build install >>"$LOG_FILE" 2>&1
            fi
        fi
        popd >/dev/null
    fi
    popd >/dev/null
}

build_swww_from_source() {
    log_info "Cloning & compiling swww wallpaper daemon from GitHub (Rust/Cargo)..."
    rm -rf "$BUILD_DIR/swww"
    git clone --depth 1 https://github.com/LGFae/swww.git "$BUILD_DIR/swww" >>"$LOG_FILE" 2>&1
    pushd "$BUILD_DIR/swww" >/dev/null
    if run_with_spinner "Compiling swww & swww-daemon (cargo build --release)" cargo build --release; then
        sudo install -Dm755 target/release/swww /usr/local/bin/swww
        sudo install -Dm755 target/release/swww-daemon /usr/local/bin/swww-daemon
        log_ok "Built and installed swww & swww-daemon to /usr/local/bin."
    else
        log_warn "swww Rust build failed; installing swaybg as lightweight fallback."
        smart_install_pkg "swaybg"
    fi
    popd >/dev/null
}

build_hyprlock_or_fallback() {
    log_info "Building Dynamic Lock Screen (hyprlock / gtklock)..."
    rm -rf "$BUILD_DIR/hyprlock"
    if git clone --depth 1 https://github.com/hyprwm/hyprlock.git "$BUILD_DIR/hyprlock" >>"$LOG_FILE" 2>&1; then
        pushd "$BUILD_DIR/hyprlock" >/dev/null
        if cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build >>"$LOG_FILE" 2>&1; then
            if cmake --build ./build --config Release --target hyprlock -j2 >>"$LOG_FILE" 2>&1; then
                sudo cmake --install build >>"$LOG_FILE" 2>&1
                popd >/dev/null
                log_ok "Built and installed hyprlock from source."
                return 0
            fi
        fi
        popd >/dev/null
    fi

    log_warn "Hyprland C++23 libs unavailable on this distro; compiling gtklock (ext-session-lock-v1) from GitHub..."
    rm -rf "$BUILD_DIR/gtklock"
    git clone --depth 1 https://github.com/jovanlanik/gtklock.git "$BUILD_DIR/gtklock" >>"$LOG_FILE" 2>&1
    pushd "$BUILD_DIR/gtklock" >/dev/null
    if meson setup build --prefix=/usr --buildtype=release >>"$LOG_FILE" 2>&1; then
        if ninja -C build >>"$LOG_FILE" 2>&1; then
            sudo ninja -C build install >>"$LOG_FILE" 2>&1
        fi
    fi
    popd >/dev/null
    if ! command -v hyprlock &>/dev/null; then
        if command -v gtklock &>/dev/null; then
            sudo ln -sf /usr/bin/gtklock /usr/local/bin/hyprlock
            log_ok "Linked gtklock -> /usr/local/bin/hyprlock."
        fi
    fi
}

build_ytdlp_binary() {
    log_info "Fetching latest precompiled yt-dlp binary directly from GitHub..."
    sudo curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
    sudo chmod a+rx /usr/local/bin/yt-dlp
    log_ok "Installed latest yt-dlp to /usr/local/bin/yt-dlp."
}

process_source_build_queue() {
    if [ "$FORCE_SOURCE" = "true" ]; then
        SOURCE_BUILD_QUEUE=("gtk4-layer-shell" "wayfire" "wayfire-plugins-extra" "swww")
    fi

    if ! command -v wayfire &>/dev/null; then queue_source_build "wayfire"; fi
    if ! command -v swww &>/dev/null; then queue_source_build "swww"; fi
    if ! command -v hyprlock &>/dev/null; then queue_source_build "hyprlock"; fi
    if ! command -v yt-dlp &>/dev/null; then queue_source_build "yt-dlp"; fi
    if ! ldconfig -p 2>/dev/null > /tmp/ldcache.txt; then true; fi
    if ! grep -q "libgtk4-layer-shell.so" /tmp/ldcache.txt 2>/dev/null; then
        queue_source_build "gtk4-layer-shell"
    fi

    local q_len="${#SOURCE_BUILD_QUEUE[@]}"
    if [ "$q_len" -eq 0 ]; then
        log_ok "All packages were installed from binary repositories! No source builds needed."
        return 0
    fi

    echo -e "\n  ${YELLOW}${BOLD}Missing Precompiled Packages Detected:${NC} ${SOURCE_BUILD_QUEUE[*]}"
    if [ "$INSTALL_MODE" = "interactive" ]; then
        prompt_choice "Compile missing packages from GitHub source now?" \
            "Yes — Automatically install build dependencies & compile from GitHub (Recommended)" \
            "Skip source compilation"
        if [ "$REPLY_INDEX" -eq 2 ]; then
            return 0
        fi
    fi

    install_build_toolchain

    local item
    for item in "${SOURCE_BUILD_QUEUE[@]}"; do
        case "$item" in
            gtk4-layer-shell)      build_gtk4_layer_shell_from_source ;;
            wayfire)               build_wayfire_from_source ;;
            wayfire-plugins-extra) build_wayfire_plugins_extra_from_source ;;
            swww)                  build_swww_from_source ;;
            hyprlock)              build_hyprlock_or_fallback ;;
            yt-dlp)                build_ytdlp_binary ;;
            *)                     log_warn "No custom source recipe for '$item', skipping." ;;
        esac
    done
}

# ==============================================================================
# STEP 5: Hardware Driver Scanner & Repository Package Installation
# ==============================================================================
scan_and_install_packages() {
    progress_bar 1 5 "Scanning CPU, GPU, Wi-Fi, Bluetooth & Firmware..."

    lscpu > /tmp/hw_cpu.txt 2>/dev/null
    lspci > /tmp/hw_pci.txt 2>/dev/null
    lsusb > /tmp/hw_usb.txt 2>/dev/null

    progress_bar 2 5 "Updating package manager caches & installing drivers..."
    case "$PKG_MGR" in
        apt)
            sudo apt-get update -y >>"$LOG_FILE" 2>&1
            PKGS=(
                firmware-linux network-manager bluez blueman pavucontrol pipewire wireplumber
                mesa-vulkan-drivers wayfire wayfire-plugins-extra xwayland swww
                mpv yt-dlp nautilus gnome-sushi foot wl-clipboard
                python3 python3-gi gir1.2-gtk-4.0 libgtk4-layer-shell0
                fprintd libpam-fprintd hyprlock imagemagick jq curl
            )
            ;;
        dnf)
            PKGS=(
                linux-firmware NetworkManager bluez blueman pavucontrol pipewire wireplumber
                mesa-dri-drivers mesa-vulkan-drivers wayfire wf-config wayfire-plugins-extra
                xorg-x11-server-Xwayland swww mpv yt-dlp nautilus sushi foot wl-clipboard
                python3 python3-gobject gtk4 gtk4-layer-shell
                fprintd fprintd-pam hyprlock ImageMagick jq curl
            )
            ;;
        pacman)
            sudo pacman -Syy >>"$LOG_FILE" 2>&1
            PKGS=(
                linux-firmware networkmanager iwd bluez bluez-utils blueman pavucontrol pipewire wireplumber
                wayfire wf-config wayfire-plugins-extra wlroots xorg-xwayland
                swww mpv yt-dlp nautilus sushi foot wl-clipboard
                python python-gobject gtk4 gtk4-layer-shell libdbusmenu-glib
                appmenu-gtk-module fprintd hyprlock imagemagick jq curl
            )
            if grep -qi "AMD" /tmp/hw_cpu.txt; then PKGS+=(amd-ucode); fi
            if grep -qi "Intel" /tmp/hw_cpu.txt; then PKGS+=(intel-ucode); fi
            if grep -qi "nvidia" /tmp/hw_pci.txt; then PKGS+=(nvidia-open-dkms nvidia-utils egl-wayland); fi
            if grep -qi -e "amd" -e "radeon" /tmp/hw_pci.txt; then PKGS+=(mesa vulkan-radeon libva-mesa-driver); fi
            if grep -qi "intel" /tmp/hw_pci.txt; then PKGS+=(mesa vulkan-intel intel-media-driver); fi
            ;;
    esac

    local pkg
    for pkg in "${PKGS[@]}"; do
        smart_install_pkg "$pkg"
    done

    sudo systemctl enable --now NetworkManager.service >>"$LOG_FILE" 2>&1
    sudo systemctl enable --now bluetooth.service >>"$LOG_FILE" 2>&1

    progress_bar 3 5 "Resolving missing packages via GitHub Source Builder..."
    process_source_build_queue
}

# ==============================================================================
# STEP 6: Deploy AquaRoot DE Configs, Liquid Glass Theme, Apps & aquaroot-cli
# ==============================================================================
deploy_aquaroot_files() {
    progress_bar 4 5 "Deploying AquaRoot DE scripts, Liquid Glass CSS & aquaroot-cli..."

    mkdir -p "$HOME/.local/bin" \
             "$HOME/.config/gtk-4.0" \
             "$HOME/.config/gtk-3.0" \
             "$HOME/.config/hypr" \
             "$HOME/.config/aquaroot" \
             "$HOME/.local/share/aquaroot/wallpapers" \
             "$HOME/.local/share/applications"

    # --- 1. ~/.config/wayfire.ini ---
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

[blur]
method = kawase
mode = normal
kawase_degrade = 3
kawase_iterations = 4
kawase_offset = 2.2
saturation = 1.35
blur_by_default = all

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
binding_terminal = <super> KEY_ENTER
command_terminal = foot
binding_lock = <super> KEY_L
command_lock = hyprlock

[autostart]
00_env = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=AquaRoot
01_wallpaper_daemon = swww-daemon
02_topbar = ~/.local/bin/aquaroot-topbar.py
03_dock = ~/.local/bin/aquaroot-dock.py
04_wallpaper_sync = ~/.local/bin/aquaroot-wallpaper.sh --restore
05_welcome = ~/.local/bin/aquaroot-welcome.py
EOF

    # --- 2. ~/.config/gtk-4.0/gtk.css ---
    cat << 'EOF' > "$HOME/.config/gtk-4.0/gtk.css"
/* AQUAROOT_DYNAMIC_VARS_START */
@define-color liquid_bg rgba(22, 26, 36, 0.52);
@define-color liquid_surface rgba(255, 255, 255, 0.12);
@define-color liquid_highlight rgba(255, 255, 255, 0.55);
@define-color liquid_border rgba(255, 255, 255, 0.25);
@define-color aqua_accent #0A84FF;
@define-color text_primary #F5F7FA;
/* AQUAROOT_DYNAMIC_VARS_END */

.liquid-glass,
popover.background > contents,
window.nautilus-window .sidebar-pane,
window#org-gnome-NautilusPreviewer,
.sushi-window {
    background-color: @liquid_bg;
    background-image: linear-gradient(
        135deg,
        rgba(255, 255, 255, 0.24),
        rgba(255, 255, 255, 0.05),
        rgba(255, 255, 255, 0.12)
    );
    border-radius: 16px;
    border: 1px solid @liquid_border;
    box-shadow:
        inset 0 1px 1px 0 @liquid_highlight,
        inset 1px 0 1px 0 rgba(255, 255, 255, 0.25),
        0 14px 34px rgba(0, 0, 0, 0.42);
    color: @text_primary;
}

window#aquaroot-topbar {
    background: transparent;
}

.topbar-capsule {
    background-color: @liquid_bg;
    background-image: linear-gradient(
        180deg,
        rgba(255, 255, 255, 0.28),
        rgba(255, 255, 255, 0.06)
    );
    border-radius: 999px;
    border: 1px solid @liquid_border;
    box-shadow:
        inset 0 1px 1.5px @liquid_highlight,
        0 6px 20px rgba(0, 0, 0, 0.35);
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

window.nautilus-window {
    background-color: @liquid_bg;
    border-radius: 14px;
}

window.nautilus-window .navigation-sidebar {
    background-color: transparent;
    padding: 8px;
}

window.nautilus-window .navigation-sidebar row {
    border-radius: 10px;
    margin: 2px 4px;
    padding: 6px 10px;
    transition: all 150ms ease;
}

window.nautilus-window .navigation-sidebar row:selected {
    background-color: rgba(10, 132, 255, 0.75);
    box-shadow:
        inset 0 1px 1px rgba(255, 255, 255, 0.55),
        0 4px 12px rgba(10, 132, 255, 0.35);
    color: #FFFFFF;
    font-weight: 600;
}

window.nautilus-window .view {
    background-color: rgba(18, 20, 26, 0.88);
    border-top-left-radius: 12px;
}

headerbar {
    background: @liquid_bg;
    box-shadow: inset 0 1px 0 @liquid_highlight;
    border-bottom: 1px solid @liquid_border;
}
EOF
    ln -sf "$HOME/.config/gtk-4.0/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"

    # --- 3. ~/.local/bin/aquaroot-glass-ctl.py ---
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

    # --- 4. ~/.local/bin/aquaroot-topbar.py ---
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-topbar.py"
#!/usr/bin/env python3
import os
import json
import socket
import datetime
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
        self.track_label.set_max_width_chars(20)
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
        pop_box.set_margin_top(12)
        pop_box.set_margin_bottom(12)
        pop_box.set_margin_start(12)
        pop_box.set_margin_end(12)
        pop_box.set_size_request(300, -1)

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
                payload = json.dumps({"command": cmd_list}) + "\n"
                s.sendall(payload.encode("utf-8"))
        except OSError:
            pass

    def on_search_activate(self, entry):
        query = entry.get_text().strip()
        if not query:
            return
        self.track_label.set_text("Loading stream...")
        threading.Thread(target=self._stream_yt, args=(query,), daemon=True).start()

    def _stream_yt(self, query):
        subprocess.run(["pkill", "-f", MPV_SOCKET], stderr=subprocess.DEVNULL)
        target = query if query.startswith("http") else f"ytsearch1:{query}"
        try:
            title_out = subprocess.check_output(
                ["yt-dlp", "--get-title", "-f", "bestaudio", target],
                text=True,
            ).strip().splitlines()[0]
        except Exception:
            title_out = query

        GLib.idle_add(self.track_label.set_text, title_out)
        GLib.idle_add(self.play_btn.set_icon_name, "media-playback-pause-symbolic")
        self.is_playing = True

        subprocess.Popen(
            [
                "mpv",
                "--no-video",
                f"--input-ipc-server={MPV_SOCKET}",
                f"--volume={int(self.vol_scale.get_value())}",
                "--ytdl-format=bestaudio",
                target,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def toggle_pause(self, _btn):
        self._send_mpv_cmd(["cycle", "pause"])
        self.is_playing = not self.is_playing
        icon = "media-playback-pause-symbolic" if self.is_playing else "media-playback-start-symbolic"
        self.play_btn.set_icon_name(icon)

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
        self.stat_label = Gtk.Label(label="CPU 0  GPU 0  RAM 0  40°C")
        box.append(icon)
        box.append(self.stat_label)
        self.set_child(box)

        pop = Gtk.Popover()
        pop_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        pop_box.set_margin_top(12)
        pop_box.set_margin_bottom(12)
        pop_box.set_margin_start(14)
        pop_box.set_margin_end(14)
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
            if diff_total == 0:
                return 0
            return int(100.0 * (1.0 - diff_idle / diff_total))
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
        pct = chr(37)

        self.stat_label.set_markup(
            f"<small><b>CPU</b> {cpu}{pct}  <b>GPU</b> {gpu}{pct}  <b>RAM</b> {ram_pct}{pct}  <b>{temp}°C</b></small>"
        )
        self.cpu_bar.set_value(cpu)
        self.gpu_bar.set_value(gpu)
        self.ram_bar.set_value(ram_pct)
        self.detail_lbl.set_markup(
            f"<small>RAM: {ram_used_mb} MB / {ram_tot_mb} MB\nCore Thermal: {temp}°C</small>"
        )
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

        left_capsule = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        left_capsule.add_css_class("topbar-capsule")

        distro_name, distro_icon = get_distro_info()
        distro_btn = Gtk.MenuButton()
        distro_btn.set_has_frame(False)
        distro_img = Gtk.Image.new_from_icon_name(distro_icon)
        distro_btn.set_child(distro_img)
        distro_btn.set_popover(self._build_system_popover(distro_name))
        left_capsule.append(distro_btn)

        self.app_title = Gtk.Label()
        self.app_title.set_markup("<b>Finder</b>")
        self.app_title.set_margin_start(6)
        self.app_title.set_margin_end(8)
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

        right_capsule = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        right_capsule.add_css_class("topbar-capsule")

        self.yt_widget = YouTubeAudioWidget()
        right_capsule.append(self.yt_widget)

        self.telemetry_widget = SystemTelemetryWidget()
        right_capsule.append(self.telemetry_widget)

        spot_btn = Gtk.Button.new_from_icon_name("system-search-symbolic")
        spot_btn.set_has_frame(False)
        spot_btn.set_tooltip_text("Spotlight Search (Super+Space)")
        spot_btn.connect("clicked", lambda _: subprocess.Popen([os.path.expanduser("~/.local/bin/aquaroot-spotlight.py")]))
        right_capsule.append(spot_btn)

        wall_btn = Gtk.Button.new_from_icon_name("preferences-desktop-wallpaper-symbolic")
        wall_btn.set_has_frame(False)
        wall_btn.set_tooltip_text("Fetch Online 4K Wallpaper")
        wall_btn.connect("clicked", lambda _: subprocess.Popen([os.path.expanduser("~/.local/bin/aquaroot-wallpaper.sh"), "--online"]))
        right_capsule.append(wall_btn)

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
            ("AquaRoot System Settings...", [os.path.expanduser("~/.local/bin/aquaroot-settings.py")]),
            ("AquaRoot Interactive CLI...", ["foot", "-e", os.path.expanduser("~/.local/bin/aquaroot-cli")]),
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
            "File": [("New Finder Window", ["nautilus", "--new-window"]), ("Spotlight Search", [os.path.expanduser("~/.local/bin/aquaroot-spotlight.py")])],
            "Edit": [("Settings", [os.path.expanduser("~/.local/bin/aquaroot-settings.py")])],
            "View": [("Toggle High-Contrast Glass", [os.path.expanduser("~/.local/bin/aquaroot-glass-ctl.py"), "reduce_transparency=true"]),
                     ("Restore Liquid Glass", [os.path.expanduser("~/.local/bin/aquaroot-glass-ctl.py"), "reduce_transparency=false"])],
            "Go": [("Home Folder", ["nautilus"]), ("Terminal", ["foot"])],
            "Window": [("System Settings", [os.path.expanduser("~/.local/bin/aquaroot-settings.py")])],
            "Help": [("Welcome Tour", [os.path.expanduser("~/.local/bin/aquaroot-welcome.py"), "--force"])],
        }
        for label, cmd in shortcuts.get(section, []):
            row = Gtk.Button(label=label)
            row.set_has_frame(False)
            row.connect("clicked", lambda _, c=cmd: subprocess.Popen(c))
            box.append(row)
        pop.set_child(box)
        return pop

    def _update_clock(self):
        now = datetime.datetime.now()
        self.clock_lbl.set_markup(f"<b>{now.ctime()[:16]}</b>")
        return True


if __name__ == "__main__":
    AquaRootTopBar().run(None)
EOF

    # --- 5. ~/.local/bin/aquaroot-dock.py ---
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
    ("Terminal", "utilities-terminal", ["foot"]),
    ("Settings", "preferences-system", [os.path.expanduser("~/.local/bin/aquaroot-settings.py")]),
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
        self.dock_box.set_margin_top(16)
        self.dock_box.set_margin_bottom(8)
        self.dock_box.set_margin_start(16)
        self.dock_box.set_margin_end(16)

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

    # --- 6. ~/.local/bin/aquaroot-spotlight.py ---
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-spotlight.py"
#!/usr/bin/env python3
import os
import math
import glob
import shlex
import subprocess
import configparser
from ctypes import CDLL

CDLL("libgtk4-layer-shell.so")

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gdk, Gtk4LayerShell


def load_desktop_apps():
    apps = []
    dirs = ["/usr/share/applications", os.path.expanduser("~/.local/share/applications")]
    seen = set()
    for d in dirs:
        for path in glob.glob(os.path.join(d, "*.desktop")):
            cp = configparser.ConfigParser(interpolation=None)
            try:
                cp.read(path)
                sec = cp["Desktop Entry"]
                if sec.get("NoDisplay", "false").lower() == "true":
                    continue
                name = sec.get("Name")
                exec_cmd = sec.get("Exec", "")
                icon = sec.get("Icon", "application-x-executable")
                if name and exec_cmd and name not in seen:
                    seen.add(name)
                    clean_cmd = [p for p in shlex.split(exec_cmd) if not p.startswith(chr(37))]
                    apps.append({"name": name, "cmd": clean_cmd, "icon": icon})
            except Exception:
                continue
    return apps


class AquaRootSpotlight(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aquaroot.Spotlight")
        self.apps = load_desktop_apps()
        self.results = []

    def do_activate(self):
        self.win = Gtk.ApplicationWindow(application=self)
        self.win.set_name("aquaroot-topbar")

        Gtk4LayerShell.init_for_window(self.win)
        Gtk4LayerShell.set_layer(self.win, Gtk4LayerShell.Layer.OVERLAY)
        Gtk4LayerShell.set_keyboard_mode(self.win, Gtk4LayerShell.KeyboardMode.EXCLUSIVE)
        Gtk4LayerShell.set_anchor(self.win, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_margin(self.win, Gtk4LayerShell.Edge.TOP, 180)

        key_ctrl = Gtk.EventControllerKey.new()
        key_ctrl.connect("key-pressed", self.on_key_pressed)
        self.win.add_controller(key_ctrl)

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        main_box.add_css_class("liquid-glass")
        main_box.set_size_request(680, -1)
        main_box.set_margin_top(10)
        main_box.set_margin_bottom(10)
        main_box.set_margin_start(14)
        main_box.set_margin_end(14)

        search_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        search_row.set_margin_top(10)
        search_row.set_margin_bottom(8)
        search_row.set_margin_start(12)
        search_row.set_margin_end(12)

        mag_icon = Gtk.Image.new_from_icon_name("system-search-symbolic")
        mag_icon.set_pixel_size(28)
        search_row.append(mag_icon)

        self.entry = Gtk.Entry()
        self.entry.set_placeholder_text("Spotlight Search (Apps, Files, or Math)...")
        self.entry.set_hexpand(True)
        self.entry.set_has_frame(False)
        self.entry.connect("changed", self.on_query_changed)
        self.entry.connect("activate", self.on_activate_first)
        search_row.append(self.entry)
        main_box.append(search_row)

        self.listbox = Gtk.ListBox()
        self.listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.listbox.connect("row-activated", self.on_row_activated)
        self.listbox.set_visible(False)
        main_box.append(self.listbox)

        self.win.set_child(main_box)
        self.win.present()
        self.entry.grab_focus()

    def on_key_pressed(self, _ctrl, keyval, _keycode, _state):
        if keyval == Gdk.KEY_Escape:
            self.quit()
            return True
        return False

    def on_query_changed(self, entry):
        q = entry.get_text().strip()
        while (child := self.listbox.get_first_child()) is not None:
            self.listbox.remove(child)
        self.results.clear()

        if not q:
            self.listbox.set_visible(False)
            return

        if any(op in q for op in ["+", "-", "*", "/", "^"]) and q[0].isdigit():
            try:
                val = eval(q.replace("^", "**"), {"__builtins__": None}, vars(math))
                self._add_result_row(f"= {val}", "accessories-calculator", ["wl-copy", str(val)], "Calculator (Enter to Copy)")
            except Exception:
                pass

        ql = q.lower()
        for app in self.apps:
            if ql in app["name"].lower():
                self._add_result_row(app["name"], app["icon"], app["cmd"], "Application")
                if len(self.results) >= 6:
                    break

        if len(q) >= 3 and len(self.results) < 8:
            try:
                out = subprocess.check_output(
                    ["find", os.path.expanduser("~"), "-maxdepth", "3", "-not", "-path", "*/.*", "-iname", f"*{q}*"],
                    text=True, stderr=subprocess.DEVNULL, timeout=0.25
                ).splitlines()
                for path in out[:3]:
                    fname = os.path.basename(path)
                    self._add_result_row(fname, "folder" if os.path.isdir(path) else "text-x-generic", ["xdg-open", path], path)
            except Exception:
                pass

        self.listbox.set_visible(len(self.results) > 0)

    def _add_result_row(self, title, icon_name, cmd, subtitle):
        row_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row_box.set_margin_top(6)
        row_box.set_margin_bottom(6)
        row_box.set_margin_start(10)
        row_box.set_margin_end(10)

        img = Gtk.Image.new_from_icon_name(icon_name)
        img.set_pixel_size(32)
        row_box.append(img)

        text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        lbl = Gtk.Label(xalign=0)
        lbl.set_markup(f"<b>{title}</b>")
        sub = Gtk.Label(label=subtitle, xalign=0)
        sub.set_opacity(0.65)
        text_box.append(lbl)
        text_box.append(sub)
        row_box.append(text_box)

        self.listbox.append(row_box)
        self.results.append(cmd)

    def on_activate_first(self, _entry):
        if self.results:
            subprocess.Popen(self.results[0])
            self.quit()

    def on_row_activated(self, _listbox, row):
        idx = row.get_index()
        if 0 <= idx < len(self.results):
            subprocess.Popen(self.results[idx])
            self.quit()


if __name__ == "__main__":
    AquaRootSpotlight().run(None)
EOF

    # --- 7. ~/.local/bin/aquaroot-settings.py ---
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-settings.py"
#!/usr/bin/env python3
import os
import json
import subprocess
from pathlib import Path
import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk

GLASS_CTL = os.path.expanduser("~/.local/bin/aquaroot-glass-ctl.py")
WALL_SH = os.path.expanduser("~/.local/bin/aquaroot-wallpaper.sh")
GLASS_JSON = Path.home() / ".config" / "aquaroot" / "glass.json"


class AquaRootSettings(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.aquaroot.Settings")

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        win.set_title("AquaRoot System Settings")
        win.set_default_size(820, 560)
        win.add_css_class("liquid-glass")

        root = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)

        stack = Gtk.Stack()
        stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        stack.set_hexpand(True)

        sidebar = Gtk.StackSidebar()
        sidebar.set_stack(stack)
        sidebar.set_size_request(210, -1)

        stack.add_titled(self._build_glass_page(), "glass", "Liquid Glass & Readability")
        stack.add_titled(self._build_wallpaper_page(), "wallpaper", "Wallpaper & Style")
        stack.add_titled(self._build_biometrics_page(), "security", "Face ID & Touch ID")
        stack.add_titled(self._build_hardware_page(), "hardware", "Wi-Fi, Bluetooth & Audio")

        root.append(sidebar)
        root.append(stack)
        win.set_child(root)
        win.present()

    def _load_glass(self):
        if GLASS_JSON.exists():
            try:
                return json.loads(GLASS_JSON.read_text())
            except Exception:
                pass
        return {"opacity": 0.52, "blur_iterations": 4, "blur_offset": 2.2, "specular_intensity": 0.55, "reduce_transparency": False, "tint_mode": "dark"}

    def _build_glass_page(self):
        cfg = self._load_glass()
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_margin_top(24)
        box.set_margin_start(28)
        box.set_margin_end(28)

        hdr = Gtk.Label(xalign=0)
        hdr.set_markup("<span size='x-large'><b>Liquid Glass &amp; Readability</b></span>\n<small>Tune refraction, backdrop blur, or boost contrast if text is hard to read.</small>")
        box.append(hdr)

        rt_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        rt_lbl = Gtk.Label(label="Reduce Transparency (High Contrast Readability Mode)", xalign=0, hexpand=True)
        rt_switch = Gtk.Switch()
        rt_switch.set_active(cfg.get("reduce_transparency", False))
        rt_switch.connect("notify::active", lambda sw, _: subprocess.Popen([GLASS_CTL, f"reduce_transparency={sw.get_active()}"]))
        rt_row.append(rt_lbl)
        rt_row.append(rt_switch)
        box.append(rt_row)

        box.append(Gtk.Label(label="Glass Surface Opacity (Higher = Easier to Read Text)", xalign=0))
        op_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0.25, 0.95, 0.05)
        op_scale.set_value(cfg.get("opacity", 0.52))
        op_scale.connect("value-changed", lambda s: subprocess.Popen([GLASS_CTL, f"opacity={s.get_value():.2f}"]))
        box.append(op_scale)

        box.append(Gtk.Label(label="Background Blur Intensity (Kawase Passes)", xalign=0))
        blur_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 1, 8, 1)
        blur_scale.set_value(cfg.get("blur_iterations", 4))
        blur_scale.connect("value-changed", lambda s: subprocess.Popen([GLASS_CTL, f"blur_iterations={int(s.get_value())}"]))
        box.append(blur_scale)

        box.append(Gtk.Label(label="Liquid Glass Specular Rim Highlight", xalign=0))
        spec_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0.0, 1.0, 0.05)
        spec_scale.set_value(cfg.get("specular_intensity", 0.55))
        spec_scale.connect("value-changed", lambda s: subprocess.Popen([GLASS_CTL, f"specular_intensity={s.get_value():.2f}"]))
        box.append(spec_scale)

        tint_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        dark_btn = Gtk.Button(label="Dark Obsidian Glass")
        dark_btn.connect("clicked", lambda _: subprocess.Popen([GLASS_CTL, "tint_mode=dark"]))
        light_btn = Gtk.Button(label="Light Frost Glass")
        light_btn.connect("clicked", lambda _: subprocess.Popen([GLASS_CTL, "tint_mode=light"]))
        tint_box.append(dark_btn)
        tint_box.append(light_btn)
        box.append(tint_box)

        return box

    def _build_wallpaper_page(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        box.set_margin_top(24)
        box.set_margin_start(28)
        box.set_margin_end(28)

        hdr = Gtk.Label(xalign=0)
        hdr.set_markup("<span size='x-large'><b>Wallpaper &amp; Online Collections</b></span>")
        box.append(hdr)

        query_entry = Gtk.Entry()
        query_entry.set_placeholder_text("Enter theme (e.g., macos+liquid+4k, mountains, abstract)...")
        box.append(query_entry)

        fetch_btn = Gtk.Button(label="Fetch & Apply 4K Online Wallpaper")
        fetch_btn.connect(
            "clicked",
            lambda _: subprocess.Popen([WALL_SH, "--online", query_entry.get_text().strip() or "macos+liquid+4k"])
        )
        box.append(fetch_btn)
        return box

    def _build_biometrics_page(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        box.set_margin_top(24)
        box.set_margin_start(28)
        box.set_margin_end(28)

        hdr = Gtk.Label(xalign=0)
        hdr.set_markup("<span size='x-large'><b>Face ID &amp; Touch ID</b></span>\n<small>Configure biometric authentication for the AquaRoot Dynamic Lock Screen.</small>")
        box.append(hdr)

        face_btn = Gtk.Button(label="Enroll Face ID (Howdy IR / Webcam)")
        face_btn.connect("clicked", lambda _: subprocess.Popen(["foot", "-e", "sudo", "howdy", "add"]))
        box.append(face_btn)

        fp_btn = Gtk.Button(label="Enroll Touch ID (fprintd Fingerprint Sensor)")
        fp_btn.connect("clicked", lambda _: subprocess.Popen(["foot", "-e", "fprintd-enroll"]))
        box.append(fp_btn)

        lock_btn = Gtk.Button(label="Test Dynamic Lock Screen Now")
        lock_btn.connect("clicked", lambda _: subprocess.Popen(["hyprlock"]))
        box.append(lock_btn)
        return box

    def _build_hardware_page(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        box.set_margin_top(24)
        box.set_margin_start(28)
        box.set_margin_end(28)

        hdr = Gtk.Label(xalign=0)
        hdr.set_markup("<span size='x-large'><b>Wi-Fi, Bluetooth &amp; Sound</b></span>")
        box.append(hdr)

        wifi_btn = Gtk.Button(label="Open Network & Wi-Fi Manager (nmtui)")
        wifi_btn.connect("clicked", lambda _: subprocess.Popen(["foot", "-e", "nmtui"]))
        box.append(wifi_btn)

        bt_btn = Gtk.Button(label="Open Bluetooth Device Manager (blueman)")
        bt_btn.connect("clicked", lambda _: subprocess.Popen(["blueman-manager"]))
        box.append(bt_btn)

        audio_btn = Gtk.Button(label="Open PipeWire Audio Mixer (pavucontrol)")
        audio_btn.connect("clicked", lambda _: subprocess.Popen(["pavucontrol"]))
        box.append(audio_btn)
        return box


if __name__ == "__main__":
    AquaRootSettings().run(None)
EOF

    # --- 8. ~/.local/bin/aquaroot-welcome.py ---
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
        win.set_title("Welcome to AquaRoot")
        win.set_default_size(640, 440)
        win.add_css_class("liquid-glass")

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.stack.set_transition_duration(350)

        p1 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18, valign=Gtk.Align.CENTER)
        p1.set_margin_start(40)
        p1.set_margin_end(40)
        hello = Gtk.Label()
        hello.set_markup("<span size='xx-large'><b>Hello.</b></span>\n<span size='large'>Welcome to <b>AquaRoot DE</b></span>")
        hello.set_justify(Gtk.Justification.CENTER)
        desc = Gtk.Label(label="Experience Liquid Glass aesthetics, Genie window physics, Spotlight search (Super+Space), and QuickLook file previews (Spacebar) on top of wlroots.")
        desc.set_wrap(True)
        desc.set_justify(Gtk.Justification.CENTER)
        next1 = Gtk.Button(label="Continue →", halign=Gtk.Align.CENTER)
        next1.connect("clicked", lambda _: self.stack.set_visible_child_name("page2"))
        p1.append(hello)
        p1.append(desc)
        p1.append(next1)

        p2 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14, valign=Gtk.Align.CENTER)
        p2.set_margin_start(40)
        p2.set_margin_end(40)
        p2_title = Gtk.Label()
        p2_title.set_markup("<span size='x-large'><b>Choose Your Liquid Glass Style</b></span>\n<small>You can adjust opacity and blur anytime in AquaRoot Settings.</small>")
        p2_title.set_justify(Gtk.Justification.CENTER)

        btn_ultra = Gtk.Button(label="Ultra-Clear Liquid Glass (0.45 Opacity, High Refraction)")
        btn_ultra.connect("clicked", lambda _: subprocess.Popen([GLASS_CTL, "opacity=0.45", "reduce_transparency=false"]))

        btn_balanced = Gtk.Button(label="Balanced Aqua Glass (0.55 Opacity — Recommended)")
        btn_balanced.connect("clicked", lambda _: subprocess.Popen([GLASS_CTL, "opacity=0.55", "reduce_transparency=false"]))

        btn_readable = Gtk.Button(label="High-Contrast Readability Glass (0.85 Opacity)")
        btn_readable.connect("clicked", lambda _: subprocess.Popen([GLASS_CTL, "opacity=0.85", "reduce_transparency=false"]))

        next2 = Gtk.Button(label="Continue →", halign=Gtk.Align.CENTER)
        next2.connect("clicked", lambda _: self.stack.set_visible_child_name("page3"))

        for w in [p2_title, btn_ultra, btn_balanced, btn_readable, next2]:
            p2.append(w)

        p3 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16, valign=Gtk.Align.CENTER)
        p3.set_margin_start(40)
        p3.set_margin_end(40)
        p3_title = Gtk.Label()
        p3_title.set_markup("<span size='x-large'><b>Your Desktop is Ready</b></span>")
        wall_btn = Gtk.Button(label="Download First 4K Liquid Wallpaper", halign=Gtk.Align.CENTER)
        wall_btn.connect("clicked", lambda _: subprocess.Popen([WALL_SH, "--online"]))

        finish_btn = Gtk.Button(label="Get Started", halign=Gtk.Align.CENTER)
        finish_btn.connect("clicked", self.finish_onboarding)
        p3.append(p3_title)
        p3.append(wall_btn)
        p3.append(finish_btn)

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

    # --- 9. ~/.local/bin/aquaroot-wallpaper.sh ---
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-wallpaper.sh"
#!/usr/bin/env bash
set -uo pipefail

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
            --transition-fps 120
    elif command -v swaybg &>/dev/null; then
        pkill swaybg 2>/dev/null
        swaybg -i "$img" -m fill &
    fi
}

case "${1:---online}" in
    --online)
        Query="${2:-macos+abstract+liquid+4k}"
        curl -s "https://wallhaven.cc/api/v1/search?q=${Query}&atleast=3840x2160&sorting=random" -o /tmp/aquaroot-wall.json
        IMG_URL=$(jq -r '.data[0].path' /tmp/aquaroot-wall.json 2>/dev/null)
        if [ -n "$IMG_URL" ] && [ "$IMG_URL" != "null" ]; then
            DEST="$WALL_DIR/wall_latest.jpg"
            curl -sL "$IMG_URL" -o "$DEST"
            apply_wallpaper "$DEST"
        fi
        ;;
    --restore)
        if [ -f "$CURRENT_LINK" ]; then
            apply_wallpaper "$CURRENT_LINK"
        else
            convert -size 3840x2160 plasma:fractal -blur 0x25 "$WALL_DIR/default_aqua.jpg" 2>/dev/null
            if [ -f "$WALL_DIR/default_aqua.jpg" ]; then
                apply_wallpaper "$WALL_DIR/default_aqua.jpg"
            fi
        fi
        ;;
    *)
        if [ -f "$1" ]; then
            apply_wallpaper "$1"
        fi
        ;;
esac
EOF

    # --- 10. Permanent Interactive CLI Utility (~/.local/bin/aquaroot-cli) ---
    cat << 'EOF' > "$HOME/.local/bin/aquaroot-cli"
#!/usr/bin/env bash
set -uo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

GLASS_CTL="$HOME/.local/bin/aquaroot-glass-ctl.py"
WALL_SH="$HOME/.local/bin/aquaroot-wallpaper.sh"

show_status() {
    echo -e "\n${CYAN}${BOLD}=== AquaRoot DE System Health & Binary Check ===${NC}"
    local bin
    for bin in wayfire swww hyprlock yt-dlp mpv nautilus foot; do
        if command -v "$bin" &>/dev/null; then
            echo -e "  ${GREEN}[OK]${NC}    $bin: $(command -v "$bin")"
        else
            echo -e "  ${RED}[MISS]${NC}  $bin: MISSING"
        fi
    done
    ldconfig -p > /tmp/ldcache.txt 2>/dev/null
    if grep -q "libgtk4-layer-shell.so" /tmp/ldcache.txt 2>/dev/null; then
        echo -e "  ${GREEN}[OK]${NC}    libgtk4-layer-shell.so: Installed"
    else
        echo -e "  ${RED}[MISS]${NC}  libgtk4-layer-shell.so: MISSING"
    fi
}

while true; do
    echo -e "\n${CYAN}${BOLD}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║           AquaRoot DE — Interactive CLI Tool           ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════╝${NC}"
    echo -e "  ${CYAN}[1]${NC} Check AquaRoot Component & Driver Status"
    echo -e "  ${CYAN}[2]${NC} Switch Liquid Glass Preset (Ultra-Clear / Balanced / High-Contrast)"
    echo -e "  ${CYAN}[3]${NC} Fetch & Apply New 4K Online Wallpaper"
    echo -e "  ${CYAN}[4]${NC} Restart Top Bar & Magnification Dock"
    echo -e "  ${CYAN}[5]${NC} Enroll Face ID (Howdy) or Touch ID (fprintd)"
    echo -e "  ${CYAN}[6]${NC} Exit"
    read -rp "  Select action [1-6]: " act
    case "${act:-6}" in
        1) show_status ;;
        2)
            read -rp "  Choose preset (1=Ultra-Clear 0.45, 2=Balanced 0.55, 3=High-Contrast 0.90): " p
            if [ "$p" = "1" ]; then "$GLASS_CTL" opacity=0.45 reduce_transparency=false; fi
            if [ "$p" = "2" ]; then "$GLASS_CTL" opacity=0.55 reduce_transparency=false; fi
            if [ "$p" = "3" ]; then "$GLASS_CTL" opacity=0.90 reduce_transparency=true; fi
            echo -e "  ${GREEN}Applied Liquid Glass preset.${NC}"
            ;;
        3)
            read -rp "  Enter search tag (default: macos+liquid+4k): " tag
            "$WALL_SH" --online "${tag:-macos+liquid+4k}"
            ;;
        4)
            pkill -f aquaroot-topbar.py 2>/dev/null
            pkill -f aquaroot-dock.py 2>/dev/null
            nohup "$HOME/.local/bin/aquaroot-topbar.py" >/dev/null 2>&1 &
            nohup "$HOME/.local/bin/aquaroot-dock.py" >/dev/null 2>&1 &
            echo -e "  ${GREEN}Top Bar and Dock restarted.${NC}"
            ;;
        5)
            read -rp "  Enroll (1) Face ID or (2) Fingerprint? " bio
            if [ "$bio" = "1" ]; then sudo howdy add; fi
            if [ "$bio" = "2" ]; then fprintd-enroll; fi
            ;;
        6) exit 0 ;;
    esac
done
EOF

    # --- 11. ~/.config/hypr/hyprlock.conf & PAM ---
    cat << 'EOF' > "$HOME/.config/hypr/hyprlock.conf"
general {
    hide_cursor = false
    grace = 1
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

    cat << 'EOF' > /tmp/aquaroot-pam
auth       sufficient   pam_howdy.so
auth       sufficient   pam_fprintd.so
auth       include      system-auth
EOF
    sudo cp /tmp/aquaroot-pam /etc/pam.d/hyprlock

    cat << EOF > "$HOME/.local/share/applications/aquaroot-settings.desktop"
[Desktop Entry]
Name=AquaRoot Settings
Comment=Configure Liquid Glass, Readability, Wallpaper & Biometrics
Exec=$HOME/.local/bin/aquaroot-settings.py
Icon=preferences-system
Terminal=false
Type=Application
Categories=Settings;System;
EOF

    chmod +x "$HOME/.local/bin/"aquaroot-*
    gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:' 2>/dev/null
    "$HOME/.local/bin/aquaroot-glass-ctl.py"

    sudo mkdir -p /usr/share/wayland-sessions
    cat << 'EOF' > /tmp/aquaroot.desktop
[Desktop Entry]
Name=AquaRoot (Liquid Glass)
Comment=macOS-inspired Liquid Glass Desktop Environment on wlroots
Exec=/usr/bin/env XDG_CURRENT_DESKTOP=AquaRoot GTK_MODULES=appmenu-gtk-module wayfire
Type=Application
DesktopNames=AquaRoot;wlroots;
EOF
    sudo cp /tmp/aquaroot.desktop /usr/share/wayland-sessions/aquaroot.desktop

    progress_bar 5 5 "AquaRoot DE v2.2 Installation Complete!"
}

# ==============================================================================
# MAIN EXECUTION FLOW
# ==============================================================================
show_main_menu
detect_distro

if [ "$INSTALL_MODE" = "repair" ]; then
    install_build_toolchain
    FORCE_SOURCE="true"
    process_source_build_queue
    deploy_aquaroot_files
else
    scan_and_install_packages
    deploy_aquaroot_files
fi

echo -e "\n  ${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "  ${GREEN}${BOLD}║  AquaRoot DE v0.1 is ready!                                          ║${NC}"
echo -e "  ${GREEN}${BOLD}║  • Run '~/.local/bin/aquaroot-cli' anytime to manage your desktop.   ║${NC}"
echo -e "  ${GREEN}${BOLD}║  • Log out and select 'AquaRoot (Liquid Glass)' at login.            ║${NC}"
echo -e "  ${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}\n"
