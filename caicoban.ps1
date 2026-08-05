# =====================================================================
# HACHIHI DEPLOYMENT TOOL v3.0 MASTER EDITION
# =====================================================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$global:hachihiDir = "C:\HachihiSoftware"
if (-not (Test-Path $global:hachihiDir)) { New-Item -ItemType Directory -Path $global:hachihiDir | Out-Null }
$global:logPath = "$global:hachihiDir\install.log"
$global:jsonPath = "$global:hachihiDir\install.json"
$global:configUrl = "https://raw.githubusercontent.com/haihoanggmail/caidatcoban/main/apps.json"
$global:webhookUrl = "YOUR_GOOGLE_APPS_SCRIPT_WEB_URL_HERE"

function Write-HachihiLog {
    param([string]$message, [string]$type = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$type] $message"
    Out-File -FilePath $global:logPath -InputObject $logLine -Append -Encoding utf8
    if ($global:txtLogControl) {
        $global:txtLogControl.AppendText("$logLine`r`n")
        $global:txtLogControl.SelectionStart = $global:txtLogControl.Text.Length
        $global:txtLogControl.ScrollToCaret()
    }
    [System.Windows.Forms.Application]::DoEvents()
}


function Test-WindowsPendingReboot {
    $cbs = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue
    $wu = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue
    return ($null -ne $cbs -or $null -ne $wu)
}

function Get-HachihiSystemMetrics {
    $cs = Get-CimInstance Win32_ComputerSystem
    $proc = Get-CimInstance Win32_Processor
    $os = Get-CimInstance Win32_OperatingSystem
    $bios = Get-CimInstance Win32_BIOS
    $driveC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $ip = (Find-NetRoute -RemoteIPAddress 8.8.8.8 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IPAddress) -join ", "

    return @{
        ComputerName   = $env:COMPUTERNAME
        Model          = $cs.Model.Trim()
        Serial         = $bios.SerialNumber.Trim()
        CPU            = $proc.Name.Trim()
        RAM_GB         = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        FreeDiskC_GB   = [math]::Round($driveC.FreeSpace / 1GB, 1)
        OSVersion      = $os.Caption.Trim()
        IPAddress      = $ip
        PendingReboot  = (Test-WindowsPendingReboot)
    }
}

function Test-WingetAppInstalled {
    param([string]$appId)
    $output = winget list --exact --id $appId --accept-source-agreements 2>$null
    return ($output -match [regex]::Escape($appId))
}

# GIAO DIỆN WINFORMS
$form = New-Object System.Windows.Forms.Form
$form.Text = "Hachihi Deployment Tool v3.0 Master"
$form.Size = New-Object System.Drawing.Size(600, 680)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)

$panelHeader = New-Object System.Windows.Forms.Panel
$panelHeader.Size = New-Object System.Drawing.Size(600, 60)
$panelHeader.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblTitle.Size = New-Object System.Drawing.Size(550, 30)
$lblTitle.Text = "HACHIHI TECH - TỰ ĐỘNG HÓA TRIỂN KHAI MÁY MỚI"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::White
$panelHeader.Controls.Add($lblTitle)
$form.Controls.Add($panelHeader)

$lblPC = New-Object System.Windows.Forms.Label
$lblPC.Location = New-Object System.Drawing.Point(20, 75)
$lblPC.Text = "Tên máy tính:"
$lblPC.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblPC)

$txtPCName = New-Object System.Windows.Forms.TextBox
$txtPCName.Location = New-Object System.Drawing.Point(20, 95)
$txtPCName.Size = New-Object System.Drawing.Size(250, 25)
$txtPCName.Text = $env:COMPUTERNAME
$form.Controls.Add($txtPCName)

$lblProfile = New-Object System.Windows.Forms.Label
$lblProfile.Location = New-Object System.Drawing.Point(300, 75)
$lblProfile.Text = "Profile Phòng ban:"
$lblProfile.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblProfile)

$cmbProfile = New-Object System.Windows.Forms.ComboBox
$cmbProfile.Location = New-Object System.Drawing.Point(300, 95)
$cmbProfile.Size = New-Object System.Drawing.Size(260, 25)
$cmbProfile.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$form.Controls.Add($cmbProfile)

$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Location = New-Object System.Drawing.Point(20, 135)
$checkedListBox.Size = New-Object System.Drawing.Size(540, 180)
$checkedListBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Controls.Add($checkedListBox)

$chkRestore = New-Object System.Windows.Forms.CheckBox
$chkRestore.Location = New-Object System.Drawing.Point(20, 325)
$chkRestore.Size = New-Object System.Drawing.Size(250, 24)
$chkRestore.Text = "Tạo Restore Point hệ thống"
$chkRestore.Checked = $true
$form.Controls.Add($chkRestore)

$chkRestart = New-Object System.Windows.Forms.CheckBox
$chkRestart.Location = New-Object System.Drawing.Point(300, 325)
$chkRestart.Size = New-Object System.Drawing.Size(250, 24)
$chkRestart.Text = "Tự khởi động lại sau khi xong"
$form.Controls.Add($chkRestart)

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Location = New-Object System.Drawing.Point(180, 360)
$btnInstall.Size = New-Object System.Drawing.Size(220, 40)
$btnInstall.Text = "BẮT ĐẦU CÀI ĐẶT v3.0"
$btnInstall.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnInstall.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnInstall.ForeColor = [System.Drawing.Color]::White
$btnInstall.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnInstall.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnInstall)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 415)
$progressBar.Size = New-Object System.Drawing.Size(540, 20)
$progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
$form.Controls.Add($progressBar)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20, 445)
$txtLog.Size = New-Object System.Drawing.Size(540, 180)
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtLog.BackColor = [System.Drawing.Color]::Black
$txtLog.ForeColor = [System.Drawing.Color]::LightGreen
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$form.Controls.Add($txtLog)
$global:txtLogControl = $txtLog

