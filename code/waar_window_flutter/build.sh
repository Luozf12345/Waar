#!/usr/bin/env bash
# Build APK + desktop app for the current host platform.
# Release artifacts -> ../../app/
# Debug artifacts    -> ../../app/debug/
#
# Usage:
#   ./build.sh                              # interactive mode selection
#   ./build.sh debug                        # build debug
#   ./build.sh release                      # build release (default)
#   ./build.sh --flutter-sdk /path release  # override Flutter SDK
#   FLUTTER_SDK=/path ./build.sh release    # via environment variable
#
# Flutter SDK is read from local.prop by default (see local.prop.example).

set -euo pipefail

APP_NAME="waar_window_flutter"
DEFAULT_FLUTTER_SDK="${HOME}/tools/flutter1"
LOCAL_PROP_FILE="local.prop"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_RELEASE="$REPO_ROOT/app"
OUTPUT_DEBUG="$REPO_ROOT/app/debug"

FLUTTER_SDK="${FLUTTER_SDK:-}"
BUILD_MODE_ARG=""

usage() {
  cat <<EOF
Usage: ./build.sh [options] [debug|release]

Build APK and a desktop app for the current environment:
  - macOS Apple Silicon (arm64)
  - macOS Intel (x86_64)
  - Windows (x64)

Options:
  --flutter-sdk <path>  Override Flutter SDK directory
                        priority: --flutter-sdk > FLUTTER_SDK env > local.prop > ${DEFAULT_FLUTTER_SDK}

Output:
  release -> app/
  debug   -> app/debug/
EOF
}

expand_home_path() {
  local path="$1"
  if [[ "$path" == "~" ]]; then
    echo "$HOME"
  elif [[ "$path" == "~/"* ]]; then
    echo "${HOME}/${path:2}"
  elif [[ "$path" == "~"* ]]; then
    echo "${HOME}/${path:1}"
  else
    echo "$path"
  fi
}

load_flutter_sdk_from_local_prop() {
  local prop_file="$SCRIPT_DIR/$LOCAL_PROP_FILE"
  [[ -f "$prop_file" ]] || return 0

  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    [[ "$line" != *"="* ]] && continue

    key="${line%%=*}"
    value="${line#*=}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"

    if [[ "$key" == "flutter.sdk" && -n "$value" ]]; then
      FLUTTER_SDK="$(expand_home_path "$value")"
      return 0
    fi
  done < "$prop_file"
}

resolve_flutter_sdk() {
  if [[ -z "$FLUTTER_SDK" ]]; then
    load_flutter_sdk_from_local_prop
  fi
  if [[ -z "$FLUTTER_SDK" ]]; then
    FLUTTER_SDK="$DEFAULT_FLUTTER_SDK"
  fi
}

sync_android_local_properties() {
  local android_props="$SCRIPT_DIR/android/local.properties"
  local sdk_dir_line=""

  if [[ -f "$android_props" ]]; then
    sdk_dir_line="$(grep '^sdk\.dir=' "$android_props" || true)"
  fi

  {
    echo "flutter.sdk=$FLUTTER_SDK"
    if [[ -n "$sdk_dir_line" ]]; then
      echo "$sdk_dir_line"
    fi
  } > "$android_props"
}

resolve_flutter_bin() {
  local sdk_dir="$1"
  local flutter_bin="$sdk_dir/bin/flutter"

  if [[ ! -x "$flutter_bin" ]]; then
    echo "Flutter executable not found: $flutter_bin" >&2
    exit 1
  fi

  echo "$flutter_bin"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help|help)
        usage
        exit 0
        ;;
      --flutter-sdk)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for --flutter-sdk" >&2
          usage >&2
          exit 1
        fi
        FLUTTER_SDK="$2"
        shift 2
        ;;
      debug|Debug|DEBUG|release|Release|RELEASE)
        if [[ -n "$BUILD_MODE_ARG" ]]; then
          echo "Duplicate build mode: $1" >&2
          usage >&2
          exit 1
        fi
        BUILD_MODE_ARG="$1"
        shift
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
}

resolve_build_mode() {
  local arg="${1:-}"

  case "$arg" in
    -h|--help|help)
      usage
      exit 0
      ;;
    debug|Debug|DEBUG)
      echo "debug"
      return
      ;;
    release|Release|RELEASE|"")
      if [[ -z "$arg" && -t 0 ]]; then
        echo "Select build mode:" >&2
        echo "  1) debug" >&2
        echo "  2) release" >&2
        read -r -p "Choice [1-2] (default: 2): " choice
        case "${choice:-2}" in
          1) echo "debug"; return ;;
          2|"") echo "release"; return ;;
          *)
            echo "Invalid choice: $choice" >&2
            exit 1
            ;;
        esac
      fi
      echo "release"
      return
      ;;
    *)
      echo "Unknown build mode: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
}

