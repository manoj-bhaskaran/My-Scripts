BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' '..' '..' '..' '..' '..' 'src' 'powershell' 'modules' 'FileManagement' 'FileDistributor' 'FileDistributor.psd1'

    Import-Module -Name $script:ModulePath -Force | Out-Null
}

Describe 'FileDistributorRunState typed state contract' {
    It 'constructs with expected default values' {
        $state = [FileDistributorRunState]::new()

        $state | Should -BeOfType 'FileDistributorRunState'
        $state.TotalSourceFilesAll | Should -Be 0
        $state.TotalSourceFiles | Should -Be 0
        $state.TotalTargetFilesBefore | Should -Be 0
        $state.TotalSkippedFiles | Should -Be 0
        $state.Subfolders | Should -BeEmpty
        $state.SourceFiles | Should -BeEmpty
        $state.SkippedFilesByExtension.Count | Should -Be 0
    }

    It 'supports property mutation with typed fields' {
        $state = [FileDistributorRunState]::new()

        $state.TotalSourceFilesAll = 25
        $state.TotalSourceFiles = 10
        $state.TotalTargetFilesBefore = 5
        $state.TotalSkippedFiles = 3
        $state.MaxFilesToCopy = 10
        $state.SourceFolder = 'C:\source'
        $state.SkippedFilesByExtension['.tmp'] = 3

        $state.TotalSourceFilesAll | Should -Be 25
        $state.TotalSourceFiles | Should -Be 10
        $state.TotalTargetFilesBefore | Should -Be 5
        $state.TotalSkippedFiles | Should -Be 3
        $state.MaxFilesToCopy | Should -Be 10
        $state.SourceFolder | Should -Be 'C:\source'
        $state.SkippedFilesByExtension['.tmp'] | Should -Be 3
    }

    It 'round-trips through JSON using ToSerializableHashtable and FromHashtable' {
        $state = [FileDistributorRunState]::new()
        $state.TotalSourceFilesAll = 120
        $state.TotalSourceFiles = 50
        $state.TotalTargetFilesBefore = 70
        $state.TotalSkippedFiles = 11
        $state.MaxFilesToCopy = 50
        $state.SourceFolder = 'C:\input'
        $state.SkippedFilesByExtension['.gif'] = 11

        $payload = $state.ToSerializableHashtable()
        $json = $payload | ConvertTo-Json -Depth 10
        $deserialized = ConvertFrom-Json -InputObject $json

        $roundTripTable = @{}
        foreach ($prop in $deserialized.PSObject.Properties) {
            if ($prop.Value -is [System.Management.Automation.PSCustomObject]) {
                $inner = @{}
                foreach ($innerProp in $prop.Value.PSObject.Properties) {
                    $inner[$innerProp.Name] = $innerProp.Value
                }
                $roundTripTable[$prop.Name] = $inner
            } else {
                $roundTripTable[$prop.Name] = $prop.Value
            }
        }

        $roundTrip = [FileDistributorRunState]::FromHashtable($roundTripTable)

        $roundTrip.TotalSourceFilesAll | Should -Be 120
        $roundTrip.TotalSourceFiles | Should -Be 50
        $roundTrip.TotalTargetFilesBefore | Should -Be 70
        $roundTrip.TotalSkippedFiles | Should -Be 11
        $roundTrip.MaxFilesToCopy | Should -Be 50
        $roundTrip.SourceFolder | Should -Be 'C:\input'
        $roundTrip.SkippedFilesByExtension['.gif'] | Should -Be 11
    }

    It 'loads legacy checkpoint hashtable shape using case-insensitive keys' {
        $legacy = @{
            totalsourcefiles = 12
            TOTALSOURCEFILESALL = 20
            totaltargetfilesbefore = 8
            maxfilestocopy = 12
            sourcefolder = 'C:\legacy'
            totalskippedfiles = 2
            skippedfilesbyextension = @{ '.tmp' = 2 }
            checkpoint = 3
            sessionid = 'legacy-session-id'
        }

        $state = [FileDistributorRunState]::FromHashtable($legacy)

        $state.TotalSourceFiles | Should -Be 12
        $state.TotalSourceFilesAll | Should -Be 20
        $state.TotalTargetFilesBefore | Should -Be 8
        $state.MaxFilesToCopy | Should -Be 12
        $state.SourceFolder | Should -Be 'C:\legacy'
        $state.TotalSkippedFiles | Should -Be 2
        $state.SkippedFilesByExtension['.tmp'] | Should -Be 2
        $state.LastCheckpoint | Should -Be 3
        $state.SessionId | Should -Be 'legacy-session-id'
    }
}
