{ : Paper, and what a device makes of it.

  The smallest unit in the library: paper sizes, margins, and the
  pixels-per-millimetre of whatever is being drawn on. It knows nothing
  about drawings, printers, frameworks or JSON, and it uses nothing but
  the base types.

  WHY IT IS ITS OWN UNIT

  It was part of VCL.FNCCS4Print until sheets arrived. A sheet is paper
  with viewports on it, a sheet belongs to the drawing, and the drawing
  lives in VCL.FNCCADSys4 - which VCL.FNCCS4Print uses and therefore
  cannot use back. Two tables of paper sizes was never an option: the
  one that was wrong would be the one nobody printed from. So the paper
  moved down, below both of them.

  VCL.FNCCS4Print repeats the type names and the paper kinds as
  aliases, so a unit that prints still needs only that one in its uses
  clause.
}
unit VCL.FNCCS4Paper;

{$I VCL.FNCCADSys.inc}

interface

uses
{$IFDEF CADSYS_LCL}
  SysUtils, Types, Math,
{$ELSE}
  System.SysUtils, System.Types, System.Math,
{$ENDIF}
  VCL.FNCCS4BaseTypes;

const
  { : Millimetres in an inch. Printers talk in dots per inch; everything
    here talks in millimetres. }
  CADMMPerInch = 25.4;

