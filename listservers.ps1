Get-ADComputer -Filter 'operatingsystem -like "*server*" -and enabled -eq "true"' -Property Name | 
ForEach-Object {
    try {
        $ip = (Resolve-DnsName $_.Name -ErrorAction Stop | Where-Object { $_.QueryType -eq "A" }).IPAddress
    } catch {
#        $ip = "No DNS Entry"
    }
    [PSCustomObject]@{
#        Name = $_.Name
        IP   = $ip
    }
} | Format-Table -AutoSize
