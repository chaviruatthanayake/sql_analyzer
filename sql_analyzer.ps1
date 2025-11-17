# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "SQL Server Configuration Analyzer"
$form.Size = New-Object System.Drawing.Size(600,400)
$form.StartPosition = "CenterScreen"

# Server name label and textbox
$labelServer = New-Object System.Windows.Forms.Label
$labelServer.Text = "SQL Server Name:"
$labelServer.Location = New-Object System.Drawing.Point(20,20)
$labelServer.Size = New-Object System.Drawing.Size(120,20)
$form.Controls.Add($labelServer)

$textBoxServer = New-Object System.Windows.Forms.TextBox
$textBoxServer.Location = New-Object System.Drawing.Point(150,20)
$textBoxServer.Size = New-Object System.Drawing.Size(400,20)
$form.Controls.Add($textBoxServer)

# RichTextBox for colorful output
$richTextBoxOutput = New-Object System.Windows.Forms.RichTextBox
$richTextBoxOutput.Location = New-Object System.Drawing.Point(20,60)
$richTextBoxOutput.Size = New-Object System.Drawing.Size(530,250)
$richTextBoxOutput.ReadOnly = $true
$richTextBoxOutput.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($richTextBoxOutput)

# Button to run analysis
$buttonRun = New-Object System.Windows.Forms.Button
$buttonRun.Text = "Run Analysis"
$buttonRun.Location = New-Object System.Drawing.Point(20,320)
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
        
        # Set connection to allow basic enumeration
        $server.ConnectionContext.ConnectTimeout = 30
        
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
        
        # Filter out system databases
        $userDatabases = $server.Databases | Where-Object { $systemDatabases -notcontains $_.Name }
        
        Append-ColoredText $richTextBoxOutput "`r`nUser Databases: $($userDatabases.Count)" ([System.Drawing.Color]::Blue) $true
        Append-ColoredText $richTextBoxOutput "Total Databases (including system): $($server.Databases.Count)" ([System.Drawing.Color]::Blue) $false
        
        foreach ($db in $userDatabases) {
            try {
                Append-ColoredText $richTextBoxOutput "`r`nDatabase: $($db.Name)" ([System.Drawing.Color]::DarkRed) $true
                Append-ColoredText $richTextBoxOutput "  Size: $([math]::Round($db.Size,2)) MB" ([System.Drawing.Color]::DarkGreen) $true
                
                # Safely count data files
                try {
                    $dataFileCount = 0
                    foreach ($fg in $db.FileGroups) {
                        $dataFileCount += $fg.Files.Count
                    }
                    Append-ColoredText $richTextBoxOutput "  Data Files: $dataFileCount" ([System.Drawing.Color]::DarkBlue) $true
                } catch {
                    Append-ColoredText $richTextBoxOutput "  Data Files: Unable to retrieve" ([System.Drawing.Color]::DarkBlue) $true
                }
                
                # Safely count stored procedures (excluding system objects)
                try {
                    $userSPs = 0
                    foreach ($sp in $db.StoredProcedures) {
                        if (-not $sp.IsSystemObject) {
                            $userSPs++
                        }
                    }
                    Append-ColoredText $richTextBoxOutput "  User Stored Procedures: $userSPs" ([System.Drawing.Color]::DarkMagenta) $true
                } catch {
                    Append-ColoredText $richTextBoxOutput "  User Stored Procedures: Unable to retrieve" ([System.Drawing.Color]::DarkMagenta) $true
                }
                
                # Safely count user views
                try {
                    $userViews = 0
                    foreach ($view in $db.Views) {
                        if (-not $view.IsSystemObject) {
                            $userViews++
                        }
                    }
                    Append-ColoredText $richTextBoxOutput "  User Views: $userViews" ([System.Drawing.Color]::DarkCyan) $true
                } catch {
                    Append-ColoredText $richTextBoxOutput "  User Views: Unable to retrieve" ([System.Drawing.Color]::DarkCyan) $true
                }
                
                # Safely count user defined functions
                try {
                    $userFunctions = 0
                    foreach ($func in $db.UserDefinedFunctions) {
                        if (-not $func.IsSystemObject) {
                            $userFunctions++
                        }
                    }
                    Append-ColoredText $richTextBoxOutput "  User Defined Functions: $userFunctions" ([System.Drawing.Color]::Chocolate) $true
                } catch {
                    Append-ColoredText $richTextBoxOutput "  User Defined Functions: Unable to retrieve" ([System.Drawing.Color]::Chocolate) $true
                }
                
                # Safely count triggers
                try {
                    $triggerCount = 0
                    foreach ($table in $db.Tables) {
                        if (-not $table.IsSystemObject) {
                            $triggerCount += $table.Triggers.Count
                        }
                    }
                    Append-ColoredText $richTextBoxOutput "  Triggers: $triggerCount" ([System.Drawing.Color]::DarkGoldenrod) $true
                } catch {
                    Append-ColoredText $richTextBoxOutput "  Triggers: Unable to retrieve" ([System.Drawing.Color]::DarkGoldenrod) $true
                }
                
            } catch {
                Append-ColoredText $richTextBoxOutput "  Error retrieving database details: $($_.Exception.Message)" ([System.Drawing.Color]::Red) $false
            }
        }
        
        Append-ColoredText $richTextBoxOutput "`r`nLogins:" ([System.Drawing.Color]::Purple) $true
        try {
            foreach ($login in $server.Logins) {
                Append-ColoredText $richTextBoxOutput "  $($login.Name) ($($login.LoginType))" ([System.Drawing.Color]::DarkSlateBlue) $false
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