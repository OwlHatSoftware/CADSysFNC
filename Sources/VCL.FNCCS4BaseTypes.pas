{: This help file explain all the base types defined in
   the CADSys 4.0 library for both the 2D and 3D use.

   These types are defined in the VCL.FNCCS4BaseTypes unit file
   that you must include in the <B=uses> clause in all of your units
   that use CADSys.
}
unit VCL.FNCCS4BaseTypes;

{$I VCL.FNCCADSys.inc}

interface

uses
{$IFDEF CADSYS_LCL}
  Classes, Types,
{$ELSE}
  System.Classes, System.Types,
{$ENDIF}
{$IFDEF CADSYS_VCL}
  { TCanvas, and nothing else. It is here only for the GDI-backend
    constructor of TDecorativeCanvas; on FMX and LCL this unit mentions
    no framework type at all, which is the point of the whole seam. }
  Vcl.Graphics,
{$ENDIF}
  VCL.FNCCS4Graphics;

type
  { : Signature of <See Var=CADSysOnWarning>. }
  TCADWarningEvent = procedure(const AMessage: String);

  { : Reports how far a long operation has got, so the application can
    show it however it likes.

    <I=APosition> counts units of work done. <I=AMax> is the total when it
    is known and <B=0> when it is not - a DXF is read as a text file, whose
    length in groups cannot be known before the end.
  }
  TCADProgressEvent = procedure(Sender: TObject;
    const APosition, AMax: Int64) of object;

type
{: To let the library to use any floating point precision value
   in defining the coordinates of points and so on, all
   floating point number used by the library is of this type.

   At the moment the precision is set to Single but you don't
   rely on this assumption when you create new kind of shapes
   classes or use the library.

   <B=Note>: I don't think that this type will change due to storage
   and speed efficency.
}
  TRealType = Double; //maurog.
{: This type is the result information of a clipping method. The
   clipping functions are used internally by the library and you
   don't need to use them directly.

   The tags have the following meanings:

   <LI=<I=ccFirst> the clipping function has modified the first point of the segment>
   <LI=<I=ccSecond> the clipping function has modified the second point of the segment>
   <LI=<I=ccNotVisible> the segment to be clipped is not visible>
   <LI=<I=ccVisible> the segment to be clipped is fully visible>
}
  TClipCode = (ccFirst, ccSecond, ccNotVisible, ccVisible);
{: This type is a set of <See Type=TClipCode> tags. A clipping function may
   return such a set.
}
  TClipResult = set of TClipCode;
{: This type define the point position against view frustum.
}
  TOutPos = (left, bottom, right, top, neareye, fareye);
{: This type define the point position against view frustum.
}
  TOutCode = set of TOutPos;

{: This type defines a 2D point in homogeneous coordinates.

   All point informations in the library are in homogeneous
   coordinates that is they have a third coordinate W. This
   coordinate may be treated as divisor coefficient for the X and Y
   coordinates.

   A 2D point in the euclidean space (the normally used point) can
   be obtained by dividing each X and Y coordinates by W:

   <Code=
     Xe := X / W;<BR>
     Ye := Y / W;<BR>.
   >

   A point to be valid must have at least one of its coordinates
   not zero. If a point has W = 0 it is called a point at infinitum
   and it is not allowed in the library. Normally this kind of
   points is used to rapresent a direction but in the library
   the <See Type=TVector2D> type is used instead.
}
  TPoint2D = record
   X, Y, W: TRealType;
  end;

{: This type defines a 2D vector or direction.

   Use this type when you need to defines directions in the
   2D space. In the case of 2D application this type may be
   used in defining parametric segments or to specify
   ortogonal segments.
}
  TVector2D = record
   X, Y: TRealType;
  end;

{: This type defines a 2D axis aligned rectangle.

   The rectangle is specified by two of its corners, the
   lower-left ones and the upper-right ones. Consider that
   the origin of the coordinates of the library is different
   from the Windows' one. Use <See Function=Rect2DToRect> and
   <See Function=RectToRect2D> functions to convert from the
   two coordinate systems.

   This type is useful to defines bounding boxes of shapes.
}
  TRect2D = record
   case Byte of
    0: (Left, Bottom, W1, Right, Top, W2: TRealType);
    1: (FirstEdge, SecondEdge: TPoint2D);
  end;

