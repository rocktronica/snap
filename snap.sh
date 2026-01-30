#!/bin/bash

set -euo pipefail

TRIGGER="snap"
SNAPSHOT_DELAY=0
TIMELAPSE_DELAY=0
TRIGGER_SOUND="tink"
SUCCESS_SOUND="glass"
SCREEN_PREFIX="Screen"
BUILTIN_MICROPHONE="BuiltInMicrophoneDevice"
CAMERA_NAME=""
MICROPHONE_ID=""
OUTPUT_DIR=""

trap 'echo "Error: Script failed" >&2; exit 1' ERR

usage() {
    local exit_code="${1:-0}"
    echo "snap.sh - Voice-triggered camera snapshot tool"
    echo ""
    echo "Captures snapshots from a selected camera when a voice trigger phrase is detected."
    echo "Saves timestamped images to a session folder."
    echo ""
    echo "Usage: snap.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --trigger PHRASE         Voice trigger phrase (default: snap)"
    echo "  --camera NAME            Camera device name (skip prompt)"
    echo "                           Use quotes if name contains spaces"
    echo "  --microphone ID          Microphone device ID (skip prompt)"
    echo "  --timelapse SECONDS      Delay between snapshots (default: 0, no timelapse)"
    echo "  --output PATH            Output folder (default: local/TIMESTAMP)"
    echo "  -h, --help               Show this help message"
    echo ""
    exit "$exit_code"
}

require_value() {
    local flag="$1"
    local value="${2-}"
    if [[ -z $value || $value == -* ]]; then
        echo "Error: $flag requires a value" >&2
        usage 1
    fi
}

parse_flags() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --trigger)
                require_value "$1" "$2"
                TRIGGER="$2"
                shift 2
                ;;
            --camera)
                require_value "$1" "$2"
                CAMERA_NAME="$2"
                shift 2
                ;;
            --microphone)
                require_value "$1" "$2"
                MICROPHONE_ID="$2"
                shift 2
                ;;
            --timelapse)
                require_value "$1" "$2"
                TIMELAPSE_DELAY="$2"
                shift 2
                ;;
            --output)
                require_value "$1" "$2"
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -h|--help) usage ;;
            *)
                echo "Error: Unknown option: $1" >&2
                usage 1
                ;;
        esac
    done
}

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

list_photo_inputs() {
    imagesnap -l 2>&1 | grep -v WARNING | grep "^=>" | sed 's/^=> //'
    list_screens
}

get_display_count() {
    local display_count
    display_count=$(system_profiler SPDisplaysDataType 2>/dev/null | awk '/Resolution:/{count++} END {print count+0}')
    if [[ $display_count -lt 1 ]]; then
        display_count=1
    fi
    echo "$display_count"
}

list_screens() {
    local display_count
    display_count=$(get_display_count)

    local i
    for ((i=1; i<=display_count; i++)); do
        echo "$SCREEN_PREFIX $i"
    done
}

get_photo_input() {
    local photo_inputs
    photo_inputs=$(list_photo_inputs)
    select_from_list "Select photo input:" "$photo_inputs" echo
}

photo_input_exists() {
    local photo_input_name="$1"
    local photo_inputs
    photo_inputs=$(list_photo_inputs)
    echo "$photo_inputs" | grep -Fxq -- "$photo_input_name"
}

parse_microphone_id() {
    local device="$1"
    echo "$device" | sed -E 's/.*\(ID: //; s/\)$//'
}

parse_microphone_name() {
    local device="$1"
    echo "$device" | sed -E 's/^[0-9]+\. *//; s/ \(ID: .*\)$//'
}

list_microphones() {
    local all_devices
    all_devices=$(hear --audio-input-devices 2>&1 | grep -E '^[0-9]+\.')
    echo "$all_devices" | grep "$BUILTIN_MICROPHONE"
    echo "$all_devices" | grep -v "$BUILTIN_MICROPHONE"
}

get_microphone_input() {
    local devices
    devices=$(list_microphones)
    select_from_list "Select microphone input:" "$devices" parse_microphone_id parse_microphone_name
}

microphone_exists() {
    local microphone_id="$1"
    local devices
    devices=$(list_microphones)
    echo "$devices" | sed -E 's/.*\(ID: //; s/\)$//' | grep -Fxq -- "$microphone_id"
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
    if [[ $camera_name == "$SCREEN_PREFIX"* ]]; then
        local display_id
        display_id=$(echo "$camera_name" | sed -n "s/^${SCREEN_PREFIX} \([0-9][0-9]*\)$/\1/p")
        if [[ -n $display_id ]]; then
            screencapture -x -D "$display_id" "$filename"
        else
            screencapture -x "$filename"
        fi
    else
        imagesnap -w "$SNAPSHOT_DELAY" -q -d "$camera_name" "$filename" 2>/dev/null
    fi
    echo " Done."
}

run_snapshot_loop() {
    local selected_photo_input="$1"
    local selected_microphone="$2"
    local output_dir="$3"

    while true; do
        hear --exit-word "$TRIGGER" --timeout "$TIMELAPSE_DELAY" \
            --input-device-id "$selected_microphone" >/dev/null 2>&1
        play_system_sound "$TRIGGER_SOUND"
        take_snapshot "$selected_photo_input" "$output_dir"
        play_system_sound "$SUCCESS_SOUND"
    done
}

resolve_or_prompt() {
    local label="$1"
    local provided_value="$2"
    local exists_func="$3"
    local prompt_func="$4"

    if [[ -n $provided_value ]]; then
        if $exists_func "$provided_value"; then
            echo "$provided_value"
            return
        fi

        echo "$label not found: $provided_value" >&2
    fi

    $prompt_func
}

main() {
    echo "snap.sh"
    echo ""

    local selected_photo_input
    selected_photo_input=$(resolve_or_prompt "Photo input" "$CAMERA_NAME" photo_input_exists get_photo_input)
    echo

    local selected_microphone
    selected_microphone=$(resolve_or_prompt "Microphone" "$MICROPHONE_ID" microphone_exists get_microphone_input)
    echo

    local output_dir="${OUTPUT_DIR:-local/$(get_timestamp)}"
    mkdir -p "$output_dir"

    echo "Photo input:      $selected_photo_input"
    echo "Microphone input: $selected_microphone"
    echo "Output folder:    $output_dir"
    echo "Trigger phrase:   $TRIGGER"
    echo
    echo "Press Ctrl+C to exit."
    echo

    run_snapshot_loop "$selected_photo_input" "$selected_microphone" "$output_dir"
}

parse_flags "$@"
check_dependencies
main
