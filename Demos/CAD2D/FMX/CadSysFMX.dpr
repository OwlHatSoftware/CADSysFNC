program CadSysFMX;

uses
  System.StartUpCopy,
  System.SysUtils,
  FMX.Forms,
  DemoDlg in 'DemoDlg.pas',
  DemoLog in '..\..\common\DemoLog.pas',
  LayersFrm in 'LayersFrm.pas',
  PrintPrvFrm in 'PrintPrvFrm.pas',
  MainFrm in 'MainFrm.pas' {MainForm};

{$R *.res}

begin
  { Everything is wrapped, because the interesting failures here happen
    during construction - before there is a form to show a dialog on,
    and before FMX has an exception handler installed. Without this the
    result is a bare Windows application error and no clue. }
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