function RefreshAppChecklist {
    $checkedListBox.Items.Clear()
    $selectedProfile = $cmbProfile.SelectedItem
    foreach ($app in $global:config.Apps) {
        $isDefault = $app.Profiles -contains $selectedProfile
        $idx = $checkedListBox.Items.Add($app.Name)
        $checkedListBox.SetItemChecked($idx, $isDefault)
    }
}

$form.Add_Load({

    try {
        $jsonRaw = Invoke-WebRequest -Uri $global:configUrl -TimeoutSec 10 -UseBasicParsing
        $global:config = ConvertFrom-Json $jsonRaw.Content
        foreach ($profile in $global:config.Profiles) {
            [void]$cmbProfile.Items.Add($profile)
        }
        $cmbProfile.SelectedIndex = 0
        RefreshAppChecklist
        Write-HachihiLog "Tải thành công cấu hình v$($global:config.Version)" "SUCCESS"
    } catch {
        Write-HachihiLog "Không thể tải file JSON cấu hình." "ERROR"
    }
})

$cmbProfile.Add_SelectedIndexChanged({ RefreshAppChecklist })

$btnInstall.Add_Click({
    $btnInstall.Enabled = $false
    $txtPCName.Enabled = $false
    $cmbProfile.Enabled = $false
    $checkedListBox.Enabled = $false
    $chkRestore.Enabled = $false
    $chkRestart.Enabled = $false

    $startTime = Get-Date
    Write-HachihiLog "=== BẮT ĐẦU TRIỂN KHAI HỆ THỐNG ===" "START"

    $sysInfo = Get-HachihiSystemMetrics
    if ($txtPCName.Text.Trim() -and $txtPCName.Text.Trim() -ne $env:COMPUTERNAME) {
        Rename-Computer -NewName $txtPCName.Text.Trim() -Force -ErrorAction SilentlyContinue
    }

    if ($chkRestore.Checked) {
        try {
            Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description "Hachihi_v3_Setup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
        } catch {}
    }

    winget source update | Out-Null

    $selectedIndices = $checkedListBox.CheckedIndices
    $totalSteps = $selectedIndices.Count
    $currentStep = 0
    $installedSummary = @()

    foreach ($idx in $selectedIndices) {
        $currentStep++
        $app = $global:config.Apps[$idx]
        $progressBar.Value = [math]::Round(($currentStep / $totalSteps) * 100)
        
        if ($app.Type -eq "Winget") {
            Write-HachihiLog "[$currentStep/$totalSteps] Kiểm tra: $($app.Name)..." "INSTALL"
            if (Test-WingetAppInstalled -appId $app.Id) {
                Write-HachihiLog "-> SKIP: $($app.Name) đã có sẵn." "SKIP"
                $installedSummary += "$($app.Name): Đã có sẵn"
                continue
            }
            $p = Start-Process -FilePath "winget" -ArgumentList "install --id $($app.Id) -e --silent --accept-package-agreements --accept-source-agreements" -Wait -PassThru -NoNewWindow
            if ($p.ExitCode -eq 0) {
                Write-HachihiLog "-> SUCCESS: Cài xong $($app.Name)" "SUCCESS"
                $installedSummary += "$($app.Name): Thành công"
            } else {
                Write-HachihiLog "-> ERROR: Lỗi cài $($app.Name)" "ERROR"
                $installedSummary += "$($app.Name): Thất bại"
            }
        }

        if ($app.Type -eq "Font") {
            Write-HachihiLog "[$currentStep/$totalSteps] Đang cài bộ Font chữ..." "FONT"
            $tempDir = "$env:TEMP\HachihiFonts"
            if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
            New-Item -ItemType Directory -Path $tempDir | Out-Null
            $zipPath = "$tempDir\fonts.zip"
            $extractPath = "$tempDir\extracted"

            try {
                Invoke-WebRequest -Uri $global:config.FontUrl -OutFile $zipPath -TimeoutSec 30 -ErrorAction Stop
                Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
                $fontFiles = Get-ChildItem $extractPath -Recurse -Include *.ttf, *.otf
                $winFontDir = "$env:SystemRoot\Fonts"
                $fCount = 0

                foreach ($font in $fontFiles) {
                    $targetPath = Join-Path $winFontDir $font.Name
                    if (-not (Test-Path $targetPath)) {
                        Copy-Item $font.FullName -Destination $winFontDir -Force
                        $regName = "$($font.BaseName) (TrueType)"
                        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -Name $regName -Value $font.Name -PropertyType String -Force | Out-Null
                        $fCount++
                    }
                }
                Write-HachihiLog "-> SUCCESS: Đã cài $fCount Font mới!" "SUCCESS"
                $installedSummary += "Hệ thống Font: $fCount font mới"
            } catch {
                Write-HachihiLog "-> ERROR: Lỗi cài Font chữ." "ERROR"
            }
            if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
        }
    }

    $endTime = Get-Date
    $timeSpan = $endTime - $startTime
    $durationStr = "{0:D2}m:{1:D2}s" -f $timeSpan.Minutes, $timeSpan.Seconds
    Write-HachihiLog "=== HOÀN TẤT TRONG $durationStr ===" "FINISH"

    if ($chkRestart.Checked) {
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    } else {
        [System.Windows.Forms.MessageBox]::Show("Hoàn tất thiết lập trong $durationStr!", "Hachihi Tool", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        Start-Process "diskmgmt.msc"
    }
})

[void]$form.ShowDialog()