{: This type defines a 2D transformation for homogeneous points
   and vectors.

   The convention used by the library is that a matrix premultiply
   a point, that is:

   <Code=TP = M * T>

   where <I=TP> and <I=T> are points and <I=M> is a matrix.

   The matrix is specified by columns, that is <I=M[2, 1]> is
   the element at row 2 and column 1 and <I=M[1, 2]> is the
   element at row 1 anc column 2.
}
  TTransf2D = array[1..3, 1..3] of TRealType;

{: This type defines the new way of considering a normal vector to a
   plane. In <I=hrRightHand mode> the normal vector is computed by using
   the right hand rule, in the <I=hrLeftHand mode> the normal vector is
   computed by using the left hand rule.
}
  THandleRule = (hrRightHand, hrLeftHand);
{: This type defines a 3D point in homogeneous coordinates.

   All point informations in the library are in homogeneous
   coordinates that is they have a third coordinate W. This
   coordinate may be treated as divisor coefficient for the X, Y and Z
   coordinates.

   A 3D point in the euclidean space (the normally used point) can
   be obtained by dividing each X, Y and Z coordinates by W:

   <Code=
     Xe := X / W;
     Ye := Y / W;
     Ze := Z / W;
   >

   A point to be valid must have at least one of its coordinates
   not zero. If a point has W = 0 it is called a point at infinitum
   and it is not allowed in the library. Normally this kind of
   points is used to rapresent a direction but in the library
   the <See Type=TVector3D> type is used instead.

   Use <See Function=Point3DToPoint2D> and
   <See Function=Point2DToPoint3D> functions to convert from 2D
   points to 3D points.
}
  TPoint3D = record
    X, Y, Z, W: TRealType;
  end;
{: This type defines a 3D vector or direction.

   Use this type when you need to defines directions in the
   3D space. In the case of 3D application this type may be
   used in defining parametric segments or to specify
   normal surface vectors.
}
  TVector3D = record
    X, Y, Z: TRealType;
  end;
{: This type defines a 3D axis aligned rectangle.

   The rectangle is specified by two of its corners, the
   lower-left-front ones and the upper-right-back ones.
   Use <See Function=Rect3DToRect2D> and
   <See Function=Rect2DToRect3D> functions to convert from 2D
   boxes to 3D boxes.

   This type is useful to defines bounding boxes of shapes.
}
  TRect3D = record
   case Byte of
    0: (Left, Bottom, Front, W1, Right, Top, Back, W2: TRealType);
    1: (FirstEdge, SecondEdge: TPoint3D);
  end;
{: This type defines a 3D transformation for homogeneous points
   and vectors.

   The convention used by the library is that a matrix premultiply
   a point, that is:

   <Code=TP = M * T>

   where <I=TP> and <I=T> are points and <I=M> is a matrix.

   The matrix is specified by columns, that is <I=M[2, 1]> is
   the element at row 2 and column 1 and <I=M[1, 2]> is the
   element at row 1 anc column 2.
}
  TTransf3D = array[1..4, 1..4] of TRealType;

  {: Vector of 2D points. }
  TVectPoints2D = array [0..0] of TPoint2D;
  {: Pointer to vector of 2D points. }
  PVectPoints2D = ^TVectPoints2D;

  {: Vector of 3D points. }
  TVectPoints3D = array [0..0] of TPoint3D;
  {: Pointer to vector of 3D points. }
  PVectPoints3D = ^TVectPoints3D;

