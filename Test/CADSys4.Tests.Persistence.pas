{ : DUnitX tests for the JSON persistence of CADSys.

  Three layers are covered:

  1. VCL.FNCCS4JSON, the conversion helpers: value round trips and the lenient
     reading rules the format relies on.
  2. TGraphicObject.SaveToJSON / CreateFromJSON per shape family, through
     CADSysObjectToJSON / CADSysObjectFromJSON - the same path a document
     takes.
  3. TFNCCADCmp2D whole-document round trips: layers, source blocks, files,
     text, and the document header.

  VCL.FNCCadSysRegister is in the uses clause because its initialization section
  fills the class registry. Without it CADSysObjectFromJSON raises
  ECADObjClassNotFound for every shape.

  The DXF tests that used to live here are in CADSys4.Tests.DXF.
}
unit CADSys4.Tests.Persistence;

interface

uses
  DUnitX.TestFramework;

type

  { : The VCL.FNCCS4JSON value helpers. }
  [TestFixture]
  TJSONHelperTests = class(TObject)
  public
    [Test]
    procedure Point2D_RoundTrips;
    [Test]
    procedure Point2D_HomogeneousCoordinate_IsOnlyWrittenWhenNotOne;
    [Test]
    procedure Point3D_RoundTrips;
    [Test]
    procedure Transform2D_RoundTrips;
    [Test]
    procedure Transform3D_RoundTrips;
    [Test]
    procedure Enum_IsWrittenByName;
    [Test]
    procedure Enum_UnknownName_FallsBackToTheDefault;
    [Test]
    procedure MissingMembers_ReturnTheDefaults;
    [Test]
    procedure WrongMemberKind_Raises;
    [Test]
    procedure Text_RoundTripsThroughAStream;
    [Test]
    procedure InvalidText_Raises;
  end;

  { : Per shape SaveToJSON / CreateFromJSON. }
  [TestFixture]
  TShapeJSONRoundTripTests = class(TObject)
  public
    [Test]
    procedure Line2D_PreservesEndpoints;
    [Test]
    procedure SavedObject_CarriesItsClassName;
    [Test]
    procedure SavedPoints_AreCompactArrays;
    [Test]
    procedure Polyline2D_PreservesPointsAndGrowing;
    [Test]
    procedure Frame2D_PreservesSavingTypeAndPrecision;
    [Test]
    procedure Arc2D_PreservesDirection;
    [Test]
    procedure BSpline2D_PreservesOrder;
    [Test]
    procedure Text2D_PreservesTextAndFont;
    [Test]
    procedure Text2D_NonAsciiText_SurvivesUnchanged;
    [Test]
    procedure Object2D_PreservesTheModelTransform;
    [Test]
    procedure Object2D_WithoutTransform_WritesNoTransformMember;
    [Test]
    procedure GraphicObject_PreservesIDLayerAndFlags;
    [Test]
    procedure Container2D_PreservesItsChildren;
    [Test]
    procedure Line3D_PreservesEndpoints;
  end;

  { : Whole documents through TFNCCADCmp2D. }
  [TestFixture]
  TDocumentJSONRoundTripTests = class(TObject)
  private
    FTempFile: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure EmptyDocument_LoadsWithNoObjects;
    [Test]
    procedure Document_PreservesObjectCount;
    [Test]
    procedure Document_PreservesGeometryInOrder;
    [Test]
    procedure Document_PreservesShapeClasses;
    [Test]
    procedure Document_PreservesLayerAssignment;
    [Test]
    procedure Document_ViaFile_PreservesGeometry;
    [Test]
    procedure Document_ViaString_PreservesGeometry;
    [Test]
    procedure ModifiedLayer_PreservesNameAndFlags;
    [Test]
    procedure LayerColour_WritesHexWithAlphaOnlyWhenNeeded;
    [Test]
    procedure UnmodifiedLayer_IsNotSaved;
    [Test]
    procedure NonStreamableLayer_ObjectsAreNotSaved;
    [Test]
    procedure SourceBlockAndBlock_RelinkByName;
    [Test]
    procedure Library_SavesOnlyLibraryBlocks;
    [Test]
    procedure SavedDocument_HasTheFormatHeader;
    [Test]
    procedure ForeignFormat_RaisesECADFileNotValid;
    [Test]
    procedure WrongKind_RaisesECADFileNotValid;
    [Test]
    procedure UnsupportedVersion_RaisesECADFileNotValid;
  end;

  { : Vectorial fonts. }
  [TestFixture]
  TVectFontJSONTests = class(TObject)
  public
    [Test]
    procedure VectChar_PreservesItsVectors;
    [Test]
    procedure VectFont_PreservesItsCharsByCode;
    [Test]
    procedure VectFont_HasTheFontKindHeader;
  end;

  { : The class registry that CADSysObjectFromJSON uses. }
  [TestFixture]
  TClassRegistryTests = class(TObject)
  public
    [Test]
    procedure FindClassByName_ReturnsTheClassReference;
    [Test]
    procedure FindClassByIndex_RoundTripsWithFindClassIndex;
    [Test]
    procedure UnknownClassName_RaisesECADObjClassNotFound;
    [Test]
    procedure ObjectWithoutType_RaisesECADObjClassNotFound;
    [Test]
    procedure ObjectWithUnknownType_RaisesECADObjClassNotFound;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  VCL.FNCCS4BaseTypes,
  VCL.FNCCS4JSON,
  VCL.FNCCS4Graphics,
  VCL.FNCCADSys4,
  VCL.FNCCS4Shapes,
  { Required: its initialization section fills the persistence class
    registry and the font list. }
  VCL.FNCCadSysRegister;

const
  { Geometry must survive a Double round trip; the tolerance only keeps
    the intent readable. }
  TOL_EXACT = 1E-9;

procedure AssertReal(const AExpected, AActual, ATolerance: Double;
  const AMessage: string);
begin
  Assert.AreEqual(AExpected, AActual, ATolerance, AMessage);
end;

procedure AssertInt(const AExpected, AActual: Integer;
  const AMessage: string);
begin
  Assert.AreEqual(AExpected, AActual, AMessage);
end;

