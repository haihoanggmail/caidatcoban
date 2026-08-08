# =====================================================================
# HACHIHI DEPLOYMENT TOOL v3.1 (NO RESTORE POINT - ENHANCED CHECK)
# Enterprise-Grade One-Click Automated Setup System
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
$global:jsonPath = "$global:hachihiDir\install.json"
$global:configUrl = "https://raw.githubusercontent.com/hachihi/hachihi-setup/main/apps.json" # Link config JSON của bạn
$global:webhookUrl = "YOUR_GOOGLE_APPS_SCRIPT_WEB_URL_HERE" # Link Apps Script của bạn
$global:config = $null

# =====================================================================
# HÀM BỔ TRỢ HỆ THỐNG (SYSTEM UTILITY FUNCTIONS)
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


function Test-HachihiInternet {
    try {
        $res = Invoke-WebRequest -Uri "https://www.msftconnecttest.com/connecttest.txt" -TimeoutSec 4 -UseBasicParsing -ErrorAction Stop
        return ($res.StatusCode -eq 200)
    } catch {
        return $false
    }
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
# THIẾT LẬP GIAO DIỆN WINFORMS (SINGLE-WINDOW PROGRESS UI)
# =====================================================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Hachihi Deployment Tool v3.1"
$form.Size = New-Object System.Drawing.Size(600, 650)
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
$lblTitle.Text = "HACHIHI TECH - TỰ ĐỘNG HÓA TRIỂN KHAI MÁY MỚI"
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
$checkedListBox.Size = New-Object System.Drawing.Size(540, 180)
$checkedListBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Controls.Add($checkedListBox)

# Options Checkbox (Đã bỏ Restore Point, chỉ giữ lại Tự khởi động lại)
$chkRestart = New-Object System.Windows.Forms.CheckBox
$chkRestart.Location = New-Object System.Drawing.Point(20, 325)
$chkRestart.Size = New-Object System.Drawing.Size(300, 24)
$chkRestart.Text = "Tự khởi động lại sau khi hoàn tất"
$chkRestart.Checked = $true
$form.Controls.Add($chkRestart)

# Nút Cài đặt
$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Location = New-Object System.Drawing.Point(180, 355)
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
$progressBar.Location = New-Object System.Drawing.Point(20, 405)
$progressBar.Size = New-Object System.Drawing.Size(540, 20)
$progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
$form.Controls.Add($progressBar)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20, 435)
$txtLog.Size = New-Object System.Drawing.Size(540, 170)
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
    Write-HachihiLog "Đang kết nối kiểm tra Internet..." "INIT"
    if (-not (Test-HachihiInternet)) {
        [System.Windows.Forms.MessageBox]::Show("Không thể kết nối Internet. Vui lòng kiểm tra lại mạng!", "Lỗi Kết Nối", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $form.Close()
        return
    }

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
        Write-HachihiLog "Đã tải thành công cấu hình v$($global:config.Version)" "SUCCESS"
    } catch {
        Write-HachihiLog "Không thể lấy file JSON trực tuyến. Vui lòng kiểm tra cấu hình URL." "ERROR"
    }
})

$cmbProfile.Add_SelectedIndexChanged({ RefreshAppChecklist })

