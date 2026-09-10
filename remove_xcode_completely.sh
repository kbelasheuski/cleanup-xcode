#!/bin/zsh
if [ -z "${ZSH_VERSION:-}" ]; then
  exec /bin/zsh "$0" "$@"
fi

set -euo pipefail

if [[ -t 1 ]]; then
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  MAGENTA=$'\033[35m'
  CYAN=$'\033[36m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  MAGENTA=''
  CYAN=''
  BOLD=''
  RESET=''
fi

MODE=""
MODE_TITLE=""
ASSUME_YES=0
SCAN_ONLY=0
SKIP_DOCK=0
ESTIMATE_SIZES=0
BYTES_BEFORE=0
BYTES_AFTER=0
ESTIMATED_BYTES=0
REMOVED_BYTES=0
FAILED_TARGETS=()

FULL_TARGETS=(
  "/Applications/Xcode.app"
  "/Library/Developer/CommandLineTools"
  "/Library/Developer/CoreSimulator"
  "/Library/Developer/CoreDevice"
  "/Library/Developer/DeviceKit"
  "/Library/Developer/DeveloperDiskImages"
  "/Library/Developer/PrivateFrameworks"
  "$HOME/Library/Developer/Xcode"
  "$HOME/Library/Developer/CoreSimulator"
  "$HOME/Library/Developer/XCTestDevices"
  "$HOME/Library/Application Support/Xcode"
  "$HOME/Library/Application Support/com.apple.dt.Xcode"
  "$HOME/Library/Caches/com.apple.dt.Xcode"
  "$HOME/Library/Caches/com.apple.dt.xcodebuild"
  "$HOME/Library/Caches/com.apple.dt.Xcode.ITunesSoftwareService"
  "$HOME/Library/Caches/com.apple.python/Applications/Xcode.app"
  "$HOME/Library/HTTPStorages/com.apple.dt.Xcode"
  "$HOME/Library/HTTPStorages/com.apple.dt.xcodebuild"
  "$HOME/Library/HTTPStorages/com.apple.dt.Xcode.ITunesSoftwareService"
  "$HOME/Library/Logs/Xcode"
  "$HOME/Library/Logs/CoreSimulator"
  "$HOME/Library/Preferences/com.apple.dt.Xcode.plist"
  "$HOME/Library/Preferences/com.apple.dt.xcodebuild.plist"
  "$HOME/Library/Preferences/com.apple.CoreSimulator.plist"
  "$HOME/Library/Preferences/com.apple.iphonesimulator.plist"
  "$HOME/Library/Saved Application State/com.apple.dt.Xcode.savedState"
  "$HOME/Library/Saved Application State/com.apple.iphonesimulator.savedState"
  "$HOME/Library/WebKit/com.apple.dt.Xcode"
  "$HOME/Library/Group Containers/group.com.apple.dt.Xcode.SecureSettingsContainer"
  "$HOME/Library/Containers/com.apple.iphonesimulator.ShareExtension"
  "$HOME/Library/MobileDevice/Provisioning Profiles"
)

FULL_GLOB_TARGETS=(
  "$HOME/Library/Application Support/CrashReporter/Xcode_*.plist"
  "$HOME/Library/Application Support/CrashReporter/Simulator_*.plist"
)

KEEP_BASE_TARGETS=(
  "$HOME/Library/Developer/Xcode/DerivedData"
  "$HOME/Library/Developer/Xcode/Archives"
  "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
  "$HOME/Library/Developer/Xcode/watchOS DeviceSupport"
  "$HOME/Library/Developer/Xcode/tvOS DeviceSupport"
  "$HOME/Library/Developer/Xcode/UserData/Previews"
  "$HOME/Library/Developer/XCTestDevices"
  "$HOME/Library/Developer/CoreSimulator/Devices"
  "$HOME/Library/Developer/CoreSimulator/Caches"
  "$HOME/Library/Developer/CoreSimulator/Logs"
  "$HOME/Library/Developer/CoreSimulator/tmp"
  "$HOME/Library/Caches/com.apple.dt.Xcode"
  "$HOME/Library/Caches/com.apple.dt.xcodebuild"
  "$HOME/Library/Caches/com.apple.dt.Xcode.ITunesSoftwareService"
  "$HOME/Library/HTTPStorages/com.apple.dt.Xcode"
  "$HOME/Library/HTTPStorages/com.apple.dt.xcodebuild"
  "$HOME/Library/HTTPStorages/com.apple.dt.Xcode.ITunesSoftwareService"
  "$HOME/Library/Logs/Xcode"
  "$HOME/Library/Logs/CoreSimulator"
  "$HOME/Library/Preferences/com.apple.dt.Xcode.plist"
  "$HOME/Library/Preferences/com.apple.dt.xcodebuild.plist"
  "$HOME/Library/Preferences/com.apple.CoreSimulator.plist"
  "$HOME/Library/Preferences/com.apple.iphonesimulator.plist"
  "$HOME/Library/Saved Application State/com.apple.dt.Xcode.savedState"
  "$HOME/Library/Saved Application State/com.apple.iphonesimulator.savedState"
)

