#Requires AutoHotkey v2.0
#SingleInstance Force

; ══════════════════════════════════════════════════════════════════════════════
; GLOBAL STATE
; ══════════════════════════════════════════════════════════════════════════════
global bossImages              := []
global isScanning              := false
global stopPlayback            := false
global isPlayingRec            := false
global lowPlayerStreak         := 0
global bossFoundDuringPlayback := false
global bossSpawnCount          := 0   ; session counter

; ESC menu player list
global escCalibrated     := false
global isCheckingPlayers := false
global escIndicatorImg   := ""
global addFriendImg      := ""   ; crop of "Add friend" button
global friendLabelImg    := ""   ; crop of "Friend" label
global escImgTolerance   := 30   ; ImageSearch shade tolerance

; Recording cache — parsed once on load
global recCache     := []
global recCachePath := ""

; Paths
global dataDir      := A_ScriptDir "\data"
global imagesDir    := A_ScriptDir "\data\images"
global ssDir        := A_ScriptDir "\data\screenshots"
global configFile   := A_ScriptDir "\data\config.ini"
global logsDir      := A_ScriptDir "\data\logs"

; GDI+ — initialized once at startup, kept alive for all screenshots
global gdipToken := 0
global consoleGui  := 0    ; live log window — opens on Start, closes on Stop
global consoleEdit := 0    ; edit control inside console showing log text
global lbBoss, picPreview, edKeys, edDelay, edScan
global btnStart, btnStop, lblStatus
global lblEscIndicator, edPlayerCheckInterval, edEscScrollSteps, lblEscTestResult
global lblAddFriendImg, lblFriendLabelImg
global edRecPath, edPlayerThreshold, cbEnablePlayerCheck, cbActionAfterTT
global lblRecInfo, edPlayerScanDelay
global edWebhookUrl, cbEnableWebhook, cbDetectItem, lblWebhookStatus, lblSpawnCount, edUserId
global edAfkRecPath, edAfkInterval, cbEnableAfk, lblAfkRecInfo, lblAfkStatus
global afkRecCache := []
global afkRecCachePath := ""

; ══════════════════════════════════════════════════════════════════════════════
; GUI
; ══════════════════════════════════════════════════════════════════════════════
g := Gui("+Resize -MaximizeBox", "Z-Macro v1")
g.SetFont("s9 q5", "Segoe UI")
g.BackColor := "1E1E2E"
g.SetFont("s9 cWhite", "Segoe UI")

tabs := g.AddTab3("xm y5 w450 h430 Background1E1E2E", ["  Boss Detect  ", "  Player Count  ", "  Recording  ", "  Notify  ", "  Anti-AFK  "])

; ─────────────────────────────────────────────────────────────────────────────
; TAB 1 — BOSS DETECT
; ─────────────────────────────────────────────────────────────────────────────
tabs.UseTab(1)

g.AddText("xm+10 y35 w270 cWhite Background1E1E2E", "Boss screenshots (PNG or BMP recommended):")
lbBoss := g.AddListBox("xm+10 y53 w265 h130 Background2A2A3E cWhite", [])
lbBoss.OnEvent("Change", ShowPreview)
g.AddButton("x285 y53 w155 h28", "Add Image(s)").OnEvent("Click", AddImage)
g.AddButton("x285 y85 w155 h28", "Remove Selected").OnEvent("Click", RemoveImage)

g.AddGroupBox("xm+10 y190 w185 h130 cWhite", "Preview")
picPreview := g.AddPicture("xm+20 y207 w165 h105 Border Background2A2A3E", "")

g.AddGroupBox("x205 y190 w235 h130 cWhite", "Macro Settings")
g.AddText("x215 y210 w215 cWhite Background1E1E2E", "Keys (comma-separated):")
edKeys  := g.AddEdit("x215 y227 w215 h22 Background2A2A3E cWhite", "e,q,r")
g.AddText("x215 y257 w105 cWhite Background1E1E2E", "Key delay (ms):")
edDelay := g.AddEdit("x215 y273 w80 h22 Background2A2A3E cWhite", "150")
g.AddText("x305 y257 w105 cWhite Background1E1E2E", "Scan interval (ms):")
edScan  := g.AddEdit("x305 y273 w80 h22 Background2A2A3E cWhite", "500")
g.AddText("x215 y303 w215 cGray Background1E1E2E", "Special keys: {Space} {Enter} {F1} etc.")

; ─────────────────────────────────────────────────────────────────────────────
; TAB 2 — PLAYER COUNT
; ─────────────────────────────────────────────────────────────────────────────
tabs.UseTab(2)

g.AddGroupBox("xm+10 y35 w430 h130 cWhite", "Step 1 — Player Button Images")
g.AddText("xm+20 y55 w400 cWhite Background1E1E2E",
    "Crop a tight screenshot of each button from the ESC People list:`n" .
    "'Add friend' button (for non-friends) and 'Friend' label (for friends).`n" .
    "The script finds all occurrences of each image, adds +1 for yourself.")
g.AddButton("xm+20 y100 w175 h26", "Browse 'Add friend' image").OnEvent("Click", BrowseAddFriendImg)
lblAddFriendImg := g.AddText("x203 y104 w225 cGray Background1E1E2E", "Not set.")
g.AddButton("xm+20 y130 w175 h26", "Browse 'Friend' label image").OnEvent("Click", BrowseFriendLabelImg)
lblFriendLabelImg := g.AddText("x203 y134 w225 cGray Background1E1E2E", "Not set.")

g.AddGroupBox("xm+10 y173 w430 h65 cWhite", "Step 2 — ESC Menu Indicator Image")
g.AddText("xm+20 y193 w400 cWhite Background1E1E2E", "Crop any element ONLY visible when ESC menu is open (e.g. Leave button):")
g.AddButton("xm+20 y210 w145 h24", "Browse Indicator").OnEvent("Click", BrowseEscIndicator)
lblEscIndicator := g.AddText("x173 y214 w255 cGray Background1E1E2E", "Not set — ESC guard disabled.")

g.AddGroupBox("xm+10 y246 w430 h75 cWhite", "Step 3 — Settings")
g.AddText("xm+20 y266 w150 cWhite Background1E1E2E", "Check interval (min):")
edPlayerCheckInterval := g.AddEdit("x175 y263 w45 h22 Background2A2A3E cWhite", "5")
g.AddText("x228 y266 w95 cGray Background1E1E2E", "mins between checks")
g.AddText("x330 y266 w55 cWhite Background1E1E2E", "Max scrolls:")
edEscScrollSteps := g.AddEdit("x390 y263 w35 h22 Background2A2A3E cWhite", "5")
g.AddText("xm+20 y291 w400 cGray Background1E1E2E", "Image match tolerance: lower = stricter. Default 30 works for most cases.")

g.AddButton("xm+20 y330 w185 h28", "Test Count Now").OnEvent("Click", TestPlayerCount)
lblEscTestResult := g.AddText("x215 y336 w215 cLime Background1E1E2E", "")

g.AddGroupBox("xm+10 y367 w430 h60 cWhite", "How it works")
g.AddText("xm+20 y383 w410 cGray Background1E1E2E",
    "Opens ESC → scrolls down → finds all 'Add friend' + 'Friend' images → never`n" .
    "scans the same area twice. Total = found occurrences + 1 (yourself).")