procedure AssertStr(const AExpected, AActual: string; const AMessage: string);
begin
  Assert.AreEqual(AExpected, AActual, AMessage);
end;

procedure AssertPoint(const AExpected, AActual: TPoint2D;
  const AMessage: string);
begin
  AssertReal(AExpected.X, AActual.X, TOL_EXACT, AMessage + ' (X)');
  AssertReal(AExpected.Y, AActual.Y, TOL_EXACT, AMessage + ' (Y)');
  AssertReal(AExpected.W, AActual.W, TOL_EXACT, AMessage + ' (W)');
end;

{ : Saves AObj to JSON and rebuilds it through the registry - the path a
  document takes. The caller owns the result. }
function SaveAndReload(const AObj: TGraphicObject): TGraphicObject;
var
  TmpJSON: TJSONObject;
begin
  TmpJSON := CADSysObjectToJSON(AObj);
  try
    Result := CADSysObjectFromJSON(TmpJSON);
  finally
    TmpJSON.Free;
  end;
end;

{ : Saves ASrc and loads it into ADst through JSON text, the way a file
  round trip works. }
procedure SaveAndLoadDocument(const ASrc, ADst: TFNCCADCmp2D);
begin
  ADst.LoadFromJSONString(ASrc.SaveToJSONString);
end;

{ =================================================================== }
{ TJSONHelperTests                                                    }
{ =================================================================== }

procedure TJSONHelperTests.Point2D_RoundTrips;
var
  TmpArray: TJSONArray;
begin
  TmpArray := Point2DToJSON(Point2D(1.25, -7.5));
  try
    AssertPoint(Point2D(1.25, -7.5), JSONToPoint2D(TmpArray), 'Point');
  finally
    TmpArray.Free;
  end;
end;

procedure TJSONHelperTests.Point2D_HomogeneousCoordinate_IsOnlyWrittenWhenNotOne;
var
  TmpPt: TPoint2D;
  TmpArray: TJSONArray;
begin
  TmpArray := Point2DToJSON(Point2D(1, 2));
  try
    AssertInt(2, TmpArray.Count, 'W = 1 stays out of the file');
  finally
    TmpArray.Free;
  end;
  TmpPt.X := 1;
  TmpPt.Y := 2;
  TmpPt.W := 4;
  TmpArray := Point2DToJSON(TmpPt);
  try
    AssertInt(3, TmpArray.Count, 'W <> 1 is written');
    AssertReal(4, JSONToPoint2D(TmpArray).W, TOL_EXACT, 'W');
  finally
    TmpArray.Free;
  end;
end;

procedure TJSONHelperTests.Point3D_RoundTrips;
var
  TmpArray: TJSONArray;
  TmpPt: TPoint3D;
begin
  TmpArray := Point3DToJSON(Point3D(1.5, 2.5, -3.5));
  try
    TmpPt := JSONToPoint3D(TmpArray);
    AssertReal(1.5, TmpPt.X, TOL_EXACT, 'X');
    AssertReal(2.5, TmpPt.Y, TOL_EXACT, 'Y');
    AssertReal(-3.5, TmpPt.Z, TOL_EXACT, 'Z');
    AssertReal(1.0, TmpPt.W, TOL_EXACT, 'W defaults to 1');
  finally
    TmpArray.Free;
  end;
end;

procedure TJSONHelperTests.Transform2D_RoundTrips;
var
  TmpObj: TJSONObject;
  TmpSrc, TmpDst: TTransf2D;
  R, C: Integer;
begin
  TmpSrc := Translate2D(3.5, -1.25);
  TmpObj := TJSONObject.Create;
  try
    JSetTransf2D(TmpObj, 'transform', TmpSrc);
    TmpDst := JGetTransf2D(TmpObj, 'transform');
    for R := 1 to 3 do
      for C := 1 to 3 do
        AssertReal(TmpSrc[R, C], TmpDst[R, C], TOL_EXACT,
          Format('[%d,%d]', [R, C]));
  finally
    TmpObj.Free;
  end;
end;

procedure TJSONHelperTests.Transform3D_RoundTrips;
var
  TmpObj: TJSONObject;
  TmpSrc, TmpDst: TTransf3D;
  R, C: Integer;
begin
  TmpSrc := Translate3D(1, 2, 3);
  TmpObj := TJSONObject.Create;
  try
    JSetTransf3D(TmpObj, 'transform', TmpSrc);
    TmpDst := JGetTransf3D(TmpObj, 'transform');
    for R := 1 to 4 do
      for C := 1 to 4 do
        AssertReal(TmpSrc[R, C], TmpDst[R, C], TOL_EXACT,
          Format('[%d,%d]', [R, C]));
  finally
    TmpObj.Free;
  end;
end;

procedure TJSONHelperTests.Enum_IsWrittenByName;
var
  TmpObj: TJSONObject;
begin
  TmpObj := TJSONObject.Create;
  try
    JSetEnum(TmpObj, 'kind', 1, ['first', 'second', 'third']);
    AssertStr('second', JGetStr(TmpObj, 'kind'), 'The name, not the ordinal');
    AssertInt(1, JGetEnum(TmpObj, 'kind', 0, ['first', 'second', 'third']),
      'Read back as its ordinal');
  finally
    TmpObj.Free;
  end;
end;

procedure TJSONHelperTests.Enum_UnknownName_FallsBackToTheDefault;
var
  TmpObj: TJSONObject;
begin
  TmpObj := TJSONObject.Create;
  try
    JSetStr(TmpObj, 'kind', 'fourth');
    AssertInt(2, JGetEnum(TmpObj, 'kind', 2, ['first', 'second', 'third']),
      'An unknown name gives the default');
  finally
    TmpObj.Free;
  end;
end;

procedure TJSONHelperTests.MissingMembers_ReturnTheDefaults;
var
  TmpObj: TJSONObject;
