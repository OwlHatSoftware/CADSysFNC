{ ============================================================================
  CADSysCommon.inc - the part of the framework selection that is the same
  for all three.

  Not included directly. Each framework has its own file beside this one,
  named for that framework, which defines its own CADSYS_* symbol and then
  includes this. (The three names are not written out here on purpose:
  the generator rewrites that text wherever it appears, comments
  included, and a comment listing all three would come out of the FMX
  tree naming FMX twice.) A unit includes the one
  named for its framework, and the generator (Tools\gen-units.ps1) rewrites
  that name along with everything else when it makes the per-framework
  copies. So the copy IS the framework: there is nothing a project can
  forget to define, and nothing it can define wrongly.

  That is the whole point of the arrangement. Before it, a project that
  did not define CADSYS_FMX silently got the VCL, and the first symptom
  was E2010 about TWinControl and TMainForm several thousand lines away.

  Three rules for the units that include this:

  - Never test FMXLIB/VCLLIB/LCLLIB directly. Those belong to TMS FNC and
    are not guaranteed to be set in a project that only uses CADSys.
  - RTL units are spelled with their scope on Delphi (System.SysUtils) and
    without it on FPC (SysUtils), under IFDEF CADSYS_LCL. Writing them
    bare everywhere and leaning on Delphi's unit scope names - which is
    what TMS FNC does - works, but it makes 'Graphics' mean whichever of
    Vcl and FMX the project happens to list first. These units carry all
    three frameworks in one copy, so they cannot afford that ambiguity.
  - Prefer IFDEF CADSYS_VCL ... ELSE over listing FMX and LCL separately
    when the two agree, which is most of the time: the VCL is the odd one
    out because it is the only target with a GDI backend.

  A framework-free unit still includes a framework file - FPC needs the
  mode and string dialect set before anything else - but must never test
  CADSYS_*. If one starts wanting to, it is no longer framework-free, and
  that is worth noticing rather than papering over.

  The directives named in this comment are written without their braces
  on purpose. A brace comment does not nest, so a real directive in this
  prose would end the comment at its own closing brace and quietly turn
  everything after it into code.
  ============================================================================ }

{ Two frameworks at once is always a configuration mistake, and it is far
  cheaper to say so here than to let it surface as a puzzling error in a
  uses clause several thousand lines away.

  It is still reachable: a project can define CADSYS_FMX and then compile
  the VCL tree. That is exactly the mistake worth catching, and it is now
  caught at the first unit rather than at the first incompatible type. }
{$IFDEF CADSYS_VCL}
  {$IFDEF CADSYS_FMX}
    {$MESSAGE Fatal 'CADSys: CADSYS_FMX is defined but this is the VCL tree. Compile against Generated\FMX, or stop defining it.'}
  {$ENDIF}
  {$IFDEF CADSYS_LCL}
    {$MESSAGE Fatal 'CADSys: CADSYS_LCL is defined but this is the VCL tree.'}
  {$ENDIF}
{$ENDIF}
{$IFDEF CADSYS_FMX}
  {$IFDEF CADSYS_LCL}
    {$MESSAGE Fatal 'CADSys: CADSYS_LCL is defined but this is the FMX tree.'}
  {$ENDIF}
{$ENDIF}
