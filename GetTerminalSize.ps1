# Query the current terminal buffer size
$columns = [Console]::WindowWidth
$rows = [Console]::WindowHeight

Write-Output "Terminal Dimensions:"
Write-Output "Columns (Width): $columns"
Write-Output "Rows (Height): $rows"
