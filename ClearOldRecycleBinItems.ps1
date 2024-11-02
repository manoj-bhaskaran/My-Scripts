# Get the current date
$currentDate = Get-Date

# Get all items in the Recycle Bin
$recycleBinItems = New-Object -ComObject Shell.Application
$recycleBin = $recycleBinItems.Namespace(10).Items()

# Iterate over each item in the Recycle Bin
foreach ($item in $recycleBin) {
    # Get the file's deletion date
    $deletionDate = $item.ExtendedProperty("System.Recycle.DateDeleted")

    # Check if the file is older than one week
    if ($deletionDate -lt ($currentDate.AddDays(-7))) {
        # Delete the item
        $item.InvokeVerb("delete")
    }
}
