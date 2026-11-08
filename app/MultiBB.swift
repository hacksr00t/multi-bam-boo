// Multi-Bam-Boo — a tiny menu bar front end for the `multibb` CLI.
// Switch Bambu Studio accounts with one click, or run several accounts side by side.
// Based on bamboo-switch by c0ryd (MIT). Not affiliated with Bambu Lab.

import AppKit
import ServiceManagement

let bambuBundleID = "com.bambulab.bambu-studio"
let supportDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support")
let bambuLink = supportDir.appendingPathComponent("BambuStudio")
let profilePrefix = "BambuStudio-"

enum ConfigState {
    case managed(String)      // symlink -> BambuStudio-<name>
    case unmanaged            // plain folder, setup not done yet
    case missing
}

func currentState() -> ConfigState {
    let fm = FileManager.default
    if let dest = try? fm.destinationOfSymbolicLink(atPath: bambuLink.path) {
        let base = (dest as NSString).lastPathComponent
        return .managed(base.hasPrefix(profilePrefix) ? String(base.dropFirst(profilePrefix.count)) : base)
    }
    var isDir: ObjCBool = false
    if fm.fileExists(atPath: bambuLink.path, isDirectory: &isDir), isDir.boolValue { return .unmanaged }
    return .missing
}

func listProfiles() -> [String] {
    let fm = FileManager.default
    guard let items = try? fm.contentsOfDirectory(atPath: supportDir.path) else { return [] }
    return items.filter { name in
        guard name.hasPrefix(profilePrefix) else { return false }
        var isDir: ObjCBool = false
        let p = supportDir.appendingPathComponent(name).path
        let isLink = (try? fm.destinationOfSymbolicLink(atPath: p)) != nil
        return !isLink && fm.fileExists(atPath: p, isDirectory: &isDir) && isDir.boolValue
    }
    .map { String($0.dropFirst(profilePrefix.count)) }
    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
}

/// Wherever Bambu Studio is installed (normally /Applications/BambuStudio.app).
func bambuAppURL() -> URL {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: bambuBundleID)
        ?? URL(fileURLWithPath: "/Applications/BambuStudio.app")
}

func launchBambu() {
    NSWorkspace.shared.openApplication(at: bambuAppURL(), configuration: NSWorkspace.OpenConfiguration())
}

func bambuApps() -> [NSRunningApplication] {
    NSRunningApplication.runningApplications(withBundleIdentifier: bambuBundleID)
}

/// How many Bambu Studio processes are open per profile. Processes started with
/// `--datadir` belong to that folder; plain ones use whatever the symlink points at.
func runningCounts() -> [String: Int] {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/ps")
    p.arguments = ["-axo", "args="]
    let pipe = Pipe()
    p.standardOutput = pipe
    guard (try? p.run()) != nil else { return [:] }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    var counts: [String: Int] = [:]
    var symlinkProfile: String? = nil
    if case .managed(let n) = currentState() { symlinkProfile = n }
    for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
        guard line.contains("BambuStudio.app/Contents/MacOS/BambuStudio") else { continue }
        var name: String? = symlinkProfile
        if let r = line.range(of: "--datadir ") {
            let dir = String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            let base = (dir as NSString).lastPathComponent
            name = base.hasPrefix(profilePrefix) ? String(base.dropFirst(profilePrefix.count)) : base
        }
        if let name { counts[name, default: 0] += 1 }
    }
    return counts
}

var sideBySide: Bool {
    get { UserDefaults.standard.bool(forKey: "sideBySide") }
    set { UserDefaults.standard.set(newValue, forKey: "sideBySide") }
}

