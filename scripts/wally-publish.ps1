foreach ($dir in Get-ChildItem -Path "modules" -Directory) {
    Push-Location $dir.FullName
    wally publish
    Pop-Location
}
