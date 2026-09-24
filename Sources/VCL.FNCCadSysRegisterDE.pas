{: The design-time half of registration: the component palette.

   Separate from VCL.FNCCadSysRegister because the two have different
   homes. The class registry is needed by every application; the palette
   is needed only by the IDE, and the package carrying it is the one that
   requires designide. Keeping RegisterComponents out of the runtime
   package is what lets the runtime packages be RUNONLY and lets a single
   design-time package register both frameworks at once.
}
unit VCL.FNCCadSysRegisterDE;

{$I VCL.FNCCADSys.inc}

interface

uses
  Classes;

procedure Register;

implementation

uses
  { For the components themselves, and for the class registry that
    anything streamed from the palette is going to need. }
  VCL.FNCCADSys4, VCL.FNCCS4Preview, VCL.FNCCadSysRegister;

procedure Register;
begin
  { All three, on both frameworks. The IDE keeps one registration per
    component class name and tells the VCL and FMX copies apart by their
    ancestry: the viewport through TTMSFNCCustomControl, and the other
    two through TFmxObject - which is why they descend from it on FMX.
    See TFNCCADCmp. }
  RegisterComponents('FNCCadSys',
    [TFNCCADCmp2D, TFNCCADViewport2D, TFNCCADPrg2D, TFNCPrintPreview]);
end;

end.
