<#
  Generates the per-framework copies of the library's units.

  The arrangement is TMS FNC's own, and the reasoning behind adopting it
  is in the project note "What FNC-standard packaging would cost us".
  In short: the VCL and FMX packages cannot both be installed in the IDE
  while they share unit names, so each framework gets its own copy of
  every unit under its own name.

  Sources\ is the master and is edited exactly as before. Everything
  under Generated\ is a build artifact: never edited, never committed.

  Two properties are worth stating plainly, because the whole scheme
  rests on them.

  It is line preserving. A substitution never adds or removes a line, so
  [dcc32 Error] FMX.FNCCADSys4.pas(16817) is line 16817 of the master as
  well. The script asserts this per file rather than trusting it.

  It is byte exact. The files are read as bytes and mapped to text
  through Latin-1, which is the one encoding where every byte is a
  character and back again. So a UTF-8 BOM stays a BOM, CRLF stays CRLF,
  and a stray high byte in a comment survives. Get-Content and Out-File
  guarantee none of that - TMS's documented one-liner rewrites the
  encoding and the line endings of every file it touches, which is
  harmless for them and would put this repository's line-ending policy
  back where it was in step 5.

  Usage:
    gen-units.ps1              generate into Generated\
    gen-units.ps1 -Check       report drift, write nothing, exit 1 if stale
    gen-units.ps1 -Quiet       only report what changed
#>
param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$Check,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------
# Which units belong to which framework.
#
# Everything is in all three unless it names a framework in its own
# right: FNCCS4GraphicsVCL is the GDI backend and FNCCS4ExportVCL is the
# metafile and clipboard export, and neither has an FMX or an LCL
# meaning. Emitting them anyway would compile - they are only reached
# through CADSYS_VCL - but it would put a unit that says VCL into the
# FMX package, which is the confusion this whole exercise exists to
# remove.
# ---------------------------------------------------------------------
$All = @('VCL', 'FMX', 'LCL')
$Units = [ordered]@{
  'CADSys.inc'             = $All
  'FNCCADSys4.pas'         = $All
  'FNCCS4BaseTypes.pas'    = $All
  'FNCCS4DXFModule.pas'    = $All
  'FNCCS4Graphics.pas'     = $All
  'FNCCS4GraphicsFNC.pas'  = $All
  'FNCCS4GraphicsVCL.pas'  = @('VCL')
  'FNCCS4ExportVCL.pas'    = @('VCL')
  'FNCCS4JSON.pas'         = $All
  'FNCCS4Legacy.pas'       = $All
  'FNCCS4Shapes.pas'       = $All
  'FNCCS4Tasks.pas'        = $All
  'FNCCS4Views.pas'        = $All
  'FNCCadSysRegister.pas'  = $All
}

# ---------------------------------------------------------------------
# What to replace, per framework, in order.
#
# Empty on purpose. This step proves the pipeline - that the suites and
# the demos build from a generated tree - with the names unchanged, so
# that when the table fills up there is only one new thing to debug.
#
# Keep this table small when it does fill up. A substitution is
# invisible at the point where it bites: it rewrites text inside dead
# IFDEF branches too, and the file that misbehaves is not the file
# anyone is reading. Framework differences belong in {$IFDEF}, in the
# master, where they can be seen.
# ---------------------------------------------------------------------
$Subs = @{
  'VCL' = @()
  'FMX' = @()
  'LCL' = @()
}

$Latin1 = [System.Text.Encoding]::GetEncoding(28591)

function Read-Exact([string]$Path) {
  return $Latin1.GetString([System.IO.File]::ReadAllBytes($Path))
}

function Write-Exact([string]$Path, [string]$Text) {
  [System.IO.File]::WriteAllBytes($Path, $Latin1.GetBytes($Text))
}

function Apply-Subs([string]$Text, [array]$Table) {
  foreach ($pair in $Table) {
    $Text = $Text.Replace($pair[0], $pair[1])
  }
  return $Text
}

$src = Join-Path $Root 'Sources'
$gen = Join-Path $Root 'Generated'
$written = 0
$unchanged = 0
$stale = @()

foreach ($fw in $All) {
  $dest = Join-Path $gen $fw
  if (-not $Check) {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
  }
  $emitted = @{}

  foreach ($name in $Units.Keys) {
    if ($Units[$name] -notcontains $fw) { continue }

    $from = Join-Path $src $name
    if (-not (Test-Path $from)) {
      throw "Sources\$name is in the manifest and not on disk."
    }

    $text = Read-Exact $from
    $out = Apply-Subs $text $Subs[$fw]

    # Line preserving, asserted rather than assumed. A substitution that
    # swallows or adds a newline breaks the mapping from a compiler
    # error back to the master, which is the property that makes the
    # generated tree safe to work with at all.
    $before = ([regex]::Matches($text, "`n")).Count
    $after = ([regex]::Matches($out, "`n")).Count
    if ($before -ne $after) {
      throw "$fw\$name changed line count ($before -> $after). Check the substitution table."
    }

    $outName = Apply-Subs $name $Subs[$fw]
    $to = Join-Path $dest $outName
    $emitted[$outName] = $true

    $same = $false
    if (Test-Path $to) {
      $same = ((Read-Exact $to) -eq $out)
    }

    if ($same) {
      $unchanged++
    }
    elseif ($Check) {
      $stale += "$fw\$outName"
    }
    else {
      Write-Exact $to $out
      $written++
      if (-not $Quiet) { Write-Host "  $fw\$outName" }
    }
  }

  # Anything left over is from an older manifest. Left in place it would
  # sit on the unit path and compile in preference to nothing at all.
  if (Test-Path $dest) {
    foreach ($f in Get-ChildItem -Path $dest -File) {
      if (-not $emitted.ContainsKey($f.Name)) {
        if ($Check) {
          $stale += "$fw\$($f.Name) (left over)"
        }
        else {
          Remove-Item $f.FullName -Force
          Write-Host "  removed $fw\$($f.Name)"
        }
      }
    }
  }
}

if ($Check) {
  if ($stale.Count -gt 0) {
    Write-Host "Generated tree is stale:"
    foreach ($s in $stale) { Write-Host "  $s" }
    exit 1
  }
  Write-Host "Generated tree is current ($unchanged file(s))."
  exit 0
}

Write-Host "$written written, $unchanged unchanged."
exit 0
