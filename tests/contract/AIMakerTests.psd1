@{
    Run = @{
        Path = @(
            "cases"
        )
        Exit = $true
    }
    Output = @{
        Verbosity = "Detailed"
    }
    TestResult = @{
        Enabled      = $true
        OutputFormat = "NUnitXml"
        OutputPath   = "TestResults.xml"
    }
    Filter = @{
        ExcludeTag = @("VMOnly")
    }
}
