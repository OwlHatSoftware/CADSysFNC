{: DUnitX tests for the pure geometry / math layer of CADSys 4.2.

   Scope: the value types declared in FNCCS4BaseTypes and the free geometry
   functions declared in the interface of FNCCADSys4. Nothing in this unit
   touches a TCanvas, a window handle or a TFNCCADViewport, and no Draw*
   method is called, so the suite runs in a plain console runner with no
   form and no window handle.

   Every expected value below was derived by reading the actual
   implementation in FNCCADSys4.pas, not from a general assumption about
   row/column conventions. In particular:

   - TransformPoint2D computes
       Result.X := P.X*T[1,1] + P.Y*T[2,1] + P.W*T[3,1]
     i.e. the point is treated as a ROW vector multiplied on the LEFT of
     the matrix, with Delphi's [row, col] indexing. Translate2D therefore
     stores Tx/Ty in T[3,1]/T[3,2].

   - MultiplyTransform2D(M1, M2) computes Result[i,j] = sum_k M1[i,k]*M2[k,j],
     so TransformPoint2D(P, MultiplyTransform2D(M1, M2)) applies M1 FIRST
     and M2 second.

   All comparisons of exact algebra use 1E-9; anything involving trig or an
   accumulated chain of transforms uses 1E-6.

   No object is allocated by these tests (the geometry layer is entirely
   records and free functions), so there is nothing to free and a clean
   FastMM report is expected.
}
unit CADSys4.Tests.Geometry;

interface

uses
  System.SysUtils,
  System.Types,
  System.Math,
  DUnitX.TestFramework,
  FNCCS4BaseTypes,
  FNCCADSys4;

type
  {: Degree/radian helpers. }
  [TestFixture]
  TAngleConversionTests = class(TObject)
  public
    [Test]
    procedure DegToRad_HalfTurnIsPi;
    [Test]
    procedure RadToDeg_PiIsHalfTurn;
    [Test]
    [TestCase('Zero', '0')]
    [TestCase('Thirty', '30')]
    [TestCase('Ninety', '90')]
    [TestCase('OneEighty', '180')]
    [TestCase('ThreeSixty', '360')]
    [TestCase('Negative', '-45')]
    procedure DegToRad_RadToDeg_RoundTrips(const ADegrees: Integer);
  end;

  {: Constructors, vectors and the equality predicates for the 2D types. }
  [TestFixture]
  TPoint2DAndVector2DTests = class(TObject)
  public
    [Test]
    procedure Point2D_SetsWToOne;
    [Test]
    procedure VectorLength2D_ThreeFourFive;
    [Test]
    procedure VectorLength2D_ZeroVectorIsZero;
    [Test]
    procedure NormalizeVector2D_ScalesToUnitLength;
    [Test]
    procedure NormalizeVector2D_AlreadyUnitIsUnchanged;
    [Test]
    procedure NormalizeVector2D_ZeroVectorIsReturnedUnchanged;
    [Test]
    procedure Versor2D_ProducesUnitVector;
    [Test]
    procedure Vector2D_IsDifferenceOfPoints;
    [Test]
    procedure Vector2D_NormalisesWhenWDiffers;
    [Test]
    procedure Direction2D_IsUnitAndPointsFromToPoint;
    [Test]
    procedure DotProduct2D_KnownValue;
    [Test]
    procedure DotProduct2D_OfPerpendicularsIsZero;
    [Test]
    procedure Perpendicular2D_TurnsVectorQuarterTurn;
    [Test]
    procedure Perpendicular2D_PreservesLength;
    [Test]
    procedure Reflect2D_NegatesBothComponents;
    [Test]
    procedure Reflect2D_TwiceIsIdentity;
    [Test]
    procedure PointDistance2D_ThreeFourFive;
    [Test]
    procedure CartesianPoint2D_DividesByW;
    [Test]
    procedure CartesianPoint2D_LeavesUnitWUntouched;
    [Test]
    procedure CartesianPoint2D_LeavesZeroWUntouched;
    [Test]
    procedure IsSamePoint2D_IdenticalPointsAreSame;
    [Test]
    procedure IsSamePoint2D_ComparisonIsExactNotToleranced;
    [Test]
    procedure IsSamePoint2D_EquivalentHomogeneousPointsAreSame;
    [Test]
    procedure IsSameVector2D_ComparisonIsExactNotToleranced;
    [Test]
    procedure IsSameVector2D_WithDigitsRoundsBeforeComparing;
    [Test]
    procedure IsSameVector2D_WithDigitsStillSeparatesLargeDifferences;
  end;

  {: TRect2D construction, ordering, homogenisation and enlargement. }
  [TestFixture]
  TRect2DTests = class(TObject)
  public
    [Test]
    procedure Rect2D_AssignsCornersAndUnitWs;
    [Test]
    procedure Rect2D_EdgeViewMatchesFieldView;
    [Test]
    procedure ReorderRect2D_SwapsAnInvertedRectangle;
    [Test]
    procedure ReorderRect2D_LeavesAnOrderedRectangleAlone;
    [Test]
    procedure ReorderRect2D_LeavesADegenerateRectangleAlone;
    [Test]
    procedure ReorderRect2D_IsIdempotent;
    [Test]
    procedure CartesianRect2D_DividesBothCorners;
    [Test]
    procedure EnlargeBoxDelta2D_GrowsEachSideByDelta;
    [Test]
    procedure EnlargeBoxDelta2D_NegativeDeltaShrinks;
    [Test]
    procedure EnlargeBoxPerc2D_GrowsByPercentageOfEachSpan;
  end;

  {: Conversions to and from the integer Windows types. }
  [TestFixture]
  TIntegerConversionTests = class(TObject)
  public
    [Test]
    procedure Point2DToPoint_RoundsCoordinates;
    [Test]
    procedure Point2DToPoint_DividesByWBeforeRounding;
    [Test]
    procedure PointToPoint2D_SetsWToOne;
    [Test]
    procedure PointToPoint2D_Point2DToPoint_RoundTrips;
    [Test]
    procedure Rect2DToRect_MapsBottomToTopAndTopToBottom;
    [Test]
    procedure RectToRect2D_MapsTopToBottomAndBottomToTop;
    [Test]
    procedure RectToRect2D_Rect2DToRect_RoundTrips;
  end;

  {: The 2D transformation algebra. }
  [TestFixture]
  TTransform2DTests = class(TObject)
  public
    [Test]
    procedure IdentityTransf2D_LeavesAPointUnchanged;
    [Test]
    procedure IdentityTransf2D_LeavesAVectorUnchanged;
    [Test]
    procedure MultiplyTransform2D_IdentityOnTheRightIsNeutral;
    [Test]
    procedure MultiplyTransform2D_IdentityOnTheLeftIsNeutral;
    [Test]
    procedure Translate2D_StoresOffsetsInTheThirdRow;
    [Test]
    procedure Translate2D_MovesAPoint;
    [Test]
    procedure Translate2D_ThenOppositeTranslateRoundTrips;
    [Test]
    procedure Scale2D_StoresFactorsOnTheDiagonal;
    [Test]
    procedure Scale2D_ScalesAPoint;
    [Test]
    procedure Scale2D_ThenReciprocalScaleRoundTrips;
    [Test]
    procedure Rotate2D_QuarterTurnMapsXAxisOntoYAxis;
    [Test]
    procedure Rotate2D_QuarterTurnMapsYAxisOntoNegativeXAxis;
    [Test]
    procedure Rotate2D_ByAngleThenByMinusAngleRoundTrips;
    [Test]
    procedure Rotate2D_PreservesVectorLength;
    [Test]
    procedure MultiplyTransform2D_AppliesTheFirstMatrixFirst;
    [Test]
    procedure MultiplyTransform2D_TranslateThenRotateHasKnownResult;
    [Test]
    procedure MultiplyTransform2D_IsNotCommutative;
    [Test]
    procedure TransformVector2D_IgnoresTheTranslationPart;
    [Test]
    procedure TransformPoint2D_ProducesNonUnitWForANonCartesianMatrix;
    [Test]
    procedure InvertTransform2D_RoundTripsAPoint;
    [Test]
    procedure InvertTransform2D_TimesTheOriginalIsIdentity;
    [Test]
    procedure InvertTransform2D_OfASingularMatrixIsTheNullMatrix;
    [Test]
    procedure IsSameTransform2D_TrueForIdenticalMatrices;
    [Test]
    procedure IsSameTransform2D_FalseForDifferentMatrices;
    [Test]
    procedure IsCartesianTransform2D_TrueForTranslateRotateScale;
    [Test]
    procedure IsCartesianTransform2D_FalseWhenThirdColumnIsUsed;
    [Test]
    procedure TransformRect2D_TransformsBothCornersIndependently;
    [Test]
    procedure TransformBoundingBox2D_OfARotationCoversAllFourCorners;
    [Test]
    procedure TransformBoundingBox2D_OfATranslationIsTheTranslatedBox;
    [Test]
    procedure MakeOrto2D_SnapsToHorizontalWhenDxDominates;
    [Test]
    procedure MakeOrto2D_SnapsToVerticalWhenDyDominates;
  end;

  {: Box containment and box union. }
  [TestFixture]
  TBoxAlgebra2DTests = class(TObject)
  public
    [Test]
    procedure IsPointInBox2D_TrueForAnInteriorPoint;
    [Test]
    procedure IsPointInBox2D_TrueOnTheLowerLeftCorner;
    [Test]
    procedure IsPointInBox2D_TrueOnTheUpperRightCorner;
    [Test]
    procedure IsPointInBox2D_FalseJustOutsideTheLeftEdge;
    [Test]
    procedure IsPointInBox2D_FalseJustOutsideTheTopEdge;
    [Test]
    procedure IsPointInBox2D_NormalisesTheHomogeneousPoint;
    [Test]
    procedure IsPointInCartesianBox2D_AgreesForCartesianInput;
    [Test]
    procedure PointOutBox2D_GrowsTheBoxRightAndUp;
    [Test]
    procedure PointOutBox2D_GrowsTheBoxLeftAndDown;
    [Test]
    procedure PointOutBox2D_LeavesTheBoxAloneForAnInteriorPoint;
    [Test]
    procedure PointOutBox2D_ResultContainsThePoint;
    [Test]
    procedure BoxOutBox2D_HasTheKnownUnionOfTwoDisjointBoxes;
    [Test]
    procedure BoxOutBox2D_ResultContainsBothInputs;
    [Test]
    procedure BoxOutBox2D_ReordersItsArguments;
    [Test]
    procedure BoxOutBox2D_OfABoxWithItselfIsThatBox;
    [Test]
    procedure IsBoxAllInBox2D_TrueForABoxInsideItself;
    [Test]
    procedure IsBoxAllInBox2D_TrueForAnInnerBox;
    [Test]
    procedure IsBoxAllInBox2D_FalseForAnOuterBox;
    [Test]
    procedure IsBoxAllInCartesianBox2D_AgreesForCartesianInput;
    [Test]
    procedure IsBoxInBox2D_TrueForPartiallyOverlappingBoxes;
    [Test]
    procedure IsBoxInBox2D_FalseForDisjointBoxes;
  end;

  {: Point / line / segment distance and the picking predicates. }
  [TestFixture]
  TDistanceAndPicking2DTests = class(TObject)
  public
    [Test]
    procedure PointLineDistance2D_KnownPerpendicularDistance;
    [Test]
    procedure PointLineDistance2D_IsZeroForAPointOnTheLine;
    [Test]
    procedure PointLineDistance2D_ReturnsMinusOneForADegenerateSegment;
    [Test]
    procedure IsPointOnSegment2D_TrueWhenTheProjectionFallsInside;
    [Test]
    procedure IsPointOnSegment2D_FalseWhenTheProjectionFallsOutside;
    [Test]
    procedure IsPointOnSegment2D_FalseForADegenerateSegment;
    [Test]
    procedure NearPoint2D_TrueInsideTheApertureBoxAndReportsTheDistance;
    [Test]
    procedure NearPoint2D_FalseOutsideAndReportsMaxCoord;
    [Test]
    procedure IsPointOnLine2D_PicksAPointCloseToTheSegment;
    [Test]
    procedure IsPointOnLine2D_MissesAPointFarFromTheSegment;
    [Test]
    procedure IsPointOnRect2D_PicksAPointOnTheBottomEdge;
    [Test]
    procedure IsPointOnRect2D_MissesAPointFarFromTheRectangle;
  end;

  {: The Liang-Barsky clipping helpers. These are declared in the
     interface of FNCCADSys4 and take no canvas, so they are exercised here. }
  [TestFixture]
  TClipping2DTests = class(TObject)
  public
    [Test]
    procedure ClipLine2D_ReportsVisibleForAFullyContainedSegment;
    [Test]
    procedure ClipLine2D_ReportsNotVisibleForAFullyOutsideSegment;
    [Test]
    procedure ClipLine2D_ClipsBothEndsOfACrossingSegment;
    [Test]
    procedure ClipLine2D_ClipsOnlyTheOutsideEnd;
    [Test]
    procedure ClipLineLeftRight2D_ClipsInXAndIgnoresY;
    [Test]
    procedure ClipLineUpBottom2D_ClipsInYAndIgnoresX;
  end;

  {: The 3D value types, vector algebra and transformation algebra. }
  [TestFixture]
  TGeometry3DTests = class(TObject)
  public
    [Test]
    procedure Point3D_SetsWToOne;
    [Test]
    procedure Rect3D_AssignsTheTwoCorners;
    [Test]
    procedure VectorLength3D_KnownValue;
    [Test]
    procedure NormalizeVector3D_ScalesToUnitLength;
    [Test]
    procedure NormalizeVector3D_ZeroVectorIsReturnedUnchanged;
    [Test]
    procedure Versor3D_ProducesUnitVector;
    [Test]
    procedure Vector3D_IsDifferenceOfPoints;
    [Test]
    procedure Direction3D_IsUnitAndPointsFromToPoint;
    [Test]
    procedure DotProduct3D_KnownValue;
    [Test]
    procedure DotProduct3D_OfPerpendicularsIsZero;
    [Test]
    procedure CrossProd3D_XCrossYIsZ;
    [Test]
    procedure CrossProd3D_IsAntiCommutative;
    [Test]
    procedure CrossProd3D_IsPerpendicularToBothOperands;
    [Test]
    procedure CrossProd3D_OfParallelVectorsIsZero;
    [Test]
    procedure PointDistance3D_KnownValue;
    [Test]
    procedure IsSamePoint3D_IdenticalPointsAreSame;
    [Test]
    procedure IsSamePoint3D_EquivalentHomogeneousPointsAreSame;
    [Test]
    procedure IsSameVector3D_ComparisonIsExactNotToleranced;
    [Test]
    procedure IsSameVector3D_WithDigitsRoundsBeforeComparing;
    [Test]
    procedure IsSameTransform3D_TrueForIdenticalMatrices;
    [Test]
    procedure IsSameTransform3D_FalseForDifferentMatrices;
    [Test]
    procedure IsCartesianTransform3D_TrueForTranslate;
    [Test]
    procedure CartesianPoint3D_DividesByAPositiveW;
    [Test]
    procedure CartesianPoint3D_LeavesANegativeWUntouched;
    [Test]
    procedure CartesianPoint3D_LeavesUnitWUntouched;
    [Test]
    procedure ReOrderRect3D_SwapsAllThreeAxes;
    [Test]
    procedure ReOrderRect3D_LeavesAnOrderedBoxAlone;
    [Test]
    procedure IdentityTransf3D_LeavesAPointUnchanged;
    [Test]
    procedure Translate3D_MovesAPoint;
    [Test]
    procedure Translate3D_ThenOppositeTranslateRoundTrips;
    [Test]
    procedure Scale3D_ScalesAPoint;
    [Test]
    procedure Rotate3DZ_QuarterTurnMapsXAxisOntoYAxis;
    [Test]
    procedure Rotate3DX_QuarterTurnMapsYAxisOntoZAxis;
    [Test]
    procedure Rotate3DY_QuarterTurnMapsZAxisOntoXAxis;
    [Test]
    procedure Rotate3DZ_ByAngleThenByMinusAngleRoundTrips;
    [Test]
    procedure MultiplyTransform3D_IdentityIsNeutral;
    [Test]
    procedure MultiplyTransform3D_AppliesTheFirstMatrixFirst;
    [Test]
    procedure TransformVector3D_IgnoresTheTranslationPart;
    [Test]
    procedure TransformRect3D_TransformsBothCornersIndependently;
    [Test]
    procedure InvertTransform3D_RoundTripsAPointForADiagonalScale;
    [Test]
    procedure InvertTransform3D_OfASingularMatrixIsTheNullMatrix;
  end;

  {: Conversions between the 2D and 3D value types. }
  [TestFixture]
  TDimensionConversionTests = class(TObject)
  public
    [Test]
    procedure Point2DToPoint3D_ZerosZAndKeepsW;
    [Test]
    procedure Point3DToPoint2D_DropsZAndAlwaysReturnsUnitW;
    [Test]
    procedure Point3DToPoint2D_DividesByANonUnitW;
    [Test]
    procedure Point2DToPoint3D_Point3DToPoint2D_RoundTrips;
    [Test]
    procedure Rect2DToRect3D_ZerosBothZCoordinates;
    [Test]
    procedure Rect3DToRect2D_DropsBothZCoordinates;
  end;

