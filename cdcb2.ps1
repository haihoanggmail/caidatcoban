# =====================================================================
# HACHIHI DEPLOYMENT TOOL v3.2 - FULL SCRIPT
# =====================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Khởi tạo các biến toàn cục
$global:config = $null
$global:deploymentStarted = $false
$global:deploymentFinished = $false
$global:logPath = "$env:TEMP\HachihiDeploy.log"
$global:jsonPath = "$env:TEMP\HachihiDeploy_Report.json"

# =====================================================================
# 1. HÀM HỖ TRỢ LOG VÀ TIỆN ÍCH CƠ BẢN
# =====================================================================

function Write-HachihiLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    Add-Content -Path $global:logPath -Value $logLine -ErrorAction SilentlyContinue

    if ($global:txtLogControl -and !$global:txtLogControl.IsDisposed) {
        $global:txtLogControl.AppendText("$logLine`r`n")
        $global:txtLogControl.SelectionStart = $global:txtLogControl.Text.Length
        $global:txtLogControl.ScrollToCaret()
    }
}

function Test-HachihiInternet {
    try {
        $ping = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction Stop
        return $ping
    } catch {
        return $false
    }
}

function Test-HachihiWinget {
    try {
        $wingetPath = Get-Command winget -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Initialize-HachihiWinget {
    try {
        # Đồng ý các điều khoản nguồn Winget ngầm định nếu cần
        Start-Process -FilePath "winget" -ArgumentList "settings --enable BypassCertificatePolicyWarning" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    } catch {}
}

# =====================================================================
# 2. TẢI CẤU HÌNH APPS.JSON
# =====================================================================

function Get-HachihiConfig {
    param(
        [string]$ConfigUrl = "https://raw.githubusercontent.com/hachihi/deploy/main/apps.json"
    )
    Write-HachihiLog "Đang tải tệp cấu hình từ GitHub..." "CONFIG"
    try {
        $response = Invoke-RestMethod -Uri $ConfigUrl -Method Get -TimeoutSec 15 -ErrorAction Stop
        if ($response) {
            $global:config = $response
            Write-HachihiLog "Tải cấu hình thành công. Tìm thấy $($global:config.Apps.Count) phần mềm." "SUCCESS"
            return $true
        }
    } catch {
        Write-HachihiLog "Lỗi tải cấu hình: $_" "ERROR"
        # Fallback dữ liệu mẫu nếu không tải được từ mạng (dùng cho trường hợp ngoại lệ)
        $global:config = [PSCustomObject]@{
            Profiles = @("Standard", "Developer", "Design")
            Apps = @(
                [PSCustomObject]@{ Name = "Google Chrome"; Type = "Winget"; Id = "Google.Chrome"; Profile = "Standard" },
                [PSCustomObject]@{ Name = "Visual Studio Code"; Type = "Winget"; Id = "Microsoft.VisualStudioCode"; Profile = "Developer" },
                [PSCustomObject]@{ Name = "7-Zip"; Type = "Winget"; Id = "7zip.7zip"; Profile = "Standard" }
            )
        }
        Write-HachihiLog "Đã sử dụng cấu hình dự phòng cục bộ." "WARNING"
        return $true
    }
    return $false
}

# =====================================================================
# 3. KIỂM TRA HỆ THỐNG & TÊN MÁY
# =====================================================================

function Get-HachihiSystemMetrics {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $(Get-NetConnectionProfile | Select-Object -ExpandProperty InterfaceIndex) -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress

    $freeC = [math]::Round($disk.FreeSpace / 1GB, 2)
    $totalRAM = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)

    return [PSCustomObject]@{
        Model          = $cs.Model
        Serial         = (Get-CimInstance Win32_BIOS).SerialNumber
        CPU            = $cpu.Name
        RAM_GB         = $totalRAM
        FreeDiskC_GB   = $freeC
        IPAddress      = $ip
        PendingReboot  = (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") -or (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations")
    }
}

function Set-HachihiComputerName {
    param([string]$NewName)
    $currentName = $env:COMPUTERNAME
    if ([string]::IsNullOrWhiteSpace($NewName) -or $NewName -eq $currentName) {
        return [PSCustomObject]@{ Name = $currentName; Changed = $false; Error = $null }
    }
    try {
        Rename-Computer -NewName $NewName -Force -ErrorAction Stop
        Write-HachihiLog "Đã đổi tên máy từ $currentName thành $NewName. Cần khởi động lại." "SUCCESS"
        return [PSCustomObject]@{ Name = $NewName; Changed = $true; Error = $null }
    } catch {
        Write-HachihiLog "Không thể đổi tên máy: $_" "ERROR"
        return [PSCustomObject]@{ Name = $currentName; Changed = $false; Error = $_.Exception.Message }
    }
}

# =====================================================================
# 4. XỬ LÝ CÀI ĐẶT PHẦN MỀM
# =====================================================================

function Test-WingetAppInstalled {
    param([string]$AppId)
    try {
        $result = winget list --id $AppId --accept-source-agreements --exact 2>&1
        if ($result -match $AppId) {
            return $true
        }
    } catch {}
    return $false
}

function Install-HachihiWingetApp {
    param([string]$Name, [string]$AppId)
    Write-HachihiLog "Đang cài đặt $Name ($AppId)..." "INSTALL"
    try {
        $process = Start-Process -FilePath "winget" -ArgumentList "install --id $AppId --exact --silent --accept-package-agreements --accept-source-agreements" -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq -1978335189) { # Mã thành công hoặc đã cài bản mới nhất
            Write-HachihiLog "Cài đặt thành công: $Name" "SUCCESS"
            return $true
        } else {
            Write-HachihiLog "Cài đặt $Name trả về mã lỗi: $($process.ExitCode)" "ERROR"
            return $false
        }
    } catch {
        Write-HachihiLog "Lỗi ngoại lệ khi cài $Name : $_" "ERROR"
        return $false
    }
}

