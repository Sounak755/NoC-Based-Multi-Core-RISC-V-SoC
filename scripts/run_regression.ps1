
$ErrorActionPreference = "Stop"

# Create the output directory.
New-Item -ItemType Directory -Force .\build\regression | Out-Null

# Existing regression tests.
$tests = @(

    
    @{
        Name = "noc_mesh_2x2_tb"
        Top  = "noc_mesh_2x2_tb"
        File = "tb\noc_mesh_2x2_tb.sv"
    },
    @{
        Name = "noc_mesh_2x2_contention_tb"
        Top  = "noc_mesh_2x2_contention_tb"
        File = "tb\noc_mesh_2x2_contention_tb.sv"
    },
    @{
        Name = "noc_memory_fabric_2x2_tb"
        Top  = "noc_memory_fabric_2x2_tb"
        File = "tb\noc\noc_memory_fabric_2x2_tb.sv"
    },
    @{
        Name = "noc_memory_contention_tb"
        Top  = "noc_memory_contention_tb"
        File = "tb\noc\noc_memory_contention_tb.sv"
    },
    @{
        Name = "rv32i_noc_multicore_subsystem_tb"
        Top  = "rv32i_noc_multicore_subsystem_tb"
        File = "tb\cpu\rv32i_noc_multicore_subsystem_tb.sv"
    },
    @{
        Name = "noc_mesh_2x2_latency_tb"
        Top  = "noc_mesh_2x2_latency_tb"
        File = "tb\noc_mesh_2x2_latency_tb.sv"
    },
    @{
        Name = "noc_mesh_2x2_throughput_tb"
        Top  = "noc_mesh_2x2_throughput_tb"
        File = "tb\noc_mesh_2x2_throughput_tb.sv"
    }
)

# Discover RTL source files.
$rtl = @(
    Get-ChildItem .\rtl -Recurse -File -Filter "*.sv" |
        ForEach-Object { $_.FullName }
)

if ($rtl.Count -eq 0) {
    Write-Host "FAIL: No RTL SystemVerilog files found under rtl\" `
        -ForegroundColor Red
    exit 1
}

$results = @()

foreach ($test in $tests) {
    Write-Host "`n========== $($test.Name) ==========" `
        -ForegroundColor Cyan

    # Check for the testbench.
    if (-not (Test-Path $test.File)) {
        Write-Host "FAIL: Testbench not found: $($test.File)" `
            -ForegroundColor Red

        $results += [PSCustomObject]@{
            Test   = $test.Name
            Result = "FAIL (missing file)"
        }

        continue
    }

    $out        = ".\build\regression\$($test.Name).vvp"
    $compileLog = ".\build\regression\$($test.Name)_compile.log"
    $runLog     = ".\build\regression\$($test.Name)_run.log"

    # --------------------------------------------------------
    # Compile.
    #
    # Capture stdout and stderr together, but do not let a
    # compiler warning abort the script. The native exit code
    # determines whether compilation succeeded.
    # --------------------------------------------------------

    $compileExit = 0

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $compileOutput = @(
            & iverilog -g2012 -Wall -s $test.Top `
                -o $out @rtl $test.File 2>&1

            $nativeExitCode = $LASTEXITCODE
        )

        $compileExit = $nativeExitCode

        $compileOutput |
            Out-File -FilePath $compileLog -Encoding utf8

        if ($compileOutput.Count -gt 0) {
            $compileOutput | ForEach-Object { Write-Host $_ }
        }
    }
    catch {
        Write-Host "Compiler invocation failed: $_" -ForegroundColor Red
        $compileExit = 1
        "Compiler invocation failed: $_" |
            Out-File -FilePath $compileLog -Encoding utf8
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($compileExit -ne 0) {
        Write-Host "FAIL: Compilation failed (exit code $compileExit)" `
            -ForegroundColor Red

        $results += [PSCustomObject]@{
            Test   = $test.Name
            Result = "FAIL (compile)"
        }

        continue
    }

    # --------------------------------------------------------
    # Run simulation.
    # --------------------------------------------------------

    $simulationExit = 0

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $simulationOutput = @(
            & vvp $out 2>&1

            $nativeExitCode = $LASTEXITCODE
        )

        $simulationExit = $nativeExitCode

        $simulationOutput |
            Out-File -FilePath $runLog -Encoding utf8

        if ($simulationOutput.Count -gt 0) {
            $simulationOutput | ForEach-Object { Write-Host $_ }
        }
    }
    catch {
        Write-Host "Simulation invocation failed: $_" `
            -ForegroundColor Red

        $simulationExit = 1

        "Simulation invocation failed: $_" |
            Out-File -FilePath $runLog -Encoding utf8
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($simulationExit -eq 0) {
        Write-Host "PASS: $($test.Name)" -ForegroundColor Green

        $results += [PSCustomObject]@{
            Test   = $test.Name
            Result = "PASS"
        }
    }
    else {
        Write-Host "FAIL: Simulation failed (exit code $simulationExit)" `
            -ForegroundColor Red

        $results += [PSCustomObject]@{
            Test   = $test.Name
            Result = "FAIL (simulation)"
        }
    }
}

# ------------------------------------------------------------
# Final regression summary.
# ------------------------------------------------------------

Write-Host "`n========== REGRESSION SUMMARY ==========" `
    -ForegroundColor Cyan

$results | Format-Table -AutoSize

$passed = @(
    $results | Where-Object { $_.Result -eq "PASS" }
).Count

$failed = @(
    $results | Where-Object { $_.Result -ne "PASS" }
).Count

Write-Host "Passed: $passed / $($results.Count)"
Write-Host "Failed: $failed / $($results.Count)"

if ($failed -gt 0) {
    Write-Host "FAIL: Inspect logs in build\regression\" `
        -ForegroundColor Red
    exit 1
}

Write-Host "ALL REGRESSION TESTS PASSED" -ForegroundColor Green
exit 0