implementation

const
  EXACT_TOL = 1E-9;
  TRIG_TOL = 1E-6;
  {: MaxCoord is declared as an untyped real constant in FNCCS4BaseTypes;
     this typed copy lets it be passed to Assert.AreEqual directly. }
  MAX_COORD_VALUE: TRealType = MaxCoord;

{ ---------------------------------------------------------------------------
  Local assertion helpers. These live in the test unit only; they call
  nothing but DUnitX.
  --------------------------------------------------------------------------- }

procedure CheckPoint2D(const AExpectedX, AExpectedY: TRealType;
  const AActual: TPoint2D; const ATol: TRealType; const AMsg: string);
begin
  Assert.AreEqual(AExpectedX, AActual.X, ATol, AMsg + ' [X]');
  Assert.AreEqual(AExpectedY, AActual.Y, ATol, AMsg + ' [Y]');
end;

procedure CheckVector2D(const AExpectedX, AExpectedY: TRealType;
  const AActual: TVector2D; const ATol: TRealType; const AMsg: string);
begin
  Assert.AreEqual(AExpectedX, AActual.X, ATol, AMsg + ' [X]');
  Assert.AreEqual(AExpectedY, AActual.Y, ATol, AMsg + ' [Y]');
end;

procedure CheckRect2D(const AExpLeft, AExpBottom, AExpRight, AExpTop: TRealType;
  const AActual: TRect2D; const ATol: TRealType; const AMsg: string);
begin
  Assert.AreEqual(AExpLeft, AActual.Left, ATol, AMsg + ' [Left]');
  Assert.AreEqual(AExpBottom, AActual.Bottom, ATol, AMsg + ' [Bottom]');
  Assert.AreEqual(AExpRight, AActual.Right, ATol, AMsg + ' [Right]');
  Assert.AreEqual(AExpTop, AActual.Top, ATol, AMsg + ' [Top]');
end;

procedure CheckPoint3D(const AExpectedX, AExpectedY, AExpectedZ: TRealType;
  const AActual: TPoint3D; const ATol: TRealType; const AMsg: string);
begin
  Assert.AreEqual(AExpectedX, AActual.X, ATol, AMsg + ' [X]');
  Assert.AreEqual(AExpectedY, AActual.Y, ATol, AMsg + ' [Y]');
  Assert.AreEqual(AExpectedZ, AActual.Z, ATol, AMsg + ' [Z]');
end;

procedure CheckVector3D(const AExpectedX, AExpectedY, AExpectedZ: TRealType;
  const AActual: TVector3D; const ATol: TRealType; const AMsg: string);
begin
  Assert.AreEqual(AExpectedX, AActual.X, ATol, AMsg + ' [X]');
  Assert.AreEqual(AExpectedY, AActual.Y, ATol, AMsg + ' [Y]');
  Assert.AreEqual(AExpectedZ, AActual.Z, ATol, AMsg + ' [Z]');
end;

procedure CheckTransf2D(const AExpected, AActual: TTransf2D;
  const ATol: TRealType; const AMsg: string);
var
  I, J: Integer;
begin
  for I := 1 to 3 do
    for J := 1 to 3 do
      Assert.AreEqual(AExpected[I, J], AActual[I, J], ATol,
        Format('%s [%d,%d]', [AMsg, I, J]));
end;

{: Builds a TPoint2D directly, bypassing Point2D, so that W can be set
   to something other than 1.0. }
function MakeRawPoint2D(const AX, AY, AW: TRealType): TPoint2D;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.W := AW;
end;

{: Builds a TPoint3D directly, bypassing Point3D, so that W can be set
   to something other than 1.0. }
function MakeRawPoint3D(const AX, AY, AZ, AW: TRealType): TPoint3D;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.Z := AZ;
  Result.W := AW;
end;

function MakeVector2D(const AX, AY: TRealType): TVector2D;
begin
  Result.X := AX;
  Result.Y := AY;
end;

function MakeVector3D(const AX, AY, AZ: TRealType): TVector3D;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.Z := AZ;
end;

{ ---------------------------------------------------------------------------
  TAngleConversionTests
  --------------------------------------------------------------------------- }

procedure TAngleConversionTests.DegToRad_HalfTurnIsPi;
begin
  Assert.AreEqual(Pi, DegToRad(180.0), EXACT_TOL);
end;

procedure TAngleConversionTests.RadToDeg_PiIsHalfTurn;
begin
  Assert.AreEqual(180.0, RadToDeg(Pi), 1E-12);
end;

procedure TAngleConversionTests.DegToRad_RadToDeg_RoundTrips
  (const ADegrees: Integer);
var
  LExpected: TRealType;
begin
  LExpected := ADegrees;
  Assert.AreEqual(LExpected, RadToDeg(DegToRad(LExpected)), TRIG_TOL);
end;

{ ---------------------------------------------------------------------------
  TPoint2DAndVector2DTests
  --------------------------------------------------------------------------- }

procedure TPoint2DAndVector2DTests.Point2D_SetsWToOne;
var
  LP: TPoint2D;
begin
  LP := Point2D(3.5, -7.25);
  Assert.AreEqual(3.5, LP.X, EXACT_TOL, 'X');
  Assert.AreEqual(-7.25, LP.Y, EXACT_TOL, 'Y');
  Assert.AreEqual(1.0, LP.W, EXACT_TOL, 'W must be 1.0');
end;

procedure TPoint2DAndVector2DTests.VectorLength2D_ThreeFourFive;
begin
  Assert.AreEqual(5.0, VectorLength2D(MakeVector2D(3.0, 4.0)), EXACT_TOL);
end;

procedure TPoint2DAndVector2DTests.VectorLength2D_ZeroVectorIsZero;
begin
  Assert.AreEqual(0.0, VectorLength2D(MakeVector2D(0.0, 0.0)), EXACT_TOL);
end;

procedure TPoint2DAndVector2DTests.NormalizeVector2D_ScalesToUnitLength;
var
  LV: TVector2D;
begin
  LV := NormalizeVector2D(MakeVector2D(3.0, 4.0));
  CheckVector2D(0.6, 0.8, LV, EXACT_TOL, 'normalized (3,4)');
  Assert.AreEqual(1.0, VectorLength2D(LV), EXACT_TOL, 'length');
end;

procedure TPoint2DAndVector2DTests.NormalizeVector2D_AlreadyUnitIsUnchanged;
var
  LV: TVector2D;