; ─────────────────────────────────────────────────────────────────────────────
; TAB 3 — RECORDING
; ─────────────────────────────────────────────────────────────────────────────
tabs.UseTab(3)

g.AddGroupBox("xm+10 y35 w430 h75 cWhite", "Recording File (.rec)")
g.AddText("xm+20 y55 w85 cWhite Background1E1E2E", "Recording:")
edRecPath := g.AddEdit("x105 y52 w240 h22 Background2A2A3E cWhite", "C:\path\to\recording.rec")
g.AddButton("x353 y52 w80 h22", "Browse").OnEvent("Click", BrowseRec)
lblRecInfo := g.AddText("xm+20 y82 w400 cGray Background1E1E2E", "No file loaded.")

g.AddGroupBox("xm+10 y118 w430 h100 cWhite", "Trigger Condition")
cbEnablePlayerCheck := g.AddCheckbox("xm+20 y138 w380 cWhite Background1E1E2E Checked", "Enable player count check")
g.AddText("xm+20 y162 w235 cWhite Background1E1E2E", "Play recording when players fewer than:")
edPlayerThreshold := g.AddEdit("x262 y159 w45 h22 Background2A2A3E cWhite", "6")
g.AddText("x315 y162 w60 cWhite Background1E1E2E", "players")
g.AddText("xm+20 y189 w235 cWhite Background1E1E2E", "Delay before player scanning starts (s):")
edPlayerScanDelay := g.AddEdit("x262 y186 w45 h22 Background2A2A3E cWhite", "30")
g.AddText("x315 y189 w120 cGray Background1E1E2E", "(boss scans first)")

g.AddGroupBox("xm+10 y225 w430 h75 cWhite", "After Recording Finishes")
cbActionAfterTT := g.AddDropDownList("xm+20 y245 w400 Background2A2A3E cWhite Choose1", [
    "Resume scanning for boss normally",
    "Wait for player count to recover first, then resume",
    "Stop everything"
])

g.AddGroupBox("xm+10 y307 w430 h110 cWhite", "Manual Test")
g.AddButton("xm+20 y327 w195 h28", "Play Recording Once").OnEvent("Click", TestRunRecording)
g.AddButton("x225 y327 w205 h28", "Stop Playback (or F9)").OnEvent("Click", StopPlaybackNow)
g.AddText("xm+20 y365 w400 cGray Background1E1E2E",
    "Plays back your .rec file natively — no external program needed.`n" .
    "Press F9 at any time to abort playback mid-recording.")

; ─────────────────────────────────────────────────────────────────────────────
; TAB 4 — NOTIFY (Discord webhook)
; ─────────────────────────────────────────────────────────────────────────────
tabs.UseTab(4)

g.AddGroupBox("xm+10 y35 w430 h105 cWhite", "Discord Webhook")
cbEnableWebhook := g.AddCheckbox("xm+20 y55 w380 cWhite Background1E1E2E Checked", "Send Discord notification on boss spawn")
g.AddText("xm+20 y78 w90 cWhite Background1E1E2E", "Webhook URL:")
edWebhookUrl := g.AddEdit("x115 y75 w315 h22 Background2A2A3E cWhite", "https://discord.com/api/webhooks/...")
g.AddText("xm+20 y103 w90 cWhite Background1E1E2E", "Your User ID:")
edUserId := g.AddEdit("x115 y100 w175 h22 Background2A2A3E cWhite", "")
g.AddText("x298 y103 w135 cGray Background1E1E2E", "(leave blank = no ping)")

g.AddGroupBox("xm+10 y148 w430 h75 cWhite", "Bloodline Stone Detection")
cbDetectItem := g.AddCheckbox("xm+20 y168 w380 cWhite Background1E1E2E Checked", "Scan for Bloodline Stone (bright yellow/red item glow)")
g.AddText("xm+20 y192 w400 cGray Background1E1E2E", "Scans for bright yellow/red pixels on screen 1.5s after keys fire.")

g.AddGroupBox("xm+10 y231 w430 h85 cWhite", "Message Format Preview")
g.AddText("xm+20 y251 w400 cGray Background1E1E2E",
    "🦑  Boss Spawned!`n" .
    "Time: 10:35 PM  |  Bosses this session: 7`n" .
    "Bloodline Stone: ✅ Detected  (+ screenshot attached)")

g.AddGroupBox("xm+10 y324 w430 h80 cWhite", "Session Stats")
g.AddText("xm+20 y344 w150 cWhite Background1E1E2E", "Bosses spawned this session:")
lblSpawnCount := g.AddText("x175 y344 w50 cLime Background1E1E2E", "0")
g.AddButton("x235 y340 w90 h22", "Reset Count").OnEvent("Click", (*) => (bossSpawnCount := 0, lblSpawnCount.Value := "0"))
g.AddButton("xm+20 y369 w195 h28", "Send Test Notification").OnEvent("Click", TestWebhook)
lblWebhookStatus := g.AddText("x225 y375 w205 cGray Background1E1E2E", "")

g.AddGroupBox("xm+10 y412 w430 h38 cWhite", "")
g.AddText("xm+20 y424 w410 cGray Background1E1E2E",
    "⚡ Keys fire FIRST. Screenshot + webhook send in background — zero delay on keystrokes.")

; ─────────────────────────────────────────────────────────────────────────────
; TAB 5 — ANTI-AFK
; ─────────────────────────────────────────────────────────────────────────────
tabs.UseTab(5)

g.AddGroupBox("xm+10 y35 w430 h75 cWhite", "Anti-AFK Recording (.rec)")
g.AddText("xm+20 y55 w85 cWhite Background1E1E2E", "Recording:")
edAfkRecPath := g.AddEdit("x105 y52 w240 h22 Background2A2A3E cWhite", "C:\path\to\afk_recording.rec")
g.AddButton("x353 y52 w80 h22", "Browse").OnEvent("Click", BrowseAfkRec)
lblAfkRecInfo := g.AddText("xm+20 y82 w400 cGray Background1E1E2E", "No file loaded.")

g.AddGroupBox("xm+10 y118 w430 h75 cWhite", "Schedule")
cbEnableAfk := g.AddCheckbox("xm+20 y138 w380 cWhite Background1E1E2E Checked", "Enable anti-AFK")
g.AddText("xm+20 y162 w220 cWhite Background1E1E2E", "Play anti-AFK recording every:")
edAfkInterval := g.AddEdit("x245 y159 w55 h22 Background2A2A3E cWhite", "15")
g.AddText("x308 y162 w80 cWhite Background1E1E2E", "minutes")

g.AddGroupBox("xm+10 y200 w430 h130 cWhite", "Priority")
g.AddText("xm+20 y220 w410 cGray Background1E1E2E",
    "Anti-AFK is lowest priority — skipped if:`n" .
    "  • A boss macro is running`n" .
    "  • A player-count recording is playing`n`n" .
    "If a boss spawns during AFK recording it aborts`n" .
    "immediately and fires the key macro.")

