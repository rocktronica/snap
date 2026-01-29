#!/bin/bash

set -euo pipefail

TRIGGER="snap"
SNAPSHOT_DELAY=0
TRIGGER_SOUND="tink"
SUCCESS_SOUND="glass"

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

get_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

select_from_list() {
    local prompt="$1"
    local list_data="$2"
    local parser_func="$3"
    local display_parser="${4:-$parser_func}"

    echo "$prompt" >&2
    local -a items_array
    local index=1
    while IFS= read -r line; do
        local parsed_value
        local display_value
        parsed_value=$($parser_func "$line")
        display_value=$($display_parser "$line")
        items_array[$index]="$parsed_value"
        echo "$index) $display_value" >&2
        ((index++))
    done <<< "$list_data"

    local user_selection
    user_selection=$(prompt_selection "$((index-1))")
    echo "${items_array[$user_selection]}"
}

prompt_selection() {
    local max="$1"
    local min="${2:-1}"
    local default="${3:-1}"

    local user_selection
    local selection_valid=false
    while [[ $selection_valid == false ]]; do
        read -r -p "   $min-$max, default $default: " user_selection
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

parse_camera_name() {
    echo "$1"
}

get_camera_input() {
    local cameras
    cameras=$(imagesnap -l 2>&1 | grep -v WARNING | grep "^=>" | sed 's/^=> //')
    select_from_list "Select camera input:" "$cameras" parse_camera_name
}

parse_microphone_id() {
    local device="$1"
    echo "$device" | sed -E 's/.*\(ID: //; s/\)$//'
}

parse_microphone_name() {
    local device="$1"
    echo "$device" | sed -E 's/^[0-9]+\. *//; s/ \(ID: .*\)$//'
}

get_microphone_input() {
    local devices
    devices=$(hear --audio-input-devices 2>&1 | grep -E '^[0-9]+\.')
    select_from_list "Select microphone input:" "$devices" parse_microphone_id parse_microphone_name
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
    timestamp=$(get_timestamp)
    local filename="${output_dir}/${timestamp}.jpg"

    echo -n "Taking ${filename}..."
    imagesnap -w "$SNAPSHOT_DELAY" -q -d "$camera_name" "$filename" 2>/dev/null
    echo " Done."
}

run_snapshot_loop() {
    local selected_camera="$1"
    local selected_microphone="$2"
    local output_dir="$3"

    while true; do
        hear --exit-word "$TRIGGER" --input-device-id "$selected_microphone" >/dev/null 2>&1
        play_system_sound "$TRIGGER_SOUND"
        take_snapshot "$selected_camera" "$output_dir"
        play_system_sound "$SUCCESS_SOUND"
    done
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
    starting_timestamp=$(get_timestamp)
    local output_dir="local/${starting_timestamp}"
    mkdir -p "$output_dir"

    echo "Camera input:     $selected_camera"
    echo "Microphone input: $selected_microphone"
    echo "Output folder:    $output_dir"
    echo
    echo "Press Ctrl+C to exit."
    echo

    run_snapshot_loop "$selected_camera" "$selected_microphone" "$output_dir"
}

check_dependencies
main "$@"
