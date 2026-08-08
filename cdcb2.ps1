# =====================================================================
# HACHIHI DEPLOYMENT TOOL v3.2
# One-Click Automated Windows Deployment
#
# Chức năng:
# - Tự yêu cầu quyền Administrator
# - Kiểm tra Internet
# - Kiểm tra Winget
# - Update Winget sources
# - Tải apps.json từ GitHub
# - Chọn Profile
# - Kiểm tra phần mềm đã cài
# - Cài phần mềm bằng Winget
# - Verify lại sau khi cài
# - Cài Font
# - Kiểm tra dung lượng ổ C
# - Đổi tên máy
# - Log chi tiết
# - Xuất install.json
# - Gửi báo cáo Google Apps Script
# - Retry khi mạng lỗi
# - Không dừng toàn bộ khi một app lỗi
# =====================================================================

#Requires -Version 5.1

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# =====================================================================
# 1. ADMINISTRATOR
# =====================================================================

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)

if (-not $currentPrincipal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    try {
        Start-Process powershell.exe `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
            -Verb RunAs

        exit
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Không thể yêu cầu quyền Administrator.",
            "HACHIHI Deployment Tool",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        exit
    }
}

# =====================================================================
# 2. LOAD WINDOWS FORMS
# =====================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# =====================================================================
# 3. CONFIG
# =====================================================================

$global:hachihiDir = "C:\HachihiSoftware"

if (-not (Test-Path $global:hachihiDir)) {
    New-Item `
        -ItemType Directory `
        -Path $global:hachihiDir `
        -Force `
        | Out-Null
}

$global:logPath = Join-Path $global:hachihiDir "install.log"
$global:jsonPath = Join-Path $global:hachihiDir "install.json"

# ---------------------------------------------------------------------
# THAY LINK NÀY BẰNG apps.json THỰC TẾ CỦA BẠN
# ---------------------------------------------------------------------

$global:configUrl =
    "https://raw.githubusercontent.com/hachihi/hachihi-setup/main/apps.json"

# ---------------------------------------------------------------------
# THAY BẰNG GOOGLE APPS SCRIPT WEB APP
# ---------------------------------------------------------------------

$global:webhookUrl =
    "YOUR_GOOGLE_APPS_SCRIPT_WEB_URL_HERE"

# ---------------------------------------------------------------------
# Nếu webhook của bạn yêu cầu token thì điền ở đây.
# Để trống nếu chưa dùng.
# ---------------------------------------------------------------------

$global:webhookToken = ""

$global:config = $null

$global:deploymentStarted = $false
$global:deploymentFinished = $false

# =====================================================================
# 4. LOG
# =====================================================================

function Write-HachihiLog {

    param(
        [string]$Message,
        [string]$Type = "INFO"
    )

    try {

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        $logLine =
            "[$timestamp] [$Type] $Message"

        Add-Content `
            -Path $global:logPath `
            -Value $logLine `
            -Encoding UTF8

        if ($global:txtLogControl) {

            $global:txtLogControl.AppendText(
                "$logLine`r`n"
            )

            $global:txtLogControl.SelectionStart =
                $global:txtLogControl.Text.Length

            $global:txtLogControl.ScrollToCaret()
        }

        [System.Windows.Forms.Application]::DoEvents()
    }
    catch {
        # Không để lỗi log làm dừng chương trình
    }
}

# =====================================================================
# 5. RETRY
# =====================================================================