begin
  TmpObj := TJSONObject.Create;
  try
    AssertStr('none', JGetStr(TmpObj, 'absent', 'none'), 'string');
    AssertInt(7, JGetInt(TmpObj, 'absent', 7), 'integer');
    AssertReal(1.5, JGetReal(TmpObj, 'absent', 1.5), TOL_EXACT, 'real');
    Assert.IsTrue(JGetBool(TmpObj, 'absent', True), 'boolean');
    Assert.IsFalse(JHas(TmpObj, 'absent'), 'JHas');
    Assert.IsNull(JGetObject(TmpObj, 'absent'), 'object');
    Assert.IsNull(JGetArray(TmpObj, 'absent'), 'array');
  finally
    TmpObj.Free;
  end;
end;

procedure TJSONHelperTests.WrongMemberKind_Raises;
var
  TmpObj: TJSONObject;
begin
  TmpObj := TJSONObject.Create;
  try
    JSetInt(TmpObj, 'points', 3);
    Assert.WillRaise(
      procedure
      begin
        JGetArray(TmpObj, 'points');
      end, ECADJSONError, 'A member that must be an array and is not');
    Assert.WillRaise(
      procedure
      begin
        JRequireObject(TmpObj, 'absent');
      end, ECADJSONError, 'A required member that is missing');
  finally
    TmpObj.Free;
  end;
end;

procedure TJSONHelperTests.Text_RoundTripsThroughAStream;
var
  TmpObj, TmpBack: TJSONObject;
  TmpStream: TMemoryStream;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpObj := TJSONObject.Create;
    try
      JSetStr(TmpObj, 'name', 'drawing');
      JSetReal(TmpObj, 'scale', 0.125);
      JSONToStream(TmpObj, TmpStream);
    finally
      TmpObj.Free;
    end;
    TmpStream.Position := 0;
    TmpBack := JSONFromStream(TmpStream);
    try
      AssertStr('drawing', JGetStr(TmpBack, 'name'), 'name');
      AssertReal(0.125, JGetReal(TmpBack, 'scale'), TOL_EXACT, 'scale');
    finally
      TmpBack.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TJSONHelperTests.InvalidText_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      TextToJSONObject('this is not JSON').Free;
    end, ECADJSONError, 'Garbage text');
  Assert.WillRaise(
    procedure
    begin
      TextToJSONObject('[1, 2, 3]').Free;
    end, ECADJSONError, 'Valid JSON that is not an object');
end;

{ =================================================================== }
{ TShapeJSONRoundTripTests                                            }
{ =================================================================== }

procedure TShapeJSONRoundTripTests.Line2D_PreservesEndpoints;
var
  TmpSrc, TmpDst: TLine2D;
begin
  TmpSrc := TLine2D.Create(7, Point2D(1.5, -2.25), Point2D(30.125, 40.5));
  try
    TmpDst := TLine2D(SaveAndReload(TmpSrc));
    try
      AssertPoint(Point2D(1.5, -2.25), TmpDst.Points[0], 'Start point');
      AssertPoint(Point2D(30.125, 40.5), TmpDst.Points[1], 'End point');
      AssertInt(7, TmpDst.ID, 'ID');
    finally
      TmpDst.Free;
    end;
  finally
    TmpSrc.Free;
  end;
end;

procedure TShapeJSONRoundTripTests.SavedObject_CarriesItsClassName;
var
  TmpSrc: TLine2D;
  TmpJSON: TJSONObject;
begin
  TmpSrc := TLine2D.Create(0, Point2D(0, 0), Point2D(1, 1));
  try
    TmpJSON := CADSysObjectToJSON(TmpSrc);
    try
      AssertStr('TLine2D', JGetStr(TmpJSON, 'type'),
        'The class name is what rebuilds the object');
    finally
      TmpJSON.Free;
    end;
  finally
    TmpSrc.Free;
  end;
end;

procedure TShapeJSONRoundTripTests.SavedPoints_AreCompactArrays;
var
  TmpSrc: TLine2D;
  TmpJSON: TJSONObject;
  TmpPoints: TJSONArray;
begin
  TmpSrc := TLine2D.Create(0, Point2D(3, 4), Point2D(5, 6));
  try
    TmpJSON := CADSysObjectToJSON(TmpSrc);
    try
      TmpPoints := JRequireArray(TmpJSON, 'points');
      AssertInt(2, TmpPoints.Count, 'Two points');
      AssertInt(2, JItemArray(TmpPoints, 0).Count,
        'A point is an [x, y] array');
      AssertReal(3, JItemReal(JItemArray(TmpPoints, 0), 0), TOL_EXACT, 'X');
      AssertReal(4, JItemReal(JItemArray(TmpPoints, 0), 1), TOL_EXACT, 'Y');
    finally
      TmpJSON.Free;
    end;
  finally
    TmpSrc.Free;
  end;
end;

procedure TShapeJSONRoundTripTests.Polyline2D_PreservesPointsAndGrowing;
var
  TmpSrc, TmpDst: TPolyline2D;
begin
  TmpSrc := TPolyline2D.Create(0, [Point2D(0, 0), Point2D(1, 2),
    Point2D(3, 5), Point2D(8, 13)]);
  try
    TmpDst := TPolyline2D(SaveAndReload(TmpSrc));
    try
      AssertInt(4, TmpDst.Points.Count, 'Point count');
      AssertPoint(Point2D(3, 5), TmpDst.Points[2], 'Third point');
      Assert.AreEqual(TmpSrc.Points.GrowingEnabled,
        TmpDst.Points.GrowingEnabled, 'GrowingEnabled');
    finally
      TmpDst.Free;
    end;
  finally
    TmpSrc.Free;
  end;
end;

procedure TShapeJSONRoundTripTests.Frame2D_PreservesSavingTypeAndPrecision;
var
  TmpSrc, TmpDst: TFrame2D;
begin
  TmpSrc := TFrame2D.Create(0, Point2D(0, 0), Point2D(100, 50));
  try
    TmpSrc.SavingType := stSpace;
    TmpSrc.CurvePrecision := 37;
    TmpDst := TFrame2D(SaveAndReload(TmpSrc));
    try
      Assert.IsTrue(TmpDst.SavingType = stSpace, 'SavingType');
      AssertInt(37, TmpDst.CurvePrecision, 'CurvePrecision');
      AssertPoint(Point2D(100, 50), TmpDst.Points[1], 'Second corner');
    finally
      TmpDst.Free;
    end;
  finally
    TmpSrc.Free;
  end;
end;

