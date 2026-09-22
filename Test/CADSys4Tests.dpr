program CADSys4Tests;

{ DUnitX console test runner for the CADSys 4.2 library.

  Build:   the library units are reached through the unit search path
           ..\Sources, set in CADSys4Tests.dproj. Nothing from Sources is
           listed here, so the tests always compile against the real units.

  Run:     CADSys4Tests.exe                  full run, console output
           CADSys4Tests.exe --exitbehavior:Continue    for CI (no pause)
           CADSys4Tests.exe --xmloutput:results.xml    NUnit XML for CI

  Note:    FNCCadSysRegister is pulled in by the test units and its
           initialization section is what populates the class and font
           registries. Without it, anything that streams an object or looks
           a class up by name raises ECADObjClassNotFound.

  Note:    FNCCS4ExportVCL is listed below with nothing testing it, on
           purpose. It has no tests because printing and the clipboard
           need a device; but it is a library unit, and a unit that no
           build ever compiles rots. It did: it sat broken from the day
           it was written, calling three members of TFNCCADViewport that
           were private or protected, and nobody found out until the
           package was next built. Listing it here means the suite fails
           to build rather than the user's project.
}

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ENDIF }
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  CADSys4.Tests.Geometry in 'CADSys4.Tests.Geometry.pas',
  CADSys4.Tests.Structures in 'CADSys4.Tests.Structures.pas',
  CADSys4.Tests.Shapes in 'CADSys4.Tests.Shapes.pas',
  CADSys4.Tests.Persistence in 'CADSys4.Tests.Persistence.pas',
  CADSys4.Tests.Regressions in 'CADSys4.Tests.Regressions.pas',
  CADSys4.Tests.Graphics in 'CADSys4.Tests.Graphics.pas',
  CADSys4.Tests.DXF in 'CADSys4.Tests.DXF.pas',
  CADSys4.Tests.Legacy in 'CADSys4.Tests.Legacy.pas',
  FNCCS4ExportVCL;

{$IFNDEF TESTINSIGHT}
var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;
{$ENDIF}

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  try
    { Let the command line override anything below. }
    TDUnitX.CheckCommandLine;

    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;

    { Several fixtures assert only that an operation does not raise, or are
      [Ignore]d placeholders that record a coverage gap. Neither should be
      reported as a failure for lack of an assertion. }
    Runner.FailsOnNoAsserts := False;

    if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
    begin
      Logger := TDUnitXConsoleLogger.Create(
        TDUnitX.Options.ConsoleMode = TDunitXConsoleMode.Quiet);
      Runner.AddLogger(Logger);
    end;

    NUnitLogger := TDUnitXXMLNUnitFileLogger.Create(
      TDUnitX.Options.XMLOutputFile);
    Runner.AddLogger(NUnitLogger);

    Results := Runner.Execute;
    if not Results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

{$IFNDEF CI}
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
{$ENDIF}
  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := EXIT_ERRORS;
    end;
  end;
{$ENDIF}
end.