{: This class defines a decorative pen, that is a special Window pen that
   can have any pattern. The pattern is defined by a string of bits like
   '1110001100', in which a one rapresent a colored pixel and a zero
   rapresent a transparent pixel. By using this pen the redrawing of the
   image will be slower, so use it only where necessary. Because a decorative
   pen is associated to a layer you can manage it better.

   <B=Note>: The decorative pen use LineDDA functions to draw the lines and
   can only be used for lines and polylines (so no ellipses are drawed using
   the pattern).
}
  TDecorativePen = class(TObject)
  private
    fPStyle: TBits;
    fCnv: TCADGraphics;
    fCurBit: Word;
    fStartPt, fEndPt, fLastPt: TPoint;

    procedure SetBit(const Idx: Word; const B: Boolean);
    function GetBit(const Idx: Word): Boolean;
    function GetMaxBit: Word;
    procedure CallLineDDA;
  public
    constructor Create;
    destructor Destroy; override;
    {: This method is used to make deep copy of the object by obtaining state
       informations from another.

       <I=Obj> is the object from which copy the needed informations.
    }
    procedure Assign(Source: TObject);
    {: Move the pen for the canvas <I=Cnv> to the position <I=X,Y>.
    }
    procedure MoveTo(Cnv: TCADGraphics; X, Y: Integer);
    {: Move the pen for the canvas <I=Cnv> to the position <I=X,Y>.
       This will not reset the current pattern bit. It is useful
       when you are drawing a shapes made by segment.
    }
    procedure MoveToNotReset(Cnv: TCADGraphics; X, Y: Integer);
    {: Draw a line using the current pattern and color to the position <I=X,Y>.
    }
    procedure LineTo(Cnv: TCADGraphics; X, Y: Integer);
    {: Draw a polyline using the current pattern and color.
       <I=Pts> are the points of the polyline and <I=NPts> is the number of points.
    }
    procedure Polyline(Cnv: TCADGraphics; Pts: Pointer; NPts: Integer);
    {: Specify the pattern for lines.
       The pattern is defined by a string of bits like
       '1110001100', in which a one rapresent a colored pixel and a zero
       rapresent a transparent pixel. By using this pen the redrawing of the
       image will be slower, so use it only where necessary. Because a decorative
       pen is associated to a layer you can manage it better.
    }
    procedure SetPenStyle(const SString: String);
    {: Contains the patter for lines.
       The pattern is defined by a string of bits like
       '1110001100', in which a one rapresent a colored pixel and a zero
       rapresent a transparent pixel. By using this pen the redrawing of the
       image will be slower, so use it only where necessary. Because a decorative
       pen is associated to a layer you can manage it better.
    }
    property PenStyle[const Idx: Word]: Boolean read GetBit write SetBit;
    {: Contains the pattern length.
    }
    property PatternLenght: Word read GetMaxBit;
  end;

{: Defines an object that contains a DecorativePen and a Canvas.
   By using the decorative pen methods you can draw patterned lines,
   and by using the Canvas property you can draw using the
   canvas.

   See also <See Class=TDecorativePen> for details.
}
  TDecorativeCanvas = class(TObject)
  private
    fDecorativePen: TDecorativePen;
    fGraphics: TCADGraphics;
    fOwnsGraphics: Boolean;
    fRubber: Boolean;
{$IFDEF CADSYS_VCL}
    function GetCanvas: TCanvas;
{$ENDIF}
    function GetPen: TCADPen;
    function GetBrush: TCADBrush;
    function GetClipRect: TRect;
  public
{$IFDEF CADSYS_VCL}
    {: Wraps a VCL canvas (GDI backend). The canvas is not owned.

       VCL only: the GDI backend is the one place in the library that
       talks to a framework canvas directly, and there is no FMX or LCL
       equivalent. On those targets everything draws through FNC, so use
       the TCADGraphics overload. }
    constructor Create(ACanvas: TCanvas); overload;
{$ENDIF}
    {: Wraps any drawing backend. If AOwnsGraphics is True the backend is
       freed with this object. }
    constructor Create(AGraphics: TCADGraphics; AOwnsGraphics: Boolean); overload;
    destructor Destroy; override;

    {: This method is a shortcut to the MoveTo method of the
       owned decorative pen. I suggest to use it in all of your
       shapes to draw lines.
    }
    procedure MoveTo(X, Y: Integer);
    {: This method is a shortcut to the LineTo method of the
       owned decorative pen. I suggest to use it in all of your
       shapes to draw lines.
    }
    procedure LineTo(X, Y: Integer);
    {: This method is a shortcut to the Polyline method of the
       owned decorative pen. I suggest to use it in all of your
       shapes to draw polylines.
    }
    procedure Polyline(Points: Pointer; NPts: Integer);
    {: Draws a closed polygon, filled with the brush. <I=Points> points to
       <I=NPts> TPoint values. }
    procedure Polygon(Points: Pointer; NPts: Integer);
    {: Contains the decorative pen.
    }
    property DecorativePen: TDecorativePen read fDecorativePen;
    {: The drawing backend. Use it (or the Pen, Brush and ClipRect
       shortcuts) for everything that is not a patterned line. }
    property Graphics: TCADGraphics read fGraphics;
    property Pen: TCADPen read GetPen;
    property Brush: TCADBrush read GetBrush;
    property ClipRect: TRect read GetClipRect;
    {: True while this canvas is being used for transient rubber-band
       drawing - a shape being dragged, a selection frame, the cursor
       cross. A shape may then draw a cheap outline instead of its
       full appearance.

       This replaces the old <I=Pen.Mode = pmXOr> test. The library no
       longer rubber-bands by XOR-ing: the viewport restores the area
       from its back buffer and draws the overlay again, which is what
       every backend can do. }
    property Rubber: Boolean read fRubber write fRubber;
{$IFDEF CADSYS_VCL}
    {: The underlying VCL canvas, or nil when the backend is not VCL.
       Transitional: new code should not use it, and nothing in the
       library does - which is why it can be VCL-only. }
    property Canvas: TCanvas read GetCanvas;
{$ENDIF}
  end;

  // For stream operation backward compatibility
  TRealTypeSingle = Single;
  TTransf2DSingle = array[1..3, 1..3] of TRealTypeSingle;
  TTransf3DSingle = array[1..4, 1..4] of TRealTypeSingle;
  TPoint2DSingle = record
    X, Y, W: TRealTypeSingle;
  end;
  TPoint3DSingle = record
    X, Y, Z, W: TRealTypeSingle;
  end;
  TVector3DSingle = record
    X, Y, Z: TRealTypeSingle;
  end;