procedure TShapeJSONRoundTripTests.Arc2D_PreservesDirection;
var
  TmpSrc, TmpDst: TArc2D;
begin
  TmpSrc := TArc2D.Create(0, Point2D(-10, -10), Point2D(10, 10), 0.0, Pi / 2);
  try
    TmpSrc.Direction := adCounterClockwise;
    TmpDst := TArc2D(SaveAndReload(TmpSrc));
    try
      Assert.IsTrue(TmpDst.Direction = adCounterClockwise, 'Direction');
      AssertReal(TmpSrc.StartAngle, TmpDst.StartAngle, TOL_EXACT,
        'Start angle');
    finally
      TmpDst.Free;
    end;
  finally
    TmpSrc.Free;
  end;
end;

procedure TShapeJSONRoundTripTests.BSpline2D_PreservesOrder;
var
  TmpSrc, TmpDst: TBSpline2D;
begin
  TmpSrc := TBSpline2D.Create(0, [Point2D(0, 0), Point2D(1, 5),
    Point2D(4, 5), Point2D(6, 0)]);
  try
    TmpSrc.Order := 3;
    TmpDst := TBSpline2D(SaveAndReload(TmpSrc));
    try
      AssertInt(3, TmpDst.Order, 'Order');
      AssertInt(4, TmpDst.Points.Count, 'Control points');
    finally
      TmpDst.Free;
    end;
  finally
    TmpSrc.Free;
  end;
end;

procedure TShapeJSONRoundTripTests.Text2D_PreservesTextAndFont;
var
  TmpSrc, TmpDst: TText2D;
begin
  TmpSrc := TText2D.Create(42, Rect2D(1, 2, 11, 6), 3.5, AnsiString('HELLO'));
  try
    TmpSrc.DrawBox := True;
    TmpSrc.ClippingFlags := 32;
    TmpSrc.LogFont.FaceName := 'Arial';
    TmpSrc.LogFont.Escapement := 900;
    TmpDst := TText2D(SaveAndReload(TmpSrc));
    try
      AssertStr('HELLO', string(TmpDst.Text), 'Text');
      AssertReal(3.5, TmpDst.Height, TOL_EXACT, 'Height');
      Assert.IsTrue(TmpDst.DrawBox, 'DrawBox');
      AssertInt(32, TmpDst.ClippingFlags, 'ClippingFlags');
      AssertStr('Arial', string(TmpDst.LogFont.FaceName), 'Font face');
      AssertInt(900, TmpDst.LogFont.Escapement, 'Font escapement');
    finally
      TmpDst.Free;
    end;
  finally
    TmpSrc.Free;
  end;
end;

procedure TShapeJSONRoundTripTests.Text2D_NonAsciiText_SurvivesUnchanged;
var
  TmpSrc, TmpDst: TText2D;
begin
  { The old binary format wrote an AnsiString through a PChar cast, which
    handed GDI the ANSI bytes as UTF-16. JSON stores the text as text. }
  TmpSrc := TText2D.Create(1, Rect2D(0, 0, 10, 10), 5.0,
    AnsiString('Ruimte 1'));
  try
    TmpDst := TText2D(SaveAndReload(TmpSrc));
    try
      AssertStr('Ruimte 1', string(TmpDst.Text), 'Text');
    finally
      TmpDst.Free;
    end;
  finally
    TmpSrc.Free;
  end;
end;

procedure TShapeJSONRoundTripTests.Object2D_PreservesTheModelTransform;
var
  TmpSrc, TmpDst: TLine2D;
  TmpBox: TRect2D;
begin
  TmpSrc := TLine2D.Create(0, Point2D(0, 0), Point2D(10, 0));
  try
    TmpSrc.MoveTo(Point2D(5, 5), Point2D(0, 0));
    TmpBox := TmpSrc.Box;
    TmpDst := TLine2D(SaveAndReload(TmpSrc));
    try
      Assert.IsTrue(TmpDst.HasTransform, 'The transform came back');
      AssertReal(TmpBox.Left, TmpDst.Box.Left, TOL_EXACT, 'Box left');
      AssertReal(TmpBox.Bottom, TmpDst.Box.Bottom, TOL_EXACT, 'Box bottom');
    finally
      TmpDst.Free;
    end;
  finally
    TmpSrc.Free;
  end;
end;

procedure TShapeJSONRoundTripTests.Object2D_WithoutTransform_WritesNoTransformMember;
var
  TmpSrc: TLine2D;
  TmpJSON: TJSONObject;
begin
  TmpSrc := TLine2D.Create(0, Point2D(0, 0), Point2D(1, 1));
  try
    TmpJSON := CADSysObjectToJSON(TmpSrc);
    try
      Assert.IsFalse(JHas(TmpJSON, 'transform'),
        'An untransformed object keeps the member out of the file');
    finally
      TmpJSON.Free;
    end;
  finally
    TmpSrc.Free;
  end;
end;

procedure TShapeJSONRoundTripTests.GraphicObject_PreservesIDLayerAndFlags;
var
  TmpSrc, TmpDst: TLine2D;
begin
  TmpSrc := TLine2D.Create(1234, Point2D(0, 0), Point2D(1, 1));
  try
    TmpSrc.Layer := 9;
    TmpSrc.Visible := False;
    TmpSrc.Enabled := False;
    TmpDst := TLine2D(SaveAndReload(TmpSrc));
    try
      AssertInt(1234, TmpDst.ID, 'ID');
      AssertInt(9, TmpDst.Layer, 'Layer');
      Assert.IsFalse(TmpDst.Visible, 'Visible');
      Assert.IsFalse(TmpDst.Enabled, 'Enabled');
      Assert.IsTrue(TmpDst.ToBeSaved, 'ToBeSaved');
    finally
      TmpDst.Free;
    end;
  finally
    TmpSrc.Free;
  end;
end;

procedure TShapeJSONRoundTripTests.Container2D_PreservesItsChildren;
var
  TmpSrc, TmpDst: TContainer2D;
