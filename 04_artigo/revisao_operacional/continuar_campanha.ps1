param(
    [Parameter(Mandatory=$true)][string]$RunId,
    [string]$Groups = 'fairness,ablacao,pesos,timing,gate,magnitude,alarm,detection,plant_sensitivity,windows,montecarlo,probabilities,long_outage',
    [string]$Matlab = 'C:\Program Files\MATLAB\R2025b\bin\matlab.exe'
)
$ErrorActionPreference='Stop'
if ($RunId -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid run ID' }
if ($Groups -notmatch '^[a-z_,]+$') { throw 'Invalid groups' }
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$rootForMatlab = $projectRoot.Replace('\','/').Replace("'","''")
$groupCell = '{' + (($Groups.Split(',') | ForEach-Object { "'$_'" }) -join ',') + '}'
$expression = "addpath('$rootForMatlab/01_matlab_base/revisao_operacional'); executar_campanha('$rootForMatlab','$RunId',$groupCell);"
& $Matlab -batch $expression
if ($LASTEXITCODE -ne 0) { throw "MATLAB failed: $LASTEXITCODE. Completed job files remain preserved." }
