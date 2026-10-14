# Tork developer bootstrap

1. Windows PowerShell **as Administrator**:

```powershell
irm https://raw.githubusercontent.com/torkjacobs/tork-dev-bootstrap/main/windows.ps1 | iex
```

Expected: `Done. Restart now? (Y/N)`. Restart, open Ubuntu and create your Linux user.

2. Ubuntu terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/torkjacobs/tork-dev-bootstrap/main/install.sh | bash
```

Expected: the toolkit health check. Browser authentication requires your own accounts and subscriptions.

Inspect [windows.ps1](windows.ps1) and [install.sh](install.sh) before executing. Retry a failed Ubuntu stage with `bash -s -- --resume` in the second command. Preview with `bash -s -- --dry-run`.

This public repository contains no credentials. Private tools and product access require a GitHub invitation and the shared 1Password vault.

The stages install Ubuntu packages, nvm/Node LTS, official GitHub and 1Password CLIs, identity, AI CLIs, the private toolkit, login and doctor. Supabase CLI and Vercel CLI are also installed for token validation. Gemini sign-in can be deferred if the vendor does not support your account; doctor shows its actual condition.

The Windows script installs the native 1Password CLI too. Ubuntu prefers `op.exe` when available, letting it use the Windows desktop app and Windows Hello; Linux `op signin` is the fallback. Enable **Settings → Developer → Integrate with 1Password CLI** in the Windows app. This desktop setting has no supported installer API and is not silently claimed as enabled.

Google is opened before the first GitHub browser sign-in. Each service controls its own sign-in buttons: select **Continue with Google** where offered, use existing subscribed accounts, and never create a replacement account. Paid Claude/Codex account information is checked when exposed by their tools. Credentials go only to the configured 1Password vault or private local authentication files.

The installer follows Node LTS. A blocked vendor capability or unavailable vault item produces a clear error and resume command; no failing check is bypassed.
