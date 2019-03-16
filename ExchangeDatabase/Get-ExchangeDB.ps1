############################################################################
#
#
#  Author:              Archean Zhang
#  Email:               zephyr422@gmail.com
#  Blog:                https://archeanz.com/2019/03/17/moniting-exchange-server-with-zabbix
#  Date created:        15/03/2019
#  Version:             2.0
#  Description:         Get Exchange mailbox database parameters from CSV files
#      

param([string]$p1,[string]$pdb)

$myDir                  = Split-Path -Parent $MyInvocation.MyCommand.Path
$hostName               = Get-WmiObject -Class Win32_ComputerSystem | %{$_.Name}
$dbList                 = $myDir + "\DBStatus\" + $hostname + "_ExchangeDbList.csv"

$dbs		= Import-csv -path $DbList
$db 		= $dbs | where { $_.guid -eq $pdb}

  # Mounted
	if ($p1 -eq "mounted" )
		{
		Write-Host  $db.mounted
		}

  # Copy Status
  if ($p1 -eq "copystatus")
   {
   Write-Host $db.copystatus
   }
  
  # Usable space
  if ($p1 -eq "uas")
   {
   Write-Host $db.uas
   }

	# DB size
	if ($p1 -eq "dbsize" )
	{
		Write-Host $db.dbsize
	}

	# Available new mailboxes space
	if ($p1 -eq "anmbs" )
	{
		Write-Host $db.anmbs
	}

	# Item count
	if ($p1 -eq "itemcount" )
	{
		Write-Host $db.itemcount
	}

	# Total Item Size
	if ($p1 -eq "tis" )
	{
		write-Host $db.tis
	}

	# Total Deleted Item Size
	if ($p1 -eq "tdis" )
	{
		write-Host $db.tdis
	}

	# Total mailboxes
	if ($p1 -eq "mailboxcount" )
	{
		Write-Host $db.mailboxcount
	}
