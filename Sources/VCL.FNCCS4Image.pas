{ : PNG images of a sheet, or of a rectangle of the model, at a given
  resolution - CS-04 of docs\masterplanner-changes.md.

  Drawn by the same routines as everything else: a sheet through
  <See Procedure=CADDrawSheet>, onto an FNC bitmap through the FNC
  backend, so a PNG shows what the preview, the printer and the PDF
  show. Nothing in here draws.

  TRANSPARENCY

  On FMX the bitmap has an alpha channel that the drawing writes, so a
  transparent image is the drawing on a bitmap that was never filled.
  On the VCL the FNC bitmap is drawn through GDI+ onto a GDI bitmap,
  which keeps no alpha of its own. There the drawing is made twice, on
  white and on black, and each pixel's alpha read off the difference:

    on white  Cw = a*c + (1-a)*255
    on black  Cb = a*c
    so        a  = 1 - (Cw - Cb)/255   and   c = Cb/a

  which is exact for anything the drawing does, translucent layers and
  anti-aliased edges included, and needs nothing from the backend.

  SIZE

  An A0 sheet at 600 dpi is nearly 20,000 by 28,000 pixels, more than a
  32-bit process can hold as one bitmap. Anything over
  <See Variable=CADImageMaxPixels> is refused with ECADPageError rather
  than half-made: choose a lower resolution, or a PDF or SVG, which
  have no such limit. }
unit VCL.FNCCS4Image;

{$I VCL.FNCCADSys.inc}

interface

uses
{$IFDEF CADSYS_LCL}
  Classes, SysUtils, Types, Math,
{$ELSE}
  System.Classes, System.SysUtils, System.Types, System.Math,
{$ENDIF}
  VCL.FNCCS4BaseTypes, VCL.FNCCS4Graphics, VCL.FNCCS4Paper,
  VCL.FNCCADSys4;

var
  { : The largest image, in pixels, the export will make. 80 million is
    an A1 sheet at 300 dpi with a little to spare - about 320 MB of
    bitmap, twice that on the VCL for a transparent one. }
  CADImageMaxPixels: Int64 = 80000000;

{ : ASheet as a PNG at ADPI, paper size: an A3 sheet at 300 dpi is
  4961 x 3508 pixels. ATransparent leaves the paper unpainted, so only
  what is drawn on it covers what the image is put on. }
