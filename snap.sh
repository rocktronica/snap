#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
COLOR_RESET='\033[0m'
TRIGGER="snap"
SNAPSHOT_DELAY=0

trap 'echo -e "${RED}Error: Script failed${COLOR_RESET}" >&2; exit 1' ERR

check_dependencies() {
    local required_commands=("imagesnap" "hear")
    local missing_deps=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}Error: Missing dependencies: ${missing_deps[*]}${COLOR_RESET}" >&2
        exit 1
    fi
}

get_camera_input() {
    local cameras
    cameras=$(imagesnap -l 2>&1 | grep -v WARNING | grep "^=>" | sed 's/^=> //')

    echo "Select camera input:" >&2
    local -a camera_array
    local index=1
    while IFS= read -r camera; do
        camera_array[$index]="$camera"
        echo "$index) $camera" >&2
        ((index++))
    done <<< "$cameras"

    local user_selection
    local selection_valid=false
    while [[ $selection_valid == false ]]; do
        echo >&2
        read -p "Select a camera (1-$((index-1))): " user_selection

        if [[ $user_selection =~ ^[0-9]+$ ]] && [[ $user_selection -ge 1 && $user_selection -le $((index-1)) ]]; then
            selection_valid=true
        else
            echo -e "${RED}Invalid input: please enter a number between 1 and $((index-1))${COLOR_RESET}" >&2
        fi
    done

    echo "${camera_array[$user_selection]}"
}

ring_a_bell() {
    if command -v afplay &> /dev/null; then
        afplay /System/Library/Sounds/Glass.aiff 2>/dev/null & disown
    else
        echo -e '\a'
    fi
}

take_snapshot() {
    local camera_name="$1"
    local output_dir="$2"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local filename="${output_dir}/${timestamp}.jpg"

    imagesnap -w "$SNAPSHOT_DELAY" -q -d "$camera_name" "$filename" 2>/dev/null
    echo -e "${GREEN}Snapshot saved as ${filename}${COLOR_RESET}"
}

main() {
    echo "snap.sh"
    echo ""

    local selected_camera
    selected_camera=$(get_camera_input)

    echo ""
    echo "You chose $selected_camera"
    echo

    local starting_timestamp
    starting_timestamp=$(date +"%Y%m%d_%H%M%S")
    local output_dir="local/${starting_timestamp}"
    mkdir -p "$output_dir"

    echo "Listening for \"${TRIGGER}\". Press Ctrl+C to exit."
    echo

    while true; do
        hear --exit-word "$TRIGGER" >/dev/null 2>&1
        take_snapshot "$selected_camera" "$output_dir"
        ring_a_bell
    done
}

check_dependencies
main "$@"
