{ ============================================================================
  CADSys.inc - kept for projects written against the old arrangement.

  It selects the VCL, which is what not defining anything used to do, so
  an existing VCL project that includes it keeps compiling. (Written
  without its braces above for the usual reason: a directive inside a
  brace comment ends the comment at its own closing brace.)

  New code should include the file named for its framework -
  VCL.FNCCADSys.inc, FMX.FNCCADSys.inc or LCLFNCCADSys.inc - because that
  is the name the generator rewrites. This file is emitted into the VCL
  tree only, and deliberately: an FMX project that reached for it would
  be asking for exactly the mistake the new arrangement exists to stop.
  ============================================================================ }

{$I VCL.FNCCADSys.inc}