function Invoke-HachihiRetry {

    param(
        [scriptblock]$Action,
        [int]$Retries = 3,
        [int]$DelaySeconds = 2
    )

    for ($attempt = 1; $attempt -le $Retries; $attempt++) {

        try {

            return & $Action

        }
        catch {

            if ($attempt -eq $Retries) {
                throw
            }

            Write-HachihiLog `
                "Thử lại lần $attempt/$Retries..." `
                "RETRY"

            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

# =====================================================================
# 6. INTERNET
# =====================================================================

function Test-HachihiInternet {

    try {

        $res = Invoke-WebRequest `
            -Uri "https://www.msftconnecttest.com/connecttest.txt" `
            -TimeoutSec 5 `
            -UseBasicParsing `
            -ErrorAction Stop

        return ($res.StatusCode -eq 200)

    }
    catch {

        return $false
    }
}

# =====================================================================
# 7. PENDING REBOOT
# =====================================================================

function Test-WindowsPendingReboot {

    $cbs = Test-Path `
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"

    $wu = Test-Path `
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"

    $pendingFileRename = Test-Path `
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations"

    return (
        $cbs -or
        $wu -or
        $pendingFileRename
    )
}

# =====================================================================
# 8. SYSTEM INFO
# =====================================================================

function Get-HachihiSystemMetrics {

    try {

        $cs = Get-CimInstance Win32_ComputerSystem `
            -ErrorAction Stop

        $proc = Get-CimInstance Win32_Processor `
            -ErrorAction Stop |
            Select-Object -First 1

        $os = Get-CimInstance Win32_OperatingSystem `
            -ErrorAction Stop

        $bios = Get-CimInstance Win32_BIOS `
            -ErrorAction Stop

        $driveC = Get-CimInstance Win32_LogicalDisk `
            -Filter "DeviceID='C:'" `
            -ErrorAction SilentlyContinue

        $ip = ""

        try {

            $ip = (
                Get-NetIPAddress `
                    -AddressFamily IPv4 `
                    -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.IPAddress -notlike "127.*" -and
                    $_.IPAddress -notlike "169.254.*"
                } |
                Select-Object -ExpandProperty IPAddress
            ) -join ", "

        }
        catch {
            $ip = ""
        }

        $ramGB = 0
        $freeDiskGB = 0

        if ($cs.TotalPhysicalMemory) {

            $ramGB = [math]::Round(
                $cs.TotalPhysicalMemory / 1GB,
                1
            )
        }

        if ($driveC.FreeSpace) {

            $freeDiskGB = [math]::Round(
                $driveC.FreeSpace / 1GB,
                1
            )
        }

        return @{
            ComputerName  = $env:COMPUTERNAME
            Model         = [string]$cs.Model
            Manufacturer  = [string]$cs.Manufacturer
            Serial        = [string]$bios.SerialNumber
            CPU           = [string]$proc.Name
            RAM_GB        = $ramGB
            FreeDiskC_GB  = $freeDiskGB
            OSVersion     = [string]$os.Caption
            OSBuild       = [string]$os.BuildNumber
            IPAddress     = $ip
            PendingReboot = Test-WindowsPendingReboot
        }
    }
    catch {

        Write-HachihiLog `
            "Không thể đọc đầy đủ thông tin hệ thống: $($_.Exception.Message)" `
            "WARNING"

        return @{
            ComputerName  = $env:COMPUTERNAME
            Model         = "N/A"
            Manufacturer  = "N/A"
            Serial        = "N/A"
            CPU           = "N/A"
            RAM_GB        = 0
            FreeDiskC_GB  = 0
            OSVersion     = "N/A"
            OSBuild       = "N/A"
            IPAddress     = ""
            PendingReboot = $false
        }
    }
}

# =====================================================================
# 9. CHECK WINGET
# =====================================================================

function Get-HachihiWingetPath {

    $cmd = Get-Command winget.exe `
        -ErrorAction SilentlyContinue

    if ($cmd) {
        return $cmd.Source
    }

    $possiblePaths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
        "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe"
    )

    foreach ($path in $possiblePaths) {

        $found = Get-ChildItem `
            -Path $path `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($found) {
            return $found.FullName
        }
    }

    return $null
}

function Test-HachihiWinget {

    $wingetPath = Get-HachihiWingetPath

    if ($wingetPath) {

        Write-HachihiLog `
            "Đã tìm thấy Winget: $wingetPath" `
            "WINGET"

        return $true
    }

    Write-HachihiLog `
        "Không tìm thấy Winget/App Installer trên máy." `
        "ERROR"

    return $false
}

# =====================================================================
# 10. WINGET SOURCE
# =====================================================================

function Initialize-HachihiWinget {

    $wingetPath = Get-HachihiWingetPath

    if (-not $wingetPath) {
        return $false
    }

    Write-HachihiLog `
        "Đang kiểm tra nguồn Winget..." `
        "WINGET"

    try {

        & $wingetPath source update `
            --disable-interactivity `
            --accept-source-agreements `
            2>&1 |
            Out-Null

        Write-HachihiLog `
            "Winget source đã được cập nhật." `
            "SUCCESS"

        return $true
    }
    catch {

        Write-HachihiLog `
            "Không thể cập nhật Winget source: $($_.Exception.Message)" `
            "WARNING"

        return $true
    }
}

# =====================================================================
# 11. WINGET APP CHECK
# =====================================================================

function Test-WingetAppInstalled {

    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId
    )

    $wingetPath = Get-HachihiWingetPath

    if (-not $wingetPath) {
        return $false
    }

    try {

        $output = & $wingetPath list `
            --id $AppId `
            --exact `
            --accept-source-agreements `
            --disable-interactivity `
            2>&1 |
            Out-String

        if ($LASTEXITCODE -eq 0 -and
            $output -match [regex]::Escape($AppId)) {

            return $true
        }

        return $false
    }
    catch {

        return $false
    }
}

# =====================================================================
# 12. INSTALL WINGET APP
# =====================================================================

function Install-HachihiWingetApp {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$AppId
    )

    $wingetPath = Get-HachihiWingetPath

    if (-not $wingetPath) {

        Write-HachihiLog `
            "Winget không khả dụng. Không thể cài $Name." `
            "ERROR"

        return $false
    }

    Write-HachihiLog `
        "Đang cài đặt: $Name [$AppId]" `
        "INSTALL"

    try {

        $arguments = @(
            "install"
            "--id"
            $AppId
            "--exact"
            "--silent"
            "--accept-package-agreements"
            "--accept-source-agreements"
            "--disable-interactivity"
        )

        $process = Start-Process `
            -FilePath $wingetPath `
            -ArgumentList $arguments `
            -Wait `
            -PassThru `
            -NoNewWindow

        $exitCode = $process.ExitCode

        if ($exitCode -eq 0) {

            Write-HachihiLog `
                "Cài đặt thành công: $Name" `
                "SUCCESS"

            return $true
        }

        # Một số installer trả về mã thành công đặc biệt
        # dù Winget không trả 0.
        if ($exitCode -eq -1978335189) {

            Write-HachihiLog `
                "$Name có thể đã được cài đặt / installer yêu cầu trạng thái khác." `
                "WARNING"

            return $true
        }

        Write-HachihiLog `
            "Cài đặt thất bại: $Name | ExitCode=$exitCode" `
            "ERROR"

        return $false
    }
    catch {

        Write-HachihiLog `
            "Exception khi cài $Name : $($_.Exception.Message)" `
            "ERROR"

        return $false
    }
}

# =====================================================================
# 13. VERIFY APP
# =====================================================================

function Verify-HachihiApp {

    param(
        [string]$Name,
        [string]$AppId
    )

    Start-Sleep -Seconds 2

    if (Test-WingetAppInstalled -AppId $AppId) {

        Write-HachihiLog `
            "VERIFY OK: $Name" `
            "VERIFY"

        return $true
    }

    Write-HachihiLog `
        "VERIFY FAILED: $Name" `
        "ERROR"

    return $false
}

# =====================================================================
# 14. DOWNLOAD CONFIG
# =====================================================================

function Get-HachihiConfig {

    Write-HachihiLog `
        "Đang tải cấu hình từ GitHub..." `
        "CONFIG"

    try {

        $jsonRaw = Invoke-HachihiRetry `
            -Retries 3 `
            -DelaySeconds 2 `
            -Action {

                Invoke-WebRequest `
                    -Uri $global:configUrl `
                    -TimeoutSec 15 `
                    -UseBasicParsing `
                    -ErrorAction Stop
            }

        if (-not $jsonRaw.Content) {
            throw "File apps.json rỗng."
        }

        $config = ConvertFrom-Json `
            -InputObject $jsonRaw.Content `
            -ErrorAction Stop

        if (-not $config.Apps) {
            throw "apps.json không có thuộc tính Apps."
        }

        if (-not $config.Profiles) {
            throw "apps.json không có thuộc tính Profiles."
        }

        $global:config = $config

        Write-HachihiLog `
            "Đã tải apps.json thành công. Version: $($config.Version)" `
            "SUCCESS"

        return $true
    }
    catch {

        Write-HachihiLog `
            "Không thể tải/đọc apps.json: $($_.Exception.Message)" `
            "ERROR"

        return $false
    }
}

# =====================================================================
# 15. REFRESH CHECKLIST
# =====================================================================

function RefreshAppChecklist {

    if (-not $global:config) {
        return
    }

    $checkedListBox.Items.Clear()

    $selectedProfile = [string]$cmbProfile.SelectedItem

    foreach ($app in $global:config.Apps) {

        $index = $checkedListBox.Items.Add(
            [string]$app.Name
        )

        $checked = $false

        if ($app.Profiles) {

            $checked =
                $app.Profiles -contains $selectedProfile
        }

        $checkedListBox.SetItemChecked(
            $index,
            $checked
        )
    }

    Write-HachihiLog `
        "Đã tải profile: $selectedProfile" `
        "PROFILE"
}

# =====================================================================
# 16. FONT INSTALL
# =====================================================================

function Install-HachihiFonts {

    if (-not $global:config.FontUrl) {

        Write-HachihiLog `
            "Không có FontUrl trong apps.json. Bỏ qua Font." `
            "WARNING"

        return @{
            Success = $false
            Added = 0
            Skipped = 0
        }
    }

    $tempDir = Join-Path `
        $env:TEMP `
        "HachihiFonts"

    $zipPath = Join-Path `
        $tempDir `
        "fonts.zip"

    $extractPath = Join-Path `
        $tempDir `
        "extracted"

    try {

        if (Test-Path $tempDir) {

            Remove-Item `
                $tempDir `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }

        New-Item `
            -ItemType Directory `
            -Path $tempDir `
            -Force |
            Out-Null

        Write-HachihiLog `
            "Đang tải bộ Font..." `
            "FONT"

        Invoke-HachihiRetry `
            -Retries 3 `
            -DelaySeconds 2 `
            -Action {

                Invoke-WebRequest `
                    -Uri $global:config.FontUrl `
                    -OutFile $zipPath `
                    -TimeoutSec 30 `
                    -UseBasicParsing `
                    -ErrorAction Stop
            } | Out-Null

        # -------------------------------------------------------------
        # SHA256
        # -------------------------------------------------------------

        if ($global:config.FontHashSHA256) {

            Write-HachihiLog `
                "Đang kiểm tra SHA256 Font..." `
                "FONT"

            $hash = (
                Get-FileHash `
                    -Path $zipPath `
                    -Algorithm SHA256
            ).Hash

            if ($hash.ToUpper() -ne
                $global:config.FontHashSHA256.ToUpper()) {

                throw "SHA256 Font không khớp."
            }

            Write-HachihiLog `
                "SHA256 Font hợp lệ." `
                "SUCCESS"
        }

        Expand-Archive `
            -Path $zipPath `
            -DestinationPath $extractPath `
            -Force

        $fontFiles = Get-ChildItem `
            -Path $extractPath `
            -Recurse `
            -File `
            -Include *.ttf, *.otf `
            -ErrorAction Stop

        $fontDir = "$env:SystemRoot\Fonts"

        $added = 0
        $skipped = 0

        foreach ($font in $fontFiles) {

            $target = Join-Path `
                $fontDir `
                $font.Name

            if (Test-Path $target) {

                Write-HachihiLog `
                    "Font đã có: $($font.Name)" `
                    "SKIP"

                $skipped++

                continue
            }

            try {

                Copy-Item `
                    -Path $font.FullName `
                    -Destination $target `
                    -Force `
                    -ErrorAction Stop

                # Registry
                $registryPath =
                    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

                $fontType = "TrueType"

                if ($font.Extension.ToLower() -eq ".otf") {
                    $fontType = "OpenType"
                }

                $regName =
                    "$($font.BaseName) ($fontType)"

                New-ItemProperty `
                    -Path $registryPath `
                    -Name $regName `
                    -Value $font.Name `
                    -PropertyType String `
                    -Force `
                    -ErrorAction SilentlyContinue |
                    Out-Null

                $added++

                Write-HachihiLog `
                    "Đã cài Font: $($font.Name)" `
                    "SUCCESS"
            }
            catch {

                Write-HachihiLog `
                    "Không thể cài Font $($font.Name): $($_.Exception.Message)" `
                    "ERROR"
            }
        }

        Write-HachihiLog `
            "Font hoàn tất: thêm $added | bỏ qua $skipped" `
            "FONT"

        return @{
            Success = $true
            Added = $added
            Skipped = $skipped
        }
    }
    catch {

        Write-HachihiLog `
            "Lỗi Font: $($_.Exception.Message)" `
            "ERROR"

        return @{
            Success = $false
            Added = 0
            Skipped = 0
        }
    }
    finally {

        if (Test-Path $tempDir) {

            Remove-Item `
                $tempDir `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

# =====================================================================
# 17. RENAME COMPUTER
# =====================================================================

function Set-HachihiComputerName {

    param(
        [string]$NewName
    )

    $NewName = $NewName.Trim()

    if ([string]::IsNullOrWhiteSpace($NewName)) {

        return @{
            Changed = $false
            Name = $env:COMPUTERNAME
            Error = "Tên máy trống."
        }
    }

    if ($NewName -eq $env:COMPUTERNAME) {

        return @{
            Changed = $false
            Name = $env:COMPUTERNAME
            Error = ""
        }
    }

    if ($NewName.Length -gt 15) {

        return @{
            Changed = $false
            Name = $env:COMPUTERNAME
            Error = "Tên máy Windows không được quá 15 ký tự trong trường hợp này."
        }
    }

    if ($NewName -notmatch '^[A-Za-z0-9\-]+$') {

        return @{
            Changed = $false
            Name = $env:COMPUTERNAME
            Error = "Tên máy chỉ nên chứa A-Z, 0-9 và dấu gạch ngang."
        }
    }

    try {

        Rename-Computer `
            -NewName $NewName `
            -Force `
            -ErrorAction Stop

        Write-HachihiLog `
            "Đã đặt tên máy mới: $NewName" `
            "SUCCESS"

        return @{
            Changed = $true
            Name = $NewName
            Error = ""
        }
    }
    catch {

        Write-HachihiLog `
            "Không thể đổi tên máy: $($_.Exception.Message)" `
            "ERROR"

        return @{
            Changed = $false
            Name = $env:COMPUTERNAME
            Error = $_.Exception.Message
        }
    }
}

# =====================================================================
# 18. SEND WEBHOOK
# =====================================================================

function Send-HachihiWebhook {

    param(
        [object]$Report
    )

    if (
        [string]::IsNullOrWhiteSpace($global:webhookUrl) -or
        $global:webhookUrl -eq
        "YOUR_GOOGLE_APPS_SCRIPT_WEB_URL_HERE"
    ) {

        Write-HachihiLog `
            "Webhook chưa được cấu hình. Bỏ qua." `
            "WEBHOOK"

        return $false
    }

    try {

        $bodyJson =
            $Report |
            ConvertTo-Json -Depth 10

        $headers = @{}

        if (-not [string]::IsNullOrWhiteSpace(
            $global:webhookToken
        )) {

            $headers["Authorization"] =
                "Bearer $global:webhookToken"
        }

        Write-HachihiLog `
            "Đang gửi báo cáo về Google Sheets..." `
            "WEBHOOK"

        $response = Invoke-HachihiRetry `
            -Retries 3 `
            -DelaySeconds 3 `
            -Action {

                Invoke-RestMethod `
                    -Uri $global:webhookUrl `
                    -Method Post `
                    -Body $bodyJson `
                    -Headers $headers `
                    -ContentType "application/json; charset=utf-8" `
                    -TimeoutSec 15 `
                    -ErrorAction Stop
            }

        Write-HachihiLog `
            "Gửi báo cáo thành công." `
            "SUCCESS"

        return $true
    }
    catch {

        Write-HachihiLog `
            "Webhook lỗi: $($_.Exception.Message)" `
            "WARNING"

        return $false
    }
}

# =====================================================================
# 19. CREATE RESULT REPORT
# =====================================================================

function New-HachihiReport {

    param(
        [hashtable]$SystemInfo,
        [string]$FinalComputerName,
        [string]$Profile,
        [array]$InstalledSummary,
        [int]$SuccessCount,
        [int]$FailedCount,
        [int]$SkippedCount,
        [string]$Duration,
        [bool]$RestartRequired
    )

    return [ordered]@{

        ToolName =
            "HACHIHI Deployment Tool"

        ToolVersion =
            "3.2"

        ComputerName =
            $FinalComputerName

        CurrentComputerName =
            $env:COMPUTERNAME

        Manufacturer =
            $SystemInfo.Manufacturer

        Model =
            $SystemInfo.Model

        Serial =
            $SystemInfo.Serial

        CPU =
            $SystemInfo.CPU

        RAM_GB =
            $SystemInfo.RAM_GB

        FreeDiskC_GB =
            $SystemInfo.FreeDiskC_GB

        OSVersion =
            $SystemInfo.OSVersion

        OSBuild =
            $SystemInfo.OSBuild

        IPAddress =
            $SystemInfo.IPAddress

        Profile =
            $Profile

        SuccessCount =
            $SuccessCount

        FailedCount =
            $FailedCount

        SkippedCount =
            $SkippedCount

        Installed =
            $InstalledSummary

        Duration =
            $Duration

        PendingRebootBefore =
            $SystemInfo.PendingReboot

        RestartRequired =
            $RestartRequired

        Date =
            (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
}

# =====================================================================
# 20. GUI
# =====================================================================

$form = New-Object System.Windows.Forms.Form

$form.Text =
    "Hachihi Deployment Tool v3.2"

$form.Size =
    New-Object System.Drawing.Size(620, 680)

$form.StartPosition =
    "CenterScreen"

$form.FormBorderStyle =
    "FixedDialog"

$form.MaximizeBox =
    $false

$form.MinimizeBox =
    $true

$form.BackColor =
    [System.Drawing.Color]::FromArgb(
        245,
        246,
        248
    )

# =====================================================================
# HEADER
# =====================================================================

$panelHeader =
    New-Object System.Windows.Forms.Panel

$panelHeader.Location =
    New-Object System.Drawing.Point(0, 0)

$panelHeader.Size =
    New-Object System.Drawing.Size(620, 65)

$panelHeader.BackColor =
    [System.Drawing.Color]::FromArgb(
        0,
        120,
        215
    )

$form.Controls.Add(
    $panelHeader
)

$lblTitle =
    New-Object System.Windows.Forms.Label

$lblTitle.Location =
    New-Object System.Drawing.Point(20, 12)

$lblTitle.Size =
    New-Object System.Drawing.Size(570, 30)

$lblTitle.Text =
    "HACHIHI TECH - TRIỂN KHAI MÁY WINDOWS MỚI"

$lblTitle.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        11,
        [System.Drawing.FontStyle]::Bold
    )

$lblTitle.ForeColor =
    [System.Drawing.Color]::White

$panelHeader.Controls.Add(
    $lblTitle
)

$lblVersion =
    New-Object System.Windows.Forms.Label

$lblVersion.Location =
    New-Object System.Drawing.Point(20, 40)

$lblVersion.Size =
    New-Object System.Drawing.Size(570, 20)

$lblVersion.Text =
    "Deployment Tool v3.2"

$lblVersion.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        8
    )

$lblVersion.ForeColor =
    [System.Drawing.Color]::White

$panelHeader.Controls.Add(
    $lblVersion
)

# =====================================================================
# PC NAME
# =====================================================================

$lblPC =
    New-Object System.Windows.Forms.Label

$lblPC.Location =
    New-Object System.Drawing.Point(20, 80)

$lblPC.Size =
    New-Object System.Drawing.Size(250, 20)

$lblPC.Text =
    "Tên máy tính:"

$lblPC.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        9,
        [System.Drawing.FontStyle]::Bold
    )