g.AddGroupBox("xm+10 y338 w430 h75 cWhite", "Manual Test")
g.AddButton("xm+20 y358 w195 h28", "Play AFK Recording Once").OnEvent("Click", TestAfkRecording)
lblAfkStatus := g.AddText("x225 y364 w205 cGray Background1E1E2E", "")

; ─────────────────────────────────────────────────────────────────────────────
; BOTTOM BAR
; ─────────────────────────────────────────────────────────────────────────────
tabs.UseTab(0)

btnStart := g.AddButton("xm y443 w140 h36", "Start Scanning")
btnStart.OnEvent("Click", StartScan)
btnSave  := g.AddButton("x155 y443 w150 h36", "💾 Save Settings")
btnSave.OnEvent("Click", SaveSettings)
btnStop  := g.AddButton("x310 y443 w145 h36", "Stop")
btnStop.OnEvent("Click", StopScan)
btnStop.Enabled := false

g.SetFont("s9 cWhite", "Segoe UI")
g.AddText("xm y487 w45 cWhite Background1E1E2E", "Status:")
lblStatus := g.AddText("x52 y487 w398 h18 cGray Background1E1E2E", "Idle — configure settings then press Start.")
g.AddText("xm y508 w450 cGray Background1E1E2E", "F6=Start/Stop   F7=Reload   F8=Exit   F9=Stop playback")

g.Show("w465 h530")
g.OnEvent("Close", OnClose)

; Create data folders
for d in [dataDir, imagesDir, ssDir, logsDir]
    if !DirExist(d)
        DirCreate(d)

; Initialize GDI+ once for the lifetime of the script
si := Buffer(8, 0)
NumPut("UInt", 1, si)
DllCall("gdiplus\GdiplusStartup", "Ptr*", &gdipToken, "Ptr", si, "Ptr", 0)

LoadSettings()

; ══════════════════════════════════════════════════════════════════════════════
; HOTKEYS
; ══════════════════════════════════════════════════════════════════════════════
F6:: isScanning ? StopScan() : StartScan()
F7:: Reload()
F8:: ExitApp()
F9:: StopPlaybackNow()

; ══════════════════════════════════════════════════════════════════════════════
; TAB 1 — BOSS DETECT FUNCTIONS
; ══════════════════════════════════════════════════════════════════════════════

AddImage(*) {
    files := FileSelect("M 1", "", "Select Boss Screenshot(s)", "Images (*.png; *.bmp; *.jpg)")
    if !IsObject(files) || files.Length = 0
        return
    for path in files {
        SplitPath(path, &fname)
        destPath := imagesDir "\" fname
        if path != destPath
            FileCopy(path, destPath, true)
        alreadyAdded := false
        for existing in bossImages {
            if existing = destPath {
                alreadyAdded := true
                break
            }
        }
        if !alreadyAdded {
            bossImages.Push(destPath)
            lbBoss.Add([fname])
        }
    }
    SetStatus("Added " files.Length " image(s). Total: " bossImages.Length, "33FF99")
}

RemoveImage(*) {
    idx := lbBoss.Value
    if idx = 0
        return
    bossImages.RemoveAt(idx)
    lbBoss.Delete(idx)
    picPreview.Value := ""
    SetStatus("Removed. " bossImages.Length " image(s) remaining.", "FFD700")
}

ShowPreview(*) {
    idx := lbBoss.Value
    if idx = 0 || idx > bossImages.Length
        return
    try picPreview.Value := "*w165 *h105 " bossImages[idx]
    catch
        picPreview.Value := ""
}

; ══════════════════════════════════════════════════════════════════════════════
; TAB 2 — PLAYER COUNT (IMAGE-BASED)
; ══════════════════════════════════════════════════════════════════════════════

BrowseAddFriendImg(*) {
    global addFriendImg
    f := FileSelect("1", imagesDir, "Select 'Add friend' button crop", "Images (*.png;*.bmp;*.jpg)")
    if f = ""
        return
    ; Copy into data\images so the path is always local and consistent
    SplitPath(f, &fname)
    dest := imagesDir "\" fname
    if f != dest
        FileCopy(f, dest, true)
    addFriendImg := dest
    lblAddFriendImg.Value := fname
    lblAddFriendImg.Opt("cLime")
}

BrowseFriendLabelImg(*) {
    global friendLabelImg
    f := FileSelect("1", imagesDir, "Select 'Friend' label crop", "Images (*.png;*.bmp;*.jpg)")
    if f = ""
        return
    SplitPath(f, &fname)
    dest := imagesDir "\" fname
    if f != dest
        FileCopy(f, dest, true)
    friendLabelImg := dest
    lblFriendLabelImg.Value := fname
    lblFriendLabelImg.Opt("cLime")
}

BrowseEscIndicator(*) {
    global escIndicatorImg
    f := FileSelect("1", imagesDir, "Select ESC menu indicator image", "Images (*.png;*.bmp;*.jpg)")
    if f = ""
        return
    SplitPath(f, &fname)
    dest := imagesDir "\" fname
    if f != dest
        FileCopy(f, dest, true)
    escIndicatorImg := dest
    SplitPath(dest, &fname)
    lblEscIndicator.Value := "Indicator: " fname
    lblEscIndicator.Opt("cLime")
}

; Unused stubs kept so CapturePanel/TestPanelFlash calls don't crash
; (they were removed from the GUI but may linger in saved configs)
CapturePanel(*) {
    MsgBox("Calibration no longer needed — use the image-based method instead.", "Info", 64)
}
TestPanelFlash(*) {
    return
}

IsEscMenuOpen() {
    global escIndicatorImg
    if escIndicatorImg = "" || !FileExist(escIndicatorImg)
        return true
    return ImageSearch(&fx, &fy, 0, 0, A_ScreenWidth, A_ScreenHeight, "*40 " escIndicatorImg)
}

; Find ALL occurrences of an image on screen within a vertical band.
; searchFromY = start scanning from this Y (never re-scans above it).
; Returns array of found Y positions.
FindAllOccurrences(imgPath, searchFromY, tolerance) {
    found := []
    if !FileExist(imgPath)
        return found
    tol    := "*" tolerance " "
    startY := searchFromY
    Loop {
        if ImageSearch(&fx, &fy, 0, startY, A_ScreenWidth, A_ScreenHeight, tol imgPath) {
            found.Push(fy)
            ; Next search starts BELOW this find (button height ~25px, add buffer)
            startY := fy + 25
        } else {
            break
        }
    }
    return found
}

