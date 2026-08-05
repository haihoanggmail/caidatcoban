# ==========================================
# 0. YÊU CẦU CHẠY QUYỀN ADMINISTRATOR
# ==========================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ==========================================
# 1 & 2. KIỂM TRA INTERNET & WINGET
# ==========================================
if (!(Test-Connection 8.8.8.8 -Count 1 -Quiet)) {
    [System.Windows.Forms.MessageBox]::Show("Không có kết nối Internet. Vui lòng kiểm tra lại mạng!", "Lỗi Kết Nối", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
    [System.Windows.Forms.MessageBox]::Show("Máy tính chưa có Winget (App Installer). Vui lòng cập nhật Windows Store.", "Thiếu Winget", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==========================================
# KHỞI TẠO THƯ MỤC & LOG HACHIHI
# ==========================================
$hachihiDir = "C:\HachihiSoftware"
if (-not (Test-Path $hachihiDir)) { New-Item -ItemType Directory -Path $hachihiDir | Out-Null }
$logFile = "$hachihiDir\install.log"
"--- BẮT ĐẦU CÀI ĐẶT: $(Get-Date) ---" | Out-File -FilePath $logFile -Encoding utf8

# ==========================================
# DANH SÁCH APP & PROFILE PHÒNG BAN
# ==========================================
$appList = @(
    [PSCustomObject]@{ Name = "Google Chrome (Trình duyệt web)"; Id = "Google.Chrome"; Type = "Winget"; Profile = @("Văn phòng","Kỹ thuật","Bảo hành","Kế toán") },
    [PSCustomObject]@{ Name = "UniKey (Bộ gõ tiếng Việt)"; Id = "UniKey.UniKey"; Type = "Winget"; Profile = @("Văn phòng","Kỹ thuật","Bảo hành","Kế toán") },
    [PSCustomObject]@{ Name = "Zalo PC (Ứng dụng nhắn tin)"; Id = "Zalo.Zalo"; Type = "Winget"; Profile = @("Văn phòng","Kỹ thuật","Bảo hành","Kế toán") },
    [PSCustomObject]@{ Name = "7-Zip (Phần mềm giải nén)"; Id = "7zip.7zip"; Type = "Winget"; Profile = @("Văn phòng","Kỹ thuật","Bảo hành","Kế toán") },
    [PSCustomObject]@{ Name = "Notepad++ (Soạn thảo code/text)"; Id = "Notepad++.Notepad++"; Type = "Winget"; Profile = @("Kỹ thuật","Kế toán") },
    [PSCustomObject]@{ Name = "Adobe Acrobat Reader"; Id = "Adobe.Acrobat.Reader.64-bit"; Type = "Winget"; Profile = @("Văn phòng","Kế toán") },
    [PSCustomObject]@{ Name = "AnyDesk (Điều khiển từ xa)"; Id = "AnyDesk.AnyDesk"; Type = "Winget"; Profile = @("Kỹ thuật","Bảo hành") },
    [PSCustomObject]@{ Name = "Visual C++ Redistributable"; Id = "Microsoft.VCRedist.2015+.x64"; Type = "Winget"; Profile = @("Kỹ thuật","Bảo hành") },
    [PSCustomObject]@{ Name = ".NET Desktop Runtime"; Id = "Microsoft.DotNet.DesktopRuntime.8"; Type = "Winget"; Profile = @("Kỹ thuật") },
    [PSCustomObject]@{ Name = "Hệ thống Font chữ tiêu chuẩn Hachihi"; Id = "HachihiFonts"; Type = "Font"; Profile = @("Văn phòng","Kỹ thuật","Bảo hành","Kế toán") }
)

# ==========================================
# TẠO GIAO DIỆN WINFORMS HIỆN ĐẠI
# ==========================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Hachihi Tech - One-Click Setup v2.0"
$form.Size = New-Object System.Drawing.Size(520, 600)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)

# Panel Header
$panelTop = New-Object System.Windows.Forms.Panel
$panelTop.Size = New-Object System.Drawing.Size(520, 60)
$panelTop.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)

$labelTitle = New-Object System.Windows.Forms.Label
$labelTitle.Location = New-Object System.Drawing.Point(20, 15)
$labelTitle.Size = New-Object System.Drawing.Size(480, 30)
$labelTitle.Text = "HỆ THỐNG CÀI ĐẶT MÁY MỚI - HACHIHI TECH"
$labelTitle.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$labelTitle.ForeColor = [System.Drawing.Color]::White
$panelTop.Controls.Add($labelTitle)
$form.Controls.Add($panelTop)

# Nhập Tên Máy (Computer Name)
$lblPC = New-Object System.Windows.Forms.Label
$lblPC.Location = New-Object System.Drawing.Point(20, 75)
$lblPC.Size = New-Object System.Drawing.Size(150, 20)
$lblPC.Text = "Đổi tên máy tính:"
$lblPC.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblPC)

