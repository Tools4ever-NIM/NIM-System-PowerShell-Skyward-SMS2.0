$Log_MaskableKeys = @(
    'password'
)


#
# System functions
#

function Idm-SystemInfo {
    param (
        # Operations
        [switch] $Connection,
        [switch] $TestConnection,
        [switch] $Configuration,
        # Parameters
        [string] $ConnectionParams
    )

    Log info "-Connection=$Connection -TestConnection=$TestConnection -Configuration=$Configuration -ConnectionParams='$ConnectionParams'"
    
    if ($Connection) {
        @(
            @{
                name = 'host_name'
                type = 'textbox'
                label = 'Server'
                description = 'IP or Hostname of Server'
                value = ''
            }
            @{
                name = 'port'
                type = 'textbox'
                label = 'Port'
                description = 'Instance port'
                value = '22501'
            }
            @{
                name = 'database'
                type = 'textbox'
                label = 'Database'
                description = 'Name of database'
                value = 'SKYWARD'
            }
             @{
                name = 'driver_version'
                type = 'textbox'
                label = 'Driver Version'
                description = 'Version of Progress OpenEdge Driver'
                value = '11.7'
            }
            @{
                name = 'enableVPN'
                type = 'checkbox'
                label = 'Use VPN'
                value = $true
            }
            @{
                name = 'vpnOpenPath'
                type = 'textbox'
                label = 'Open VPN Path'
                description = 'Path to script start connection to vpn'
                value = 'C:\\Tools4ever\\Scripts\\connectSkywardVPN.bat'
            }
            @{
                name = 'vpnClosePath'
                type = 'textbox'
                label = 'Close VPN Path'
                description = 'Path to script close connection to vpn'
                value = 'C:\\Tools4ever\\Scripts\\disconnectSkywardVPN.bat'
            }
            @{
                name = 'user'
                type = 'textbox'
                label = 'Username'
                label_indent = $true
                description = 'User account name to access server'
            }
            @{
                name = 'password'
                type = 'textbox'
                password = $true
                label = 'Password'
                label_indent = $true
                description = 'User account password to access server'
            }
            @{
                name = 'isolation_mode'
                type = 'textbox'
                label = 'Isolation Mode'
                value = 'READ UNCOMMITTED'
            }
            @{
                name = 'array_size'
                type = 'textbox'
                label = 'Array Size'
                value = '50'
            }
            @{
                name = 'enableETWT'
                type = 'checkbox'
                label = 'Enable ETWT'
                value = $true
            }
            @{
                name = 'enableUWCT'
                type = 'checkbox'
                label = 'Enable UWCT'
                value = $true
            }
            @{
                name = 'enableKA'
                type = 'checkbox'
                label = 'Enable KA'
                value = $true
            }
        )
    }

    if ($TestConnection) {
        Open-ProgressDBConnection $ConnectionParams

        $tables = Invoke-ProgressDBCommand "
                SELECT TBL 'Name', 'Table' `"Type`"  
                FROM sysprogress.SYSTABLES_FULL 
                WHERE TBLTYPE = 'T'
                ORDER BY TBL
            "
    }

    if ($Configuration) {
        @()
    }

    Log info "Done"
}


function Idm-OnUnload {
    Close-ProgressDBConnection
}


#
# CRUD functions
#

$ColumnsInfoCache = @{}


function Compose-SqlCommand-SelectColumnsInfo {
    param (
        [string] $Table
    )

    "SELECT * FROM SYSPROGRESS.SYSCOLUMNS WHERE TBL = '$($Table)' "
}


