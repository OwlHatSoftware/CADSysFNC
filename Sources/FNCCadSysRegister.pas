unit FNCCadSysRegister;

{$I CADSys.inc}

interface

uses
  Classes, FNCCS4Shapes, FNCCADSys4, FNCCS4BaseTypes, FNCCS4DXFModule;

procedure register;

var
  _NullChar: TVectChar;
  _DefaultFont: TVectFont;
  _DefaultHandler2D: TPrimitive2DHandler;
  _DefaultHandler3D: TPrimitive3DHandler;

implementation

procedure register;
begin
  RegisterComponents('FNCCadSys', [TFNCCADPrg2D]);
  RegisterComponents('FNCCadSys', [TFNCCADCmp2D]);
  RegisterComponents('FNCCadSys', [TFNCCADViewport2D]);
end;

initialization

// Spostata inizializzazione da FNCCADSys4 a FNCCS4Shapes perchè pare che venga fatta prima questa inizializzazione e poi quella di FNCCADSys4
CADSysInitClassRegister;

CADSysRegisterClass(0, TContainer2D);
CADSysRegisterClass(1, TSourceBlock2D);
CADSysRegisterClass(2, TBlock2D);
CADSysRegisterClass(3, TLine2D);
CADSysRegisterClass(4, TPolyline2D);
CADSysRegisterClass(5, TPolygon2D);
CADSysRegisterClass(6, TRectangle2D);
CADSysRegisterClass(7, TArc2D);
CADSysRegisterClass(8, TEllipse2D);
CADSysRegisterClass(9, TFilledEllipse2D);
CADSysRegisterClass(10, TText2D);
CADSysRegisterClass(11, TFrame2D);
CADSysRegisterClass(12, TBitmap2D);
CADSysRegisterClass(13, TBSpline2D);
CADSysRegisterClass(14, TJustifiedVectText2D);

_DefaultHandler2D := TPrimitive2DHandler.Create(nil);
CADSysRegisterClass(50, TContainer3D);
CADSysRegisterClass(51, TSourceBlock3D);
CADSysRegisterClass(52, TBlock3D);
CADSysRegisterClass(53, TLine3D);
CADSysRegisterClass(54, TPolyline3D);
CADSysRegisterClass(55, TFace3D);
CADSysRegisterClass(56, TArc3D);
CADSysRegisterClass(57, TEllipse3D);
CADSysRegisterClass(58, TPlanar2DObject3D);
CADSysRegisterClass(60, TPlanarPolyline3D);
CADSysRegisterClass(61, TFrame3D);
CADSysRegisterClass(62, TPlanarSpline3D);
CADSysRegisterClass(63, TPlanarFace3D);
CADSysRegisterClass(64, TExtrudedOutline3D);
CADSysRegisterClass(65, TRotationalOutline3D);
CADSysRegisterClass(66, TMesh3D);
CADSysRegisterClass(67, TCameraObject3D);
CADSysRegisterClass(68, TPolyface3D);
CADSysRegisterClass(69, TJustifiedVectText3D);
CADSysRegisterClass(70, TPlanarFieldGrid3D);

_DefaultHandler3D := TPrimitive3DHandler.Create(nil);
// Vectorial fonts
CADSysInitFontList;

_NullChar := TVectChar.Create(1);
_NullChar.Vectors[0].Add(Point2D(0.0, 0.0));
_NullChar.Vectors[0].Add(Point2D(0.8, 0.0));
_NullChar.UpdateExtension(nil);
_DefaultFont := nil;

finalization

CADSysClearFontList;
_NullChar.Free;
{ CS4-FIX (M11): these are shared handlers held by reference count; use
  Release so a shape still holding one is not left with a dead pointer. }
if Assigned(_DefaultHandler2D) then
  _DefaultHandler2D.Release;
if Assigned(_DefaultHandler3D) then
  _DefaultHandler3D.Release;
end.
