#!/bin/bash

set -euo pipefail


TRIGGER="snap"
SNAPSHOT_DELAY=0

trap 'echo "Error: Script failed" >&2; exit 1' ERR

check_dependencies() {
    local required_commands=("imagesnap" "hear")
    local missing_deps=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Error: Missing dependencies: ${missing_deps[*]}" >&2
        exit 1
    fi
}

prompt_selection() {
    local max="$1"
    local min="${2:-1}"
    local default="${3:-1}"

    local user_selection
    local selection_valid=false
    while [[ $selection_valid == false ]]; do
        read -p "$min-$max, default $default: " user_selection
        if [[ -z $user_selection ]]; then
            user_selection="$default"
        fi

        if [[ $user_selection =~ ^[0-9]+$ ]] && [[ $user_selection -ge $min && $user_selection -le $max ]]; then
            selection_valid=true
        else
            echo "Invalid input: please enter a number between $min and $max" >&2
        fi
    done

    echo "$user_selection"
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
    user_selection=$(prompt_selection "$((index-1))")
    echo "${camera_array[$user_selection]}"
}

get_microphone_input() {
    local devices
    devices=$(hear --audio-input-devices 2>&1 | grep -E '^[0-9]+\.')

    echo "Select microphone input:" >&2
    local -a microphone_array
    local index=1
    while IFS= read -r device; do
        local microphone_name
        local microphone_id
        microphone_name=$(echo "$device" | sed -E 's/^[0-9]+\. *//; s/ \(ID: .*\)$//')
        microphone_id=$(echo "$device" | sed -E 's/.*\(ID: //; s/\)$//')
        microphone_array[$index]="$microphone_id"
        echo "$index) $microphone_name" >&2
        ((index++))
    done <<< "$devices"

    local user_selection
    user_selection=$(prompt_selection "$((index-1))")
    echo "${microphone_array[$user_selection]}"
}

play_system_sound() {
    local sound_name="$1"
    if command -v afplay &> /dev/null; then
        afplay "/System/Library/Sounds/${sound_name}.aiff" 2>/dev/null & disown
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

    echo -n "Taking ${filename}..."
    imagesnap -w "$SNAPSHOT_DELAY" -q -d "$camera_name" "$filename" 2>/dev/null
    echo " Done."
}

main() {
    echo "snap.sh"
    echo ""

    local selected_camera
    selected_camera=$(get_camera_input)
    echo

    local selected_microphone
    selected_microphone=$(get_microphone_input)
    echo

    local starting_timestamp
    starting_timestamp=$(date +"%Y%m%d_%H%M%S")
    local output_dir="local/${starting_timestamp}"
    mkdir -p "$output_dir"

    echo "Microphone input: $selected_microphone"
    echo "Camera input:     $selected_camera"
    echo "Output folder:    $output_dir"
    echo
    echo "Press Ctrl+C to exit."
    echo

    while true; do
        hear --exit-word "$TRIGGER" --input-device-id "$selected_microphone" >/dev/null 2>&1
        play_system_sound tink
        take_snapshot "$selected_camera" "$output_dir"
        play_system_sound glass
    done
}

check_dependencies
main "$@"
