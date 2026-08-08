# =====================================================================
# HACHIHI DEPLOYMENT TOOL v3.1 - LIGHT & FAST
# =====================================================================

# 1. KIỂM TRA QUYỀN ADMINISTRATOR
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# CẤU HÌNH ĐƯỜNG DẪN DỮ LIỆU
$global:hachihiDir = "C:\HachihiSoftware"
if (-not (Test-Path $global:hachihiDir)) { New-Item -ItemType Directory -Path $global:hachihiDir | Out-Null }
$global:logPath = "$global:hachihiDir\install.log"
$global:configUrl = "https://raw.githubusercontent.com/hachihi/hachihi-setup/main/apps.json"
$global:config = $null

# =====================================================================
# HÀM BỔ TRỢ HỆ THỐNG
# =====================================================================

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

function Test-WingetAppInstalled {
    param([string]$appId)
    $output = winget list --exact --id $appId --accept-source-agreements 2>$null
    return ($output -match [regex]::Escape($appId))
}

function RefreshAppChecklist {
    if (-not $global:config) { return }
    $checkedListBox.Items.Clear()
    $selectedProfile = $cmbProfile.SelectedItem
    foreach ($app in $global:config.Apps) {
        $isDefault = $app.Profiles -contains $selectedProfile
        $idx = $checkedListBox.Items.Add($app.Name)
        $checkedListBox.SetItemChecked($idx, $isDefault)
    }
}

# =====================================================================
# THIẾT LẬP GIAO DIỆN WINFORMS
# =====================================================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Hachihi Deployment Tool v3.1 Light"
$form.Size = New-Object System.Drawing.Size(600, 620)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)

# Panel Header
$panelHeader = New-Object System.Windows.Forms.Panel
$panelHeader.Size = New-Object System.Drawing.Size(600, 60)
$panelHeader.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblTitle.Size = New-Object System.Drawing.Size(550, 30)
$lblTitle.Text = "HACHIHI TECH - TRIỂN KHAI NHANH"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::White
$panelHeader.Controls.Add($lblTitle)
$form.Controls.Add($panelHeader)

# Form Controls Input
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

# Checklist phần mềm
$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Location = New-Object System.Drawing.Point(20, 135)
$checkedListBox.Size = New-Object System.Drawing.Size(540, 160)
$checkedListBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Controls.Add($checkedListBox)

# Options Checkbox (Đã bỏ Restore Point)
$chkRestart = New-Object System.Windows.Forms.CheckBox
$chkRestart.Location = New-Object System.Drawing.Point(20, 305)
$chkRestart.Size = New-Object System.Drawing.Size(300, 24)
$chkRestart.Text = "Tự khởi động lại sau khi xong"
$chkRestart.Checked = $true
$form.Controls.Add($chkRestart)

# Nút Cài đặt
$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Location = New-Object System.Drawing.Point(180, 335)
$btnInstall.Size = New-Object System.Drawing.Size(220, 40)
$btnInstall.Text = "BẮT ĐẦU CÀI ĐẶT"
$btnInstall.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnInstall.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnInstall.ForeColor = [System.Drawing.Color]::White
$btnInstall.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnInstall.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnInstall)

# Thanh Progress Bar & Terminal Log
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 385)
$progressBar.Size = New-Object System.Drawing.Size(540, 20)
$progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
$form.Controls.Add($progressBar)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20, 415)
$txtLog.Size = New-Object System.Drawing.Size(540, 150)
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtLog.BackColor = [System.Drawing.Color]::Black
$txtLog.ForeColor = [System.Drawing.Color]::LightGreen
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$form.Controls.Add($txtLog)
$global:txtLogControl = $txtLog

# =====================================================================
# EVENT HANDLING & CHƯƠNG TRÌNH CHÍNH
# =====================================================================

