# Hướng dẫn chạy script generate_svg.ps1

### Mở PowerShell và chạy:

```powershell
cd "D:\TAKE NOTE FEATURE\CTS\Analysis\Code\md"

.\generate_svg.ps1 -FolderPath ".\MatchMonitorClassificationBySport\puml"

# Or run for all folder
.\generate_svg.ps1 -FolderPath "."
```

## Example specific:

### Generate SVG cho MatchMonitorClassificationBySport:
```powershell
.\generate_svg.ps1 -FolderPath ".\MatchMonitorClassificationBySport\puml"
```

### Generate SVG cho DailyProblemClassificationBySport:
```powershell
.\generate_svg.ps1 -FolderPath ".\DailyProblemClassificationBySport\puml"
```

### Generate SVG cho RealtimeClassificationBySport:
```powershell
.\generate_svg.ps1 -FolderPath ".\RealtimeClassificationBySport\puml"
```

### Generate SVG cho tất cả các diagram:
```powershell
.\generate_svg.ps1 -FolderPath "."
```

## Note:

1. **Execution Policy**: If you get an error about execution policy, run:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

2. **Java**: The script will automatically download PlantUML jar if Java is available. If Java is not available, the online service will be used.


## Troubleshooting:

- **Error "cannot be loaded because running scripts is disabled"**: 
  Run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

- **Error "Java not found"**: 
  The script will automatically use online service, but requires internet connection.

- **Error download PlantUML jar**: 
  https://github.com/plantuml/plantuml/releases