function Idm-Dispatcher {
    param (
        # Optional Class/Operation
        [string] $Class,
        [string] $Operation,
        # Mode
        [switch] $GetMeta,
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams
    )

    Log info "-Class='$Class' -Operation='$Operation' -GetMeta=$GetMeta -SystemParams='$SystemParams' -FunctionParams='$FunctionParams'"

    if ($Class -eq '') {

        if ($GetMeta) {
            #
            # Get all tables and views in database
            #

            Open-ProgressDBConnection $SystemParams

            $tables = Invoke-ProgressDBCommand "
                SELECT TBL 'Name', 'Table' `"Type`"  
                FROM sysprogress.SYSTABLES_FULL 
                WHERE TBLTYPE = 'T'
                ORDER BY TBL
            "

            #
            # Output list of supported operations per table/view (named Class)
            #

            @(
                foreach ($t in $tables) {

                    $primary_key = '' #ProgressDB you have you query primary index to find the primary key. TBD.
                    if ($t.Type -ne 'Table') {
                        # Non-tables only support 'Read'
                        [ordered]@{
                            Class = $t.Name
                            Operation = 'Read'
                            'Source type' = $t.Type
                            'Primary key' = $primary_key
                            'Supported operations' = 'R'
                        }
                    }
                    else {
                        [ordered]@{
                            Class = $t.Name
                            Operation = 'Create'
                        }

                        [ordered]@{
                            Class = $t.Name
                            Operation = 'Read'
                            'Source type' = $t.Type
                            'Primary key' = $primary_key
                            'Supported operations' = "CR$(if ($primary_key) { 'UD' } else { '' })"
                        }

                        if ($primary_key) {
                            # Only supported if primary key is present
                            [ordered]@{
                                Class = $t.Name
                                Operation = 'Update'
                            }

                            [ordered]@{
                                Class = $t.Name
                                Operation = 'Delete'
                            }
                        }
                    }
                }
            )

        }
        else {
            # Purposely no-operation.
        }

    }
    else {

        if ($GetMeta) {
            #
            # Get meta data
            #

            Open-ProgressDBConnection $SystemParams

            $columns = Invoke-ProgressDBCommand (Compose-SqlCommand-SelectColumnsInfo $Class)

            switch ($Operation) {
                'Create' {
                    @{
                        semantics = 'create'
                        parameters = @(
                            $columns | ForEach-Object {
                                @{
                                    name = $_.COL;
                                    #allowance = if ($_.is_identity -or $_.is_computed) { 'prohibited' } elseif (! $_.is_nullable) { 'mandatory' } else { 'optional' }
                                    allowance = 'optional'
                                }
                            }
                        )
                    }
                    break
                }

                'Read' {
                    @(
                        @{
                            name = 'where_clause'
                            type = 'textbox'
                            label = 'Filter (SQL where-clause)'
                            description = 'Applied SQL where-clause'
                            value = ''
                        }
                        @{
                            name = 'selected_columns'
                            type = 'grid'
                            label = 'Include columns'
                            description = 'Selected columns'
                            table = @{
                                rows = @($columns | ForEach-Object {
                                    @{
                                        name = $_.COL
                                        config = @(
                                            #if ($_.is_primary_key) { 'Primary key' }
                                            #if ($_.is_identity)    { 'Auto identity' }
                                            #if ($_.is_computed)    { 'Computed' }
                                            #if ($_.is_nullable)    { 'Nullable' }
                                        ) -join ' | '
                                    }
                                })
                                settings_grid = @{
                                    selection = 'multiple'
                                    key_column = 'name'
                                    checkbox = $true
                                    filter = $true
                                    columns = @(
                                        @{
                                            name = 'name'
                                            display_name = 'Name'
                                        }
                                        @{
                                            name = 'config'
                                            display_name = 'Configuration'
                                        }
                                    )
                                }
                            }
                            value = @($columns | ForEach-Object { $_.column_name })
                        }
                    )
                    break
                }

                'Update' {
                    @{
                        semantics = 'update'
                        parameters = @(
                            $columns | ForEach-Object {
                                @{
                                    name = $_.column_name;
                                    #allowance = if ($_.is_primary_key) { 'mandatory' } else { 'optional' }
                                    allowance = 'optional'
                                }
                            }
                        )
                    }
                    break
                }

                'Delete' {
                    @{
                        semantics = 'delete'
                        parameters = @(
                            $columns | ForEach-Object {
                                if ($_.is_primary_key) {
                                    @{
                                        name = $_.column_name
                                        allowance = 'mandatory'
                                    }
                                }
                            }
                            @{
                                name = '*'
                                allowance = 'prohibited'
                            }
                        )
                    }
                    break
                }
            }

        }
        else {
            #
            # Execute function
            #

            Open-ProgressDBConnection $SystemParams

            if (! $Global:ColumnsInfoCache[$Class]) {
                $columns = Invoke-ProgressDBCommand (Compose-SqlCommand-SelectColumnsInfo $Class)

                $Global:ColumnsInfoCache[$Class] = @{
                    #primary_key  = @($columns | Where-Object { $_.is_primary_key } | ForEach-Object { $_.column_name })[0]
                    #identity_col = @($columns | Where-Object { $_.is_identity    } | ForEach-Object { $_.column_name })[0]
                    primary_key = ''
                    identity_col = ''
                }
            }

            $primary_key  = $Global:ColumnsInfoCache[$Class].primary_key
            $identity_col = $Global:ColumnsInfoCache[$Class].identity_col

            $function_params = ConvertFrom-Json2 $FunctionParams

            $command = $null

            $projection = if ($function_params['selected_columns'].count -eq 0) { '*' } else { @($function_params['selected_columns'] | ForEach-Object { "`"$_`"" }) -join ', ' }

            switch ($Operation) {
                'Create' {
                    $selection = if ($identity_col) {
                                     "[$identity_col] = SCOPE_IDENTITY()"
                                 }
                                 elseif ($primary_key) {
                                     "[$primary_key] = '$($function_params[$primary_key])'"
                                 }
                                 else {
                                     @($function_params.Keys | ForEach-Object { "`"$_`" = '$($function_params[$_])'" }) -join ' AND '
                                 }

                    $command = "INSERT INTO $Class ($(@($function_params.Keys | ForEach-Object { '"'+$_+'"' }) -join ', ')) VALUES ($(@($function_params.Keys | ForEach-Object { "$(if ($function_params[$_] -ne $null) { "'$($function_params[$_])'" } else { 'null' })" }) -join ', ')); SELECT TOP(1) $projection FROM $Class WHERE $selection"
                    break
                }

                'Read' {
                    $selection = if ($function_params['where_clause'].length -eq 0) { '' } else { " WHERE $($function_params['where_clause'])" }

                    $command = "SELECT $projection FROM `"PUB`".`"$Class`"$selection"
                    break
                }

                'Update' {
                    $command = "UPDATE TOP(1) $Class SET $(@($function_params.Keys | ForEach-Object { if ($_ -ne $primary_key) { "[$_] = $(if ($function_params[$_] -ne $null) { "'$($function_params[$_])'" } else { 'null' })" } }) -join ', ') WHERE [$primary_key] = '$($function_params[$primary_key])'; SELECT TOP(1) [$primary_key], $(@($function_params.Keys | ForEach-Object { if ($_ -ne $primary_key) { "[$_]" } }) -join ', ') FROM $Class WHERE [$primary_key] = '$($function_params[$primary_key])'"
                    break
                }

                'Delete' {
                    $command = "DELETE TOP(1) $Class WHERE [$primary_key] = '$($function_params[$primary_key])'"
                    break
                }
            }

            if ($command) {
                LogIO info ($command -split ' ')[0] -In -Command $command

                if ($Operation -eq 'Read') {
                    # Streamed output
                    Invoke-ProgressDBCommand $command
                }
                else {
                    # Log output
                    $rv = Invoke-ProgressDBCommand $command
                    LogIO info ($command -split ' ')[0] -Out $rv

                    $rv
                }
            }

        }

    }

    Log info "Done"
}


