# Build Windows .exe via PyInstaller. Run from repo root.
pyinstaller --noconfirm --onefile --windowed --name Seraphonk game/main.py
Write-Host "dist/Seraphonk.exe ready — smoke it before sharing."
.\dist\Seraphonk.exe --smoke