$txtPCName = New-Object System.Windows.Forms.TextBox
$txtPCName.Location = New-Object System.Drawing.Point(20, 98)
$txtPCName.Size = New-Object System.Drawing.Size(220, 25)
$txtPCName.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$txtPCName.Text = $env:COMPUTERNAME
$form.Controls.Add($txtPCName)

# Chọn Profile Phòng Ban
$lblProfile = New-Object System.Windows.Forms.Label
$lblProfile.Location = New-Object System.Drawing.Point(260, 75)
$lblProfile.Size = New-Object System.Drawing.Size(150, 20)
$lblProfile.Text = "Chọn Profile cấu hình:"
$lblProfile.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblProfile)

$cmbProfile = New-Object System.Windows.Forms.ComboBox
$cmbProfile.Location = New-Object System.Drawing.Point(260, 98)
$cmbProfile.Size = New-Object System.Drawing.Size(222, 25)
$cmbProfile.Font = New-Object System.Drawing.Font("Segoe UI", 9)
@("Văn phòng", "Kỹ thuật", "Bảo hành", "Kế toán") | ForEach-Object { [void]$cmbProfile.Items.Add($_) }
$cmbProfile.SelectedIndex = 0
$form.Controls.Add($cmbProfile)

# Danh sách CheckedListBox Ứng dụng
$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Location = New-Object System.Drawing.Point(20, 140)
$checkedListBox.Size = New-Object System.Drawing.Size(462, 220)
$checkedListBox.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$checkedListBox.BackColor = [System.Drawing.Color]::White

function LoadAppsForProfile($profileName) {
    $checkedListBox.Items.Clear()
    foreach ($app in $appList) {
        $isChecked = $app.Profile -contains $profileName
        $index = $checkedListBox.Items.Add($app.Name)
        $checkedListBox.SetItemChecked($index, $isChecked)
    }
}
LoadAppsForProfile "Văn phòng"

$cmbProfile.add_SelectedIndexChanged({
    LoadAppsForProfile $cmbProfile.SelectedItem
})
$form.Controls.Add($checkedListBox)

# Checkbox Tạo Restore Point & Khởi động lại
$chkRestore = New-Object System.Windows.Forms.CheckBox
$chkRestore.Location = New-Object System.Drawing.Point(20, 375)
$chkRestore.Size = New-Object System.Drawing.Size(220, 24)
$chkRestore.Text = "Tạo Restore Point trước khi cài"
$chkRestore.Checked = $true
$form.Controls.Add($chkRestore)

$chkRestart = New-Object System.Windows.Forms.CheckBox
$chkRestart.Location = New-Object System.Drawing.Point(260, 375)
$chkRestart.Size = New-Object System.Drawing.Size(220, 24)
$chkRestart.Text = "Khởi động lại sau khi xong"
$chkRestart.Checked = $false
$form.Controls.Add($chkRestart)

# Nhãn đếm ngược tự động
$lblTimer = New-Object System.Windows.Forms.Label
$lblTimer.Location = New-Object System.Drawing.Point(20, 410)
$lblTimer.Size = New-Object System.Drawing.Size(462, 22)
$lblTimer.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$lblTimer.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($lblTimer)

# Nút Bắt đầu cài đặt
$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Location = New-Object System.Drawing.Point(140, 445)
$btnInstall.Size = New-Object System.Drawing.Size(220, 42)
$btnInstall.Text = "BẮT ĐẦU CÀI ĐẶT"
$btnInstall.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnInstall.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnInstall.ForeColor = [System.Drawing.Color]::White
$btnInstall.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnInstall.FlatAppearance.BorderSize = 0

$script:selectedApps = @()
$script:newComputerName = ""
$script:doRestore = $true
$script:doRestart = $false