begin
  TmpSrc := TContainer2D.Create(0, [TLine2D.Create(1, Point2D(0, 0),
    Point2D(1, 1)), TEllipse2D.Create(2, Point2D(2, 2), Point2D(6, 6))]);
  try
    TmpDst := TContainer2D(SaveAndReload(TmpSrc));
    try
      AssertInt(2, Integer(TmpDst.Objects.Count), 'Child count');
      Assert.IsTrue(TmpDst.Objects.Find(1) is TLine2D, 'First child');
      Assert.IsTrue(TmpDst.Objects.Find(2) is TEllipse2D, 'Second child');
    finally
      TmpDst.Free;
    end;
  finally
    TmpSrc.Free;
  end;
end;

procedure TShapeJSONRoundTripTests.Line3D_PreservesEndpoints;
var
  TmpSrc, TmpDst: TLine3D;
begin
  TmpSrc := TLine3D.Create(3, Point3D(1, 2, 3), Point3D(4, 5, 6));
  try
    TmpDst := TLine3D(SaveAndReload(TmpSrc));
    try
      AssertReal(1, TmpDst.Points[0].X, TOL_EXACT, 'Start X');
      AssertReal(3, TmpDst.Points[0].Z, TOL_EXACT, 'Start Z');
      AssertReal(6, TmpDst.Points[1].Z, TOL_EXACT, 'End Z');
    finally
      TmpDst.Free;
    end;
  finally
    TmpSrc.Free;
  end;
end;

{ =================================================================== }
{ TDocumentJSONRoundTripTests                                         }
{ =================================================================== }

procedure TDocumentJSONRoundTripTests.Setup;
begin
  FTempFile := TPath.ChangeExtension(TPath.GetTempFileName, '.json');
end;

procedure TDocumentJSONRoundTripTests.TearDown;
begin
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure TDocumentJSONRoundTripTests.EmptyDocument_LoadsWithNoObjects;
var
  TmpSrc, TmpDst: TFNCCADCmp2D;
begin
  TmpSrc := TFNCCADCmp2D.Create(nil);
  TmpDst := TFNCCADCmp2D.Create(nil);
  try
    SaveAndLoadDocument(TmpSrc, TmpDst);
    AssertInt(0, TmpDst.ObjectsCount, 'Object count');
    AssertInt(0, TmpDst.SourceBlocksCount, 'Source block count');
  finally
    TmpSrc.Free;
    TmpDst.Free;
  end;
end;

procedure TDocumentJSONRoundTripTests.Document_PreservesObjectCount;
var
  TmpSrc, TmpDst: TFNCCADCmp2D;
begin
  TmpSrc := TFNCCADCmp2D.Create(nil);
  TmpDst := TFNCCADCmp2D.Create(nil);
  try
    TmpSrc.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
    TmpSrc.AddObject(-1, TEllipse2D.Create(-1, Point2D(2, 2), Point2D(4, 4)));
    TmpSrc.AddObject(-1, TRectangle2D.Create(-1, Point2D(5, 5),
      Point2D(9, 7)));
    SaveAndLoadDocument(TmpSrc, TmpDst);
    AssertInt(3, TmpDst.ObjectsCount, 'Object count');
  finally
    TmpSrc.Free;
    TmpDst.Free;
  end;
end;

procedure TDocumentJSONRoundTripTests.Document_PreservesGeometryInOrder;
var
  TmpSrc, TmpDst: TFNCCADCmp2D;
  TmpLine: TLine2D;
begin
  TmpSrc := TFNCCADCmp2D.Create(nil);
  TmpDst := TFNCCADCmp2D.Create(nil);
  try
    TmpSrc.AddObject(-1, TLine2D.Create(-1, Point2D(-11.5, 22.25),
      Point2D(33.75, -44.125)));
    TmpSrc.AddObject(-1, TLine2D.Create(-1, Point2D(1, 1), Point2D(2, 2)));
    SaveAndLoadDocument(TmpSrc, TmpDst);
    TmpLine := TmpDst.GetObject(0) as TLine2D;
    AssertPoint(Point2D(-11.5, 22.25), TmpLine.Points[0], 'First line start');
    AssertPoint(Point2D(33.75, -44.125), TmpLine.Points[1], 'First line end');
    TmpLine := TmpDst.GetObject(1) as TLine2D;
    AssertPoint(Point2D(1, 1), TmpLine.Points[0], 'Second line start');
  finally
    TmpSrc.Free;
    TmpDst.Free;
  end;
end;

procedure TDocumentJSONRoundTripTests.Document_PreservesShapeClasses;
var
  TmpSrc, TmpDst: TFNCCADCmp2D;
begin
  TmpSrc := TFNCCADCmp2D.Create(nil);
  TmpDst := TFNCCADCmp2D.Create(nil);
  try
    TmpSrc.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
    TmpSrc.AddObject(-1, TFilledEllipse2D.Create(-1, Point2D(0, 0),
      Point2D(4, 4)));
    TmpSrc.AddObject(-1, TPolygon2D.Create(-1, [Point2D(1, 1), Point2D(5, 1),
      Point2D(3, 4)]));
    SaveAndLoadDocument(TmpSrc, TmpDst);
    Assert.IsTrue(TmpDst.GetObject(0) is TLine2D, 'First object');
    Assert.IsTrue(TmpDst.GetObject(1) is TFilledEllipse2D, 'Second object');
    Assert.IsTrue(TmpDst.GetObject(2) is TPolygon2D, 'Third object');
  finally
    TmpSrc.Free;
    TmpDst.Free;
  end;
end;

procedure TDocumentJSONRoundTripTests.Document_PreservesLayerAssignment;
var
  TmpSrc, TmpDst: TFNCCADCmp2D;
  TmpLine: TLine2D;
begin
  TmpSrc := TFNCCADCmp2D.Create(nil);
  TmpDst := TFNCCADCmp2D.Create(nil);
  try
    TmpLine := TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1));
    { AddObject puts the object on CurrentLayer, so the layer has to be
      set through the CAD or after the add - not on the loose object. }
    TmpSrc.AddObject(-1, TmpLine);
    TmpLine.Layer := 5;
    SaveAndLoadDocument(TmpSrc, TmpDst);
    AssertInt(5, (TmpDst.GetObject(0) as TLine2D).Layer, 'Layer');
  finally
    TmpSrc.Free;
    TmpDst.Free;
  end;