$form.Controls.Add(
    $lblPC
)

$txtPCName =
    New-Object System.Windows.Forms.TextBox

$txtPCName.Location =
    New-Object System.Drawing.Point(20, 102)

$txtPCName.Size =
    New-Object System.Drawing.Size(250, 25)

$txtPCName.Text =
    $env:COMPUTERNAME

$form.Controls.Add(
    $txtPCName
)

# =====================================================================
# PROFILE
# =====================================================================

$lblProfile =
    New-Object System.Windows.Forms.Label

$lblProfile.Location =
    New-Object System.Drawing.Point(320, 80)

$lblProfile.Size =
    New-Object System.Drawing.Size(240, 20)

$lblProfile.Text =
    "Profile phòng ban:"

$lblProfile.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        9,
        [System.Drawing.FontStyle]::Bold
    )

$form.Controls.Add(
    $lblProfile
)

$cmbProfile =
    New-Object System.Windows.Forms.ComboBox

$cmbProfile.Location =
    New-Object System.Drawing.Point(320, 102)

$cmbProfile.Size =
    New-Object System.Drawing.Size(250, 25)

$cmbProfile.DropDownStyle =
    [System.Windows.Forms.ComboBoxStyle]::DropDownList

$form.Controls.Add(
    $cmbProfile
)

