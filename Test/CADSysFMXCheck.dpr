{ : Compiles the whole library with CADSYS_FMX defined, and does nothing
  else.

  There is no FMX demo or test suite yet, and writing one before the
  units compile would mean debugging two unknowns at once. This program
  exists so the FMX error loop is a compile, not a UI. It links every
  unit in dependency order, so anything the FMX branches of CADSys.inc
  got wrong surfaces here.

  The compiler is deliberately given the FMX namespaces and *not* the
  Vcl ones (see Tools\build-fmx.cmd), so a bare 'Graphics' or 'Controls'
  that slipped into a shared uses clause cannot quietly resolve to the
  VCL unit and hide the problem until someone builds a real FMX project.

  Run it through Tools\build-fmx.cmd, not the IDE. }
program CADSysFMXCheck;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  FNCCS4Graphics in '..\Sources\FNCCS4Graphics.pas',
  FNCCS4BaseTypes in '..\Sources\FNCCS4BaseTypes.pas',
  FNCCS4JSON in '..\Sources\FNCCS4JSON.pas',
  FNCCS4GraphicsFNC in '..\Sources\FNCCS4GraphicsFNC.pas',
  FNCCADSys4 in '..\Sources\FNCCADSys4.pas',
  FNCCS4Shapes in '..\Sources\FNCCS4Shapes.pas',
  FNCCS4Tasks in '..\Sources\FNCCS4Tasks.pas',
  FNCCS4DXFModule in '..\Sources\FNCCS4DXFModule.pas',
  FNCCS4Legacy in '..\Sources\FNCCS4Legacy.pas',
  FNCCadSysRegister in '..\Sources\FNCCadSysRegister.pas';

begin
  { Touching one thing from each layer, so the linker cannot discard the
    units before the compiler has had an opinion about them. }
  Writeln('CADSys built for FMX.');
  Writeln('  drawing layer : ', SizeOf(TCADColor), ' byte colour');
  Writeln('  shapes        : ', TLine2D.ClassName);
  Writeln('  viewport      : ', TFNCCADViewport2D.ClassName);
  Writeln('  tasks         : ', TCAD2DExplodeObjects.ClassName);
end.