function Verify-HachihiApp {
    param([string]$Name, [string]$AppId)
    $installed = Test-WingetAppInstalled -AppId $AppId
    if ($installed) {
        Write-HachihiLog "Xác thực thành công: $Name đã có trên hệ thống." "SUCCESS"
        return $true
    }
    Write-HachihiLog "Xác thực thất bại: Không tìm thấy $Name sau khi cài." "WARNING"
    return $false
}

function Install-HachihiFonts {
    return [PSCustomObject]@{ Success = $true; Added = 0; Skipped = 0 }
}

# =====================================================================
# 5. BÁO CÁO & WEBHOOK
# =====================================================================

function New-HachihiReport {
    param(
        $SystemInfo,
        [string]$FinalComputerName,
        [string]$Profile,
        [array]$InstalledSummary,
        [int]$SuccessCount,
        [int]$FailedCount,
        [int]$SkippedCount,
        [string]$Duration,
        [bool]$RestartRequired
    )
    return [PSCustomObject]@{
        Timestamp         = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        ComputerName      = $FinalComputerName
        Profile           = $Profile
        SystemInfo        = $SystemInfo
        Summary           = @{
            Success = $SuccessCount
            Failed  = $FailedCount
            Skipped = $SkippedCount
            Duration = $Duration
        }
        Details           = $InstalledSummary
        RestartRequired   = $RestartRequired
    }
}

function Send-HachihiWebhook {
    param($Report)
    # Tùy chọn tích hợp Webhook (Teams/Slack/Discord) nếu cần
    return $true
}

# =====================================================================
# 6. GIAO DIỆN NGƯỜI DÙNG (GUI)
# =====================================================================