; Open ESC menu, scroll through, count all Add friend + Friend occurrences.
; Never rescans where already scanned. +1 for self at end.
; Returns: count, -1 = no images set, -2 = boss found
CountPlayers(debugMode := false) {
    global isCheckingPlayers, bossImages, addFriendImg, friendLabelImg

    if addFriendImg = "" && friendLabelImg = "" {
        return -1   ; no images set up
    }

    tol        := escImgTolerance
    maxScrolls := IsNumber(edEscScrollSteps.Value) ? Integer(edEscScrollSteps.Value) : 5

    MouseGetPos(&origX, &origY)
    isCheckingPlayers := true

    ; Open ESC menu if not already open
    if !IsEscMenuOpen() {
        Send("{Escape}")
        Sleep(500)
    } else {
        Sleep(100)
    }

    ; Scroll to top
    Loop 15
        Send("{WheelUp}")
    Sleep(250)

    CheckBoss() {
        for img in bossImages {
            if FileExist(img) && ImageSearch(&fx, &fy, 0, 0, A_ScreenWidth, A_ScreenHeight, "*50 " img)
                return true
        }
        return false
    }

    CloseMenuAndReturn(val) {
        isCheckingPlayers := false
        if IsEscMenuOpen() {
            Send("{Escape}")
            Sleep(300)
        }
        MouseMove(origX, origY)
        return val
    }

    totalCount      := 0
    scanFromY       := 0
    bottomHalfY     := 0
    prevFullCount   := 0   ; full-screen button count before scrolling — if unchanged after scroll, we're at the bottom

    Loop (maxScrolls + 1) {
        step := A_Index

        if CheckBoss()
            return CloseMenuAndReturn(-2)

        ; Always count full screen first to detect if scroll actually moved anything
        fullFoundYs := []
        if addFriendImg != ""
            for fy in FindAllOccurrences(addFriendImg, 0, tol)
                fullFoundYs.Push(fy)
        if friendLabelImg != ""
            for fy in FindAllOccurrences(friendLabelImg, 0, tol)
                fullFoundYs.Push(fy)

        ; If full-screen count is same as before the scroll, list didn't move — we're at the bottom
        if step > 1 && fullFoundYs.Length = prevFullCount {
            if debugMode
                ToolTip("Scroll " step ": no change (" fullFoundYs.Length ") — hit bottom, stopping", 10, 200, 1)
            break
        }
        prevFullCount := fullFoundYs.Length

        ; Now count only the relevant portion
        foundYs := []
        if step = 1 {
            ; First pass: count everything visible
            foundYs := fullFoundYs
        } else {
            ; Subsequent passes: only count bottom half (above = overlap already counted)
            for fy in fullFoundYs
                if fy >= bottomHalfY
                    foundYs.Push(fy)
        }

        thisCount := foundYs.Length
        totalCount += thisCount

        if step = 1 && thisCount > 0 {
            minY := foundYs[1]
            maxY := foundYs[1]
            for fy in foundYs {
                if fy < minY
                    minY := fy
                if fy > maxY
                    maxY := fy
            }
            bottomHalfY := minY + ((maxY - minY) // 2)
        }

        if debugMode
            ToolTip("Step " step ": +" thisCount " new, total=" (totalCount + 1), 10, 150, 1)

        if step > maxScrolls
            break

        Send("{WheelDown 3}")
        Sleep(200)
    }

    if CheckBoss()
        return CloseMenuAndReturn(-2)

    if debugMode {
        Sleep(3000)
        Loop 20
            ToolTip("", , , A_Index)
    }

    return CloseMenuAndReturn(totalCount + 1)   ; +1 for yourself
}

TestPlayerCount(*) {
    lblEscTestResult.Value := "Scanning... (check your screen)"
    lblEscTestResult.Opt("cYellow")
    count := CountPlayers(true)
    switch count {
        case -1: lblEscTestResult.Value := "Set up Add friend / Friend images first.", lblEscTestResult.Opt("cRed")
        case -2: lblEscTestResult.Value := "Boss detected — aborted!", lblEscTestResult.Opt("cFFD700")
        default: lblEscTestResult.Value := "Detected " count " player(s)  (+1 = you)", lblEscTestResult.Opt("cLime")
    }
}

; ══════════════════════════════════════════════════════════════════════════════
; TAB 3 — RECORDING FUNCTIONS
; ══════════════════════════════════════════════════════════════════════════════

BrowseRec(*) {
    f := FileSelect("1", "", "Select InformaalTask Recording (.rec)", "Recording (*.rec; *.txt)")
    if f = ""
        return
    edRecPath.Value := f
    ParseAndCacheRecording(f)
}

ParseAndCacheRecording(filePath) {
    global recCache, recCachePath
    recCache     := []
    recCachePath := filePath
    try {
        eventCount := 0
        duration   := 0
        for line in StrSplit(FileRead(filePath), "`n") {
            line := Trim(line)
            ; Strip BOM (U+FEFF) if present — AHK Trim() doesn't remove it
            if SubStr(line, 1, 1) = Chr(0xFEFF)
                line := SubStr(line, 2)
            if line = "" || SubStr(line, 1, 1) = "#" || SubStr(line, 1, 1) = "*"
                continue
            parts := StrSplit(line, "|")
            if parts.Length < 3
                continue
            dur := IsNumber(parts[2]) ? Integer(parts[2]) : 0
            recCache.Push({type: Trim(parts[1]), duration: dur, data: Trim(parts[3])})
            duration += dur
            eventCount++
        }
        secs := Round(duration / 1000, 1)
        lblRecInfo.Value := "Loaded: " eventCount " events  |  Est. duration: " secs "s"
        lblRecInfo.Opt("cLime")
    } catch {
        lblRecInfo.Value := "Loaded (could not parse stats)"
        lblRecInfo.Opt("cYellow")
    }
}

StopPlaybackNow(*) {
    global stopPlayback
    stopPlayback := true
    SetStatus("Playback stopped by user.", "FF6B6B")
}

TestRunRecording(*) {
    recPath := edRecPath.Value
    if !FileExist(recPath) {
        MsgBox("Recording file not found:`n" recPath, "File Missing", 48)
        return
    }
    SetStatus("Playing recording... (F9 to stop)", "FFD700")
    PlayRecording(recPath)
    if !stopPlayback
        SetStatus("Recording playback complete.", "33FF99")
}

; ── Core Playback Engine ─────────────────────────────────────────────────────
; Uses pre-parsed cache. Boss check is time-based (every 1000ms).
; ImageSearch narrowed to right 40% of screen.

PlayRecording(filePath) {
    global recCache, recCachePath
    if recCachePath != filePath || recCache.Length = 0
        ParseAndCacheRecording(filePath)
    PlayFromCache(recCache)
}

MapAHKKey(rawKey) {
    static keyMap := Map(
        " ","Space", "`t","Tab", "`r","Enter", "`n","Enter",
        "SPACE","Space","RETURN","Enter","BACK","Backspace",
        "ESC","Escape","DEL","Delete","INS","Insert",
        "UP","Up","DOWN","Down","LEFT","Left","RIGHT","Right",
        "PGUP","PgUp","PGDN","PgDn","HOME","Home","END","End"
    )
    upper := StrUpper(rawKey)
    if keyMap.Has(upper)
        return keyMap[upper]
    if keyMap.Has(rawKey)
        return keyMap[rawKey]
    return rawKey
}

; ══════════════════════════════════════════════════════════════════════════════
; CORE SCAN LOOP
; ══════════════════════════════════════════════════════════════════════════════

StartScan(*) {
    global isScanning
    if bossImages.Length = 0 {
        MsgBox("Add at least one boss image in the Boss Detect tab.", "No Images", 48)
        return
    }
    isScanning := true
    btnStart.Enabled := false
    btnStop.Enabled  := true
    OpenConsole()
    interval := IsNumber(edScan.Value) ? Integer(edScan.Value) : 500
    SetTimer(ScanLoop, interval)
    if cbEnablePlayerCheck.Value {
        delaySec := IsNumber(edPlayerScanDelay.Value) ? Integer(edPlayerScanDelay.Value) : 30
        SetTimer(BeginPlayerCountLoop, -(delaySec * 1000))
    }
    if cbEnableAfk.Value {
        afkMs := (IsNumber(edAfkInterval.Value) ? Integer(edAfkInterval.Value) : 15) * 60000
        SetTimer(AfkLoop, afkMs)
    }
    delaySec := IsNumber(edPlayerScanDelay.Value) ? Integer(edPlayerScanDelay.Value) : 30
    Log("Scanning started.")
    SetStatus("Boss scanning started. Player check in " delaySec "s...", "5BC8FF")
}

BeginPlayerCountLoop() {
    global isScanning
    if !isScanning
        return
    ; Fire the first check immediately as a one-shot
    SetTimer(PlayerCountLoop, -100)
}

StopScan(*) {
    global isScanning, lowPlayerStreak
    isScanning := false
    lowPlayerStreak := 0
    SetTimer(ScanLoop, 0)
    SetTimer(PlayerCountLoop, 0)
    SetTimer(BeginPlayerCountLoop, 0)
    SetTimer(AfkLoop, 0)
    btnStart.Enabled := true
    btnStop.Enabled  := false
    Log("Scanning stopped.")
    CloseConsole()
    SetStatus("Stopped.", "AAAAAA")
}

ScanLoop() {
    global isScanning, bossImages
    if !isScanning
        return
    for img in bossImages {
        if !FileExist(img)
            continue
        if ImageSearch(&fx, &fy, 0, 0, A_ScreenWidth, A_ScreenHeight, "*50 " img) {
            SetTimer(ScanLoop, 0)
            SetTimer(PlayerCountLoop, 0)
            SplitPath(img, &fname)
            Log("BOSS DETECTED: " fname)
            SetStatus("BOSS DETECTED (" fname ")! Running key macro...", "33FF99")
            Sleep(200)
            RunKeyMacro(fname)
            return
        }
    }
}

; Helper — call at the end of every PlayerCountLoop path to schedule next run
ScheduleNextPlayerCheck() {
    global isScanning
    if !isScanning || !cbEnablePlayerCheck.Value
        return
    intervalMs := Integer((IsNumber(edPlayerCheckInterval.Value) ? Float(edPlayerCheckInterval.Value) : 5.0) * 60000)
    SetTimer(PlayerCountLoop, intervalMs)  ; positive = repeating, reliable from any call depth
    mins := Round(intervalMs / 60000, 1)
    SetStatus("Next player check in " mins " min.", "5BC8FF")
}

PlayerCountLoop() {
    global isScanning, isPlayingRec

    if !isScanning || !cbEnablePlayerCheck.Value
        return

    ; Don’t interrupt while recording is playing
    if isPlayingRec {
        SetStatus("Player check skipped — recording active.", "AAAAAA")
        ScheduleNextPlayerCheck()
        return
    }

    threshold := IsNumber(edPlayerThreshold.Value) ? Integer(edPlayerThreshold.Value) : 6
    Log("Player count check started.")
    SetStatus("Checking player count...", "5BC8FF")

    count := CountPlayers()

    ; No images set
    if count = -1 {
        SetStatus("Player count: set up Add friend / Friend images first.", "FF6B6B")
        ScheduleNextPlayerCheck()
        return
    }

    ; Boss detected during count
    if count = -2 {
        SetTimer(ScanLoop, 0)
        Log("Boss detected during player count check.")
        SetStatus("Boss detected during player check! Running macro...", "33FF99")
        Sleep(200)
        RunKeyMacro("")
        return
    }

    ; 🔥 MAIN FIX — INSTANT TRIGGER
    if count < threshold {
        SetTimer(ScanLoop, 0)
        SetStatus("Low players (" count " < " threshold ")! Playing recording...", "FF9800")
        Sleep(200)
        HandleLowPlayerCount(count)
        return
    }

    ; Otherwise continue checking later
    ScheduleNextPlayerCheck()
}

HandleLowPlayerCount(count) {
    global isScanning, bossFoundDuringPlayback
    recPath := edRecPath.Value
    if !FileExist(recPath) {
        SetStatus("Recording not found: " recPath, "FF6B6B")
        ResumeScanning()
        return
    }
    Log("Recording playback started.")
    SetStatus("Playing recording... (F9 to stop | boss check active)", "FF9800")
    PlayRecording(recPath)
    if bossFoundDuringPlayback {
        Log("Boss detected mid-recording.")
        SetStatus("BOSS DETECTED mid-recording! Running key macro!", "33FF99")
        Sleep(100)
        RunKeyMacro("")
        return
    }
    if stopPlayback {
        SetStatus("Playback aborted.", "FF6B6B")
        return
    }
    Log("Recording playback finished.")
    SetStatus("Recording done.", "33FF99")
    Sleep(1000)
    action := cbActionAfterTT.Value
    if action = 3 {
        StopScan()
        return
    }
    if action = 2 {
        threshold := IsNumber(edPlayerThreshold.Value) ? Integer(edPlayerThreshold.Value) : 6
        SetStatus("Waiting for " threshold "+ players before resuming...", "FFD700")
        Loop {
            Sleep(5000)
            if !isScanning
                return
            c := CountPlayers()
            if c = -1 || c >= threshold
                break
            SetStatus("Waiting... " c " player(s). Need " threshold "+", "FFD700")
        }
    }
    ResumeScanning()
}

ResumeScanning() {
    global isScanning
    if !isScanning
        return
    interval := IsNumber(edScan.Value) ? Integer(edScan.Value) : 500
    SetTimer(ScanLoop, interval)
    Log("Scanning resumed.")
    if cbEnablePlayerCheck.Value {
        ScheduleNextPlayerCheck()
        ; Show next-check time in status instead of a generic "Resumed scanning"
        mins := Round((IsNumber(edPlayerCheckInterval.Value) ? Float(edPlayerCheckInterval.Value) : 5.0), 1)
        SetStatus("Scanning — next player check in " mins " min.", "5BC8FF")
    } else {
        SetStatus("Scanning for boss...", "5BC8FF")
    }
}

RunKeyMacro(bossImageName) {
    global isScanning, bossSpawnCount, isCheckingPlayers

    ; Always close ESC menu before firing keys — covers both mid-player-check
    ; and the rare case where the menu was open for any other reason
    isCheckingPlayers := false
    if IsEscMenuOpen() {
        Send("{Escape}")
        Sleep(400)
    }

    if WinExist("ahk_exe RobloxPlayerBeta.exe") {
        WinActivate("ahk_exe RobloxPlayerBeta.exe")
        Sleep(250)
    }

    ; ── KEYS FIRE FIRST ───────────────────────────────────────────────────────
    keys  := StrSplit(edKeys.Value, ",")
    delay := IsNumber(edDelay.Value) ? Integer(edDelay.Value) : 150
    for k in keys {
        k := Trim(k)
        if k != ""
            Send(k)
        Sleep(delay)
    }
    ; ── Keys done ─────────────────────────────────────────────────────────────

    bossSpawnCount++
    lblSpawnCount.Value := bossSpawnCount
    Log("Key macro fired. Session boss count: " bossSpawnCount)

    ; Take screenshot immediately after keys (GDI, ~50ms)
    ; Then send webhook in a completely background PS process — no blocking
    if cbEnableWebhook.Value && edWebhookUrl.Value != "" && !InStr(edWebhookUrl.Value, "...") {
        ; Wait 1.5s for item glow to appear on screen before scanning + screenshotting
        Sleep(1500)
        itemFound := cbDetectItem.Value ? ScanForItem() : false
        ssPath    := TakeScreenshotGDI()
        ; Launch PS fully detached — AHK moves on immediately after this line
        LaunchWebhookPS(ssPath, bossImageName, itemFound, bossSpawnCount)
        Log("Discord webhook sent. Bloodline Stone: " (itemFound ? "YES" : "NO"))
    }

    SetStatus("Key macro done. Resuming in 3s...", "FFD700")
    Sleep(1500)   ; remaining wait (1.5s already spent above if webhook on, skip overlap)
    ResumeScanning()
}

; Shared playback engine used by both recording and AFK
PlayFromCache(cache) {
    global stopPlayback, isPlayingRec, bossFoundDuringPlayback, bossImages
    stopPlayback := false
    bossFoundDuringPlayback := false
    isPlayingRec := true

    ; Focus Roblox first — coordinates are absolute screen coords from recording
    ; If Roblox isn't in the same position as when recorded, everything is off
    if WinExist("ahk_exe RobloxPlayerBeta.exe") {
        WinActivate("ahk_exe RobloxPlayerBeta.exe")
        Sleep(300)
    }

    ; Explicit screen coordinate mode — never let something else change this
    CoordMode("Mouse", "Screen")

    heldKeys        := Map()
    lastBossCheckMs := A_TickCount
    searchX1        := 0

    for event in cache {
        if stopPlayback
            break
        if event.duration > 0
            Sleep(event.duration)
        if stopPlayback
            break
        if (A_TickCount - lastBossCheckMs) >= 1000 {
            lastBossCheckMs := A_TickCount
            for img in bossImages {
                if FileExist(img) && ImageSearch(&fx, &fy, searchX1, 0, A_ScreenWidth, A_ScreenHeight, "*50 " img) {
                    stopPlayback := true
                    bossFoundDuringPlayback := true
                    break
                }
            }
            if bossFoundDuringPlayback
                break
        }
        switch event.type {
            case "MOVE":
                coords := StrSplit(event.data, ",")
                if coords.Length >= 2
                    MouseMove(Integer(coords[1]), Integer(coords[2]), 0)
            case "MOUSE_DOWN":
                Click("Down " (event.data = "RButton" ? "Right" : "Left"))
            case "MOUSE_UP":
                Click("Up " (event.data = "RButton" ? "Right" : "Left"))
            case "KEY_DOWN":
                key := MapAHKKey(event.data)
                if !heldKeys.Has(key) {
                    Send("{" key " down}")
                    heldKeys.Set(key, true)
                }
            case "KEY_UP":
                key := MapAHKKey(event.data)
                Send("{" key " up}")
                if heldKeys.Has(key)
                    heldKeys.Delete(key)
        }
    }
    for key, _ in heldKeys
        Send("{" key " up}")
    heldKeys.Clear()
    isPlayingRec := false
}

; ══════════════════════════════════════════════════════════════════════════════
; ANTI-AFK
; ══════════════════════════════════════════════════════════════════════════════

BrowseAfkRec(*) {
    global afkRecCache, afkRecCachePath
    f := FileSelect("1", "", "Select Anti-AFK Recording (.rec)", "Recording (*.rec; *.txt)")
    if f = ""
        return
    edAfkRecPath.Value := f
    SplitPath(f, &fname)
    lblAfkRecInfo.Value := "Loaded: " fname
    lblAfkRecInfo.Opt("cLime")
    afkRecCache := []
    afkRecCachePath := f
    try {
        for line in StrSplit(FileRead(f), "`n") {
            line := Trim(line)
            if SubStr(line, 1, 1) = Chr(0xFEFF)
                line := SubStr(line, 2)
            if line = "" || SubStr(line, 1, 1) = "#" || SubStr(line, 1, 1) = "*"
                continue
            parts := StrSplit(line, "|")
            if parts.Length < 3
                continue
            afkRecCache.Push({type: Trim(parts[1]), duration: IsNumber(parts[2]) ? Integer(parts[2]) : 0, data: Trim(parts[3])})
        }
    }
}

TestAfkRecording(*) {
    global afkRecCache
    if afkRecCache.Length = 0 {
        lblAfkStatus.Value := "No recording loaded!"
        lblAfkStatus.Opt("cRed")
        return
    }
    lblAfkStatus.Value := "Playing..."
    lblAfkStatus.Opt("cFFD700")
    PlayFromCache(afkRecCache)
    lblAfkStatus.Value := "Done."
    lblAfkStatus.Opt("cLime")
}

AfkLoop() {
    global isScanning, isPlayingRec, afkRecCache, bossFoundDuringPlayback
    if !isScanning || !cbEnableAfk.Value
        return
    ; Skip if any recording is already playing — never interrupt
    if isPlayingRec {
        SetStatus("AFK skipped — recording active.", "AAAAAA")
        return
    }
    if afkRecCache.Length = 0
        return
    Log("Anti-AFK recording started.")
    SetStatus("Playing anti-AFK recording...", "AAAAAA")
    PlayFromCache(afkRecCache)
    if bossFoundDuringPlayback {
        Log("Boss detected during AFK recording.")
        SetStatus("BOSS during AFK recording! Running key macro!", "33FF99")
        RunKeyMacro("")
        return
    }
    if isScanning
        Log("Anti-AFK recording finished.")
        SetStatus("Anti-AFK done. Scanning...", "5BC8FF")
}

; ══════════════════════════════════════════════════════════════════════════════
; DISCORD WEBHOOK + SCREENSHOT
; ══════════════════════════════════════════════════════════════════════════════

; Scan for bright yellow or red pixels anywhere on screen.
; Yellow = R>200 G>180 B<80. Red = R>200 G<80 B<80.
; Returns true if either found.
ScanForItem() {
    ; Search centre 60% of screen vertically, full width
    y1 := Integer(A_ScreenHeight * 0.2)
    y2 := Integer(A_ScreenHeight * 0.8)
    ; Yellow search
    if PixelSearch(&ox, &oy, 0, y1, A_ScreenWidth, y2, 0xFFDD00, 40)
        return true
    ; Red search
    if PixelSearch(&ox, &oy, 0, y1, A_ScreenWidth, y2, 0xFF1010, 40)
        return true
    return false
}

; Silent GDI screenshot — no keypresses, works for Roblox in windowed/borderless mode.
; DWM (Desktop Window Manager) composites Roblox into the desktop buffer,
; which GetDC(0)+BitBlt can read. Only exclusive fullscreen DX bypasses DWM — Roblox doesn't.
TakeScreenshotGDI() {
    global gdipToken
    timestamp := FormatTime(, "yyyyMMdd_HHmmss")
    savePath  := ssDir "\" timestamp ".png"
    Log("Screenshot: saving to " savePath)

    hDC    := DllCall("GetDC",                  "Ptr", 0,   "Ptr")
    hMemDC := DllCall("CreateCompatibleDC",     "Ptr", hDC, "Ptr")
    hBmp   := DllCall("CreateCompatibleBitmap", "Ptr", hDC, "Int", A_ScreenWidth, "Int", A_ScreenHeight, "Ptr")
    DllCall("SelectObject", "Ptr", hMemDC, "Ptr", hBmp)
    ; SRCCOPY | CAPTUREBLT — CAPTUREBLT includes layered/composited windows
    DllCall("BitBlt", "Ptr", hMemDC, "Int", 0, "Int", 0,
            "Int", A_ScreenWidth, "Int", A_ScreenHeight,
            "Ptr", hDC, "Int", 0, "Int", 0, "UInt", 0x40CC0020)

    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBmp, "Ptr", 0, "Ptr*", &pBmp := 0)
    clsid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsid)
    saveResult := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBmp, "WStr", savePath, "Ptr", clsid, "Ptr", 0)
    Log("Screenshot save result: " saveResult " | file exists after: " (FileExist(savePath) ? "YES" : "NO"))
    DllCall("gdiplus\GdipDisposeImage",    "Ptr", pBmp)

    DllCall("DeleteObject", "Ptr", hBmp)
    DllCall("DeleteDC",     "Ptr", hMemDC)
    DllCall("ReleaseDC",    "Ptr", 0, "Ptr", hDC)

    return savePath
}

