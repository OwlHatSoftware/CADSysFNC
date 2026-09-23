{ ============================================================================
  FMX.FNCCADSys.inc - this is the FMX build.

  The sibling of the VCL file, which is the master for everything except
  the DEFINE below. A unit reaches this file because the generator
  rewrote its include directive, so nothing a project does can select it
  by accident or fail to select it.
  ============================================================================ }

{$DEFINE CADSYS_FMX}

{$I CADSysCommon.inc}
