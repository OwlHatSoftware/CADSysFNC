@echo off
rem ---------------------------------------------------------------------
rem Builds both library packages with dcc32, outside the IDE.
rem
rem   build-packages.cmd [BDSVER]      BDSVER defaults to 23.0 (Delphi 12)
rem
rem Why this exists: the packages were the one thing only the IDE ever
rem built, so the only way to ask "is the package broken?" was to ask
rem the IDE, which answers with whatever else is wrong with the IDE. An
rem access violation inside coreide while installing says nothing about
rem the package source. This script does.
rem
rem It writes its BPL and DCP to Tools\build\pkg and NEVER to the IDE's
rem own folders, so running it cannot disturb, replace or half-replace
rem an installed package. It does not install anything either - a green
rem run here means the package compiles and links, and installing is
rem still a thing you do in the IDE.
rem
rem It does not run gen-units: the dpk files name their units through
rem the contains clause, which points at Sources directly. That changes
rem in step 2 of the packaging work, when the copies get their prefixes
rem and the packages start listing the generated names.
rem
rem Log: Tools\logs\build-packages.log
rem ---------------------------------------------------------------------
setlocal
set BDSVER=%1
if "%BDSVER%"=="" set BDSVER=23.0
set ROOT=%~dp0..
set LOGS=%~dp0logs
set OUT=%~dp0build
set LOG=%LOGS%\build-packages.log
if not exist "%LOGS%" mkdir "%LOGS%"
if not exist "%OUT%" mkdir "%OUT%"
if not exist "%OUT%\pkg" mkdir "%OUT%\pkg"
if not exist "%OUT%\pkg\dcp" mkdir "%OUT%\pkg\dcp"
if not exist "%OUT%\pkg\dcu-vcl" mkdir "%OUT%\pkg\dcu-vcl"
if not exist "%OUT%\pkg\dcu-fmx" mkdir "%OUT%\pkg\dcu-fmx"

rem --- where is Delphi -------------------------------------------------
set BDSROOT=
for /f "tokens=2,*" %%a in ('reg query "HKCU\Software\Embarcadero\BDS\%BDSVER%" /v RootDir 2^>nul ^| find "RootDir"') do set BDSROOT=%%b
if "%BDSROOT%"=="" for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Embarcadero\BDS\%BDSVER%" /v RootDir 2^>nul ^| find "RootDir"') do set BDSROOT=%%b
if "%BDSROOT%"=="" (
  echo Delphi BDS %BDSVER% not found in the registry. > "%LOG%"
  type "%LOG%"
  exit /b 2
)
set DCC="%BDSROOT%bin\dcc32.exe"
if not exist %DCC% (
  echo dcc32 not found at %DCC% > "%LOG%"
  type "%LOG%"
  exit /b 2
)

rem --- the IDE's DCP folder -------------------------------------------
rem A package's requires clause is resolved from .dcp files, not .dcu,
rem and rtl, vcl, fmx and the rest live in the shared folder the IDE
rem writes to. There is no registry value for it, so the usual places
rem are tried in turn.
set DCPDIR=
for %%c in (
  "%PUBLIC%\Documents\Embarcadero\Studio\%BDSVER%\Dcp"
  "%PUBLIC%\Documents\RAD Studio\%BDSVER%\Dcp"
  "%BDSROOT%lib\Win32\release"
) do (
  if not defined DCPDIR if exist "%%~c\rtl.dcp" set DCPDIR=%%~c
)
if "%DCPDIR%"=="" (
  echo Could not find rtl.dcp - the IDE's shared Dcp folder is not where > "%LOG%"
  echo this script looks. Add the right path to the DCPDIR loop. >> "%LOG%"
  type "%LOG%"
  exit /b 2
)

rem --- TMS FNC Core: both frameworks' dcps are in one folder ----------
set FNCCORE=
for %%d in (Release Debug) do (
  for %%r in ("%ROOT%\..\TMS\Products" "%ROOT%\..\..\Products" "%ROOT%\..\Products") do (
    if not defined FNCCORE if exist "%%~r\tms.fnc.core\packages\d12\Win32\%%d\VCLTMSFNCCorePkg.dcp" set FNCCORE=%%~r\tms.fnc.core\packages\d12\Win32\%%d
  )
)
if "%FNCCORE%"=="" (
  echo VCLTMSFNCCorePkg.dcp not found under tms.fnc.core\packages\d12\Win32. > "%LOG%"
  echo Build the TMS FNC Core packages in the IDE first. >> "%LOG%"
  type "%LOG%"
  exit /b 2
)

