{ : DUnitX test suite for the 2D shape hierarchy of CADSys 4.2 (FNCCS4Shapes.pas).

  Target: Delphi 12 Athens, the DUnitX bundled with the IDE, console runner.

  IMPORTANT: this suite never touches a TCanvas, a window handle or a
  TDecorativeCanvas. No Draw / DrawControlPoints / DrawObject* call is made and
  no TFNCCADViewport* is instantiated. Everything exercised here is pure geometry,
  bounding-box, profile-point and picking logic.

  FNCCadSysRegister is in the uses clause because its `initialization` section is
  what registers the shape classes, initialises the font list and creates
  _DefaultHandler2D. Every TPrimitive2D attaches that shared handler to itself
  in its constructor (FNCCS4Shapes.pas:3437) and the handler takes part in OnMe,
  so several picking expectations below depend on it being present.
}
unit CADSys4.Tests.Shapes;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  FNCCS4BaseTypes,
  FNCCADSys4,
  FNCCS4Shapes,
  FNCCadSysRegister;

type

  { ================================================================= }
  { TLine2D }
  { ================================================================= }
  [TestFixture]
  TLine2DTests = class(TObject)
  private
    FLine: TLine2D;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Construction_HasTwoControlPoints;
    [Test]
    procedure Construction_ControlPointsAreTheEndPoints;
    [Test]
    procedure Construction_GrowingIsDisabled;
    [Test]
    procedure Construction_BoxIsTheSegmentExtension;
    [Test]
    procedure MovingAControlPoint_UpdatesTheBox;
    [Test]
    procedure Transform_MovesTheBoxButNotTheControlPoints;
    [Test]
    procedure RemoveTransform_RestoresTheOriginalBox;
    [Test]
    procedure MoveTo_TranslatesTheBox;
    [Test]
    procedure Assign_CopiesGeometryAndIsIndependent;
    [Test]
    procedure Assign_DoesNotCopyTheID;
    [Test]
    procedure OnMe_PointOnTheSegment_ReturnsOnObject;
    [Test]
    procedure OnMe_PointFarAway_ReturnsNoObject;
    [Test]
    procedure OnMe_PointOnAControlPoint_ReturnsTheControlPointIndex;
    [Test]
    procedure OnMe_DisabledObject_ReturnsNoObject;
  end;

  { ================================================================= }
  { TPolyline2D / TPolygon2D }
  { ================================================================= }
  [TestFixture]
  TPolyOutlineTests = class(TObject)
  private
    FPolyline: TPolyline2D;
    FPolygon: TPolygon2D;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Polyline_Construction_PointCountMatchesTheArray;
    [Test]
    procedure Polyline_Construction_GrowingIsEnabled;
    [Test]
    procedure Polyline_ProfilePointsAreTheControlPoints;
    [Test]
    procedure Polyline_ProfileReadableWithoutBeginUse;
    [Test]
    procedure Polyline_Box;
    [Test]
    procedure Polyline_IsClosed_FalseForOpenPolyline;
    [Test]
    procedure Polyline_IsClosed_TrueWhenLastEqualsFirst;
    [Test]
    procedure Polyline_Assign_CopiesAllPointsAndIsIndependent;
    [Test]
    procedure Polyline_OnMe_PointOnASegment_ReturnsOnObject;
    [Test]
    procedure Polyline_OnMe_PointInsideButOffTheOutline_ReturnsInBBox;

    [Test]
    procedure Polygon_IsClosed_IsAlwaysTrue;
    [Test]
    procedure Polygon_OnMe_InteriorPoint_ReturnsInObject;
    [Test]
    procedure Polygon_OnMe_PointOnAnEdge_ReturnsOnObject;
    [Test]
    procedure Polygon_OnMe_PointOutsideTheBox_ReturnsNoObject;
  end;

  { ================================================================= }
  { TFrame2D / TRectangle2D }
  { ================================================================= }
  [TestFixture]
  TFrameRectangleTests = class(TObject)
  private
    FFrame: TFrame2D;
    FRect: TRectangle2D;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Frame_Construction_TwoControlPointsNoGrowing;
    [Test]
    procedure Frame_Construction_DefaultCurvePrecisionAndSavingType;
    [Test]
    procedure Frame_Box;
    [Test]
    procedure Frame_ProfileIsAlwaysFiveClosedPoints;
    [Test]
    procedure Frame_ProfilePointCountIgnoresCurvePrecision;
    [Test]
    procedure Frame_IsClosed;
    [Test]
    procedure Frame_BoxContainsEveryProfilePoint;
    [Test]
    procedure Frame_Assign_FromEllipse_CopiesTheCorners;
    [Test]
    procedure Frame_Assign_IsIndependent;
    [Test]
    procedure Frame_OnMe_PointOnAnEdge_ReturnsOnObject;
    [Test]
    procedure Frame_OnMe_InteriorPoint_ReturnsInBBox;

    [Test]
    procedure Rectangle_OnMe_InteriorPoint_ReturnsInObject;
    [Test]
    procedure Rectangle_OnMe_PointOnAControlPoint_ReturnsIndex;
  end;

  { ================================================================= }
  { TArc2D / TEllipse2D / TFilledEllipse2D }
  { ================================================================= }
  [TestFixture]
  TArcEllipseTests = class(TObject)
  private
    FArc: TArc2D;
    FEllipse: TEllipse2D;
    FFilled: TFilledEllipse2D;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Arc_Construction_FourControlPoints;
    [Test]
    procedure Arc_Construction_DefaultDirectionIsClockwise;
    [Test]
    procedure Arc_ProfileCountIsCurvePrecisionPlusOne;
    [Test]
    procedure Arc_BoxContainsEveryProfilePoint;
    [Test]
    procedure Arc_ChangingDirection_KeepsTheProfileCount;
    [Test]
    procedure Arc_Assign_CopiesAnglesDirectionAndPoints;

    [Test]
    procedure Ellipse_Construction_TwoControlPoints;
    [Test]
    procedure Ellipse_BoxIsTheControlPointBox;
    [Test]
    procedure Ellipse_ProfileCountIsCurvePrecisionPlusOne;
    [Test]
    procedure Ellipse_ProfileStartsAndEndsAtTheRightmostPoint;
    [Test]
    procedure Ellipse_BoxContainsEveryProfilePoint;
    [Test]
    procedure Ellipse_Assign_FromFrame_CopiesTheCorners;

    [Test]
    procedure FilledEllipse_OnMe_CentrePoint_ReturnsInObject;
    [Test]
    procedure FilledEllipse_OnMe_CornerOfTheBox_ReturnsInBBox;
    [Test]
    procedure FilledEllipse_OnMe_FarPoint_ReturnsNoObject;
  end;

  { ================================================================= }
  { TBSpline2D }
  { ================================================================= }
  [TestFixture]
  TBSpline2DTests = class(TObject)
  private
    FSpline: TBSpline2D;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Construction_ControlPointsAndDefaults;
    [Test]
    procedure Construction_GrowingIsEnabled;
    [Test]
    procedure ProfileCountIsCurvePrecisionPlusOne;
    [Test]
    procedure ProfileInterpolatesTheFirstAndLastControlPoints;
    [Test]
    procedure BoxLiesInsideTheControlPolygonBox;
    [Test]
    procedure FewerControlPointsThanOrder_ProfileEqualsControlPoints;
    [Test]
    procedure Assign_CopiesOrderAndPointsAndIsIndependent;
  end;

  { ================================================================= }
  { TCurve2D protocol: BeginUseProfilePoints / SavingType / CurvePrecision }
  { ================================================================= }
  [TestFixture]
  TCurveProfileProtocolTests = class(TObject)
  private
    FEllipse: TEllipse2D;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure StTime_KeepsTheProfileCachedOutsideBeginEnd;
    [Test]
    procedure StSpace_ProfilePointsRaiseOutsideBeginEnd;
    [Test]
    procedure StSpace_NumberOfProfilePtsRaisesOutsideBeginEnd;
    [Test]
    procedure StSpace_ProfileValidBetweenBeginAndEnd;
    [Test]
    procedure StSpace_NestedBeginEndPairsStayBalanced;
    [Test]
    procedure StSpace_ProfileInvalidAgainAfterEnd;
    [Test]
    procedure SettingCurvePrecision_InvalidatesTheFlattenedProfile;
    [Test]
    procedure SettingCurvePrecisionToZero_ClearsBoxAndDropsTheProfile;
    [Test]
    procedure SwitchingSavingTypeBackAndForth_KeepsTheSameProfileCount;
  end;

  { ================================================================= }
  { TText2D }
  { ================================================================= }
  [TestFixture]
  TText2DTests = class(TObject)
  private
    FText: TText2D;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Construction_TwoControlPointsFromTheRectangle;
    [Test]
    procedure Construction_TextHeightAndDefaults;
    [Test]
    procedure Construction_BoxIsTheGivenRectangle;
    [Test]
    procedure Construction_LogFontIsCreated;
    [Test]
    procedure Assign_CopiesTextAndGeometryAndIsIndependent;
    [Test]
    procedure Assign_FromFrame_CopiesOnlyTheCorners;
    [Test]
    procedure OnMe_PointInsideTheBox_ReturnsInObject;
    [Test]
    procedure OnMe_PointOutsideTheBox_ReturnsNoObject;
    [Test]
    procedure OnMe_PointOnAControlPoint_ReturnsIndex;
  end;

  { ================================================================= }
  { TJustifiedVectText2D }
  { ================================================================= }
  [TestFixture]
  TJustifiedVectText2DTests = class(TObject)
  private
    FFont: TVectFont;
    FText: TJustifiedVectText2D;
    procedure BuildFont;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Font_GlyphExtensionIsTheUnionOfItsSubVectors;
    [Test]
    procedure Font_GetTextExtension_SingleGlyph;
    [Test]
    procedure Construction_TwoControlPointsFromTheTextBox;
    [Test]
    procedure Construction_Defaults;
    [Test]
    procedure Construction_BoxIsTheJustifiedTextExtension;
    [Test]
    procedure SettingText_RecomputesTheBox;
    [Test]
    procedure SettingHeight_RecomputesTheBox;
    [Test]
    procedure RightBottomJustification_MovesTheBox;
    [Test]
    procedure Transform_MovesTheBox;
    [Test]
    procedure Assign_CopiesEverythingAndIsIndependent;
    [Test]
    procedure OnMe_PointInsideTheTextExtension_ReturnsInObject;
    [Test]
    procedure OnMe_PointInTheTextBoxButOutsideTheText_ReturnsNoObject;
  end;