end;

procedure TDocumentJSONRoundTripTests.Document_ViaFile_PreservesGeometry;
var
  TmpSrc, TmpDst: TFNCCADCmp2D;
  TmpLine: TLine2D;
begin
  TmpSrc := TFNCCADCmp2D.Create(nil);
  TmpDst := TFNCCADCmp2D.Create(nil);
  try
    TmpSrc.AddObject(-1, TLine2D.Create(-1, Point2D(2.5, 3.5),
      Point2D(4.5, 5.5)));
    TmpSrc.SaveToFile(FTempFile);
    Assert.IsTrue(TFile.Exists(FTempFile), 'The file was written');
    TmpDst.LoadFromFile(FTempFile);
    AssertInt(1, TmpDst.ObjectsCount, 'Object count');
    TmpLine := TmpDst.GetObject(0) as TLine2D;
    AssertPoint(Point2D(2.5, 3.5), TmpLine.Points[0], 'Start point');
  finally
    TmpSrc.Free;
    TmpDst.Free;
  end;
end;

procedure TDocumentJSONRoundTripTests.Document_ViaString_PreservesGeometry;
var
  TmpSrc, TmpDst: TFNCCADCmp2D;
  TmpText: string;
begin
  TmpSrc := TFNCCADCmp2D.Create(nil);
  TmpDst := TFNCCADCmp2D.Create(nil);
  try
    TmpSrc.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(9, 9)));
    TmpText := TmpSrc.SaveToJSONString;
    Assert.IsTrue(Pos('"TLine2D"', TmpText) > 0,
      'The text carries the class name');
    TmpDst.LoadFromJSONString(TmpText);
    AssertPoint(Point2D(9, 9), (TmpDst.GetObject(0) as TLine2D).Points[1],
      'End point');
  finally
    TmpSrc.Free;
    TmpDst.Free;
  end;
end;

procedure TDocumentJSONRoundTripTests.ModifiedLayer_PreservesNameAndFlags;
var
  TmpSrc, TmpDst: TFNCCADCmp2D;
begin
  TmpSrc := TFNCCADCmp2D.Create(nil);
  TmpDst := TFNCCADCmp2D.Create(nil);
  try
    { TLayer.SetName sets fModified, which is what makes TLayers save
      this layer at all. }
    TmpSrc.Layers[7].Name := 'WALLS';
    TmpSrc.Layers[7].Visible := False;
    TmpSrc.Layers[7].Opaque := True;
    TmpSrc.Layers[7].Pen.Color := TCADColor($FF334455);
    TmpSrc.Layers[7].Brush.Color := CADColorSetAlpha(cadclLime, 96);
    SaveAndLoadDocument(TmpSrc, TmpDst);
    AssertStr('WALLS', string(TmpDst.Layers[7].Name), 'Layer 7 name');
    Assert.IsFalse(TmpDst.Layers[7].Visible, 'Layer 7 Visible flag');
    Assert.IsTrue(TmpDst.Layers[7].Opaque, 'Layer 7 Opaque flag');
    Assert.IsTrue(TmpDst.Layers[7].Streamable, 'Layer 7 Streamable flag');
    Assert.AreEqual<Cardinal>(Cardinal($FF334455),
      Cardinal(TmpDst.Layers[7].Pen.Color), 'Layer 7 pen colour');
    Assert.AreEqual<Cardinal>(Cardinal(CADColorSetAlpha(cadclLime, 96)),
      Cardinal(TmpDst.Layers[7].Brush.Color),
      'Layer 7 fill colour, alpha and all');
  finally
    TmpSrc.Free;
    TmpDst.Free;
  end;
end;

procedure TDocumentJSONRoundTripTests.LayerColour_WritesHexWithAlphaOnlyWhenNeeded;
var
  TmpCad: TFNCCADCmp2D;
  TmpDoc: TJSONObject;
  TmpLayers: TJSONArray;
  TmpPen: TJSONObject;
begin
  TmpCad := TFNCCADCmp2D.Create(nil);
  try
    TmpCad.Layers[3].Name := 'OPAQUE';
    TmpCad.Layers[3].Pen.Color := cadclRed;
    TmpCad.Layers[4].Name := 'GHOST';
    TmpCad.Layers[4].Pen.Color := CADColorSetAlpha(cadclRed, 128);
    TmpDoc := TmpCad.SaveToJSON;
    try
      TmpLayers := JRequireArray(TmpDoc, 'layers');
      AssertInt(2, TmpLayers.Count, 'both modified layers were saved');
      TmpPen := JRequireObject(JItemObject(TmpLayers, 0), 'pen');
      AssertStr('#FF0000', JGetStr(TmpPen, 'color'),
        'an opaque colour stays six digits');
      TmpPen := JRequireObject(JItemObject(TmpLayers, 1), 'pen');
      AssertStr('#80FF0000', JGetStr(TmpPen, 'color'),
        'alpha is written when it is not opaque');
    finally
      TmpDoc.Free;
    end;
  finally
    TmpCad.Free;
  end;
end;

procedure TDocumentJSONRoundTripTests.UnmodifiedLayer_IsNotSaved;
var
  TmpSrc, TmpDst: TFNCCADCmp2D;
begin
  { TLayers.SaveToJSON only writes layers whose fModified is set, and
    Visible/Active/Opaque/Streamable are plain field writes that do NOT
    set it. This is current, documented behaviour - pinned so that a
    future change to the setters is visible here. }
  TmpSrc := TFNCCADCmp2D.Create(nil);
  TmpDst := TFNCCADCmp2D.Create(nil);
  try
    TmpSrc.Layers[9].Visible := False;
    Assert.IsFalse(TmpSrc.Layers[9].Modified,
      'Writing Visible does not mark the layer modified');
    SaveAndLoadDocument(TmpSrc, TmpDst);
    Assert.IsTrue(TmpDst.Layers[9].Visible,
      'Layer 9 came back at its default because it was never saved');
  finally
    TmpSrc.Free;
    TmpDst.Free;
  end;
end;

procedure TDocumentJSONRoundTripTests.NonStreamableLayer_ObjectsAreNotSaved;
var
  TmpSrc, TmpDst: TFNCCADCmp2D;
  TmpLine: TLine2D;