rem --- a stray project .cfg would win ----------------------------------
rem dcc32 reads a config named after the project it is compiling, from
rem that project's own folder, as well as the dcc32.cfg in the current
rem directory - and the project one wins. Four of these were inherited
rem from the original author's Delphi 5 install, carrying
rem -LE"c:\programmi\borland\delphi5\Projects\Bpl", a -U pointing at a
rem source folder on his machine and -$D- against our -$D+. They are
rem deleted; this refuses to compile if one ever comes back, because
rem the alternative is a build configured by a file nobody read.
set STRAYCFG=
if exist "%ROOT%\Packages\delphi\FNCCadSysVCL.cfg" set STRAYCFG=%ROOT%\Packages\delphi\FNCCadSysVCL.cfg
if exist "%ROOT%\Packages\delphi\FNCCadSysFMX.cfg" set STRAYCFG=%ROOT%\Packages\delphi\FNCCadSysFMX.cfg
if defined STRAYCFG (
  echo A stale project config is present: %STRAYCFG% > "%LOG%"
  echo dcc32 would read it instead of this script's. Delete it. >> "%LOG%"
  type "%LOG%"
  exit /b 2
)

echo === package build %DATE% %TIME% (BDS %BDSVER%) > "%LOG%"
echo --- dcp folder: %DCPDIR% >> "%LOG%"
echo --- fnc core:   %FNCCORE% >> "%LOG%"

rem --- VCL -------------------------------------------------------------
rem Its own directory, its own dcc32.cfg, its own dcu folder: the two
rem packages are built with different defines and different namespaces,
rem and dcus from one are poison to the other.
set CFG=%OUT%\pkg\dcc32.cfg
> "%CFG%" echo -U"%BDSROOT%lib\Win32\release;%DCPDIR%;%ROOT%\Sources;%FNCCORE%"
>>"%CFG%" echo -I"%BDSROOT%lib\Win32\release;%ROOT%\Sources"
>>"%CFG%" echo -R"%BDSROOT%lib\Win32\release;%ROOT%\Sources;%ROOT%\Packages\delphi"
>>"%CFG%" echo -O"%BDSROOT%lib\Win32\release"
>>"%CFG%" echo -NSVcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell;System;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win
>>"%CFG%" echo -N0"%OUT%\pkg\dcu-vcl"
>>"%CFG%" echo -LE"%OUT%\pkg"
>>"%CFG%" echo -LN"%OUT%\pkg\dcp"
>>"%CFG%" echo -$D+
>>"%CFG%" echo -$L+
>>"%CFG%" echo -$Y+
>>"%CFG%" echo -DDEBUG

pushd "%OUT%\pkg"
echo --- package: FNCCadSysVCL.dpk >> "%LOG%"
echo --- dcc32 config: >> "%LOG%"
type "%CFG%" >> "%LOG%"
%DCC% -B "%ROOT%\Packages\delphi\FNCCadSysVCL.dpk" >> "%LOG%" 2>&1
set VCLERR=%ERRORLEVEL%
echo === dcc32 exit %VCLERR% >> "%LOG%"
popd

rem --- FMX -------------------------------------------------------------
rem CADSYS_FMX on the command line, because the dpk relies on the dproj
rem to define it and dcc32 never reads the dproj. FMX namespaces and
rem not the Vcl ones, so a bare Graphics or Controls cannot quietly
rem resolve to a VCL unit - the same rule as build-fmx.cmd.
> "%CFG%" echo -U"%BDSROOT%lib\Win32\release;%DCPDIR%;%ROOT%\Sources;%FNCCORE%"
>>"%CFG%" echo -I"%BDSROOT%lib\Win32\release;%ROOT%\Sources"
>>"%CFG%" echo -R"%BDSROOT%lib\Win32\release;%ROOT%\Sources;%ROOT%\Packages\delphi"
>>"%CFG%" echo -O"%BDSROOT%lib\Win32\release"
>>"%CFG%" echo -NSSystem;Xml;Data;Datasnap;Web;Soap;FMX;Winapi;System.Win
>>"%CFG%" echo -N0"%OUT%\pkg\dcu-fmx"
>>"%CFG%" echo -LE"%OUT%\pkg"
>>"%CFG%" echo -LN"%OUT%\pkg\dcp"
>>"%CFG%" echo -$D+
>>"%CFG%" echo -$L+
>>"%CFG%" echo -$Y+
>>"%CFG%" echo -DDEBUG;CADSYS_FMX

pushd "%OUT%\pkg"
echo. >> "%LOG%"
echo --- package: FNCCadSysFMX.dpk >> "%LOG%"
echo --- dcc32 config: >> "%LOG%"
type "%CFG%" >> "%LOG%"
%DCC% -B "%ROOT%\Packages\delphi\FNCCadSysFMX.dpk" >> "%LOG%" 2>&1
set FMXERR=%ERRORLEVEL%
echo === dcc32 exit %FMXERR% >> "%LOG%"
popd

if not "%VCLERR%"=="0" (
  echo VCL PACKAGE FAILED - see Tools\logs\build-packages.log
)
if not "%FMXERR%"=="0" (
  echo FMX PACKAGE FAILED - see Tools\logs\build-packages.log
)
if not "%VCLERR%"=="0" exit /b %VCLERR%
if not "%FMXERR%"=="0" exit /b %FMXERR%

echo PACKAGES OK - bpl and dcp in Tools\build\pkg (nothing installed)
exit /b 0