implementation

const
  { Typed constants, so every Assert.AreEqual below passes three Double
    arguments and binds unambiguously to the Double overload.
    TOL_EXACT for values that are only stored and copied, TOL_TRIG for
    anything that has been through trigonometry or a transform. }
  TOL_EXACT: Double = 1E-9;
  TOL_TRIG: Double = 1E-6;

{ Runs AProc and returns the class name of whatever escapes it, or '' when
  nothing does. Used to pin down the exact exception class raised by the
  profile-point protocol. }
function CapturedExceptionClass(const AProc: TProc): string;
begin
  Result := '';
  try
    AProc();
  except
    on E: Exception do
      Result := E.ClassName;
  end;
end;

{ ===================================================================== }
{ TLine2DTests }
{ ===================================================================== }

procedure TLine2DTests.Setup;
begin
  FLine := TLine2D.Create(101, Point2D(0.0, 0.0), Point2D(10.0, 0.0));
end;

procedure TLine2DTests.TearDown;
begin
  FreeAndNil(FLine);
end;

procedure TLine2DTests.Construction_HasTwoControlPoints;
begin
  Assert.AreEqual(2, Integer(FLine.Points.Count));
  Assert.AreEqual(101, Integer(FLine.ID));
end;

procedure TLine2DTests.Construction_ControlPointsAreTheEndPoints;
begin
  Assert.AreEqual(0.0, FLine.Points[0].X, TOL_EXACT);
  Assert.AreEqual(0.0, FLine.Points[0].Y, TOL_EXACT);
  Assert.AreEqual(10.0, FLine.Points[1].X, TOL_EXACT);
  Assert.AreEqual(0.0, FLine.Points[1].Y, TOL_EXACT);
end;

procedure TLine2DTests.Construction_GrowingIsDisabled;
begin
  Assert.IsFalse(FLine.Points.GrowingEnabled,
    'TLine2D.Create disables growing on its two-point set');
end;

procedure TLine2DTests.Construction_BoxIsTheSegmentExtension;
begin
  Assert.AreEqual(0.0, FLine.Box.Left, TOL_EXACT);
  Assert.AreEqual(0.0, FLine.Box.Bottom, TOL_EXACT);
  Assert.AreEqual(10.0, FLine.Box.Right, TOL_EXACT);
  Assert.AreEqual(0.0, FLine.Box.Top, TOL_EXACT);
end;

procedure TLine2DTests.MovingAControlPoint_UpdatesTheBox;
begin
  { Writing through Points[] fires OnChange, which is wired to
    UpdateExtension in TPrimitive2D.Create. }
  FLine.Points[1] := Point2D(0.0, 20.0);
  Assert.AreEqual(0.0, FLine.Box.Left, TOL_EXACT);
  Assert.AreEqual(0.0, FLine.Box.Bottom, TOL_EXACT);
  Assert.AreEqual(0.0, FLine.Box.Right, TOL_EXACT);
  Assert.AreEqual(20.0, FLine.Box.Top, TOL_EXACT);
end;

procedure TLine2DTests.Transform_MovesTheBoxButNotTheControlPoints;
begin
  Assert.IsFalse(FLine.HasTransform, 'a freshly built line has no transform');
  FLine.Transform(Translate2D(5.0, 3.0));
  Assert.IsTrue(FLine.HasTransform);

  { The control points live in model space and must not move. }
  Assert.AreEqual(0.0, FLine.Points[0].X, TOL_EXACT);
  Assert.AreEqual(0.0, FLine.Points[0].Y, TOL_EXACT);

  { The bounding box is in world space and must move. }
  Assert.AreEqual(5.0, FLine.Box.Left, TOL_TRIG);
  Assert.AreEqual(3.0, FLine.Box.Bottom, TOL_TRIG);
  Assert.AreEqual(15.0, FLine.Box.Right, TOL_TRIG);
  Assert.AreEqual(3.0, FLine.Box.Top, TOL_TRIG);
end;

procedure TLine2DTests.RemoveTransform_RestoresTheOriginalBox;
begin
  FLine.Transform(Translate2D(5.0, 3.0));
  FLine.RemoveTransform;
  Assert.IsFalse(FLine.HasTransform);
  Assert.AreEqual(0.0, FLine.Box.Left, TOL_TRIG);
  Assert.AreEqual(10.0, FLine.Box.Right, TOL_TRIG);
end;

procedure TLine2DTests.MoveTo_TranslatesTheBox;
begin
  { Drag the point currently at (0,0) onto (4,4). }
  FLine.MoveTo(Point2D(4.0, 4.0), Point2D(0.0, 0.0));
  Assert.AreEqual(4.0, FLine.Box.Left, TOL_TRIG);
  Assert.AreEqual(4.0, FLine.Box.Bottom, TOL_TRIG);
  Assert.AreEqual(14.0, FLine.Box.Right, TOL_TRIG);
  Assert.AreEqual(4.0, FLine.Box.Top, TOL_TRIG);
end;

procedure TLine2DTests.Assign_CopiesGeometryAndIsIndependent;
var
  Dup: TLine2D;
begin
  Dup := TLine2D.Create(202, Point2D(1.0, 1.0), Point2D(2.0, 2.0));
  try
    Dup.Assign(FLine);
    Assert.AreEqual(2, Integer(Dup.Points.Count));
    Assert.AreEqual(0.0, Dup.Points[0].X, TOL_EXACT);
    Assert.AreEqual(10.0, Dup.Points[1].X, TOL_EXACT);
    Assert.AreEqual(10.0, Dup.Box.Right, TOL_EXACT);

    { Mutate the source: the copy must not follow. }
    FLine.Points[1] := Point2D(999.0, 999.0);
    Assert.AreEqual(10.0, Dup.Points[1].X, TOL_EXACT);
    Assert.AreEqual(0.0, Dup.Points[1].Y, TOL_EXACT);
    Assert.AreEqual(10.0, Dup.Box.Right, TOL_EXACT);
  finally
    Dup.Free;
  end;
end;

procedure TLine2DTests.Assign_DoesNotCopyTheID;
var
  Dup: TLine2D;
begin
  Dup := TLine2D.Create(202, Point2D(1.0, 1.0), Point2D(2.0, 2.0));
  try
    Dup.Assign(FLine);
    { TGraphicObject.Assign copies Visible/Enabled/ToBeSaved only. }
    Assert.AreEqual(202, Integer(Dup.ID));
  finally
    Dup.Free;
  end;
end;

procedure TLine2DTests.OnMe_PointOnTheSegment_ReturnsOnObject;
var
  Dist: TRealType;
  Res: Integer;
begin
  Dist := 0.0;
  Res := FLine.OnMe(Point2D(5.0, 0.0), 0.5, Dist);
  Assert.AreEqual(PICK_ONOBJECT, Res);
  Assert.AreEqual(0.0, Dist, TOL_TRIG);
end;