# =====================================================================
# APP CHECKLIST
# =====================================================================

$lblApps =
    New-Object System.Windows.Forms.Label

$lblApps.Location =
    New-Object System.Drawing.Point(20, 135)

$lblApps.Size =
    New-Object System.Drawing.Size(540, 20)

$lblApps.Text =
    "Danh sách phần mềm:"

$lblApps.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        9,
        [System.Drawing.FontStyle]::Bold
    )

$form.Controls.Add(
    $lblApps
)

$checkedListBox =
    New-Object System.Windows.Forms.CheckedListBox

$checkedListBox.Location =
    New-Object System.Drawing.Point(20, 158)

$checkedListBox.Size =
    New-Object System.Drawing.Size(550, 190)

$checkedListBox.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        9
    )

$checkedListBox.CheckOnClick =
    $true

$form.Controls.Add(
    $checkedListBox
)

# =====================================================================
# SELECT ALL
# =====================================================================

$btnSelectAll =
    New-Object System.Windows.Forms.Button

$btnSelectAll.Location =
    New-Object System.Drawing.Point(20, 355)

$btnSelectAll.Size =
    New-Object System.Drawing.Size(110, 30)

$btnSelectAll.Text =
    "Chọn tất cả"

$form.Controls.Add(
    $btnSelectAll
)