; Sends screenshot + embed to Discord using curl.exe (built into Windows 10/11).
; JSON written to a temp file to avoid all command-line quoting issues.
; curl runs in background — AHK does not wait.
LaunchWebhookPS(ssPath, bossName, itemFound, spawnCount) {
    webhookUrl := edWebhookUrl.Value
    timeStr    := FormatTime(, "h:mm tt")
    itemStr    := itemFound ? "Detected" : "Not detected"
    SplitPath(bossName, &bname)
    bname := RegExReplace(bname, "\.[^.]+$", "")
    if bname = ""
        bname := "Boss"

    ; Build mention string — <@USER_ID> pings the user in Discord
    userId  := Trim(edUserId.Value)
    mention := (userId != "" && userId != "0") ? "<@" userId ">" : ""

    ; Build Discord embed JSON
    json := '{"content":"' mention '","embeds":[{"title":"\uD83E\uDDA6 Boss Spawned!","color":16711680,"fields":['
          . '{"name":"Time","value":"' timeStr '","inline":true},'
          . '{"name":"Krakens Spawned","value":"' spawnCount '","inline":true},'
          . '{"name":"Bloodline Stone","value":"' itemStr '","inline":true},'
          . '{"name":"Boss","value":"' bname '","inline":false}'
          . ']}]}'

    ; Write JSON to temp file (avoids all cmd quoting problems)
    jsonFile := A_Temp "\bm_payload_" A_TickCount ".json"
    FileAppend(json, jsonFile, "UTF-8")

    ; Build curl command
    ; -s = silent, no progress bar
    ; payload_json=<file reads file contents as form field value (not upload)
    ; file=@path uploads the PNG as attachment
    if FileExist(ssPath)
        cmd := 'curl.exe -s -X POST "' webhookUrl '" -F "payload_json=<' jsonFile '" -F "file=@' ssPath ';type=image/png"'
    else
        cmd := 'curl.exe -s -X POST "' webhookUrl '" -F "payload_json=<' jsonFile '"'

    ; Run curl completely detached — no window, AHK continues immediately
    Run(cmd,, "Hide")
}