procedure TLine2DTests.OnMe_PointFarAway_ReturnsNoObject;
var
  Dist: TRealType;
  Res: Integer;
begin
  Dist := 0.0;
  Res := FLine.OnMe(Point2D(5.0, 50.0), 0.5, Dist);
  Assert.AreEqual(PICK_NOOBJECT, Res);
end;

procedure TLine2DTests.OnMe_PointOnAControlPoint_ReturnsTheControlPointIndex;
var
  Dist: TRealType;
  Res: Integer;
begin
  { TPrimitive2DHandler.OnMe returns the zero-based control point index, which
    is >= 0 and therefore beats every negative PICK_* constant in MaxIntValue
    inside TObject2D.OnMe. }
  Dist := 0.0;
  Res := FLine.OnMe(Point2D(10.0, 0.0), 0.5, Dist);
  Assert.AreEqual(1, Res, 'expected the index of the second control point');
  Assert.AreEqual(0.0, Dist, TOL_TRIG);
end;

procedure TLine2DTests.OnMe_DisabledObject_ReturnsNoObject;
var
  Dist: TRealType;
  Res: Integer;
begin
  FLine.Enabled := False;
  Dist := 0.0;
  Res := FLine.OnMe(Point2D(5.0, 0.0), 0.5, Dist);
  Assert.AreEqual(PICK_NOOBJECT, Res);
end;

{ ===================================================================== }
{ TPolyOutlineTests }
{ ===================================================================== }

procedure TPolyOutlineTests.Setup;
begin
  FPolyline := TPolyline2D.Create(301, [Point2D(0.0, 0.0), Point2D(10.0, 0.0),
    Point2D(10.0, 10.0)]);
  FPolygon := TPolygon2D.Create(302, [Point2D(0.0, 0.0), Point2D(10.0, 0.0),
    Point2D(10.0, 10.0), Point2D(0.0, 10.0)]);
end;

procedure TPolyOutlineTests.TearDown;
begin
  FreeAndNil(FPolyline);
  FreeAndNil(FPolygon);
end;

procedure TPolyOutlineTests.Polyline_Construction_PointCountMatchesTheArray;
begin
  Assert.AreEqual(3, Integer(FPolyline.Points.Count));
  Assert.AreEqual(4, Integer(FPolygon.Points.Count));
end;

procedure TPolyOutlineTests.Polyline_Construction_GrowingIsEnabled;
begin
  Assert.IsTrue(FPolyline.Points.GrowingEnabled);
  FPolyline.Points.Add(Point2D(0.0, 10.0));
  Assert.AreEqual(4, Integer(FPolyline.Points.Count));
  Assert.AreEqual(10.0, FPolyline.Box.Top, TOL_EXACT);
end;

procedure TPolyOutlineTests.Polyline_ProfilePointsAreTheControlPoints;
begin
  { For an outline the profile points and the control points are literally the
    same set object (FNCCS4Shapes.pas:3658). }
  Assert.IsTrue(FPolyline.ProfilePoints = FPolyline.Points);
  Assert.AreEqual(3, FPolyline.NumberOfProfilePts);
end;

procedure TPolyOutlineTests.Polyline_ProfileReadableWithoutBeginUse;
begin
  { TOutline2D.BeginUse/EndUseProfilePoints are deliberate no-ops, so unlike a
    TCurve2D the profile of an outline is always readable - but the calls must
    still balance for callers that do not know the concrete class. }
  Assert.AreEqual(3, FPolyline.NumberOfProfilePts);
  FPolyline.BeginUseProfilePoints;
  try
    Assert.AreEqual(3, FPolyline.NumberOfProfilePts);
  finally
    FPolyline.EndUseProfilePoints;
  end;
  Assert.AreEqual(3, FPolyline.NumberOfProfilePts);
end;

procedure TPolyOutlineTests.Polyline_Box;
begin
  Assert.AreEqual(0.0, FPolyline.Box.Left, TOL_EXACT);
  Assert.AreEqual(0.0, FPolyline.Box.Bottom, TOL_EXACT);
  Assert.AreEqual(10.0, FPolyline.Box.Right, TOL_EXACT);
  Assert.AreEqual(10.0, FPolyline.Box.Top, TOL_EXACT);
end;

procedure TPolyOutlineTests.Polyline_IsClosed_FalseForOpenPolyline;
begin
  Assert.IsFalse(FPolyline.IsClosed);
end;

procedure TPolyOutlineTests.Polyline_IsClosed_TrueWhenLastEqualsFirst;
begin
  FPolyline.Points.Add(Point2D(0.0, 0.0));
  Assert.IsTrue(FPolyline.IsClosed);
end;

procedure TPolyOutlineTests.Polyline_Assign_CopiesAllPointsAndIsIndependent;
var
  Dup: TPolyline2D;
begin
  Dup := TPolyline2D.Create(303, [Point2D(0.0, 0.0)]);
  try
    Dup.Assign(FPolyline);
    Assert.AreEqual(3, Integer(Dup.Points.Count));
    Assert.AreEqual(10.0, Dup.Points[2].X, TOL_EXACT);
    Assert.AreEqual(10.0, Dup.Points[2].Y, TOL_EXACT);
    Assert.IsTrue(Dup.Points.GrowingEnabled);

    FPolyline.Points[2] := Point2D(-50.0, -50.0);
    Assert.AreEqual(10.0, Dup.Points[2].X, TOL_EXACT);
    Assert.AreEqual(10.0, Dup.Box.Top, TOL_EXACT);
  finally
    Dup.Free;
  end;
end;

procedure TPolyOutlineTests.Polyline_OnMe_PointOnASegment_ReturnsOnObject;
var
  Dist: TRealType;
  Res: Integer;
begin
  Dist := 0.0;
  Res := FPolyline.OnMe(Point2D(5.0, 0.0), 0.2, Dist);
  Assert.AreEqual(PICK_ONOBJECT, Res);
end;

procedure TPolyOutlineTests.Polyline_OnMe_PointInsideButOffTheOutline_ReturnsInBBox;
var
  Dist: TRealType;
  Res: Integer;
begin
  { (2,7) sits inside the bounding box but far from both segments and from
    every control point, so only the bounding-box hit survives. }
  Dist := 0.0;
  Res := FPolyline.OnMe(Point2D(2.0, 7.0), 0.2, Dist);
  Assert.AreEqual(PICK_INBBOX, Res);
end;

procedure TPolyOutlineTests.Polygon_IsClosed_IsAlwaysTrue;
begin
  Assert.IsTrue(FPolygon.IsClosed,
    'TPolygon2D.GetIsClosed is hard-wired to True');
end;

procedure TPolyOutlineTests.Polygon_OnMe_InteriorPoint_ReturnsInObject;
var
  Dist: TRealType;
  Res: Integer;
begin
  Dist := 0.0;
  Res := FPolygon.OnMe(Point2D(5.0, 5.0), 0.1, Dist);
  Assert.AreEqual(PICK_INOBJECT, Res);
end;

procedure TPolyOutlineTests.Polygon_OnMe_PointOnAnEdge_ReturnsOnObject;
var
  Dist: TRealType;
  Res: Integer;
begin
  Dist := 0.0;
  Res := FPolygon.OnMe(Point2D(5.0, 0.0), 0.5, Dist);
  Assert.AreEqual(PICK_ONOBJECT, Res);
end;

procedure TPolyOutlineTests.Polygon_OnMe_PointOutsideTheBox_ReturnsNoObject;
var
  Dist: TRealType;
  Res: Integer;
begin
  Dist := 0.0;
  Res := FPolygon.OnMe(Point2D(-40.0, -40.0), 0.1, Dist);
  Assert.AreEqual(PICK_NOOBJECT, Res);
end;

{ ===================================================================== }
{ TFrameRectangleTests }
{ ===================================================================== }

procedure TFrameRectangleTests.Setup;
begin
  FFrame := TFrame2D.Create(401, Point2D(0.0, 0.0), Point2D(10.0, 5.0));
  FRect := TRectangle2D.Create(402, Point2D(0.0, 0.0), Point2D(10.0, 5.0));
end;

procedure TFrameRectangleTests.TearDown;
begin
  FreeAndNil(FFrame);
  FreeAndNil(FRect);
end;

procedure TFrameRectangleTests.Frame_Construction_TwoControlPointsNoGrowing;
begin
  Assert.AreEqual(2, Integer(FFrame.Points.Count));
  Assert.IsFalse(FFrame.Points.GrowingEnabled);
  { TRectangle2D adds no constructor of its own. }
  Assert.AreEqual(2, Integer(FRect.Points.Count));
end;

procedure TFrameRectangleTests.Frame_Construction_DefaultCurvePrecisionAndSavingType;
begin
  { TFrame2D.Create passes 50 to TCurve2D.Create, which defaults to stTime. }
  Assert.AreEqual(50, Integer(FFrame.CurvePrecision));
  Assert.IsTrue(FFrame.SavingType = stTime);
