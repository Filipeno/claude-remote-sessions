# Claude Remote Sessions

Keeps [Claude Code Remote Control](https://claude.com/claude-code) sessions running on your Windows PC,
so you can code from your phone or from claude.ai/code any time.

- Starts a hidden session (no terminal window) for each of your project folders when you log in
- A watchdog checks every 15 minutes: restarts sessions that crashed and picks up new folders
- Folders you trust in Claude Code are added automatically
- A simple menu to start, stop, add folders and turn it all off

## Install

**You need:** Windows 10 or 11, and [Claude Code](https://claude.com/claude-code) installed and logged in
(run `claude` once in a terminal and log in with your claude.ai account).

Open **PowerShell** (press Start, type `powershell`, press Enter), paste this line and press Enter:

```powershell
irm https://raw.githubusercontent.com/Filipeno/claude-remote-sessions/main/install-online.ps1 | iex
```

That's it. The installer:

1. sets up autostart (no admin rights needed),
2. adds a **Claude Remote Sessions** entry to your Start Menu,
3. starts a session for every folder you already trust in Claude Code,
4. and if there are none, opens a folder picker so you can choose one.

Your sessions then show up at [claude.ai/code](https://claude.ai/code) and in the Claude mobile app.

<details>
<summary>Prefer not to paste a command?</summary>

Click the green **Code** button on this page, choose **Download ZIP**, unzip it somewhere you'll keep it
(for example `Documents\claude-remote-sessions`), and double-click **Install.cmd**.
</details>

## Using it

Open **Claude Remote Sessions** from the Start Menu:

```
  CLAUDE REMOTE SESSIONS
  Autostart: ON    Chrome: auto

  [running] D:\projects\my-app
  [stopped] D:\school

  1  Start sessions now
  2  Stop all sessions
  3  Add a folder
  4  Edit the folder list
  5  Turn autostart on/off
  6  Show the log
  7  Update
  8  Uninstall
```

- **Add a folder**: pick it in a folder window. If Claude hasn't trusted that folder yet, a Claude window opens.
  Answer **yes** to "Do you trust the files in this folder?", then type `/exit`.
- **Switch a folder off**: choose *Edit the folder list* and put `#` in front of its line.
  Switched-off folders are never added back automatically.
- **Stop all sessions**: stops everything and pauses the watchdog until your next reboot or *Start sessions now*.
- **Turn autostart off**: nothing starts at login any more. Turn it back on the same way.

## Settings

`settings.psd1` in the install folder (`%LOCALAPPDATA%\ClaudeRemoteSessions`):

| Setting | Values |
|---|---|
| `Chrome` | `'auto'` (default, uses your `/chrome` setting in Claude), `'on'` (sessions always get Claude in Chrome), `'off'` |

## Good to know

- **Something didn't start?** Choose *Show the log*. `FAILED` usually means the folder isn't trusted yet
  (use *Add a folder* on it) or Claude Code isn't logged in.
- **Trusted = added.** Any folder where you answered yes to Claude's trust question gets a session.
  Your home folder, temp folders and worktrees are skipped. Switch off the ones you don't want with `#`.
- **Sessions start after you log in**, not at the Windows login screen.
- **Updating** keeps your folder list and settings.

## Uninstall

Menu → **8 Uninstall**. It removes the autostart task and the Start Menu entry, and asks whether to stop the
running sessions.

## License

MIT
