#!/bin/bash

# Layer management script for Robotics Controller Yocto project
# Usage: ./scripts/manage-layers.sh [command] [options]

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

# Set color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to show usage
show_usage() {
    echo -e "${BLUE}Layer Management Script for Robotics Controller${NC}"
    echo
    echo "Usage: $0 [command] [options]"
    echo
    echo -e "${YELLOW}Commands:${NC}"
    echo "  list                    - List all currently configured layers"
    echo "  available              - Show popular available meta-layers"
    echo "  add <name> <url> [branch] - Add a new meta-layer"
    echo "  remove <name>          - Remove a meta-layer"
    echo "  update <name>          - Update a meta-layer to latest commit"
    echo "  info <name>            - Show information about a layer"
    echo "  help                   - Show this help message"
    echo
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 add meta-golang https://github.com/bmwcarit/meta-golang"
    echo "  $0 add meta-ros https://github.com/ros/meta-ros scarthgap"
    echo "  $0 remove meta-golang"
    echo "  $0 update meta-raspberrypi"
    echo "  $0 list"
}

# Function to add a layer to bblayers.conf
add_layer_to_bblayers() {
    local layer_name="$1"
    local layer_path="$2"

    if [ -f "$PROJECT_DIR/build/conf/bblayers.conf" ]; then
        if ! grep -q "$layer_name" "$PROJECT_DIR/build/conf/bblayers.conf"; then
            echo -e "${BLUE}Adding $layer_name to bblayers.conf...${NC}"
            # Create backup
            cp "$PROJECT_DIR/build/conf/bblayers.conf" "$PROJECT_DIR/build/conf/bblayers.conf.bak"
            # Insert before the last line with meta-robotics
            sed -i "/meta-robotics/i\\  $layer_path \\\\" "$PROJECT_DIR/build/conf/bblayers.conf"
            echo -e "${GREEN}$layer_name added to bblayers.conf${NC}"
        else
            echo -e "${YELLOW}$layer_name already in bblayers.conf${NC}"
        fi
    else
        echo -e "${RED}bblayers.conf not found. Make sure you've run setup-yocto-env.sh first.${NC}"
        exit 1
    fi
}

# Function to remove a layer from bblayers.conf
remove_layer_from_bblayers() {
    local layer_name="$1"

    if [ -f "$PROJECT_DIR/build/conf/bblayers.conf" ]; then
        if grep -q "$layer_name" "$PROJECT_DIR/build/conf/bblayers.conf"; then
            echo -e "${BLUE}Removing $layer_name from bblayers.conf...${NC}"
            # Create backup
            cp "$PROJECT_DIR/build/conf/bblayers.conf" "$PROJECT_DIR/build/conf/bblayers.conf.bak"
            # Remove the layer line
            sed -i "/$layer_name/d" "$PROJECT_DIR/build/conf/bblayers.conf"
            echo -e "${GREEN}$layer_name removed from bblayers.conf${NC}"
        else
            echo -e "${YELLOW}$layer_name not found in bblayers.conf${NC}"
        fi
    fi
}

# Function to list current layers
list_layers() {
    echo -e "${BLUE}Currently configured meta-layers:${NC}"
    echo

    if [ -f "$PROJECT_DIR/build/conf/bblayers.conf" ]; then
        echo -e "${YELLOW}From bblayers.conf:${NC}"
        grep -E "meta-|poky" "$PROJECT_DIR/build/conf/bblayers.conf" | sed 's/.*\///' | sed 's/ .*//' | sort | while read -r layer; do
            if [ -n "$layer" ]; then
                if [ -d "$PROJECT_DIR/$layer" ]; then
                    echo -e "  ${GREEN}✓${NC} $layer (cloned)"
                else
                    echo -e "  ${RED}✗${NC} $layer (not cloned)"
                fi
            fi
        done
        echo
    else
        echo -e "${RED}bblayers.conf not found. Run setup-yocto-env.sh first.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Available in project root:${NC}"
    find "$PROJECT_DIR" -maxdepth 1 -name "meta-*" -type d | while read -r dir; do
        layer_name=$(basename "$dir")
        if grep -q "$layer_name" "$PROJECT_DIR/build/conf/bblayers.conf" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $layer_name (active)"
        else
            echo -e "  ${YELLOW}○${NC} $layer_name (available but not active)"
        fi
    done
}