function RefreshAppChecklist {
    $checkedListBox.Items.Clear()
    if (-not $global:config -or -not $global:config.Apps) { return }

    $selectedProfile = $cmbProfile.SelectedItem.ToString()

    foreach ($app in $global:config.Apps) {
        # Nếu app không phân định profile hoặc khớp với profile đang chọn thì hiển thị
        if (-not $app.Profile || $app.Profile -eq $selectedProfile || $selectedProfile -eq "All") {
            $index = $checkedListBox.Items.Add($app.Name)
            # Mặc định tích chọn các ứng dụng
            $checkedListBox.SetItemChecked($index, $true)
        }
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Hachihi Deployment Tool v3.2"
$form.Size = New-Object System.Drawing.Size(620, 680)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)

# HEADER
$panelHeader = New-Object System.Windows.Forms.Panel
$panelHeader.Location = New-Object System.Drawing.Point(0, 0)
$panelHeader.Size = New-Object System.Drawing.Size(620, 65)
$panelHeader.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$form.Controls.Add($panelHeader)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Location = New-Object System.Drawing.Point(20, 12)
$lblTitle.Size = New-Object System.Drawing.Size(570, 30)
$lblTitle.Text = "HACHIHI TECH - TRIỂN KHAI MÁY WINDOWS MỚI"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::White
$panelHeader.Controls.Add($lblTitle)

$lblVersion = New-Object System.Windows.Forms.Label
$lblVersion.Location = New-Object System.Drawing.Point(20, 40)
$lblVersion.Size = New-Object System.Drawing.Size(570, 20)
$lblVersion.Text = "Deployment Tool v3.2"
$lblVersion.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblVersion.ForeColor = [System.Drawing.Color]::White
$panelHeader.Controls.Add($lblVersion)

# PC NAME
$lblPC = New-Object System.Windows.Forms.Label
$lblPC.Location = New-Object System.Drawing.Point(20, 80)
$lblPC.Size = New-Object System.Drawing.Size(250, 20)
$lblPC.Text = "Tên máy tính:"
$lblPC.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblPC)

$txtPCName = New-Object System.Windows.Forms.TextBox
$txtPCName.Location = New-Object System.Drawing.Point(20, 102)
$txtPCName.Size = New-Object System.Drawing.Size(250, 25)
$txtPCName.Text = $env:COMPUTERNAME
$form.Controls.Add($txtPCName)

# PROFILE
$lblProfile = New-Object System.Windows.Forms.Label
$lblProfile.Location = New-Object System.Drawing.Point(320, 80)
$lblProfile.Size = New-Object System.Drawing.Size(240, 20)
$lblProfile.Text = "Profile phòng ban:"
$lblProfile.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblProfile)

$cmbProfile = New-Object System.Windows.Forms.ComboBox
$cmbProfile.Location = New-Object System.Drawing.Point(320, 102)
$cmbProfile.Size = New-Object System.Drawing.Size(250, 25)
$cmbProfile.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$form.Controls.Add($cmbProfile)

# APP CHECKLIST
$lblApps = New-Object System.Windows.Forms.Label
$lblApps.Location = New-Object System.Drawing.Point(20, 135)
$lblApps.Size = New-Object System.Drawing.Size(540, 20)
$lblApps.Text = "Danh sách phần mềm:"
$lblApps.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblApps)

$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Location = New-Object System.Drawing.Point(20, 158)
$checkedListBox.Size = New-Object System.Drawing.Size(550, 190)
$checkedListBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$checkedListBox.CheckOnClick = $true
$form.Controls.Add($checkedListBox)

# SELECT / UNSELECT BUTTONS
$btnSelectAll = New-Object System.Windows.Forms.Button
$btnSelectAll.Location = New-Object System.Drawing.Point(20, 355)
$btnSelectAll.Size = New-Object System.Drawing.Size(110, 30)
$btnSelectAll.Text = "Chọn tất cả"
$form.Controls.Add($btnSelectAll)

$btnUnselectAll = New-Object System.Windows.Forms.Button
$btnUnselectAll.Location = New-Object System.Drawing.Point(140, 355)
$btnUnselectAll.Size = New-Object System.Drawing.Size(110, 30)
$btnUnselectAll.Text = "Bỏ chọn"
$form.Controls.Add($btnUnselectAll)

# RESTART CHECKBOX
$chkRestart = New-Object System.Windows.Forms.CheckBox
$chkRestart.Location = New-Object System.Drawing.Point(300, 358)
$chkRestart.Size = New-Object System.Drawing.Size(270, 25)
$chkRestart.Text = "Tự khởi động lại sau khi hoàn tất"
$chkRestart.Checked = $true
$form.Controls.Add($chkRestart)

# INSTALL BUTTON
$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Location = New-Object System.Drawing.Point(180, 395)
$btnInstall.Size = New-Object System.Drawing.Size(260, 45)
$btnInstall.Text = "BẮT ĐẦU CÀI ĐẶT"
$btnInstall.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnInstall.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnInstall.ForeColor = [System.Drawing.Color]::White
$btnInstall.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnInstall.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnInstall)

# PROGRESS BAR
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 450)
$progressBar.Size = New-Object System.Drawing.Size(550, 22)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$form.Controls.Add($progressBar)