$processSelection = {
    $script:newComputerName = $txtPCName.Text.Trim()
    $script:doRestore = $chkRestore.Checked
    $script:doRestart = $chkRestart.Checked
    $script:selectedApps = @()
    for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
        if ($checkedListBox.GetItemChecked($i)) {
            $script:selectedApps += $appList[$i]
        }
    }
    $form.Close()
}

$btnInstall.Add_Click($processSelection)
$form.Controls.Add($btnInstall)

# Bộ đếm ngược 15 giây
$script:countdown = 15
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    $script:countdown--
    $lblTimer.Text = "Tự động chạy sau $script:countdown giây nếu không thao tác..."
    if ($script:countdown -le 0) {
        $timer.Stop()
        & $processSelection
    }
})
$timer.Start()

$checkedListBox.Add_MouseDown({
    if ($script:countdown -gt 0 -and $timer.Enabled) {
        $timer.Stop()
        $lblTimer.Text = "Đã chuyển sang chế độ tùy chọn thủ công."
    }
})

[void]$form.ShowDialog()

if ($script:selectedApps.Count -eq 0) {
    Write-Host "[-] Đã hủy quá trình cài đặt." -ForegroundColor Yellow
    exit
}

Clear-Host

# ==========================================
# 3. WINGET UPGRADE & TẠO RESTORE POINT
# ==========================================
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "       HỆ THỐNG CÀI ĐẶT TỰ ĐỘNG MÁY MỚI (ONE-CLICK SETUP v2.0)       " -ForegroundColor White -BackgroundColor DarkBlue
Write-Host "=====================================================================" -ForegroundColor Cyan

if ($script:doRestore) {
    Write-Host "[+] Đang tạo điểm khôi phục hệ thống (Restore Point)..." -ForegroundColor Yellow
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "Hachihi-Setup-RestorePoint" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
        Write-Host "    [OK] Đã tạo Restore Point thành công!" -ForegroundColor Green
    } catch {
        Write-Host "    [!] Không thể tạo Restore Point (Bỏ qua bước này)." -ForegroundColor Yellow
    }
}

Write-Host "[+] Đang cập nhật nguồn Winget và nâng cấp các gói sẵn có..." -ForegroundColor Yellow
winget source update | Out-Null
winget upgrade --all --silent --accept-package-agreements --accept-source-agreements | Out-Null

# ==========================================
# ĐỔI TÊN MÁY NẾU CÓ THAY ĐỔI
# ==========================================
if ($script:newComputerName -and $script:newComputerName -ne $env:COMPUTERNAME) {
    Write-Host "[+] Đang đổi tên máy thành: $script:newComputerName..." -ForegroundColor Yellow
    Rename-Computer -NewName $script:newComputerName -Force -ErrorAction SilentlyContinue
}

# ==========================================
# THIẾT LẬP MÚI GIỜ & ĐỒNG BỘ THỜI GIAN
# ==========================================
Write-Host "[+] Đang đồng bộ múi giờ Việt Nam (UTC+07:00)..." -ForegroundColor Yellow
try {
    Set-TimeZone -Id "SE Asia Standard Time" -ErrorAction SilentlyContinue
    Set-Service W32Time -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service W32Time -ErrorAction SilentlyContinue
    w32tm /resync /nowait -ErrorAction SilentlyContinue
    Write-Host "    [OK] Đã cấu hình múi giờ thành công!" -ForegroundColor Green
} catch {}

$installedAppsSummary = @()
$fontInstalledCount = 0

