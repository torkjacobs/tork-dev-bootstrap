#!/usr/bin/env bash
set -Eeuo pipefail
DRY=0
RESUME=0
for arg in "$@"; do
  case "$arg" in --dry-run) DRY=1;; --resume) RESUME=1;; *) printf 'Unknown argument: %s\n' "$arg" >&2; exit 2;; esac
done
state="${XDG_STATE_HOME:-$HOME/.local/state}/tork-bootstrap"
stage=0
fix=''
trap 'printf "Stage %s failed. Fix: %s\nContinue: curl -fsSL https://raw.githubusercontent.com/torkjacobs/tork-dev-bootstrap/main/install.sh | bash -s -- --resume\n" "$stage" "$fix" >&2' ERR
run_stage() {
  stage="$1"; fix="$3"
  printf '[%s/7] %s\n' "$stage" "$2"
  if [ "$DRY" = 1 ]; then printf '  %s\n' "$fix"; return; fi
  if [ "$RESUME" = 1 ] && [ -f "$state/$stage" ]; then printf '  already complete\n'; return; fi
  "$4"
  mkdir -p "$state"; touch "$state/$stage"
}
packages() {
  [ "$(uname -s)" = Linux ] || { echo 'Run this installer in Ubuntu.' >&2; return 1; }
  sudo apt-get update
  sudo apt-get install -y git curl unzip jq build-essential python3 zsh wget ca-certificates gnupg
}
node() {
  export NVM_DIR="$HOME/.nvm"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    local nvm_installer
    nvm_installer=$(mktemp "${TMPDIR:-/tmp}/tork-nvm.XXXXXX")
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh -o "$nvm_installer"
    bash "$nvm_installer"
    rm "$nvm_installer"
  fi
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm alias default 'lts/*'
}
github() {
  if ! command -v gh >/dev/null; then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' "$(dpkg --print-architecture)" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update; sudo apt-get install -y gh
  fi
}
identity() {
  local name email answer
  name=$(git config --global user.name || printf 'Zunaid Mohidin')
  email=$(git config --global user.email || printf 'zunaid@tork.network')
  read -r -p "Git name [$name]: " answer </dev/tty; git config --global user.name "${answer:-$name}"
  read -r -p "Git email [$email]: " answer </dev/tty; git config --global user.email "${answer:-$email}"
  git config --global core.autocrlf input
  git config --global pull.rebase true
}
password() {
  if ! command -v op >/dev/null; then
    curl -fsSL https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor | sudo tee /usr/share/keyrings/1password-archive-keyring.gpg >/dev/null
    printf 'deb [arch=%s signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main\n' "$(dpkg --print-architecture)" | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
    sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22 /usr/share/debsig/keyrings/AC2D62742012EA22
    curl -fsSL https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol >/dev/null
    curl -fsSL https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor | sudo tee /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg >/dev/null
    sudo apt-get update; sudo apt-get install -y 1password-cli
  fi
  # Prefer Windows op.exe, which can reach the Windows desktop app/Hello.
  if command -v op.exe >/dev/null 2>&1; then
    mkdir -p "$HOME/bin"
    printf '#!/usr/bin/env bash\nexec op.exe "$@"\n' > "$HOME/bin/op"
    chmod 755 "$HOME/bin/op"
    export PATH="$HOME/bin:$PATH"
  fi
  op account get >/dev/null 2>&1 || eval "$(op signin </dev/tty)"
  op vault get 'Tork – Dev (Zunaid)' >/dev/null
}
engines() {
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  npm i -g @anthropic-ai/claude-code @openai/codex @google/gemini-cli vercel
  if ! command -v supabase >/dev/null; then
    local release_dir
    release_dir=$(mktemp -d)
    local release_url
    release_url=$(curl -fsSL https://api.github.com/repos/supabase/cli/releases/latest | jq -r --arg name "supabase_linux_$(dpkg --print-architecture).deb" '.assets[] | select(.name == $name) | .browser_download_url')
    [ -n "$release_url" ] || { printf 'Supabase release unavailable; install the official CLI and rerun --resume.\n' >&2; return 1; }
    curl -fsSL "$release_url" -o "$release_dir/supabase.deb"
    sudo apt-get install -y "$release_dir"/*.deb
    rm -rf "$release_dir"
  fi
}
toolkit() {
  if ! gh auth status >/dev/null 2>&1; then
    printf 'Sign in to Google once, then choose Continue with Google where offered. Never create a new account.\n'
    if command -v wslview >/dev/null; then wslview https://accounts.google.com
    elif command -v cmd.exe >/dev/null; then cmd.exe /c start https://accounts.google.com
    elif command -v xdg-open >/dev/null; then xdg-open https://accounts.google.com
    else printf 'Open https://accounts.google.com in your Windows browser.\n'; fi
    read -r -p 'Press Enter when signed in to your Tork Google account: ' </dev/tty
    export TORK_GOOGLE_CONFIRMED=1
    gh auth login --web -h github.com -p https </dev/tty
  fi
  gh auth setup-git
  mkdir -p "$HOME/tork"
  if [ ! -d "$HOME/tork/tork-toolkit/.git" ]; then gh repo clone torkjacobs/tork-toolkit "$HOME/tork/tork-toolkit"; fi
  TORK_INSTALL_NO_DOCTOR=1 bash "$HOME/tork/tork-toolkit/install.sh"
  export PATH="$HOME/bin:$PATH"
  tork login --first-run </dev/tty
  tork doctor
}
run_stage 1 'Ubuntu packages' 'sudo apt-get update && sudo apt-get install -y git curl unzip jq build-essential python3 zsh wget ca-certificates gnupg' packages
run_stage 2 'nvm + Node LTS' 'Install nvm from https://github.com/nvm-sh/nvm, then nvm install --lts' node
if [ "$DRY" = 0 ] && [ -s "$HOME/.nvm/nvm.sh" ]; then
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
fi
run_stage 3 'GitHub CLI (official apt repo)' 'gh auth login --web -h github.com -p https' github
run_stage 4 'Git identity' 'git config --global user.name "Zunaid Mohidin"; git config --global user.email "zunaid@tork.network"' identity
run_stage 5 '1Password CLI + vault' 'Enable desktop CLI integration; run op signin; check op vault get "Tork – Dev (Zunaid)"' password
run_stage 6 'Claude Code, Codex + Gemini CLI' 'npm i -g @anthropic-ai/claude-code @openai/codex @google/gemini-cli' engines
run_stage 7 'Private toolkit, login + doctor' 'gh repo clone torkjacobs/tork-toolkit ~/tork/tork-toolkit && bash ~/tork/tork-toolkit/install.sh' toolkit