KEEP_BASE_GLOB_TARGETS=()

SCAN_ROOTS=(
  "/Applications"
  "/Library/Developer"
  "$HOME/Library/Developer"
  "$HOME/Library/Application Support"
  "$HOME/Library/Caches"
  "$HOME/Library/HTTPStorages"
  "$HOME/Library/Logs"
  "$HOME/Library/Preferences"
  "$HOME/Library/Saved Application State"
  "$HOME/Library/WebKit"
  "$HOME/Library/Group Containers"
  "$HOME/Library/Containers"
  "$HOME/Library/MobileDevice"
)

TARGETS=()
GLOB_TARGETS=()
PRESERVED_ITEMS=()

print_banner() {
  printf "%s\n" "${MAGENTA}${BOLD}"
  cat <<'BANNER'
██╗  ██╗ ██████╗ ██████╗ ██████╗ ███████╗     ██████╗██╗     ███████╗ █████╗ ███╗   ██╗██╗   ██╗██████╗
╚██╗██╔╝██╔════╝██╔═══██╗██╔══██╗██╔════╝    ██╔════╝██║     ██╔════╝██╔══██╗████╗  ██║██║   ██║██╔══██╗
 ╚███╔╝ ██║     ██║   ██║██║  ██║█████╗      ██║     ██║     █████╗  ███████║██╔██╗ ██║██║   ██║██████╔╝
 ██╔██╗ ██║     ██║   ██║██║  ██║██╔══╝      ██║     ██║     ██╔══╝  ██╔══██║██║╚██╗██║██║   ██║██╔═══╝
██╔╝ ██╗╚██████╗╚██████╔╝██████╔╝███████╗    ╚██████╗███████╗███████╗██║  ██║██║ ╚████║╚██████╔╝██║
╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝     ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝
BANNER
  printf "%s\n" "${RESET}${CYAN}${BOLD}Xcode, simulators, caches, test artifacts, and Dock cleanup${RESET}"
  printf "%s\n" "${BLUE}────────────────────────────────────────────────────────────────────────────────${RESET}"
}

print_step() {
  printf "\n${BLUE}${BOLD}==>${RESET} ${BOLD}%s${RESET}\n" "$1"
}

print_info() {
  printf "${CYAN}•${RESET} %s\n" "$1"
}

print_warn() {
  printf "${YELLOW}! %s${RESET}\n" "$1"
}

print_error() {
  printf "${RED}✗ %s${RESET}\n" "$1" >&2
}

print_ok() {
  printf "${GREEN}✓ %s${RESET}\n" "$1"
}

usage() {
  cat <<'USAGE'
Usage:
  remove_xcode_completely.sh
  remove_xcode_completely.sh [--full | --keep-base | --scan] [--estimate-sizes] [--yes] [--no-dock]

Options:
  No options   Show an interactive menu. Recommended for normal use.
  --full       Remove Xcode.app, Command Line Tools, simulator runtimes, device data, caches, and related files.
  --keep-base  Keep Xcode.app, Command Line Tools, and installed simulator runtimes; remove generated data and caches.
  --scan       Only report known Xcode-related leftovers. Does not remove anything.
  --yes        Skip confirmation prompts for the selected cleanup mode.
  --no-dock    Do not remove Xcode from the Dock.
  --estimate-sizes
              Run du before removal to estimate payload sizes. Slower, but more detailed.
  --help       Show this help.

Examples:
  ./remove_xcode_completely.sh
  ./remove_xcode_completely.sh --scan
  ./remove_xcode_completely.sh --full
  ./remove_xcode_completely.sh --keep-base --yes
USAGE
}

confirm() {
  local prompt="$1"
  local answer=""

  if (( ASSUME_YES )); then
    print_ok "$prompt [auto-yes]"
    return 0
  fi

  printf "${YELLOW}%s [y/N]: ${RESET}" "$prompt"
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "YES" ]]
}