begin
  { The implementation short-circuits when the modulus is exactly 1.0. }
  LV := NormalizeVector2D(MakeVector2D(0.0, 1.0));
  CheckVector2D(0.0, 1.0, LV, EXACT_TOL, 'already-unit vector');
end;

procedure TPoint2DAndVector2DTests.
  NormalizeVector2D_ZeroVectorIsReturnedUnchanged;
var
  LV: TVector2D;
begin
  { NormalizeVector2D guards against a zero modulus (Modul <> 0.0) and
    returns the input untouched rather than dividing by zero. }
  LV := NormalizeVector2D(MakeVector2D(0.0, 0.0));
  CheckVector2D(0.0, 0.0, LV, EXACT_TOL, 'zero vector is passed through');
end;

procedure TPoint2DAndVector2DTests.Versor2D_ProducesUnitVector;
var
  LV: TVector2D;
begin
  LV := Versor2D(3.0, 4.0);
  CheckVector2D(0.6, 0.8, LV, EXACT_TOL, 'versor (3,4)');
  Assert.AreEqual(1.0, VectorLength2D(LV), EXACT_TOL, 'length');
end;

procedure TPoint2DAndVector2DTests.Vector2D_IsDifferenceOfPoints;
begin
  CheckVector2D(3.0, 4.0, Vector2D(Point2D(1.0, 1.0), Point2D(4.0, 5.0)),
    EXACT_TOL, 'PTo - PFrom');
end;

procedure TPoint2DAndVector2DTests.Vector2D_NormalisesWhenWDiffers;
var
  LFrom, LTo: TPoint2D;
begin
  { Vector2D homogenises both points when their W values differ.
    (6,8,2) is the cartesian point (3,4). }
  LFrom := Point2D(1.0, 1.0);
  LTo := MakeRawPoint2D(6.0, 8.0, 2.0);
  CheckVector2D(2.0, 3.0, Vector2D(LFrom, LTo), EXACT_TOL,
    'differing W is homogenised first');
end;

procedure TPoint2DAndVector2DTests.Direction2D_IsUnitAndPointsFromToPoint;
var
  LV: TVector2D;
begin
  LV := Direction2D(Point2D(1.0, 1.0), Point2D(4.0, 5.0));
  CheckVector2D(0.6, 0.8, LV, EXACT_TOL, 'direction');
  Assert.AreEqual(1.0, VectorLength2D(LV), EXACT_TOL, 'length');
end;

procedure TPoint2DAndVector2DTests.DotProduct2D_KnownValue;
begin
  Assert.AreEqual(11.0,
    DotProduct2D(MakeVector2D(1.0, 2.0), MakeVector2D(3.0, 4.0)), EXACT_TOL);
end;

procedure TPoint2DAndVector2DTests.DotProduct2D_OfPerpendicularsIsZero;
var
  LV: TVector2D;
begin
  LV := MakeVector2D(2.0, -5.0);
  Assert.AreEqual(0.0, DotProduct2D(LV, Perpendicular2D(LV)), EXACT_TOL);
end;

procedure TPoint2DAndVector2DTests.Perpendicular2D_TurnsVectorQuarterTurn;
begin
  { Perpendicular2D returns (-V.Y, V.X). }
  CheckVector2D(0.0, 1.0, Perpendicular2D(MakeVector2D(1.0, 0.0)), EXACT_TOL,
    'perpendicular of +X');
  CheckVector2D(-1.0, 0.0, Perpendicular2D(MakeVector2D(0.0, 1.0)), EXACT_TOL,
    'perpendicular of +Y');
end;

procedure TPoint2DAndVector2DTests.Perpendicular2D_PreservesLength;
var
  LV: TVector2D;
begin
  LV := MakeVector2D(3.0, 4.0);
  Assert.AreEqual(VectorLength2D(LV), VectorLength2D(Perpendicular2D(LV)),
    EXACT_TOL);
end;

procedure TPoint2DAndVector2DTests.Reflect2D_NegatesBothComponents;
begin
  CheckVector2D(-1.0, -2.0, Reflect2D(MakeVector2D(1.0, 2.0)), EXACT_TOL,
    'reflected');
end;

procedure TPoint2DAndVector2DTests.Reflect2D_TwiceIsIdentity;
begin
  CheckVector2D(1.5, -2.5, Reflect2D(Reflect2D(MakeVector2D(1.5, -2.5))),
    EXACT_TOL, 'double reflection');
end;

procedure TPoint2DAndVector2DTests.PointDistance2D_ThreeFourFive;
begin
  Assert.AreEqual(5.0, PointDistance2D(Point2D(0.0, 0.0), Point2D(3.0, 4.0)),
    EXACT_TOL);
end;

procedure TPoint2DAndVector2DTests.CartesianPoint2D_DividesByW;
var
  LP: TPoint2D;
begin
  LP := CartesianPoint2D(MakeRawPoint2D(6.0, 8.0, 2.0));
  CheckPoint2D(3.0, 4.0, LP, EXACT_TOL, 'homogeneous divide');
  Assert.AreEqual(1.0, LP.W, EXACT_TOL, 'W is normalised to 1.0');
end;

procedure TPoint2DAndVector2DTests.CartesianPoint2D_LeavesUnitWUntouched;
var
  LP: TPoint2D;
begin
  LP := CartesianPoint2D(Point2D(6.0, 8.0));
  CheckPoint2D(6.0, 8.0, LP, EXACT_TOL, 'W = 1 is a no-op');
  Assert.AreEqual(1.0, LP.W, EXACT_TOL, 'W');
end;

procedure TPoint2DAndVector2DTests.CartesianPoint2D_LeavesZeroWUntouched;
var
  LP: TPoint2D;
begin
  { The implementation explicitly excludes W = 0 from the division. }
  LP := CartesianPoint2D(MakeRawPoint2D(6.0, 8.0, 0.0));
  CheckPoint2D(6.0, 8.0, LP, EXACT_TOL, 'W = 0 is passed through');
  Assert.AreEqual(0.0, LP.W, EXACT_TOL, 'W stays 0');
end;

procedure TPoint2DAndVector2DTests.IsSamePoint2D_IdenticalPointsAreSame;
begin
  Assert.IsTrue(IsSamePoint2D(Point2D(1.0, 2.0), Point2D(1.0, 2.0)));
end;

procedure TPoint2DAndVector2DTests.IsSamePoint2D_ComparisonIsExactNotToleranced;
begin
  { IsSamePoint2D uses plain '=' on the coordinates: no epsilon at all. }
  Assert.IsFalse(IsSamePoint2D(Point2D(1.0, 2.0), Point2D(1.0, 2.0 + 1E-12)),
    'the comparison must be exact, not toleranced');
end;

procedure TPoint2DAndVector2DTests.
  IsSamePoint2D_EquivalentHomogeneousPointsAreSame;
begin
  { The W values differ, so both points are homogenised before comparing. }
  Assert.IsTrue(IsSamePoint2D(MakeRawPoint2D(2.0, 4.0, 2.0),
    Point2D(1.0, 2.0)));
end;

procedure TPoint2DAndVector2DTests.
  IsSameVector2D_ComparisonIsExactNotToleranced;
begin
  Assert.IsTrue(IsSameVector2D(MakeVector2D(1.0, 2.0),
    MakeVector2D(1.0, 2.0)), 'identical vectors');
  Assert.IsFalse(IsSameVector2D(MakeVector2D(1.0, 2.0),
    MakeVector2D(1.0, 2.0 + 1E-12)),
    'the two-argument overload compares exactly');
end;

procedure TPoint2DAndVector2DTests.
  IsSameVector2D_WithDigitsRoundsBeforeComparing;
begin
  { The three-argument overload passes each coordinate through
    System.Math.RoundTo with the given TRoundToRange first. }
  Assert.IsTrue(IsSameVector2D(MakeVector2D(1.0, 2.0),
    MakeVector2D(1.001, 2.001), -2),
    'rounding to two decimals must collapse the difference');
end;

procedure TPoint2DAndVector2DTests.
  IsSameVector2D_WithDigitsStillSeparatesLargeDifferences;
begin
  Assert.IsFalse(IsSameVector2D(MakeVector2D(1.0, 2.0),
    MakeVector2D(1.5, 2.0), -2),
    'rounding to two decimals must not collapse 0.5');
end;

{ ---------------------------------------------------------------------------
  TRect2DTests
  --------------------------------------------------------------------------- }

procedure TRect2DTests.Rect2D_AssignsCornersAndUnitWs;
var
  LR: TRect2D;
begin
  LR := Rect2D(1.0, 2.0, 3.0, 4.0);
  CheckRect2D(1.0, 2.0, 3.0, 4.0, LR, EXACT_TOL, 'Rect2D(L,B,R,T)');
  Assert.AreEqual(1.0, LR.W1, EXACT_TOL, 'W1');
  Assert.AreEqual(1.0, LR.W2, EXACT_TOL, 'W2');
end;

procedure TRect2DTests.Rect2D_EdgeViewMatchesFieldView;
var
  LR: TRect2D;
begin
  { TRect2D is a variant record: (Left,Bottom,W1,Right,Top,W2) overlays
    (FirstEdge, SecondEdge). }
  LR := Rect2D(1.0, 2.0, 3.0, 4.0);
  Assert.AreEqual(LR.Left, LR.FirstEdge.X, EXACT_TOL, 'Left / FirstEdge.X');
  Assert.AreEqual(LR.Bottom, LR.FirstEdge.Y, EXACT_TOL, 'Bottom / FirstEdge.Y');
  Assert.AreEqual(LR.W1, LR.FirstEdge.W, EXACT_TOL, 'W1 / FirstEdge.W');
  Assert.AreEqual(LR.Right, LR.SecondEdge.X, EXACT_TOL, 'Right / SecondEdge.X');
  Assert.AreEqual(LR.Top, LR.SecondEdge.Y, EXACT_TOL, 'Top / SecondEdge.Y');
  Assert.AreEqual(LR.W2, LR.SecondEdge.W, EXACT_TOL, 'W2 / SecondEdge.W');
end;

procedure TRect2DTests.ReorderRect2D_SwapsAnInvertedRectangle;
begin
  { Rect2D(Left=10, Bottom=20, Right=2, Top=5) is inverted on both axes. }
  CheckRect2D(2.0, 5.0, 10.0, 20.0, ReorderRect2D(Rect2D(10.0, 20.0, 2.0, 5.0)),
    EXACT_TOL, 'reordered');
end;

procedure TRect2DTests.ReorderRect2D_LeavesAnOrderedRectangleAlone;
begin
  CheckRect2D(1.0, 2.0, 3.0, 4.0, ReorderRect2D(Rect2D(1.0, 2.0, 3.0, 4.0)),
    EXACT_TOL, 'already ordered');
end;

procedure TRect2DTests.ReorderRect2D_LeavesADegenerateRectangleAlone;
begin
  { An empty (zero area) rectangle has no inversion to fix. }
  CheckRect2D(5.0, 5.0, 5.0, 5.0, ReorderRect2D(Rect2D(5.0, 5.0, 5.0, 5.0)),
    EXACT_TOL, 'degenerate rectangle');
end;

procedure TRect2DTests.ReorderRect2D_IsIdempotent;
var
  LOnce, LTwice: TRect2D;
begin
  LOnce := ReorderRect2D(Rect2D(10.0, 20.0, 2.0, 5.0));
  LTwice := ReorderRect2D(LOnce);
  CheckRect2D(LOnce.Left, LOnce.Bottom, LOnce.Right, LOnce.Top, LTwice,
    EXACT_TOL, 'reordering twice equals reordering once');
end;

procedure TRect2DTests.CartesianRect2D_DividesBothCorners;
var
  LR, LC: TRect2D;
