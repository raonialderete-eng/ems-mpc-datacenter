param([string]$RunId='campanha_v1')
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$python=Join-Path $projectRoot '.venv_revisao/Scripts/python.exe'
if(!(Test-Path -LiteralPath $python)){throw 'Ambiente .venv_revisao ausente. Consulte RETOMADA_20260910.md.'}
& $python -c 'import numpy, scipy, matplotlib'
if($LASTEXITCODE -ne 0){throw 'Dependencias Python incompletas'}
& (Join-Path $PSScriptRoot 'executar_pipeline.ps1') -RunId $RunId -Python $python
