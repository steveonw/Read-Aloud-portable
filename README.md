# Read Aloud Portable Builder

This project builds one USB-ready folder for Windows x64, macOS Intel/Apple
Silicon, and Linux x64. The three operating systems use small native launchers;
the large browser application, Sherpa WebAssembly engine, and converted Piper
`en_US-amy-medium` voice are shared once.

## What is already included

- A pure-Go loopback server/launcher.
- Cross-build scripts for Windows, Linux, macOS x64, and macOS arm64.
- A universal macOS Mach-O packer, so the Mac app contains both architectures.
- A proofreading UI: paste text, highlight a sentence, press **F8**, hear it,
  and discard the audio.
- A Linux wrapper that copies the small native launcher to `~/.cache` before
  running, avoiding common exFAT/no-execute issues.
- A GitHub Actions builder that downloads the official converted Amy model,
  builds Sherpa WASM, and uploads the finished USB ZIP.

## Fastest build: GitHub Actions

1. Put this project in a GitHub repository.
2. Open **Actions**.
3. Run **Build Read Aloud USB**.
4. Download the `ReadAloudUSB` artifact.
5. Extract `ReadAloudUSB.zip` and copy the folder to an exFAT USB drive.

The build uses internet access, but the finished app does not.

## Local build

Requirements:

- Git
- Go 1.22+
- Python 3
- CMake and a build tool
- Emscripten SDK (`emcc` available in `PATH`)
- curl, tar, bzip2, and zip

Then run:

```bash
./scripts/build_all.sh
```

Output:

```text
dist/ReadAloudUSB/
dist/ReadAloudUSB.zip
```

## Resulting USB layout

```text
ReadAloudUSB/
├── START HERE.html
├── START - WINDOWS.exe
├── START - MACOS.app
├── START - LINUX.sh
├── shared/
│   ├── index.html
│   ├── app.js
│   ├── style.css
│   ├── sherpa-onnx-tts.js
│   ├── sherpa-onnx-tts.worker.js
│   ├── *.wasm
│   └── *.data
├── platform/linux/readaloud-server
├── LICENSES/
├── README.txt
└── SHA256SUMS.txt
```

## macOS signing

The builder creates a functional universal `.app`, but it cannot use your Apple
Developer identity automatically. For smooth distribution to nontechnical Mac
users, sign, notarize, and staple the app on a Mac. A helper is provided:

```bash
./scripts/sign_macos.sh \
  "Developer ID Application: Your Name (TEAMID)" \
  dist/ReadAloudUSB
```

Then submit a ZIP of the app with Apple's `notarytool` and staple the accepted
ticket. A private unsigned build can instead use macOS's one-time **Open
Anyway** approval.

## Reproducibility controls

Defaults are pinned in `scripts/build_wasm.sh`:

- Sherpa tag: `v1.13.4`
- Voice: official Sherpa-converted `vits-piper-en_US-amy-medium`

Override them only deliberately:

```bash
SHERPA_TAG=v1.13.4 AMY_MODEL_URL=https://... ./scripts/build_all.sh
```

## Runtime privacy

The launcher binds only to `127.0.0.1`. The browser loads local files from that
loopback server. Text is passed only to the in-page WASM worker, and generated
audio is played from memory rather than saved.