type
  { : Raised when a page setup cannot produce a page - a paper size of
    zero, a scale of zero, an empty drawing window. }
  ECADPageError = class(Exception);

  { : The standard paper sizes, portrait. pkCustom takes its size from
    whatever holds it - a page setup's CustomWidthMM and
    CustomHeightMM, or a sheet's. }
  TCADPaperKind = (pkA5, pkA4, pkA3, pkA2, pkA1, pkA0, pkLetter, pkLegal,
    pkTabloid, pkCustom);

  { : Portrait or landscape.

    Spelled pgo rather than po because Vcl.Printers and FMX.Printer both
    declare a TPrinterOrientation with poPortrait and poLandscape in it,
    and any unit that prints has both in scope. Two enumerations with
    the same member names in one uses clause is an afternoon lost to a
    message that points at the wrong line. }
  TCADPageOrientation = (pgoPortrait, pgoLandscape);

  { : The unprinted border, in millimetres. }
  TCADPageMargins = record
    Left, Top, Right, Bottom: TRealType;
    { : The same margin on all four sides. }
    class function Uniform(const AMM: TRealType): TCADPageMargins; static;
    class function Sides(const ALeft, ATop, ARight, ABottom: TRealType)
      : TCADPageMargins; static;
    function Horizontal: TRealType;
    function Vertical: TRealType;
  end;

  { : What the surface being drawn on can do, in device pixels.

    X and Y are separate because a printer's are not always equal, and
    because keeping them separate costs nothing and getting it wrong
    costs a squashed drawing.

    OffsetXPx and OffsetYPx are where the paper's top-left corner sits
    in the canvas' coordinates. A printer canvas normally begins at the
    printable area rather than at the sheet, so for a printer they are
    negative - the sheet starts above and to the left of pixel zero. A
    preview that draws the whole sheet leaves them at zero. }
  TCADPageDevice = record
    PixelsPerMMX, PixelsPerMMY: TRealType;
    OffsetXPx, OffsetYPx: Integer;

    { : From a device's resolution in dots per inch. }
    class function FromDPI(const ADPIX, ADPIY: TRealType)
      : TCADPageDevice; static;
    { : From pixels per millimetre, the same both ways. }
    class function FromPixelsPerMM(const APixelsPerMM: TRealType)
      : TCADPageDevice; static;
    { : A device that renders APaperWidthMM x APaperHeightMM into a box
      AWidthPx x AHeightPx - what a preview control wants. The aspect is
      preserved and the result is centred, so a preview of a portrait
      sheet in a wide box has the sheet in the middle. }
    class function ToBox(const APaperWidthMM, APaperHeightMM: TRealType;
      const AWidthPx, AHeightPx: Integer): TCADPageDevice; static;

    function MMToPxX(const AMM: TRealType): Integer;
    function MMToPxY(const AMM: TRealType): Integer;
    { : The mean of the two axes - for anything with one figure to give,
      such as a line weight. }
    function PixelsPerMM: TRealType;
    { : The whole sheet as a device rectangle. }
    function PaperRect(const AWidthMM, AHeightMM: TRealType): TRect;
  end;

const
  { : Written as names rather than as ordinals, like every other
    enumeration in this library's files. An ordinal is one insertion
    away from meaning something else. }
  CADPageOrientationNames: array [0 .. 1] of String =
    ('portrait', 'landscape');

  { : Written as names, for the same reason. pkCustom is in the list:
    a sheet or a setup that carries its own size still says so. }
  CADPaperKindNames: array [0 .. 9] of String = ('A5', 'A4', 'A3', 'A2',
    'A1', 'A0', 'Letter', 'Legal', 'Tabloid', 'Custom');

{ : The sheet in millimetres, portrait, for a standard size. pkCustom
  gives back zeroes - whoever holds the custom size fills them in. }
procedure CADPaperSizeMM(const AKind: TCADPaperKind;
  out AWidth, AHeight: TRealType);
{ : 'A4', 'Letter', 'Custom' - for a combo box. }
function CADPaperKindName(const AKind: TCADPaperKind): String;
{ : The paper with that name, or ADefault when nothing matches. Case
  does not matter. }
function CADPaperKindFromName(const AName: String;
  const ADefault: TCADPaperKind = pkA4): TCADPaperKind;

{ : APaper with AOrientation applied, taking a custom size from
  ACustomWidthMM and ACustomHeightMM. The one place in the library that
  turns a paper kind into two numbers. }
procedure CADSheetSizeMM(const APaper: TCADPaperKind;
  const AOrientation: TCADPageOrientation;
  const ACustomWidthMM, ACustomHeightMM: TRealType;
  out AWidth, AHeight: TRealType);

implementation

const
  { : The A series, portrait, in millimetres. }
  PaperMM: array [pkA5 .. pkTabloid] of array [0 .. 1] of TRealType =
    ((148, 210), (210, 297), (297, 420), (420, 594), (594, 841), (841, 1189),
    (215.9, 279.4), (215.9, 355.6), (279.4, 431.8));

{ ==================================================================
  TCADPageMargins
  ================================================================== }

class function TCADPageMargins.Uniform(const AMM: TRealType): TCADPageMargins;
begin
  Result.Left := AMM;
  Result.Top := AMM;
  Result.Right := AMM;
  Result.Bottom := AMM;
end;

class function TCADPageMargins.Sides(const ALeft, ATop, ARight,
  ABottom: TRealType): TCADPageMargins;
begin
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Right := ARight;
  Result.Bottom := ABottom;
end;

function TCADPageMargins.Horizontal: TRealType;
begin
  Result := Left + Right;
end;

function TCADPageMargins.Vertical: TRealType;
begin
  Result := Top + Bottom;
end;

{ ==================================================================
  TCADPageDevice
  ================================================================== }

class function TCADPageDevice.FromDPI(const ADPIX, ADPIY: TRealType)
  : TCADPageDevice;
begin
  Result.PixelsPerMMX := ADPIX / CADMMPerInch;
  Result.PixelsPerMMY := ADPIY / CADMMPerInch;
  Result.OffsetXPx := 0;
  Result.OffsetYPx := 0;
end;

class function TCADPageDevice.FromPixelsPerMM(const APixelsPerMM: TRealType)
  : TCADPageDevice;
begin
  Result.PixelsPerMMX := APixelsPerMM;
  Result.PixelsPerMMY := APixelsPerMM;
  Result.OffsetXPx := 0;
  Result.OffsetYPx := 0;
end;

class function TCADPageDevice.ToBox(const APaperWidthMM,
  APaperHeightMM: TRealType; const AWidthPx, AHeightPx: Integer)
  : TCADPageDevice;
var
  TmpScale: TRealType;
begin
  { One scale for both axes: a preview of a sheet has to look like the
    sheet, and a box that is the wrong shape is the box's problem. }
  Result.PixelsPerMMX := 0;
  Result.PixelsPerMMY := 0;
  Result.OffsetXPx := 0;
  Result.OffsetYPx := 0;
  if (APaperWidthMM <= 0) or (APaperHeightMM <= 0) or (AWidthPx <= 0) or
    (AHeightPx <= 0) then
    Exit;
  TmpScale := MinValue([AWidthPx / APaperWidthMM, AHeightPx / APaperHeightMM]);
  Result.PixelsPerMMX := TmpScale;
  Result.PixelsPerMMY := TmpScale;
  Result.OffsetXPx := Round((AWidthPx - APaperWidthMM * TmpScale) / 2);
  Result.OffsetYPx := Round((AHeightPx - APaperHeightMM * TmpScale) / 2);
end;

function TCADPageDevice.MMToPxX(const AMM: TRealType): Integer;
begin
  Result := Round(AMM * PixelsPerMMX);
end;

function TCADPageDevice.MMToPxY(const AMM: TRealType): Integer;
begin
  Result := Round(AMM * PixelsPerMMY);
end;

function TCADPageDevice.PixelsPerMM: TRealType;
begin
  Result := (PixelsPerMMX + PixelsPerMMY) / 2;
end;

function TCADPageDevice.PaperRect(const AWidthMM, AHeightMM: TRealType): TRect;
begin
  Result.Left := OffsetXPx;
  Result.Top := OffsetYPx;
  Result.Right := OffsetXPx + MMToPxX(AWidthMM);
  Result.Bottom := OffsetYPx + MMToPxY(AHeightMM);
end;

{ ==================================================================
  Paper
  ================================================================== }

procedure CADPaperSizeMM(const AKind: TCADPaperKind;
  out AWidth, AHeight: TRealType);
begin
  if AKind = pkCustom then
  begin
    AWidth := 0;
    AHeight := 0;
    Exit;
  end;
  AWidth := PaperMM[AKind][0];
  AHeight := PaperMM[AKind][1];
end;

function CADPaperKindName(const AKind: TCADPaperKind): String;
begin
  Result := CADPaperKindNames[Ord(AKind)];
end;

function CADPaperKindFromName(const AName: String;
  const ADefault: TCADPaperKind): TCADPaperKind;
var
  I: Integer;
begin
  Result := ADefault;
  for I := 0 to High(CADPaperKindNames) do
    if SameText(AName, CADPaperKindNames[I]) then
    begin
      Result := TCADPaperKind(I);
      Exit;
    end;
end;

procedure CADSheetSizeMM(const APaper: TCADPaperKind;
  const AOrientation: TCADPageOrientation;
  const ACustomWidthMM, ACustomHeightMM: TRealType;
  out AWidth, AHeight: TRealType);
var
  TmpSwap: TRealType;
begin
  if APaper = pkCustom then
  begin
    AWidth := ACustomWidthMM;
    AHeight := ACustomHeightMM;
  end
  else
    CADPaperSizeMM(APaper, AWidth, AHeight);
  { The tables are portrait, so landscape is a swap and nothing else.
    Everything downstream - the transform, the tiling, the printer -
    then works in the size that is actually on the desk. }
  if AOrientation = pgoLandscape then
  begin
    TmpSwap := AWidth;
    AWidth := AHeight;
    AHeight := TmpSwap;
  end;
end;

end.