$btnUnselectAll =
    New-Object System.Windows.Forms.Button

$btnUnselectAll.Location =
    New-Object System.Drawing.Point(140, 355)

$btnUnselectAll.Size =
    New-Object System.Drawing.Size(110, 30)

$btnUnselectAll.Text =
    "Bỏ chọn"

$form.Controls.Add(
    $btnUnselectAll
)

# =====================================================================
# RESTART
# =====================================================================

$chkRestart =
    New-Object System.Windows.Forms.CheckBox

$chkRestart.Location =
    New-Object System.Drawing.Point(300, 358)

$chkRestart.Size =
    New-Object System.Drawing.Size(270, 25)

$chkRestart.Text =
    "Tự khởi động lại sau khi hoàn tất"

$chkRestart.Checked =
    $true

$form.Controls.Add(
    $chkRestart
)

# =====================================================================
# INSTALL BUTTON
# =====================================================================

$btnInstall =
    New-Object System.Windows.Forms.Button

$btnInstall.Location =
    New-Object System.Drawing.Point(180, 395)

$btnInstall.Size =
    New-Object System.Drawing.Size(260, 45)

$btnInstall.Text =
    "BẮT ĐẦU CÀI ĐẶT"

$btnInstall.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        10,
        [System.Drawing.FontStyle]::Bold
    )

$btnInstall.BackColor =
    [System.Drawing.Color]::FromArgb(
        0,
        120,
        215
    )

$btnInstall.ForeColor =
    [System.Drawing.Color]::White

$btnInstall.FlatStyle =
    [System.Windows.Forms.FlatStyle]::Flat

$btnInstall.FlatAppearance.BorderSize =
    0

$form.Controls.Add(
    $btnInstall
)

# =====================================================================
# PROGRESS
# =====================================================================

$progressBar =
    New-Object System.Windows.Forms.ProgressBar

$progressBar.Location =
    New-Object System.Drawing.Point(20, 450)

$progressBar.Size =
    New-Object System.Drawing.Size(550, 22)

$progressBar.Minimum =
    0

$progressBar.Maximum =
    100

$progressBar.Value =
    0