begin
  LR.FirstEdge := MakeRawPoint2D(2.0, 4.0, 2.0);
  LR.SecondEdge := MakeRawPoint2D(30.0, 40.0, 10.0);
  LC := CartesianRect2D(LR);
  CheckRect2D(1.0, 2.0, 3.0, 4.0, LC, EXACT_TOL, 'both corners homogenised');
  Assert.AreEqual(1.0, LC.W1, EXACT_TOL, 'W1');
  Assert.AreEqual(1.0, LC.W2, EXACT_TOL, 'W2');
end;

procedure TRect2DTests.EnlargeBoxDelta2D_GrowsEachSideByDelta;
begin
  CheckRect2D(-2.0, -2.0, 12.0, 12.0,
    EnlargeBoxDelta2D(Rect2D(0.0, 0.0, 10.0, 10.0), 2.0), EXACT_TOL, 'delta 2');
end;

procedure TRect2DTests.EnlargeBoxDelta2D_NegativeDeltaShrinks;
begin
  CheckRect2D(1.0, 1.0, 9.0, 9.0,
    EnlargeBoxDelta2D(Rect2D(0.0, 0.0, 10.0, 10.0), -1.0), EXACT_TOL,
    'delta -1');
end;

procedure TRect2DTests.EnlargeBoxPerc2D_GrowsByPercentageOfEachSpan;
begin
  { The margin is Abs(span) * Perc, applied on both sides of each axis. }
  CheckRect2D(-1.0, -2.0, 11.0, 22.0,
    EnlargeBoxPerc2D(Rect2D(0.0, 0.0, 10.0, 20.0), 0.1), EXACT_TOL, 'perc 10%');
end;

{ ---------------------------------------------------------------------------
  TIntegerConversionTests
  --------------------------------------------------------------------------- }

procedure TIntegerConversionTests.Point2DToPoint_RoundsCoordinates;
var
  LP: TPoint;
begin
  LP := Point2DToPoint(Point2D(1.4, 2.6));
  Assert.AreEqual(1, LP.X, 'X');
  Assert.AreEqual(3, LP.Y, 'Y');
end;

procedure TIntegerConversionTests.Point2DToPoint_DividesByWBeforeRounding;
var
  LP: TPoint;
begin
  LP := Point2DToPoint(MakeRawPoint2D(6.0, 8.0, 2.0));
  Assert.AreEqual(3, LP.X, 'X');
  Assert.AreEqual(4, LP.Y, 'Y');
end;

procedure TIntegerConversionTests.PointToPoint2D_SetsWToOne;
var
  LSrc: TPoint;
  LP: TPoint2D;
begin
  LSrc.X := 3;
  LSrc.Y := 4;
  LP := PointToPoint2D(LSrc);
  CheckPoint2D(3.0, 4.0, LP, EXACT_TOL, 'converted point');
  Assert.AreEqual(1.0, LP.W, EXACT_TOL, 'W');
end;

procedure TIntegerConversionTests.PointToPoint2D_Point2DToPoint_RoundTrips;
var
  LSrc, LBack: TPoint;
begin
  LSrc.X := -17;
  LSrc.Y := 42;
  LBack := Point2DToPoint(PointToPoint2D(LSrc));
  Assert.AreEqual(LSrc.X, LBack.X, 'X');
  Assert.AreEqual(LSrc.Y, LBack.Y, 'Y');
end;

procedure TIntegerConversionTests.Rect2DToRect_MapsBottomToTopAndTopToBottom;
var
  LR: TRect;
begin
  { The library's Y axis points up, the Windows one points down, so
    Rect2DToRect writes Round(R.Bottom) into Top and Round(R.Top) into
    Bottom, after reordering. }
  LR := Rect2DToRect(Rect2D(1.0, 2.0, 3.0, 4.0));
  Assert.AreEqual(1, LR.Left, 'Left');
  Assert.AreEqual(3, LR.Right, 'Right');
  Assert.AreEqual(2, LR.Top, 'Top comes from Bottom');
  Assert.AreEqual(4, LR.Bottom, 'Bottom comes from Top');
end;

procedure TIntegerConversionTests.RectToRect2D_MapsTopToBottomAndBottomToTop;
var
  LSrc: TRect;
  LR: TRect2D;
begin
  LSrc.Left := 1;
  LSrc.Top := 2;
  LSrc.Right := 3;
  LSrc.Bottom := 4;
  LR := RectToRect2D(LSrc);
  CheckRect2D(1.0, 2.0, 3.0, 4.0, LR, EXACT_TOL,
    'RectToRect2D is Rect2D(Left, Top, Right, Bottom)');
end;

procedure TIntegerConversionTests.RectToRect2D_Rect2DToRect_RoundTrips;
var
  LSrc, LBack: TRect;
begin
  LSrc.Left := 1;
  LSrc.Top := 2;
  LSrc.Right := 3;
  LSrc.Bottom := 4;
  LBack := Rect2DToRect(RectToRect2D(LSrc));
  Assert.AreEqual(LSrc.Left, LBack.Left, 'Left');
  Assert.AreEqual(LSrc.Top, LBack.Top, 'Top');
  Assert.AreEqual(LSrc.Right, LBack.Right, 'Right');
  Assert.AreEqual(LSrc.Bottom, LBack.Bottom, 'Bottom');
end;

{ ---------------------------------------------------------------------------
  TTransform2DTests
  --------------------------------------------------------------------------- }

procedure TTransform2DTests.IdentityTransf2D_LeavesAPointUnchanged;
var
  LP: TPoint2D;
begin
  LP := TransformPoint2D(Point2D(3.0, -4.0), IdentityTransf2D);
  CheckPoint2D(3.0, -4.0, LP, EXACT_TOL, 'identity');
  Assert.AreEqual(1.0, LP.W, EXACT_TOL, 'W');
end;

procedure TTransform2DTests.IdentityTransf2D_LeavesAVectorUnchanged;
begin
  CheckVector2D(3.0, -4.0,
    TransformVector2D(MakeVector2D(3.0, -4.0), IdentityTransf2D), EXACT_TOL,
    'identity');
end;

procedure TTransform2DTests.MultiplyTransform2D_IdentityOnTheRightIsNeutral;
var
  LM: TTransf2D;
begin
  LM := MultiplyTransform2D(Translate2D(3.0, 4.0), Scale2D(2.0, 5.0));
  CheckTransf2D(LM, MultiplyTransform2D(LM, IdentityTransf2D), EXACT_TOL,
    'M * I');
end;

procedure TTransform2DTests.MultiplyTransform2D_IdentityOnTheLeftIsNeutral;
var
  LM: TTransf2D;
begin
  LM := MultiplyTransform2D(Translate2D(3.0, 4.0), Scale2D(2.0, 5.0));
  CheckTransf2D(LM, MultiplyTransform2D(IdentityTransf2D, LM), EXACT_TOL,
    'I * M');
end;

procedure TTransform2DTests.Translate2D_StoresOffsetsInTheThirdRow;
var
  LM: TTransf2D;
begin
  { Translate2D builds the identity and then writes Tx into [3,1] and
    Ty into [3,2]. }
  LM := Translate2D(7.0, -9.0);
  Assert.AreEqual(7.0, LM[3, 1], EXACT_TOL, '[3,1] holds Tx');
  Assert.AreEqual(-9.0, LM[3, 2], EXACT_TOL, '[3,2] holds Ty');
  Assert.AreEqual(1.0, LM[1, 1], EXACT_TOL, '[1,1]');
  Assert.AreEqual(0.0, LM[1, 2], EXACT_TOL, '[1,2]');
  Assert.AreEqual(0.0, LM[2, 1], EXACT_TOL, '[2,1]');
  Assert.AreEqual(1.0, LM[2, 2], EXACT_TOL, '[2,2]');
  Assert.AreEqual(1.0, LM[3, 3], EXACT_TOL, '[3,3]');
end;

procedure TTransform2DTests.Translate2D_MovesAPoint;
begin
  CheckPoint2D(4.0, 6.0, TransformPoint2D(Point2D(1.0, 2.0),
    Translate2D(3.0, 4.0)), EXACT_TOL, 'translated');
end;

procedure TTransform2DTests.Translate2D_ThenOppositeTranslateRoundTrips;
var
  LP: TPoint2D;
begin
  LP := TransformPoint2D(TransformPoint2D(Point2D(1.5, -2.5),
    Translate2D(30.0, -40.0)), Translate2D(-30.0, 40.0));
  CheckPoint2D(1.5, -2.5, LP, EXACT_TOL, 'translate then untranslate');
end;

procedure TTransform2DTests.Scale2D_StoresFactorsOnTheDiagonal;
var
  LM: TTransf2D;
begin
  LM := Scale2D(2.0, 3.0);
  Assert.AreEqual(2.0, LM[1, 1], EXACT_TOL, '[1,1] holds Sx');
  Assert.AreEqual(3.0, LM[2, 2], EXACT_TOL, '[2,2] holds Sy');
  Assert.AreEqual(0.0, LM[3, 1], EXACT_TOL, '[3,1] has no translation');
  Assert.AreEqual(0.0, LM[3, 2], EXACT_TOL, '[3,2] has no translation');
end;

procedure TTransform2DTests.Scale2D_ScalesAPoint;
begin
  CheckPoint2D(6.0, 12.0, TransformPoint2D(Point2D(3.0, 3.0),
    Scale2D(2.0, 4.0)), EXACT_TOL, 'scaled');
end;

procedure TTransform2DTests.Scale2D_ThenReciprocalScaleRoundTrips;
var
  LP: TPoint2D;
begin
  LP := TransformPoint2D(TransformPoint2D(Point2D(3.0, -7.0),
    Scale2D(2.0, 4.0)), Scale2D(0.5, 0.25));
  CheckPoint2D(3.0, -7.0, LP, EXACT_TOL, 'scale then unscale');
end;

procedure TTransform2DTests.Rotate2D_QuarterTurnMapsXAxisOntoYAxis;
begin
  { Rotate2D writes cos into [1,1] and [2,2], sin into [1,2] and -sin
    into [2,1]; with the row-vector convention that is a counter
    clockwise rotation. }
  CheckPoint2D(0.0, 1.0, TransformPoint2D(Point2D(1.0, 0.0),
    Rotate2D(Pi / 2.0)), TRIG_TOL, '+X rotated a quarter turn');
end;

procedure TTransform2DTests.Rotate2D_QuarterTurnMapsYAxisOntoNegativeXAxis;
begin
  CheckPoint2D(-1.0, 0.0, TransformPoint2D(Point2D(0.0, 1.0),
    Rotate2D(Pi / 2.0)), TRIG_TOL, '+Y rotated a quarter turn');
end;

procedure TTransform2DTests.Rotate2D_ByAngleThenByMinusAngleRoundTrips;
var
  LP: TPoint2D;
begin
  LP := TransformPoint2D(TransformPoint2D(Point2D(3.0, -7.0),
    Rotate2D(0.7)), Rotate2D(-0.7));
  CheckPoint2D(3.0, -7.0, LP, TRIG_TOL, 'rotate then unrotate');
end;

procedure TTransform2DTests.Rotate2D_PreservesVectorLength;
var
  LV: TVector2D;
begin
  LV := TransformVector2D(MakeVector2D(3.0, 4.0), Rotate2D(1.234));
  Assert.AreEqual(5.0, VectorLength2D(LV), TRIG_TOL);
end;

procedure TTransform2DTests.MultiplyTransform2D_AppliesTheFirstMatrixFirst;
var
  LComposed, LSequential: TPoint2D;
  LM: TTransf2D;
begin
  { MultiplyTransform2D(M1, M2)[i,j] = sum_k M1[i,k]*M2[k,j], and
    TransformPoint2D multiplies the point as a row vector on the left,
    so the composed matrix applies M1 and then M2. }
  LM := MultiplyTransform2D(Translate2D(10.0, 0.0), Rotate2D(Pi / 2.0));
  LComposed := TransformPoint2D(Point2D(1.0, 2.0), LM);
  LSequential := TransformPoint2D(TransformPoint2D(Point2D(1.0, 2.0),
    Translate2D(10.0, 0.0)), Rotate2D(Pi / 2.0));
  CheckPoint2D(LSequential.X, LSequential.Y, LComposed, TRIG_TOL,
    'composed equals sequential (M1 first)');