# STATUS LABEL
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(20, 478)
$lblStatus.Size = New-Object System.Drawing.Size(550, 22)
$lblStatus.Text = "Trạng thái: Đang khởi tạo..."
$lblStatus.ForeColor = [System.Drawing.Color]::DarkBlue
$form.Controls.Add($lblStatus)

# LOG CONSOLE
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20, 505)
$txtLog.Size = New-Object System.Drawing.Size(550, 125)
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtLog.BackColor = [System.Drawing.Color]::Black
$txtLog.ForeColor = [System.Drawing.Color]::LightGreen
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$form.Controls.Add($txtLog)

$global:txtLogControl = $txtLog

# =====================================================================
# 7. SỰ KIỆN GIAO DIỆN (EVENT HANDLERS)
# =====================================================================

$btnSelectAll.Add_Click({
    for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
        $checkedListBox.SetItemChecked($i, $true)
    }
})

$btnUnselectAll.Add_Click({
    for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
        $checkedListBox.SetItemChecked($i, $false)
    }
})

$cmbProfile.Add_SelectedIndexChanged({
    RefreshAppChecklist
})

$form.Add_Load({
    Write-HachihiLog "========================================" "INIT"
    Write-HachihiLog "HACHIHI DEPLOYMENT TOOL v3.2" "INIT"
    Write-HachihiLog "Computer: $env:COMPUTERNAME" "INIT"
    
    if (-not (Test-HachihiInternet)) {
        Write-HachihiLog "Không có kết nối Internet." "ERROR"
        $lblStatus.Text = "Trạng thái: Không có Internet"
        $lblStatus.ForeColor = [System.Drawing.Color]::Red
        $btnInstall.Enabled = $false
        return
    }
    Write-HachihiLog "Internet: OK" "SUCCESS"

    if (-not (Test-HachihiWinget)) {
        $lblStatus.Text = "Trạng thái: Không có Winget"
        $lblStatus.ForeColor = [System.Drawing.Color]::Red
        [System.Windows.Forms.MessageBox]::Show("Máy này không tìm thấy Winget.`r`n`r`nVui lòng cập nhật App Installer / Windows trước.", "Thiếu Winget", 'OK', 'Error')
        $btnInstall.Enabled = $false
        return
    }
    Initialize-HachihiWinget

    if (-not (Get-HachihiConfig)) {
        $lblStatus.Text = "Trạng thái: Không tải được cấu hình"
        $lblStatus.ForeColor = [System.Drawing.Color]::Red
        $btnInstall.Enabled = $false
        return
    }

    foreach ($profile in $global:config.Profiles) {
        [void]$cmbProfile.Items.Add([string]$profile)
    }
    [void]$cmbProfile.Items.Add("All")

    if ($cmbProfile.Items.Count -gt 0) {
        $cmbProfile.SelectedIndex = 0
    }

    $lblStatus.Text = "Trạng thái: Sẵn sàng triển khai"
    $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
    Write-HachihiLog "Tool đã sẵn sàng." "SUCCESS"
})