$form.Controls.Add(
    $progressBar
)

# =====================================================================
# STATUS
# =====================================================================

$lblStatus =
    New-Object System.Windows.Forms.Label

$lblStatus.Location =
    New-Object System.Drawing.Point(20, 478)

$lblStatus.Size =
    New-Object System.Drawing.Size(550, 22)

$lblStatus.Text =
    "Trạng thái: Đang khởi tạo..."

$lblStatus.ForeColor =
    [System.Drawing.Color]::DarkBlue

$form.Controls.Add(
    $lblStatus
)

# =====================================================================
# LOG
# =====================================================================

$txtLog =
    New-Object System.Windows.Forms.TextBox

$txtLog.Location =
    New-Object System.Drawing.Point(20, 505)

$txtLog.Size =
    New-Object System.Drawing.Size(550, 125)

$txtLog.Multiline =
    $true

$txtLog.ReadOnly =
    $true

$txtLog.ScrollBars =
    [System.Windows.Forms.ScrollBars]::Vertical

$txtLog.BackColor =
    [System.Drawing.Color]::Black

$txtLog.ForeColor =
    [System.Drawing.Color]::LightGreen

$txtLog.Font =
    New-Object System.Drawing.Font(
        "Consolas",
        8.5
    )

$form.Controls.Add(
    $txtLog
)

$global:txtLogControl =
    $txtLog

# =====================================================================
# SELECT ALL EVENTS
# =====================================================================

$btnSelectAll.Add_Click({

    for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {

        $checkedListBox.SetItemChecked(
            $i,
            $true
        )
    }
})

$btnUnselectAll.Add_Click({

    for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {

        $checkedListBox.SetItemChecked(
            $i,
            $false
        )
    }
})

# =====================================================================
# PROFILE EVENT
# =====================================================================

$cmbProfile.Add_SelectedIndexChanged({

    RefreshAppChecklist
})

# =====================================================================
# FORM LOAD
# =====================================================================

$form.Add_Load({

    Write-HachihiLog `
        "========================================" `
        "INIT"

    Write-HachihiLog `
        "HACHIHI DEPLOYMENT TOOL v3.2" `
        "INIT"

    Write-HachihiLog `
        "Computer: $env:COMPUTERNAME" `
        "INIT"

    Write-HachihiLog `
        "Đang kiểm tra Internet..." `
        "INIT"

    if (-not (Test-HachihiInternet)) {

        Write-HachihiLog `
            "Không có kết nối Internet." `
            "ERROR"

        $lblStatus.Text =
            "Trạng thái: Không có Internet"

        $lblStatus.ForeColor =
            [System.Drawing.Color]::Red

        $btnInstall.Enabled =
            $false

        return
    }

    Write-HachihiLog `
        "Internet: OK" `
        "SUCCESS"

    # -------------------------------------------------------------
    # WINGET
    # -------------------------------------------------------------

    Write-HachihiLog `
        "Đang kiểm tra Winget..." `
        "WINGET"

    if (-not (Test-HachihiWinget)) {

        $lblStatus.Text =
            "Trạng thái: Không có Winget"

        $lblStatus.ForeColor =
            [System.Drawing.Color]::Red

        [System.Windows.Forms.MessageBox]::Show(
            "Máy này không tìm thấy Winget.`r`n`r`n" +
            "Vui lòng cập nhật App Installer / Windows trước khi chạy Deployment Tool.",
            "Thiếu Winget",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )

        $btnInstall.Enabled =
            $false

        return
    }

    Initialize-HachihiWinget

    # -------------------------------------------------------------
    # CONFIG
    # -------------------------------------------------------------

    if (-not (Get-HachihiConfig)) {

        $lblStatus.Text =
            "Trạng thái: Không tải được apps.json"

        $lblStatus.ForeColor =
            [System.Drawing.Color]::Red

        [System.Windows.Forms.MessageBox]::Show(
            "Không thể tải apps.json từ GitHub.`r`n`r`n" +
            "Kiểm tra lại configUrl và Internet.",
            "Lỗi cấu hình",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )

        $btnInstall.Enabled =
            $false

        return
    }

    # -------------------------------------------------------------
    # PROFILES
    # -------------------------------------------------------------

    foreach ($profile in $global:config.Profiles) {

        [void]$cmbProfile.Items.Add(
            [string]$profile
        )
    }

    if ($cmbProfile.Items.Count -gt 0) {

        $cmbProfile.SelectedIndex =
            0
    }

    $lblStatus.Text =
        "Trạng thái: Sẵn sàng triển khai"

    $lblStatus.ForeColor =
        [System.Drawing.Color]::DarkGreen

    Write-HachihiLog `
        "Tool đã sẵn sàng." `
        "SUCCESS"
})

# =====================================================================
# INSTALL CLICK
# =====================================================================

