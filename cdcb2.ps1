# =====================================================================
# HACHIHI DEPLOYMENT TOOL v3.2 - MODERN TABBED EDITION
# =====================================================================

# 1. KIỂM TRA QUYỀN ADMINISTRATOR
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# CẤU HÌNH ĐƯỜNG DẪN
$global:hachihiDir = "C:\HachihiSoftware"
if (-not (Test-Path $global:hachihiDir)) { New-Item -ItemType Directory -Path $global:hachihiDir | Out-Null }
$global:logPath = "$global:hachihiDir\install.log"
$global:configUrl = "https://raw.githubusercontent.com/haihoanggmail/caidatcoban/main/apps.json"
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
# THIẾT LẬP GIAO DIỆN WINFORMS HIỆN ĐẠI (TAB CONTROL)
# =====================================================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Hachihi Deployment Tool v3.2 Pro"
$form.Size = New-Object System.Drawing.Size(630, 640)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)

# Tạo TabControl chính
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(12, 12)
$tabControl.Size = New-Object System.Drawing.Size(590, 575)
$tabControl.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Medium)
$form.Controls.Add($tabControl)

# --- TAB 1: TRIỂN KHAI NHANH ---
$tabInstall = New-Object System.Windows.Forms.TabPage
$tabInstall.Text = "  🚀 Triển Khai Nhanh  "
$tabInstall.BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)
$tabControl.Controls.Add($tabInstall)

# Header Banner trong Tab 1
$panelHeader = New-Object System.Windows.Forms.Panel
$panelHeader.Location = New-Object System.Drawing.Point(10, 10)
$panelHeader.Size = New-Object System.Drawing.Size(562, 50)
$panelHeader.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Location = New-Object System.Drawing.Point(15, 14)
$lblTitle.Size = New-Object System.Drawing.Size(530, 25)
$lblTitle.Text = "HACHIHI TECH - AUTOMATED DEPLOYMENT"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10.5, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::White
$panelHeader.Controls.Add($lblTitle)
$tabInstall.Controls.Add($panelHeader)

# Inputs
voicesPC = New-Object System.Windows.Forms.Label
$lblPC = New-Object System.Windows.Forms.Label
$lblPC.Location = New-Object System.Drawing.Point(10, 70)
$lblPC.Size = New-Object System.Drawing.Size(150, 20)
$lblPC.Text = "Tên máy tính:"
$lblPC.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$tabInstall.Controls.Add($lblPC)

$txtPCName = New-Object System.Windows.Forms.TextBox
$txtPCName.Location = New-Object System.Drawing.Point(10, 92)
$txtPCName.Size = New-Object System.Drawing.Size(265, 25)
$txtPCName.Text = $env:COMPUTERNAME
$tabInstall.Controls.Add($txtPCName)

$lblProfile = New-Object System.Windows.Forms.Label
$lblProfile.Location = New-Object System.Drawing.Point(295, 70)
$lblProfile.Size = New-Object System.Drawing.Size(150, 20)
$lblProfile.Text = "Profile Phòng ban:"
$lblProfile.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$tabInstall.Controls.Add($lblProfile)

$cmbProfile = New-Object System.Windows.Forms.ComboBox
$cmbProfile.Location = New-Object System.Drawing.Point(295, 92)
$cmbProfile.Size = New-Object System.Drawing.Size(277, 25)
$cmbProfile.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$tabInstall.Controls.Add($cmbProfile)

# Checklist phần mềm
$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Location = New-Object System.Drawing.Point(10, 128)
$checkedListBox.Size = New-Object System.Drawing.Size(562, 145)
$checkedListBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$tabInstall.Controls.Add($checkedListBox)

# Option Checkbox & Button
$chkRestart = New-Object System.Windows.Forms.CheckBox
$chkRestart.Location = New-Object System.Drawing.Point(10, 282)
$chkRestart.Size = New-Object System.Drawing.Size(250, 24)
$chkRestart.Text = "Tự khởi động lại sau khi xong"
$chkRestart.Checked = $true
$tabInstall.Controls.Add($chkRestart)

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Location = New-Object System.Drawing.Point(171, 312)
$btnInstall.Size = New-Object System.Drawing.Size(220, 38)
$btnInstall.Text = "BẮT ĐẦU CÀI ĐẶT"
$btnInstall.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnInstall.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnInstall.ForeColor = [System.Drawing.Color]::White
$btnInstall.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnInstall.FlatAppearance.BorderSize = 0
$tabInstall.Controls.Add($btnInstall)

