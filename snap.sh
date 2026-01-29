#!/bin/bash

# Script name: snap.sh
# Description: Brief description of what this script does
# Author: $(whoami)
# Date: $(date +%Y-%m-%d)

set -euo pipefail

# Colors for output (optional)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Error handling
trap 'echo -e "${RED}Error: Script failed${NC}" >&2; exit 1' ERR

# Check for required dependencies
check_dependencies() {
    if ! command -v imagesnap &> /dev/null; then
        echo -e "${RED}Error: imagesnap is not installed${NC}" >&2
        exit 1
    fi
}

# Main function
main() {
    echo "snap.sh"
    echo ""

    # Get available camera inputs
    local cameras
    cameras=$(imagesnap -l 2>&1 | grep -v WARNING | grep "^=>" | sed 's/^=> //')

    # Present as a numbered list
    echo "Select camera input:"
    local -a camera_array
    local index=1
    while IFS= read -r camera; do
        camera_array[$index]="$camera"
        echo "$index) $camera"
        ((index++))
    done <<< "$cameras"

    # Wait for user selection with validation loop
    local selection
    local valid_selection=false
    while [[ $valid_selection == false ]]; do
        echo
        read -p "Select a camera (1-$((index-1))): " selection

        # Check if input is numeric and within range
        if [[ $selection =~ ^[0-9]+$ ]] && [[ $selection -ge 1 && $selection -le $((index-1)) ]]; then
            valid_selection=true
        else
            echo -e "${RED}Invalid input: please enter a number${NC}" >&2
        fi
    done

    echo ""
    echo "You chose ${camera_array[$selection]}"
}

# Check dependencies before running main
check_dependencies

# Run main function
main "$@"