end;

procedure TFrameRectangleTests.Frame_Box;
begin
  Assert.AreEqual(0.0, FFrame.Box.Left, TOL_EXACT);
  Assert.AreEqual(0.0, FFrame.Box.Bottom, TOL_EXACT);
  Assert.AreEqual(10.0, FFrame.Box.Right, TOL_EXACT);
  Assert.AreEqual(5.0, FFrame.Box.Top, TOL_EXACT);
end;

procedure TFrameRectangleTests.Frame_ProfileIsAlwaysFiveClosedPoints;
begin
  FFrame.BeginUseProfilePoints;
  try
    Assert.AreEqual(5, FFrame.NumberOfProfilePts);
    { P0, (P0.X,P1.Y), P1, (P1.X,P0.Y), P0 }
    Assert.AreEqual(0.0, FFrame.ProfilePoints[0].X, TOL_EXACT);
    Assert.AreEqual(0.0, FFrame.ProfilePoints[0].Y, TOL_EXACT);
    Assert.AreEqual(0.0, FFrame.ProfilePoints[1].X, TOL_EXACT);
    Assert.AreEqual(5.0, FFrame.ProfilePoints[1].Y, TOL_EXACT);
    Assert.AreEqual(10.0, FFrame.ProfilePoints[2].X, TOL_EXACT);
    Assert.AreEqual(5.0, FFrame.ProfilePoints[2].Y, TOL_EXACT);
    Assert.AreEqual(10.0, FFrame.ProfilePoints[3].X, TOL_EXACT);
    Assert.AreEqual(0.0, FFrame.ProfilePoints[3].Y, TOL_EXACT);
    Assert.AreEqual(0.0, FFrame.ProfilePoints[4].X, TOL_EXACT);
    Assert.AreEqual(0.0, FFrame.ProfilePoints[4].Y, TOL_EXACT);
  finally
    FFrame.EndUseProfilePoints;
  end;
end;

procedure TFrameRectangleTests.Frame_ProfilePointCountIgnoresCurvePrecision;
begin
  { A frame is flat by construction, so its profile is five points whatever the
    precision is - unlike an arc, an ellipse or a spline. }
  FFrame.CurvePrecision := 7;
  Assert.AreEqual(7, Integer(FFrame.CurvePrecision));
  FFrame.BeginUseProfilePoints;
  try
    Assert.AreEqual(5, FFrame.NumberOfProfilePts);
  finally
    FFrame.EndUseProfilePoints;
  end;
end;

procedure TFrameRectangleTests.Frame_IsClosed;
begin
  Assert.IsTrue(FFrame.IsClosed,
    'the frame profile repeats its first point at the end');
end;

procedure TFrameRectangleTests.Frame_BoxContainsEveryProfilePoint;
var
  I: Integer;
begin
  FFrame.BeginUseProfilePoints;
  try
    for I := 0 to FFrame.NumberOfProfilePts - 1 do
      Assert.IsTrue(IsPointInBox2D(FFrame.ProfilePoints[I], FFrame.Box),
        'profile point ' + IntToStr(I) + ' escapes the bounding box');
  finally
    FFrame.EndUseProfilePoints;
  end;
end;

procedure TFrameRectangleTests.Frame_Assign_FromEllipse_CopiesTheCorners;
var
  Ell: TEllipse2D;
begin
  { TFrame2D.Assign accepts a frame, an ellipse or an arc and takes the two
    corner points from it. }
  Ell := TEllipse2D.Create(403, Point2D(-2.0, -3.0), Point2D(4.0, 6.0));
  try
    FFrame.Assign(Ell);
    Assert.AreEqual(2, Integer(FFrame.Points.Count));
    Assert.AreEqual(-2.0, FFrame.Points[0].X, TOL_EXACT);
    Assert.AreEqual(-3.0, FFrame.Points[0].Y, TOL_EXACT);
    Assert.AreEqual(4.0, FFrame.Points[1].X, TOL_EXACT);
    Assert.AreEqual(6.0, FFrame.Points[1].Y, TOL_EXACT);
    Assert.AreEqual(-2.0, FFrame.Box.Left, TOL_EXACT);
    Assert.AreEqual(6.0, FFrame.Box.Top, TOL_EXACT);
  finally
    Ell.Free;
  end;
end;

procedure TFrameRectangleTests.Frame_Assign_IsIndependent;
var
  Dup: TFrame2D;
begin
  Dup := TFrame2D.Create(404, Point2D(1.0, 1.0), Point2D(2.0, 2.0));
  try
    Dup.Assign(FFrame);
    Assert.AreEqual(10.0, Dup.Points[1].X, TOL_EXACT);
    Assert.AreEqual(50, Integer(Dup.CurvePrecision));

    FFrame.Points[1] := Point2D(1000.0, 1000.0);
    Assert.AreEqual(10.0, Dup.Points[1].X, TOL_EXACT);
    Assert.AreEqual(10.0, Dup.Box.Right, TOL_EXACT);
  finally
    Dup.Free;
  end;
end;

procedure TFrameRectangleTests.Frame_OnMe_PointOnAnEdge_ReturnsOnObject;
var
  Dist: TRealType;
  Res: Integer;
begin
  Dist := 0.0;
  Res := FFrame.OnMe(Point2D(5.0, 0.0), 0.2, Dist);
  Assert.AreEqual(PICK_ONOBJECT, Res);
end;

procedure TFrameRectangleTests.Frame_OnMe_InteriorPoint_ReturnsInBBox;
var
  Dist: TRealType;
  Res: Integer;
begin
  { A frame is an outline, not a filled shape: its interior is not "on" it. }
  Dist := 0.0;
  Res := FFrame.OnMe(Point2D(5.0, 2.5), 0.2, Dist);
  Assert.AreEqual(PICK_INBBOX, Res);
end;

procedure TFrameRectangleTests.Rectangle_OnMe_InteriorPoint_ReturnsInObject;
var
  Dist: TRealType;
  Res: Integer;
begin
  { TRectangle2D is the filled variant and does pick its interior. }
  Dist := 0.0;
  Res := FRect.OnMe(Point2D(5.0, 2.5), 0.2, Dist);
  Assert.AreEqual(PICK_INOBJECT, Res);
end;

procedure TFrameRectangleTests.Rectangle_OnMe_PointOnAControlPoint_ReturnsIndex;
var
  Dist: TRealType;
  Res: Integer;
begin
  Dist := 0.0;
  Res := FRect.OnMe(Point2D(10.0, 5.0), 0.3, Dist);
  Assert.AreEqual(1, Res, 'expected the index of the second corner');
end;

{ ===================================================================== }
{ TArcEllipseTests }
{ ===================================================================== }

procedure TArcEllipseTests.Setup;
begin
  FArc := TArc2D.Create(501, Point2D(-10.0, -10.0), Point2D(10.0, 10.0),
    Pi / 6.0, Pi / 2.0);
  FEllipse := TEllipse2D.Create(502, Point2D(0.0, 0.0), Point2D(10.0, 6.0));
  FFilled := TFilledEllipse2D.Create(503, Point2D(0.0, 0.0),
    Point2D(10.0, 6.0));
end;

procedure TArcEllipseTests.TearDown;
begin
  FreeAndNil(FArc);
  FreeAndNil(FEllipse);
  FreeAndNil(FFilled);
end;

procedure TArcEllipseTests.Arc_Construction_FourControlPoints;
begin
  { P1 and P2 are the corners of the arc's ellipse box; the third and fourth
    control points carry the start and the end angle. }
  Assert.AreEqual(4, Integer(FArc.Points.Count));
  Assert.IsFalse(FArc.Points.GrowingEnabled);
  Assert.AreEqual(-10.0, FArc.Points[0].X, TOL_EXACT);
  Assert.AreEqual(10.0, FArc.Points[1].Y, TOL_EXACT);
  Assert.AreEqual(50, Integer(FArc.CurvePrecision));
end;

procedure TArcEllipseTests.Arc_Construction_DefaultDirectionIsClockwise;
begin
  Assert.IsTrue(FArc.Direction = adClockwise);
end;

procedure TArcEllipseTests.Arc_ProfileCountIsCurvePrecisionPlusOne;
begin
  { TArc2D.PopulateCurvePoints emits CurvePrecision interior samples plus the
    explicit end point. }
  FArc.BeginUseProfilePoints;
  try
    Assert.AreEqual(51, FArc.NumberOfProfilePts);
  finally
    FArc.EndUseProfilePoints;
  end;

  FArc.CurvePrecision := 12;
  FArc.BeginUseProfilePoints;
  try
    Assert.AreEqual(13, FArc.NumberOfProfilePts);
  finally
    FArc.EndUseProfilePoints;
  end;