TestWebhook(*) {
    if edWebhookUrl.Value = "" || InStr(edWebhookUrl.Value, "...") {
        lblWebhookStatus.Value := "Enter a webhook URL first."
        lblWebhookStatus.Opt("cRed")
        return
    }
    lblWebhookStatus.Value := "Sending test..."
    lblWebhookStatus.Opt("cYellow")
    ssPath := TakeScreenshotGDI()
    LaunchWebhookPS(ssPath, "TestBoss.png", true, bossSpawnCount)
    lblWebhookStatus.Value := "Sent via curl — check Discord."
    lblWebhookStatus.Opt("cLime")
}

; ══════════════════════════════════════════════════════════════════════════════
; UTILITY
; ══════════════════════════════════════════════════════════════════════════════
SetStatus(msg, hexColor := "FFFFFF") {
    lblStatus.Value := msg
    lblStatus.Opt("c" hexColor)
}

; Write a timestamped line to today's log file AND push to console window if open
Log(msg) {
    global logsDir, consoleEdit
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    line      := "[" timestamp "] " msg
    logFile   := logsDir "\" FormatTime(, "yyyy-MM-dd") ".log"
    FileAppend(line "`n", logFile, "UTF-8")
    ; If console is open, append this line to the live view
    if consoleEdit {
        try {
            consoleEdit.Value .= (consoleEdit.Value = "" ? "" : "`r`n") line
            ; Auto-scroll to bottom by selecting end position
            SendMessage(0x00B1, -1, -1, consoleEdit.Hwnd)   ; EM_SETSEL
            SendMessage(0x00B7, 0, 0, consoleEdit.Hwnd)     ; EM_SCROLLCARET
        }
    }
}

