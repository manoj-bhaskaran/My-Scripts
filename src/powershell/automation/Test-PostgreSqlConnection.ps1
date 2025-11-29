# Define the connection string for ODBC
$dsn = "gnucash"
$user = "gnucash_user"
$securePassword = ConvertTo-SecureString "gnucash01" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($user, $securePassword)

# Function to create and hold a connection for a random period
function Open-OdbcConnection {
    param (
        [string]$dsn,
        [PSCredential]$Credential
    )

    # Create a new ODBC connection
    $connection = New-Object System.Data.Odbc.OdbcConnection
    $connection.ConnectionString = "DSN=$dsn;Uid=$($Credential.UserName);Pwd=$($Credential.GetNetworkCredential().Password);"

    # Open the connection
    $connection.Open()

    # Generate a random delay (in milliseconds) under 5 minutes (300000 ms)
    $delay = Get-Random -Minimum 0 -Maximum 300000

    # Keep the connection open for the random delay period
    Start-Sleep -Milliseconds $delay

    # Close the connection
    $connection.Close()
}

# Create and open 100 simultaneous connections
for ($i = 1; $i -le 100; $i++) {
    Start-Job -ScriptBlock {
        param ($dsn, $credential)

        # Call the function to open and hold a connection
        Open-OdbcConnection -dsn $using:dsn -Credential $using:credential

    } -ArgumentList $dsn, $credential
}

# Wait for all jobs to complete
Get-Job | Wait-Job

# Clean up jobs
Get-Job | Remove-Job