end;

procedure TTransform2DTests.MultiplyTransform2D_TranslateThenRotateHasKnownResult;
var
  LP: TPoint2D;
begin
  { (1,2) translated by (10,0) is (11,2); rotated a quarter turn CCW
    that is (-2,11). }
  LP := TransformPoint2D(Point2D(1.0, 2.0),
    MultiplyTransform2D(Translate2D(10.0, 0.0), Rotate2D(Pi / 2.0)));
  CheckPoint2D(-2.0, 11.0, LP, TRIG_TOL, 'translate then rotate');
end;

procedure TTransform2DTests.MultiplyTransform2D_IsNotCommutative;
var
  LA, LB: TPoint2D;
begin
  LA := TransformPoint2D(Point2D(1.0, 2.0),
    MultiplyTransform2D(Translate2D(10.0, 0.0), Rotate2D(Pi / 2.0)));
  LB := TransformPoint2D(Point2D(1.0, 2.0),
    MultiplyTransform2D(Rotate2D(Pi / 2.0), Translate2D(10.0, 0.0)));
  Assert.IsFalse(IsSamePoint2D(LA, LB),
    'translate*rotate must differ from rotate*translate');
  { Rotate first: (1,2) -> (-2,1); then translate -> (8,1). }
  CheckPoint2D(8.0, 1.0, LB, TRIG_TOL, 'rotate then translate');
end;

procedure TTransform2DTests.TransformVector2D_IgnoresTheTranslationPart;
begin
  { TransformVector2D never reads row 3 of the matrix. }
  CheckVector2D(3.0, 4.0,
    TransformVector2D(MakeVector2D(3.0, 4.0), Translate2D(100.0, -100.0)),
    EXACT_TOL, 'a vector is not translated');
end;

procedure TTransform2DTests.
  TransformPoint2D_ProducesNonUnitWForANonCartesianMatrix;
var
  LM: TTransf2D;
  LP: TPoint2D;
begin
  LM := IdentityTransf2D;
  LM[3, 3] := 2.0;
  LP := TransformPoint2D(Point2D(4.0, 6.0), LM);
  Assert.AreEqual(2.0, LP.W, EXACT_TOL, 'W picks up [3,3]');
  CheckPoint2D(2.0, 3.0, CartesianPoint2D(LP), EXACT_TOL,
    'homogenising recovers the cartesian point');
end;

procedure TTransform2DTests.InvertTransform2D_RoundTripsAPoint;
var
  LM: TTransf2D;
  LP: TPoint2D;
begin
  LM := MultiplyTransform2D(MultiplyTransform2D(Scale2D(2.0, 3.0),
    Rotate2D(0.7)), Translate2D(5.0, -1.0));
  LP := TransformPoint2D(TransformPoint2D(Point2D(3.0, -7.0), LM),
    InvertTransform2D(LM));
  CheckPoint2D(3.0, -7.0, LP, TRIG_TOL, 'transform then invert');
end;

procedure TTransform2DTests.InvertTransform2D_TimesTheOriginalIsIdentity;
var
  LM: TTransf2D;
begin
  LM := MultiplyTransform2D(Scale2D(2.0, 3.0), Translate2D(5.0, -1.0));
  CheckTransf2D(IdentityTransf2D,
    MultiplyTransform2D(LM, InvertTransform2D(LM)), TRIG_TOL, 'M * M^-1');
end;

procedure TTransform2DTests.InvertTransform2D_OfASingularMatrixIsTheNullMatrix;
begin
  { Scale2D(0,0) is cartesian with a zero 2x2 determinant, and the
    implementation returns NullTransf2D in that case. }
  Assert.IsTrue(IsSameTransform2D(InvertTransform2D(Scale2D(0.0, 0.0)),
    NullTransf2D), 'a singular matrix must invert to NullTransf2D');
end;

procedure TTransform2DTests.IsSameTransform2D_TrueForIdenticalMatrices;
begin
  Assert.IsTrue(IsSameTransform2D(Translate2D(1.0, 2.0),
    Translate2D(1.0, 2.0)));
end;

procedure TTransform2DTests.IsSameTransform2D_FalseForDifferentMatrices;
begin
  Assert.IsFalse(IsSameTransform2D(IdentityTransf2D, Translate2D(1.0, 0.0)));
end;

procedure TTransform2DTests.IsCartesianTransform2D_TrueForTranslateRotateScale;
begin
  Assert.IsTrue(IsCartesianTransform2D(Translate2D(1.0, 2.0)), 'translate');
  Assert.IsTrue(IsCartesianTransform2D(Rotate2D(0.4)), 'rotate');
  Assert.IsTrue(IsCartesianTransform2D(Scale2D(2.0, 3.0)), 'scale');
  Assert.IsTrue(IsCartesianTransform2D(IdentityTransf2D), 'identity');
end;

procedure TTransform2DTests.IsCartesianTransform2D_FalseWhenThirdColumnIsUsed;
var
  LM: TTransf2D;
begin
  LM := IdentityTransf2D;
  LM[1, 3] := 0.5;
  Assert.IsFalse(IsCartesianTransform2D(LM));
end;

procedure TTransform2DTests.TransformRect2D_TransformsBothCornersIndependently;
begin
  CheckRect2D(1.0, 2.0, 11.0, 12.0,
    TransformRect2D(Rect2D(0.0, 0.0, 10.0, 10.0), Translate2D(1.0, 2.0)),
    EXACT_TOL, 'translated rectangle');
end;

procedure TTransform2DTests.
  TransformBoundingBox2D_OfARotationCoversAllFourCorners;
begin
  { TransformBoundingBox2D transforms both diagonals and unions the two
    results, so a quarter turn of the unit-ish box (0,0)-(10,10) lands on
    (-10,0)-(0,10). }
  CheckRect2D(-10.0, 0.0, 0.0, 10.0,
    TransformBoundingBox2D(Rect2D(0.0, 0.0, 10.0, 10.0), Rotate2D(Pi / 2.0)),
    TRIG_TOL, 'bounding box of a quarter turn');
end;

procedure TTransform2DTests.
  TransformBoundingBox2D_OfATranslationIsTheTranslatedBox;
begin
  CheckRect2D(1.0, 2.0, 11.0, 12.0,
    TransformBoundingBox2D(Rect2D(0.0, 0.0, 10.0, 10.0),
    Translate2D(1.0, 2.0)), EXACT_TOL, 'bounding box of a translation');
end;

procedure TTransform2DTests.MakeOrto2D_SnapsToHorizontalWhenDxDominates;
var
  LCurr: TPoint2D;
begin
  LCurr := Point2D(10.0, 3.0);
  MakeOrto2D(Point2D(0.0, 0.0), LCurr);
  CheckPoint2D(10.0, 0.0, LCurr, EXACT_TOL, 'snapped to the horizontal');
end;

procedure TTransform2DTests.MakeOrto2D_SnapsToVerticalWhenDyDominates;
var
  LCurr: TPoint2D;
begin
  LCurr := Point2D(3.0, 10.0);
  MakeOrto2D(Point2D(0.0, 0.0), LCurr);
  CheckPoint2D(0.0, 10.0, LCurr, EXACT_TOL, 'snapped to the vertical');
end;

{ ---------------------------------------------------------------------------
  TBoxAlgebra2DTests
  --------------------------------------------------------------------------- }

procedure TBoxAlgebra2DTests.IsPointInBox2D_TrueForAnInteriorPoint;
begin
  Assert.IsTrue(IsPointInBox2D(Point2D(5.0, 5.0),
    Rect2D(0.0, 0.0, 10.0, 10.0)));
end;

procedure TBoxAlgebra2DTests.IsPointInBox2D_TrueOnTheLowerLeftCorner;
begin
  { The position code uses strict '<' and '>', so the edges are inside. }
  Assert.IsTrue(IsPointInBox2D(Point2D(0.0, 0.0),
    Rect2D(0.0, 0.0, 10.0, 10.0)), 'the boundary is inclusive');
end;

procedure TBoxAlgebra2DTests.IsPointInBox2D_TrueOnTheUpperRightCorner;
begin
  Assert.IsTrue(IsPointInBox2D(Point2D(10.0, 10.0),
    Rect2D(0.0, 0.0, 10.0, 10.0)), 'the boundary is inclusive');
end;

procedure TBoxAlgebra2DTests.IsPointInBox2D_FalseJustOutsideTheLeftEdge;
begin
  Assert.IsFalse(IsPointInBox2D(Point2D(-0.001, 5.0),
    Rect2D(0.0, 0.0, 10.0, 10.0)));
end;

procedure TBoxAlgebra2DTests.IsPointInBox2D_FalseJustOutsideTheTopEdge;
begin
  Assert.IsFalse(IsPointInBox2D(Point2D(5.0, 10.001),
    Rect2D(0.0, 0.0, 10.0, 10.0)));
end;

procedure TBoxAlgebra2DTests.IsPointInBox2D_NormalisesTheHomogeneousPoint;
begin
  { (30,30,4) is the cartesian point (7.5,7.5), which is inside; the raw
    coordinates (30,30) would be well outside. }
  Assert.IsTrue(IsPointInBox2D(MakeRawPoint2D(30.0, 30.0, 4.0),
    Rect2D(0.0, 0.0, 10.0, 10.0)),
    'the point must be homogenised before testing');
end;

procedure TBoxAlgebra2DTests.IsPointInCartesianBox2D_AgreesForCartesianInput;
begin
  Assert.IsTrue(IsPointInCartesianBox2D(Point2D(5.0, 5.0),
    Rect2D(0.0, 0.0, 10.0, 10.0)), 'inside');
  Assert.IsFalse(IsPointInCartesianBox2D(Point2D(-5.0, 5.0),
    Rect2D(0.0, 0.0, 10.0, 10.0)), 'outside');
end;

procedure TBoxAlgebra2DTests.PointOutBox2D_GrowsTheBoxRightAndUp;
begin
  CheckRect2D(0.0, 0.0, 5.0, 7.0,
    PointOutBox2D(Point2D(5.0, 7.0), Rect2D(0.0, 0.0, 1.0, 1.0)), EXACT_TOL,
    'grown to the upper right');
end;

procedure TBoxAlgebra2DTests.PointOutBox2D_GrowsTheBoxLeftAndDown;
begin
  CheckRect2D(-3.0, -4.0, 1.0, 1.0,
    PointOutBox2D(Point2D(-3.0, -4.0), Rect2D(0.0, 0.0, 1.0, 1.0)), EXACT_TOL,
    'grown to the lower left');
end;

procedure TBoxAlgebra2DTests.PointOutBox2D_LeavesTheBoxAloneForAnInteriorPoint;
begin
  CheckRect2D(0.0, 0.0, 10.0, 10.0,
    PointOutBox2D(Point2D(5.0, 5.0), Rect2D(0.0, 0.0, 10.0, 10.0)), EXACT_TOL,
    'an interior point changes nothing');
end;

procedure TBoxAlgebra2DTests.PointOutBox2D_ResultContainsThePoint;
var
  LPt: TPoint2D;
  LBox: TRect2D;
begin
  LPt := Point2D(42.0, -13.0);
  LBox := PointOutBox2D(LPt, Rect2D(0.0, 0.0, 1.0, 1.0));
  Assert.IsTrue(IsPointInBox2D(LPt, LBox),
    'the grown box must contain the point');
end;

procedure TBoxAlgebra2DTests.BoxOutBox2D_HasTheKnownUnionOfTwoDisjointBoxes;
begin
  CheckRect2D(0.0, 0.0, 3.0, 3.0,
    BoxOutBox2D(Rect2D(0.0, 0.0, 1.0, 1.0), Rect2D(2.0, 2.0, 3.0, 3.0)),
    EXACT_TOL, 'union');
