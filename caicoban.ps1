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
# TẠO GIAO DIỆN CHỌN APP (GUI CHECKBOX)
# ==========================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Hachihi Tech - Trình Cài Đặt Tự Động Máy Mới"
$form.Size = New-Object System.Drawing.Size(460, 420)
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
$checkedListBox.Size = New-Object System.Drawing.Size(415, 240)
$checkedListBox.Font = New-Object System.Drawing.Font("Arial", 9)

foreach ($app in $appList) {
    $index = $checkedListBox.Items.Add($app.Name)
    $checkedListBox.SetItemChecked($index, $app.Checked)
}
$form.Controls.Add($checkedListBox)

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Location = New-Object System.Drawing.Point(155, 315)
$btnInstall.Size = New-Object System.Drawing.Size(140, 40)
$btnInstall.Text = "BẮT ĐẦU CÀI ĐẶT"
$btnInstall.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
$btnInstall.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnInstall.ForeColor = [System.Drawing.Color]::White

$selectedApps = @()
$btnInstall.Add_Click({
    for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
        if ($checkedListBox.GetItemChecked($i)) {
            $script:selectedApps += $appList[$i]
        }
    }
    $form.Close()
})
$form.Controls.Add($btnInstall)

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
        Write-Host " [+] Đang cài đặt: $($item.Name)..." -ForegroundColor White
        
        winget install --id $item.Id -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
        
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
            Write-Host "     [OK] Cài đặt thành công!" -ForegroundColor Green
            if ($item.Id -eq "Google.Chrome") { $chromeStatus = "Đã cài thành công" }
            if ($item.Id -eq "UniKey.UniKey") { $unikeyStatus = "Đã cài thành công" }
            $extraAppsStatus += "$($item.Name): Thành công"
        } else {
            Write-Host "     [!] Gặp sự cố khi cài đặt (Có thể đã có sẵn trên máy)." -ForegroundColor Yellow
            if ($item.Id -eq "Google.Chrome") { $chromeStatus = "Đã có sẵn / Bỏ qua" }
            if ($item.Id -eq "UniKey.UniKey") { $unikeyStatus = "Đã có sẵn / Bỏ qua" }
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
            
            # Thư mục font hệ thống Windows
            $winFontDir = "$env:SystemRoot\Fonts"
            $fontsNamespace = (New-Object -ComObject Shell.Application).Namespace(0x14)
            
            foreach ($font in $fontFiles) {
                $targetPath = Join-Path $winFontDir $font.Name
                # Kiểm tra nếu font chưa có thì mới cài để tránh hiện bảng hỏi trùng lặp
                if (-not (Test-Path $targetPath)) {
                    $fontsNamespace.CopyHere($font.FullName, 0x10)
                    $script:fontInstalledCount++
                }
            }
            Write-Host "     [OK] Tổng số font quét thấy: $fontCount | Đã cài mới bổ sung: $fontInstalledCount font." -ForegroundColor Green
        } catch {
            Write-Host "     [!] Không thể tải font chữ." -ForegroundColor Yellow
        }
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
    }
}

# ==========================================
# BÁO CÁO TỔNG KẾT (SUMMARY REPORT)
# ==========================================
$host.UI.RawUI.WindowTitle = "Hoàn tất quá trình cài đặt!"
Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "                  BÁO CÁO KẾT QUẢ CÀI ĐẶT HỆ THỐNG                    " -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "  [ + ] Google Chrome          : " -NoNewline; Write-Host "$chromeStatus" -ForegroundColor Cyan
Write-Host "  [ + ] UniKey                 : " -NoNewline; Write-Host "$unikeyStatus" -ForegroundColor Cyan
foreach ($st in $extraAppsStatus) {
    Write-Host "  [ + ] $st" -ForegroundColor Cyan
}
if ($fontCount -gt 0) {
    Write-Host "  [ + ] Font chữ (Đã cài mới)  : " -NoNewline; Write-Host "$fontInstalledCount / $fontCount font" -ForegroundColor Cyan
}
Write-Host "---------------------------------------------------------------------" -ForegroundColor Green
Write-Host "  [+] Thiết lập máy mới hoàn tất xuất sắc!" -ForegroundColor White
Write-Host "  [+] Cửa sổ này sẽ tự động đóng lại sau 10 giây..." -ForegroundColor Yellow
Write-Host "=====================================================================" -ForegroundColor Green

Start-Sleep -Seconds 10
