program CadSysVCL;

uses
  {$IFDEF EurekaLog}
  EMemLeaks,
  EResLeaks,
  EResourceStrings,
  EDebugJCL,
  EDebugExports,
  EFixSafeCallException,
  EMapWin32,
  EAppVCL,
  EDialogWinAPIMSClassic,
  EDialogWinAPIEurekaLogDetailed,
  EDialogWinAPIStepsToReproduce,
  EBase,
  ExceptionLog7,
  {$ENDIF EurekaLog}
  Forms,
  SysUtils,
  DemoLog in '..\..\common\DemoLog.pas',
  DemoDlg in 'DemoDlg.pas',
  LayersFrm in 'LayersFrm.pas',
  PrintPrvFrm in 'PrintPrvFrm.pas',
  MainFrm in 'MainFrm.pas' {MainForm};

{$R *.RES}

begin
  { Wrapped and logged exactly as the FMX demo is - see
    Demos\CAD2D\FMX\CadSysFMX.dpr. The two are meant to be diffed, and
    a failure during construction should produce the same evidence
    whichever framework it happened in. }
  ReportMemoryLeaksOnShutdown := True;
  LogStart;
  try
    Log('Application.Initialize');
    Application.Initialize;
    Log('Application.CreateForm');
    Application.CreateForm(TMainForm, MainForm);
    Log('Application.Run');
    Application.Run;
    Log('clean exit');
  except
    on E: Exception do
    begin
      LogError('startup', E);
      raise;
    end;
  end;
end.

