$dir = 'd:\PERSONAL\docs\obsidian\CAREER'
$files = Get-ChildItem -Path $dir -Recurse -Filter *.md

$total = 0
$missingFrontmatter = 0
$missingMasteryCheck = 0

foreach ($file in $files) {
    if ($file.Name -match '^_') { continue } # Skip files like _main.md
    $total++
    $content = Get-Content $file.FullName -Raw
    
    if (-not ($content -match '(?s)^---.*?---')) {
        $missingFrontmatter++
    }
    
    if (-not ($content -match 'Mastery Check')) {
        $missingMasteryCheck++
    }
}

$result = @{
    Total = $total
    MissingFrontmatter = $missingFrontmatter
    MissingMasteryCheck = $missingMasteryCheck
}

$result | ConvertTo-Json | Out-File 'd:\PERSONAL\docs\obsidian\CAREER\analysis.json'
