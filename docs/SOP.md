# SOP: Accessing the EITaaS VDI from Linux with `eitaas-vdi`

| | |
|---|---|
| **Applies to** | Air Force members and civilians who use a Linux computer and have an EITaaS Azure Virtual Desktop (VDI) |
| **Tool** | `eitaas-vdi` (this repository), an unofficial community tool |
| **Effective** | 2 October 2026 |
| **Tested on** | Arch Linux / Omarchy (Hyprland, Wayland), FreeRDP 3.31.1, Google Chrome |

---

## Contents

1. [Purpose](#1-purpose)
2. [Before you start: important notices](#2-before-you-start-important-notices)
3. [What you need](#3-what-you-need)
4. [Procedure A: Prepare your computer (one time)](#4-procedure-a-prepare-your-computer-one-time)
5. [Procedure B: Install eitaas-vdi](#5-procedure-b-install-eitaas-vdi)
6. [Procedure C: First launch (import your workspace profile)](#6-procedure-c-first-launch-import-your-workspace-profile)
7. [Procedure D: Connect (every day)](#7-procedure-d-connect-every-day)
8. [Procedure E: Working inside the VDI](#8-procedure-e-working-inside-the-vdi)
9. [Procedure F: Ending a session](#9-procedure-f-ending-a-session)
10. [Troubleshooting](#10-troubleshooting)
11. [Logs and getting help](#11-logs-and-getting-help)
12. [Security and privacy](#12-security-and-privacy)
13. [Updating and uninstalling](#13-updating-and-uninstalling)
14. [Quick reference](#14-quick-reference)

---

## 1. Purpose

This SOP explains how to connect a Linux computer to your EITaaS virtual desktop **with your CAC working inside the Windows session**. Inside the session you can then use CAC-protected websites, sign documents and use encrypted email, the same as on a government Windows machine.

Microsoft's official client (the *Windows App*) doesn't run on Linux. The browser-based web client works, but it can't pass your smart card into the session. `eitaas-vdi` uses the open-source FreeRDP client, which can, and uses your browser for the CAC sign-in.

## 2. Before you start: important notices

> [!WARNING]
> **`eitaas-vdi` is unofficial.** It isn't made, endorsed or supported by the Department of the Air Force, the DoD, Microsoft, or the EITaaS program and its service center. Don't call the EITaaS Service Center for help with this tool. See [section 11](#11-logs-and-getting-help) instead.

- **Get approval first.** Ask your unit's cybersecurity office/ISSM whether you're allowed to reach the VDI from your device with a non-Microsoft client. Follow their answer.
- **Same service, same rules.** The tool connects to the same Azure Virtual Desktop and uses the same CAC certificate sign-in as the official clients. Every rule that applies to using the VDI still applies: the classification banner, acceptable use, and handling of CUI/PII.
- **Your device is your responsibility.** Keep your Linux system updated, use full-disk encryption and a screen lock, and don't share your user account.
- **Nothing secret is stored.** The tool never sees or stores your PIN. Your PIN goes only to your card, through the browser's PIN prompt. No passwords or tokens are written to disk. See [section 12](#12-security-and-privacy).

## 3. What you need

**Hardware**

- Your CAC.
- A USB smart card reader that works with the standard Linux CCID driver. Almost all common CAC readers do.

**Software** (installed in [Procedure A](#4-procedure-a-prepare-your-computer-one-time))

| Component | Why | Requirement |
|---|---|---|
| FreeRDP 3 SDL client (`sdl-freerdp3`) | Runs the remote desktop and passes your CAC through | **Version 3.16 or newer**, built with AAD and PC/SC support |
| Google Chrome or Chromium | CAC sign-in to Microsoft | **Native package**, not Flatpak or Snap |
| pcsc-lite (`pcscd`) + CCID driver | Talks to the card reader | |
| OpenSC | Lets the browser use the CAC | |
| NSS tools (`modutil`) | Registers OpenSC with the browser | |
| Python 3, zenity, libnotify (`notify-send`) | The launcher, its popups and notifications | Usually already installed |

> [!NOTE]
> Older FreeRDP versions can't do this. Ubuntu 24.04 ships FreeRDP 3.5, which is too old for the Azure Government sign-in. `eitaas-vdi doctor` shows your version.

## 4. Procedure A: Prepare your computer (one time)

### A1. Install the packages

**Arch Linux / Omarchy**

```bash
sudo pacman -S --needed freerdp pcsclite ccid opensc nss zenity libnotify python
# Browser: Chromium from the official repos, or Google Chrome from the AUR (google-chrome)
sudo pacman -S --needed chromium
```

**Fedora**

```bash
sudo dnf install freerdp pcsc-lite pcsc-lite-ccid opensc nss-tools zenity libnotify python3
```

**Debian / Ubuntu** (only releases whose FreeRDP 3 is 3.16 or newer)

```bash
sudo apt install freerdp3-sdl pcscd libccid opensc libnss3-tools zenity libnotify-bin python3
```

On Fedora and Debian/Ubuntu, install Google Chrome from google.com/chrome as a native `.rpm` or `.deb` package. Package names differ between releases. If a name doesn't exist, search your package manager for the component in the table above.

### A2. Start the smart card service

```bash
sudo systemctl enable --now pcscd.socket
```

### A3. Check that the reader sees your card

Plug in the reader, insert your CAC, and run:

```bash
opensc-tool -l
```

Expected: one line for your reader with **`Yes`** in the *Card present* column. If you get `No smart card readers found`, try another USB port and check that `pcscd` is running (step A2).

### A4. Set up your CAC in the browser

Chrome and Chromium on Linux find smart cards through a shared certificate database in `~/.pki/nssdb`. OpenSC has to be registered there **once**.

1. **Fully close Chrome/Chromium** (all windows).
2. Find the OpenSC module on your system:

   ```bash
   ls /usr/lib/opensc-pkcs11.so /usr/lib64/opensc-pkcs11.so /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so 2>/dev/null
   ```

3. Register it, using the path printed in step 2:

   ```bash
   mkdir -p ~/.pki/nssdb
   modutil -dbdir sql:$HOME/.pki/nssdb -add "OpenSC" -libfile /usr/lib/opensc-pkcs11.so
   ```

   Press **Enter** when `modutil` warns about the browser. If it says the module already exists, you're done.
4. Check it:

   ```bash
   modutil -dbdir sql:$HOME/.pki/nssdb -list | grep -i opensc
   ```

> [!TIP]
> Some distributions (often Fedora) already expose OpenSC to browsers through `p11-kit`. If CAC sign-in already works in your browser, you can skip A4.

**Optional: DoD root certificates.** `eitaas-vdi` doesn't need them, because the Microsoft sign-in and AVD gateways use public certificates. You'll still want them for other CAC-enabled DoD websites. Get the DoD PKI trust bundle from the DoD Cyber Exchange (public.cyber.mil, PKI/PKE section) and add it to your system trust store, following your distribution's instructions.

## 5. Procedure B: Install eitaas-vdi

```bash
git clone https://github.com/Athesias/eitaas-vdi-linux.git
cd eitaas-vdi-linux
./install.sh
```

The installer:

- copies the program to `~/.local/bin/eitaas-vdi` (no root needed);
- adds **EITaaS VDI** to your application launcher;
- runs a system check (`eitaas-vdi doctor`) and marks anything missing with ✗.

Fix any ✗ items before continuing. *Profile: missing* is expected at this point; Procedure C fixes it.

**Hyprland users (optional but recommended).** Add the rules from [`hyprland/eitaas-vdi.lua`](../hyprland/eitaas-vdi.lua) to your config (on Omarchy: `~/.config/hypr/windows.lua`), then run `hyprctl reload`. They make the sign-in window and the CAC PIN prompt open as small centered popups instead of tiling across the screen.

## 6. Procedure C: First launch (import your workspace profile)

The launcher needs your **workspace profile**, a small `.rdpw` file that tells it where your virtual desktop is. You download it once from the AVD web client.

1. Plug in your reader and insert your CAC.
2. Open **EITaaS VDI** from your application launcher.
3. A **Welcome to EITaaS VDI** window appears. Click **Open web client**.
4. A browser window opens the Azure Virtual Desktop web client (`https://rdweb.wvd.azure.us/arm/webclient`).
   - Enter your Air Force email address (`first.last@us.af.mil`) if asked.
   - When asked for a certificate, choose your **PIV Authentication** certificate. Don't choose the *Digital Signature* or *Encryption* ones.
   - Enter your CAC **PIN** in the *Unlock Security Device* prompt.
5. In the web client, click the **settings cog** (top right) and choose **Download the rdp file**.
6. Click your desktop (usually named **Desktop**). A file like `Desktop.rdpw` downloads.
7. The launcher detects the download, **imports it, closes the browser, and starts connecting** ([Procedure D](#7-procedure-d-connect-every-day), step 3).

The profile is moved out of your Downloads folder to `~/.config/eitaas-vdi/profile.rdpw`, readable only by you. You only need to do this once, or again if EITaaS moves your desktop or the connection starts failing with profile errors.

**Alternative: import a file you already have**

```bash
eitaas-vdi setup ~/Downloads/Desktop.rdpw
```

Only Azure US Government AVD profiles are accepted (gateway in `*.wvd.azure.us`). Anything else is refused.

## 7. Procedure D: Connect (every day)

1. Plug in your reader and insert your CAC **before** launching.
2. Open **EITaaS VDI** from your application launcher.
3. A notification says *Connecting…*. A small **Sign in to your account** window opens.
4. If prompted, pick your **PIV Authentication** certificate and enter your **PIN** in the *Unlock Security Device* prompt.
5. The window changes to **Signed in. Connecting to your desktop…**. A second sign-in step follows in the same window automatically. You enter your PIN **only once** per connection.
6. The desktop window opens and the sign-in window closes by itself. This may take 30–60 seconds, or a few minutes if your session host has to start.
7. **On Hyprland** the desktop opens **fullscreen on the monitor you launched it from**, at that monitor's resolution. **On other desktops** it opens in a window; if the desktop is a small box inside the window, resize the window once.

If something is missing (no reader, no card, no profile), a popup tells you what to do instead.

## 8. Procedure E: Working inside the VDI

### Keyboard

While the VDI window has focus, the keyboard is **grabbed**: Windows-key shortcuts (Win+E, Win+R, …) go to Windows, not to your Linux desktop. Your Linux shortcuts (for example Super+W, Super+1) don't work until you release the grab or switch focus away.

FreeRDP reserves these **Right Shift** hotkeys:

| Keys | Action |
|---|---|
| **Right Shift + D** | Disconnect and close the window |
| **Right Shift + G** | Release / re-grab the keyboard (your Linux shortcuts work while released) |
| **Right Shift + Enter** | Toggle FreeRDP fullscreen |
| **Right Shift + M** | Minimize |

### Your CAC inside Windows

Your card reader appears inside the Windows session as a smart card reader. Windows uses it for CAC-protected websites, digital signatures and encrypted email, the same as at work. Keep the card inserted for the whole session. If you pull it, Windows behaves as if you pulled it from a work computer.

### Clipboard, sound and microphone

Copy/paste of text between Linux and the VDI, sound, and microphone are on by default.

### Fullscreen, window size and monitors

- **On Hyprland the VDI starts fullscreen** on the monitor that had focus when you launched it.
- **To leave fullscreen**, first release the keyboard with **Right Shift + G**, then use your normal fullscreen key (Omarchy: **Super + F**). The window then tiles like any other, and Windows resizes to match. Press **Right Shift + G** again to give the keyboard back to Windows.
- **To always start in a window**, create `~/.config/eitaas-vdi/settings` containing:

  ```
  start = windowed
  ```

- The session uses **one monitor**. Spanning several monitors (`/multimon`) and FreeRDP's own fullscreen (`/f`) currently fail on Wayland because of a FreeRDP bug (it measures the screen as 64×64). Don't put them in `freerdp-args` on a Wayland desktop.

## 9. Procedure F: Ending a session

| Goal | How | Result |
|---|---|---|
| **Done for the day** (recommended) | Inside Windows: **Start → your profile picture → Sign out** | Windows signs you out and closes your apps; the window closes by itself |
| **Step away, keep apps open** | **Right Shift + D** | Disconnects; your Windows session keeps running on the server. Your next connection resumes where you left off. Idle disconnected sessions are usually signed out by policy after a while, so save your work. |
| **Window frozen / unresponsive** | Kill the process `sdl-freerdp3` (e.g. in `btop`/`htop`, or `pkill -x sdl-freerdp3`) | Same as a disconnect. The launcher (`python3 … eitaas-vdi connect`) then exits by itself. |

Closing with Super+W/Alt+F4 usually does nothing while the keyboard is grabbed. Use one of the options above.

## 10. Troubleshooting

**Start here:** run the system check.

```bash
eitaas-vdi doctor          # in a terminal
```

Or use **EITaaS VDI → Check CAC and setup** in the launcher's right-click/actions menu. Fix anything marked ✗.

| Symptom | Likely cause | Fix |
|---|---|---|
| Popup: *No smart card reader found* | Reader unplugged or not detected | Re-plug the reader; check `opensc-tool -l` (A3) |
| Popup: *The reader is empty* | CAC not inserted or not seated | Re-insert the CAC (chip up/in) |
| Popup: *PC/SC service is not running* | `pcscd` disabled | `sudo systemctl enable --now pcscd.socket` |
| Sign-in window never asks for a certificate/PIN, or says no certificate was found | OpenSC not registered for the browser, or the browser is a Flatpak/Snap | Do step A4 with the browser fully closed; use a native browser package |
| Wrong certificate chosen / sign-in error after PIN | Picked *Signature* or *Encryption* instead of *PIV Authentication* | Run `eitaas-vdi signout`, then connect again and pick **PIV Authentication** |
| PIN prompt or sign-in window stretched across the screen (Hyprland) | Window rules not installed | Add `hyprland/eitaas-vdi.lua` rules (Procedure B) |
| Notification: *Sign-in was cancelled or did not finish* | Sign-in window closed, timed out after 5 minutes, or Microsoft returned an error | Connect again; if it repeats, check the log for an `AADSTS…` code |
| Notification mentions `AADSTS…` | Microsoft sign-in refused the request | Note the code and report it (section 11); `AADSTS50011`/`AADSTS700016` suggest the Government endpoints changed |
| Popup: *certificate name mismatch / host key* from FreeRDP | A gateway is using a certificate the launcher didn't pre-verify | **Don't accept blindly.** Cancel and report the hostname shown (section 11). |
| Asked for your PIN twice in one connection | The sign-in window was closed between the two sign-in steps | Leave the sign-in window open until the desktop appears |
| Notification: *error retrieving ARM configuration* | Gateway timed out while starting your session host | Wait a minute and connect again |
| Desktop is a small box (≈1024×768) in a big window | Windowed mode, or a desktop other than Hyprland: the window was resized before the session was ready | Resize the window once. On Hyprland press **Super+T** twice (float/unfloat), or fullscreen it. |
| Linux shortcuts (Super+…) don't work in the VDI | Keyboard grab | **Right Shift + G** to release |
| CAC not seen inside Windows | Card pulled, or reader re-plugged mid-session | Re-insert, then disconnect (Right Shift + D) and reconnect |
| Popup: *A connection is already starting or running* | Another launcher instance is open | Use the open window, or end it (section 9) |
| Popup: *No .rdpw file was downloaded* | The browser was closed before the download | Launch again and repeat Procedure C |
| `eitaas-vdi doctor`: FreeRDP version ✗ | FreeRDP older than 3.16 | Upgrade FreeRDP (a newer distribution release or backports). Point `EITAAS_VDI_FREERDP` at a newer build if you have one. |

## 11. Logs and getting help

- Each connection writes a log to **`~/.local/state/eitaas-vdi/last.log`**, overwritten on the next connection and readable only by you.
- Authorization codes, tokens, your Windows logon (domain\user) and your 10-digit DoD ID number are **redacted automatically**.
- **Read the log before sharing it** and remove anything else you consider sensitive (for example host names).
- **Never share your `.rdpw` profile** or the `~/.local/share/eitaas-vdi/` folder.

For problems with this tool, open an issue on the GitHub repository. Include your distribution, the `eitaas-vdi doctor` output, and the relevant (reviewed) log lines.

Problems with your VDI itself (account, desktop not assigned, Windows apps) go to the EITaaS Service Center as usual. Tell them the problem also happens in the official web client if it does. Don't ask them to support this tool.

## 12. Security and privacy

| What | Where | Notes |
|---|---|---|
| Workspace profile | `~/.config/eitaas-vdi/profile.rdpw` | Mode 0600. Contains your workspace/tenant identifiers, no password. |
| Per-session profile copy | `$XDG_RUNTIME_DIR/eitaas-vdi/session.rdpw` | Mode 0600, in memory (tmpfs), deleted when the session ends |
| Sign-in browser profile | `~/.local/share/eitaas-vdi/signin-browser/` | Mode 0700. Holds Microsoft's sign-in cookies so the second sign-in step is automatic. Delete with `eitaas-vdi signout`. |
| Log | `~/.local/state/eitaas-vdi/last.log` | Mode 0600, redacted (section 11) |
| Your PIN | **Nowhere** | Typed only into the browser's PIN prompt and sent to your card |

How the connection is protected:

- Sign-in uses Microsoft's own Azure Government endpoint (`login.microsoftonline.us`) with your CAC certificate. The launcher refuses to open a sign-in page on any other host.
- FreeRDP 3.30+ wrongly flags Microsoft's wildcard gateway certificates as a name mismatch. Instead of turning certificate checks off, the launcher **verifies the gateway certificates itself** (system CA store plus proper hostname matching) and tells FreeRDP to accept only those exact certificates (SHA-256 pinning).
- The sign-in browser is controlled over a private pipe, not a network debugging port, so other programs on your computer can't drive it.

To remove all stored data: `./install.sh --purge` from the repository folder (section 13).

## 13. Updating and uninstalling

**Update**

```bash
cd eitaas-vdi-linux
git pull
./install.sh
```

Your profile and settings are kept.

**After a FreeRDP upgrade**, run `eitaas-vdi doctor` and make one test connection. FreeRDP's sign-in behavior changed in 3.32; if connecting breaks after an upgrade, report it (section 11).

**Uninstall**

```bash
./install.sh --uninstall   # remove the program and launcher entry; keep profile and logs
./install.sh --purge       # also remove profile, sign-in browser data and logs
```

## 14. Quick reference

**Commands**

| Command | What it does |
|---|---|
| `eitaas-vdi` / `eitaas-vdi connect` | Connect (what the launcher runs) |
| `eitaas-vdi setup` | Import the profile through the web client |
| `eitaas-vdi setup FILE.rdpw` | Import a profile file you already have |
| `eitaas-vdi doctor` | System check (`--dialog` for a popup) |
| `eitaas-vdi signout` | Forget the browser sign-in |

**Launcher actions** (right-click EITaaS VDI, or your launcher's actions menu): *Import profile from web client*, *Check CAC and setup*, *Forget browser sign-in*.

**In-session hotkeys:** Right Shift + D disconnect · Right Shift + G keyboard grab · Right Shift + Enter fullscreen · Right Shift + M minimize.

**Optional settings**

| Setting | Purpose |
|---|---|
| `~/.config/eitaas-vdi/settings` | `start = fullscreen` (default on Hyprland) or `start = windowed`; on Omarchy, `theme = default` stops the popups following your Omarchy theme |
| `~/.config/eitaas-vdi/freerdp-args` | Extra FreeRDP options, one per line; lines starting with `#` are ignored |
| `EITAAS_VDI_BROWSER=chromium` | Use a specific browser command for sign-in |
| `EITAAS_VDI_FREERDP=/path/to/sdl-freerdp3` | Use a specific FreeRDP build |
