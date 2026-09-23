{ ============================================================================
  LCLFNCCADSys.inc - this is the Lazarus/LCL build.

  The sibling of the VCL file. The three mode switches are the same
  ones TMS FNC's own LCLTMSFNCDefines.inc turns on, and they have to come
  before anything else the compiler reads: this is Delphi source being
  compiled by FPC.
  ============================================================================ }

{$DEFINE CADSYS_LCL}

{$MODE DELPHI}
{$H+}
{$MODESWITCH ADVANCEDRECORDS}

{$I CADSysCommon.inc}