# Function to show available layers
show_available_layers() {
    echo -e "${BLUE}Popular meta-layers for embedded/robotics development:${NC}"
    echo
    echo -e "${YELLOW}Hardware BSP Layers:${NC}"
    echo "  meta-ti               - git://git.yoctoproject.org/meta-ti"
    echo "  meta-raspberrypi      - git://git.yoctoproject.org/meta-raspberrypi"
    echo "  meta-intel            - git://git.yoctoproject.org/meta-intel"
    echo "  meta-xilinx           - https://github.com/Xilinx/meta-xilinx"
    echo
    echo -e "${YELLOW}Real-time and Performance:${NC}"
    echo "  meta-realtime         - git://git.yoctoproject.org/meta-realtime"
    echo "  meta-latency-testing  - https://github.com/derekstraka/meta-latency-testing"
    echo
    echo -e "${YELLOW}Security:${NC}"
    echo "  meta-security         - git://git.yoctoproject.org/meta-security"
    echo "  meta-tpm              - https://github.com/kraj/meta-tpm"
    echo "  meta-selinux          - git://git.yoctoproject.org/meta-selinux"
    echo
    echo -e "${YELLOW}Connectivity and IoT:${NC}"
    echo "  meta-networking       - git://git.openembedded.org/meta-networking"
    echo "  meta-bluetooth        - https://github.com/fhunleth/meta-bluetooth"
    echo "  meta-iot              - https://github.com/intel-iot-devkit/meta-iot"
    echo
    echo -e "${YELLOW}Development and Languages:${NC}"
    echo "  meta-nodejs           - https://github.com/imyller/meta-nodejs"
    echo "  meta-python           - git://git.openembedded.org/meta-python"
    echo "  meta-rust             - https://github.com/meta-rust/meta-rust"
    echo "  meta-golang           - https://github.com/bmwcarit/meta-golang"
    echo "  meta-java             - https://github.com/openjdk/meta-openjdk"
    echo
    echo -e "${YELLOW}Robotics and AI:${NC}"
    echo "  meta-ros              - https://github.com/ros/meta-ros"
    echo "  meta-tensorflow-lite  - https://github.com/NobuoTsukamoto/meta-tensorflow-lite"
    echo "  meta-opencv           - https://github.com/robwoolley/meta-opencv"
    echo
    echo -e "${YELLOW}Multimedia and Graphics:${NC}"
    echo "  meta-multimedia       - git://git.openembedded.org/meta-multimedia"
    echo "  meta-qt5              - git://code.qt.io/yocto/meta-qt5"
    echo "  meta-gnome            - git://git.yoctoproject.org/meta-gnome"
    echo
    echo -e "${YELLOW}Virtualization and Containers:${NC}"
    echo "  meta-virtualization   - git://git.yoctoproject.org/meta-virtualization"
    echo "  meta-cloud-services   - git://git.yoctoproject.org/meta-cloud-services"
    echo
    echo -e "${BLUE}To add a layer, use:${NC} $0 add <layer-name> <git-url> [branch]"
}

