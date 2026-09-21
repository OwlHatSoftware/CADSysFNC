{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit FNCCADSys;

{$warn 5023 off : no warning about unused units}
interface

uses
  FNCCADSys4, FNCCS4BaseTypes, FNCCS4DXFModule, FNCCS4Shapes, FNCCS4Tasks, FNCCS4Graphics, 
  FNCCS4GraphicsVCL, FNCCS4JSON, FNCCadSysReg, 
  LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('FNCCadSysReg', @FNCCadSysReg.Register);
end;

initialization
  RegisterPackage('FNCCADSys', @Register);
end.