end;

procedure TArcEllipseTests.Arc_BoxContainsEveryProfilePoint;
var
  I: Integer;
begin
  FArc.BeginUseProfilePoints;
  try
    Assert.IsTrue(FArc.NumberOfProfilePts > 2);
    for I := 0 to FArc.NumberOfProfilePts - 1 do
      Assert.IsTrue(IsPointInBox2D(FArc.ProfilePoints[I], FArc.Box),
        'arc profile point ' + IntToStr(I) + ' escapes the bounding box');
  finally
    FArc.EndUseProfilePoints;
  end;
end;

procedure TArcEllipseTests.Arc_ChangingDirection_KeepsTheProfileCount;
begin
  FArc.Direction := adCounterClockwise;
  Assert.IsTrue(FArc.Direction = adCounterClockwise);
  FArc.BeginUseProfilePoints;
  try
    Assert.AreEqual(51, FArc.NumberOfProfilePts);
  finally
    FArc.EndUseProfilePoints;
  end;
end;

procedure TArcEllipseTests.Arc_Assign_CopiesAnglesDirectionAndPoints;
var
  Dup: TArc2D;
  SrcStart, SrcEnd: TRealType;
begin
  FArc.Direction := adCounterClockwise;
  { Read the angles back after the last _UpdateExtension: TArc2D recomputes
    them from control points 2 and 3 every time it repopulates. }
  SrcStart := FArc.StartAngle;
  SrcEnd := FArc.EndAngle;

  Dup := TArc2D.Create(504, Point2D(0.0, 0.0), Point2D(1.0, 1.0), 0.0,
    Pi / 4.0);
  try
    Dup.Assign(FArc);
    Assert.AreEqual(4, Integer(Dup.Points.Count));
    Assert.IsTrue(Dup.Direction = adCounterClockwise);
    Assert.AreEqual(SrcStart, Dup.StartAngle, TOL_TRIG);
    Assert.AreEqual(SrcEnd, Dup.EndAngle, TOL_TRIG);
    Assert.AreEqual(-10.0, Dup.Points[0].X, TOL_EXACT);
    Assert.AreEqual(10.0, Dup.Points[1].X, TOL_EXACT);

    FArc.Points[0] := Point2D(-100.0, -100.0);
    Assert.AreEqual(-10.0, Dup.Points[0].X, TOL_EXACT);
  finally
    Dup.Free;
  end;
end;

procedure TArcEllipseTests.Ellipse_Construction_TwoControlPoints;
begin
  Assert.AreEqual(2, Integer(FEllipse.Points.Count));
  Assert.IsFalse(FEllipse.Points.GrowingEnabled);
  Assert.AreEqual(50, Integer(FEllipse.CurvePrecision));
  Assert.IsTrue(FEllipse.SavingType = stTime);
end;

procedure TArcEllipseTests.Ellipse_BoxIsTheControlPointBox;
begin
  { TEllipse2D.PopulateCurvePoints returns the extension of the CONTROL points,
    not of the flattened profile (FNCCS4Shapes.pas:4225). }
  Assert.AreEqual(0.0, FEllipse.Box.Left, TOL_EXACT);
  Assert.AreEqual(0.0, FEllipse.Box.Bottom, TOL_EXACT);
  Assert.AreEqual(10.0, FEllipse.Box.Right, TOL_EXACT);
  Assert.AreEqual(6.0, FEllipse.Box.Top, TOL_EXACT);
end;

procedure TArcEllipseTests.Ellipse_ProfileCountIsCurvePrecisionPlusOne;
begin
  FEllipse.BeginUseProfilePoints;
  try
    Assert.AreEqual(51, FEllipse.NumberOfProfilePts);
  finally
    FEllipse.EndUseProfilePoints;
  end;
end;

procedure TArcEllipseTests.Ellipse_ProfileStartsAndEndsAtTheRightmostPoint;
var
  N: Integer;
begin
  FEllipse.BeginUseProfilePoints;
  try
    N := FEllipse.NumberOfProfilePts;
    { Centre (5,3), RX = 5: the profile opens and closes at (CX+RX, CY). }
    Assert.AreEqual(10.0, FEllipse.ProfilePoints[0].X, TOL_TRIG);
    Assert.AreEqual(3.0, FEllipse.ProfilePoints[0].Y, TOL_TRIG);
    Assert.AreEqual(10.0, FEllipse.ProfilePoints[N - 1].X, TOL_TRIG);
    Assert.AreEqual(3.0, FEllipse.ProfilePoints[N - 1].Y, TOL_TRIG);
  finally
    FEllipse.EndUseProfilePoints;
  end;
end;

procedure TArcEllipseTests.Ellipse_BoxContainsEveryProfilePoint;
var
  I: Integer;
begin
  FEllipse.BeginUseProfilePoints;
  try
    for I := 0 to FEllipse.NumberOfProfilePts - 1 do
      Assert.IsTrue(IsPointInBox2D(FEllipse.ProfilePoints[I], FEllipse.Box),
        'ellipse profile point ' + IntToStr(I) + ' escapes the bounding box');
  finally
    FEllipse.EndUseProfilePoints;
  end;
end;

procedure TArcEllipseTests.Ellipse_Assign_FromFrame_CopiesTheCorners;
var
  Frm: TFrame2D;
begin
  Frm := TFrame2D.Create(505, Point2D(1.0, 2.0), Point2D(3.0, 8.0));
  try
    FEllipse.Assign(Frm);
    Assert.AreEqual(2, Integer(FEllipse.Points.Count));
    Assert.AreEqual(1.0, FEllipse.Points[0].X, TOL_EXACT);
    Assert.AreEqual(8.0, FEllipse.Points[1].Y, TOL_EXACT);
    Assert.AreEqual(1.0, FEllipse.Box.Left, TOL_EXACT);
    Assert.AreEqual(8.0, FEllipse.Box.Top, TOL_EXACT);

    Frm.Points[0] := Point2D(-77.0, -77.0);
    Assert.AreEqual(1.0, FEllipse.Points[0].X, TOL_EXACT);
  finally
    Frm.Free;
  end;
end;

procedure TArcEllipseTests.FilledEllipse_OnMe_CentrePoint_ReturnsInObject;
var
  Dist: TRealType;
  Res: Integer;
begin
  Dist := 0.0;
  Res := FFilled.OnMe(Point2D(5.0, 3.0), 0.2, Dist);
  Assert.AreEqual(PICK_INOBJECT, Res);
end;

procedure TArcEllipseTests.FilledEllipse_OnMe_CornerOfTheBox_ReturnsInBBox;
var
  Dist: TRealType;
  Res: Integer;
begin
  { (0.2, 0.2) is inside the axis-aligned box but comfortably outside the
    ellipse and more than one aperture away from the (0,0) control point. }
  Dist := 0.0;
  Res := FFilled.OnMe(Point2D(0.2, 0.2), 0.1, Dist);
  Assert.AreEqual(PICK_INBBOX, Res);
end;

procedure TArcEllipseTests.FilledEllipse_OnMe_FarPoint_ReturnsNoObject;
var
  Dist: TRealType;
  Res: Integer;
begin
  Dist := 0.0;
  Res := FFilled.OnMe(Point2D(-50.0, -50.0), 0.1, Dist);
  Assert.AreEqual(PICK_NOOBJECT, Res);
end;

{ ===================================================================== }
{ TBSpline2DTests }
{ ===================================================================== }

procedure TBSpline2DTests.Setup;
begin
  FSpline := TBSpline2D.Create(601, [Point2D(0.0, 0.0), Point2D(5.0, 10.0),
    Point2D(10.0, 0.0), Point2D(15.0, 10.0)]);
end;

procedure TBSpline2DTests.TearDown;
begin
  FreeAndNil(FSpline);
end;

procedure TBSpline2DTests.Construction_ControlPointsAndDefaults;
begin
  Assert.AreEqual(4, Integer(FSpline.Points.Count));
  Assert.AreEqual(3, Integer(FSpline.Order), 'the default spline is cubic');
  Assert.AreEqual(50, Integer(FSpline.CurvePrecision));
  Assert.IsTrue(FSpline.SavingType = stTime);
end;

procedure TBSpline2DTests.Construction_GrowingIsEnabled;
begin
  Assert.IsTrue(FSpline.Points.GrowingEnabled);
  FSpline.Points.Add(Point2D(20.0, 0.0));
  Assert.AreEqual(5, Integer(FSpline.Points.Count));
end;

procedure TBSpline2DTests.ProfileCountIsCurvePrecisionPlusOne;
begin
  FSpline.BeginUseProfilePoints;
  try
    Assert.AreEqual(51, FSpline.NumberOfProfilePts);
  finally
    FSpline.EndUseProfilePoints;
  end;