set_mode() {
  local requested_mode="$1"
  case "$requested_mode" in
    keep-base)
      MODE="keep-base"
      MODE_TITLE="Keep Xcode + CLT + simulator runtimes"
      TARGETS=("${KEEP_BASE_TARGETS[@]}")
      GLOB_TARGETS=("${KEEP_BASE_GLOB_TARGETS[@]}")
      PRESERVED_ITEMS=(
        "/Applications/Xcode.app"
        "/Library/Developer/CommandLineTools"
        "/Library/Developer/CoreSimulator/Profiles/Runtimes"
        "$HOME/Library/Developer/CoreSimulator/Profiles"
      )
      ;;
    full)
      MODE="full"
      MODE_TITLE="Full purge"
      TARGETS=("${FULL_TARGETS[@]}")
      GLOB_TARGETS=("${FULL_GLOB_TARGETS[@]}")
      PRESERVED_ITEMS=()
      ;;
    *)
      print_error "Unknown mode: $requested_mode"
      exit 2
      ;;
  esac
  expand_glob_targets
}

expand_glob_targets() {
  local pattern=""
  local target=""

  for pattern in "${GLOB_TARGETS[@]}"; do
    for target in ${~pattern}(N); do
      TARGETS+=("$target")
    done
  done
}

parse_args() {
  local arg=""
  while (( $# > 0 )); do
    arg="$1"
    case "$arg" in
      --full)
        set_mode "full"
        ;;
      --keep-base)
        set_mode "keep-base"
        ;;
      --scan)
        SCAN_ONLY=1
        ;;
      --yes|-y)
        ASSUME_YES=1
        ;;
      --no-dock)
        SKIP_DOCK=1
        ;;
      --estimate-sizes)
        ESTIMATE_SIZES=1
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        print_error "Unknown option: $arg"
        usage
        exit 2
        ;;
    esac
    shift
  done
}

choose_mode() {
  if [[ -n "$MODE" ]]; then
    print_ok "Selected mode: $MODE_TITLE"
    return 0
  fi

  local answer=""
  while true; do
    print_step "What do you want to do?"
    printf "${BOLD}1.${RESET} Full purge\n"
    printf "   Remove Xcode.app, Command Line Tools, simulator runtimes, device data, caches, and related files.\n\n"
    printf "${BOLD}2.${RESET} Keep base install\n"
    printf "   Keep Xcode.app, Command Line Tools, and installed simulator runtimes.\n"
    printf "   Remove DerivedData, Archives, DeviceSupport, XCTestDevices, simulator device data, and caches.\n\n"
    printf "${BOLD}3.${RESET} Scan only\n"
    printf "   Show Xcode-related leftovers without deleting anything.\n\n"
    printf "${BOLD}4.${RESET} Help\n"
    printf "${BOLD}5.${RESET} Quit\n\n"
    printf "${YELLOW}Choose action [1-5, default 1]: ${RESET}"

    read -r answer
    case "$answer" in
      2)
        set_mode "keep-base"
        print_ok "Selected mode: $MODE_TITLE"
        return 0
        ;;
      3)
        SCAN_ONLY=1
        print_ok "Selected mode: Scan only"
        return 0
        ;;
      4)
        usage
        ;;
      5|q|Q|quit|exit)
        print_warn "Aborted by user"
        exit 0
        ;;
      1|"")
        set_mode "full"
        print_ok "Selected mode: $MODE_TITLE"
        return 0
        ;;
      *)
        print_warn "Please choose 1, 2, 3, 4, or 5"
        ;;
    esac
  done
}

choose_size_estimate() {
  local answer=""

  if (( SCAN_ONLY || ESTIMATE_SIZES || ASSUME_YES )); then
    return 0
  fi

  print_step "Size estimate"
  printf "${BOLD}1.${RESET} Skip size estimate\n"
  printf "   Faster startup. The script still reports free-space change after cleanup.\n\n"
  printf "${BOLD}2.${RESET} Estimate sizes before removal\n"
  printf "   Slower, especially with large simulator runtimes, but shows the expected removable payload.\n\n"
  printf "${YELLOW}Choose size mode [1/2, default 1]: ${RESET}"
  read -r answer

  case "$answer" in
    2)
      ESTIMATE_SIZES=1
      print_ok "Size estimate enabled"
      ;;
    *)
      print_ok "Size estimate skipped"
      ;;
  esac
}