# Function to add a new meta-layer
add_layer() {
    if [ $# -lt 2 ]; then
        echo -e "${RED}Error: Missing arguments${NC}"
        echo "Usage: $0 add <layer-name> <git-url> [branch]"
        echo "Example: $0 add meta-golang https://github.com/bmwcarit/meta-golang scarthgap"
        exit 1
    fi

    local layer_name="$1"
    local git_url="$2"
    local branch="${3:-scarthgap}"
    local layer_path="$PROJECT_DIR/$layer_name"

    echo -e "${BLUE}Adding new meta-layer: $layer_name${NC}"

    # Clone the layer if it doesn't exist
    if [ ! -d "$layer_path" ]; then
        echo -e "${BLUE}Cloning $layer_name from $git_url (branch: $branch)...${NC}"
        if git clone "$git_url" -b "$branch" "$layer_path"; then
            echo -e "${GREEN}$layer_name cloned successfully!${NC}"
        else
            echo -e "${RED}Failed to clone $layer_name${NC}"
            echo -e "${YELLOW}Trying with master branch...${NC}"
            if git clone "$git_url" "$layer_path"; then
                echo -e "${GREEN}$layer_name cloned successfully with default branch!${NC}"
            else
                echo -e "${RED}Failed to clone $layer_name with any branch${NC}"
                exit 1
            fi
        fi
    else
        echo -e "${YELLOW}$layer_name already exists at $layer_path${NC}"
    fi

    # Add to bblayers.conf
    add_layer_to_bblayers "$layer_name" "\${TOPDIR}/../$layer_name"

    echo -e "${GREEN}$layer_name has been added to your Yocto build!${NC}"
    echo -e "${YELLOW}Note: You may need to check layer dependencies and update local.conf if needed.${NC}"
}

# Function to remove a meta-layer
remove_layer() {
    if [ $# -lt 1 ]; then
        echo -e "${RED}Error: Missing layer name${NC}"
        echo "Usage: $0 remove <layer-name>"
        exit 1
    fi

    local layer_name="$1"
    local layer_path="$PROJECT_DIR/$layer_name"

    echo -e "${BLUE}Removing meta-layer: $layer_name${NC}"

    # Remove from bblayers.conf
    remove_layer_from_bblayers "$layer_name"

    # Ask if user wants to delete the directory
    if [ -d "$layer_path" ]; then
        echo -e "${YELLOW}Do you want to delete the layer directory? This will remove all local changes.${NC}"
        read -p "Delete $layer_path? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$layer_path"
            echo -e "${GREEN}$layer_name directory deleted${NC}"
        else
            echo -e "${YELLOW}$layer_name directory kept${NC}"
        fi
    fi

    echo -e "${GREEN}$layer_name has been removed from your Yocto build!${NC}"
}

# Function to update a meta-layer
update_layer() {
    if [ $# -lt 1 ]; then
        echo -e "${RED}Error: Missing layer name${NC}"
        echo "Usage: $0 update <layer-name>"
        exit 1
    fi

    local layer_name="$1"
    local layer_path="$PROJECT_DIR/$layer_name"

    if [ ! -d "$layer_path" ]; then
        echo -e "${RED}Error: $layer_name not found at $layer_path${NC}"
        exit 1
    fi

    echo -e "${BLUE}Updating meta-layer: $layer_name${NC}"

    cd "$layer_path" || exit 1

    # Check if it's a git repository
    if [ ! -d ".git" ]; then
        echo -e "${RED}Error: $layer_name is not a git repository${NC}"
        exit 1
    fi

    # Get current branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    echo -e "${BLUE}Current branch: $current_branch${NC}"

    # Update the layer
    if git pull; then
        echo -e "${GREEN}$layer_name updated successfully!${NC}"
    else
        echo -e "${RED}Failed to update $layer_name${NC}"
        exit 1
    fi
}

# Function to show layer information
show_layer_info() {
    if [ $# -lt 1 ]; then
        echo -e "${RED}Error: Missing layer name${NC}"
        echo "Usage: $0 info <layer-name>"
        exit 1
    fi

    local layer_name="$1"
    local layer_path="$PROJECT_DIR/$layer_name"

    if [ ! -d "$layer_path" ]; then
        echo -e "${RED}Error: $layer_name not found at $layer_path${NC}"
        exit 1
    fi

    echo -e "${BLUE}Layer Information: $layer_name${NC}"
    echo

    # Show layer.conf if it exists
    if [ -f "$layer_path/conf/layer.conf" ]; then
        echo -e "${YELLOW}Layer Configuration:${NC}"
        echo "  Path: $layer_path"
        echo "  Priority: $(grep BBFILE_PRIORITY "$layer_path/conf/layer.conf" 2>/dev/null || echo "Not specified")"
        echo "  Dependencies: $(grep LAYERDEPENDS "$layer_path/conf/layer.conf" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "None specified")"
        echo "  Series Compatibility: $(grep LAYERSERIES_COMPAT "$layer_path/conf/layer.conf" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "Not specified")"
        echo
    fi

    # Show git information if it's a git repository
    if [ -d "$layer_path/.git" ]; then
        cd "$layer_path" || exit 1
        echo -e "${YELLOW}Git Information:${NC}"
        echo "  Branch: $(git rev-parse --abbrev-ref HEAD)"
        echo "  Commit: $(git rev-parse --short HEAD)"
        echo "  Remote: $(git remote get-url origin 2>/dev/null || echo "No remote")"
        echo "  Last commit: $(git log -1 --format="%cd" --date=short)"
        echo
    fi

    # Show recipes count
    recipe_dirs=$(find "$layer_path" -maxdepth 1 -name "recipes-*" -type d 2>/dev/null)
    if [ -n "$recipe_dirs" ]; then
        echo -e "${YELLOW}Recipes:${NC}"
        recipe_count=$(find "$layer_path" -name "*.bb" -o -name "*.bbappend" | wc -l)
        echo "  Total recipes: $recipe_count"
        echo "  Recipe directories:"
        echo "$recipe_dirs" | while read -r dir; do
            echo "    $(basename "$dir")"
        done
        echo
    fi

    # Show README if it exists
    if [ -f "$layer_path/README" ] || [ -f "$layer_path/README.md" ]; then
        echo -e "${YELLOW}README (first 10 lines):${NC}"
        head -n 10 "$layer_path/README"* 2>/dev/null | head -n 10
        echo
    fi
}

# Main script logic
case "$1" in
    list)
        list_layers
        ;;
    available)
        show_available_layers
        ;;
    add)
        shift
        add_layer "$@"
        ;;
    remove)
        shift
        remove_layer "$@"
        ;;
    update)
        shift
        update_layer "$@"
        ;;
    info)
        shift
        show_layer_info "$@"
        ;;
    help|--help|-h)
        show_usage
        ;;
    "")
        show_usage
        ;;
    *)
        echo -e "${RED}Error: Unknown command '$1'${NC}"
        echo
        show_usage
        exit 1
        ;;
esac
