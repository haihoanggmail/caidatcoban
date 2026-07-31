# Yêu cầu chạy quyền Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==========================================
# DANH SÁCH MỞ RỘNG (DỄ DÀNG THÊM APP SAU NÀY)
# ==========================================
$appList = @(
    [PSCustomObject]@{ Name = "Google Chrome (Trình duyệt web)"; Id = "Google.Chrome"; Type = "Winget"; Checked = $true },
    [PSCustomObject]@{ Name = "UniKey (Bộ gõ tiếng Việt)"; Id = "UniKey.UniKey"; Type = "Winget"; Checked = $true },
    [PSCustomObject]@{ Name = "7-Zip (Phần mềm giải nén)"; Id = "7zip.7zip"; Type = "Winget"; Checked = $false },
    [PSCustomObject]@{ Name = "VLC Media Player (Xem phim/nghe nhạc)"; Id = "VideoLAN.VLC"; Type = "Winget"; Checked = $false },
    [PSCustomObject]@{ Name = "Hệ thống Font chữ tiêu chuẩn Hachihi"; Id = "HachihiFonts"; Type = "Font"; Checked = $true }
)

# ==========================================
# TẠO GIAO DIỆN CHỌN APP (CÓ ĐẾM NGƯỢC 30 GIÂY)
# ==========================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Hachihi Tech - Trình Cài Đặt Tự Động Máy Mới"
$form.Size = New-Object System.Drawing.Size(460, 440)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(15, 15)
$label.Size = New-Object System.Drawing.Size(415, 30)
$label.Text = "Vui lòng chọn các thành phần cần cài đặt cho máy mới:"
$label.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($label)

$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Location = New-Object System.Drawing.Point(15, 50)
$checkedListBox.Size = New-Object System.Drawing.Size(415, 230)
$checkedListBox.Font = New-Object System.Drawing.Font("Arial", 9)

foreach ($app in $appList) {
    $index = $checkedListBox.Items.Add($app.Name)
    $checkedListBox.SetItemChecked($index, $app.Checked)
}
$form.Controls.Add($checkedListBox)

$lblTimer = New-Object System.Windows.Forms.Label
$lblTimer.Location = New-Object System.Drawing.Point(15, 285)
$lblTimer.Size = New-Object System.Drawing.Size(415, 25)
$lblTimer.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Italic)
$lblTimer.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($lblTimer)

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Location = New-Object System.Drawing.Point(155, 320)
$btnInstall.Size = New-Object System.Drawing.Size(140, 40)
$btnInstall.Text = "BẮT ĐẦU CÀI ĐẶT"
$btnInstall.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
$btnInstall.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnInstall.ForeColor = [System.Drawing.Color]::White

$selectedApps = @()
$processSelection = {
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

$script:countdown = 30
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    script:countdown--
    $lblTimer.Text = "Tự động chạy sau $script:countdown giây nếu không có thao tác..."
    if ($script:countdown -le 0) {
        $timer.Stop()
        & $processSelection
    }
})
$timer.Start()

$form.Add_Shown({ $form.Activate() })
$checkedListBox.Add_MouseMove({
    if ($script:countdown -gt 0 -and $timer.Enabled) {
        $timer.Stop()
        $lblTimer.Text = "Đã chọn thủ công (Đã tắt đếm ngược tự động)."
        $lblTimer.ForeColor = [System.Drawing.Color]::DarkGreen
    }
})

[void]$form.ShowDialog()

if ($selectedApps.Count -eq 0) {
    Write-Host "[-] Bạn đã hủy quá trình cài đặt." -ForegroundColor Yellow
    exit
}

Clear-Host

# ==========================================
# HIỂN THỊ LOGO HACHIHI TECH
# ==========================================
$host.UI.RawUI.WindowTitle = "Hachihi Tech - Đang chuẩn bị hệ thống..."
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "                             ▄███▄                                   " -ForegroundColor Cyan
Write-Host "                             ▀███▀                                   " -ForegroundColor Cyan
Write-Host "                                                                     "
Write-Host "                             ▄███▄                                   " -ForegroundColor Cyan
Write-Host "              ▄███▄          █████                                   " -ForegroundColor Blue
Write-Host "              █████          █████                                   " -ForegroundColor Blue
Write-Host "              █████          █████           ▄███▄                   " -ForegroundColor Blue
Write-Host "              █████          █████           █████                   " -ForegroundColor Blue
Write-Host "              █████          █████           █████                   " -ForegroundColor Blue
Write-Host "              ▀███▀          █████           ▀███▀                   " -ForegroundColor Blue
Write-Host "                             █████                                   " -ForegroundColor Cyan
Write-Host "                             ▀███▀                                   " -ForegroundColor Cyan
Write-Host "                                                                     "
Write-Host "             HỆ THỐNG CÀI ĐẶT TỰ ĐỘNG MÁY MỚI (ONE-CLICK SETUP)        " -ForegroundColor White -BackgroundColor DarkBlue
Write-Host "             By phòng kỹ thuật hachihi - Phiên bản chuyên nghiệp      " -ForegroundColor Yellow 
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

$chromeStatus = "Bỏ qua"
$unikeyStatus = "Bỏ qua"
$chromePath = ""
$unikeyPath = ""
$extraAppsStatus = @()
$fontCount = 0
$fontInstalledCount = 0