begin
  TmpSrc := TFNCCADCmp2D.Create(nil);
  TmpDst := TFNCCADCmp2D.Create(nil);
  try
    TmpSrc.Layers[4].Streamable := False;
    TmpLine := TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1));
    { AddObject puts the object on CurrentLayer; set the layer after. }
    TmpSrc.AddObject(-1, TmpLine);
    TmpLine.Layer := 4;
    TmpSrc.AddObject(-1, TLine2D.Create(-1, Point2D(2, 2), Point2D(3, 3)));
    SaveAndLoadDocument(TmpSrc, TmpDst);
    AssertInt(1, TmpDst.ObjectsCount,
      'Only the object on the streamable layer was saved');
  finally
    TmpSrc.Free;
    TmpDst.Free;
  end;
end;

procedure TDocumentJSONRoundTripTests.SourceBlockAndBlock_RelinkByName;
var
  TmpSrc, TmpDst: TFNCCADCmp2D;
  TmpSource: TSourceBlock2D;
  TmpBlock: TBlock2D;
begin
  TmpSrc := TFNCCADCmp2D.Create(nil);
  TmpDst := TFNCCADCmp2D.Create(nil);
  try
    TmpSource := TSourceBlock2D.Create(-1, StringToBlockName('DOOR'),
      [TLine2D.Create(0, Point2D(0, 0), Point2D(0, 2)),
      TLine2D.Create(1, Point2D(0, 2), Point2D(1, 2))]);
    TmpSrc.AddSourceBlock(TmpSource);
    TmpSrc.AddObject(-1, TBlock2D.Create(-1, TmpSource));
    SaveAndLoadDocument(TmpSrc, TmpDst);
    AssertInt(1, TmpDst.SourceBlocksCount, 'Source blocks after loading');
    AssertInt(1, TmpDst.ObjectsCount, 'Objects after loading');
    TmpBlock := TmpDst.GetObject(0) as TBlock2D;
    Assert.IsTrue(TmpBlock.SourceBlock <> nil,
      'TBlock2D.UpdateReference relinked the block to its source');
    Assert.IsTrue(TmpBlock.SourceBlock.Name = StringToBlockName('DOOR'),
      'The block was relinked by source block name');
    AssertInt(2, Integer(TmpBlock.SourceBlock.Objects.Count),
      'The source block kept both of its children');
  finally
    TmpSrc.Free;
    TmpDst.Free;
  end;
end;

procedure TDocumentJSONRoundTripTests.Library_SavesOnlyLibraryBlocks;
var
  TmpSrc, TmpDst: TFNCCADCmp2D;
  TmpLib, TmpPlain: TSourceBlock2D;
  TmpDoc: TJSONObject;
begin
  TmpSrc := TFNCCADCmp2D.Create(nil);
  TmpDst := TFNCCADCmp2D.Create(nil);
  try
    TmpLib := TSourceBlock2D.Create(-1, StringToBlockName('WINDOW'),
      [TLine2D.Create(0, Point2D(0, 0), Point2D(1, 0))]);
    TmpLib.IsLibraryBlock := True;
    TmpSrc.AddSourceBlock(TmpLib);
    TmpPlain := TSourceBlock2D.Create(-1, StringToBlockName('DOOR'),
      [TLine2D.Create(0, Point2D(0, 0), Point2D(0, 1))]);
    TmpSrc.AddSourceBlock(TmpPlain);

    TmpDoc := TmpSrc.SaveLibraryToJSON;
    try
      AssertStr('library', JGetStr(TmpDoc, 'kind'), 'Document kind');
      AssertInt(1, JRequireArray(TmpDoc, 'blocks').Count,
        'Only the library block is in a library document');
      TmpDst.LoadLibraryFromJSON(TmpDoc);
    finally
      TmpDoc.Free;
    end;
    AssertInt(1, TmpDst.SourceBlocksCount, 'Blocks after loading');
  finally
    TmpSrc.Free;
    TmpDst.Free;
  end;
end;

procedure TDocumentJSONRoundTripTests.SavedDocument_HasTheFormatHeader;
var
  TmpCad: TFNCCADCmp2D;
  TmpDoc: TJSONObject;
begin
  TmpCad := TFNCCADCmp2D.Create(nil);
  try
    TmpDoc := TmpCad.SaveToJSON;
    try
      AssertStr(CADSysJSONFormat, JGetStr(TmpDoc, 'format'), 'format');
      AssertStr(CADSysJSONVersion, JGetStr(TmpDoc, 'version'), 'version');
      AssertStr('drawing', JGetStr(TmpDoc, 'kind'), 'kind');
      Assert.IsNotNull(JGetArray(TmpDoc, 'layers'), 'layers');
      Assert.IsNotNull(JGetArray(TmpDoc, 'blocks'), 'blocks');
      Assert.IsNotNull(JGetArray(TmpDoc, 'objects'), 'objects');
    finally
      TmpDoc.Free;
    end;
  finally
    TmpCad.Free;
  end;
end;

procedure TDocumentJSONRoundTripTests.ForeignFormat_RaisesECADFileNotValid;
var
  TmpCad: TFNCCADCmp2D;
begin
  TmpCad := TFNCCADCmp2D.Create(nil);
  try
    Assert.WillRaise(
      procedure
      begin
        TmpCad.LoadFromJSONString('{"format":"something-else",' +
          '"version":"5.0","kind":"drawing"}');
      end, ECADFileNotValid, 'A document from another program');
  finally
    TmpCad.Free;
  end;
end;

procedure TDocumentJSONRoundTripTests.WrongKind_RaisesECADFileNotValid;
var
  TmpCad: TFNCCADCmp2D;
begin
  TmpCad := TFNCCADCmp2D.Create(nil);
  try
    Assert.WillRaise(
      procedure
      begin
        TmpCad.LoadFromJSONString('{"format":"' + CADSysJSONFormat +
          '","version":"' + CADSysJSONVersion + '","kind":"library"}');
      end, ECADFileNotValid, 'A library loaded as a drawing');
  finally
    TmpCad.Free;
  end;
end;

