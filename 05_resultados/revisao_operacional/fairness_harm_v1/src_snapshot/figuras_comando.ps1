# Generate minimal SVG command windows from comando_eventos.csv (no MATLAB GUI).
$dest = "C:\Users\Rauni\Documents\MPC_DATACENTER\05_resultados\revisao_operacional\fairness_sintese_v1"
$csv = Import-Csv (Join-Path $dest "comando_eventos.csv")
$figd = Join-Path $dest "figuras"
New-Item -ItemType Directory -Force -Path $figd | Out-Null

function Write-Svg($path, $series, $title) {
  $allx = $series | ForEach-Object { $_.pts | ForEach-Object { $_[0] } }
  $ally = $series | ForEach-Object { $_.pts | ForEach-Object { $_[1] } }
  $xmin = ($allx | Measure-Object -Minimum).Minimum
  $xmax = ($allx | Measure-Object -Maximum).Maximum
  $ymin = ($ally | Measure-Object -Minimum).Minimum
  $ymax = ($ally | Measure-Object -Maximum).Maximum
  if ($xmax -eq $xmin) { $xmax = $xmin + 1 }
  if ($ymax -eq $ymin) { $ymax = $ymin + 1 }
  $W=640; $H=280; $l=50; $b=30; $r=20; $t=28
  $pw=$W-$l-$r; $ph=$H-$t-$b
  function X($x) { $l + ($x-$xmin)/($xmax-$xmin)*$pw }
  function Y($y) { $t + $ph - ($y-$ymin)/($ymax-$ymin)*$ph }
  $colors = @("#1f77b4","#d62728","#2ca02c")
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
  [void]$sb.AppendLine("<svg xmlns=`"http://www.w3.org/2000/svg`" width=`"$W`" height=`"$H`" viewBox=`"0 0 $W $H`">")
  [void]$sb.AppendLine("<rect width=`"100%`" height=`"100%`" fill=`"white`"/>")
  [void]$sb.AppendLine("<text x=`"$($W/2)`" y=`"18`" text-anchor=`"middle`" font-size=`"13`" font-family=`"sans-serif`">$title</text>")
  $i=0
  foreach ($s in $series) {
    $d = ($s.pts | ForEach-Object { "{0:N2},{1:N2}" -f (X $_[0]), (Y $_[1]) }) -join " L "
    $d = "M " + $d
    [void]$sb.AppendLine("<path d=`"$d`" fill=`"none`" stroke=`"$($colors[$i])`" stroke-width=`"1.6`"/>")
    [void]$sb.AppendLine("<text x=`"$($W-8)`" y=`"$($40+$i*14)`" text-anchor=`"end`" font-size=`"11`" fill=`"$($colors[$i])`" font-family=`"sans-serif`">$($s.name)</text>")
    $i++
  }
  [void]$sb.AppendLine("<text x=`"$($W/2)`" y=`"$($H-6)`" text-anchor=`"middle`" font-size=`"11`" font-family=`"sans-serif`">t (s)</text>")
  [void]$sb.AppendLine("<text x=`"12`" y=`"$($H/2)`" font-size=`"11`" font-family=`"sans-serif`" transform=`"rotate(-90 12 $($H/2))`">u (kW)</text>")
  [void]$sb.AppendLine("</svg>")
  Set-Content -Path $path -Value $sb.ToString() -Encoding UTF8
}

function Series($id, $evento) {
  $rows = $csv | Where-Object { $_.id -eq $id -and $_.evento -eq $evento }
  $pts = @()
  foreach ($r in $rows) { $pts += ,@([double]$r.t, [double]$r.u) }
  return @{ name = $id; pts = $pts }
}

$pairs = @(
  @{ file="faixas_degrau950.svg"; title="carga_faixas step 950 kW"; a="j00003"; b="j00004"; ev="degrau_L_950" },
  @{ file="faixas400_degrau950.svg"; title="fairness 400 kW/s step 950 kW"; a="j00048"; b="j00049"; ev="degrau_L_950" },
  @{ file="perda_G1to0.svg"; title="perda_fonte first G:1to0"; a="j00013"; b="j00014"; ev="G_1to0" },
  @{ file="perda400_G1to0.svg"; title="fairness 400 perda G:1to0"; a="j00086"; b="j00087"; ev="G_1to0" }
)
foreach ($p in $pairs) {
  Write-Svg (Join-Path $figd $p.file) @((Series $p.a $p.ev), (Series $p.b $p.ev)) $p.title
}
Write-Output "svg ok"