# ==========================================
# THỰC THI CÀI ĐẶT DỰA TRÊN LỰA CHỌN
# ==========================================
foreach ($item in $selectedApps) {
    if ($item.Type -eq "Winget") {
        $host.UI.RawUI.WindowTitle = "Đang cài đặt: $($item.Name)"
        Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host " [+] Đang kiểm tra và cài đặt: $($item.Name)..." -ForegroundColor White
        
        winget install --id $item.Id -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
        
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
            Write-Host "     [OK] Đã sẵn sàng trên hệ thống." -ForegroundColor Green
            
            # Dò tìm đường dẫn thực tế và tạo shortcut tối ưu
            if ($item.Id -eq "Google.Chrome") {
                $chromeStatus = "Thành công"
                $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
            }
            if ($item.Id -eq "UniKey.UniKey") {
                $unikeyStatus = "Thành công"
                # Tìm đường dẫn UniKey thực tế trên máy
                $possiblePaths = @(
                    "$env:ProgramFiles\UniKey\unikeynt.exe",
                    "${env:ProgramFiles(x86)}\UniKey\unikeynt.exe",
                    "$env:LocalAppData\Programs\UniKey\unikeynt.exe"
                )
                foreach ($p in $possiblePaths) {
                    if (Test-Path $p) {
                        $unikeyPath = $p
                        break
                    }
                }
                # Nếu không tìm thấy mặc định, quét trong thư mục Program Files
                if (-not $unikeyPath) {
                    $found = Get-ChildItem "C:\Program Files" -Recurse -Filter "unikeynt.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($found) { $unikeyPath = $found.FullName }
                }
                
                # Tạo Shortcut ra Desktop cho UniKey để dễ thấy
                if ($unikeyPath) {
                    $DesktopPath = [Environment]::GetFolderPath("Desktop")
                    $WScriptShell = New-Object -ComObject WScript.Shell
                    $Shortcut = $WScriptShell.CreateShortcut("$DesktopPath\UniKey.lnk")
                    $Shortcut.TargetPath = $unikeyPath
                    $Shortcut.Save()
                }
            }
            $extraAppsStatus += "$($item.Name): Thành công"
        } else {
            Write-Host "     [!] Phần mềm đã có sẵn trên hệ thống." -ForegroundColor Yellow
            if ($item.Id -eq "Google.Chrome") { 
                $chromeStatus = "Đã có sẵn"
                $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
            }
            if ($item.Id -eq "UniKey.UniKey") { 
                $unikeyStatus = "Đã có sẵn"
                $found = Get-ChildItem "C:\Program Files" -Recurse -Filter "unikeynt.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) { $unikeyPath = $found.FullName }
            }
            $extraAppsStatus += "$($item.Name): Đã có sẵn"
        }
    }
    
    if ($item.Type -eq "Font") {
        $host.UI.RawUI.WindowTitle = "Đang cài đặt bộ Font chữ hệ thống..."
        Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host " [+] Đang tải và kiểm tra Bộ Font hệ thống..." -ForegroundColor White
        
        $tempDir = "$env:TEMP\HachihiFonts"
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
        New-Item -ItemType Directory -Path $tempDir | Out-Null
        
        $fontZipUrl = "https://drive.google.com/uc?export=download&id=1wGyWMJRc18poAYfaSfN2EoK2M3-iObQO"
        $zipPath = "$tempDir\fonts.zip"
        $extractPath = "$tempDir\extracted"
        
        try {
            Invoke-WebRequest -Uri $fontZipUrl -OutFile $zipPath
            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
            
            $fontFiles = Get-ChildItem $extractPath -Recurse -Include *.ttf, *.otf
            $fontCount = $fontFiles.Count
            
            $winFontDir = "$env:SystemRoot\Fonts"
            $fontsNamespace = (New-Object -ComObject Shell.Application).Namespace(0x14)
            
            foreach ($font in $fontFiles) {
                $targetPath = Join-Path $winFontDir $font.Name
                if (-not (Test-Path $targetPath)) {
                    $fontsNamespace.CopyHere($font.FullName, 0x10)
                    $script:fontInstalledCount++
                }
            }
            Write-Host "     [OK] Tổng số font quét thấy: $fontCount | Đã cài mới bổ sung: $script:fontInstalledCount font." -ForegroundColor Green
        } catch {
            Write-Host "     [!] Không thể tải font chữ." -ForegroundColor Yellow
        }
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
    }
}

# ==========================================
# BÁO CÁO TỔNG KẾT (CÓ HIỂN THỊ ĐƯỜNG DẪN)
# ==========================================
$host.UI.RawUI.WindowTitle = "Hoàn tất quá trình cài đặt!"
Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "                  BÁO CÁO KẾT QUẢ CÀI ĐẶT HỆ THỐNG                    " -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "  [ + ] Google Chrome          : $chromeStatus" -ForegroundColor Cyan
if ($chromePath) {
    Write-Host "        Path: $chromePath" -ForegroundColor DarkGray
}

Write-Host "  [ + ] UniKey                 : $unikeyStatus" -ForegroundColor Cyan
if ($unikeyPath) {
    Write-Host "        Path: $unikeyPath (Đã tạo Shortcut ngoài Desktop)" -ForegroundColor DarkGray
}

foreach ($st in $extraAppsStatus) {
    Write-Host "  [ + ] $st" -ForegroundColor Cyan
}

if ($fontCount -gt 0) {
    Write-Host "  [ + ] Font chữ (Đã cài mới)  : $fontInstalledCount / $fontCount font" -ForegroundColor Cyan
    Write-Host "        Path: C:\Windows\Fonts" -ForegroundColor DarkGray
}
Write-Host "---------------------------------------------------------------------" -ForegroundColor Green
Write-Host "  [+] Thiết lập máy mới hoàn tất xuất sắc!" -ForegroundColor White
Write-Host "  [+] Cửa sổ này sẽ tự động đóng lại sau 15 giây..." -ForegroundColor Yellow
Write-Host "=====================================================================" -ForegroundColor Green

Start-Sleep -Seconds 15
