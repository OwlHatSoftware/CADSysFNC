program CADSysFNCTests;

{ DUnitX console test runner for the TMS FNC drawing backend of CADSys.
  Needs TMS FNC Core (VCL) on the library path.

  Build:   the library units are reached through the unit search path
           ..\Sources, set in CADSys4Tests.dproj. Nothing from Sources is
           listed here, so the tests always compile against the real units.

  Run:     CADSys4Tests.exe                  full run, console output
           CADSys4Tests.exe --exitbehavior:Continue    for CI (no pause)
           CADSys4Tests.exe --xmloutput:results.xml    NUnit XML for CI

  Note:    VCL.FNCCadSysRegister is pulled in by the test units and its
           initialization section is what populates the class and font
           registries. Without it, anything that streams an object or looks
           a class up by name raises ECADObjClassNotFound.
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
  CADSys4.Tests.GraphicsFNC in 'CADSys4.Tests.GraphicsFNC.pas';

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
