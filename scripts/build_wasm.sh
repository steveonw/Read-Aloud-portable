#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${READALOUD_WORK_DIR:-$PROJECT_ROOT/build/work}"
SHERPA_TAG="${SHERPA_TAG:-v1.13.4}"
MODEL_URL="${AMY_MODEL_URL:-https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-amy-medium.tar.bz2}"
REPO_DIR="$WORK_DIR/sherpa-onnx"
MODEL_ARCHIVE="$WORK_DIR/vits-piper-en_US-amy-medium.tar.bz2"
OUTPUT_DIR="$PROJECT_ROOT/build/wasm"

for command in git curl tar emcc cmake python3; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Missing required build command: %s\n' "$command" >&2
    exit 1
  fi
done

rm -rf "$REPO_DIR" "$OUTPUT_DIR"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

printf 'Cloning sherpa-onnx %s...\n' "$SHERPA_TAG"
git clone --depth 1 --branch "$SHERPA_TAG" https://github.com/k2-fsa/sherpa-onnx.git "$REPO_DIR"

printf 'Downloading converted Amy medium model...\n'
curl --fail --location --retry 4 --retry-delay 3 \
  --output "$MODEL_ARCHIVE" "$MODEL_URL"

MODEL_UNPACK="$WORK_DIR/model-unpack"
rm -rf "$MODEL_UNPACK"
mkdir -p "$MODEL_UNPACK"
tar -xjf "$MODEL_ARCHIVE" -C "$MODEL_UNPACK"

MODEL_FILE="$(find "$MODEL_UNPACK" -type f -name 'en_US-amy-medium.onnx' -print -quit)"
TOKENS_FILE="$(find "$MODEL_UNPACK" -type f -name 'tokens.txt' -print -quit)"
ESPEAK_DIR="$(find "$MODEL_UNPACK" -type d -name 'espeak-ng-data' -print -quit)"

if [[ -z "$MODEL_FILE" || -z "$TOKENS_FILE" || -z "$ESPEAK_DIR" ]]; then
  printf 'The Amy archive did not contain the expected model, tokens, and espeak-ng-data.\n' >&2
  exit 1
fi

ASSETS="$REPO_DIR/wasm/tts/assets"
find "$ASSETS" -mindepth 1 -maxdepth 1 ! -name README.md -exec rm -rf {} +
cp "$MODEL_FILE" "$ASSETS/model.onnx"
cp "$TOKENS_FILE" "$ASSETS/tokens.txt"
cp -R "$ESPEAK_DIR" "$ASSETS/espeak-ng-data"

printf 'Building single-threaded SIMD WebAssembly TTS...\n'
(
  cd "$REPO_DIR"
  ./build-wasm-simd-tts.sh
)

GENERATED="$REPO_DIR/build-wasm-simd-tts/install/bin/wasm/tts"
if [[ ! -d "$GENERATED" ]]; then
  printf 'Sherpa build completed without the expected output directory: %s\n' "$GENERATED" >&2
  exit 1
fi

cp -R "$GENERATED"/. "$OUTPUT_DIR"/
cp "$PROJECT_ROOT/web/index.html" "$OUTPUT_DIR/index.html"
cp "$PROJECT_ROOT/web/app.js" "$OUTPUT_DIR/app.js"
cp "$PROJECT_ROOT/web/style.css" "$OUTPUT_DIR/style.css"

for required in index.html app.js style.css sherpa-onnx-tts.js sherpa-onnx-tts.worker.js; do
  if [[ ! -f "$OUTPUT_DIR/$required" ]]; then
    printf 'Missing generated file: %s\n' "$required" >&2
    exit 1
  fi
done

if ! compgen -G "$OUTPUT_DIR/*.wasm" >/dev/null; then
  printf 'No .wasm file was generated.\n' >&2
  exit 1
fi
if ! compgen -G "$OUTPUT_DIR/*.data" >/dev/null; then
  printf 'No Emscripten .data package was generated.\n' >&2
  exit 1
fi

printf 'WASM application written to %s\n' "$OUTPUT_DIR"
