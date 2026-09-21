unit FNCCadSysReg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

procedure Register;

implementation

uses
  FNCCADSys4;

{$R FNCCadSys.dcr}

procedure Register;
begin
  RegisterComponents('FNCCadSys', [TFNCRuler]);
  RegisterComponents('FNCCadSys 2D', [TFNCCADCmp2D, TFNCCADViewport2D, TFNCCADPrg2D]);
  RegisterComponents('FNCCadSys 3D', [TFNCCADCmp3D, TFNCCADParallelViewport3D, TFNCCADOrtogonalViewport3D, TFNCCADPerspectiveViewport3D, TFNCCADPrg3D]);
end;

end.