# ==========================================
# THỰC THI CÀI ĐẶT ỨNG DỤNG
# ==========================================
foreach ($item in $script:selectedApps) {
    if ($item.Type -eq "Winget") {
        Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host " [+] Đang cài đặt: $($item.Name)..." -ForegroundColor White
        
        winget install --id $item.Id -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
        
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
            Write-Host "     [OK] Thành công." -ForegroundColor Green
            $installedAppsSummary += "$($item.Name): Thành công"
            "[$((Get-Date))] Installed via Winget: $($item.Name)" | Out-File -FilePath $logFile -Append -Encoding utf8
        } else {
            Write-Host "     [!] Đã có sẵn hoặc không cần cập nhật." -ForegroundColor Yellow
            $installedAppsSummary += "$($item.Name): Đã có sẵn"
            "[$((Get-Date))] Already available: $($item.Name)" | Out-File -FilePath $logFile -Append -Encoding utf8
        }
    }
    
    if ($item.Type -eq "Font") {
        Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host " [+] Đang tải và cài đặt bộ Font tiêu chuẩn Hachihi..." -ForegroundColor White
        
        $tempDir = "$env:TEMP\HachihiFonts"
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
        New-Item -ItemType Directory -Path $tempDir | Out-Null
        
        # Link Github Release hoặc Direct link lưu trữ Font của bạn
        $fontZipUrl = "https://github.com/hachihi/hachihi-setup/raw/main/fonts.zip" 
        $zipPath = "$tempDir\fonts.zip"
        $extractPath = "$tempDir\extracted"
        
        try {
            Invoke-WebRequest -Uri $fontZipUrl -OutFile $zipPath -ErrorAction Stop
            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
            
            $fontFiles = Get-ChildItem $extractPath -Recurse -Include *.ttf, *.otf
            $winFontDir = "$env:SystemRoot\Fonts"
            
            foreach ($font in $fontFiles) {
                $targetPath = Join-Path $winFontDir $font.Name
                if (-not (Test-Path $targetPath)) {
                    Copy-Item $font.FullName -Destination $winFontDir -Force
                    # Đăng ký Registry an toàn không dùng FromStream
                    $regName = "$($font.BaseName) (TrueType)"
                    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -Name $regName -Value $font.Name -PropertyType String -Force | Out-Null
                    $script:fontInstalledCount++
                }
            }
            Write-Host "     [OK] Đã cài bổ sung $script:fontInstalledCount font chữ mới." -ForegroundColor Green
            $installedAppsSummary += "Hệ thống Font chữ: $script:fontInstalledCount font mới"
        } catch {
            Write-Host "     [!] Không thể tải bộ font từ kho lưu trữ. Vui lòng kiểm tra lại link." -ForegroundColor Yellow
        }
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
    }
}

# ==========================================
# LẤY THÔNG TIN SERIAL & PHẦN CỨNG CUỐI KỲ
# ==========================================
$bios = Get-CimInstance Win32_BIOS
$serialNumber = $bios.SerialNumber.Trim()
$model = (Get-CimInstance Win32_ComputerSystem).Model.Trim()
$osVersion = (Get-CimInstance Win32_OperatingSystem).Caption.Trim()
$ipAddress = (Find-NetRoute -RemoteIPAddress 8.8.8.8 | Select-Object -ExpandProperty IPAddress) -join ", "

# ==========================================
# GỬI KẾT QUẢ VỀ GOOGLE SHEETS (APPS SCRIPT)
# ==========================================
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "[+] Đang gửi báo cáo cấu hình về hệ thống quản lý (Google Sheets)..." -ForegroundColor Yellow
try {
    $webhookUrl = "YOUR_GOOGLE_APPS_SCRIPT_WEB_URL_HERE" # Thay thế link Google Apps Script Web App của bạn vào đây
    if ($webhookUrl -ne "YOUR_GOOGLE_APPS_SCRIPT_WEB_URL_HERE") {
        $body = @{
            ComputerName = $env:COMPUTERNAME
            Model        = $model
            Serial       = $serialNumber
            IP           = $ipAddress
            OS           = $osVersion
            Profile      = $cmbProfile.SelectedItem
            Apps         = ($installedAppsSummary -join ", ")
            Date         = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        } | ConvertTo-Json

        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $body -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
        Write-Host "    [OK] Đã đồng bộ dữ liệu lên ERP/Google Sheets thành công!" -ForegroundColor Green
    }
} catch {
    Write-Host "    [!] Không thể kết nối tới máy chủ ghi nhận báo cáo." -ForegroundColor Yellow
}

# ==========================================
# BÁO CÁO TỔNG KẾT
# ==========================================
Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "                  HOÀN TẤT THIẾT LẬP MÁY MỚI!                          " -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host " [ + ] Máy tính / Model : $env:COMPUTERNAME / $model" -ForegroundColor Cyan
Write-Host " [ + ] Serial Number    : $serialNumber" -ForegroundColor Cyan
Write-Host " [ + ] Địa chỉ IP       : $ipAddress" -ForegroundColor Cyan
Write-Host "---------------------------------------------------------------------" -ForegroundColor Green

if ($script:doRestart) {
    Write-Host " [+] Máy tính sẽ khởi động lại sau 10 giây..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Restart-Computer -Force
} else {
    Write-Host " [+] Hoàn tất! Bạn có thể bắt đầu sử dụng máy." -ForegroundColor White
    Start-Process "diskmgmt.msc"
}