end;

procedure TBSpline2DTests.ProfileInterpolatesTheFirstAndLastControlPoints;
var
  N: Integer;
begin
  FSpline.BeginUseProfilePoints;
  try
    N := FSpline.NumberOfProfilePts;
    { An open uniform B-spline starts on its first control point... }
    Assert.AreEqual(FSpline.Points[0].X, FSpline.ProfilePoints[0].X, TOL_TRIG);
    Assert.AreEqual(FSpline.Points[0].Y, FSpline.ProfilePoints[0].Y, TOL_TRIG);
    { ...and PopulateCurvePoints appends the last control point verbatim. }
    Assert.AreEqual(FSpline.Points[3].X, FSpline.ProfilePoints[N - 1].X,
      TOL_EXACT);
    Assert.AreEqual(FSpline.Points[3].Y, FSpline.ProfilePoints[N - 1].Y,
      TOL_EXACT);
  finally
    FSpline.EndUseProfilePoints;
  end;
end;

procedure TBSpline2DTests.BoxLiesInsideTheControlPolygonBox;
begin
  { A B-spline never leaves the convex hull of its control points, so its box
    can never exceed the control point box (0,0)-(15,10). Asserting the
    invariant rather than a hand-computed flattening. }
  Assert.IsTrue(FSpline.Box.Left >= -TOL_TRIG, 'box left escapes the hull');
  Assert.IsTrue(FSpline.Box.Bottom >= -TOL_TRIG, 'box bottom escapes the hull');
  Assert.IsTrue(FSpline.Box.Right <= 15.0 + TOL_TRIG,
    'box right escapes the hull');
  Assert.IsTrue(FSpline.Box.Top <= 10.0 + TOL_TRIG, 'box top escapes the hull');
end;

procedure TBSpline2DTests.FewerControlPointsThanOrder_ProfileEqualsControlPoints;
var
  Small: TBSpline2D;
begin
  { With Points.Count < Order the curve degenerates into its control polygon
    (FNCCS4Shapes.pas:4360). }
  Small := TBSpline2D.Create(602, [Point2D(0.0, 0.0), Point2D(4.0, 4.0)]);
  try
    Assert.AreEqual(2, Integer(Small.Points.Count));
    Small.BeginUseProfilePoints;
    try
      Assert.AreEqual(2, Small.NumberOfProfilePts);
      Assert.AreEqual(0.0, Small.ProfilePoints[0].X, TOL_EXACT);
      Assert.AreEqual(4.0, Small.ProfilePoints[1].X, TOL_EXACT);
      Assert.AreEqual(4.0, Small.ProfilePoints[1].Y, TOL_EXACT);
    finally
      Small.EndUseProfilePoints;
    end;
  finally
    Small.Free;
  end;
end;

procedure TBSpline2DTests.Assign_CopiesOrderAndPointsAndIsIndependent;
var
  Dup: TBSpline2D;
begin
  FSpline.Order := 4;
  Dup := TBSpline2D.Create(603, [Point2D(0.0, 0.0)]);
  try
    Dup.Assign(FSpline);
    Assert.AreEqual(4, Integer(Dup.Order));
    Assert.AreEqual(4, Integer(Dup.Points.Count));
    Assert.AreEqual(15.0, Dup.Points[3].X, TOL_EXACT);
    Assert.AreEqual(10.0, Dup.Points[3].Y, TOL_EXACT);
    Assert.IsTrue(Dup.Points.GrowingEnabled);

    FSpline.Points[3] := Point2D(-1.0, -1.0);
    Assert.AreEqual(15.0, Dup.Points[3].X, TOL_EXACT);
  finally
    Dup.Free;
  end;
end;

{ ===================================================================== }
{ TCurveProfileProtocolTests }
{ ===================================================================== }

procedure TCurveProfileProtocolTests.Setup;
begin
  FEllipse := TEllipse2D.Create(701, Point2D(0.0, 0.0), Point2D(10.0, 6.0));
end;

procedure TCurveProfileProtocolTests.TearDown;
begin
  FreeAndNil(FEllipse);
end;

procedure TCurveProfileProtocolTests.StTime_KeepsTheProfileCachedOutsideBeginEnd;
begin
  { Under stTime (the default) the flattened profile is retained between uses,
    which is exactly the space/time trade-off the property documents. }
  Assert.IsTrue(FEllipse.SavingType = stTime);
  Assert.AreEqual(51, FEllipse.NumberOfProfilePts);
end;

procedure TCurveProfileProtocolTests.StSpace_ProfilePointsRaiseOutsideBeginEnd;
var
  ExcClass: string;
begin
  FEllipse.SavingType := stSpace;
  ExcClass := CapturedExceptionClass(
    procedure
    var
      P: TPoint2D;
    begin
      P := FEllipse.ProfilePoints[0];
      Assert.Fail('ProfilePoints outside Begin/End must raise; got X = ' +
        FloatToStr(P.X));
    end);
  Assert.IsTrue(ExcClass = 'ECADSysException',
    'expected ECADSysException, got: ' + ExcClass);
end;

procedure TCurveProfileProtocolTests.StSpace_NumberOfProfilePtsRaisesOutsideBeginEnd;
var
  ExcClass: string;
begin
  FEllipse.SavingType := stSpace;
  ExcClass := CapturedExceptionClass(
    procedure
    var
      N: Integer;
    begin
      N := FEllipse.NumberOfProfilePts;
      Assert.Fail('NumberOfProfilePts outside Begin/End must raise; got ' +
        IntToStr(N));
    end);
  Assert.IsTrue(ExcClass = 'ECADSysException',
    'expected ECADSysException, got: ' + ExcClass);
end;

procedure TCurveProfileProtocolTests.StSpace_ProfileValidBetweenBeginAndEnd;
begin
  FEllipse.SavingType := stSpace;
  FEllipse.BeginUseProfilePoints;
  try
    Assert.AreEqual(51, FEllipse.NumberOfProfilePts);
    Assert.AreEqual(10.0, FEllipse.ProfilePoints[0].X, TOL_TRIG);
    Assert.AreEqual(3.0, FEllipse.ProfilePoints[0].Y, TOL_TRIG);
  finally
    FEllipse.EndUseProfilePoints;
  end;
end;

procedure TCurveProfileProtocolTests.StSpace_NestedBeginEndPairsStayBalanced;
begin
  FEllipse.SavingType := stSpace;
  FEllipse.BeginUseProfilePoints;
  try
    FEllipse.BeginUseProfilePoints;
    try
      Assert.AreEqual(51, FEllipse.NumberOfProfilePts);
    finally
      FEllipse.EndUseProfilePoints;
    end;
    { The inner End must not drop the profile while the outer pair is open. }
    Assert.AreEqual(51, FEllipse.NumberOfProfilePts);
  finally
    FEllipse.EndUseProfilePoints;
  end;
end;

procedure TCurveProfileProtocolTests.StSpace_ProfileInvalidAgainAfterEnd;
var
  ExcClass: string;
begin
  FEllipse.SavingType := stSpace;
  FEllipse.BeginUseProfilePoints;
  try
    Assert.AreEqual(51, FEllipse.NumberOfProfilePts);
  finally
    FEllipse.EndUseProfilePoints;
  end;
  ExcClass := CapturedExceptionClass(
    procedure
    var
      N: Integer;
    begin
      N := FEllipse.NumberOfProfilePts;
      Assert.Fail('the profile must be released by EndUseProfilePoints; got ' +
        IntToStr(N));
    end);
  Assert.IsTrue(ExcClass = 'ECADSysException',
    'expected ECADSysException, got: ' + ExcClass);
end;

procedure TCurveProfileProtocolTests.SettingCurvePrecision_InvalidatesTheFlattenedProfile;
begin
  { CS4-FIX (P6): SetCurvePrecision now calls UpdateExtension, so the cached
    profile is rebuilt immediately instead of keeping the stale segment count
    until some unrelated edit happens to fire _UpdateExtension. }
  Assert.AreEqual(51, FEllipse.NumberOfProfilePts);

  FEllipse.CurvePrecision := 8;
  Assert.AreEqual(8, Integer(FEllipse.CurvePrecision));
  Assert.AreEqual(9, FEllipse.NumberOfProfilePts,
    'CurvePrecision must invalidate the cached profile straight away');

  FEllipse.CurvePrecision := 24;
  Assert.AreEqual(25, FEllipse.NumberOfProfilePts);
end;

procedure TCurveProfileProtocolTests.SettingCurvePrecisionToZero_ClearsBoxAndDropsTheProfile;
var
  ExcClass: string;
