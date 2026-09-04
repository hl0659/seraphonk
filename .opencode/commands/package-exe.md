# package-exe — Windows build
1. Run `python -m pytest -q` + smoke. Stop if red.
2. Run `powershell -ExecutionPolicy Bypass -File tools/build_exe.ps1`
3. Report `dist/Seraphonk.exe` size + smoke output.