; Small terminal-style window for live log output. Opens on Start, closes on Stop.
OpenConsole() {
    global consoleGui, consoleEdit
    if consoleGui
        return   ; already open
    consoleGui := Gui("+AlwaysOnTop +ToolWindow -MinimizeBox -MaximizeBox", "Boss Macro — Live Log")
    consoleGui.BackColor := "0A0A0A"
    consoleGui.SetFont("s8 cLime", "Consolas")
    consoleEdit := consoleGui.AddEdit("w380 h380 Background0A0A0A ReadOnly -VScroll +HScroll VScroll Multi", "")
    consoleGui.OnEvent("Close", (*) => CloseConsole())
    ; Position top-right of screen — out of the way of Roblox
    consoleGui.Show("x" (A_ScreenWidth - 400) " y40 w400 h400 NoActivate")
    Log("═══ Console opened ═══")
}

CloseConsole() {
    global consoleGui, consoleEdit
    if !consoleGui
        return
    try consoleGui.Destroy()
    consoleGui  := 0
    consoleEdit := 0
}

; ══════════════════════════════════════════════════════════════════════════════
; SAVE / LOAD SETTINGS
; ══════════════════════════════════════════════════════════════════════════════

OnClose(*) {
    global gdipToken
    CloseConsole()
    if gdipToken
        DllCall("gdiplus\GdiplusShutdown", "Ptr", gdipToken)
    SaveSettings()
    ExitApp()
}

