{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit FNCCADSys;

{$warn 5023 off : no warning about unused units}
interface

uses
  LCLFNCCADSys4, LCLFNCCS4BaseTypes, LCLFNCCS4DXFModule, LCLFNCCS4Shapes, LCLFNCCS4Tasks, LCLFNCCS4Graphics, 
  LCLFNCCS4GraphicsVCL, LCLFNCCS4JSON, FNCCadSysReg, 
  LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('FNCCadSysReg', @FNCCadSysReg.Register);
end;

initialization
  RegisterPackage('FNCCADSys', @Register);
end.