$form.Add_Load({
    Write-HachihiLog "Đang tải cấu hình phần mềm từ GitHub..." "INIT"
    try {
        $jsonRaw = Invoke-WebRequest -Uri $global:configUrl -TimeoutSec 10 -UseBasicParsing
        $global:config = ConvertFrom-Json $jsonRaw.Content
        
        foreach ($profile in $global:config.Profiles) {
            [void]$cmbProfile.Items.Add($profile)
        }
        if ($cmbProfile.Items.Count -gt 0) {
            $cmbProfile.SelectedIndex = 0
        }
        Write-HachihiLog "Tải cấu hình thành công!" "SUCCESS"
    } catch {
        Write-HachihiLog "Không thể tải file JSON trực tuyến." "ERROR"
    }
})

$cmbProfile.Add_SelectedIndexChanged({ RefreshAppChecklist })

$btnInstall.Add_Click({
    $btnInstall.Enabled = $false
    $txtPCName.Enabled = $false
    $cmbProfile.Enabled = $false
    $checkedListBox.Enabled = $false
    $chkRestart.Enabled = $false

    $startTime = Get-Date
    Write-HachihiLog "=== BẮT ĐẦU CÀI ĐẶT ===" "START"

    # Đổi tên máy nếu có thay đổi
    if ($txtPCName.Text.Trim() -and $txtPCName.Text.Trim() -ne $env:COMPUTERNAME) {
        Write-HachihiLog "Đang đổi tên máy thành: $($txtPCName.Text.Trim())..." "CONFIG"
        Rename-Computer -NewName $txtPCName.Text.Trim() -Force -ErrorAction SilentlyContinue
    }

    # Cập nhật nguồn Winget
    Write-HachihiLog "Đang cập nhật nguồn Winget..." "WINGET"
    winget source update | Out-Null

    # Lặp cài đặt danh sách phần mềm đã chọn
    $selectedIndices = $checkedListBox.CheckedIndices
    $totalSteps = $selectedIndices.Count
    if ($totalSteps -eq 0) { $totalSteps = 1 }
    $currentStep = 0

    foreach ($idx in $selectedIndices) {
        $currentStep++
        $app = $global:config.Apps[$idx]
        $progressBar.Value = [math]::Round(($currentStep / $totalSteps) * 100)
        
        if ($app.Type -eq "Winget") {
            Write-HachihiLog "[$currentStep/$totalSteps] Kiểm tra: $($app.Name)..." "INSTALL"
            
            if (Test-WingetAppInstalled -appId $app.Id) {
                Write-HachihiLog "-> SKIP: $($app.Name) đã có sẵn." "SKIP"
                continue
            }

            Write-HachihiLog "-> Đang cài đặt $($app.Name)..." "INSTALL"
            $p = Start-Process -FilePath "winget" -ArgumentList "install --id $($app.Id) -e --silent --accept-package-agreements --accept-source-agreements" -Wait -PassThru -NoNewWindow
            
            if ($p.ExitCode -eq 0) {
                Write-HachihiLog "-> SUCCESS: $($app.Name)" "SUCCESS"
            } else {
                Write-HachihiLog "-> ERROR: $($app.Name) (ExitCode: $($p.ExitCode))" "ERROR"
            }
        }
    }

    $endTime = Get-Date
    $timeSpan = $endTime -$startTime
    $durationStr = "{0:D2}m:{1:D2}s" -f $timeSpan.Minutes, $timeSpan.Seconds

    Write-HachihiLog "=== HOÀN TẤT TRONG $durationStr ===" "FINISH"

    if ($chkRestart.Checked) {
        Write-HachihiLog "Khởi động lại sau 5 giây..." "SYS"
        Start-Sleep -Seconds 5
        Restart-Computer -Force
    } else {
        [System.Windows.Forms.MessageBox]::Show("Cài đặt hoàn tất trong $durationStr!", "Hachihi Deployment Tool", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
})

$form.Add_FormClosing({
    if ($btnInstall.Enabled -eq $false) {
        # Đang cài đặt mà tắt form thì xác nhận
    }
})

[void]$form.ShowDialog()