$btnInstall.Add_Click({

    if ($global:deploymentStarted) {
        return
    }

    if (-not $global:config) {

        [System.Windows.Forms.MessageBox]::Show(
            "Chưa tải được apps.json.",
            "Lỗi",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )

        return
    }

    # -------------------------------------------------------------
    # CONFIRM
    # -------------------------------------------------------------

    $selectedCount =
        $checkedListBox.CheckedItems.Count

    if ($selectedCount -eq 0) {

        [System.Windows.Forms.MessageBox]::Show(
            "Bạn chưa chọn phần mềm nào.",
            "HACHIHI Deployment Tool",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        return
    }

    $confirm =
        [System.Windows.Forms.MessageBox]::Show(
            "Bắt đầu triển khai máy này?`r`n`r`n" +
            "Máy: $($txtPCName.Text)`r`n" +
            "Profile: $($cmbProfile.SelectedItem)`r`n" +
            "Số mục: $selectedCount",
            "Xác nhận triển khai",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

    if ($confirm -ne
        [System.Windows.Forms.DialogResult]::Yes) {

        return
    }

    # -------------------------------------------------------------
    # LOCK UI
    # -------------------------------------------------------------

    $global:deploymentStarted =
        $true

    $btnInstall.Enabled =
        $false

    $btnSelectAll.Enabled =
        $false

    $btnUnselectAll.Enabled =
        $false

    $txtPCName.Enabled =
        $false

    $cmbProfile.Enabled =
        $false

    $checkedListBox.Enabled =
        $false

    $chkRestart.Enabled =
        $false

    $startTime =
        Get-Date

    $successCount = 0
    $failedCount = 0
    $skippedCount = 0

    $installedSummary =
        New-Object System.Collections.ArrayList

    $restartRequired =
        $false

    try {

        Write-HachihiLog `
            "========================================" `
            "START"

        Write-HachihiLog `
            "BẮT ĐẦU DEPLOYMENT" `
            "START"

        # =============================================================
        # SYSTEM INFO
        # =============================================================

        $lblStatus.Text =
            "Trạng thái: Kiểm tra hệ thống..."

        $progressBar.Value =
            5

        Write-HachihiLog `
            "Đang thu thập thông tin hệ thống..." `
            "SYSTEM"

        $sysInfo =
            Get-HachihiSystemMetrics

        Write-HachihiLog `
            "Model: $($sysInfo.Model)" `
            "SYSTEM"

        Write-HachihiLog `
            "Serial: $($sysInfo.Serial)" `
            "SYSTEM"

        Write-HachihiLog `
            "CPU: $($sysInfo.CPU)" `
            "SYSTEM"

        Write-HachihiLog `
            "RAM: $($sysInfo.RAM_GB) GB" `
            "SYSTEM"

        Write-HachihiLog `
            "Ổ C trống: $($sysInfo.FreeDiskC_GB) GB" `
            "SYSTEM"

        Write-HachihiLog `
            "IP: $($sysInfo.IPAddress)" `
            "SYSTEM"

        # =============================================================
        # DISK
        # =============================================================

        if ($sysInfo.FreeDiskC_GB -lt 5) {

            Write-HachihiLog `
                "CẢNH BÁO: Ổ C còn dưới 5GB." `
                "WARNING"
        }

        # =============================================================
        # PENDING REBOOT
        # =============================================================

        if ($sysInfo.PendingReboot) {

            Write-HachihiLog `
                "Windows đang có Pending Reboot." `
                "WARNING"
        }

        # =============================================================
        # COMPUTER NAME
        # =============================================================

        $requestedName =
            $txtPCName.Text.Trim()

        $renameResult =
            Set-HachihiComputerName `
                -NewName $requestedName

        $finalComputerName =
            $renameResult.Name

        if ($renameResult.Changed) {

            $restartRequired =
                $true
        }

        if ($renameResult.Error) {

            Write-HachihiLog `
                "Rename warning: $($renameResult.Error)" `
                "WARNING"
        }

        # =============================================================
        # WINGET
        # =============================================================

        $lblStatus.Text =
            "Trạng thái: Kiểm tra Winget..."

        $progressBar.Value =
            10

        if (-not (Test-HachihiWinget)) {

            throw "Winget không khả dụng."
        }

        Initialize-HachihiWinget

        # =============================================================
        # APP INSTALL
        # =============================================================

        $selectedIndices =
            @($checkedListBox.CheckedIndices)

        $totalSteps =
            $selectedIndices.Count

        $currentStep =
            0

        foreach ($idx in $selectedIndices) {

            $currentStep++

            $app =
                $global:config.Apps[$idx]

            if (-not $app) {

                Write-HachihiLog `
                    "Không tìm thấy app index $idx." `
                    "ERROR"

                $failedCount++

                continue
            }

            $name =
                [string]$app.Name

            $type =
                [string]$app.Type

            $percent =
                10 +
                [math]::Floor(
                    ($currentStep / $totalSteps) * 75
                )

            if ($percent -gt 85) {
                $percent = 85
            }

            $progressBar.Value =
                [int]$percent

            $lblStatus.Text =
                "Trạng thái: [$currentStep/$totalSteps] $name"

            # =========================================================
            # WINGET
            # =========================================================

            if ($type -eq "Winget") {

                $appId =
                    [string]$app.Id

                if ([string]::IsNullOrWhiteSpace($appId)) {

                    Write-HachihiLog `
                        "$name không có App ID." `
                        "ERROR"

                    $failedCount++

                    [void]$installedSummary.Add(
                        "$name: Lỗi - thiếu App ID"
                    )

                    continue
                }

                Write-HachihiLog `
                    "[$currentStep/$totalSteps] Kiểm tra $name..." `
                    "INSTALL"

                if (
                    Test-WingetAppInstalled `
                        -AppId $appId
                ) {

                    Write-HachihiLog `
                        "$name đã có sẵn. Bỏ qua cài đặt." `
                        "SKIP"

                    $skippedCount++

                    [void]$installedSummary.Add(
                        "$name: Đã có sẵn"
                    )

                    continue
                }

                $installed =
                    Install-HachihiWingetApp `
                        -Name $name `
                        -AppId $appId

                if ($installed) {

                    if (
                        Verify-HachihiApp `
                            -Name $name `
                            -AppId $appId
                    ) {

                        $successCount++

                        [void]$installedSummary.Add(
                            "$name: Thành công + Verify OK"
                        )

                    }
                    else {

                        $failedCount++

                        [void]$installedSummary.Add(
                            "$name: Cài xong nhưng Verify thất bại"
                        )
                    }

                }
                else {

                    $failedCount++

                    [void]$installedSummary.Add(
                        "$name: Cài đặt thất bại"
                    )
                }

                continue
            }

            # =========================================================
            # FONT
            # =========================================================

            if ($type -eq "Font") {

                $fontResult =
                    Install-HachihiFonts

                if ($fontResult.Success) {

                    $successCount++

                    [void]$installedSummary.Add(
                        "Font: Thêm $($fontResult.Added), Bỏ qua $($fontResult.Skipped)"
                    )
                }
                else {

                    $failedCount++

                    [void]$installedSummary.Add(
                        "Font: Thất bại"
                    )
                }

                continue
            }

            # =========================================================
            # UNKNOWN TYPE
            # =========================================================

            Write-HachihiLog `
                "Loại app không được hỗ trợ: $type ($name)" `
                "ERROR"

            $failedCount++

            [void]$installedSummary.Add(
                "$name: Loại $type không được hỗ trợ"
            )
        }

        # =============================================================
        # FINISH
        # =============================================================

        $progressBar.Value =
            90

        $lblStatus.Text =
            "Trạng thái: Đang tạo báo cáo..."

        $endTime =
            Get-Date

        $timeSpan =
            $endTime - $startTime

        $durationStr =
            "{0:D2}m:{1:D2}s" -f `
            [int]$timeSpan.TotalMinutes,
            $timeSpan.Seconds

        # =============================================================
        # REPORT
        # =============================================================

        $reportObject =
            New-HachihiReport `
                -SystemInfo $sysInfo `
                -FinalComputerName $finalComputerName `
                -Profile ([string]$cmbProfile.SelectedItem) `
                -InstalledSummary @($installedSummary) `
                -SuccessCount $successCount `
                -FailedCount $failedCount `
                -SkippedCount $skippedCount `
                -Duration $durationStr `
                -RestartRequired $restartRequired

        $reportObject |
            ConvertTo-Json -Depth 10 |
            Out-File `
                -FilePath $global:jsonPath `
                -Encoding UTF8 `
                -Force

        Write-HachihiLog `
            "Đã lưu báo cáo: $global:jsonPath" `
            "REPORT"

        # =============================================================
        # WEBHOOK
        # =============================================================

        $progressBar.Value =
            95

        Send-HachihiWebhook `
            -Report $reportObject |
            Out-Null

        # =============================================================
        # FINISH
        # =============================================================

        $progressBar.Value =
            100

        $global:deploymentFinished =
            $true

        Write-HachihiLog `
            "========================================" `
            "FINISH"

        Write-HachihiLog `
            "DEPLOYMENT HOÀN TẤT" `
            "FINISH"

        Write-HachihiLog `
            "Thành công: $successCount" `
            "FINISH"

        Write-HachihiLog `
            "Thất bại: $failedCount" `
            "FINISH"

        Write-HachihiLog `
            "Bỏ qua: $skippedCount" `
            "FINISH"

        Write-HachihiLog `
            "Thời gian: $durationStr" `
            "FINISH"

        $lblStatus.Text =
            "Trạng thái: Hoàn tất"

        if ($failedCount -eq 0) {

            $lblStatus.ForeColor =
                [System.Drawing.Color]::DarkGreen
        }
        else {

            $lblStatus.ForeColor =
                [System.Drawing.Color]::DarkOrange
        }

        # =============================================================
        # RESULT MESSAGE
        # =============================================================

        $message =
            "DEPLOYMENT HOÀN TẤT`r`n`r`n" +
            "Máy: $finalComputerName`r`n" +
            "Profile: $($cmbProfile.SelectedItem)`r`n`r`n" +
            "Thành công: $successCount`r`n" +
            "Thất bại: $failedCount`r`n" +
            "Bỏ qua: $skippedCount`r`n" +
            "Thời gian: $durationStr`r`n`r`n" +
            "Report:`r`n$global:jsonPath"

        if ($restartRequired -or $chkRestart.Checked) {

            $message +=
                "`r`n`r`nMáy sẽ khởi động lại."
        }

        $result =
            [System.Windows.Forms.MessageBox]::Show(
                $message,
                "HACHIHI Deployment Tool",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                $(if ($failedCount -eq 0) {
                    [System.Windows.Forms.MessageBoxIcon]::Information
                }
                else {
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                })
            )

        # =============================================================
        # RESTART
        # =============================================================

        if ($chkRestart.Checked) {

            Write-HachihiLog `
                "Máy sẽ khởi động lại sau 10 giây..." `
                "SYSTEM"

            for ($i = 10; $i -ge 1; $i--) {

                $lblStatus.Text =
                    "Trạng thái: Khởi động lại sau $i giây..."

                [System.Windows.Forms.Application]::DoEvents()

                Start-Sleep -Seconds 1
            }

            Restart-Computer -Force
        }
    }
    catch {

        Write-HachihiLog `
            "DEPLOYMENT EXCEPTION: $($_.Exception.Message)" `
            "ERROR"

        $lblStatus.Text =
            "Trạng thái: Có lỗi xảy ra"

        $lblStatus.ForeColor =
            [System.Drawing.Color]::Red

        [System.Windows.Forms.MessageBox]::Show(
            "Quá trình triển khai gặp lỗi:`r`n`r`n" +
            "$($_.Exception.Message)`r`n`r`n" +
            "Log:`r`n$global:logPath",
            "HACHIHI Deployment Tool",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
    finally {

        # Nếu không restart thì mở khóa UI
        if (-not $chkRestart.Checked) {

            $btnInstall.Enabled =
                $false
        }
    }
})

# =====================================================================
# CLOSE EVENT
# =====================================================================

$form.Add_FormClosing({

    if (
        $global:deploymentStarted -and
        -not $global:deploymentFinished
    ) {

        $answer =
            [System.Windows.Forms.MessageBox]::Show(
                "Deployment đang chạy.`r`n`r`nBạn có chắc muốn thoát?",
                "HACHIHI Deployment Tool",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )

        if (
            $answer -ne
            [System.Windows.Forms.DialogResult]::Yes
        ) {

            $_.Cancel =
                $true
        }
    }
})

# =====================================================================
# START
# =====================================================================

[void]$form.ShowDialog()