const
  TWOPI = 2 * Pi;
  SQRT2 = 1.414213562373;

  {: Constant used with the picking functions.

     See also <See Method=TFNCCADViewport2D@PickObject> and
     <See Method=TFNCCADViewport3D@PickObject>.
  }
  PICK_NOOBJECT = -200;
  {: Constant used with the picking functions.

     See also <See Method=TFNCCADViewport2D@PickObject> and
     <See Method=TFNCCADViewport3D@PickObject>.
  }
  PICK_INBBOX = -100;
  {: Constant used with the picking functions.

     See also <See Method=TFNCCADViewport2D@PickObject> and
     <See Method=TFNCCADViewport3D@PickObject>.
  }
  PICK_ONOBJECT = -1;
  {: Constant used with the picking functions.

     See also <See Method=TFNCCADViewport2D@PickObject> and
     <See Method=TFNCCADViewport3D@PickObject>.
  }
  PICK_INOBJECT = -2;
  {: This is the identity matrix for 2D transformation.
  }
  IdentityTransf2D: TTransf2D = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0));
  {: This is the null matrix for 2D transformation.
  }
  NullTransf2D: TTransf2D = ((0.0, 0.0, 0.0), (0.0, 0.0, 0.0), (0.0, 0.0, 1.0));
  {: This is the identity matrix for 3D transformation.
  }
  IdentityTransf3D: TTransf3D = ((1.0, 0.0, 0.0, 0.0), (0.0, 1.0, 0.0, 0.0), (0.0, 0.0, 1.0, 0.0), (0.0, 0.0, 0.0, 1.0));
  {: This is the null matrix for 3D transformation.
  }
  NullTransf3D: TTransf3D = ((0.0, 0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0));
  {: This is the minimum value for coordinates.
  }
  MinCoord = -1.0E8;
  {: This is the maximun value for coordinates.
  }
  MaxCoord = 1.0E8;

var
  { : Hook for <See Function=CADSysWarn>. Point it at whatever the
    application uses to tell the user something - a status bar, a log,
    ShowMessage. Nil, the default, swallows the warning.
  }
  CADSysOnWarning: TCADWarningEvent = nil;

