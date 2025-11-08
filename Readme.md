# SQL Server Configuration Analyzer

A PowerShell-based GUI tool for analyzing SQL Server configurations and database objects.

## Description

This tool provides a quick overview of SQL Server instance configuration and database statistics through an easy-to-use Windows Forms interface. It displays server information, database details, and object counts with color-coded output for better readability.

## Features

- **Server Information**: Edition, version, product level, memory configuration, and processor count
- **Database Analysis**: For each database, displays:
  - Database size
  - Number of data files
  - Count of stored procedures
  - Count of views
  - Count of user-defined functions
  - Count of triggers
- **Login Information**: Lists all server logins with their login types
- **Color-Coded Output**: Easy-to-read results with different colors for different information types

## Prerequisites

- Windows PowerShell 5.1 or later
- SQL Server Management Objects (SMO)
  - Usually installed with SQL Server Management Studio (SSMS)
  - Or install via: `Install-Module -Name SqlServer`
- Appropriate permissions to connect to the target SQL Server instance

## Usage

1. Save the script as `SQLServerAnalyzer.ps1`
2. Right-click and select "Run with PowerShell" or run from PowerShell console:
   ```powershell
   .\SQLServerAnalyzer.ps1
   ```
3. Enter the SQL Server name/instance in the text box (e.g., `localhost`, `SERVER\INSTANCE`)
4. Click "Run Analysis" button
5. Review the color-coded output in the results window

## Server Name Examples

- Local default instance: `localhost` or `(local)` or `.`
- Named instance: `localhost\SQLEXPRESS` or `SERVER\INSTANCENAME`
- Remote server: `192.168.1.100` or `SERVERNAME`
- Using specific port: `SERVERNAME,1433`

## Authentication

The script uses Windows Authentication by default. Ensure your Windows account has appropriate permissions on the target SQL Server.

## Troubleshooting

**Error: "Could not load file or assembly"**
- Install SQL Server Management Objects (SMO) or SQL Server PowerShell module

**Error: "Login failed for user"**
- Verify you have permissions to connect to the SQL Server
- Check if Windows Authentication is enabled on the target server

**Connection timeout**
- Verify the server name is correct
- Ensure SQL Server Browser service is running (for named instances)
- Check firewall settings

## Notes

- System databases (master, model, msdb, tempdb) are included in the analysis
- Large servers with many databases may take a few seconds to analyze
- The tool is read-only and makes no changes to the SQL Server

## Author

Created for SQL Server administrators and database developers to quickly assess server configurations and database object counts.

## License

Free to use and modify as needed.