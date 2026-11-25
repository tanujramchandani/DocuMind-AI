#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
tools_dir="$root_dir/.tools"
export PATH="$tools_dir/bin:$tools_dir/node/bin:$PATH"

if ! command -v uv >/dev/null 2>&1; then
    command -v curl >/dev/null 2>&1 || { echo 'Install curl to bootstrap uv.' >&2; exit 1; }
    mkdir -p "$tools_dir/bin"
    installer="$(mktemp)"
    trap 'rm -f "$installer"' EXIT
    curl -fsSL https://astral.sh/uv/0.13.4/install.sh -o "$installer"
    UV_INSTALL_DIR="$tools_dir/bin" sh "$installer"
fi

node_major=0
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    node_major="$(node -p 'Number(process.versions.node.split(".")[0])')"
fi
if (( node_major < 20 )); then
    command -v curl >/dev/null 2>&1 || { echo 'Install curl to bootstrap Node.js.' >&2; exit 1; }
    case "$(uname -s)-$(uname -m)" in
        Linux-x86_64) platform=linux-x64 ;;
        Linux-aarch64|Linux-arm64) platform=linux-arm64 ;;
        Darwin-x86_64) platform=darwin-x64 ;;
        Darwin-arm64) platform=darwin-arm64 ;;
        *) echo 'Unsupported platform. Install Node.js 20 or newer manually.' >&2; exit 1 ;;
    esac
    archive="node-v22.23.5-$platform.tar.gz"
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "$temp_dir"; [[ -z "${installer:-}" ]] || rm -f "$installer"' EXIT
    curl -fsSL "https://nodejs.org/dist/v22.23.5/$archive" -o "$temp_dir/$archive"
    curl -fsSL https://nodejs.org/dist/v22.23.5/SHASUMS256.txt -o "$temp_dir/SHASUMS256.txt"
    expected="$(awk -v name="$archive" '$2 == name {print $1}' "$temp_dir/SHASUMS256.txt")"
    if command -v sha256sum >/dev/null 2>&1; then
        actual="$(sha256sum "$temp_dir/$archive" | awk '{print $1}')"
    else
        actual="$(shasum -a 256 "$temp_dir/$archive" | awk '{print $1}')"
    fi
    [[ -n "$expected" && "$actual" == "$expected" ]] || { echo 'Node.js checksum verification failed.' >&2; exit 1; }
    mkdir -p "$tools_dir/node"
    tar -xzf "$temp_dir/$archive" --strip-components=1 -C "$tools_dir/node"
    hash -r
fi

(cd "$root_dir/backend" && uv sync --locked)
(cd "$root_dir/frontend" && npm ci)
(cd "$root_dir/backend" && uv run --locked python "$root_dir/scripts/configure-env.py")

printf 'For this shell, run: export PATH="%s/bin:%s/node/bin:$PATH"\n' "$tools_dir" "$tools_dir"
cat <<'MESSAGE'
Installation complete. If you skipped the Groq key, add it to backend/.env before using chat.
Start the backend:  cd backend && uv run --locked uvicorn app.main:app --reload
Start the frontend: cd frontend && npm run dev
MESSAGE