{ : Reports something the library noticed but could recover from: a
  drawing that refers to a vector font nobody registered, a DXF entity it
  cannot represent, a source block that is missing.

  It calls <See Var=CADSysOnWarning> when the application has set one, and
  does nothing otherwise. The library must not open a dialog of its own -
  it has to build on VCL, FMX and LCL alike.
}
procedure CADSysWarn(const AMessage: String);

implementation

{$IFDEF CADSYS_VCL}
uses VCL.FNCCS4GraphicsVCL;
{$ENDIF}

procedure CADSysWarn(const AMessage: String);
begin
  if Assigned(CADSysOnWarning) then
    CADSysOnWarning(AMessage);
end;

{ TDecorativeCanvas }

{$IFDEF CADSYS_VCL}
constructor TDecorativeCanvas.Create(ACanvas: TCanvas);
begin
  Create(TCADVCLGraphics.Create(ACanvas), True);
end;
{$ENDIF}

constructor TDecorativeCanvas.Create(AGraphics: TCADGraphics;
  AOwnsGraphics: Boolean);
begin
  inherited Create;
  fGraphics := AGraphics;
  fOwnsGraphics := AOwnsGraphics;
  fDecorativePen := TDecorativePen.Create;
end;

destructor TDecorativeCanvas.Destroy;
begin
  fDecorativePen.Free;
  if fOwnsGraphics then
    fGraphics.Free;
  inherited Destroy;
end;

{$IFDEF CADSYS_VCL}
function TDecorativeCanvas.GetCanvas: TCanvas;
begin
  Result := VCLCanvasOf(fGraphics);
end;
{$ENDIF}

function TDecorativeCanvas.GetPen: TCADPen;
begin
  Result := fGraphics.Pen;
end;

function TDecorativeCanvas.GetBrush: TCADBrush;
begin
  Result := fGraphics.Brush;
end;

function TDecorativeCanvas.GetClipRect: TRect;
begin
  Result := fGraphics.ClipRect;
end;

procedure TDecorativeCanvas.MoveTo(X, Y: Integer);
begin
  fDecorativePen.MoveTo(fGraphics, X, Y);
end;

procedure TDecorativeCanvas.LineTo(X, Y: Integer);
begin
  fDecorativePen.LineTo(fGraphics, X, Y);
end;

procedure TDecorativeCanvas.Polyline(Points: Pointer; NPts: Integer);
begin
  fDecorativePen.Polyline(fGraphics, Points, NPts);
end;

procedure TDecorativeCanvas.Polygon(Points: Pointer; NPts: Integer);
begin
  fGraphics.Polygon(Points, NPts);
end;

{ TDecorativePen }

procedure LineDDAMethod1(X, Y: Integer; lpData: Pointer); stdcall;
var
  NextBit: Integer;
begin
  with TDecorativePen(lpData) do
   begin
     NextBit := (fCurBit + Abs(X - fLastPt.X)) mod GetMaxBit;
     fLastPt := System.Types.Point(X, Y);
     if (fCurBit < GetMaxBit) and
        (fPStyle[fCurBit] and
        not fPStyle[NextBit]) then
      fCnv.Polyline([System.Types.Point(fStartPt.X, fStartPt.Y), System.Types.Point(X, Y)])
     else if not fPStyle[fCurBit] then
      fStartPt := System.Types.Point(X, Y);
     if (X = fEndPt.X - 1) or (X = fEndPt.X + 1) then
      fCnv.Polyline([System.Types.Point(fStartPt.X, fStartPt.Y), System.Types.Point(X, Y)]);
     fCurBit := NextBit;
   end;
end;

procedure LineDDAMethod2(X, Y: Integer; lpData: Pointer); stdcall;
var
  NextBit: Integer;
begin
  with TDecorativePen(lpData) do
   begin
     NextBit := (fCurBit + Abs(Y - fLastPt.Y)) mod GetMaxBit;
     fLastPt := System.Types.Point(X, Y);
     if (fCurBit < GetMaxBit) and
        (fPStyle[fCurBit] and not fPStyle[NextBit]) then
      fCnv.Polyline([System.Types.Point(fStartPt.X, fStartPt.Y), System.Types.Point(X, Y)])
     else if not fPStyle[fCurBit] then
      fStartPt := System.Types.Point(X, Y);
     if (Y = fEndPt.Y - 1) or (Y = fEndPt.Y + 1) then
      fCnv.Polyline([System.Types.Point(fStartPt.X, fStartPt.Y), System.Types.Point(X, Y)]);
     fCurBit := NextBit;
   end
