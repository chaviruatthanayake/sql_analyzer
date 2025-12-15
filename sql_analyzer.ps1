# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "SQL Server Configuration Analyzer"
$form.Size = New-Object System.Drawing.Size(900,600)
$form.StartPosition = "CenterScreen"

# Server name label and textbox
$labelServer = New-Object System.Windows.Forms.Label
$labelServer.Text = "SQL Server Name:"
$labelServer.Location = New-Object System.Drawing.Point(20,20)
$labelServer.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($labelServer)

$textBoxServer = New-Object System.Windows.Forms.TextBox
$textBoxServer.Location = New-Object System.Drawing.Point(150,20)
$textBoxServer.Size = New-Object System.Drawing.Size(700,20)
$form.Controls.Add($textBoxServer)

# RichTextBox for colorful output
$richTextBoxOutput = New-Object System.Windows.Forms.RichTextBox
$richTextBoxOutput.Location = New-Object System.Drawing.Point(20,60)
$richTextBoxOutput.Size = New-Object System.Drawing.Size(840,450)
$richTextBoxOutput.ReadOnly = $true
$richTextBoxOutput.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($richTextBoxOutput)

# Button to run analysis
$buttonRun = New-Object System.Windows.Forms.Button
$buttonRun.Text = "Run Analysis"
$buttonRun.Location = New-Object System.Drawing.Point(20,520)
$buttonRun.Size = New-Object System.Drawing.Size(100,30)
$form.Controls.Add($buttonRun)

# Helper function to append colored text
function Append-ColoredText {
    param (
        [System.Windows.Forms.RichTextBox]$box,
        [string]$text,
        [System.Drawing.Color]$color,
        [bool]$bold = $false
    )
    $start = $box.TextLength
    $box.AppendText($text + "`r`n")
    $box.Select($start, $text.Length)
    $box.SelectionColor = $color
    if ($bold) {
        $box.SelectionFont = New-Object System.Drawing.Font($box.Font, [System.Drawing.FontStyle]::Bold)
    }
    $box.Select($box.TextLength, 0)
    $box.ScrollToCaret()
}

