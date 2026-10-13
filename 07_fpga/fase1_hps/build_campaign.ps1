# Build OSQP / qpOASES / ADMM campaign (Windows MinGW, no fast-math).
# Reproducible command for campanha_solvers_20260919.

$ErrorActionPreference = "Stop"
$Root = "C:\Users\Rauni\Documents\MPC_DATACENTER\07_fpga\fase1_hps"
$Mingw = "C:\Users\Rauni\AppData\Local\Microsoft\WinGet\Packages\BrechtSanders.WinLibs.POSIX.UCRT_Microsoft.Winget.Source_8wekyb3d8bbwe\mingw64\bin"
$env:PATH = "$Mingw;" + $env:PATH
$gcc = Join-Path $Mingw "gcc.exe"
$gpp = Join-Path $Mingw "g++.exe"
$cmake = Join-Path $Mingw "cmake.exe"
$cflags = @("-O2", "-std=c99", "-Wall", "-Wextra", "-I$Root", "-D_POSIX_C_SOURCE=200809L", "-DQP_WITH_QPOASES")
$cxxflags = @("-O2", "-Wall", "-I$Root", "-I$Root\third_party\qpOASES\include", "-D__SUPPRESSANYOUTPUT__", "-D__NO_COPYRIGHT__", "-DQP_WITH_QPOASES")

$qdl = Join-Path $Root "third_party\qdldl"
$osqpSrc = Join-Path $Root "third_party\osqp"
$osqpBuild = Join-Path $osqpSrc "build"
New-Item -ItemType Directory -Force -Path $osqpBuild | Out-Null
if (-not (Test-Path (Join-Path $osqpBuild "out\libosqp.a")) -and -not (Test-Path (Join-Path $osqpBuild "out\libosqp.dll.a"))) {
    Push-Location $osqpBuild
    & $cmake -G "MinGW Makefiles" `
        -DCMAKE_C_COMPILER="$gcc" `
        -DCMAKE_BUILD_TYPE=Release `
        -DOSQP_BUILD_DEMO_EXE=OFF `
        -DOSQP_BUILD_UNITTESTS=OFF `
        -DOSQP_ALGEBRA_BACKEND=builtin `
        -DFETCHCONTENT_SOURCE_DIR_QDLDL="$qdl" `
        $osqpSrc
    & $cmake --build . --config Release --target osqpstatic
    Pop-Location
}

$qpoObjDir = Join-Path $Root "third_party\qpOASES\bin_mingw"
New-Item -ItemType Directory -Force -Path $qpoObjDir | Out-Null
$qpoSrc = @(
    "Bounds.cpp","Constraints.cpp","Flipper.cpp","Indexlist.cpp","Matrices.cpp",
    "MessageHandling.cpp","Options.cpp","QProblem.cpp","QProblemB.cpp",
    "SQProblem.cpp","SubjectTo.cpp","Utils.cpp","BLASReplacement.cpp","LAPACKReplacement.cpp"
)
$qpoObjs = @()
foreach ($s in $qpoSrc) {
    $src = Join-Path $Root "third_party\qpOASES\src\$s"
    $obj = Join-Path $qpoObjDir ($s -replace "\.cpp$",".o")
    if (-not (Test-Path $obj) -or (Get-Item $src).LastWriteTime -gt (Get-Item $obj).LastWriteTime) {
        & $gpp @cxxflags -c $src -o $obj
        if ($LASTEXITCODE -ne 0) { throw "qpOASES compile failed $s" }
    }
    $qpoObjs += $obj
}

$osqpInc = @(
    "-I$osqpSrc\include\public",
    "-I$osqpBuild\include\public",
    "-I$osqpBuild\include"
)
$osqpLib = $null
foreach ($c in @("out\libosqpstatic.a","out\libosqp.a","libosqpstatic.a","libosqp.a")) {
    $p = Join-Path $osqpBuild $c
    if (Test-Path $p) { $osqpLib = $p; break }
}
Get-ChildItem $osqpBuild -Recurse -Filter "*osqp*" | Select-Object -First 20 FullName

$commonC = @(
    "qp_admm.c","qp_admm_hist.c","qp_metrics.c","qp_eval.c","qp_sha256.c",
    "qp_dump_io.c","qp_engine.c","qp_osqp.c","ems_param.c","ems_work.c","ems_clock.c"
)
$objs = @()
foreach ($s in $commonC) {
    $src = Join-Path $Root $s
    $obj = Join-Path $Root ($s -replace "\.c$",".o")
    & $gcc @cflags @osqpInc -c $src -o $obj
    if ($LASTEXITCODE -ne 0) { throw "compile failed $s" }
    $objs += $obj
}
$qpoasesCpp = Join-Path $Root "qp_qpoases.cpp"
$qpoasesO = Join-Path $Root "qp_qpoases.o"
& $gpp @cxxflags -c $qpoasesCpp -o $qpoasesO
if ($LASTEXITCODE -ne 0) { throw "qp_qpoases.cpp failed" }

$campO = Join-Path $Root "qp_campaign.o"
& $gcc @cflags -c (Join-Path $Root "qp_campaign.c") -o $campO
if ($LASTEXITCODE -ne 0) { throw "qp_campaign.c failed" }

$exe = Join-Path $Root "qp_campaign.exe"
$link = @($campO) + $objs + @($qpoasesO) + $qpoObjs
if ($osqpLib) { $link += $osqpLib }
& $gpp -O2 -static -o $exe @link -lm
if ($LASTEXITCODE -ne 0) { throw "link qp_campaign failed" }

$emsSrc = @(
    "ems_param.c","planta_bess.c","controle_heuristico.c","gera_cenario.c",
    "qp_admm.c","qp_metrics.c","controle_mpc_fpga.c","ems_protocol.c","ems_work.c",
    "ems_clock.c","ems_hps_main.c","qp_engine.c","qp_osqp.c","qp_eval.c","qp_sha256.c",
    "qp_dump_io.c","qp_admm_hist.c"
)
$emsObjs = @()
foreach ($s in $emsSrc) {
    $obj = Join-Path $Root ("ems_" + ($s -replace "\.c$",".o"))
    & $gcc @cflags @osqpInc -c (Join-Path $Root $s) -o $obj
    if ($LASTEXITCODE -ne 0) { throw "ems compile failed $s" }
    $emsObjs += $obj
}
$emsExe = Join-Path $Root "ems_hps.exe"
$emsLink = $emsObjs + @($qpoasesO) + $qpoObjs
if ($osqpLib) { $emsLink += $osqpLib }
& $gpp -O2 -static -o $emsExe @emsLink -lm
if ($LASTEXITCODE -ne 0) { throw "link ems_hps failed" }

Write-Host "OK $exe"
Write-Host "OK $emsExe"