# ProgressBar & Log Box
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 358)
$progressBar.Size = New-Object System.Drawing.Size(562, 18)
$progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
$tabInstall.Controls.Add($progressBar)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(10, 385)
$txtLog.Size = New-Object System.Drawing.Size(562, 145)
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
$txtLog.ForeColor = [System.Drawing.Color]::LightGreen
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$tabInstall.Controls.Add($txtLog)
$global:txtLogControl = $txtLog


# --- TAB 2: GIỚI THIỆU (ABOUT HACHIHI) ---
$tabAbout = New-Object System.Windows.Forms.TabPage
$tabAbout.Text = "  💡 Giới Thiệu Hachihi  "
$tabAbout.BackColor = [System.Drawing.Color]::White
$tabControl.Controls.Add($tabAbout)

# Vẽ Logo Hachihi tùy chỉnh (Custom Logo Canvas)
$picLogo = New-Object System.Windows.Forms.PictureBox
$picLogo.Location = New-Object System.Drawing.Point(215, 30)
$picLogo.Size = New-Object System.Drawing.Size(150, 150)
$picLogo.Add_Paint({
    param($sender, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    
    # Vẽ nền hình tròn gradient hoặc màu chủ đạo
    $brushBg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, 120, 215))
    $g.FillEllipse($brushBg, 10, 10, 130, 130)

    # Vẽ chữ H cách điệu biểu tượng Hachihi
    $penH = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 12)
    $penH.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $penH.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

    # Trụ trái chữ H
    $g.DrawLine($penH, 45, 40, 45, 110)
    # Trụ phải chữ H
    $g.DrawLine($penH, 105, 40, 105, 110)
    # Thanh ngang chữ H
    $g.DrawLine($penH, 45, 75, 105, 75)
})
$tabAbout.Controls.Add($picLogo)

# Thông tin About
$lblAboutTitle = New-Object System.Windows.Forms.Label
$lblAboutTitle.Location = New-Object System.Drawing.Point(50, 195)
$lblAboutTitle.Size = New-Object System.Drawing.Size(485, 30)
$lblAboutTitle.Text = "HACHIHI DEPLOYMENT SYSTEM v3.2"
$lblAboutTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblAboutTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblAboutTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$tabAbout.Controls.Add($lblAboutTitle)

$lblAboutDesc = New-Object System.Windows.Forms.Label
$lblAboutDesc.Location = New-Object System.Drawing.Point(50, 235)
$lblAboutDesc.Size = New-Object System.Drawing.Size(485, 200)
$lblAboutDesc.Text = "Công cụ tự động hóa triển khai phần mềm chuẩn hóa dành riêng cho hệ thống nội bộ Hachihi Tech.`n`n* Tác giả: Hoàng Huy Hải`n* Nền tảng: PowerShell & Windows Package Manager (Winget)`n* Tính năng nổi bật:`n  - Tự động cấu hình theo Profile phòng ban linh hoạt.`n  - Kiểm tra thông minh ứng dụng đã có sẵn trên máy.`n  - Giao diện trực quan, đồng bộ hóa dữ liệu nguồn qua GitHub.`n`nBản quyền thuộc về Hachihi Tech © 2026."
$lblAboutDesc.TextAlign = [System.Drawing.ContentAlignment]::TopCenter
$lblAboutDesc.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$lblAboutDesc.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
$tabAbout.Controls.Add($lblAboutDesc)


# =====================================================================
# SỰ KIỆN TẢI & CHẠY CHÍNH
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
        Write-HachihiLog "Không thể tải file JSON từ GitHub." "ERROR"
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

    if ($txtPCName.Text.Trim() -and $txtPCName.Text.Trim() -ne $env:COMPUTERNAME) {
        Write-HachihiLog "Đang đổi tên máy thành: $($txtPCName.Text.Trim())..." "CONFIG"
        Rename-Computer -NewName $txtPCName.Text.Trim() -Force -ErrorAction SilentlyContinue
    }

    Write-HachihiLog "Đang cập nhật nguồn Winget..." "WINGET"
    winget source update | Out-Null

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
    $timeSpan = $endTime - $startTime
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

[void]$form.ShowDialog()