procedure CADSaveSheetToImage(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet; const AFileName: String;
  const ADPI: Integer = 300; const ATransparent: Boolean = False);
{ : The same, into AStream - for the clipboard, or a document of the
  application's own. }
procedure CADSaveSheetToPNGStream(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet; const AStream: TStream;
  const ADPI: Integer = 300; const ATransparent: Boolean = False);

{ : ARect of the model as a PNG, at AUnitsPerMM drawing units to the
  millimetre and ADPI: the image is as large as ARect would be on paper
  at that scale. Every object on a visible layer that reaches into
  ARect is drawn, cut at its edge. }
procedure CADSaveModelRectToImage(const ACAD: TFNCCADCmp2D;
  const ARect: TRect2D; const AUnitsPerMM: TRealType;
  const AFileName: String; const ADPI: Integer = 300;
  const ATransparent: Boolean = False);
procedure CADSaveModelRectToPNGStream(const ACAD: TFNCCADCmp2D;
  const ARect: TRect2D; const AUnitsPerMM: TRealType;
  const AStream: TStream; const ADPI: Integer = 300;
  const ATransparent: Boolean = False);

{ : The pixel size the two would make, without making anything - for a
  dialog that shows it, or checks it against CADImageMaxPixels first. }
function CADSheetImageSize(const ASheet: TCADSheet;
  const ADPI: Integer): TPoint;
function CADModelRectImageSize(const ARect: TRect2D;
  const AUnitsPerMM: TRealType; const ADPI: Integer): TPoint;

implementation

uses
{$IFDEF CADSYS_FMX}
  System.UITypes, FMX.Graphics,
  FMX.TMSFNCTypes, FMX.TMSFNCGraphicsTypes, FMX.TMSFNCGraphics,
{$ENDIF}
{$IFDEF CADSYS_VCL}
  Vcl.Graphics, Vcl.Imaging.pngimage,
  VCL.TMSFNCTypes, VCL.TMSFNCGraphicsTypes, VCL.TMSFNCGraphics,
{$ENDIF}
{$IFDEF CADSYS_LCL}
  LCLTMSFNCTypes, LCLTMSFNCGraphicsTypes, LCLTMSFNCGraphics,
{$ENDIF}
  VCL.FNCCS4GraphicsFNC;

type
  TCADImageDraw = reference to procedure(const ACanvas: TDecorativeCanvas);

function CADSheetImageSize(const ASheet: TCADSheet;
  const ADPI: Integer): TPoint;
var
  TmpW, TmpH: TRealType;
  TmpDevice: TCADPageDevice;
begin
  Result := Point(0, 0);
  if (ASheet = nil) or (ADPI <= 0) then
    Exit;
  ASheet.SizeMM(TmpW, TmpH);
  TmpDevice := TCADPageDevice.FromDPI(ADPI, ADPI);
  Result := Point(TmpDevice.MMToPxX(TmpW), TmpDevice.MMToPxY(TmpH));
end;

function CADModelRectImageSize(const ARect: TRect2D;
  const AUnitsPerMM: TRealType; const ADPI: Integer): TPoint;
var
  TmpRect: TRect2D;
  TmpDevice: TCADPageDevice;
begin
  Result := Point(0, 0);
  if (AUnitsPerMM <= 0) or (ADPI <= 0) then
    Exit;
  TmpRect := ReorderRect2D(ARect);
  TmpDevice := TCADPageDevice.FromDPI(ADPI, ADPI);
  Result := Point(TmpDevice.MMToPxX((TmpRect.Right - TmpRect.Left) /
    AUnitsPerMM), TmpDevice.MMToPxY((TmpRect.Top - TmpRect.Bottom) /
    AUnitsPerMM));
end;

procedure CheckSize(const ASize: TPoint);
begin
  if (ASize.X <= 0) or (ASize.Y <= 0) then
    Raise ECADPageError.Create('Nothing to make an image of');
  if Int64(ASize.X) * ASize.Y > CADImageMaxPixels then
    Raise ECADPageError.CreateFmt('An image of %d x %d pixels is larger ' +
      'than CADImageMaxPixels allows - use a lower resolution, or a PDF ' +
      'or SVG, which have no such limit', [ASize.X, ASize.Y]);
end;

{$IFNDEF CADSYS_LCL}

{ : One rendering: an FNC bitmap ASize big, filled with ABack unless
  AFill is False, and ADraw drawn on it through the FNC backend. The
  caller owns the result and its Bitmap. }
function Render(const ASize: TPoint; const AFill: Boolean;
  const ABack: TTMSFNCGraphicsColor; const APixelsPerMM: TRealType;
  const ADraw: TCADImageDraw): TTMSFNCGraphics;
var
  TmpCAD: TCADFNCGraphics;
  TmpCanvas: TDecorativeCanvas;
begin
  { Not high-DPI: an image of N pixels is N pixels, whatever the
    display the program happens to run on. }
  Result := TTMSFNCGraphics.CreateBitmapCanvas(ASize.X, ASize.Y, False,
    False);
  try
    Result.BeginScene;
    try
      if AFill then
      begin
        Result.Fill.Kind := gfkSolid;
        Result.Fill.Color := ABack;
        Result.Stroke.Kind := gskNone;
        Result.DrawRectangle(RectF(0, 0, ASize.X, ASize.Y), gcrmNone);
      end;
      TmpCAD := TCADFNCGraphics.Create(Result, Rect(0, 0, ASize.X,
        ASize.Y), False);
      TmpCanvas := TDecorativeCanvas.Create(TmpCAD, True);
      try
        { So millimetre line weights and hatch spacing come out at their
          size on paper. CADDrawSheet sets it again for itself. }
        TmpCAD.PixelsPerMM := APixelsPerMM;
        ADraw(TmpCanvas);
      finally
        TmpCanvas.Free;
      end;
    finally
      Result.EndScene;
    end;
  except
    Result.Free;
    Raise;
  end;
end;

{$IFDEF CADSYS_FMX}

procedure SavePNG(const ASize: TPoint; const APixelsPerMM: TRealType;
  const ATransparent: Boolean; const ADraw: TCADImageDraw;
  const AStream: TStream);
var
  TmpG: TTMSFNCGraphics;
begin
  { An FMX bitmap starts out clear and keeps the alpha the drawing
    writes, so a transparent image is one that was never filled. }
  TmpG := Render(ASize, not ATransparent, gcWhite, APixelsPerMM, ADraw);
  try
    TmpG.Bitmap.SaveToStream(AStream);
  finally
    TmpG.Free;
  end;
end;

{$ELSE}

procedure SavePNG(const ASize: TPoint; const APixelsPerMM: TRealType;
  const ATransparent: Boolean; const ADraw: TCADImageDraw;
  const AStream: TStream);
var
  TmpWhite, TmpBlack: TTMSFNCGraphics;
  TmpPNG: TPngImage;
  TmpW, TmpB: PByteArray;
  TmpRGB: PByteArray;
  TmpAlpha: PByteArray;
  X, Y, C, TmpA: Integer;
begin
  TmpWhite := Render(ASize, True, gcWhite, APixelsPerMM, ADraw);
  try
    TmpWhite.Bitmap.PixelFormat := pf24bit;
    if not ATransparent then
    begin
      TmpPNG := TPngImage.Create;
      try
        TmpPNG.Assign(TmpWhite.Bitmap);
        TmpPNG.SaveToStream(AStream);
      finally
        TmpPNG.Free;
      end;
      Exit;
    end;
    { See the unit header: the alpha is what changed between the two. }
    TmpBlack := Render(ASize, True, gcBlack, APixelsPerMM, ADraw);
    try
      TmpBlack.Bitmap.PixelFormat := pf24bit;
      TmpPNG := TPngImage.CreateBlank(COLOR_RGBALPHA, 8, ASize.X, ASize.Y);
      try
        for Y := 0 to ASize.Y - 1 do
        begin
          TmpW := TmpWhite.Bitmap.ScanLine[Y];
          TmpB := TmpBlack.Bitmap.ScanLine[Y];
          TmpRGB := TmpPNG.ScanLine[Y];
          TmpAlpha := TmpPNG.AlphaScanline[Y];
          for X := 0 to ASize.X - 1 do
          begin
            { Green, the channel GDI+ rounds most kindly, decides the
              alpha; all three are then divided by it. }
            TmpA := 255 - (TmpW[X * 3 + 1] - TmpB[X * 3 + 1]);
            if TmpA < 0 then
              TmpA := 0
            else if TmpA > 255 then
              TmpA := 255;
            TmpAlpha[X] := TmpA;
            for C := 0 to 2 do
              if TmpA = 0 then
                TmpRGB[X * 3 + C] := 0
              else
                TmpRGB[X * 3 + C] := Min(255, (TmpB[X * 3 + C] * 255 +
                  TmpA div 2) div TmpA);
          end;
        end;
        TmpPNG.SaveToStream(AStream);
      finally
        TmpPNG.Free;
      end;
    finally
      TmpBlack.Free;
    end;
  finally
    TmpWhite.Free;
  end;
end;

{$ENDIF}
{$ENDIF}

procedure SaveToFileVia(const AFileName: String;
  const ASave: TProc<TStream>);
var
  TmpStream: TFileStream;
begin
  TmpStream := TFileStream.Create(AFileName, fmCreate);
  try
    ASave(TmpStream);
  finally
    TmpStream.Free;
  end;
end;

procedure CADSaveSheetToPNGStream(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet; const AStream: TStream; const ADPI: Integer;
  const ATransparent: Boolean);
{$IFNDEF CADSYS_LCL}
var
  TmpSize: TPoint;
  TmpDevice: TCADPageDevice;
{$ENDIF}
begin
{$IFDEF CADSYS_LCL}
  Raise ECADPageError.Create('Image export is not available on the LCL yet');
{$ELSE}
  if (ACAD = nil) or (ASheet = nil) or (AStream = nil) then
    Exit;
  TmpSize := CADSheetImageSize(ASheet, ADPI);
  CheckSize(TmpSize);
  TmpDevice := TCADPageDevice.FromDPI(ADPI, ADPI);
  SavePNG(TmpSize, TmpDevice.PixelsPerMM, ATransparent,
    procedure(const ACanvas: TDecorativeCanvas)
    begin
      CADDrawSheet(ACAD, ASheet, TmpDevice, ACanvas);
    end, AStream);
{$ENDIF}
end;

procedure CADSaveSheetToImage(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet; const AFileName: String; const ADPI: Integer;
  const ATransparent: Boolean);
begin
  if (ACAD = nil) or (ASheet = nil) or (AFileName = '') then
    Exit;
  { The size is checked before the file is created, so a refusal does
    not leave an empty file behind. }
  CheckSize(CADSheetImageSize(ASheet, ADPI));
  SaveToFileVia(AFileName,
    procedure(AStream: TStream)
    begin
      CADSaveSheetToPNGStream(ACAD, ASheet, AStream, ADPI, ATransparent);
    end);
end;

procedure CADSaveModelRectToPNGStream(const ACAD: TFNCCADCmp2D;
  const ARect: TRect2D; const AUnitsPerMM: TRealType;
  const AStream: TStream; const ADPI: Integer;
  const ATransparent: Boolean);
{$IFNDEF CADSYS_LCL}
var
  TmpSize: TPoint;
  TmpWindow: TRect2D;
  TmpDevice: TCADPageDevice;
{$ENDIF}
begin
{$IFDEF CADSYS_LCL}
  Raise ECADPageError.Create('Image export is not available on the LCL yet');
{$ELSE}
  if (ACAD = nil) or (AStream = nil) then
    Exit;
  TmpSize := CADModelRectImageSize(ARect, AUnitsPerMM, ADPI);
  CheckSize(TmpSize);
  TmpWindow := ReorderRect2D(ARect);
  TmpDevice := TCADPageDevice.FromDPI(ADPI, ADPI);
  SavePNG(TmpSize, TmpDevice.PixelsPerMM, ATransparent,
    procedure(const ACanvas: TDecorativeCanvas)
    var
      TmpWin: TRect2D;
      TmpTransf: TTransf2D;
      TmpClip: TRect2D;
      TmpIter: TGraphicObjIterator;
      TmpObj: TObject2D;
    begin
      { The window onto the image, as a sheet viewport puts the model
        on paper - the same transform, the same visibility test, the
        same per-layer setup. GetVisualTransform2D may adjust the
        window it is given, so it gets a copy. }
      TmpWin := TmpWindow;
      TmpTransf := GetVisualTransform2D(TmpWin, Rect(0, 0, TmpSize.X,
        TmpSize.Y), 0);
      TmpClip := RectToRect2D(Rect(0, 0, TmpSize.X, TmpSize.Y));
      TmpIter := ACAD.ObjectsIterator;
      try
        TmpObj := TObject2D(TmpIter.First);
        while TmpObj <> nil do
        begin
          if TmpObj.IsVisible(TmpWindow, 0) and
            ACAD.Layers.SetCanvas(ACanvas, TmpObj.Layer) then
            TmpObj.Draw(TmpTransf, ACanvas, TmpClip, 0);
          TmpObj := TObject2D(TmpIter.Next);
        end;
      finally
        TmpIter.Free;
      end;
    end, AStream);
{$ENDIF}
end;

procedure CADSaveModelRectToImage(const ACAD: TFNCCADCmp2D;
  const ARect: TRect2D; const AUnitsPerMM: TRealType;
  const AFileName: String; const ADPI: Integer;
  const ATransparent: Boolean);
begin
  if (ACAD = nil) or (AFileName = '') then
    Exit;
  CheckSize(CADModelRectImageSize(ARect, AUnitsPerMM, ADPI));
  SaveToFileVia(AFileName,
    procedure(AStream: TStream)
    begin
      CADSaveModelRectToPNGStream(ACAD, ARect, AUnitsPerMM, AStream, ADPI,
        ATransparent);
    end);
end;

end.