detect_platform() {
  case "$(uname -s)" in
    Darwin)
      PLATFORM="macos"
      ARCH="$(uname -m)"
      case "$ARCH" in
        arm64) PLATFORM_LABEL="macOS Apple Silicon (arm64)" ;;
        x86_64) PLATFORM_LABEL="macOS Intel (x86_64)" ;;
        *) PLATFORM_LABEL="macOS ($ARCH)" ;;
      esac
      ;;
    MINGW*|MSYS*|CYGWIN*)
      PLATFORM="windows"
      ARCH="x64"
      PLATFORM_LABEL="Windows (x64)"
      ;;
    *)
      echo "Unsupported host OS: $(uname -s)" >&2
      exit 1
      ;;
  esac
}

prepare_output_dir() {
  local out_dir="$1"
  mkdir -p "$out_dir"
}

copy_apk() {
  local mode="$1"
  local out_dir="$2"
  local apk_name

  if [[ "$mode" == "debug" ]]; then
    apk_name="app-debug.apk"
  else
    apk_name="app-release.apk"
  fi

  local src="$SCRIPT_DIR/build/app/outputs/flutter-apk/$apk_name"
  if [[ ! -f "$src" ]]; then
    echo "APK not found: $src" >&2
    exit 1
  fi

  cp "$src" "$out_dir/${APP_NAME}.apk"
  echo "  APK -> $out_dir/${APP_NAME}.apk"
}

copy_desktop_artifact() {
  local mode="$1"
  local out_dir="$2"
  local product_dir

  if [[ "$mode" == "debug" ]]; then
    product_dir="Debug"
  else
    product_dir="Release"
  fi

  case "$PLATFORM" in
    macos)
      local src="$SCRIPT_DIR/build/macos/Build/Products/$product_dir/${APP_NAME}.app"
      if [[ ! -d "$src" ]]; then
        echo "macOS app not found: $src" >&2
        exit 1
      fi
      rm -rf "$out_dir/${APP_NAME}.app"
      cp -R "$src" "$out_dir/"
      echo "  Desktop -> $out_dir/${APP_NAME}.app"
      ;;
    windows)
      local src="$SCRIPT_DIR/build/windows/x64/runner/$product_dir"
      if [[ ! -d "$src" ]]; then
        echo "Windows build not found: $src" >&2
        exit 1
      fi
      rm -rf "$out_dir/${APP_NAME}"
      mkdir -p "$out_dir/${APP_NAME}"
      cp -R "$src/"* "$out_dir/${APP_NAME}/"
      echo "  Desktop -> $out_dir/${APP_NAME}/"
      ;;
  esac
}

build_desktop() {
  local mode="$1"
  local flutter_mode_flag="--$mode"

  case "$PLATFORM" in
    macos)
      "$FLUTTER_BIN" build macos "$flutter_mode_flag"
      ;;
    windows)
      "$FLUTTER_BIN" build windows "$flutter_mode_flag"
      ;;
  esac
}

main() {
  parse_args "$@"
  resolve_flutter_sdk

  local build_mode
  build_mode="$(resolve_build_mode "$BUILD_MODE_ARG")"
  FLUTTER_BIN="$(resolve_flutter_bin "$FLUTTER_SDK")"
  detect_platform

  local out_dir
  if [[ "$build_mode" == "debug" ]]; then
    out_dir="$OUTPUT_DEBUG"
  else
    out_dir="$OUTPUT_RELEASE"
  fi

  echo "==> Build mode   : $build_mode"
  echo "==> Platform     : $PLATFORM_LABEL"
  echo "==> Flutter SDK  : $FLUTTER_SDK"
  echo "==> Output dir   : $out_dir"
  echo

  cd "$SCRIPT_DIR"
  prepare_output_dir "$out_dir"
  sync_android_local_properties

  echo "==> Building APK..."
  "$FLUTTER_BIN" build apk "--$build_mode"

  echo "==> Building desktop app..."
  build_desktop "$build_mode"

  echo "==> Copying artifacts..."
  copy_apk "$build_mode" "$out_dir"
  copy_desktop_artifact "$build_mode" "$out_dir"

  echo
  echo "Build completed."
  echo "Artifacts:"
  echo "  - $out_dir/${APP_NAME}.apk"
  case "$PLATFORM" in
    macos) echo "  - $out_dir/${APP_NAME}.app" ;;
    windows) echo "  - $out_dir/${APP_NAME}/" ;;
  esac
}

main "$@"