func stripANSI(_ s: String) -> String {
    s.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression)
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var busy = false

    var cliPath: String {
        if let bundled = Bundle.main.path(forResource: "multibb", ofType: nil) { return bundled }
        for p in ["/opt/homebrew/bin/multibb", "/usr/local/bin/multibb"]
            where FileManager.default.isExecutableFile(atPath: p) { return p }
        return "multibb"
    }

    // multibb://switch/<profile> and multibb://open/<profile> — let Shortcuts, Raycast, Alfred, Stream Deck etc. switch.
    func applicationWillFinishLaunching(_ note: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURL(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    @objc func handleURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let s = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: s), url.host == "switch" || url.host == "open" else { return }
        let name = url.lastPathComponent
        guard listProfiles().contains(name) else {
            alert("No profile named “\(name)”", "Profiles: " + listProfiles().joined(separator: ", "))
            return
        }
        let item = NSMenuItem(); item.representedObject = name
        if url.host == "open" { newWindow(item) } else { switchTo(item) }
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refreshTitle()
        // Keep the title honest if someone switches from the terminal.
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            if self?.busy == false { self?.refreshTitle() }
        }
    }

    // MARK: Title

    func refreshTitle(_ override: String? = nil) {
        guard let button = statusItem.button else { return }
        let img = NSImage(systemSymbolName: "printer.fill", accessibilityDescription: "Multi-Bam-Boo")
        img?.isTemplate = true
        button.image = img
        button.imagePosition = .imageLeading
        button.title = " " + (override ?? titleText())
    }

    func titleText() -> String {
        if sideBySide, case .managed = currentState() {
            let open = runningCounts().filter { $0.value > 0 }.keys.sorted()
            return open.isEmpty ? "Bambu" : open.joined(separator: " · ")
        }
        switch currentState() {
        case .managed(let name): return name
        case .unmanaged, .missing: return "setup"
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if busy {
            menu.addItem(disabled("Switching… please wait"))
            return
        }
        let state = currentState()
        switch state {
        case .managed where sideBySide:
            let counts = runningCounts()
            menu.addItem(disabled("Open a new Bambu Studio window"))
            for (i, name) in listProfiles().enumerated() {
                let n = counts[name] ?? 0
                let item = NSMenuItem(title: "New \(name) window" + (n > 0 ? "   (\(n) open)" : ""),
                                      action: #selector(newWindow(_:)),
                                      keyEquivalent: i < 9 ? "\(i + 1)" : "")
                item.target = self
                item.representedObject = name
                item.image = NSImage(systemSymbolName: n > 0 ? "macwindow.badge.plus" : "plus.rectangle.on.rectangle",
                                     accessibilityDescription: nil)
                menu.addItem(item)
            }
            menu.addItem(.separator())
            menu.addItem(action("New Profile…", #selector(newProfile), "n"))
        case .managed(let active):
            menu.addItem(disabled("Bambu account profiles"))
            for (i, name) in listProfiles().enumerated() {
                let item = NSMenuItem(title: name, action: #selector(switchTo(_:)),
                                      keyEquivalent: i < 9 ? "\(i + 1)" : "")
                item.target = self
                item.representedObject = name
                item.state = (name == active) ? .on : .off
                item.image = NSImage(systemSymbolName: name == active ? "person.crop.circle.fill" : "person.crop.circle",
                                     accessibilityDescription: nil)
                menu.addItem(item)
            }
            menu.addItem(.separator())
            menu.addItem(action("New Profile…", #selector(newProfile), "n"))
        case .unmanaged:
            menu.addItem(disabled("Not set up yet"))
            menu.addItem(action("Set Up Multi-Bam-Boo…", #selector(setUp), ""))
        case .missing:
            menu.addItem(disabled("No Bambu Studio config found"))
            menu.addItem(action("Set Up Multi-Bam-Boo…", #selector(setUp), ""))
        }
        menu.addItem(.separator())
        if case .managed = state {
            let sbs = action("Run Accounts Side by Side", #selector(toggleSideBySide), "")
            sbs.state = sideBySide ? .on : .off
            menu.addItem(sbs)
        }
        if !sideBySide {
            menu.addItem(action(bambuApps().isEmpty ? "Open Bambu Studio" : "Bring Bambu Studio to Front",
                                #selector(openBambu), "o"))
        }
        menu.addItem(action("Show Profiles in Finder", #selector(showInFinder), ""))
        menu.addItem(.separator())
        let login = action("Launch at Login", #selector(toggleLogin), "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(action("How to Use…", #selector(openHelp), ""))
        menu.addItem(action("About Multi-Bam-Boo", #selector(showAbout), ""))
        menu.addItem(action("Quit Multi-Bam-Boo", #selector(quitApp), "q"))
    }

    func disabled(_ title: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.isEnabled = false
        return i
    }

    func action(_ title: String, _ sel: Selector, _ key: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        i.target = self
        return i
    }

    // MARK: Actions

    @objc func switchTo(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        if case .managed(let active) = currentState(), active == name {
            openBambu()   // already on it; just make sure Bambu is up
            return
        }
        busy = true
        refreshTitle("→ \(name)…")
        quitBambuThen { [weak self] ok in
            guard let self else { return }
            guard ok else {
                self.busy = false
                self.refreshTitle()
                self.alert("Bambu Studio is still open",
                           "It didn't quit (maybe a “Save changes?” dialog is waiting). Close it, then pick the profile again.")
                return
            }
            self.runCLI([name]) { status, out in
                self.busy = false
                self.refreshTitle()
                if status != 0 { self.alert("Couldn't switch to “\(name)”", out) }
            }
        }
    }

    /// Side-by-side mode: start another Bambu Studio process on this profile's folder.
    @objc func newWindow(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        refreshTitle("opening \(name)…")
        runCLI(["open", name]) { status, out in
            if status != 0 { self.alert("Couldn't open a \(name) window", out) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.refreshTitle() }
        }
    }

    @objc func toggleSideBySide() {
        if sideBySide {
            sideBySide = false
            refreshTitle()
            return
        }
        var plain = "your default account"
        if case .managed(let n) = currentState() { plain = "“\(n)”" }
        let a = NSAlert()
        a.messageText = "Run accounts side by side?"
        a.informativeText = """
        This menu will open Bambu Studio windows for each account, so you can have several accounts open at the same time (and more than one window per account).

        Good to know:
        • Open new windows from this menu. Bambu's own File → New Window, and the regular Bambu Studio icon, always open on \(plain).
        • Only the first window you open finds printers on your home network directly. The others connect through Bambu's cloud, which is fine for cloud printing.
        • Each window says which account it's on (top left of the Home tab).
        """
        a.addButton(withTitle: "Turn On")
        a.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard a.runModal() == .alertFirstButtonReturn else { return }
        sideBySide = true
        refreshTitle()
    }

    @objc func newProfile() {
        guard let name = askForName(title: "New Bambu profile",
                                    info: "Give it a short name like “work” or “home”. Letters, numbers, - and _ only.",
                                    button: "Create") else { return }
        runCLI(["create", name]) { status, out in
            if status != 0 { self.alert("Couldn't create “\(name)”", out); return }
            if sideBySide {
                let a = NSAlert()
                a.messageText = "Profile “\(name)” created"
                a.informativeText = "Open a window for it now? Sign in to the other Bambu account once in that window. After that it stays signed in."
                a.addButton(withTitle: "Open Window")
                a.addButton(withTitle: "Later")
                NSApp.activate(ignoringOtherApps: true)
                if a.runModal() == .alertFirstButtonReturn {
                    let item = NSMenuItem(); item.representedObject = name
                    self.newWindow(item)
                }
                return
            }
            let a = NSAlert()
            a.messageText = "Profile “\(name)” created"
            a.informativeText = "Switch to it now? Bambu Studio will restart and you'll sign in to the other Bambu account once. After that it stays signed in."
            a.addButton(withTitle: "Switch Now")
            a.addButton(withTitle: "Later")
            NSApp.activate(ignoringOtherApps: true)
            if a.runModal() == .alertFirstButtonReturn {
                let item = NSMenuItem(); item.representedObject = name
                self.switchTo(item)
            }
        }
    }

    @objc func setUp() {
        guard let name = askForName(title: "Set up Multi-Bam-Boo",
                                    info: "Your current Bambu Studio login and settings will become the first profile. What should it be called? (e.g. “home”)",
                                    button: "Set Up") else { return }
        busy = true
        refreshTitle("setting up…")
        quitBambuThen { [weak self] ok in
            guard let self else { return }
            guard ok else {
                self.busy = false; self.refreshTitle()
                self.alert("Bambu Studio is still open", "Close it, then run Set Up again.")
                return
            }
            self.runCLI(["init", name], stdin: "y\n") { status, out in
                self.busy = false
                self.refreshTitle()
                if status != 0 { self.alert("Setup failed", out); return }
                launchBambu()
            }
        }
    }

    @objc func openBambu() {
        if let app = bambuApps().first {
            app.activate()
        } else {
            launchBambu()
        }
    }

    @objc func showInFinder() {
        let profiles = listProfiles().map { supportDir.appendingPathComponent(profilePrefix + $0) }
        if profiles.isEmpty { NSWorkspace.shared.open(supportDir) }
        else { NSWorkspace.shared.activateFileViewerSelecting(profiles) }
    }

    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            alert("Couldn't change Launch at Login", error.localizedDescription +
                  "\n\nYou can add it by hand: System Settings → General → Login Items → +, then pick Multi-Bam-Boo.")
        }
    }

    @objc func openHelp() {
        if let help = Bundle.main.url(forResource: "HOW-TO-USE", withExtension: "md") {
            NSWorkspace.shared.open(help)
        }
    }

    @objc func showAbout() {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        alert("Multi-Bam-Boo \(v)", """
        Switch Bambu Studio between accounts in one click, or run several accounts side by side.

        Based on bamboo-switch by c0ryd (github.com/c0ryd/bamboo-switch), MIT License.

        Not affiliated with or endorsed by Bambu Lab. Bambu Studio is a trademark of Bambu Lab.
        """)
    }

    @objc func quitApp() { NSApp.terminate(nil) }

    // MARK: Helpers

    /// Politely ask Bambu Studio to quit (lets it show its own "Save changes?" dialog),
    /// then wait up to 3 min (Bambu can take ~2 min to shut down). Never force-kills.
    func quitBambuThen(_ done: @escaping (Bool) -> Void) {
        let apps = bambuApps()
        if apps.isEmpty && !pgrepBambu() { done(true); return }
        apps.forEach { $0.terminate() }
        var waited = 0.0
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { t in
            waited += 0.5
            if bambuApps().isEmpty && !self.pgrepBambu() { t.invalidate(); done(true) }
            else if waited >= 180 { t.invalidate(); done(false) }
        }
    }

    func pgrepBambu() -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        p.arguments = ["-x", "BambuStudio"]
        p.standardOutput = FileHandle.nullDevice
        try? p.run(); p.waitUntilExit()
        return p.terminationStatus == 0
    }

    func runCLI(_ args: [String], stdin: String? = nil, done: @escaping (Int32, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = [self.cliPath] + args
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            p.environment = env
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            let inPipe = Pipe()
            p.standardInput = inPipe
            var status: Int32 = -1
            do {
                try p.run()
                if let stdin { inPipe.fileHandleForWriting.write(stdin.data(using: .utf8)!) }
                try? inPipe.fileHandleForWriting.close()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                status = p.terminationStatus
                let out = stripANSI(String(data: data, encoding: .utf8) ?? "")
                DispatchQueue.main.async { done(status, out) }
            } catch {
                DispatchQueue.main.async { done(status, error.localizedDescription) }
            }
        }
    }

    func askForName(title: String, info: String, button: String) -> String? {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = info
        a.addButton(withTitle: button)
        a.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "work"
        a.accessoryView = field
        a.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard a.runModal() == .alertFirstButtonReturn else { return nil }
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard name.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else {
            alert("That name won't work", "Use only letters, numbers, dashes and underscores (no spaces).")
            return nil
        }
        return name
    }

    func alert(_ title: String, _ text: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }
}

let delegate = AppDelegate()

// Debug: `MultiBB --dump` prints the menu bar title and menu items, then exits.
if CommandLine.arguments.contains("--dump") {
    print("title: \(delegate.titleText())")
    let m = NSMenu()
    delegate.menuNeedsUpdate(m)
    for i in m.items {
        print(i.isSeparatorItem ? "  ----" : "  [\(i.state == .on ? "x" : " ")] \(i.title)" + (i.keyEquivalent.isEmpty ? "" : "  ⌘\(i.keyEquivalent)"))
    }
    exit(0)
}

let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
