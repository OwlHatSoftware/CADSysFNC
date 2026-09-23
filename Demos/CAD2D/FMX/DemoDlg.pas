{ : The handful of dialogs the demo needs, in one place.

  The VCL demo reaches for InputQuery and ShowMessage from Vcl.Dialogs
  without thinking about it. FMX has equivalents but spells them
  differently, and the spelling has changed more than once across
  versions - TDialogService is the supported route now, with a
  synchronous flavour for desktop.

  Wrapping them here means the demo's own code reads the same as the
  VCL one, and that if a spelling turns out to be wrong there is exactly
  one place to fix rather than fifteen call sites. }
unit DemoDlg;

{$I FMX.FNCCADSys.inc}

interface

uses
  System.SysUtils, System.UITypes;

{: Asks for one string. Returns False if the user cancelled. }
function AskString(const ACaption, APrompt: string;
  var AValue: string): Boolean;
{: Asks for two strings at once - a point, in practice. }
function AskTwoStrings(const ACaption, APrompt1, APrompt2: string;
  var AValue1, AValue2: string): Boolean;
{: Says something and waits for an acknowledgement. }
procedure Say(const AMessage: string);

implementation

uses
  FMX.Dialogs, FMX.DialogService.Sync;

function AskString(const ACaption, APrompt: string;
  var AValue: string): Boolean;
var
  TmpValues: array of string;
begin
  SetLength(TmpValues, 1);
  TmpValues[0] := AValue;
  Result := TDialogServiceSync.InputQuery(ACaption, [APrompt], TmpValues);
  if Result then
    AValue := TmpValues[0];
end;

function AskTwoStrings(const ACaption, APrompt1, APrompt2: string;
  var AValue1, AValue2: string): Boolean;
var
  TmpValues: array of string;
begin
  SetLength(TmpValues, 2);
  TmpValues[0] := AValue1;
  TmpValues[1] := AValue2;
  Result := TDialogServiceSync.InputQuery(ACaption, [APrompt1, APrompt2],
    TmpValues);
  if Result then
  begin
    AValue1 := TmpValues[0];
    AValue2 := TmpValues[1];
  end;
end;

procedure Say(const AMessage: string);
begin
  TDialogServiceSync.MessageDialog(AMessage, TMsgDlgType.mtInformation,
    [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0);
end;

end.
