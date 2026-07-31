# Yêu cầu chạy quyền Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Clear-Host

# ==========================================
# CẤU HÌNH GIAO DIỆN HACHIHI TECH
# ==========================================
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
Write-Host "[*] Đang khởi chạy quy trình thiết lập hệ thống tự động..." -ForegroundColor Green
Write-Host "[*] Vui lòng không tắt cửa sổ này trong quá trình cài đặt." -ForegroundColor Yellow
Start-Sleep -Seconds 2

# Khởi tạo biến lưu trạng thái báo cáo
$chromeStatus = "Thất bại"
$unikeyStatus = "Thất bại"
$fontCount = 0

# ==========================================
# BƯỚC 1: CÀI ĐẶT PHẦN MỀM QUA WINGET
# ==========================================
Write-Host ""
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "[ BƯỚC 1/3 ] CÀI ĐẶT PHẦN MỀM TIỆN ÍCH (CHROME, UNIKEY)" -ForegroundColor Cyan
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan

Write-Host "  - Đang cài đặt Google Chrome..." -ForegroundColor White
winget install --id Google.Chrome -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) { 
    $chromeStatus = "Đã cài thành công"
    Write-Host "    [OK] Google Chrome đã sẵn sàng." -ForegroundColor Green
} else {
    Write-Host "    [!] Google Chrome gặp sự cố khi cài đặt." -ForegroundColor Yellow
}

Write-Host "  - Đang cài đặt UniKey..." -ForegroundColor White
winget install --id UniKey.UniKey -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) { 
    $unikeyStatus = "Đã cài thành công"
    Write-Host "    [OK] UniKey đã sẵn sàng." -ForegroundColor Green
} else {
    Write-Host "    [!] UniKey gặp sự cố khi cài đặt." -ForegroundColor Yellow
}

# ==========================================
# BƯỚC 2: TẢI VÀ CÀI ĐẶT FONT CHỮ
# ==========================================
Write-Host ""
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "[ BƯỚC 2/3 ] TẢI VÀ TÍCH HỢP BỘ FONT TIÊU CHUẨN" -ForegroundColor Cyan
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan

$tempDir = "$env:TEMP\HachihiFonts"
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir | Out-Null

$fontZipUrl = "https://drive.google.com/uc?export=download&id=1wGyWMJRc18poAYfaSfN2EoK2M3-iObQO"
$zipPath = "$tempDir\fonts.zip"
$extractPath = "$tempDir\extracted"

Write-Host "  - Đang tải gói Font hệ thống..." -ForegroundColor White
try {
    Invoke-WebRequest -Uri $fontZipUrl -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    # Đếm số lượng file font hợp lệ (.ttf, .otf)
    $fontFiles = Get-ChildItem $extractPath -Recurse -Include *.ttf, *.otf
    $fontCount = $fontFiles.Count

    Write-Host "  - Đang cài đặt $fontCount Font chữ vào hệ thống Windows..." -ForegroundColor White
    $fonts = (New-Object -ComObject Shell.Application).Namespace(0x14)
    foreach ($font in $fontFiles) {
        $fonts.CopyHere($font.FullName, 0x10)
    }
    Write-Host "    [OK] Đã tích hợp thành công bộ font chữ." -ForegroundColor Green
} catch {
    Write-Host "  [!] Không thể tải hoặc cài đặt font tự động." -ForegroundColor Yellow
}

# ==========================================
# BƯỚC 3: DỌN DẸP
# ==========================================
Write-Host ""
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "[ BƯỚC 3/3 ] DỌN DẸP HỆ THỐNG" -ForegroundColor Cyan
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
Write-Host "    [OK] Đã dọn dẹp các tệp tin tạm thời." -ForegroundColor Green

# ==========================================
# BẢNG TỔNG KẾT (SUMMARY REPORT) CHUYÊN NGHIỆP
# ==========================================
Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "                  BÁO CÁO KẾT QUẢ CÀI ĐẶT HỆ THỐNG                    " -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "  [ + ] Trạng thái Google Chrome : " -NoNewline; Write-Host "$chromeStatus" -ForegroundColor Cyan
Write-Host "  [ + ] Trạng thái UniKey        : " -NoNewline; Write-Host "$unikeyStatus" -ForegroundColor Cyan
Write-Host "  [ + ] Số lượng font chữ đã cài : " -NoNewline; Write-Host "$fontCount font" -ForegroundColor Cyan
Write-Host "---------------------------------------------------------------------" -ForegroundColor Green
Write-Host "  [+] Quá trình thiết lập máy mới đã hoàn tất xuất sắc!" -ForegroundColor White
Write-Host "  [+] Cửa sổ này sẽ tự động đóng lại sau 10 giây..." -ForegroundColor Yellow
Write-Host "=====================================================================" -ForegroundColor Green

Start-Sleep -Seconds 10