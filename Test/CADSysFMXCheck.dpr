{ : Compiles the whole library with CADSYS_FMX defined, and does nothing
  else.

  There is no FMX demo or test suite yet, and writing one before the
  units compile would mean debugging two unknowns at once. This program
  exists so the FMX error loop is a compile, not a UI. It links every
  unit in dependency order, so anything the FMX branches got wrong
  surfaces here. The units come from Generated\FMX, which is what
  defines CADSYS_FMX - see Tools\gen-units.ps1.

  The compiler is deliberately given the FMX namespaces and *not* the
  Vcl ones (see Tools\build-fmx.cmd), so a bare 'Graphics' or 'Controls'
  that slipped into a shared uses clause cannot quietly resolve to the
  VCL unit and hide the problem until someone builds a real FMX project.

  Run it through Tools\build-fmx.cmd, not the IDE. }
program CADSysFMXCheck;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  FMX.FNCCS4Graphics,
  FMX.FNCCS4BaseTypes,
  FMX.FNCCS4JSON,
  FMX.FNCCS4GraphicsFNC,
  FMX.FNCCADSys4,
  FMX.FNCCS4Shapes,
  FMX.FNCCS4Tasks,
  FMX.FNCCS4DXFModule,
  FMX.FNCCS4Legacy,
  FMX.FNCCS4Paper,
  FMX.FNCCS4Views,
  FMX.FNCCS4Print,
  FMX.FNCCS4Preview,
  FMX.FNCCS4PDF,
  FMX.FNCCadSysRegister;

begin
  { Touching one thing from each layer, so the linker cannot discard the
    units before the compiler has had an opinion about them. }
  Writeln('CADSys built for FMX.');
  Writeln('  drawing layer : ', SizeOf(TCADColor), ' byte colour');
  Writeln('  shapes        : ', TLine2D.ClassName);
  Writeln('  viewport      : ', TFNCCADViewport2D.ClassName);
  Writeln('  tasks         : ', TCAD2DExplodeObjects.ClassName);
  Writeln('  page model    : ', CADPaperKindName(pkA3), ' ',
    TCADPageSetup.Default.UnitsPerMM:0:1, ' units/mm');
  Writeln('  preview       : ', TFNCPrintPreview.ClassName);
  Writeln('  pdf           : ', CADPDFResolution, ' dpi layout, ',
    CADPDFPointsPerMM:0:3, ' points/mm');
end.