begin
  { Documents current behaviour: a zero precision makes PopulateCurvePoints
    bail out before allocating anything, so the box collapses to the origin and
    the profile becomes unreadable even under stTime. }
  FEllipse.CurvePrecision := 0;
  Assert.AreEqual(0.0, FEllipse.Box.Left, TOL_EXACT);
  Assert.AreEqual(0.0, FEllipse.Box.Bottom, TOL_EXACT);
  Assert.AreEqual(0.0, FEllipse.Box.Right, TOL_EXACT);
  Assert.AreEqual(0.0, FEllipse.Box.Top, TOL_EXACT);

  ExcClass := CapturedExceptionClass(
    procedure
    var
      N: Integer;
    begin
      N := FEllipse.NumberOfProfilePts;
      Assert.Fail('a zero CurvePrecision leaves no profile; got ' +
        IntToStr(N));
    end);
  Assert.IsTrue(ExcClass = 'ECADSysException',
    'expected ECADSysException, got: ' + ExcClass);
end;

procedure TCurveProfileProtocolTests.SwitchingSavingTypeBackAndForth_KeepsTheSameProfileCount;
begin
  FEllipse.SavingType := stSpace;
  FEllipse.BeginUseProfilePoints;
  try
    Assert.AreEqual(51, FEllipse.NumberOfProfilePts);
  finally
    FEllipse.EndUseProfilePoints;
  end;

  FEllipse.SavingType := stTime;
  Assert.IsTrue(FEllipse.SavingType = stTime);
  Assert.AreEqual(51, FEllipse.NumberOfProfilePts);
  Assert.AreEqual(10.0, FEllipse.Box.Right, TOL_EXACT);
end;

{ ===================================================================== }
{ TText2DTests }
{ ===================================================================== }

procedure TText2DTests.Setup;
begin
  FText := TText2D.Create(801, Rect2D(0.0, 0.0, 20.0, 5.0), 2.0, 'Hello');
end;

procedure TText2DTests.TearDown;
begin
  FreeAndNil(FText);
end;

procedure TText2DTests.Construction_TwoControlPointsFromTheRectangle;
begin
  Assert.AreEqual(2, Integer(FText.Points.Count));
  Assert.IsFalse(FText.Points.GrowingEnabled);
  Assert.AreEqual(0.0, FText.Points[0].X, TOL_EXACT);
  Assert.AreEqual(0.0, FText.Points[0].Y, TOL_EXACT);
  Assert.AreEqual(20.0, FText.Points[1].X, TOL_EXACT);
  Assert.AreEqual(5.0, FText.Points[1].Y, TOL_EXACT);
end;

procedure TText2DTests.Construction_TextHeightAndDefaults;
begin
  Assert.IsTrue(String(FText.Text) = 'Hello', 'text round-trip');
  Assert.AreEqual(2.0, FText.Height, TOL_EXACT);
  Assert.IsFalse(FText.DrawBox);
  Assert.IsFalse(FText.AutoSize);
  Assert.AreEqual(0, FText.ClippingFlags);
end;

procedure TText2DTests.Construction_BoxIsTheGivenRectangle;
begin
  Assert.AreEqual(0.0, FText.Box.Left, TOL_EXACT);
  Assert.AreEqual(0.0, FText.Box.Bottom, TOL_EXACT);
  Assert.AreEqual(20.0, FText.Box.Right, TOL_EXACT);
  Assert.AreEqual(5.0, FText.Box.Top, TOL_EXACT);
end;

procedure TText2DTests.Construction_LogFontIsCreated;
begin
  { TExtendedFont is a plain font description now - no handle, no canvas,
    so nothing here needs a window. }
  Assert.IsTrue(Assigned(FText.LogFont),
    'TText2D.Create builds its TExtendedFont');
end;

procedure TText2DTests.Assign_CopiesTextAndGeometryAndIsIndependent;
var
  Dup: TText2D;
begin
  FText.DrawBox := True;
  FText.ClippingFlags := 5;

  Dup := TText2D.Create(802, Rect2D(1.0, 1.0, 2.0, 2.0), 1.0, 'X');
  try
    Dup.Assign(FText);
    Assert.IsTrue(String(Dup.Text) = 'Hello');
    Assert.AreEqual(2.0, Dup.Height, TOL_EXACT);
    Assert.IsTrue(Dup.DrawBox);
    Assert.AreEqual(5, Dup.ClippingFlags);
    Assert.AreEqual(20.0, Dup.Points[1].X, TOL_EXACT);
    Assert.AreEqual(20.0, Dup.Box.Right, TOL_EXACT);

    FText.Text := 'Changed';
    FText.Height := 99.0;
    FText.Points[1] := Point2D(-4.0, -4.0);
    Assert.IsTrue(String(Dup.Text) = 'Hello',
      'the copy must not track the source');
    Assert.AreEqual(2.0, Dup.Height, TOL_EXACT);
    Assert.AreEqual(20.0, Dup.Points[1].X, TOL_EXACT);
  finally
    Dup.Free;
  end;
end;

procedure TText2DTests.Assign_FromFrame_CopiesOnlyTheCorners;
var
  Frm: TFrame2D;
begin
  { TText2D.Assign also accepts a TFrame2D; only the two corner points are
    taken and the text properties are left alone. }
  Frm := TFrame2D.Create(803, Point2D(2.0, 3.0), Point2D(7.0, 9.0));
  try
    FText.Assign(Frm);
    Assert.AreEqual(2, Integer(FText.Points.Count));
    Assert.AreEqual(2.0, FText.Points[0].X, TOL_EXACT);
    Assert.AreEqual(9.0, FText.Points[1].Y, TOL_EXACT);
    Assert.IsTrue(String(FText.Text) = 'Hello',
      'a frame carries no text to copy');
    Assert.AreEqual(2.0, FText.Box.Left, TOL_EXACT);
    Assert.AreEqual(9.0, FText.Box.Top, TOL_EXACT);
  finally
    Frm.Free;
  end;
end;

procedure TText2DTests.OnMe_PointInsideTheBox_ReturnsInObject;
var
  Dist: TRealType;
  Res: Integer;
begin
  { TText2D promotes any bounding-box hit to PICK_INOBJECT. }
  Dist := 0.0;
  Res := FText.OnMe(Point2D(10.0, 2.5), 0.2, Dist);
  Assert.AreEqual(PICK_INOBJECT, Res);
end;

procedure TText2DTests.OnMe_PointOutsideTheBox_ReturnsNoObject;
var
  Dist: TRealType;
  Res: Integer;
begin
  Dist := 0.0;
  Res := FText.OnMe(Point2D(100.0, 100.0), 0.2, Dist);
  Assert.AreEqual(PICK_NOOBJECT, Res);
end;

procedure TText2DTests.OnMe_PointOnAControlPoint_ReturnsIndex;
var
  Dist: TRealType;
  Res: Integer;
begin
  Dist := 0.0;
  Res := FText.OnMe(Point2D(0.0, 0.0), 0.5, Dist);
  Assert.AreEqual(0, Res, 'expected the index of the first control point');
end;

{ ===================================================================== }
{ TJustifiedVectText2DTests }
{ ===================================================================== }

procedure TJustifiedVectText2DTests.BuildFont;
var
  Glyph: TVectChar;
begin
  { A one-glyph vectorial font. Per TVectChar's contract the outline lives in
    the unit square, so this glyph's box is (0,0)-(0.6,1): advance 0.6, full
    height, no descender. FNCCadSysRegister's initialization has already run
    CADSysInitFontList and built _NullChar. }
  FFont := TVectFont.Create;
  Glyph := FFont.CreateChar('A', 1);
  Glyph.Vectors[0].Add(Point2D(0.0, 0.0));
  Glyph.Vectors[0].Add(Point2D(0.6, 0.0));
  Glyph.Vectors[0].Add(Point2D(0.6, 1.0));
  Glyph.Vectors[0].Add(Point2D(0.0, 1.0));
  Glyph.UpdateExtension(nil);
end;

procedure TJustifiedVectText2DTests.Setup;
begin
  BuildFont;
  FText := TJustifiedVectText2D.Create(901, FFont, Rect2D(0.0, 0.0, 10.0, 8.0),
    2.0, 'A');
end;

procedure TJustifiedVectText2DTests.TearDown;
begin
  { The text object only references the font, it never owns it - so the font is
    freed here and exactly once. }
  FreeAndNil(FText);
  FreeAndNil(FFont);
end;

procedure TJustifiedVectText2DTests.Font_GlyphExtensionIsTheUnionOfItsSubVectors;
var
  Glyph: TVectChar;
