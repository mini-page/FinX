Add-Type -AssemblyName System.Drawing

$sourcePath = "assets/icon/brand_logo.png"
if (-not (Test-Path $sourcePath)) {
    $sourcePath = "assets/images/FinX_logo.png"
}

Write-Host "Using source image: $sourcePath"

# Load source image
$srcImg = [System.Drawing.Image]::FromFile((Resolve-Path $sourcePath).Path)

# 1. Generate xpens_logo.png (1024x1024, transparent)
$xpensLogo = New-Object System.Drawing.Bitmap 1024, 1024
$g1 = [System.Drawing.Graphics]::FromImage($xpensLogo)
$g1.Clear([System.Drawing.Color]::Transparent)
# Enable high-quality scaling
$g1.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g1.DrawImage($srcImg, 0, 0, 1024, 1024)
$g1.Dispose()
$xpensLogo.Save((Join-Path (Get-Location).Path "assets/images/xpens_logo.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$xpensLogo.Dispose()
Write-Host "Generated assets/images/xpens_logo.png"

# 2. Generate app_icon.png (1024x1024, solid navy #0E1626)
$appIcon = New-Object System.Drawing.Bitmap 1024, 1024
$g2 = [System.Drawing.Graphics]::FromImage($appIcon)
$navyColor = [System.Drawing.Color]::FromArgb(255, 14, 22, 38)
$g2.Clear($navyColor)
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g2.DrawImage($srcImg, 0, 0, 1024, 1024)
$g2.Dispose()
$appIcon.Save((Join-Path (Get-Location).Path "assets/icon/app_icon.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$appIcon.Dispose()
Write-Host "Generated assets/icon/app_icon.png"

# 3. Generate app_icon_fg.png (1024x1024, transparent, logo scaled to 680x680 centered)
$appIconFg = New-Object System.Drawing.Bitmap 1024, 1024
$g3 = [System.Drawing.Graphics]::FromImage($appIconFg)
$g3.Clear([System.Drawing.Color]::Transparent)
$g3.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$fgSize = 680
$offset = [int]((1024 - $fgSize) / 2)
$g3.DrawImage($srcImg, $offset, $offset, $fgSize, $fgSize)
$g3.Dispose()
$appIconFg.Save((Join-Path (Get-Location).Path "assets/icon/app_icon_fg.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$appIconFg.Dispose()
Write-Host "Generated assets/icon/app_icon_fg.png"

# 4. Generate splash_mark.png (512x512, transparent, logo scaled to 300x300 centered)
$splashMark = New-Object System.Drawing.Bitmap 512, 512
$g4 = [System.Drawing.Graphics]::FromImage($splashMark)
$g4.Clear([System.Drawing.Color]::Transparent)
$g4.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$splashSize = 300
$offsetSplash = [int]((512 - $splashSize) / 2)
$g4.DrawImage($srcImg, $offsetSplash, $offsetSplash, $splashSize, $splashSize)
$g4.Dispose()
$splashMark.Save((Join-Path (Get-Location).Path "assets/icon/splash_mark.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$splashMark.Dispose()
Write-Host "Generated assets/icon/splash_mark.png"

$srcImg.Dispose()
Write-Host "All assets successfully generated!"