end;

procedure TBoxAlgebra2DTests.BoxOutBox2D_ResultContainsBothInputs;
var
  LA, LB, LU: TRect2D;
begin
  LA := Rect2D(-5.0, 1.0, 2.0, 8.0);
  LB := Rect2D(0.0, -3.0, 12.0, 4.0);
  LU := BoxOutBox2D(LA, LB);
  Assert.IsTrue(IsBoxAllInBox2D(LA, LU), 'the union must contain box 1');
  Assert.IsTrue(IsBoxAllInBox2D(LB, LU), 'the union must contain box 2');
end;

procedure TBoxAlgebra2DTests.BoxOutBox2D_ReordersItsArguments;
begin
  { BoxOutBox2D reorders both arguments before unioning them. }
  CheckRect2D(0.0, 0.0, 10.0, 10.0,
    BoxOutBox2D(Rect2D(10.0, 10.0, 0.0, 0.0), Rect2D(2.0, 2.0, 3.0, 3.0)),
    EXACT_TOL, 'an inverted first box is reordered');
end;

procedure TBoxAlgebra2DTests.BoxOutBox2D_OfABoxWithItselfIsThatBox;
begin
  CheckRect2D(-1.0, -2.0, 3.0, 4.0,
    BoxOutBox2D(Rect2D(-1.0, -2.0, 3.0, 4.0), Rect2D(-1.0, -2.0, 3.0, 4.0)),
    EXACT_TOL, 'union with itself');
end;

procedure TBoxAlgebra2DTests.IsBoxAllInBox2D_TrueForABoxInsideItself;
var
  LBox: TRect2D;
begin
  LBox := Rect2D(0.0, 0.0, 10.0, 10.0);
  Assert.IsTrue(IsBoxAllInBox2D(LBox, LBox));
end;

procedure TBoxAlgebra2DTests.IsBoxAllInBox2D_TrueForAnInnerBox;
begin
  Assert.IsTrue(IsBoxAllInBox2D(Rect2D(2.0, 2.0, 8.0, 8.0),
    Rect2D(0.0, 0.0, 10.0, 10.0)));
end;

procedure TBoxAlgebra2DTests.IsBoxAllInBox2D_FalseForAnOuterBox;
begin
  Assert.IsFalse(IsBoxAllInBox2D(Rect2D(0.0, 0.0, 10.0, 10.0),
    Rect2D(2.0, 2.0, 8.0, 8.0)));
end;

procedure TBoxAlgebra2DTests.IsBoxAllInCartesianBox2D_AgreesForCartesianInput;
begin
  Assert.IsTrue(IsBoxAllInCartesianBox2D(Rect2D(2.0, 2.0, 8.0, 8.0),
    Rect2D(0.0, 0.0, 10.0, 10.0)), 'inner box');
  Assert.IsFalse(IsBoxAllInCartesianBox2D(Rect2D(0.0, 0.0, 10.0, 10.0),
    Rect2D(2.0, 2.0, 8.0, 8.0)), 'outer box');
end;

procedure TBoxAlgebra2DTests.IsBoxInBox2D_TrueForPartiallyOverlappingBoxes;
begin
  Assert.IsTrue(IsBoxInBox2D(Rect2D(0.0, 0.0, 10.0, 10.0),
    Rect2D(5.0, 5.0, 15.0, 15.0)));
end;

procedure TBoxAlgebra2DTests.IsBoxInBox2D_FalseForDisjointBoxes;
begin
  Assert.IsFalse(IsBoxInBox2D(Rect2D(0.0, 0.0, 1.0, 1.0),
    Rect2D(5.0, 5.0, 6.0, 6.0)));
end;

{ ---------------------------------------------------------------------------
  TDistanceAndPicking2DTests
  --------------------------------------------------------------------------- }

procedure TDistanceAndPicking2DTests.
  PointLineDistance2D_KnownPerpendicularDistance;
begin
  Assert.AreEqual(5.0, PointLineDistance2D(Point2D(0.0, 5.0),
    Point2D(-1.0, 0.0), Point2D(1.0, 0.0)), EXACT_TOL);
end;

procedure TDistanceAndPicking2DTests.
  PointLineDistance2D_IsZeroForAPointOnTheLine;
begin
  Assert.AreEqual(0.0, PointLineDistance2D(Point2D(0.5, 0.0),
    Point2D(0.0, 0.0), Point2D(1.0, 0.0)), EXACT_TOL);
end;

procedure TDistanceAndPicking2DTests.
  PointLineDistance2D_ReturnsMinusOneForADegenerateSegment;
begin
  { The implementation initialises the result to -1.0 and bails out when
    the segment has zero length. }
  Assert.AreEqual(-1.0, PointLineDistance2D(Point2D(5.0, 5.0),
    Point2D(1.0, 1.0), Point2D(1.0, 1.0)), EXACT_TOL);
end;

procedure TDistanceAndPicking2DTests.
  IsPointOnSegment2D_TrueWhenTheProjectionFallsInside;
begin
  { IsPointOnSegment2D only tests the projection parameter, not the
    perpendicular distance, so a point well off the segment still counts
    as long as its projection lies between the endpoints. }
  Assert.IsTrue(IsPointOnSegment2D(Point2D(0.5, 3.0), Point2D(0.0, 0.0),
    Point2D(1.0, 0.0)));
end;

procedure TDistanceAndPicking2DTests.
  IsPointOnSegment2D_FalseWhenTheProjectionFallsOutside;
begin
  Assert.IsFalse(IsPointOnSegment2D(Point2D(2.0, 0.0), Point2D(0.0, 0.0),
    Point2D(1.0, 0.0)));
end;

procedure TDistanceAndPicking2DTests.
  IsPointOnSegment2D_FalseForADegenerateSegment;
begin
  Assert.IsFalse(IsPointOnSegment2D(Point2D(1.0, 1.0), Point2D(1.0, 1.0),
    Point2D(1.0, 1.0)), 'a zero length segment always returns False');
end;

procedure TDistanceAndPicking2DTests.
  NearPoint2D_TrueInsideTheApertureBoxAndReportsTheDistance;
var
  LDist: TRealType;
begin
  LDist := 0.0;
  Assert.IsTrue(NearPoint2D(Point2D(0.0, 0.0), Point2D(1.0, 1.0), 2.0, LDist),
    'inside the aperture box');
  Assert.AreEqual(Sqrt(2.0), LDist, EXACT_TOL, 'reported distance');
end;

procedure TDistanceAndPicking2DTests.NearPoint2D_FalseOutsideAndReportsMaxCoord;
var
  LDist: TRealType;
begin
  LDist := 0.0;
  Assert.IsFalse(NearPoint2D(Point2D(0.0, 0.0), Point2D(5.0, 0.0), 2.0, LDist),
    'outside the aperture box');
  Assert.AreEqual(MAX_COORD_VALUE, LDist, EXACT_TOL,
    'the distance is set to MaxCoord when the point is not near');
end;

procedure TDistanceAndPicking2DTests.IsPointOnLine2D_PicksAPointCloseToTheSegment;
var
  LDist: TRealType;
  LRes: Integer;
begin
  LDist := 0.0;
  LRes := IsPointOnLine2D(Point2D(0.0, 0.0), Point2D(10.0, 0.0),
    Point2D(5.0, 0.5), LDist, 1.0, IdentityTransf2D);
  Assert.IsTrue(LRes = PICK_ONOBJECT, 'the point must be picked');
  Assert.AreEqual(0.5, LDist, EXACT_TOL, 'perpendicular distance');
end;

procedure TDistanceAndPicking2DTests.
  IsPointOnLine2D_MissesAPointFarFromTheSegment;
var
  LDist: TRealType;
  LRes: Integer;
begin
  LDist := 0.0;
  LRes := IsPointOnLine2D(Point2D(0.0, 0.0), Point2D(10.0, 0.0),
    Point2D(5.0, 50.0), LDist, 1.0, IdentityTransf2D);
  Assert.IsTrue(LRes = PICK_NOOBJECT, 'the point must not be picked');
  Assert.AreEqual(MAX_COORD_VALUE, LDist, EXACT_TOL,
    'the distance is left at MaxCoord on a miss');
end;

procedure TDistanceAndPicking2DTests.IsPointOnRect2D_PicksAPointOnTheBottomEdge;
var
  LDist: TRealType;
  LRes: Integer;
begin
  LDist := 0.0;
  LRes := IsPointOnRect2D(Rect2D(0.0, 0.0, 10.0, 10.0), Point2D(5.0, 0.0),
    LDist, 0.5, IdentityTransf2D);
  Assert.IsTrue(LRes = PICK_ONOBJECT, 'a point on the bottom edge is picked');
  Assert.AreEqual(0.0, LDist, EXACT_TOL, 'the distance to the edge is zero');
end;

procedure TDistanceAndPicking2DTests.
  IsPointOnRect2D_MissesAPointFarFromTheRectangle;
var
  LDist: TRealType;
  LRes: Integer;
begin
  LDist := 0.0;
  LRes := IsPointOnRect2D(Rect2D(0.0, 0.0, 10.0, 10.0), Point2D(50.0, 50.0),
    LDist, 0.5, IdentityTransf2D);
  Assert.IsTrue(LRes = PICK_NOOBJECT, 'a far point is not picked');
  Assert.AreEqual(MAX_COORD_VALUE, LDist, EXACT_TOL,
    'the distance is left at MaxCoord on a miss');
end;

{ ---------------------------------------------------------------------------
  TClipping2DTests
  --------------------------------------------------------------------------- }

procedure TClipping2DTests.ClipLine2D_ReportsVisibleForAFullyContainedSegment;
var
  LP1, LP2: TPoint2D;
  LRes: TClipResult;
begin
  LP1 := Point2D(2.0, 2.0);
  LP2 := Point2D(8.0, 8.0);
  LRes := ClipLine2D(Rect2D(0.0, 0.0, 10.0, 10.0), LP1, LP2);
  Assert.IsTrue(ccVisible in LRes, 'the segment is entirely inside');
  Assert.IsFalse(ccFirst in LRes, 'the first point must not be moved');
  Assert.IsFalse(ccSecond in LRes, 'the second point must not be moved');
  CheckPoint2D(2.0, 2.0, LP1, EXACT_TOL, 'first point');
  CheckPoint2D(8.0, 8.0, LP2, EXACT_TOL, 'second point');
end;

procedure TClipping2DTests.ClipLine2D_ReportsNotVisibleForAFullyOutsideSegment;
var
  LP1, LP2: TPoint2D;
  LRes: TClipResult;
begin
  LP1 := Point2D(20.0, 20.0);
  LP2 := Point2D(30.0, 30.0);
  LRes := ClipLine2D(Rect2D(0.0, 0.0, 10.0, 10.0), LP1, LP2);
  Assert.IsTrue(ccNotVisible in LRes, 'the segment is entirely outside');
  Assert.IsFalse(ccVisible in LRes, 'it must not also be reported visible');
end;

procedure TClipping2DTests.ClipLine2D_ClipsBothEndsOfACrossingSegment;
var
  LP1, LP2: TPoint2D;
  LRes: TClipResult;
begin
  LP1 := Point2D(-5.0, 5.0);
  LP2 := Point2D(15.0, 5.0);
  LRes := ClipLine2D(Rect2D(0.0, 0.0, 10.0, 10.0), LP1, LP2);
  Assert.IsTrue(ccFirst in LRes, 'the first point was clipped');
  Assert.IsTrue(ccSecond in LRes, 'the second point was clipped');
  CheckPoint2D(0.0, 5.0, LP1, EXACT_TOL, 'clipped to the left edge');
  CheckPoint2D(10.0, 5.0, LP2, EXACT_TOL, 'clipped to the right edge');