safe_kill() {
  local name="$1"
  if pgrep -ix "$name" >/dev/null 2>&1; then
    print_info "Stopping $name"
    killall -9 "$name" 2>/dev/null || true
  fi
}

safe_kill_pattern() {
  local pattern="$1"
  local pids=""

  pids=$(pgrep -f "$pattern" 2>/dev/null || true)
  if [[ -n "$pids" ]]; then
    print_info "Stopping processes matching: $pattern"
    if ! print -r -- "$pids" | xargs kill -9 2>/dev/null; then
      print_warn "Regular kill failed for $pattern, retrying with sudo"
      sudo pkill -9 -f "$pattern" 2>/dev/null || true
    fi
  fi
}

safe_kill_pattern_sudo() {
  local pattern="$1"
  if pgrep -f "$pattern" >/dev/null 2>&1; then
    print_info "Stopping privileged processes matching: $pattern"
    sudo pkill -9 -f "$pattern" 2>/dev/null || true
  fi
}

find_simctl() {
  local candidate=""
  local developer_dir=""
  local selected_developer_dir=""

  if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    candidate="${DEVELOPER_DIR}/usr/bin/simctl"
    if [[ -x "$candidate" ]]; then
      printf "%s\n" "$candidate"
      return 0
    fi
  fi

  selected_developer_dir=$(xcode-select -p 2>/dev/null || true)
  for developer_dir in "$selected_developer_dir" "/Applications/Xcode.app/Contents/Developer" "/Library/Developer/CommandLineTools"; do
    [[ -n "$developer_dir" ]] || continue
    candidate="${developer_dir}/usr/bin/simctl"
    if [[ -x "$candidate" ]]; then
      printf "%s\n" "$candidate"
      return 0
    fi
  done

  candidate=$(xcrun --find simctl 2>/dev/null || true)
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    printf "%s\n" "$candidate"
    return 0
  fi

  return 1
}

run_simctl_for_login_user() {
  local simctl="$1"
  shift

  if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    sudo -u "$SUDO_USER" "$simctl" "$@"
  else
    "$simctl" "$@"
  fi
}

shutdown_simulators() {
  local simctl=""

  simctl=$(find_simctl || true)
  if [[ -n "$simctl" ]]; then
    print_info "Shutting down simulator devices"
    run_simctl_for_login_user "$simctl" shutdown all 2>/dev/null || true
  else
    print_warn "simctl not found; skipping simulator shutdown"
  fi
}

list_simulator_runtime_ids() {
  local simctl="$1"

  "$simctl" runtime list -j 2>/dev/null \
    | awk -F '"' '/"identifier"[[:space:]]*:/ {print $4}' \
    | sort -u
}

delete_simulator_devices_and_runtimes() {
  local simctl=""
  local runtime_id=""
  local found_runtime=0

  simctl=$(find_simctl || true)
  if [[ -z "$simctl" ]]; then
    print_warn "simctl not found; Xcode may already be removed. Skipping official simulator runtime deletion."
    return 0
  fi

  print_step "Deleting simulator devices and runtimes"
  run_simctl_for_login_user "$simctl" shutdown all 2>/dev/null || true
  run_simctl_for_login_user "$simctl" delete all 2>/dev/null || true

  while IFS= read -r runtime_id; do
    [[ -n "$runtime_id" ]] || continue
    found_runtime=1
    print_info "Deleting simulator runtime $runtime_id"
    "$simctl" runtime delete "$runtime_id" >/dev/null 2>&1 || print_warn "simctl could not delete runtime: $runtime_id"
  done < <(list_simulator_runtime_ids "$simctl")

  if (( ! found_runtime )); then
    print_info "No simulator runtimes reported by simctl"
  fi
}

force_unmount_path() {
  local mount_point="$1"

  [[ -n "$mount_point" ]] || return 0
  sudo diskutil unmount force "$mount_point" >/dev/null 2>&1 || true
  sudo /sbin/umount -f "$mount_point" >/dev/null 2>&1 || true
  sudo hdiutil detach -force "$mount_point" >/dev/null 2>&1 || true
}

