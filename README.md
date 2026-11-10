# Multi-Bam-Boo (MultiBB)

**Use several Bambu Studio accounts on one Mac, one at a time or all at once, from a free menu bar app.**

> Not affiliated with or endorsed by Bambu Lab. "Bambu Studio" and "Bambu Lab" are trademarks of their owner.

Bambu Studio only lets you sign in to one Bambu account, and switching means logging out, logging back in and doing 2FA every time. If your printers are split across accounts (home and work, personal and a team or club), that gets old fast.

Multi-Bam-Boo gives each account its own Bambu Studio profile that **stays signed in**, and puts a 🖨 icon in your menu bar to use them:

- **Switch mode:** click an account and Bambu Studio closes, swaps and reopens on it, usually within a few seconds.
- **Side-by-side mode:** open Bambu Studio windows for different accounts *at the same time*, as many per account as you like. You can watch every printer at once, and nothing needs saving and reloading.

```
🖨 personal · team
 ├ Open a new Bambu Studio window
 │   New personal window   (1 open)   ⌘1
 │   New team window       (2 open)   ⌘2
 ├ New Profile…
 ├ ✓ Run Accounts Side by Side
 ├ Show Profiles in Finder
 ├ ✓ Launch at Login
 └ How to Use… / About / Quit
```

It also includes a `multibb` command-line tool and `multibb://` links for Shortcuts, Raycast, Alfred or a Stream Deck.

## Install

### Download

Signed, notarized downloads will appear under [Releases](../../releases). Until the first one is out, build from source (below). It takes about a minute.

### Build from source

You need Xcode or its Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/hacksr00t/multi-bam-boo.git
cd multi-bam-boo
./build.sh
```

This builds a universal (Apple Silicon + Intel) app, installs it to `/Applications/Multi-Bam-Boo.app`, and puts `multibb` in your Homebrew bin folder (or `~/.local/bin`).

### Command-line tool only

```bash
make install            # → /usr/local/bin/multibb  (PREFIX=... to change)
```

## Getting started

1. Open **Multi-Bam-Boo** and click the 🖨 icon → **Set Up Multi-Bam-Boo…**. Your current Bambu Studio login becomes the first profile.
2. Click **New Profile…** to add the second account, then switch to it and sign in once.
3. Optional: turn on **Run Accounts Side by Side** to keep both open at once.

Full instructions, caveats and troubleshooting: **[HOW-TO-USE.md](HOW-TO-USE.md)** (also under **How to Use…** in the menu).

## Command line

```bash
multibb init personal   # first-time setup: current config → profile "personal"
multibb create team     # add a profile
multibb team            # switch (closes + reopens Bambu Studio)
multibb open team       # open an extra window on "team", side by side
multibb list | status | delete <name> | help
```

## How it works

Bambu Studio keeps its settings and login in `~/Library/Application Support/BambuStudio`. Multi-Bam-Boo makes that a symlink to `BambuStudio-<profile>` folders and repoints it to switch accounts. For side-by-side mode it starts extra Bambu Studio copies with Bambu Studio's built-in `--datadir` option, aimed straight at a profile folder.

Your data stays in normal folders. Nothing in Bambu Studio is modified, and Bambu Studio updates keep working.

**Limitations**

- macOS 13+ only.
- In side-by-side mode, only the first window finds printers on your local network directly. The others connect through Bambu's cloud, which works for cloud printing and monitoring.
- Bambu's own **File → New Window** doesn't know about profiles, so open windows from the 🖨 menu.

## Credits

Multi-Bam-Boo started as a fork of **[bamboo-switch](https://github.com/c0ryd/bamboo-switch)** by [c0ryd](https://github.com/c0ryd) (MIT). The symlink profile approach and the original CLI are his. Profiles are compatible both ways.

Changes in Multi-Bam-Boo:

- A free native menu bar app (Swift/AppKit).
- Side-by-side mode (`multibb open`, using `--datadir`).
- `init` no longer crashes on an existing config.
- Switching never force-quits Bambu Studio, so unsaved projects aren't lost.
- New profiles reuse the ~300 MB network plugin instead of downloading it again.
- `multibb://` links.
- Bambu Studio is found by bundle ID, so it doesn't have to be in `/Applications`.

c0ryd also sells a polished menu bar app for bamboo-switch. If you prefer that one, [go support him](https://corydawson8.gumroad.com/l/qmriaz).

## Building a release (maintainers)

`./release.sh` signs with your Developer ID, notarizes with Apple and produces `dist/Multi-Bam-Boo-<version>.zip`. One-time setup steps are at the top of the script.

## License

[MIT](LICENSE)