end;

procedure TClipping2DTests.ClipLine2D_ClipsOnlyTheOutsideEnd;
var
  LP1, LP2: TPoint2D;
  LRes: TClipResult;
begin
  LP1 := Point2D(5.0, 5.0);
  LP2 := Point2D(25.0, 5.0);
  LRes := ClipLine2D(Rect2D(0.0, 0.0, 10.0, 10.0), LP1, LP2);
  Assert.IsTrue(ccSecond in LRes, 'only the second point leaves the box');
  Assert.IsFalse(ccFirst in LRes, 'the first point is already inside');
  CheckPoint2D(5.0, 5.0, LP1, EXACT_TOL, 'first point is untouched');
  CheckPoint2D(10.0, 5.0, LP2, EXACT_TOL, 'clipped to the right edge');
end;

procedure TClipping2DTests.ClipLineLeftRight2D_ClipsInXAndIgnoresY;
var
  LP1, LP2: TPoint2D;
  LRes: TClipResult;
begin
  { This variant only applies the left and right half planes, so a
    segment far above the box is still clipped in X and reported. }
  LP1 := Point2D(-5.0, 50.0);
  LP2 := Point2D(15.0, 50.0);
  LRes := ClipLineLeftRight2D(Rect2D(0.0, 0.0, 10.0, 10.0), LP1, LP2);
  Assert.IsTrue(ccFirst in LRes, 'the first point was clipped in X');
  Assert.IsTrue(ccSecond in LRes, 'the second point was clipped in X');
  CheckPoint2D(0.0, 50.0, LP1, EXACT_TOL, 'Y is left alone');
  CheckPoint2D(10.0, 50.0, LP2, EXACT_TOL, 'Y is left alone');
end;

procedure TClipping2DTests.ClipLineUpBottom2D_ClipsInYAndIgnoresX;
var
  LP1, LP2: TPoint2D;
  LRes: TClipResult;
begin
  LP1 := Point2D(50.0, -5.0);
  LP2 := Point2D(50.0, 15.0);
  LRes := ClipLineUpBottom2D(Rect2D(0.0, 0.0, 10.0, 10.0), LP1, LP2);
  Assert.IsTrue(ccFirst in LRes, 'the first point was clipped in Y');
  Assert.IsTrue(ccSecond in LRes, 'the second point was clipped in Y');
  CheckPoint2D(50.0, 0.0, LP1, EXACT_TOL, 'X is left alone');
  CheckPoint2D(50.0, 10.0, LP2, EXACT_TOL, 'X is left alone');
end;

{ ---------------------------------------------------------------------------
  TGeometry3DTests
  --------------------------------------------------------------------------- }

procedure TGeometry3DTests.Point3D_SetsWToOne;
var
  LP: TPoint3D;
begin
  LP := Point3D(1.0, 2.0, 3.0);
  CheckPoint3D(1.0, 2.0, 3.0, LP, EXACT_TOL, 'Point3D');
  Assert.AreEqual(1.0, LP.W, EXACT_TOL, 'W');
end;

procedure TGeometry3DTests.Rect3D_AssignsTheTwoCorners;
var
  LR: TRect3D;
begin
  LR := Rect3D(1.0, 2.0, 3.0, 4.0, 5.0, 6.0);
  CheckPoint3D(1.0, 2.0, 3.0, LR.FirstEdge, EXACT_TOL,
    'FirstEdge is (Left, Bottom, Front)');
  CheckPoint3D(4.0, 5.0, 6.0, LR.SecondEdge, EXACT_TOL,
    'SecondEdge is (Right, Top, Back)');
end;

procedure TGeometry3DTests.VectorLength3D_KnownValue;
begin
  Assert.AreEqual(3.0, VectorLength3D(MakeVector3D(1.0, 2.0, 2.0)), EXACT_TOL);
end;

procedure TGeometry3DTests.NormalizeVector3D_ScalesToUnitLength;
var
  LV: TVector3D;
begin
  LV := NormalizeVector3D(MakeVector3D(1.0, 2.0, 2.0));
  CheckVector3D(1.0 / 3.0, 2.0 / 3.0, 2.0 / 3.0, LV, EXACT_TOL, 'normalized');
  Assert.AreEqual(1.0, VectorLength3D(LV), EXACT_TOL, 'length');
end;

procedure TGeometry3DTests.NormalizeVector3D_ZeroVectorIsReturnedUnchanged;
begin
  { Like the 2D version, a zero modulus is guarded and the input is
    returned untouched instead of dividing by zero. }
  CheckVector3D(0.0, 0.0, 0.0, NormalizeVector3D(MakeVector3D(0.0, 0.0, 0.0)),
    EXACT_TOL, 'zero vector is passed through');
end;

procedure TGeometry3DTests.Versor3D_ProducesUnitVector;
begin
  Assert.AreEqual(1.0, VectorLength3D(Versor3D(1.0, 2.0, 2.0)), EXACT_TOL);
end;

procedure TGeometry3DTests.Vector3D_IsDifferenceOfPoints;
begin
  CheckVector3D(3.0, 4.0, 5.0,
    Vector3D(Point3D(1.0, 1.0, 1.0), Point3D(4.0, 5.0, 6.0)), EXACT_TOL,
    'PTo - PFrom');
end;

procedure TGeometry3DTests.Direction3D_IsUnitAndPointsFromToPoint;
var
  LV: TVector3D;
begin
  LV := Direction3D(Point3D(0.0, 0.0, 0.0), Point3D(1.0, 2.0, 2.0));
  CheckVector3D(1.0 / 3.0, 2.0 / 3.0, 2.0 / 3.0, LV, EXACT_TOL, 'direction');
  Assert.AreEqual(1.0, VectorLength3D(LV), EXACT_TOL, 'length');
end;

procedure TGeometry3DTests.DotProduct3D_KnownValue;
begin
  Assert.AreEqual(32.0, DotProduct3D(MakeVector3D(1.0, 2.0, 3.0),
    MakeVector3D(4.0, 5.0, 6.0)), EXACT_TOL);
end;

procedure TGeometry3DTests.DotProduct3D_OfPerpendicularsIsZero;
begin
  Assert.AreEqual(0.0, DotProduct3D(MakeVector3D(1.0, 0.0, 0.0),
    MakeVector3D(0.0, 1.0, 0.0)), EXACT_TOL);
end;

procedure TGeometry3DTests.CrossProd3D_XCrossYIsZ;
begin
  CheckVector3D(0.0, 0.0, 1.0, CrossProd3D(MakeVector3D(1.0, 0.0, 0.0),
    MakeVector3D(0.0, 1.0, 0.0)), EXACT_TOL, 'X x Y');
end;

procedure TGeometry3DTests.CrossProd3D_IsAntiCommutative;
var
  LA, LB, LAB, LBA: TVector3D;
begin
  LA := MakeVector3D(1.0, 2.0, 3.0);
  LB := MakeVector3D(4.0, 5.0, 6.0);
  LAB := CrossProd3D(LA, LB);
  LBA := CrossProd3D(LB, LA);
  CheckVector3D(-LAB.X, -LAB.Y, -LAB.Z, LBA, EXACT_TOL, 'B x A = -(A x B)');
end;

procedure TGeometry3DTests.CrossProd3D_IsPerpendicularToBothOperands;
var
  LA, LB, LC: TVector3D;
begin
  LA := MakeVector3D(1.0, 2.0, 3.0);
  LB := MakeVector3D(4.0, 5.0, 6.0);
  LC := CrossProd3D(LA, LB);
  Assert.AreEqual(0.0, DotProduct3D(LC, LA), EXACT_TOL, 'perpendicular to A');
  Assert.AreEqual(0.0, DotProduct3D(LC, LB), EXACT_TOL, 'perpendicular to B');
end;

procedure TGeometry3DTests.CrossProd3D_OfParallelVectorsIsZero;
begin
  CheckVector3D(0.0, 0.0, 0.0, CrossProd3D(MakeVector3D(1.0, 2.0, 3.0),
    MakeVector3D(2.0, 4.0, 6.0)), EXACT_TOL, 'parallel operands');
end;

procedure TGeometry3DTests.PointDistance3D_KnownValue;
begin
  Assert.AreEqual(3.0, PointDistance3D(Point3D(0.0, 0.0, 0.0),
    Point3D(1.0, 2.0, 2.0)), EXACT_TOL);
end;

procedure TGeometry3DTests.IsSamePoint3D_IdenticalPointsAreSame;
begin
  Assert.IsTrue(IsSamePoint3D(Point3D(1.0, 2.0, 3.0), Point3D(1.0, 2.0, 3.0)));
  Assert.IsFalse(IsSamePoint3D(Point3D(1.0, 2.0, 3.0),
    Point3D(1.0, 2.0, 3.0 + 1E-12)), 'the comparison is exact');
end;

procedure TGeometry3DTests.IsSamePoint3D_EquivalentHomogeneousPointsAreSame;
begin
  Assert.IsTrue(IsSamePoint3D(MakeRawPoint3D(2.0, 4.0, 6.0, 2.0),
    Point3D(1.0, 2.0, 3.0)));
end;

procedure TGeometry3DTests.IsSameVector3D_ComparisonIsExactNotToleranced;
begin
  Assert.IsTrue(IsSameVector3D(MakeVector3D(1.0, 2.0, 3.0),
    MakeVector3D(1.0, 2.0, 3.0)), 'identical vectors');
  Assert.IsFalse(IsSameVector3D(MakeVector3D(1.0, 2.0, 3.0),
    MakeVector3D(1.0, 2.0, 3.0 + 1E-12)), 'the comparison is exact');
end;

procedure TGeometry3DTests.IsSameVector3D_WithDigitsRoundsBeforeComparing;
begin
  Assert.IsTrue(IsSameVector3D(MakeVector3D(1.0, 2.0, 3.0),
    MakeVector3D(1.001, 2.001, 3.001), -2), 'rounded to two decimals');
  Assert.IsFalse(IsSameVector3D(MakeVector3D(1.0, 2.0, 3.0),
    MakeVector3D(1.5, 2.0, 3.0), -2), '0.5 must survive the rounding');
end;

procedure TGeometry3DTests.IsSameTransform3D_TrueForIdenticalMatrices;
begin
  Assert.IsTrue(IsSameTransform3D(Translate3D(1.0, 2.0, 3.0),
    Translate3D(1.0, 2.0, 3.0)));
end;

procedure TGeometry3DTests.IsSameTransform3D_FalseForDifferentMatrices;
begin
  Assert.IsFalse(IsSameTransform3D(IdentityTransf3D,
    Translate3D(1.0, 0.0, 0.0)));
end;

procedure TGeometry3DTests.IsCartesianTransform3D_TrueForTranslate;
begin
  Assert.IsTrue(IsCartesianTransform3D(Translate3D(1.0, 2.0, 3.0)),
    'translate');
  Assert.IsTrue(IsCartesianTransform3D(IdentityTransf3D), 'identity');
  Assert.IsTrue(IsCartesianTransform3D(Rotate3DZ(0.4)), 'rotate about Z');
end;

procedure TGeometry3DTests.CartesianPoint3D_DividesByAPositiveW;
var
  LP: TPoint3D;
begin
  LP := CartesianPoint3D(MakeRawPoint3D(2.0, 4.0, 6.0, 2.0));
  CheckPoint3D(1.0, 2.0, 3.0, LP, EXACT_TOL, 'homogeneous divide');
  Assert.AreEqual(1.0, LP.W, EXACT_TOL, 'W is normalised to 1.0');
end;

procedure TGeometry3DTests.CartesianPoint3D_LeavesANegativeWUntouched;
var
  LP: TPoint3D;