unmount_core_simulator_volumes() {
  local base=""
  local line=""
  local mount_point=""
  local mounted_paths=()
  local runtime_mount_roots=(
    "/Library/Developer/CoreSimulator/Volumes"
    "/Library/Developer/CoreSimulator/Images/mnt"
    "/Library/Developer/CoreSimulator/Cryptex/Images/mnt"
  )

  if [[ ! -d "/Library/Developer/CoreSimulator" ]]; then
    return 0
  fi

  print_info "Unmounting CoreSimulator runtime volumes if mounted"

  while IFS= read -r line; do
    [[ "$line" == *" on /Library/Developer/CoreSimulator"* ]] || continue
    mount_point="${line#* on }"
    mount_point="${mount_point%% \(*}"
    [[ -n "$mount_point" ]] && mounted_paths+=("$mount_point")
  done < <(/sbin/mount 2>/dev/null || true)

  for mount_point in "${(@ou)mounted_paths}"; do
    force_unmount_path "$mount_point"
  done

  for base in "${runtime_mount_roots[@]}"; do
    [[ -d "$base" ]] || continue
    while IFS= read -r mount_point; do
      [[ -n "$mount_point" ]] || continue
      force_unmount_path "$mount_point"
    done < <(/usr/bin/find "$base" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null || true)
  done
}

is_non_negative_integer() {
  local value="${1:-}"
  [[ "$value" == <-> ]]
}

size_bytes_of_path() {
  local target="$1"
  local size_kb=""

  if (( ! ESTIMATE_SIZES )); then
    printf "0\n"
    return 0
  fi

  if [[ ! -e "$target" ]]; then
    printf "0\n"
    return 0
  fi

  size_kb=$(du -skx "$target" 2>/dev/null | awk 'NR==1 {print $1}' || true)
  if ! is_non_negative_integer "$size_kb"; then
    printf "${YELLOW}! Could not estimate size for: %s${RESET}\n" "$target" >&2
    printf "0\n"
    return 0
  fi

  printf "%s\n" $((size_kb * 1024))
}

safe_human_size_of_path() {
  local target="$1"
  local size=""

  if [[ ! -e "$target" ]]; then
    printf "missing"
    return 0
  fi

  if (( ! ESTIMATE_SIZES )); then
    printf "present"
    return 0
  fi

  size=$(du -shx "$target" 2>/dev/null | awk 'NR==1 {print $1}' || true)
  if [[ -z "$size" ]]; then
    printf "unknown"
  else
    printf "%s" "$size"
  fi
}

