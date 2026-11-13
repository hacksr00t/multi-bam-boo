# Multi-Bam-Boo: how to use it

Multi-Bam-Boo puts a 🖨 printer icon in your menu bar. It can work in two ways:

- **Switch mode:** one Bambu Studio account at a time. One click closes Bambu Studio, swaps accounts and reopens it.
- **Side-by-side mode:** several accounts open at once, each in its own Bambu Studio window, with as many windows per account as you like.

Each account stays signed in, so there's no logging out and no 2FA every time.

The examples below use two profiles called **personal** and **team**. Yours can be called anything.

---

## First-time setup

1. Open **Multi-Bam-Boo** from Applications. A 🖨 icon appears in the menu bar showing `setup`.
2. Click it → **Set Up Multi-Bam-Boo…** and name the account you're signed in to now (e.g. `personal`). Bambu Studio closes, your current login and settings become that profile, and Bambu Studio reopens.
3. Click the icon → **Add Another Account…** and name the second account (e.g. `team`). Multi-Bam-Boo copies Bambu's network plugin and stock printer presets into it, so nothing big is downloaded again.
4. Switch to the new profile (or open a window for it in side-by-side mode). Bambu Studio starts like a fresh install:
   - Go through the **Setup Wizard**.
   - Click **Login/Register** and sign in to the second account.
   - You only do this once per profile.
5. Click the icon → **Launch at Login** so the icon is always there.

> Setting up from Terminal instead? Run `multibb init personal`, then `multibb create team`.

---

## Switch mode (the default)

Click the 🖨 icon, then click a profile name. The active one has a ✓, and **⌘1** / **⌘2** pick from the open menu.

Bambu Studio closes, swaps accounts and reopens. This usually takes a few seconds. If Bambu Studio has been open a long time it can take a minute or two to close, and the icon shows `→ team…` the whole time.

If you have unsaved changes, Bambu Studio asks "Save changes?" as usual. Nothing is ever force-quit.

---

## Side-by-side mode: several accounts at once

**Turn it on:** click the icon → **Run Accounts Side by Side** → **Turn On**.

The menu then shows:

```
Open a new Bambu Studio window
  New personal window   (1 open)   ⌘1
  New team window       (2 open)   ⌘2
```

- Each click opens another Bambu Studio window signed in to that account. Nothing gets closed.
- The menu bar shows which accounts are open, e.g. `🖨 personal · team`.
- To tell windows apart, look at the account name at the top left of each window's **Home** tab.
- To close a window, press ⌘Q in it. The others keep running.
- To go back to switch mode, untick **Run Accounts Side by Side**.

**Good to know:**

- **Open windows from the 🖨 menu.** Bambu's own **File → New Window**, and the regular Bambu Studio icon, always open on the profile that switch mode last selected. Bambu doesn't pass the account along when it opens a new window itself.
- **Cloud printing works in every window.** Only the first window you open can find printers directly on your local network (LAN). The others reach your printers through Bambu's cloud.
- **Settings with two windows on one account:** settings you change in one (preferences, presets) are kept from whichever window closes last.
- **Opening .3mf files:** double-clicking one in Finder sends it to *a* running Bambu Studio, and you can't choose which. Use **File → Open Project** in the window you want instead.
- Each window is a full Bambu Studio, so several at once use noticeably more memory.

---

## Managing profiles: rename and delete

Click the icon → **Manage Profiles**, pick a profile, then:

- **Rename…** gives the profile a new name, e.g. `team` → `makerspace`. Its login and settings stay as they are, since only the label changes.
- **Delete…** moves the profile to the **Trash**: its Bambu Studio login, settings and presets on this Mac. Your Bambu account, cloud presets and printers aren't affected. If you change your mind, put the `BambuStudio-<name>` folder back from the Trash before emptying it.

Some things are blocked to keep your data safe:

- You can't rename or delete a profile while a Bambu Studio window is using it. Close those windows first.
- You can't delete the **active** profile (the one with the ✓ in switch mode). Switch to another profile first. Renaming the active profile is fine once Bambu Studio is closed.

---

## The rest of the menu

| Item | What it does |
|---|---|
| **Add Another Account…** | Only shown while you have a single profile. Adds the second one. After that, use **Manage Profiles → New Profile…** |
| **Run Accounts Side by Side** | Switches between switch mode and side-by-side mode. |
| **Open Bambu Studio** | Switch mode only. Opens Bambu Studio on the current profile, or brings it to the front. |
| **Manage Profiles** | Rename or delete profiles, add a new one, or show the profile folders in Finder. |
| **Launch at Login** | Starts Multi-Bam-Boo automatically when you log in. |
| **How to Use…** | Opens this page. |
| **About Multi-Bam-Boo** | Version and credits. |
| **Quit Multi-Bam-Boo** | Hides the icon. It does not close Bambu Studio. |

---

## Terminal: the `multibb` command

```bash
multibb list           # show profiles, * = active
multibb team           # switch to "team" (closes + reopens Bambu Studio)
multibb open team      # open an EXTRA window on "team" (side by side, closes nothing)
multibb status         # which profile is active
multibb create work    # add a profile
multibb rename work makerspace   # rename a profile
multibb delete work    # delete a profile permanently (asks first; the menu's Delete… uses the Trash instead)
multibb init [name]    # first-time setup
```

## Shortcuts, Raycast, Alfred, Stream Deck

Open these links, e.g. with a Shortcut's *Open URL* action or a Raycast quicklink:

- `multibb://switch/team` switches to that profile.
- `multibb://open/team` opens an extra window on that profile.

---

## How it works

Bambu Studio keeps everything, including your login, in `~/Library/Application Support/BambuStudio`. Multi-Bam-Boo turns that folder into a **symlink** pointing at one of several profile folders:

```
~/Library/Application Support/BambuStudio  ->  BambuStudio-personal
~/Library/Application Support/BambuStudio-personal/
~/Library/Application Support/BambuStudio-team/
```

- **Switch mode** repoints the symlink while Bambu Studio is closed.
- **Side-by-side mode** starts extra copies of Bambu Studio with its built-in `--datadir` option, aimed straight at a profile folder. The symlink is left alone.

The profile layout is the same as [bamboo-switch](https://github.com/c0ryd/bamboo-switch)'s, so existing bamboo-switch profiles work as they are.

**Recent files** are copied across when you switch, so "Recently Opened" looks the same on every profile. To turn that off, set `SYNC_RECENTS=false` near the top of `multibb`.

## Troubleshooting

| Problem | Fix |
|---|---|
| "Bambu Studio is still open" message | It didn't finish closing within 3 minutes. Close it yourself (⌘Q) and try again. |
| The 🖨 icon is gone | Open **Applications → Multi-Bam-Boo** and turn on **Launch at Login**. |
| A profile shows as logged out | Bambu's login token expired. Sign in once more in that profile. |
| Bambu Studio updates | These are safe. Updates don't touch the profile folders. |

## Uninstall / undo everything

1. Quit Bambu Studio and Multi-Bam-Boo.
2. In Terminal, replacing `personal` with the profile you want to keep as your normal Bambu Studio setup:
   ```bash
   cd ~/Library/Application\ Support
   rm BambuStudio
   mv BambuStudio-personal BambuStudio
   ```
   The `rm` removes only the symlink, not your data.
3. Delete `/Applications/Multi-Bam-Boo.app` and the `multibb` command (`which multibb` shows where it is).
4. Optionally delete any other `BambuStudio-<name>` folders.
