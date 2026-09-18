param(
    [string]$RunId='campanha_v1',
    [string]$Python='C:\Users\Rauni\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
)
$ErrorActionPreference='Stop'
if($RunId -notmatch '^[A-Za-z0-9_-]+$'){throw 'Invalid RunId'}
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$outRoot=Join-Path $projectRoot '05_resultados/revisao_operacional'
$eventLog=Join-Path $outRoot "pipeline_$stamp.jsonl"
function Event([string]$State,[string]$Message){
    @{timestamp=(Get-Date -Format o);state=$State;message=$Message;run=$RunId} | ConvertTo-Json -Compress | Add-Content -LiteralPath $eventLog -Encoding utf8
}
Event 'starting' 'Integrity check and immutable code snapshot'
& $Python (Join-Path $PSScriptRoot 'verificar_integridade.py') --output (Join-Path $outRoot "integridade_inicio_$stamp") --snapshot
if($LASTEXITCODE -ne 0){Event 'failed' 'Integrity check failed';exit 1}
try {
    & (Join-Path $PSScriptRoot 'continuar_campanha.ps1') -RunId $RunId -Groups 'principal,fairness,ablacao,pesos,timing,gate,magnitude,alarm,detection,plant_sensitivity,windows,montecarlo,probabilities,long_outage'
    Event 'simulations_finished' 'All registered groups returned normally'
} catch {
    Event 'simulation_error' $_.Exception.Message
    throw
}
& $Python (Join-Path $PSScriptRoot 'analisar_resultados.py') --run (Join-Path $outRoot $RunId) --output (Join-Path $outRoot "analise_final_$stamp")
if($LASTEXITCODE -ne 0){Event 'analysis_failed' 'Review logs';exit 1}
& $Python (Join-Path $PSScriptRoot 'verificar_integridade.py') --output (Join-Path $outRoot "integridade_fim_$stamp")
if($LASTEXITCODE -ne 0){Event 'failed' 'Final historical-integrity check failed';exit 1}
Event 'completed_execution' 'Simulations and automated analysis finished. Scientific review and physical laboratory remain separate.'