$btnInstall.Add_Click({
    if ($global:deploymentStarted) { return }

    $selectedCount = $checkedListBox.CheckedItems.Count
    if ($selectedCount -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Bạn chưa chọn phần mềm nào.", "Thông báo", 'OK', 'Warning')
        return
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show("Bắt đầu triển khai máy này?`r`n`r`nMáy: $($txtPCName.Text)`r`nProfile: $($cmbProfile.SelectedItem)`r`nSố mục: $selectedCount", "Xác nhận", 'YesNo', 'Question')
    if ($confirm -ne 'Yes') { return }

    $global:deploymentStarted = $true
    $btnInstall.Enabled = $false
    $btnSelectAll.Enabled = $false
    $btnUnselectAll.Enabled = $false
    $txtPCName.Enabled = $false
    $cmbProfile.Enabled = $false
    $checkedListBox.Enabled = $false
    $chkRestart.Enabled = $false

    $startTime = Get-Date
    $successCount = 0
    $failedCount = 0
    $skippedCount = 0
    $installedSummary = New-Object System.Collections.ArrayList
    $restartRequired = $false

    try {
        Write-HachihiLog "========================================" "START"
        Write-HachihiLog "BẮT ĐẦU DEPLOYMENT" "START"

        $lblStatus.Text = "Trạng thái: Kiểm tra hệ thống..."
        $progressBar.Value = 5
        $sysInfo = Get-HachihiSystemMetrics

        $renameResult = Set-HachihiComputerName -NewName $txtPCName.Text.Trim()
        $finalComputerName = $renameResult.Name
        if ($renameResult.Changed) { $restartRequired = $true }

        $selectedIndices = @($checkedListBox.CheckedIndices)
        $totalSteps = $selectedIndices.Count
        $currentStep = 0

        foreach ($idx in $selectedIndices) {
            $currentStep++
            $app = $global:config.Apps[$idx]
            if (-not $app) { continue }

            $name = [string]$app.Name
            $type = [string]$app.Type
            $percent = 10 + [math]::Floor(($currentStep / $totalSteps) * 75)
            if ($percent -gt 85) { $percent = 85 }

            $progressBar.Value = [int]$percent
            $lblStatus.Text = "Trạng thái: [$currentStep/$totalSteps] $name"

            if ($type -eq "Winget") {
                $appId = [string]$app.Id
                if (Test-WingetAppInstalled -AppId $appId) {
                    Write-HachihiLog "$name đã có sẵn. Bỏ qua." "SKIP"
                    $skippedCount++
                    [void]$installedSummary.Add("$name: Đã có sẵn")
                    continue
                }

                if (Install-HachihiWingetApp -Name $name -AppId $appId) {
                    if (Verify-HachihiApp -Name $name -AppId $appId) {
                        $successCount++
                        [void]$installedSummary.Add("$name: Thành công")
                    } else {
                        $failedCount++
                        [void]$installedSummary.Add("$name: Verify thất bại")
                    }
                } else {
                    $failedCount++
                    [void]$installedSummary.Add("$name: Thất bại")
                }
            }
        }

        $progressBar.Value = 90
        $endTime = Get-Date
        $timeSpan = $endTime - $startTime
        $durationStr = "{0:D2}m:{1:D2}s" -f [int]$timeSpan.TotalMinutes, $timeSpan.Seconds

        $reportObject = New-HachihiReport -SystemInfo $sysInfo -FinalComputerName $finalComputerName -Profile ([string]$cmbProfile.SelectedItem) -InstalledSummary @($installedSummary) -SuccessCount $successCount -FailedCount $failedCount -SkippedCount $skippedCount -Duration $durationStr -RestartRequired $restartRequired
        
        $reportObject | ConvertTo-Json -Depth 10 | Out-File -FilePath $global:jsonPath -Encoding UTF8 -Force
        Send-HachihiWebhook -Report $reportObject | Out-Null

        $progressBar.Value = 100
        $global:deploymentFinished = $true
        Write-HachihiLog "DEPLOYMENT HOÀN TẤT. Thành công: $successCount, Thất bại: $failedCount" "FINISH"

        $lblStatus.Text = "Trạng thái: Hoàn tất"
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen

        [System.Windows.Forms.MessageBox]::Show("Triển khai hoàn tất!`r`nThành công: $successCount`r`nThất bại: $failedCount`r`nThời gian: $durationStr", "Hachihi Tool", 'OK', 'Information')

        if ($chkRestart.Checked) {
            for ($i = 10; $i -ge 1; $i--) {
                $lblStatus.Text = "Trạng thái: Khởi động lại sau $i giây..."
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Seconds 1
            }
            Restart-Computer -Force
        }
    }
    catch {
        Write-HachihiLog "LỖI EXCEPTION: $_" "ERROR"
        $lblStatus.Text = "Trạng thái: Có lỗi xảy ra"
        $lblStatus.ForeColor = [System.Drawing.Color]::Red
        [System.Windows.Forms.MessageBox]::Show("Đã xảy ra lỗi: $_", "Lỗi", 'OK', 'Error')
    }
})

$form.Add_FormClosing({
    if ($global:deploymentStarted -and -not $global:deploymentFinished) {
        $ans = [System.Windows.Forms.MessageBox]::Show("Deployment đang chạy. Bạn có chắc muốn thoát?", "Cảnh báo", 'YesNo', 'Warning')
        if ($ans -ne 'Yes') { $_.Cancel = $true }
    }
})

[void]$form.ShowDialog()