procedure TDocumentJSONRoundTripTests.UnsupportedVersion_RaisesECADFileNotValid;
var
  TmpCad: TFNCCADCmp2D;
begin
  TmpCad := TFNCCADCmp2D.Create(nil);
  try
    Assert.WillRaise(
      procedure
      begin
        TmpCad.LoadFromJSONString('{"format":"' + CADSysJSONFormat +
          '","version":"99.0","kind":"drawing"}');
      end, ECADFileNotValid, 'A newer document version');
  finally
    TmpCad.Free;
  end;
end;

{ =================================================================== }
{ TVectFontJSONTests                                                  }
{ =================================================================== }

procedure TVectFontJSONTests.VectChar_PreservesItsVectors;
var
  TmpSrc, TmpDst: TVectChar;
  TmpJSON: TJSONObject;
begin
  TmpSrc := TVectChar.Create(2);
  try
    TmpSrc.Vectors[0].Add(Point2D(0, 0));
    TmpSrc.Vectors[0].Add(Point2D(0.5, 1));
    TmpSrc.Vectors[1].Add(Point2D(0.5, 1));
    TmpSrc.Vectors[1].Add(Point2D(1, 0));
    TmpSrc.UpdateExtension(nil);
    TmpJSON := TJSONObject.Create;
    try
      TmpSrc.SaveToJSON(TmpJSON);
      TmpDst := TVectChar.CreateFromJSON(TmpJSON);
      try
        AssertInt(2, TmpDst.VectorCount, 'Sub vector count');
        AssertInt(2, Integer(TmpDst.Vectors[0].Count), 'First vector points');
        AssertPoint(Point2D(0.5, 1), TmpDst.Vectors[0].Points[1],
          'Second point of the first vector');
        AssertPoint(Point2D(1, 0), TmpDst.Vectors[1].Points[1],
          'Second point of the second vector');
      finally
        TmpDst.Free;
      end;
    finally
      TmpJSON.Free;
    end;
  finally
    TmpSrc.Free;
  end;
end;

procedure TVectFontJSONTests.VectFont_PreservesItsCharsByCode;
var
  TmpSrc, TmpDst: TVectFont;
  TmpChar: TVectChar;
  TmpJSON: TJSONObject;
begin
  TmpSrc := TVectFont.Create;
  try
    TmpChar := TmpSrc.CreateChar('A', 1);
    TmpChar.Vectors[0].Add(Point2D(0, 0));
    TmpChar.Vectors[0].Add(Point2D(1, 1));
    TmpChar.UpdateExtension(nil);
    TmpJSON := TJSONObject.Create;
    try
      TmpSrc.SaveToJSON(TmpJSON);
      TmpDst := TVectFont.CreateFromJSON(TmpJSON);
      try
        Assert.IsNotNull(TmpDst.Chars['A'], 'The char came back');
        AssertPoint(Point2D(1, 1), TmpDst.Chars['A'].Vectors[0].Points[1],
          'Char geometry');
      finally
        TmpDst.Free;
      end;
    finally
      TmpJSON.Free;
    end;
  finally
    TmpSrc.Free;
  end;
end;

procedure TVectFontJSONTests.VectFont_HasTheFontKindHeader;
var
  TmpFont: TVectFont;
  TmpJSON: TJSONObject;
begin
  TmpFont := TVectFont.Create;
  try
    TmpJSON := TJSONObject.Create;
    try
      TmpFont.SaveToJSON(TmpJSON);
      AssertStr(CADSysJSONFormat, JGetStr(TmpJSON, 'format'), 'format');
      AssertStr('font', JGetStr(TmpJSON, 'kind'), 'kind');
    finally
      TmpJSON.Free;
    end;
  finally
    TmpFont.Free;
  end;
end;

{ =================================================================== }
{ TClassRegistryTests                                                 }
{ =================================================================== }

procedure TClassRegistryTests.FindClassByName_ReturnsTheClassReference;
begin
  Assert.IsTrue(CADSysFindClassByName('TLine2D') = TLine2D, 'TLine2D');
  Assert.IsTrue(CADSysFindClassByName('TText2D') = TText2D, 'TText2D');
end;

procedure TClassRegistryTests.FindClassByIndex_RoundTripsWithFindClassIndex;
var
  TmpIndex: Word;
begin
  TmpIndex := CADSysFindClassIndex('TPolygon2D');
  Assert.IsTrue(CADSysFindClassByIndex(TmpIndex) = TPolygon2D,
    'Index and name resolve to the same class');
end;

procedure TClassRegistryTests.UnknownClassName_RaisesECADObjClassNotFound;
begin
  Assert.WillRaise(
    procedure
    begin
      CADSysFindClassByName('TNotAShape');
    end, ECADObjClassNotFound, 'An unregistered class name');
end;

procedure TClassRegistryTests.ObjectWithoutType_RaisesECADObjClassNotFound;
var
  TmpJSON: TJSONObject;
begin
  TmpJSON := TJSONObject.Create;
  try
    JSetInt(TmpJSON, 'id', 1);
    Assert.WillRaise(
      procedure
      begin
        CADSysObjectFromJSON(TmpJSON).Free;
      end, ECADObjClassNotFound, 'An object with no "type" member');
  finally
    TmpJSON.Free;
  end;
end;

procedure TClassRegistryTests.ObjectWithUnknownType_RaisesECADObjClassNotFound;
var
  TmpJSON: TJSONObject;
begin
  TmpJSON := TJSONObject.Create;
  try
    JSetStr(TmpJSON, 'type', 'TSomethingElse');
    Assert.WillRaise(
      procedure
      begin
        CADSysObjectFromJSON(TmpJSON).Free;
      end, ECADObjClassNotFound, 'An object of an unregistered class');
  finally
    TmpJSON.Free;
  end;
end;

initialization

TDUnitX.RegisterTestFixture(TJSONHelperTests);
TDUnitX.RegisterTestFixture(TShapeJSONRoundTripTests);
TDUnitX.RegisterTestFixture(TDocumentJSONRoundTripTests);
TDUnitX.RegisterTestFixture(TVectFontJSONTests);
TDUnitX.RegisterTestFixture(TClassRegistryTests);

end.
