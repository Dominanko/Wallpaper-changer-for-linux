#!/bin/bash

# Wallpaper Changer Script for Linux
# Supports GNOME and KDE Plasma desktop environments
# Usage: ./wallpaper_changer.sh [options]

VERSION="1.0"
CONFIG_FILE="$HOME/.config/wallpaper_changer.conf"
DEFAULT_INTERVAL=300 # 5 minutes in seconds

# Detect desktop environment
detect_de() {
    if [ "$XDG_CURRENT_DESKTOP" = "GNOME" ] || [ "$XDG_CURRENT_DESKTOP" = "ubuntu:GNOME" ]; then
        echo "gnome"
    elif [ "$XDG_CURRENT_DESKTOP" = "KDE" ]; then
        echo "kde"
    else
        # Try to detect by process
        if pgrep -x "gnome-shell" > /dev/null; then
            echo "gnome"
        elif pgrep -x "plasmashell" > /dev/null; then
            echo "kde"
        else
            echo "unknown"
        fi
    fi
}

DE=$(detect_de)

# Set wallpaper function
set_wallpaper() {
    local wallpaper="$1"
    
    if [ ! -f "$wallpaper" ]; then
        echo "Error: File '$wallpaper' does not exist."
        return 1
    fi

    case $DE in
        "gnome")
            gsettings set org.gnome.desktop.background picture-uri "file://$wallpaper"
            gsettings set org.gnome.desktop.background picture-uri-dark "file://$wallpaper"
            ;;
        "kde")
            qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
                var allDesktops = desktops();
                for (i=0;i<allDesktops.length;i++) {
                    d = allDesktops[i];
                    d.wallpaperPlugin = 'org.kde.image';
                    d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');
                    d.writeConfig('Image', 'file://$wallpaper');
                }
            "
            ;;
        *)
            echo "Unsupported desktop environment: $DE"
            return 1
            ;;
    esac
    
    echo "Wallpaper set to: $wallpaper"
    return 0
}

# Random wallpaper from directory
random_wallpaper() {
    local dir="$1"
    
    if [ ! -d "$dir" ]; then
        echo "Error: Directory '$dir' does not exist."
        return 1
    fi

    # Get list of image files
    local wallpapers=($(find "$dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" \)))
    
    if [ ${#wallpapers[@]} -eq 0 ]; then
        echo "Error: No image files found in '$dir'."
        return 1
    fi

    # Select random wallpaper
    local random_index=$((RANDOM % ${#wallpapers[@]}))
    local selected_wallpaper="${wallpapers[$random_index]}"
    
    set_wallpaper "$selected_wallpaper"
    return $?
}

# Slideshow mode
slideshow() {
    local dir="$1"
    local interval="${2:-$DEFAULT_INTERVAL}"
    
    if [ ! -d "$dir" ]; then
        echo "Error: Directory '$dir' does not exist."
        return 1
    fi

    echo "Starting slideshow from directory: $dir"
    echo "Changing wallpaper every $interval seconds"
    echo "Press Ctrl+C to stop"

    while true; do
        random_wallpaper "$dir"
        sleep "$interval"
    done
}

# Save configuration
save_config() {
    local dir="$1"
    local interval="$2"
    
    mkdir -p "$(dirname "$CONFIG_FILE")"
    echo "WALLPAPER_DIR=\"$dir\"" > "$CONFIG_FILE"
    echo "INTERVAL=$interval" >> "$CONFIG_FILE"
    echo "Configuration saved to $CONFIG_FILE"
}

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# Main function
main() {
    load_config

    local command=""
    local dir=""
    local interval=""
    local wallpaper=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--random)
                command="random"
                dir="$2"
                shift 2
                ;;
            -s|--slideshow)
                command="slideshow"
                dir="$2"
                if [[ "$3" =~ ^[0-9]+$ ]]; then
                    interval="$3"
                    shift 3
                else
                    interval="$DEFAULT_INTERVAL"
                    shift 2
                fi
                ;;
            -w|--wallpaper)
                command="set"
                wallpaper="$2"
                shift 2
                ;;
            -c|--config)
                command="config"
                dir="$2"
                if [[ "$3" =~ ^[0-9]+$ ]]; then
                    interval="$3"
                    shift 3
                else
                    interval="$DEFAULT_INTERVAL"
                    shift 2
                fi
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "Wallpaper Changer v$VERSION"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Execute command
    case "$command" in
        "random")
            random_wallpaper "${dir:-$WALLPAPER_DIR}"
            ;;
        "slideshow")
            slideshow "${dir:-$WALLPAPER_DIR}" "${interval:-$INTERVAL}"
            ;;
        "set")
            set_wallpaper "$wallpaper"
            ;;
        "config")
            save_config "$dir" "$interval"
            ;;
        "")
            if [ -n "$WALLPAPER_DIR" ]; then
                random_wallpaper "$WALLPAPER_DIR"
            else
                echo "No command specified and no default directory configured."
                show_help
                exit 1
            fi
            ;;
    esac
}

# Show help
show_help() {
    cat << EOF
Wallpaper Changer v$VERSION - A script to manage wallpapers on Linux

Usage: $0 [options]

Options:
  -r, --random <directory>    Set a random wallpaper from the specified directory
  -s, --slideshow <directory> [interval] Start a slideshow with wallpapers from directory
                              (optional interval in seconds, default: $DEFAULT_INTERVAL)
  -w, --wallpaper <file>      Set a specific wallpaper file
  -c, --config <directory> [interval] Save default directory and interval to config file
  -h, --help                 Show this help message
  -v, --version              Show version information

If no options are provided, the script will use the default directory from config
(if available) and set a random wallpaper.

Supported desktop environments: GNOME, KDE Plasma
EOF
}

# Run main function
main "$@"