begin
  Glyph := FFont.Chars['A'];
  Assert.IsTrue(Assigned(Glyph), 'the glyph must be registered under its code');
  Assert.AreEqual(1, Glyph.VectorCount);
  Assert.AreEqual(4, Integer(Glyph.Vectors[0].Count));
  Assert.AreEqual(0.0, Glyph.Extension.Left, TOL_EXACT);
  Assert.AreEqual(0.0, Glyph.Extension.Bottom, TOL_EXACT);
  Assert.AreEqual(0.6, Glyph.Extension.Right, TOL_EXACT);
  Assert.AreEqual(1.0, Glyph.Extension.Top, TOL_EXACT);
end;

procedure TJustifiedVectText2DTests.Font_GetTextExtension_SingleGlyph;
var
  R: TRect2D;
begin
  { One glyph of advance 0.6 plus one inter-char space of 0.1 which is trimmed
    off the last glyph, all scaled by H = 2 -> width 1.2, height 0 .. 2. }
  R := FFont.GetTextExtension('A', 2.0, 0.1, 0.02);
  Assert.AreEqual(0.0, R.Left, TOL_EXACT);
  Assert.AreEqual(0.0, R.Bottom, TOL_TRIG);
  Assert.AreEqual(1.2, R.Right, TOL_TRIG);
  Assert.AreEqual(2.0, R.Top, TOL_EXACT);
end;

procedure TJustifiedVectText2DTests.Construction_TwoControlPointsFromTheTextBox;
begin
  Assert.AreEqual(2, Integer(FText.Points.Count));
  Assert.IsFalse(FText.Points.GrowingEnabled);
  Assert.AreEqual(0.0, FText.Points[0].X, TOL_EXACT);
  Assert.AreEqual(0.0, FText.Points[0].Y, TOL_EXACT);
  Assert.AreEqual(10.0, FText.Points[1].X, TOL_EXACT);
  Assert.AreEqual(8.0, FText.Points[1].Y, TOL_EXACT);
end;

procedure TJustifiedVectText2DTests.Construction_Defaults;
begin
  Assert.IsTrue(FText.VectFont = FFont);
  Assert.IsTrue(FText.Text = 'A');
  Assert.AreEqual(2.0, FText.Height, TOL_EXACT);
  Assert.AreEqual(0.1, FText.CharSpace, TOL_EXACT);
  Assert.AreEqual(0.02, FText.InterLine, TOL_EXACT);
  Assert.IsFalse(FText.DrawBox);
  Assert.IsTrue(FText.HorizontalJust = jhLeft);
  Assert.IsTrue(FText.VerticalJust = jvTop);
end;

procedure TJustifiedVectText2DTests.Construction_BoxIsTheJustifiedTextExtension;
begin
  { Left/top justified inside a (0,0)-(10,8) box: the 1.2 x 2.0 text sits in
    the upper-left corner, so the box is (0,6)-(1.2,8). Note the box of a
    TJustifiedVectText2D is the extension of the TEXT, not of the text box. }
  Assert.AreEqual(0.0, FText.Box.Left, TOL_TRIG);
  Assert.AreEqual(6.0, FText.Box.Bottom, TOL_TRIG);
  Assert.AreEqual(1.2, FText.Box.Right, TOL_TRIG);
  Assert.AreEqual(8.0, FText.Box.Top, TOL_TRIG);
end;

procedure TJustifiedVectText2DTests.SettingText_RecomputesTheBox;
begin
  FText.Text := 'AA';
  Assert.IsTrue(FText.Text = 'AA');
  { Two glyphs: 2 * (0.6 + 0.1) - 0.1 = 1.3, times H = 2 -> 2.6. }
  Assert.AreEqual(0.0, FText.Box.Left, TOL_TRIG);
  Assert.AreEqual(2.6, FText.Box.Right, TOL_TRIG);
  Assert.AreEqual(8.0, FText.Box.Top, TOL_TRIG);
end;

procedure TJustifiedVectText2DTests.SettingHeight_RecomputesTheBox;
begin
  FText.Height := 4.0;
  Assert.AreEqual(4.0, FText.Height, TOL_EXACT);
  { Width and height both scale with H, and top justification pins the top. }
  Assert.AreEqual(2.4, FText.Box.Right, TOL_TRIG);
  Assert.AreEqual(4.0, FText.Box.Bottom, TOL_TRIG);
  Assert.AreEqual(8.0, FText.Box.Top, TOL_TRIG);
end;

procedure TJustifiedVectText2DTests.RightBottomJustification_MovesTheBox;
begin
  { The justification properties write their field directly, so the extension
    has to be refreshed explicitly. }
  FText.HorizontalJust := jhRight;
  FText.VerticalJust := jvBottom;
  FText.UpdateExtension(nil);
  { Right justified: the 1.2 wide text ends at x = 10. Bottom justified: it
    starts at y = 0. }
  Assert.AreEqual(8.8, FText.Box.Left, TOL_TRIG);
  Assert.AreEqual(10.0, FText.Box.Right, TOL_TRIG);
  Assert.AreEqual(0.0, FText.Box.Bottom, TOL_TRIG);
  Assert.AreEqual(2.0, FText.Box.Top, TOL_TRIG);
end;

procedure TJustifiedVectText2DTests.Transform_MovesTheBox;
begin
  FText.Transform(Translate2D(100.0, 0.0));
  Assert.IsTrue(FText.HasTransform);
  Assert.AreEqual(100.0, FText.Box.Left, TOL_TRIG);
  Assert.AreEqual(101.2, FText.Box.Right, TOL_TRIG);
  Assert.AreEqual(6.0, FText.Box.Bottom, TOL_TRIG);
  Assert.AreEqual(8.0, FText.Box.Top, TOL_TRIG);
  { Control points stay in model space. }
  Assert.AreEqual(0.0, FText.Points[0].X, TOL_EXACT);
  Assert.AreEqual(10.0, FText.Points[1].X, TOL_EXACT);
end;

procedure TJustifiedVectText2DTests.Assign_CopiesEverythingAndIsIndependent;
var
  Dup: TJustifiedVectText2D;
begin
  FText.HorizontalJust := jhCenter;
  FText.DrawBox := True;

  Dup := TJustifiedVectText2D.Create(902, FFont, Rect2D(0.0, 0.0, 1.0, 1.0),
    1.0, 'A');
  try
    Dup.Assign(FText);
    Assert.IsTrue(Dup.Text = 'A');
    Assert.AreEqual(2.0, Dup.Height, TOL_EXACT);
    Assert.AreEqual(0.1, Dup.CharSpace, TOL_EXACT);
    Assert.AreEqual(0.02, Dup.InterLine, TOL_EXACT);
    Assert.IsTrue(Dup.DrawBox);
    Assert.IsTrue(Dup.HorizontalJust = jhCenter);
    Assert.IsTrue(Dup.VerticalJust = jvTop);
    Assert.IsTrue(Dup.VectFont = FFont, 'the font is shared, not cloned');
    Assert.AreEqual(2, Integer(Dup.Points.Count));
    Assert.AreEqual(10.0, Dup.Points[1].X, TOL_EXACT);
    Assert.AreEqual(8.0, Dup.Points[1].Y, TOL_EXACT);

    FText.Text := 'AAAA';
    FText.Height := 9.0;
    Assert.IsTrue(Dup.Text = 'A', 'the copy must not track the source');
    Assert.AreEqual(2.0, Dup.Height, TOL_EXACT);
  finally
    Dup.Free;
  end;
end;

procedure TJustifiedVectText2DTests.OnMe_PointInsideTheTextExtension_ReturnsInObject;
var
  Dist: TRealType;
  Res: Integer;
begin
  { The text extension is (0,6)-(1.2,8); (0.6,7) sits in its middle. }
  Dist := 0.0;
  Res := FText.OnMe(Point2D(0.6, 7.0), 0.1, Dist);
  Assert.AreEqual(PICK_INOBJECT, Res);
end;

procedure TJustifiedVectText2DTests.OnMe_PointInTheTextBoxButOutsideTheText_ReturnsNoObject;
var
  Dist: TRealType;
  Res: Integer;
begin
  { (5,1) is inside the justification box but nowhere near the glyphs, and the
    object's Box is the text extension - so it is not even a bounding-box hit. }
  Dist := 0.0;
  Res := FText.OnMe(Point2D(5.0, 1.0), 0.1, Dist);
  Assert.AreEqual(PICK_NOOBJECT, Res);
end;

initialization

TDUnitX.RegisterTestFixture(TLine2DTests);
TDUnitX.RegisterTestFixture(TPolyOutlineTests);
TDUnitX.RegisterTestFixture(TFrameRectangleTests);
TDUnitX.RegisterTestFixture(TArcEllipseTests);
TDUnitX.RegisterTestFixture(TBSpline2DTests);
TDUnitX.RegisterTestFixture(TCurveProfileProtocolTests);
TDUnitX.RegisterTestFixture(TText2DTests);
TDUnitX.RegisterTestFixture(TJustifiedVectText2DTests);

end.
