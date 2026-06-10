# PowerShell script to generate SVG from PlantUML files
# Usage: .\generate_svg.ps1 [folder_path]

param(
    [string]$FolderPath = "."
)

# Check if Java is available
$javaAvailable = $false
try {
    $null = java -version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $javaAvailable = $true
        Write-Host "Java is available" -ForegroundColor Green
    }
} catch {
    Write-Host "Java is not available" -ForegroundColor Yellow
}

# Function to download PlantUML jar
function Download-PlantUML {
    $jarPath = "$PSScriptRoot\plantuml.jar"
    if (-not (Test-Path $jarPath)) {
        Write-Host "Downloading PlantUML jar..." -ForegroundColor Yellow
        $url = "https://github.com/plantuml/plantuml/releases/download/v1.2024.5/plantuml-1.2024.5.jar"
        try {
            Invoke-WebRequest -Uri $url -OutFile $jarPath -UseBasicParsing
            Write-Host "PlantUML jar downloaded successfully" -ForegroundColor Green
        } catch {
            Write-Host "Failed to download PlantUML jar. Error: $_" -ForegroundColor Red
            return $false
        }
    }
    return $true
}

# Function to generate SVG using PlantUML jar
function Generate-SVG-FromJar {
    param(
        [string]$PumlFile,
        [string]$JarPath
    )
    
    $outputDir = Split-Path -Parent $PumlFile
    
    # Extract diagram name from @startuml tag
    $pumlContent = Get-Content $PumlFile -Raw -ErrorAction SilentlyContinue
    $diagramName = ""
    if ($pumlContent -match '@startuml\s+(\S+)') {
        $diagramName = $matches[1]
    }
    
    # If no name found in @startuml, use filename
    if ([string]::IsNullOrEmpty($diagramName)) {
        $diagramName = [System.IO.Path]::GetFileNameWithoutExtension($PumlFile)
    }
    
    $svgFile = Join-Path $outputDir "$diagramName.svg"
    $expectedSvgFile = $PumlFile -replace '\.puml$', '.svg'
    
    Write-Host "Generating SVG: $svgFile" -ForegroundColor Cyan
    
    try {
        $errorFile = "$env:TEMP\plantuml_error_$(Get-Random).txt"
        $outputFile = "$env:TEMP\plantuml_output_$(Get-Random).txt"
        
        & java -jar $JarPath -tsvg -o $outputDir $PumlFile 2>$errorFile 1>$outputFile
        
        if ($LASTEXITCODE -eq 0) {
            # Check for SVG file with diagram name or expected filename
            $foundSvg = $false
            if (Test-Path $svgFile) {
                Write-Host "  ✓ Success: $svgFile" -ForegroundColor Green
                $foundSvg = $true
            } elseif (Test-Path $expectedSvgFile) {
                Write-Host "  ✓ Success: $expectedSvgFile" -ForegroundColor Green
                $foundSvg = $true
            } else {
                Write-Host "  ✗ Failed: SVG file not created" -ForegroundColor Red
                $errorContent = Get-Content $errorFile -ErrorAction SilentlyContinue
                if ($errorContent) {
                    Write-Host "    Error: $($errorContent -join ' ')" -ForegroundColor Yellow
                }
                Remove-Item $errorFile -ErrorAction SilentlyContinue
                Remove-Item $outputFile -ErrorAction SilentlyContinue
                return $false
            }
            Remove-Item $errorFile -ErrorAction SilentlyContinue
            Remove-Item $outputFile -ErrorAction SilentlyContinue
            return $foundSvg
        } else {
            $errorContent = Get-Content $errorFile -ErrorAction SilentlyContinue
            if ($errorContent) {
                Write-Host "  Failed: $($errorContent -join ' ')" -ForegroundColor Red
            } else {
                Write-Host "  Failed: ExitCode $LASTEXITCODE" -ForegroundColor Red
            }
            Remove-Item $errorFile -ErrorAction SilentlyContinue
            Remove-Item $outputFile -ErrorAction SilentlyContinue
            return $false
        }
    } catch {
        Write-Host "  Error: $_" -ForegroundColor Red
        return $false
    }
}

# Function to generate SVG using online service (fallback)
function Generate-SVG-Online {
    param(
        [string]$PumlFile
    )
    
    $svgFile = $PumlFile -replace '\.puml$', '.svg'
    $pumlContent = Get-Content $PumlFile -Raw -Encoding UTF8
    
    # Encode PlantUML content for URL
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pumlContent))
    $encoded = $encoded -replace '\+', '-' -replace '/', '_' -replace '=', ''
    
    $url = "http://www.plantuml.com/plantuml/svg/$encoded"
    
    Write-Host "Generating SVG (online): $svgFile" -ForegroundColor Cyan
    
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30
        if ($response.StatusCode -eq 200) {
            $response.Content | Out-File -FilePath $svgFile -Encoding UTF8
            Write-Host "  Success: $svgFile" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  Failed: HTTP $($response.StatusCode)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "  Error: $_" -ForegroundColor Red
        return $false
    }
}

# Main execution
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PlantUML to SVG Generator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Resolve folder path
if (-not (Test-Path $FolderPath)) {
    Write-Host "Error: Folder not found: $FolderPath" -ForegroundColor Red
    exit 1
}

$fullPath = Resolve-Path $FolderPath
Write-Host "Processing folder: $fullPath" -ForegroundColor Yellow
Write-Host ""

# Find all .puml files
$pumlFiles = Get-ChildItem -Path $fullPath -Filter "*.puml" -Recurse

if ($pumlFiles.Count -eq 0) {
    Write-Host "No .puml files found in: $fullPath" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($pumlFiles.Count) .puml file(s)" -ForegroundColor Yellow
Write-Host ""

# Try to use PlantUML jar if Java is available
$useJar = $false
$jarPath = ""

if ($javaAvailable) {
    $jarPath = "$PSScriptRoot\plantuml.jar"
    if (Test-Path $jarPath) {
        $useJar = $true
        Write-Host "Using PlantUML jar: $jarPath" -ForegroundColor Green
    } elseif (Download-PlantUML) {
        $useJar = $true
        $jarPath = "$PSScriptRoot\plantuml.jar"
        Write-Host "Using PlantUML jar: $jarPath" -ForegroundColor Green
    } else {
        Write-Host "Falling back to online service" -ForegroundColor Yellow
    }
} else {
    Write-Host "Java not available, using online service" -ForegroundColor Yellow
}

Write-Host ""

# Generate SVG for each file
$successCount = 0
$failCount = 0

foreach ($file in $pumlFiles) {
    if ($useJar) {
        if (Generate-SVG-FromJar -PumlFile $file.FullName -JarPath $jarPath) {
            $successCount++
        } else {
            $failCount++
        }
    } else {
        if (Generate-SVG-Online -PumlFile $file.FullName) {
            $successCount++
        } else {
            $failCount++
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Success: $successCount" -ForegroundColor Green
Write-Host "Failed:  $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-Host ""
