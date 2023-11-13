param(
    [Parameter(mandatory=$true)] [string] $GroupName, 
    [Parameter(mandatory=$true)] [string] $GroupOU, 
    [Parameter(mandatory=$true)] [string] $SnowflakeRole,
    [Parameter(mandatory=$true)] [string] $SnowflakeConnectionName,
    [string] $ExcludeUsers,
    [string] $SnowflakeScriptResultsFile
)

Function GetCurrentDomainPath()
{
    [System.DirectoryServices.DirectoryEntry]$de = New-Object System.DirectoryServices.DirectoryEntry("LDAP://RootDSE")
    If ($de -ne $Null -and $de.Properties.Count -gt 0)
    {
        return "LDAP://" + $de.Properties["defaultNamingContext"][0].ToString()
    } Else {
        return $Null
    }
}


Function GetDirecotryEntry()
{
    $ldapUri = GetCurrentDomainPath
    If ($ldapUri -ne $Null)
    {
        [System.DirectoryServices.DirectoryEntry]$de = New-Object System.DirectoryServices.DirectoryEntry($ldapUri)
        return $de
    } Else {
        return $Null
    }
}


Function SearchAD($de, $groupName, $groupOuPath, $excludeUserNamesList)
{
    #    "(!(sAMAccountName:=$exclude))"
    $excludePart = ""
    If ($excludeUserNamesList -ne $null -and $excludeUserNamesList.Length -gt 0)
    {
        ForEach($u in $excludeUserNamesList)
        {
            $excludePart = "$excludePart (!(sAMAccountName:=$($u.Trim())))"
        }
    }
    #$query = "(&(objectClass=user) -- LDAP_QUERY_EXTRA -- (objectCategory=person) (memberOf=CN=%GROUP_NAME%,OU=PLUTO,OU=Security Groups,OU=Groups,DC=groupnet,DC=gr) )"
    $query = "(&(objectClass=user) $excludePart (objectCategory=person) (memberOf=CN=$groupName,$groupOuPath) )"
    Write-Host "AD Query: $query"
    [System.DirectoryServices.DirectorySearcher]$searcher = New-Object System.DirectoryServices.DirectorySearcher($de)
    
    $searcher.Filter = $query;

    $results = $searcher.FindAll()

    return $results
}


Function ListAttributes($results, $attributesList)
{
    #ForEach($attr in $attributesList)
    #{
    #    Write-Host "Attribute: $attr"
    #}
    $list = [System.Collections.ArrayList]@()
    
    ForEach($result in $results)
    {
        [System.DirectoryServices.DirectoryEntry]$de = $result.GetDirectoryEntry()
        Write-Host "# Props: $($de.Properties.Count) - $($de.Path)"
        
        $userProps = [System.Collections.ArrayList]@()
         
        ForEach($attr in $attributesList)
        {
            Write-Host "    $($de.Properties[$attr])"
            
            $userProps.Add($de.Properties[$attr].Value) | Out-Null
        }
        
        $list.Add($userProps) | Out-Null
    }
    #Write-Host "Users List Count: $($list.Count)"

    return $list
}


Function CreateSnowflakeUserSqlScript($usersList, $filePath, $sfRoleName)
{
    $sqlUser = "CREATE USER IF NOT EXISTS {0} PASSWORD = '' LOGIN_NAME = '{1}' DISPLAY_NAME = '{2}' DEFAULT_SECONDARY_ROLES = ('ALL');"
    $sqlGrant = "GRANT ROLE {0} TO USER {1};"
    
    If (Test-Path -Path $filePath)
    {
        Remove-Item -Path $filePath
    }
        
    $results = [System.Collections.ArrayList]@()
    ForEach($u In $usersList) {
        If ($u.Count -eq 3)
        {
            $paramUserName = $u[0]
            $paramDisplayName = $u[1]
            $paramEmail = $u[2]
        
            If ((-not [String]::IsNullOrWhitespace($paramUserName)) -and (-not [String]::IsNullOrWhitespace($paramEmail)))
            {
                $line = [String]::Format($sqlUser, $paramUserName, $paramEmail, $paramDisplayName.Replace("'", " "))
                $results.Add("OK: $paramUserName - Create User")

                Add-Content -Path $filePath -Value $line
                
                If (-not [String]::IsNullOrWhitespace($sfRoleName))
                {
                    $line = [String]::Format($sqlGrant, $sfRoleName, $paramUserName)
                    $results.Add("OK: $paramUserName - Grant User")
                    
                    Add-Content -Path $filePath -Value $line
                }
            }
            Else
            {
                $results.Add("WARN: $paramUserName : Username or Email is empty")
            }
        }
        Else
        {
            $results.Add("ERROR: $($u[0]) : Invalid numbers of user properties (array elements): $($u.Count)")
        }
    }
    return $results
}