end;

procedure TDecorativePen.SetBit(const Idx: Word; const B: Boolean);
begin
  fPStyle[Idx] := B;
end;

function TDecorativePen.GetBit(const Idx: Word): Boolean;
begin
  Result := fPStyle[Idx];
end;

function TDecorativePen.GetMaxBit: Word;
begin
  Result := fPStyle.Size;
end;

procedure TDecorativePen.CallLineDDA;
begin
  //if (Abs(fEndPt.X - fStartPt.X) > Abs(fEndPt.Y - fStartPt.Y)) then
  // LineDDA(fStartPt.X, fStartPt.Y, fEndPt.X, fEndPt.Y, @LineDDAMethod1, Integer(Self))
  //else
  // LineDDA(fStartPt.X, fStartPt.Y, fEndPt.X, fEndPt.Y, @LineDDAMethod2, Integer(Self));
  fCnv.MoveTo(fStartPt.X, fStartPt.Y);
  fCnv.LineTo(fEndPt.X, fEndPt.Y);
end;

constructor TDecorativePen.Create;
begin
  inherited;

  fPStyle := TBits.Create;
end;

destructor TDecorativePen.Destroy;
begin
  fPStyle.Free;
  inherited;
end;

procedure TDecorativePen.Assign(Source: TObject);
var
  Cont: Integer;
begin
  if (Source = Self) then
   Exit;
  if Source is TDecorativePen then
   begin
     fPStyle.Size := 0;
     for Cont := 0 to TDecorativePen(Source).fPStyle.Size - 1 do
      fPStyle[Cont] := TDecorativePen(Source).fPStyle[Cont];
   end;
end;

procedure TDecorativePen.MoveTo(Cnv: TCADGraphics; X, Y: Integer);
begin
  if( fPStyle.Size > 0 ) then
   begin
     fStartPt := System.Types.Point(X, Y);
     fEndPt := System.Types.Point(X, Y);
     fLastPt := fStartPt;
     fCurBit := 0;
   end
  else
   Cnv.MoveTo(X, Y);
end;

procedure TDecorativePen.MoveToNotReset(Cnv: TCADGraphics; X, Y: Integer);
begin
  if( fPStyle.Size > 0 ) then
   begin
     fStartPt := System.Types.Point(X, Y);
     fEndPt := System.Types.Point(X, Y);
     fLastPt := fStartPt;
   end
  else
   Cnv.MoveTo(X, Y);
end;

procedure TDecorativePen.LineTo(Cnv: TCADGraphics; X, Y: Integer);
begin
  if( fPStyle.Size > 0 ) then
   begin
     fEndPt := System.Types.Point(X, Y);
     fCnv := Cnv;
     CallLineDDA;
     fStartPt := System.Types.Point(X, Y);
     fLastPt := fStartPt;
   end
  else
   Cnv.LineTo(X, Y);
end;

procedure TDecorativePen.Polyline(Cnv: TCADGraphics; Pts: Pointer; NPts: Integer);
begin
  if NPts <= 1 then
   Exit;
  { CS4-FIX (S5): the patterned branch looped MoveTo/LineTo per segment through
    CallLineDDA - whose LineDDA calls are themselves commented out - so it drew
    exactly the same solid pixels as a single WinAPI.Windows.Polyline, at N
    times the GDI cost, for a decorative pattern that no longer works.
    LineDDAMethod1/2 stay unreachable; restoring them needs the Integer(Self)
    cast replaced with an LPARAM/NativeInt one for 64-bit first. }
  Cnv.Polyline(Pts, NPts);
end;

procedure TDecorativePen.SetPenStyle(const SString: String);
var
  Cont: Integer;
begin
  fPStyle.Size := Length(SString);
  for Cont := 1 to fPStyle.Size do
   if SString[Cont] = '1' then
    SetBit(Cont - 1, True)
   else
    SetBit(Cont - 1, False);
end;

end.