is_safe_remove_target() {
  local target="$1"

  [[ -n "$target" ]] || return 1
  [[ "$target" != "/" ]] || return 1
  [[ "$target" != "$HOME" ]] || return 1
  [[ "$target" != "$HOME/Library" ]] || return 1
  [[ "$target" != "/Library" ]] || return 1
  [[ "$target" != "/Library/Developer" ]] || return 1

  if [[ "$target" == "/Applications/Xcode.app" ]]; then
    return 0
  fi
  if [[ "$target" == /Library/Developer/* ]]; then
    return 0
  fi
  if [[ "$target" == "$HOME"/Library/* ]]; then
    return 0
  fi

  return 1
}

remove_path() {
  local target="$1"
  local path_bytes=0
  local error_log=""
  local rm_status=0

  if ! is_safe_remove_target "$target"; then
    print_error "Refusing unsafe target: $target"
    return 1
  fi

  if [[ -e "$target" ]]; then
    path_bytes=$(size_bytes_of_path "$target")
    if ! is_non_negative_integer "$path_bytes"; then
      path_bytes=0
    fi
    REMOVED_BYTES=$((REMOVED_BYTES + path_bytes))
    print_info "Removing $target"

    if [[ "$target" == "/Library/Developer/CoreSimulator" ]]; then
      unmount_core_simulator_volumes
    fi

    error_log=$(mktemp -t xcode-cleanup-rm.XXXXXX 2>/dev/null || true)
    rm_status=0
    remove_path_fast "$target" "$error_log" || rm_status=$?

    if (( rm_status != 0 )) || [[ -e "$target" ]]; then
      print_warn "Fast removal did not finish cleanly; retrying after permission cleanup"
      prepare_remove_path "$target"
      if [[ "$target" == "/Library/Developer/CoreSimulator" ]]; then
        unmount_core_simulator_volumes
      fi
      rm_status=0
      remove_path_fast "$target" "$error_log" || rm_status=$?
    fi

    if (( rm_status == 0 )) && [[ ! -e "$target" ]]; then
      print_ok "Removed $target"
    else
      print_warn "Could not fully remove: $target"
      if [[ -n "$error_log" && -s "$error_log" ]]; then
        print_warn "First rm errors:"
        sed -n '1,8p' "$error_log" | while IFS= read -r line; do
          print_warn "  $line"
        done
      fi
      FAILED_TARGETS+=("$target")
    fi

    [[ -n "$error_log" ]] && rm -f "$error_log" 2>/dev/null || true
  else
    print_warn "Skipping missing path: $target"
  fi
}

remove_path_fast() {
  local target="$1"
  local error_log="${2:-}"

  if [[ "$target" == "$HOME/Library/Developer/XCTestDevices" || "$target" == "$HOME/Library/Developer/CoreSimulator" ]]; then
    remove_children_with_progress "$target" "$error_log"
    return $?
  fi

  if [[ -n "$error_log" ]]; then
    sudo rm -rf "$target" 2>>"$error_log"
  else
    sudo rm -rf "$target"
  fi
}

remove_children_with_progress() {
  local target="$1"
  local error_log="${2:-}"
  local child=""
  local count=0
  local total=0
  local status=0
  local children=()

  while IFS= read -r child; do
    [[ -n "$child" ]] || continue
    children+=("$child")
  done < <(/usr/bin/find "$target" -mindepth 1 -maxdepth 1 -print 2>/dev/null || true)

  total=${#children[@]}
  if (( total == 0 )); then
    if [[ -n "$error_log" ]]; then
      sudo rmdir "$target" 2>>"$error_log" || return $?
    else
      sudo rmdir "$target" || return $?
    fi
    return 0
  fi

  for child in "${children[@]}"; do
    count=$((count + 1))
    print_info "Removing item $count/$total: ${child:t}"
    if [[ -n "$error_log" ]]; then
      sudo rm -rf "$child" 2>>"$error_log" || status=$?
    else
      sudo rm -rf "$child" || status=$?
    fi
  done

  if [[ -n "$error_log" ]]; then
    sudo rmdir "$target" 2>>"$error_log" || status=$?
  else
    sudo rmdir "$target" || status=$?
  fi

  return $status
}

remove_empty_library_developer_dir() {
  if [[ -d "/Library/Developer" ]]; then
    sudo rmdir "/Library/Developer" 2>/dev/null || true
  fi
}

prepare_remove_path() {
  local target="$1"

  print_info "Clearing file flags in $target"
  sudo chflags -R nouchg,noschg "$target" 2>/dev/null || true
  print_info "Clearing ACLs in $target"
  sudo chmod -RN "$target" 2>/dev/null || true
  print_info "Making files writable in $target"
  sudo chmod -R u+rwX "$target" 2>/dev/null || true
  print_info "Clearing extended attributes in $target"
  sudo xattr -rc "$target" 2>/dev/null || true
}

show_targets() {
  print_step "Targets"
  local target=""
  for target in "${TARGETS[@]}"; do
    printf "  - %s\n" "$target"
  done
}

show_preserved_items() {
  if (( ${#PRESERVED_ITEMS[@]} > 0 )); then
    print_step "Preserved in this mode"
    local item=""
    for item in "${PRESERVED_ITEMS[@]}"; do
      printf "  - %s\n" "$item"
    done
  fi
}

sum_target_bytes() {
  local total=0
  local target=""
  local path_bytes=0

  for target in "${TARGETS[@]}"; do
    path_bytes=$(size_bytes_of_path "$target")
    if ! is_non_negative_integer "$path_bytes"; then
      path_bytes=0
    fi
    total=$((total + path_bytes))
  done

  printf "%s\n" "$total"
}

capture_free_bytes() {
  local blocks=""
  blocks=$(df -k / | awk 'NR==2 {print $4}' || true)
  if is_non_negative_integer "$blocks"; then
    printf "%s\n" $((blocks * 1024))
  else
    printf "0\n"
  fi
}

human_bytes() {
  local bytes="${1:-0}"
  awk -v bytes="$bytes" 'BEGIN {
    split("B KB MB GB TB PB", units, " ")
    value = bytes + 0
    unit = 1
    while (value >= 1024 && unit < 6) {
      value /= 1024
      unit++
    }
    printf "%.2f %s\n", value, units[unit]
  }'
}

show_disk_usage() {
  if (( ESTIMATE_SIZES )); then
    print_step "Current developer-related disk usage"
  else
    print_step "Current developer-related paths"
  fi
  local target=""
  for target in "${TARGETS[@]}"; do
    if [[ -e "$target" ]]; then
      printf "%8s  %s\n" "$(safe_human_size_of_path "$target")" "$target"
    fi
  done
  echo
  df -h /
}

remove_xcode_from_dock() {
  print_step "Removing Xcode from Dock"
  local plist="$HOME/Library/Preferences/com.apple.dock.plist"
  local buddy="/usr/libexec/PlistBuddy"
  local found=0

  if [[ ! -f "$plist" ]]; then
    print_warn "Dock plist not found, skipping"
    return 0
  fi

  killall cfprefsd 2>/dev/null || true

  local key=""
  for key in "persistent-apps" "recent-apps" "persistent-others"; do
    local indices=()
    local idx=0

    while "$buddy" -c "Print :${key}:${idx}" "$plist" >/dev/null 2>&1; do
      local label=""
      local url=""
      local bundle_id=""
      local label_lc=""
      local url_lc=""

      label=$("$buddy" -c "Print :${key}:${idx}:tile-data:file-label" "$plist" 2>/dev/null || true)
      url=$("$buddy" -c "Print :${key}:${idx}:tile-data:file-data:_CFURLString" "$plist" 2>/dev/null || true)
      bundle_id=$("$buddy" -c "Print :${key}:${idx}:tile-data:bundle-identifier" "$plist" 2>/dev/null || true)
      label_lc=$(printf "%s" "$label" | tr '[:upper:]' '[:lower:]')
      url_lc=$(printf "%s" "$url" | tr '[:upper:]' '[:lower:]')

      if [[ "$label_lc" == "xcode" || "$url_lc" == *"xcode.app"* || "$bundle_id" == "com.apple.dt.Xcode" ]]; then
        indices+=("$idx")
        found=1
      fi

      idx=$((idx + 1))
    done

    local i=0
    for (( i=${#indices[@]}-1; i>=0; i-- )); do
      "$buddy" -c "Delete :${key}:${indices[i]}" "$plist" >/dev/null 2>&1 || true
    done
  done

  if (( found )); then
    print_ok "Removed Xcode from Dock entries"
  else
    print_warn "Xcode not found in Dock entries"
  fi

  killall cfprefsd 2>/dev/null || true
  killall Dock 2>/dev/null || true
  print_ok "Dock refreshed"
}

scan_known_paths() {
  print_step "Known Xcode-related paths"
  local any=0
  local seen=()
  local target=""
  local known_targets=("${FULL_TARGETS[@]}")
  local pattern=""

  for pattern in "${FULL_GLOB_TARGETS[@]}"; do
    for target in ${~pattern}(N); do
      known_targets+=("$target")
    done
  done

  for target in "${known_targets[@]}"; do
    if [[ -e "$target" ]]; then
      if (( ${seen[(Ie)$target]} == 0 )); then
        seen+=("$target")
        printf "%8s  %s\n" "$(safe_human_size_of_path "$target")" "$target"
        any=1
      fi
    fi
  done

  if (( ! any )); then
    print_ok "No known full-purge targets were found"
  fi
}

scan_by_name() {
  print_step "Name-based leftover scan"
  local root=""
  local matches=()
  local item=""

  for root in "${SCAN_ROOTS[@]}"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r item; do
      [[ -n "$item" ]] || continue
      matches+=("$item")
    done < <(/usr/bin/find "$root" -maxdepth 3 \( -iname '*xcode*' -o -iname '*simulator*' -o -iname '*coresimulator*' -o -iname '*xctest*' \) -print 2>/dev/null || true)
  done

  if (( ${#matches[@]} == 0 )); then
    print_ok "No additional name-based leftovers found"
    return 0
  fi

  local unique_matches=("${(@ou)matches}")
  for item in "${unique_matches[@]}"; do
    printf "  - %s\n" "$item"
  done
}

scan_remaining() {
  scan_known_paths
  scan_by_name
}

show_failed_targets() {
  local target=""
  local has_core_simulator=0

  if (( ${#FAILED_TARGETS[@]} == 0 )); then
    return 0
  fi

  print_step "Targets needing follow-up"
  for target in "${FAILED_TARGETS[@]}"; do
    printf "  - %s\n" "$target"
    [[ "$target" == "/Library/Developer/CoreSimulator" ]] && has_core_simulator=1
  done

  if (( has_core_simulator )); then
    print_warn "CoreSimulator can be held by runtime mount services even after shutdown."
    print_warn "Restart macOS and rerun this script with --full --yes before opening Xcode or Simulator."
    print_warn "If it still reports Operation not permitted, give Terminal Full Disk Access and rerun."
  fi
}

print_summary() {
  print_step "Cleanup summary"
  local observed_freed=0
  if (( BYTES_AFTER > BYTES_BEFORE )); then
    observed_freed=$((BYTES_AFTER - BYTES_BEFORE))
  fi

  if (( ESTIMATE_SIZES )); then
    printf "%s\n" "${CYAN}Estimated cleanup payload:${RESET} $(human_bytes "$ESTIMATED_BYTES")"
    printf "%s\n" "${CYAN}Processed removable content:${RESET} $(human_bytes "$REMOVED_BYTES")"
  else
    printf "%s\n" "${CYAN}Size estimate:${RESET} skipped (choose size estimate in the menu or use --estimate-sizes)"
  fi
  printf "%s\n" "${GREEN}${BOLD}Observed free-space change:${RESET} $(human_bytes "$observed_freed")"
  echo
  printf "%s\n" "${MAGENTA}Before:${RESET} $(human_bytes "$BYTES_BEFORE") free"
  printf "%s\n" "${MAGENTA}After :${RESET} $(human_bytes "$BYTES_AFTER") free"
  echo
  if [[ "$MODE" == "keep-base" ]]; then
    printf "%s\n" "${YELLOW}Keep-base mode preserved Xcode.app, Command Line Tools, and simulator runtimes.${RESET}"
  fi
  printf "%s\n" "${CYAN}────────────────────────────  CLEANUP COMPLETE  ────────────────────────────${RESET}"
}

main() {
  parse_args "$@"

  print_banner
  print_warn "This script permanently removes files. Review the selected mode carefully."
  print_warn "Choose Scan only first if you only want to inspect leftovers."

  if (( SCAN_ONLY )); then
    scan_remaining
    print_ok "Scan finished; no files were removed"
    return 0
  fi

  choose_mode
  if (( SCAN_ONLY )); then
    scan_remaining
    print_ok "Scan finished; no files were removed"
    return 0
  fi

  choose_size_estimate
  BYTES_BEFORE=$(capture_free_bytes)
  show_targets
  show_preserved_items
  if (( ESTIMATE_SIZES )); then
    ESTIMATED_BYTES=$(sum_target_bytes)
    print_info "Estimated removable payload: $(human_bytes "$ESTIMATED_BYTES")"
  else
    print_info "Size estimate skipped for faster startup"
  fi
  show_disk_usage

  if ! confirm "Do you want to continue"; then
    print_warn "Aborted by user"
    return 0
  fi

  if ! confirm "Remove all selected targets now"; then
    print_warn "File removal skipped by user"
    return 0
  fi

  print_step "Stopping Xcode and simulator-related processes"
  shutdown_simulators
  if [[ "$MODE" == "full" ]]; then
    delete_simulator_devices_and_runtimes
  fi
  safe_kill "Xcode"
  safe_kill "Simulator"
  safe_kill "xcodebuild"
  safe_kill_pattern_sudo "CoreSimulator"
  safe_kill_pattern_sudo "com.apple.CoreSimulator.CoreSimulatorService"
  safe_kill_pattern_sudo "simdiskimaged"
  safe_kill_pattern "iphonesimulator"
  safe_kill_pattern "XCTest"
  safe_kill_pattern "xctest"
  safe_kill_pattern "SourceKitService"
  safe_kill_pattern "swift-frontend"
  print_ok "Process cleanup finished"

  if [[ "$MODE" == "full" ]]; then
    unmount_core_simulator_volumes
  fi

  print_step "Removing selected targets"
  local local_target=""
  for local_target in "${TARGETS[@]}"; do
    remove_path "$local_target"
  done
  remove_empty_library_developer_dir

  if [[ "$MODE" == "full" ]]; then
    print_step "Resetting active developer directory"
    sudo xcode-select --reset 2>/dev/null || true
    print_ok "xcode-select reset attempted"
  else
    print_step "Preserving base install"
    print_ok "Skipped xcode-select reset in keep-base mode"
  fi

  if (( SKIP_DOCK )); then
    print_warn "Dock cleanup skipped by --no-dock"
  elif confirm "Remove Xcode from Dock"; then
    remove_xcode_from_dock
  else
    print_warn "Dock cleanup skipped by user"
  fi

  print_step "Post-cleanup scan"
  scan_remaining
  show_failed_targets

  echo
  print_step "Current free disk space"
  /bin/df -h /

  BYTES_AFTER=$(capture_free_bytes)
  print_summary
  print_ok "Cleanup script finished"
}

main "$@"
