############################################################################
#
#
#  Author:              Archean Zhang
#  Email:               zephyr422@gmail.com
#  Blog:                https://archeanz.com/2019/03/17/moniting-exchange-server-with-zabbix
#  Date created:        15/03/2019
#  Version:             2.0
#  Description:         Zabbix discover script, return json data
#      

$myDir                  = Split-Path -Parent $MyInvocation.MyCommand.Path
$hostName               = Get-WmiObject -Class Win32_ComputerSystem | %{$_.Name}
$dbList  				= $myDir + "\DBStatus\" + $hostname + "_ExchangeDbList.csv"
$Dbs		  			= Import-csv -path $DbList

$dbsCount=$dbs.length

Write-Host "{"
Write-Host '"data":'
Write-Host "["

$i=0
	foreach ($db in $dbs)
	{
        $i += 1
	$dbJsonServer='"{#SERVER}":"'+$db.Server+'", '
	$dbJsonName='"{#MBNAME}":"'+$db.name+'", '
	$dbJsonGUID='"{#MBGUID}":"'+$db.Guid+'" '
        Write-Host "{"
	Write-Host $dbJsonServer
	Write-Host $dbJsonName
	Write-Host $dbJsonGUID

	if ($i -lt $dbsCount)
	{
	Write-Host "},"
	}
	else
	{
	Write-Host "}"
	}

}


Write-Host "]"
Write-Host "}"
