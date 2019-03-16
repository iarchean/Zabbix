############################################################################
#
#
#  Author:              Archean Zhang
#  Email:               zephyr422@gmail.com
#  Blog:                https://archeanz.com/2019/03/17/moniting-exchange-server-with-zabbix
#  Date created:        15/03/2019
#  Version:             2.0
#  Description:         Get Exchange mailbox database parameters and save to csv&json files
#                                                

$myDir                  = Split-Path -Parent $MyInvocation.MyCommand.Path
$filepath               = "$myDir\DBStatus\"

If(!(test-path $filepath)) {New-Item -ItemType Directory $filepath}

$hostName               = Get-WmiObject -Class Win32_ComputerSystem | %{$_.Name}
$dbList                 = $myDir + "\DBStatus\" + $hostname + "_ExchangeDbList.csv"
$ParametersDatabases    = @()



#Add Exchange 2010 snapin if not already loaded
if (!(Get-PSSnapin | where {$_.Name -eq "Microsoft.Exchange.Management.PowerShell.E2010"}))
{
    Write-Verbose "Loading Exchange 2010 Snapin"
    Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010 -ErrorAction SilentlyContinue
}


$dbsonserver = @(Get-MailboxDatabaseCopyStatus -server $hostName | Where {$_.ActivationPreference -ne 1}).DatabaseName
$dbs = @( foreach ($dbonserver in $dbsonserver) {Get-MailboxDatabase -identity $dbonserver -status} )

foreach ($db in $dbs)
{
$datetime                   = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
$dbStatistics               = $db | Get-MailboxStatistics |
                                select @{Name="TotalItemSize";Expression={$_.Totalitemsize.Value.ToMb()}},
                                @{Name="TotalDeletedItemSize";Expression={$_.TotalDeletedItemSize.Value.ToMb()}},
                                itemcount | measure-object TotalItemSize, itemCount, TotalDeletedItemSize -Sum
$itemCount                  = ($dbStatistics | where-object {$_.property -eq "ItemCount"}).Sum
$TotalItemSize              = [math]::Round((($dbStatistics | where-object {$_.property -eq "TotalItemSize"}).Sum)/1024)
$TotalDeletedItemSize       = [math]::Round((($dbStatistics | where-object {$_.property -eq "TotalDeletedItemSize"}).Sum)/1024)
$mailboxcount               = (($db | Get-Mailbox -resultsize unlimited).count + 1 )

$mountstatus                = @($db | Get-MailboxDatabaseCopyStatus | Where {$_.status -like "*ount*"}).status
$copystatus                 = @($db | Get-MailboxDatabaseCopyStatus | Where {$_.status -notlike "*ount*"}).status

$mailboxdisk                = (get-mailboxdatabase $db).EdbFilePath.Drivename
$mailboxserver              = $db.server.name
$diskfreespace              = (Get-WmiObject Win32_LogicalDisk -ComputerName $mailboxserver -Filter "DeviceID='$mailboxdisk'" | Foreach-Object {$_.FreeSpace  / 1GB}).ToString("0.0")
$diskcapacity               = (Get-WmiObject Win32_LogicalDisk -ComputerName $mailboxserver -Filter "DeviceID='$mailboxdisk'" | Foreach-Object {$_.Size  / 1GB}).ToString("0.0")
$useablespace               = $db.AvailableNewMailboxSpace.ToGb()+$diskfreespace


$ParametersDatabase = New-Object -TypeName PSObject
$ParametersDatabase | Add-Member -MemberType NoteProperty -Name ts              -Value $datetime
$ParametersDatabase | Add-Member -MemberType NoteProperty -Name name            -Value $db.name
$ParametersDatabase | Add-Member -MemberType NoteProperty -Name server          -Value $db.server.name
$ParametersDatabase | Add-Member -MemberType NoteProperty -Name guid            -Value $db.guid
$ParametersDatabase | Add-Member -MemberType NoteProperty -Name mounted         -Value $mountstatus
$ParametersDatabase | Add-Member -MemberType NoteProperty -Name copystatus      -Value $copystatus
$ParametersDatabase | Add-Member -MemberType NoteProperty -Name mailboxcount    -Value $mailboxcount
$ParametersDatabase | Add-Member -MemberType NoteProperty -Name itemcount       -Value $itemCount
$ParametersDatabase | Add-Member -MemberType NoteProperty -Name dbsize          -Value $db.DatabaseSize.ToGb()
$ParametersDatabase | Add-Member -MemberType NoteProperty -Name anmbs           -Value $db.AvailableNewMailboxSpace.ToGb()
$ParametersDatabase | Add-Member -MemberType NoteProperty -Name tis             -Value $TotalItemSize
$ParametersDatabase | Add-Member -MemberType NoteProperty -Name tdis            -Value $TotalDeletedItemSize
$ParametersDatabase | Add-Member -MemberType NoteProperty -Name uas             -Value $useablespace
$ParametersDatabase | Add-Member -MemberType NoteProperty -Name dc              -Value $diskcapacity

$ParametersDatabases += $ParametersDatabase

}

$ParametersDatabases | Export-csv $dbList -NoTypeInformation