Function GetSnowSqlExecutablePath()
{
    $SnowSql = "$Env:Programfiles\Snowflake SnowSQL\snowsql.exe"
    If (-not (Test-Path $SnowSql)) {
        $SnowSql = $Null
    }
    return $SnowSql
}


Function HandleProxySettings()
{
    $proxy = "$Env:http_proxy"
    If (-not ([string]::IsNullOrWhitespace($proxy))) {
        $response = Read-Host "Proxy settings detected (http_proxy variable). Press 'Y' key to continue with existing settings, or 'N' to cleanup settings"
        
        If ($response -eq "N" -or $response -eq "n") {
            $Env:http_proxy = ""
            $Env:https_proxy = ""
        }
    }
    return $SnowSql
}


$de = GetDirecotryEntry

Write-Host

If ($de -ne $null)
{
    Write-Host "LDAP Path: $($de.Path)"

    $paramExcludeUsers = ("user1", "user2")

    If (-not [String]::IsNullOrWhitespace($GroupName))
    {
        $paramGroupName = $GroupName
    }

    If (-not [String]::IsNullOrWhitespace($GroupOU))
    {
        $paramGroupOU = $GroupOU
    }

    If (-not [String]::IsNullOrWhitespace($SnowflakeRole))
    {
        $paramSnowflakeRole = $SnowflakeRole
    }

    If (-not [String]::IsNullOrWhitespace($SnowflakeConnectionName))
    {
        $paramSnowflakeConnectionName = $SnowflakeConnectionName
    }

    $paramSnowflakeScriptResultsFile = "_tmp_$($paramGroupName)_sql_result.csv"

    If (-not [String]::IsNullOrWhitespace($SnowflakeScriptResultsFile))
    {
        $paramSnowflakeScriptResultsFile = $SnowflakeScriptResultsFile
    }

    If (-not [String]::IsNullOrWhitespace($ExcludeUsers))
    {
        $paramExcludeUsers = $ExcludeUsers.Split(",")
    }

    Write-Host
    Write-Host "GroupName: $paramGroupName"
    Write-Host "Group OU : $paramGroupOU"
    Write-Host "SF Role  : $paramSnowflakeRole"
    Write-Host "SF Conn  : $paramSnowflakeConnectionName"
    Write-Host

    ForEach($u in $paramExcludeUsers)
    {
        Write-Host "Exclude User: $u"
    }

    Write-Host

    $results = SearchAD $de $paramGroupName $paramGroupOU $paramExcludeUsers

    Write-Host "# AD Results: $($results.Count)"
    Write-Host

    Write-Host "-----------------------------------------------------------------"
    $usersList = ListAttributes $results ("sAMAccountName", "displayName", "mail")

    Write-Host
    Write-Host "-----------------------------------------------------------------"
    Write-Host
    Write-Host "Creating sql script file ..."

    $filePath = "_tmp_$paramGroupName.sql"
    $scriptResults = CreateSnowflakeUserSqlScript $usersList $filePath $paramSnowflakeRole

    If (Test-Path -Path $filePath)
    {
        Write-Host
        Write-Host "-----------------------------------------------------------------"
        Write-Host "Sql script:"
        Write-Host
        Get-Content -Path $filePath | Write-Host
        Write-Host
        
        
        $executeSFScript = Read-Host "Press 'Y' key to continue with SF role assignemnt"
        If ($executeSFScript -eq "Y" -or $executeSFScript -eq "y") {
            $SnowSql = GetSnowSqlExecutablePath
            If ($SnowSql -ne $Null) {
                HandleProxySettings
                
                & "$SnowSql" -c $paramSnowflakeConnectionName -f $filePath -o output_file=$paramSnowflakeScriptResultsFile -o quiet=false -o friendly=true -o header=true -o output_format=csv
            }
        }
    }
} Else {
    Write-Host "Cannot connect to LDAP" -ForegroundColor Yellow
}
