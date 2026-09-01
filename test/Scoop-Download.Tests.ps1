BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\download.ps1"
}

Describe 'url_filename' -Tag 'Scoop' {
    It 'should extract the real filename from an url' {
        url_filename 'http://example.org/foo.txt' | Should-Be 'foo.txt'
        url_filename 'http://example.org/foo.txt?var=123' | Should-Be 'foo.txt'
    }

    It 'can be tricked with a hash to override the real filename' {
        url_filename 'http://example.org/foo-v2.zip#/foo.zip' | Should-Be 'foo.zip'
    }
}

Describe 'url_remote_filename' -Tag 'Scoop' {
    It 'should extract the real filename from an url' {
        url_remote_filename 'http://example.org/foo.txt' | Should-Be 'foo.txt'
        url_remote_filename 'http://example.org/foo.txt?var=123' | Should-Be 'foo.txt'
    }

    It 'can not be tricked with a hash to override the real filename' {
        url_remote_filename 'http://example.org/foo-v2.zip#/foo.zip' | Should-Be 'foo-v2.zip'
    }
}

Describe 'Get-GitHubToken' -Tag 'Scoop' {
    BeforeAll {
        # Mock needs a real command to replace; a 'function' statement would trip the linter.
        Set-Item -Path function:script:gh -Value { 'gho_realCliMustNotRun' }

        $tokenVars = 'SCOOP_GH_TOKEN', 'GH_TOKEN', 'GITHUB_TOKEN'
        $origEnv = @{}
        $tokenVars | ForEach-Object { $origEnv[$_] = [Environment]::GetEnvironmentVariable($_) }
    }

    AfterAll {
        Remove-Item -Path function:script:gh -ErrorAction Ignore
        $origEnv.Keys | ForEach-Object { [Environment]::SetEnvironmentVariable($_, $origEnv[$_]) }
    }

    BeforeEach {
        Mock get_config { $null }
        Mock gh { 'gho_FROM_CLI' }
        $tokenVars | ForEach-Object { [Environment]::SetEnvironmentVariable($_, $null) }
        # Remove rather than assign, so each test also covers the unassigned first call
        Remove-Variable -Name ghCliToken -Scope Script -ErrorAction Ignore
    }

    It 'should give up when the GitHub CLI fails, and not retry it' {
        Mock gh { throw 'gh: could not read token' }
        Get-GitHubToken | Should-BeNull
        Get-GitHubToken | Should-BeNull
        Should-Invoke -CommandName gh -Times 1 -Exactly
    }

    # checkver.ps1 and autoupdate.ps1 call this without bin/scoop.ps1's 'Set-StrictMode -Off'
    It 'tolerates StrictMode when no token source is set' {
        Mock gh { }
        & { Set-StrictMode -Version Latest; $ErrorActionPreference = 'Stop'; Get-GitHubToken } | Should-BeNull
    }

    It 'tolerates StrictMode when reading the probe cache before it was assigned' {
        & { Set-StrictMode -Version Latest; $ErrorActionPreference = 'Stop'; Get-GitHubToken } | Should-Be 'gho_FROM_CLI'
    }
}