#
# Helper functions
#

function Invoke-ProgressDBCommand {
    param (
        [string] $Command
    )

    function Invoke-ProgressDBCommand-ExecuteReader {
        param (
            [string] $Command
        )
        log debug $Command     
        $sql_command  = New-Object System.Data.Odbc.OdbcCommand($Command, $Global:ProgressDBConnection)
        $data_adapter = New-Object System.Data.Odbc.OdbcDataAdapter($sql_command)
        $data_table   = New-Object System.Data.DataTable
        $data_adapter.Fill($data_table) | Out-Null

        # Output data
        $data_table.Rows | Select $data_table.Columns.ColumnName

        log debug $data_table.Columns

        $data_table.Dispose()
        $data_adapter.Dispose()
        $sql_command.Dispose()
    }
    $Command = ($Command -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }) -join ' '

    try {
        Invoke-ProgressDBCommand-ExecuteReader $Command
    }
    catch {
        Log error "Failed: $_"
        Write-Error $_
    }
}


function Open-ProgressDBConnection {
    param (
        [string] $ConnectionParams
    )

    $connection_params = ConvertFrom-Json2 $ConnectionParams

    $connection_string =  "DRIVER={Progress OpenEdge $($connection_params.driver_version) driver};HOST=$($connection_params.host_name);PORT=$($connection_params.port);DB=$($connection_params.database);UID=$($connection_params.user);PWD=$($connection_params.password);DIL=$($connection_params.isolation_mode);AS=$($connection_params.array_size)"
    
    if($connection_params.enableETWT) { $connectionString += "ETWT=1;" }
    if($connection_params.enableUWCT) { $connectionString += "UWCT=1;" }
    if($connection_params.enableKA) { $connectionString += "KA=1;" }
    LOG info $connection_string
    
    if ($Global:ProgressDBConnection -and $connection_string -ne $Global:ProgressDBConnectionString) {
        Log info "ProgressDBConnection connection parameters changed"
        Close-ProgressDBConnection
    }

    if ($Global:ProgressDBConnection -and $Global:ProgressDBConnection.State -ne 'Open') {
        Log warn "ProgressDBConnection State is '$($Global:ProgressDBConnection.State)'"
        Close-ProgressDBConnection
    }

    Log info "Opening ProgressDBConnection '$connection_string'"

    try {
        $connection = (new-object System.Data.Odbc.OdbcConnection);
        $connection.connectionstring = $connection_string
        $connection.open();

        $Global:ProgressDBConnection       = $connection
        $Global:ProgressDBConnectionString = $connection_string

        $Global:ColumnsInfoCache = @{}
    }
    catch {
        Log warn "Failed: $_"
        #Write-Error $_
    }

    Log info "Done"
    
}


function Close-ProgressDBConnection {
    if ($Global:ProgressDBConnection) {
        Log info "Closing ProgressDBConnection"

        try {
            $Global:ProgressDBConnection.Close()
            $Global:ProgressDBConnection = $null
        }
        catch {
            # Purposely ignoring errors
        }

        Log info "Done"
    }
}