begin
  { The 3D guard is (P.W <> 1.0) and (P.W > 1.0E-8), so unlike the 2D
    version a negative W is NOT divided out. This asserts the behaviour
    as implemented. }
  LP := CartesianPoint3D(MakeRawPoint3D(2.0, 4.0, 6.0, -2.0));
  CheckPoint3D(2.0, 4.0, 6.0, LP, EXACT_TOL, 'negative W is passed through');
  Assert.AreEqual(-2.0, LP.W, EXACT_TOL, 'W is left alone');
end;

procedure TGeometry3DTests.CartesianPoint3D_LeavesUnitWUntouched;
begin
  CheckPoint3D(2.0, 4.0, 6.0, CartesianPoint3D(Point3D(2.0, 4.0, 6.0)),
    EXACT_TOL, 'W = 1 is a no-op');
end;

procedure TGeometry3DTests.ReOrderRect3D_SwapsAllThreeAxes;
var
  LR: TRect3D;
begin
  LR := ReOrderRect3D(Rect3D(10.0, 20.0, 30.0, 1.0, 2.0, 3.0));
  CheckPoint3D(1.0, 2.0, 3.0, LR.FirstEdge, EXACT_TOL, 'FirstEdge');
  CheckPoint3D(10.0, 20.0, 30.0, LR.SecondEdge, EXACT_TOL, 'SecondEdge');
end;

procedure TGeometry3DTests.ReOrderRect3D_LeavesAnOrderedBoxAlone;
var
  LR: TRect3D;
begin
  LR := ReOrderRect3D(Rect3D(1.0, 2.0, 3.0, 10.0, 20.0, 30.0));
  CheckPoint3D(1.0, 2.0, 3.0, LR.FirstEdge, EXACT_TOL, 'FirstEdge');
  CheckPoint3D(10.0, 20.0, 30.0, LR.SecondEdge, EXACT_TOL, 'SecondEdge');
end;

procedure TGeometry3DTests.IdentityTransf3D_LeavesAPointUnchanged;
begin
  CheckPoint3D(3.0, -4.0, 5.0,
    TransformPoint3D(Point3D(3.0, -4.0, 5.0), IdentityTransf3D), EXACT_TOL,
    'identity');
end;

procedure TGeometry3DTests.Translate3D_MovesAPoint;
begin
  CheckPoint3D(1.0, 2.0, 3.0,
    TransformPoint3D(Point3D(0.0, 0.0, 0.0), Translate3D(1.0, 2.0, 3.0)),
    EXACT_TOL, 'translated');
end;

procedure TGeometry3DTests.Translate3D_ThenOppositeTranslateRoundTrips;
var
  LP: TPoint3D;
begin
  LP := TransformPoint3D(TransformPoint3D(Point3D(1.5, -2.5, 3.5),
    Translate3D(10.0, 20.0, 30.0)), Translate3D(-10.0, -20.0, -30.0));
  CheckPoint3D(1.5, -2.5, 3.5, LP, EXACT_TOL, 'translate then untranslate');
end;

procedure TGeometry3DTests.Scale3D_ScalesAPoint;
begin
  CheckPoint3D(2.0, 6.0, 12.0,
    TransformPoint3D(Point3D(1.0, 2.0, 3.0), Scale3D(2.0, 3.0, 4.0)),
    EXACT_TOL, 'scaled');
end;

procedure TGeometry3DTests.Rotate3DZ_QuarterTurnMapsXAxisOntoYAxis;
begin
  CheckPoint3D(0.0, 1.0, 0.0,
    TransformPoint3D(Point3D(1.0, 0.0, 0.0), Rotate3DZ(Pi / 2.0)), TRIG_TOL,
    '+X about Z');
end;

procedure TGeometry3DTests.Rotate3DX_QuarterTurnMapsYAxisOntoZAxis;
begin
  CheckPoint3D(0.0, 0.0, 1.0,
    TransformPoint3D(Point3D(0.0, 1.0, 0.0), Rotate3DX(Pi / 2.0)), TRIG_TOL,
    '+Y about X');
end;

procedure TGeometry3DTests.Rotate3DY_QuarterTurnMapsZAxisOntoXAxis;
begin
  CheckPoint3D(1.0, 0.0, 0.0,
    TransformPoint3D(Point3D(0.0, 0.0, 1.0), Rotate3DY(Pi / 2.0)), TRIG_TOL,
    '+Z about Y');
end;

procedure TGeometry3DTests.Rotate3DZ_ByAngleThenByMinusAngleRoundTrips;
var
  LP: TPoint3D;
begin
  LP := TransformPoint3D(TransformPoint3D(Point3D(3.0, -7.0, 2.0),
    Rotate3DZ(0.9)), Rotate3DZ(-0.9));
  CheckPoint3D(3.0, -7.0, 2.0, LP, TRIG_TOL, 'rotate then unrotate');
end;

procedure TGeometry3DTests.MultiplyTransform3D_IdentityIsNeutral;
var
  LM: TTransf3D;
begin
  LM := MultiplyTransform3D(Translate3D(1.0, 2.0, 3.0), Scale3D(2.0, 3.0, 4.0));
  Assert.IsTrue(IsSameTransform3D(LM,
    MultiplyTransform3D(LM, IdentityTransf3D)), 'M * I');
  Assert.IsTrue(IsSameTransform3D(LM,
    MultiplyTransform3D(IdentityTransf3D, LM)), 'I * M');
end;

procedure TGeometry3DTests.MultiplyTransform3D_AppliesTheFirstMatrixFirst;
var
  LComposed, LSequential: TPoint3D;
begin
  LComposed := TransformPoint3D(Point3D(1.0, 2.0, 3.0),
    MultiplyTransform3D(Translate3D(10.0, 0.0, 0.0), Scale3D(2.0, 2.0, 2.0)));
  LSequential := TransformPoint3D(TransformPoint3D(Point3D(1.0, 2.0, 3.0),
    Translate3D(10.0, 0.0, 0.0)), Scale3D(2.0, 2.0, 2.0));
  CheckPoint3D(LSequential.X, LSequential.Y, LSequential.Z, LComposed,
    TRIG_TOL, 'composed equals sequential (M1 first)');
  { (1,2,3) -> translate -> (11,2,3) -> scale x2 -> (22,4,6). }
  CheckPoint3D(22.0, 4.0, 6.0, LComposed, TRIG_TOL, 'known result');
end;

procedure TGeometry3DTests.TransformVector3D_IgnoresTheTranslationPart;
begin
  CheckVector3D(1.0, 2.0, 3.0,
    TransformVector3D(MakeVector3D(1.0, 2.0, 3.0),
    Translate3D(100.0, 100.0, 100.0)), EXACT_TOL, 'a vector is not translated');
end;

procedure TGeometry3DTests.TransformRect3D_TransformsBothCornersIndependently;
var
  LR: TRect3D;
begin
  LR := TransformRect3D(Rect3D(0.0, 0.0, 0.0, 10.0, 10.0, 10.0),
    Translate3D(1.0, 2.0, 3.0));
  CheckPoint3D(1.0, 2.0, 3.0, LR.FirstEdge, EXACT_TOL, 'FirstEdge');
  CheckPoint3D(11.0, 12.0, 13.0, LR.SecondEdge, EXACT_TOL, 'SecondEdge');
end;

procedure TGeometry3DTests.InvertTransform3D_RoundTripsAPointForADiagonalScale;
var
  LM, LInv: TTransf3D;
  LP: TPoint3D;
begin
  { Scale3D(2,4,5) has determinant 40, so it takes the normal branch of
    InvertTransform3D. }
  LM := Scale3D(2.0, 4.0, 5.0);
  LInv := InvertTransform3D(LM);
  Assert.AreEqual(0.5, LInv[1, 1], EXACT_TOL, '[1,1]');
  Assert.AreEqual(0.25, LInv[2, 2], EXACT_TOL, '[2,2]');
  Assert.AreEqual(0.2, LInv[3, 3], EXACT_TOL, '[3,3]');
  LP := TransformPoint3D(TransformPoint3D(Point3D(3.0, -7.0, 11.0), LM), LInv);
  CheckPoint3D(3.0, -7.0, 11.0, LP, TRIG_TOL, 'scale then unscale');
end;

procedure TGeometry3DTests.InvertTransform3D_OfASingularMatrixIsTheNullMatrix;
begin
  { A zero determinant makes InvertTransform3D return NullTransf3D. }
  Assert.IsTrue(IsSameTransform3D(InvertTransform3D(Scale3D(0.0, 0.0, 0.0)),
    NullTransf3D), 'a singular matrix must invert to NullTransf3D');
end;

{ ---------------------------------------------------------------------------
  TDimensionConversionTests
  --------------------------------------------------------------------------- }

procedure TDimensionConversionTests.Point2DToPoint3D_ZerosZAndKeepsW;
var
  LP: TPoint3D;
begin
  LP := Point2DToPoint3D(MakeRawPoint2D(3.0, 4.0, 2.0));
  CheckPoint3D(3.0, 4.0, 0.0, LP, EXACT_TOL, 'Z is zeroed');
  Assert.AreEqual(2.0, LP.W, EXACT_TOL, 'W is carried over verbatim');
end;

procedure TDimensionConversionTests.
  Point3DToPoint2D_DropsZAndAlwaysReturnsUnitW;
var
  LP: TPoint2D;
begin
  LP := Point3DToPoint2D(Point3D(3.0, 4.0, 5.0));
  CheckPoint2D(3.0, 4.0, LP, EXACT_TOL, 'Z is dropped');
  Assert.AreEqual(1.0, LP.W, EXACT_TOL, 'W is always set to 1.0');
end;

procedure TDimensionConversionTests.Point3DToPoint2D_DividesByANonUnitW;
var
  LP: TPoint2D;
begin
  LP := Point3DToPoint2D(MakeRawPoint3D(6.0, 8.0, 10.0, 2.0));
  CheckPoint2D(3.0, 4.0, LP, EXACT_TOL, 'homogeneous divide');
  Assert.AreEqual(1.0, LP.W, EXACT_TOL, 'W');
end;

procedure TDimensionConversionTests.
  Point2DToPoint3D_Point3DToPoint2D_RoundTrips;
var
  LP: TPoint2D;
begin
  LP := Point3DToPoint2D(Point2DToPoint3D(Point2D(3.5, -4.5)));
  CheckPoint2D(3.5, -4.5, LP, EXACT_TOL, 'round trip through 3D');
  Assert.AreEqual(1.0, LP.W, EXACT_TOL, 'W');
end;

procedure TDimensionConversionTests.Rect2DToRect3D_ZerosBothZCoordinates;
var
  LR: TRect3D;
begin
  LR := Rect2DToRect3D(Rect2D(1.0, 2.0, 3.0, 4.0));
  CheckPoint3D(1.0, 2.0, 0.0, LR.FirstEdge, EXACT_TOL, 'FirstEdge');
  CheckPoint3D(3.0, 4.0, 0.0, LR.SecondEdge, EXACT_TOL, 'SecondEdge');
end;

procedure TDimensionConversionTests.Rect3DToRect2D_DropsBothZCoordinates;
begin
  CheckRect2D(1.0, 2.0, 4.0, 5.0,
    Rect3DToRect2D(Rect3D(1.0, 2.0, 3.0, 4.0, 5.0, 6.0)), EXACT_TOL,
    'Z is dropped from both corners');
end;

initialization

TDUnitX.RegisterTestFixture(TAngleConversionTests);
TDUnitX.RegisterTestFixture(TPoint2DAndVector2DTests);
TDUnitX.RegisterTestFixture(TRect2DTests);
TDUnitX.RegisterTestFixture(TIntegerConversionTests);
TDUnitX.RegisterTestFixture(TTransform2DTests);
TDUnitX.RegisterTestFixture(TBoxAlgebra2DTests);
TDUnitX.RegisterTestFixture(TDistanceAndPicking2DTests);
TDUnitX.RegisterTestFixture(TClipping2DTests);
TDUnitX.RegisterTestFixture(TGeometry3DTests);
TDUnitX.RegisterTestFixture(TDimensionConversionTests);

end.
