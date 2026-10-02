# eitaas-vdi

Connect to the **Air Force EITaaS virtual desktop** (Azure Virtual Desktop in the Azure US Government cloud) from Linux, **with your CAC passed through into the Windows session**. Your card then works inside the VDI for CAC-protected sites, digital signatures and encrypted email.

Microsoft's own client, the *Windows App*, has no Linux version. The AVD web client runs in a Linux browser, but it can't pass your smart card into the session. `eitaas-vdi` fills that gap with stock, distribution-packaged software:

- **FreeRDP 3** (`sdl-freerdp3`) runs the remote desktop natively on Wayland or X11 and redirects your CAC over PC/SC.
- **Your normal Chrome/Chromium CAC setup** handles the Microsoft sign-in, so certificate selection and the PIN prompt work the same way they do on any CAC-enabled site.
- **A small launcher** (one Python file, standard library only) connects the two. It adds a desktop entry, a first-run setup, popups for problems, and a redacted log.

> [!IMPORTANT]
> This is an **unofficial, community-made tool**. It isn't produced, endorsed or supported by the Department of the Air Force, the DoD, Microsoft, or the EITaaS program and its service center. It connects to the same AVD service and uses the same CAC sign-in as the official clients. **Check with your unit's cybersecurity office/ISSM** that accessing the VDI this way from your device is allowed before you use it.

## Status

| | |
|---|---|
| Tested | Arch Linux / [Omarchy](https://omarchy.org) (Hyprland, Wayland), FreeRDP 3.31.1, Google Chrome, single monitor. CAC sign-in, CAC passthrough into the session, and disconnect are verified on the real VDI. |
| Should work | Any distribution with **FreeRDP ≥ 3.16** built with AAD and PC/SC support, a native (non-Flatpak/Snap) Chrome or Chromium, and pcsc-lite + OpenSC. |
| Won't work | FreeRDP 2.x or 3.x older than 3.16 (e.g. Ubuntu 24.04's `freerdp3-sdl` 3.5). Flatpak or Snap browsers, which can't see the CAC module in `~/.pki/nssdb`. |

`eitaas-vdi doctor` checks all of this for you.

## Quick start

```bash
git clone https://github.com/Athesias/eitaas-vdi-linux.git
cd eitaas-vdi-linux
./install.sh
```

Then open **EITaaS VDI** from your application launcher. The first launch walks you through importing your workspace profile from the web client. After that, each launch signs you in with your CAC and opens the desktop.

**Read the [Standard Operating Procedure](docs/SOP.md)** for full setup (packages, CAC in the browser), daily use, disconnecting, troubleshooting and security notes.

## How it works

```
 eitaas-vdi ──starts──▶ sdl-freerdp3 profile.rdpw /gateway:type:arm /sec:aad /smartcard …
     │                        │
     │   "Browse to: https://login.microsoftonline.us/…"   (FreeRDP needs an Entra ID token)
     │◀───────────────────────┘
     ├─▶ opens that URL in a dedicated Chrome --app window
     │        └─ you pick your PIV certificate and enter your PIN (Chrome + OpenSC)
     ├─◀ catches the redirect (…/oauth2/nativeclient?code=…) over Chrome's private DevTools pipe
     └─▶ hands it back to FreeRDP, which finishes sign-in and opens the desktop
                                   └─ your CAC is redirected into Windows over PC/SC
```

- **Azure US Government endpoints.** FreeRDP defaults to the commercial cloud. The launcher points it at `login.microsoftonline.us` with the `www.wvd.azure.us` scope.
- **One sign-in window, one PIN.** FreeRDP asks for two tokens (the gateway, then the session host). Both run in the same sign-in window, which keeps your CAC unlocked and the Microsoft session alive, so you enter your PIN once. The window shows a "connecting" page in between and closes once Windows logs you on.
- **Separate sign-in browser profile.** The sign-in browser uses its own profile (`~/.local/share/eitaas-vdi/signin-browser`), so it never touches your everyday browser. `eitaas-vdi signout` deletes it.
- **Profile import.** `.rdpw` files are checked on import (must be an ARM/AVD profile with a `*.wvd.azure.us` gateway) and stored with mode `0600`.
- **Fullscreen on Hyprland.** The desktop opens fullscreen on the monitor you launched from, at that monitor's resolution. Put `start = windowed` in `~/.config/eitaas-vdi/settings` to get a window instead.
- **Follows your Omarchy theme.** On Omarchy, the popups and the sign-in window's "connecting" page use the colors of your current theme (Omarchy itself colors the sign-in browser's frame, the notifications and the window border). On other desktops they keep their stock look. Put `theme = default` in `~/.config/eitaas-vdi/settings` to opt out.
- **Log.** `~/.local/state/eitaas-vdi/last.log` has authorization codes, tokens and your logon identity (domain\user, DoD ID number) redacted.

### FreeRDP issues it works around

These are real FreeRDP 3.30–3.32 behaviors that otherwise break AVD on Linux:

| Problem | What eitaas-vdi does |
|---|---|
| FreeRDP's hostname check rejects wildcard certificates (`*.wvd.azure.us`): its URL regex has no `*`. Every AVD gateway then shows a scary "certificate name mismatch" prompt. | Verifies the gateway certificates itself with Python's `ssl` (system CA store plus a correct hostname check) and pins the verified SHA-256 fingerprints with `/cert:fingerprint:…`. Nothing is ever blindly trusted. |
| Web-client profiles set both `smart sizing` and `dynamic resolution`. FreeRDP refuses that combination (exit 22). | Runs FreeRDP on a private per-session copy (`$XDG_RUNTIME_DIR/eitaas-vdi/session.rdpw`) with smart sizing off. |
| Profiles set `use multimon` + `singlemoninwindowedmode`. FreeRDP ignores the latter and fails with 64×64 "monitors" (exit 136). | The session copy uses one monitor, unless you ask for multi-monitor in `freerdp-args`. |
| On Wayland, FreeRDP's SDL3 client measures monitors from its not-yet-sized window (64×64), so its own fullscreen (`/f`) and `/multimon` fail the pre-connect check. | On Hyprland the session is sized to the focused monitor (`/size:`) and Hyprland fullscreens the window when it appears. Windows starts at the right resolution. |
| FreeRDP never sends the window's size when the resize channel comes up, so a window a tiling WM resized at startup stays a 1024×768 box. | Windowed mode on Hyprland: re-tiles the window once at that moment so the real size is sent. Other desktops: resize the window once. |
| The Right Shift+D disconnect exits with the same code as a failed connection (131). | Recognizes the hotkey in the log and doesn't report an error. |

## Files

| Path | What |
|---|---|
| `eitaas-vdi` | The launcher (Python 3, standard library only) |
| `eitaas-vdi.desktop.in` | Launcher entry template; `install.sh` fills in the path |
| `install.sh` | Per-user install, update, `--uninstall`, `--purge` |
| `hyprland/eitaas-vdi.lua` | Optional Hyprland rules that float the sign-in window and the CAC PIN dialog |
| `docs/SOP.md` | Standard Operating Procedure for users |

## Credits

The Azure US Government sign-in values (authority, scope, redirect) and the ARM gateway timeout were first worked out and hardware-validated by **[EITaaS-Linux](https://github.com/sjtrotter/EITaaS-Linux)** (MIT). That project takes a different approach: patched Remmina/FreeRDP packages with an embedded WebKit sign-in. eitaas-vdi is an independent implementation that uses unmodified distribution FreeRDP and your existing browser CAC setup.

## License

[MIT](LICENSE)