# Action on button click
$buttonRun.Add_Click({
    $serverName = $textBoxServer.Text
    if ([string]::IsNullOrWhiteSpace($serverName)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a SQL Server name.", "Input Error")
        return
    }
    
    try {
        # Load SMO
        [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
        $server = New-Object Microsoft.SqlServer.Management.Smo.Server $serverName
        
        # Set connection properties
        $server.ConnectionContext.ConnectTimeout = 30
        $server.ConnectionContext.StatementTimeout = 60
        
        # Force connection
        $null = $server.Version
        
        $richTextBoxOutput.Clear()
        Append-ColoredText $richTextBoxOutput "SQL Server Analysis for: $serverName" ([System.Drawing.Color]::Blue) $true
        Append-ColoredText $richTextBoxOutput "Server Name: $($server.Name)" ([System.Drawing.Color]::DarkGreen) $true
        Append-ColoredText $richTextBoxOutput "Machine Name: $($server.ComputerNamePhysicalNetBIOS)" ([System.Drawing.Color]::DarkGreen) $true
        Append-ColoredText $richTextBoxOutput "Edition: $($server.Edition)" ([System.Drawing.Color]::DarkGreen) $true
        Append-ColoredText $richTextBoxOutput "Version: $($server.VersionString)" ([System.Drawing.Color]::DarkGreen) $true
        Append-ColoredText $richTextBoxOutput "Product Level: $($server.ProductLevel)" ([System.Drawing.Color]::DarkGreen) $true
        Append-ColoredText $richTextBoxOutput "Processors: $($server.Processors)" ([System.Drawing.Color]::DarkGreen) $true
        Append-ColoredText $richTextBoxOutput "Physical Memory: $($server.PhysicalMemory) MB" ([System.Drawing.Color]::DarkGreen) $true
        Append-ColoredText $richTextBoxOutput "Max Server Memory: $($server.Configuration.MaxServerMemory.RunValue) MB" ([System.Drawing.Color]::DarkGreen) $true
        Append-ColoredText $richTextBoxOutput "Min Server Memory: $($server.Configuration.MinServerMemory.RunValue) MB" ([System.Drawing.Color]::DarkGreen) $true
        
        # System databases to exclude
        $systemDatabases = @('master', 'model', 'msdb', 'tempdb')
        
        # Get list of user databases using SQL query
        $userDatabaseNames = @()
        try {
            $query = "SELECT name FROM sys.databases WHERE name NOT IN ('master', 'model', 'msdb', 'tempdb') ORDER BY name"
            $result = $server.ConnectionContext.ExecuteWithResults($query)
            foreach ($row in $result.Tables[0].Rows) {
                $userDatabaseNames += $row["name"]
            }
        } catch {
            Append-ColoredText $richTextBoxOutput "`r`nError getting database list: $($_.Exception.Message)" ([System.Drawing.Color]::Red) $false
        }
        
        # Get total database count using SQL query
        $totalDbCount = 0
        try {
            $totalDbQuery = "SELECT COUNT(*) AS DbCount FROM sys.databases"
            $totalDbResult = $server.ConnectionContext.ExecuteWithResults($totalDbQuery)
            $totalDbCount = $totalDbResult.Tables[0].Rows[0]["DbCount"]
        } catch {
            $totalDbCount = "Unknown"
        }
        
        Append-ColoredText $richTextBoxOutput "`r`nUser Databases: $($userDatabaseNames.Count)" ([System.Drawing.Color]::Blue) $true
        Append-ColoredText $richTextBoxOutput "Total Databases (including system): $totalDbCount" ([System.Drawing.Color]::Blue) $false
        
        foreach ($dbName in $userDatabaseNames) {
            try {
                Append-ColoredText $richTextBoxOutput "`r`nDatabase: $dbName" ([System.Drawing.Color]::DarkRed) $true
                
                # Get database size
                try {
                    $sizeQuery = @"
USE [$dbName];
SELECT SUM(CAST(size AS BIGINT) * 8 / 1024.0) AS SizeMB FROM sys.database_files;
"@
                    $sizeResult = $server.ConnectionContext.ExecuteWithResults($sizeQuery)
                    if ($sizeResult.Tables[0].Rows.Count -gt 0 -and $null -ne $sizeResult.Tables[0].Rows[0]["SizeMB"]) {
                        $sizeMB = [math]::Round($sizeResult.Tables[0].Rows[0]["SizeMB"], 2)
                        Append-ColoredText $richTextBoxOutput "  Size: $sizeMB MB" ([System.Drawing.Color]::DarkGreen) $true
                    } else {
                        Append-ColoredText $richTextBoxOutput "  Size: 0 MB" ([System.Drawing.Color]::DarkGreen) $true
                    }
                } catch {
                    Append-ColoredText $richTextBoxOutput "  Size: Unable to retrieve" ([System.Drawing.Color]::DarkGreen) $true
                }
                
                # Get data file count
                try {
                    $fileQuery = @"
USE [$dbName];
SELECT COUNT(*) AS FileCount FROM sys.database_files WHERE type = 0;
"@
                    $fileResult = $server.ConnectionContext.ExecuteWithResults($fileQuery)
                    $fileCount = $fileResult.Tables[0].Rows[0]["FileCount"]
                    Append-ColoredText $richTextBoxOutput "  Data Files: $fileCount" ([System.Drawing.Color]::DarkBlue) $true
                } catch {
                    Append-ColoredText $richTextBoxOutput "  Data Files: Unable to retrieve" ([System.Drawing.Color]::DarkBlue) $true
                }
                
                # Get stored procedure count
                try {
                    $spQuery = @"
USE [$dbName];
SELECT COUNT(*) AS SPCount FROM sys.procedures WHERE is_ms_shipped = 0;
"@
                    $spResult = $server.ConnectionContext.ExecuteWithResults($spQuery)
                    $spCount = $spResult.Tables[0].Rows[0]["SPCount"]
                    Append-ColoredText $richTextBoxOutput "  User Stored Procedures: $spCount" ([System.Drawing.Color]::DarkMagenta) $true
                } catch {
                    Append-ColoredText $richTextBoxOutput "  User Stored Procedures: Unable to retrieve" ([System.Drawing.Color]::DarkMagenta) $true
                }
                
                # Get view count
                try {
                    $viewQuery = @"
USE [$dbName];
SELECT COUNT(*) AS ViewCount FROM sys.views WHERE is_ms_shipped = 0;
"@
                    $viewResult = $server.ConnectionContext.ExecuteWithResults($viewQuery)
                    $viewCount = $viewResult.Tables[0].Rows[0]["ViewCount"]
                    Append-ColoredText $richTextBoxOutput "  User Views: $viewCount" ([System.Drawing.Color]::DarkCyan) $true
                } catch {
                    Append-ColoredText $richTextBoxOutput "  User Views: Unable to retrieve" ([System.Drawing.Color]::DarkCyan) $true
                }
                
                # Get user defined function count
                try {
                    $funcQuery = @"
USE [$dbName];
SELECT COUNT(*) AS FuncCount FROM sys.objects WHERE type IN ('FN', 'IF', 'TF') AND is_ms_shipped = 0;
"@
                    $funcResult = $server.ConnectionContext.ExecuteWithResults($funcQuery)
                    $funcCount = $funcResult.Tables[0].Rows[0]["FuncCount"]
                    Append-ColoredText $richTextBoxOutput "  User Defined Functions: $funcCount" ([System.Drawing.Color]::Chocolate) $true
                } catch {
                    Append-ColoredText $richTextBoxOutput "  User Defined Functions: Unable to retrieve" ([System.Drawing.Color]::Chocolate) $true
                }
                
                # Get trigger count
                try {
                    $triggerQuery = @"
USE [$dbName];
SELECT COUNT(*) AS TriggerCount FROM sys.triggers WHERE parent_class = 1 AND is_ms_shipped = 0;
"@
                    $triggerResult = $server.ConnectionContext.ExecuteWithResults($triggerQuery)
                    $triggerCount = $triggerResult.Tables[0].Rows[0]["TriggerCount"]
                    Append-ColoredText $richTextBoxOutput "  Triggers: $triggerCount" ([System.Drawing.Color]::DarkGoldenrod) $true
                } catch {
                    Append-ColoredText $richTextBoxOutput "  Triggers: Unable to retrieve" ([System.Drawing.Color]::DarkGoldenrod) $true
                }
                
            } catch {
                Append-ColoredText $richTextBoxOutput "  Error retrieving database details: $($_.Exception.Message)" ([System.Drawing.Color]::Red) $false
            }
        }
        
        Append-ColoredText $richTextBoxOutput "`r`nDatabase Files (sys.master_files):" ([System.Drawing.Color]::Purple) $true
        try {
            $masterFilesQuery = @"
SELECT 
    DB_NAME(database_id) AS DatabaseName,
    name AS LogicalName,
    physical_name AS PhysicalPath,
    CASE type
        WHEN 0 THEN 'Data'
        WHEN 1 THEN 'Log'
        WHEN 2 THEN 'FileStream'
        WHEN 3 THEN 'FullText'
        ELSE 'Unknown'
    END AS FileType,
    CAST(size * 8.0 / 1024 AS DECIMAL(10,2)) AS SizeMB,
    CASE 
        WHEN max_size = -1 THEN 'Unlimited'
        WHEN max_size = 0 THEN '0 MB'
        ELSE CAST(max_size * 8.0 / 1024 AS VARCHAR(20)) + ' MB'
    END AS MaxSize,
    CASE 
        WHEN is_percent_growth = 1 THEN CAST(growth AS VARCHAR(10)) + '%'
        ELSE CAST(growth * 8.0 / 1024 AS VARCHAR(10)) + ' MB'
    END AS GrowthSetting,
    state_desc AS State
FROM sys.master_files
WHERE DB_NAME(database_id) NOT IN ('master', 'model', 'msdb', 'tempdb')
ORDER BY DatabaseName, FileType, name
"@
            $masterFilesResult = $server.ConnectionContext.ExecuteWithResults($masterFilesQuery)
            
            if ($masterFilesResult.Tables[0].Rows.Count -eq 0) {
                Append-ColoredText $richTextBoxOutput "  No user database files found" ([System.Drawing.Color]::DarkSlateGray) $false
            } else {
                $currentDb = ""
                foreach ($row in $masterFilesResult.Tables[0].Rows) {
                    if ($currentDb -ne $row['DatabaseName']) {
                        $currentDb = $row['DatabaseName']
                        Append-ColoredText $richTextBoxOutput "`r`n  Database: $currentDb" ([System.Drawing.Color]::DarkRed) $true
                    }
                    $fileInfo = "    [$($row['FileType'])] $($row['LogicalName'])"
                    Append-ColoredText $richTextBoxOutput $fileInfo ([System.Drawing.Color]::DarkBlue) $false
                    Append-ColoredText $richTextBoxOutput "      Path: $($row['PhysicalPath'])" ([System.Drawing.Color]::DarkGreen) $false
                    Append-ColoredText $richTextBoxOutput "      Size: $($row['SizeMB']) MB | Max: $($row['MaxSize']) | Growth: $($row['GrowthSetting']) | State: $($row['State'])" ([System.Drawing.Color]::DarkCyan) $false
                }
            }
        } catch {
            Append-ColoredText $richTextBoxOutput "  Unable to retrieve master_files info: $($_.Exception.Message)" ([System.Drawing.Color]::Red) $false
        }
        
        Append-ColoredText $richTextBoxOutput "`r`nLogins:" ([System.Drawing.Color]::Purple) $true
        try {
            $loginQuery = @"
SELECT 
    name,
    CASE type_desc
        WHEN 'SQL_LOGIN' THEN 'SqlLogin'
        WHEN 'WINDOWS_LOGIN' THEN 'WindowsUser'
        WHEN 'WINDOWS_GROUP' THEN 'WindowsGroup'
        ELSE type_desc
    END AS LoginType
FROM master.sys.server_principals
WHERE type IN ('S', 'U', 'G')
    AND name NOT LIKE '##%'
    AND name NOT LIKE 'NT %'
ORDER BY name
"@
            $loginResult = $server.ConnectionContext.ExecuteWithResults($loginQuery)
            foreach ($row in $loginResult.Tables[0].Rows) {
                Append-ColoredText $richTextBoxOutput "  $($row['name']) ($($row['LoginType']))" ([System.Drawing.Color]::DarkSlateBlue) $false
            }
        } catch {
            Append-ColoredText $richTextBoxOutput "  Unable to retrieve logins: $($_.Exception.Message)" ([System.Drawing.Color]::Red) $false
        }
        
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error connecting to SQL Server: $($_.Exception.Message)", "Connection Error")
    }
})

# Run the form
$form.Topmost = $true
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()