{: VCL export helpers for CADSys.

   Everything here puts a drawing onto something that only exists on the
   VCL: a <I=TCanvas>, a printer, the clipboard. The viewport itself no
   longer knows about any of those - it copies onto a
   <See Class=TDecorativeCanvas> and calibrates from a millimetres-per-pixel
   figure - which is what lets VCL.FNCCADSys4 compile for FMX and LCL as well.

   These are plain routines rather than methods so that the unit is purely
   additive: add it to your uses clause and the old calls keep their shape.

     CADCopyToCanvas(Viewport, Printer.Canvas, cmAspect, cvExtension, 1, 1);
     CADCopyToClipboard(Viewport, Clipboard);

   Nothing in the library uses this unit, so a project that does not need
   it does not link it.
}
unit VCL.FNCCS4ExportVCL;

{$I VCL.FNCCADSys.inc}

{$IFNDEF CADSYS_VCL}
{$MESSAGE Fatal 'VCL.FNCCS4ExportVCL is VCL-only (the printing and clipboard helpers). Remove it from the FMX or LCL package rather than compiling it there.'}
{$ENDIF}

interface

uses
  WinAPI.Windows, System.Types, System.UITypes, System.Classes,
  Vcl.Graphics, Vcl.ClipBrd,
  VCL.FNCCS4BaseTypes, VCL.FNCCS4Graphics, VCL.FNCCS4GraphicsVCL, VCL.FNCCADSys4;

{: The size of one pixel of <I=Cnv>, in millimetres. It is what
   <See Method=TFNCCADViewport@CalibrateMM> wants, and it is the one thing
   about a canvas the viewport cannot work out for itself. }
procedure CADCanvasMMPerPixel(const Cnv: TCanvas;
  out AMMPerPixelX, AMMPerPixelY: TRealType);

{: Scales the viewport so that one drawing unit comes out at the given
   scale on <I=Cnv>. The screen version is CADCalibrate. }
procedure CADCalibrateToCanvas(const V: TFNCCADViewport; const Cnv: TCanvas;
  const XScale, YScale: TRealType);

{: The same, against the viewport's own screen surface. }
procedure CADCalibrate(const V: TFNCCADViewport;
  const XScale, YScale: TRealType);

{: Draws <I=CADRect> of the drawing onto <I=CanvasRect> of <I=Cnv>. }
procedure CADCopyRectToCanvas(const V: TFNCCADViewport; CADRect: TRect2D;
  const CanvasRect: TRect; const Cnv: TCanvas; const Mode: TCanvasCopyMode);

{: Draws the whole view onto <I=Cnv>. <I=View> says what to fit: the
   current view, the drawing's extension, or the given scale. }
procedure CADCopyToCanvas(const V: TFNCCADViewport; const Cnv: TCanvas;
  const Mode: TCanvasCopyMode; const View: TCanvasCopyView;
  const XScale, YScale: TRealType);

{: Puts the viewport's off-screen buffer on the clipboard. }
procedure CADCopyToClipboard(const V: TFNCCADViewport; const Clp: TClipboard);

implementation

{ : The millimetres-per-pixel of a device context. The one place that
  actually asks GDI, so both entry points below give the same answer. }
procedure DCMMPerPixel(const DC: HDC;
  out AMMPerPixelX, AMMPerPixelY: TRealType);
var
  TmpRes: Integer;
begin
  AMMPerPixelX := 0;
  AMMPerPixelY := 0;
  if DC = 0 then
    Exit;
  TmpRes := GetDeviceCaps(DC, HORZRES);
  if TmpRes <> 0 then
    AMMPerPixelX := GetDeviceCaps(DC, HORZSIZE) / TmpRes;
  TmpRes := GetDeviceCaps(DC, VERTRES);
  if TmpRes <> 0 then
    AMMPerPixelY := GetDeviceCaps(DC, VERTSIZE) / TmpRes;
end;

procedure CADCanvasMMPerPixel(const Cnv: TCanvas;
  out AMMPerPixelX, AMMPerPixelY: TRealType);
begin
  AMMPerPixelX := 0;
  AMMPerPixelY := 0;
  if Cnv = nil then
    Exit;
  DCMMPerPixel(Cnv.Handle, AMMPerPixelX, AMMPerPixelY);
end;

procedure CADCalibrateToCanvas(const V: TFNCCADViewport; const Cnv: TCanvas;
  const XScale, YScale: TRealType);
var
  TmpX, TmpY: TRealType;
begin
  if V = nil then
    Exit;
  CADCanvasMMPerPixel(Cnv, TmpX, TmpY);
  V.CalibrateMM(TmpX, TmpY, XScale, YScale);
end;

procedure CADCalibrate(const V: TFNCCADViewport;
  const XScale, YScale: TRealType);
var
  TmpDC: HDC;
  TmpX, TmpY: TRealType;
begin
  if V = nil then
    Exit;
  { The screen's own device context, not the viewport's canvas.
    TCustomControl.Canvas is protected, so this unit cannot reach it -
    and it does not need to: a control's canvas reports the metrics of
    the screen it sits on, which is exactly what a screen DC gives. }
  TmpDC := GetDC(0);
  try
    DCMMPerPixel(TmpDC, TmpX, TmpY);
  finally
    ReleaseDC(0, TmpDC);
  end;
  V.CalibrateMM(TmpX, TmpY, XScale, YScale);
end;

procedure CADCopyRectToCanvas(const V: TFNCCADViewport; CADRect: TRect2D;
  const CanvasRect: TRect; const Cnv: TCanvas; const Mode: TCanvasCopyMode);
var
  TmpCanvas: TDecorativeCanvas;
begin
  if (V = nil) or (Cnv = nil) then
    Exit;
  TmpCanvas := TDecorativeCanvas.Create(Cnv);
  try
    V.CopyRectToCanvas(CADRect, CanvasRect, TmpCanvas, Mode);
  finally
    TmpCanvas.Free;
  end;
end;

procedure CADCopyToCanvas(const V: TFNCCADViewport; const Cnv: TCanvas;
  const Mode: TCanvasCopyMode; const View: TCanvasCopyView;
  const XScale, YScale: TRealType);
var
  TmpCanvas: TDecorativeCanvas;
  TmpX, TmpY: TRealType;
begin
  if (V = nil) or (Cnv = nil) then
    Exit;
  CADCanvasMMPerPixel(Cnv, TmpX, TmpY);
  TmpCanvas := TDecorativeCanvas.Create(Cnv);
  try
    V.CopyToCanvas(TmpCanvas, Mode, View, TmpX, TmpY, XScale, YScale);
  finally
    TmpCanvas.Free;
  end;
end;

procedure CADCopyToClipboard(const V: TFNCCADViewport; const Clp: TClipboard);
begin
  if (V = nil) or (Clp = nil) then
    Exit;
  Clp.Assign(V.OffScreenBitmap);
end;

end.
