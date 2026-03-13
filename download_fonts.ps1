$fonts = @(
    @{
        Url  = "https://github.com/google/fonts/raw/main/ofl/cairo/Cairo-Black.ttf"
        Path = "assets/fonts/Cairo-Black.ttf"
    },
    @{
        Url  = "https://github.com/google/fonts/raw/main/ofl/tajawal/Tajawal-Medium.ttf"
        Path = "assets/fonts/Tajawal-Medium.ttf"
    },
    @{
        Url  = "https://github.com/google/fonts/raw/main/ofl/tajawal/Tajawal-Bold.ttf"
        Path = "assets/fonts/Tajawal-Bold.ttf"
    }
)

foreach ($font in $fonts) {
    Write-Host "Downloading $($font.Url)..."
    try {
        Invoke-WebRequest -Uri $font.Url -OutFile $font.Path
        Write-Host "Downloaded to $($font.Path)"
    }
    catch {
        Write-Host "Failed to download $($font.Url): $_"
    }
}