# TIẾN HÀNH THỰC THI (MAIN PROCESS)
$btnInstall.Add_Click({
    # Khóa UI
    $btnInstall.Enabled = $false
    $txtPCName.Enabled = $false
    $cmbProfile.Enabled = $false
    $checkedListBox.Enabled = $false
    $chkRestart.Enabled = $false

    $startTime = Get-Date
    Write-HachihiLog "=== BẮT ĐẦU TRIỂN KHAI HỆ THỐNG ===" "START"

    # 1. Kiểm tra dung lượng đĩa C và trạng thái hệ thống
    $sysInfo = Get-HachihiSystemMetrics
    Write-HachihiLog "Cấu hình: CPU: $($sysInfo.CPU) | RAM: $($sysInfo.RAM_GB)GB | Ổ C Trống: $($sysInfo.FreeDiskC_GB)GB" "SYS"
    
    if ($sysInfo.FreeDiskC_GB -lt 5) {
        Write-HachihiLog "CẢNH BÁO: Dung lượng ổ C khả dụng nhỏ hơn 5GB!" "WARNING"
    }

    if ($sysInfo.PendingReboot) {
        Write-HachihiLog "CẢNH BÁO: Windows đang trong trạng thái chờ Khởi động lại (Pending Reboot)." "WARNING"
    }

    # 2. Đổi tên máy nếu có sửa
    if ($txtPCName.Text.Trim() -and $txtPCName.Text.Trim() -ne $env:COMPUTERNAME) {
        Write-HachihiLog "Đang đổi tên máy thành: $($txtPCName.Text.Trim())..." "CONFIG"
        Rename-Computer -NewName $txtPCName.Text.Trim() -Force -ErrorAction SilentlyContinue
    }

    # 3. Winget Update Sources
    Write-HachihiLog "Đang cập nhật danh mục nguồn Winget..." "WINGET"
    winget source update | Out-Null

    # 4. Lặp cài đặt danh sách phần mềm đã chọn
    $selectedIndices = $checkedListBox.CheckedIndices
    $totalSteps = $selectedIndices.Count
    if ($totalSteps -eq 0) { $totalSteps = 1 }
    $currentStep = 0

    $installedSummary = @()

    foreach ($idx in $selectedIndices) {
        $currentStep++
        $app = $global:config.Apps[$idx]
        $progressBar.Value = [math]::Round(($currentStep / $totalSteps) * 100)
        
        if ($app.Type -eq "Winget") {
            Write-HachihiLog "[$currentStep/$totalSteps] Kiểm tra phần mềm: $($app.Name)..." "INSTALL"
            
            # Kiểm tra nếu đã cài đặt -> Bỏ qua và thông báo ra màn hình log
            if (Test-WingetAppInstalled -appId $app.Id) {
                Write-HachihiLog "-> THÔNG BÁO: $($app.Name) đã có sẵn trên máy. Bỏ qua bước cài đặt." "SKIP"
                $installedSummary += "$($app.Name): Đã có sẵn"
                continue
            }

            Write-HachihiLog "-> Đang tải & cài đặt $($app.Name)..." "INSTALL"
            $p = Start-Process -FilePath "winget" -ArgumentList "install --id $($app.Id) -e --silent --accept-package-agreements --accept-source-agreements" -Wait -PassThru -NoNewWindow
            
            if ($p.ExitCode -eq 0) {
                Write-HachihiLog "-> SUCCESS: Cài đặt thành công $($app.Name)!" "SUCCESS"
                $installedSummary += "$($app.Name): Thành công"
            } else {
                Write-HachihiLog "-> ERROR: Không thể cài đặt $($app.Name) (ExitCode: $($p.ExitCode))" "ERROR"
                $installedSummary += "$($app.Name): Thất bại"
            }
        }

        if ($app.Type -eq "Font") {
            Write-HachihiLog "[$currentStep/$totalSteps] Đang xử lý bộ Font chữ tiêu chuẩn..." "FONT"
            $tempDir = "$env:TEMP\HachihiFonts"
            if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
            New-Item -ItemType Directory -Path $tempDir | Out-Null
            
            $zipPath = "$tempDir\fonts.zip"
            $extractPath = "$tempDir\extracted"

            try {
                Invoke-WebRequest -Uri $global:config.FontUrl -OutFile $zipPath -TimeoutSec 30 -ErrorAction Stop
                
                if ($global:config.FontHashSHA256) {
                    $fileHash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
                    if ($fileHash -ne $global:config.FontHashSHA256) {
                        Write-HachihiLog "CẢNH BÁO: SHA256 Hash file Font không khớp! Hủy cài Font." "ERROR"
                        continue
                    }
                }

                Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
                $fontFiles = Get-ChildItem $extractPath -Recurse -Include *.ttf, *.otf
                $winFontDir = "$env:SystemRoot\Fonts"
                $fCount = 0
                $fSkipped = 0

                foreach ($font in $fontFiles) {
                    $targetPath = Join-Path $winFontDir $font.Name
                    if (-not (Test-Path $targetPath)) {
                        Copy-Item $font.FullName -Destination $winFontDir -Force
                        $regName = "$($font.BaseName) (TrueType)"
                        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -Name $regName -Value $font.Name -PropertyType String -Force | Out-Null
                        $fCount++
                    } else {
                        Write-HachihiLog "-> THÔNG BÁO: Font [$($font.Name)] đã có sẵn trên máy. Bỏ qua." "SKIP"
                        $fSkipped++
                    }
                }
                Write-HachihiLog "-> SUCCESS: Đã thêm mới $fCount font, bỏ qua $fSkipped font đã có sẵn." "SUCCESS"
                $installedSummary += "Hệ thống Font: Thêm $fCount, Bỏ qua $fSkipped"
            } catch {
                Write-HachihiLog "-> ERROR: Lỗi trong quá trình xử lý Font chữ." "ERROR"
            }
            if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
        }
    }

    # 5. Tổng kết thời gian & Xuất file Báo cáo
    $endTime = Get-Date
    $timeSpan = $endTime - $startTime
    $durationStr = "{0:D2}m:{1:D2}s" -f $timeSpan.Minutes, $timeSpan.Seconds

    Write-HachihiLog "=== HOÀN TẤT SETUP TRONG $durationStr ===" "FINISH"

    $reportObject = @{
        ComputerName = $env:COMPUTERNAME
        Model        = $sysInfo.Model
        Serial       = $sysInfo.Serial
        CPU          = $sysInfo.CPU
        RAM_GB       = $sysInfo.RAM_GB
        FreeDiskC_GB = $sysInfo.FreeDiskC_GB
        OSVersion    = $sysInfo.OSVersion
        IPAddress    = $sysInfo.IPAddress
        Profile      = $cmbProfile.SelectedItem
        Installed    = $installedSummary
        Duration     = $durationStr
        Date         = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    $reportObject | ConvertTo-Json -Depth 3 | Out-File -FilePath $global:jsonPath -Encoding utf8

    # 6. Gửi telemetry lên Google Sheets Webhook
    if ($global:webhookUrl -and $global:webhookUrl -ne "YOUR_GOOGLE_APPS_SCRIPT_WEB_URL_HERE") {
        Write-HachihiLog "Đang đồng bộ báo cáo về Google Sheets / ERP..." "WEBHOOK"
        try {
            $bodyJson = $reportObject | ConvertTo-Json -Depth 3
            Invoke-RestMethod -Uri $global:webhookUrl -Method Post -Body $bodyJson -ContentType "application/json" -TimeoutSec 10 -ErrorAction SilentlyContinue | Out-Null
            Write-HachihiLog "Đã gửi dữ liệu thành công!" "SUCCESS"
        } catch {
            Write-HachihiLog "Không thể gửi dữ liệu lên Google Sheets Webhook." "WARNING"
        }
    }

    # 7. Xử lý Sau khi hoàn tất
    if ($chkRestart.Checked) {
        Write-HachihiLog "Máy tính sẽ khởi động lại sau 10 giây..." "SYS"
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    } else {
        [System.Windows.Forms.MessageBox]::Show("Quá trình thiết lập hoàn tất xuất sắc trong $durationStr!", "Hachihi Deployment Tool", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
})

# Chạy hiển thị Form
[void]$form.ShowDialog()
