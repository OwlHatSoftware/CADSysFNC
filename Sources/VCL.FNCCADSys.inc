{ ============================================================================
  VCL.FNCCADSys.inc - this is the VCL build.

  The master. Tools\gen-units.ps1 rewrites VCL.FNCC to FMX.FNCC and
  LCLFNCC when it makes the other two trees, which turns every
  include directive naming this file into one naming its sibling. Edit
  this one; the others are build artifacts, except for the single
  DEFINE line each of them carries, which is why they are separate files
  rather than generated copies of this one.
  ============================================================================ }

{$DEFINE CADSYS_VCL}

{$I CADSysCommon.inc}
