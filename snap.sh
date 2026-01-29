#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
COLOR_RESET='\033[0m'

trap 'echo -e "${RED}Error: Script failed${COLOR_RESET}" >&2; exit 1' ERR

check_dependencies() {
    if ! command -v imagesnap &> /dev/null; then
        echo -e "${RED}Error: imagesnap is not installed${COLOR_RESET}" >&2
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

main() {
    echo "snap.sh"
    echo ""

    local selected_camera
    selected_camera=$(get_camera_input)

    echo ""
    echo "You chose $selected_camera"
}

check_dependencies
main "$@"