SaveSettings(*) {
    global addFriendImg, friendLabelImg, escIndicatorImg
    global bossImages, configFile
    IniWrite(edKeys.Value,  configFile, "BossDetect", "Keys")
    IniWrite(edDelay.Value, configFile, "BossDetect", "KeyDelay")
    IniWrite(edScan.Value,  configFile, "BossDetect", "ScanInterval")
    IniWrite(bossImages.Length, configFile, "BossDetect", "ImageCount")
    loop bossImages.Length {
        SplitPath(bossImages[A_Index], &fname)
        IniWrite(fname, configFile, "BossDetect", "Image" A_Index)
    }
    IniWrite(escIndicatorImg,              configFile, "PlayerCount", "EscIndicatorImg")
    IniWrite(addFriendImg,                 configFile, "PlayerCount", "AddFriendImg")
    IniWrite(friendLabelImg,               configFile, "PlayerCount", "FriendLabelImg")
    IniWrite(edEscScrollSteps.Value,       configFile, "PlayerCount", "EscScrollSteps")
    IniWrite(edPlayerCheckInterval.Value,  configFile, "PlayerCount", "CheckInterval")
    IniWrite(edRecPath.Value,            configFile, "Recording", "RecPath")
    IniWrite(edPlayerThreshold.Value,    configFile, "Recording", "PlayerThreshold")
    IniWrite(edPlayerScanDelay.Value,    configFile, "Recording", "PlayerScanDelay")
    IniWrite(cbEnablePlayerCheck.Value,  configFile, "Recording", "EnablePlayerCheck")
    IniWrite(cbActionAfterTT.Value,      configFile, "Recording", "ActionAfterRec")
    IniWrite(edWebhookUrl.Value,    configFile, "Notify", "WebhookUrl")
    IniWrite(cbEnableWebhook.Value, configFile, "Notify", "EnableWebhook")
    IniWrite(cbDetectItem.Value,    configFile, "Notify", "DetectItem")
    IniWrite(edUserId.Value,        configFile, "Notify", "UserId")
    IniWrite(edAfkRecPath.Value,  configFile, "AntiAFK", "RecPath")
    IniWrite(edAfkInterval.Value, configFile, "AntiAFK", "Interval")
    IniWrite(cbEnableAfk.Value,   configFile, "AntiAFK", "Enabled")
    SetStatus("Settings saved.", "33FF99")
}

LoadSettings() {
    global panelX1, panelY1, panelX2, panelY2, panelCalibrated
    global addFriendImg, friendLabelImg, escIndicatorImg
    global bossImages, imagesDir, configFile

    if !FileExist(configFile)
        return

    edKeys.Value  := IniRead(configFile, "BossDetect", "Keys",         "e,q,r")
    edDelay.Value := IniRead(configFile, "BossDetect", "KeyDelay",     "150")
    edScan.Value  := IniRead(configFile, "BossDetect", "ScanInterval", "500")
    imgCount := Integer(IniRead(configFile, "BossDetect", "ImageCount", "0"))
    loop imgCount {
        fname    := IniRead(configFile, "BossDetect", "Image" A_Index, "")
        fullPath := imagesDir "\" fname
        if fname != "" && FileExist(fullPath) {
            bossImages.Push(fullPath)
            lbBoss.Add([fname])
        }
    }

    escIndicatorImg := IniRead(configFile, "PlayerCount", "EscIndicatorImg", "")
    addFriendImg    := IniRead(configFile, "PlayerCount", "AddFriendImg",    "")
    friendLabelImg  := IniRead(configFile, "PlayerCount", "FriendLabelImg",  "")

    ; If stored path doesn't exist, try resolving from imagesDir (handles moved folders)
    FixImgPath(path) {
        if path = ""
            return ""
        if FileExist(path)
            return path
        SplitPath(path, &fname)
        alt := imagesDir "\" fname
        return FileExist(alt) ? alt : path
    }
    escIndicatorImg := FixImgPath(escIndicatorImg)
    addFriendImg    := FixImgPath(addFriendImg)
    friendLabelImg  := FixImgPath(friendLabelImg)

    edEscScrollSteps.Value      := IniRead(configFile, "PlayerCount", "EscScrollSteps", "5")
    edPlayerCheckInterval.Value := IniRead(configFile, "PlayerCount", "CheckInterval",  "5")
    if escIndicatorImg != "" && FileExist(escIndicatorImg) {
        SplitPath(escIndicatorImg, &fname)
        lblEscIndicator.Value := "Indicator: " fname
        lblEscIndicator.Opt("cLime")
    }
    if addFriendImg != "" && FileExist(addFriendImg) {
        SplitPath(addFriendImg, &fname)
        lblAddFriendImg.Value := fname
        lblAddFriendImg.Opt("cLime")
    }
    if friendLabelImg != "" && FileExist(friendLabelImg) {
        SplitPath(friendLabelImg, &fname)
        lblFriendLabelImg.Value := fname
        lblFriendLabelImg.Opt("cLime")
    }

    edRecPath.Value           := IniRead(configFile, "Recording", "RecPath",           "")
    edPlayerThreshold.Value   := IniRead(configFile, "Recording", "PlayerThreshold",   "6")
    edPlayerScanDelay.Value   := IniRead(configFile, "Recording", "PlayerScanDelay",   "30")
    cbEnablePlayerCheck.Value := Integer(IniRead(configFile, "Recording", "EnablePlayerCheck", "1"))
    cbActionAfterTT.Value     := Integer(IniRead(configFile, "Recording", "ActionAfterRec",    "1"))

    if edRecPath.Value != "" && FileExist(edRecPath.Value) {
        SplitPath(edRecPath.Value, &fname)
        lblRecInfo.Value := "Loaded: " fname
        lblRecInfo.Opt("cLime")
        ParseAndCacheRecording(edRecPath.Value)
    }

    edWebhookUrl.Value    := IniRead(configFile, "Notify", "WebhookUrl",     "https://discord.com/api/webhooks/...")
    cbEnableWebhook.Value := Integer(IniRead(configFile, "Notify", "EnableWebhook", "1"))
    cbDetectItem.Value    := Integer(IniRead(configFile, "Notify", "DetectItem",    "1"))
    edUserId.Value        := IniRead(configFile, "Notify", "UserId",         "")

    edAfkRecPath.Value  := IniRead(configFile, "AntiAFK", "RecPath",  "")
    edAfkInterval.Value := IniRead(configFile, "AntiAFK", "Interval", "15")
    cbEnableAfk.Value   := Integer(IniRead(configFile, "AntiAFK", "Enabled", "1"))
    if edAfkRecPath.Value != "" && FileExist(edAfkRecPath.Value) {
        SplitPath(edAfkRecPath.Value, &fname)
        lblAfkRecInfo.Value := "Loaded: " fname
        lblAfkRecInfo.Opt("cLime")
        BrowseAfkRec_LoadPath(edAfkRecPath.Value)
    }

    SetStatus("Settings loaded.", "5BC8FF")
}

BrowseAfkRec_LoadPath(f) {
    global afkRecCache, afkRecCachePath
    afkRecCache := []
    afkRecCachePath := f
    try {
        for line in StrSplit(FileRead(f), "`n") {
            line := Trim(line)
            if SubStr(line, 1, 1) = Chr(0xFEFF)
                line := SubStr(line, 2)
            if line = "" || SubStr(line, 1, 1) = "#" || SubStr(line, 1, 1) = "*"
                continue
            parts := StrSplit(line, "|")
            if parts.Length < 3
                continue
            afkRecCache.Push({type: Trim(parts[1]), duration: IsNumber(parts[2]) ? Integer(parts[2]) : 0, data: Trim(parts[3])})
        }
    }
}
