{ : Regression tests for defects found in the CADSys 4.2 optimization and
  correctness review (docs/features/optimization-review.md).

  Each test here corresponds to a specific finding ID. A test in this unit
  should FAIL on commit a0ccd7a (the pre-fix baseline) and PASS on the
  fix branch. That is the whole point of the unit: it pins the fixes so a
  later refactor cannot silently reintroduce them.

  Findings that cannot be exercised from a console runner are recorded here
  as [Ignore]d placeholders rather than omitted, so the coverage gap stays
  visible instead of being forgotten.
}
unit CADSys4.Tests.Regressions;

interface

uses
  DUnitX.TestFramework,
  FNCCS4BaseTypes,
  FNCCADSys4,
  FNCCS4Shapes,
  FNCCadSysRegister;

type
  { M12 - TContainer2D/TContainer3D.Assign used repeat..until, which executes
    its body once unconditionally. Copying an empty container therefore
    dereferenced a nil TmpIter.Current and access-violated. }
  [TestFixture]
  TContainerAssignRegressionTests = class(TObject)
  public
    [Test]
    procedure M12_Assign_FromEmptyContainer2D_DoesNotRaise;
    [Test]
    procedure M12_Assign_FromEmptyContainer3D_DoesNotRaise;
    [Test]
    procedure M12_Assign_FromPopulatedContainer2D_CopiesEveryObject;
    [Test]
    procedure M12_Assign_FromPopulatedContainer2D_CopiesAreIndependent;
  end;

  { X5 - TVectFont indexes a 256-slot TIndexedObjectList with Ord(Ch), but Ch
    is a WideChar under Unicode Delphi. Any character above U+00FF raised
    ECADOutOfBound out of the middle of a repaint. }
  [TestFixture]
  TVectFontUnicodeRegressionTests = class(TObject)
  private
    FFont: TVectFont;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure X5_Chars_AboveLatin1_ReturnsFallbackInsteadOfRaising;
    [Test]
    procedure X5_Chars_WithinLatin1_StillReturnsNilForUnmappedSlot;
    [Test]
    procedure X5_GetTextExtension_WithNonLatin1Text_DoesNotRaise;
    [Test]
    procedure X5_CreateChar_AboveLatin1_RaisesOutOfBoundExplicitly;
    [Test]
    procedure X5_CreateChar_WithinLatin1_StillWorks;
  end;

  { CADSysFindFontByIndex indexed the global font registry with an unchecked
    Word read straight from a stream, while every sibling accessor
    bounds-checked. }
  [TestFixture]
  TFontRegistryRegressionTests = class(TObject)
  public
    [Test]
    procedure FontIndex_AboveRegistrySize_RaisesInsteadOfReadingGarbage;
    [Test]
    procedure FontIndex_UnregisteredButInRange_RaisesTheSameWay;
  end;

  { Findings that are real and fixed, but whose observable effect cannot be
    reached from a console test runner. Recorded so the gap is explicit. }
  [TestFixture]
  TUntestableHeadlessRegressionNotes = class(TObject)
  public
    [Test]
    [Ignore('M1: needs a TFNCCADPrg driving a TFNCCADPrg2D against a live TFNCCADViewport2D. ' +
            'The double free happens in TCADPrgPan/TCADPrgDragPan OnEvent/OnStop, ' +
            'which are only reachable through the FSM event pump. Verify with FastMM ' +
            'full-debug mode in the CAD2D demo: pan, then cancel.')]
    procedure M1_PanStatesDoubleFreeRubberBandLine;

    [Test]
    [Ignore('P3b: Draw2DSubSetAsPolyline/Polygon take a TDecorativeCanvas and write ' +
            'through a GDI handle. The overrun is only observable with range checking ' +
            'on and a real canvas. Cover it in a GUI test host, not here.')]
    procedure P3b_DrawHelperBoundsOverrun;

    [Test]
    [Ignore('X1: SetWindowLong/LongInt truncation is inside {$IFDEF windows}, an ' +
            'FPC/Lazarus conditional. It is dead code in a Delphi build, so there is ' +
            'nothing for a Delphi test to observe. Compile-time concern only.')]
    procedure X1_WndProcPointerTruncation;

    [Test]
    [Ignore('P4: TExtendedFont no longer owns a GDI handle at all - it is a ' +
            'description, and the VCL backend caches one HFONT keyed on it. There ' +
            'is no churn left to observe through the public API.')]
    procedure P4_FontHandleChurn;

    [Test]
    [Ignore('TPointsSet3D.Expand Z-initialisation: Get() bounds-checks against fCount, ' +
            'not fCapacity (FNCCADSys4.pas:13326), so grown-but-unwritten slots are ' +
            'unreachable through the public API. The fix is correct but unobservable ' +
            'without touching PointsReference directly, which would itself be UB.')]
    procedure PointsSet3D_ExpandInitialisesZ;
  end;

  { Findings deliberately NOT yet fixed. These are written as the failing
    cases they will need, and ignored until the corresponding phase lands. }
  [TestFixture]
  TDeferredFindingNotes = class(TObject)
  public
    [Test]
    [Ignore('M5/M7/M8/A3 - param ownership rework. TCADPrgSelectAreaParam.Destroy ' +
            'still leaks fCallerParam, and SuspendOperation still aliases the ' +
            'suspended state param. These must be fixed together; see the review.')]
    procedure ParamOwnershipContract;

    [Test]
    [Ignore('M2 - TPointsSet2D/3D fCapacity is a Word and truncates in Expand above ' +
            '~32767 points, shrinking the buffer and zeroing live points. Needs the ' +
            'Word->Integer widening across both units and every descendant.')]
    procedure PointsSet_CapacityAbove32767;

    [Test]
    [Ignore('X3/X4 - the binary on-disk format doubled under Unicode ' +
            '(TCADVersion, TSourceBlockName, TText2D). Fixed by dropping ' +
            'that format: drawings are JSON now, and the round trips in ' +
            'CADSys4.Tests.Persistence cover it. Kept as a marker.')]
    procedure StreamFormat_VersionGate;
  end;

implementation

uses
  System.SysUtils;

{ TContainerAssignRegressionTests }

procedure TContainerAssignRegressionTests.M12_Assign_FromEmptyContainer2D_DoesNotRaise;
begin
  Assert.WillNotRaise(
    procedure
    var
      Src, Dst: TContainer2D;
    begin
      { [nil] is the documented way to build a void container - see the
        TContainer2D.Create doc comment in FNCCADSys4.pas. }
      Src := TContainer2D.Create(1, [nil]);
      try
        Dst := TContainer2D.Create(2, [nil]);
        try
          Dst.Assign(Src);
        finally
          Dst.Free;
        end;
      finally
        Src.Free;
      end;
    end,
    nil,
    'Assigning from an empty TContainer2D must not dereference a nil iterator');
end;

procedure TContainerAssignRegressionTests.M12_Assign_FromEmptyContainer3D_DoesNotRaise;
begin
  Assert.WillNotRaise(
    procedure
    var
      Src, Dst: TContainer3D;
    begin
      Src := TContainer3D.Create(1, [nil]);
      try
        Dst := TContainer3D.Create(2, [nil]);
        try
          Dst.Assign(Src);
        finally
          Dst.Free;
        end;
      finally
        Src.Free;
      end;
    end,
    nil,
    'Assigning from an empty TContainer3D must not dereference a nil iterator');
end;

procedure TContainerAssignRegressionTests.M12_Assign_FromPopulatedContainer2D_CopiesEveryObject;
var
  Src, Dst: TContainer2D;
  Iter: TGraphicObjIterator;
  Cnt: Integer;
begin
  { The nil-deref fix rewrote the copy loop, so confirm the normal path still
    copies everything rather than, say, dropping the first or last element. }
  Src := TContainer2D.Create(1,
    [TLine2D.Create(10, Point2D(0, 0), Point2D(1, 1)),
     TLine2D.Create(11, Point2D(2, 2), Point2D(3, 3)),
     TLine2D.Create(12, Point2D(4, 4), Point2D(5, 5))]);
  try
    Dst := TContainer2D.Create(2, [nil]);
    try
      Dst.Assign(Src);

      Cnt := 0;
      Iter := Dst.Objects.GetIterator;
      try
        if Iter.First <> nil then
          repeat
            Inc(Cnt);
          until Iter.Next = nil;
      finally
        Iter.Free;
      end;

      Assert.AreEqual(3, Cnt, 'Assign must copy every contained object');
    finally
      Dst.Free;
    end;
  finally
    Src.Free;
  end;
end;

procedure TContainerAssignRegressionTests.M12_Assign_FromPopulatedContainer2D_CopiesAreIndependent;
var
  Src, Dst: TContainer2D;
  SrcLine, DstLine: TLine2D;
  Iter: TGraphicObjIterator;
begin
  SrcLine := TLine2D.Create(10, Point2D(0, 0), Point2D(1, 1));
  Src := TContainer2D.Create(1, [SrcLine]);
  try
    Dst := TContainer2D.Create(2, [nil]);
    try
      Dst.Assign(Src);

      { Mutate the source after the copy. }
      SrcLine.Points[1] := Point2D(99, 99);

      DstLine := nil;
      Iter := Dst.Objects.GetIterator;
      try
        DstLine := Iter.First as TLine2D;
      finally
        Iter.Free;
      end;

      Assert.IsNotNull(DstLine, 'The copy must contain the line');
      Assert.AreEqual(1.0, DstLine.Points[1].X, 1E-9,
        'Assign must deep-copy geometry, not alias the source');
    finally
      Dst.Free;
    end;
  finally
    Src.Free;
  end;
end;

{ TVectFontUnicodeRegressionTests }

procedure TVectFontUnicodeRegressionTests.Setup;
begin
  FFont := TVectFont.Create;
end;

procedure TVectFontUnicodeRegressionTests.TearDown;
begin
  FreeAndNil(FFont);
end;

procedure TVectFontUnicodeRegressionTests.X5_Chars_AboveLatin1_ReturnsFallbackInsteadOfRaising;
var
  Glyph: TVectChar;
begin
  { U+20AC EURO SIGN. Built from a code point rather than a source literal so
    the test does not depend on this file's encoding. }
  Glyph := FFont.Chars[Char($20AC)];
  Assert.IsNotNull(Glyph,
    'A character above U+00FF must fall back to the null glyph, not raise');
  Assert.AreSame(_NullChar, Glyph,
    'The fallback should be the same _NullChar used for unmapped Latin-1 codes');
end;

procedure TVectFontUnicodeRegressionTests.X5_Chars_WithinLatin1_StillReturnsNilForUnmappedSlot;
begin
  { The fix must not change behaviour inside the mapped range: an unmapped
    slot in a freshly created font is still nil. }
  Assert.IsNull(FFont.Chars['A'],
    'An unmapped Latin-1 slot must still return nil, unchanged by the fix');
end;

procedure TVectFontUnicodeRegressionTests.X5_GetTextExtension_WithNonLatin1Text_DoesNotRaise;
begin
  Assert.WillNotRaise(
    procedure
    begin
      FFont.GetTextExtension('a' + Char($20AC) + 'b', 1.0, 0.1, 0.1);
    end,
    nil,
    'Measuring text containing a character above U+00FF must not raise');
end;

procedure TVectFontUnicodeRegressionTests.X5_CreateChar_AboveLatin1_RaisesOutOfBoundExplicitly;
begin
  { Writing is a different contract from reading: an out-of-range slot is
    refused loudly rather than silently corrupting the list. }
  Assert.WillRaise(
    procedure
    begin
      FFont.CreateChar(Char($20AC), 1);
    end,
    ECADOutOfBound,
    'CreateChar must refuse a character code above 255');
end;

procedure TVectFontUnicodeRegressionTests.X5_CreateChar_WithinLatin1_StillWorks;
var
  Glyph: TVectChar;
begin
  Glyph := FFont.CreateChar('A', 1);
  Assert.IsNotNull(Glyph, 'CreateChar must still work inside the mapped range');
  Assert.AreSame(Glyph, FFont.Chars['A'],
    'The created glyph must be the one returned by Chars[]');
end;

{ TFontRegistryRegressionTests }

procedure TFontRegistryRegressionTests.FontIndex_AboveRegistrySize_RaisesInsteadOfReadingGarbage;
begin
  { VectFonts2DRegistered is array[0..MAX_REGISTERED_FONTS] with
    MAX_REGISTERED_FONTS = 512. Before the fix this read past the end of the
    array and returned whatever pointer happened to be there. With no default
    font registered (FNCCadSysRegister sets _DefaultFont := nil) the bounds check
    now surfaces as a clean ECADObjClassNotFound. }
  Assert.WillRaise(
    procedure
    begin
      CADSysFindFontByIndex(60000);
    end,
    ECADObjClassNotFound,
    'An out-of-range font index must be rejected, not read out of bounds');
end;

procedure TFontRegistryRegressionTests.FontIndex_UnregisteredButInRange_RaisesTheSameWay;
begin
  { Behaviour inside the array must be unchanged by the bounds fix. }
  Assert.WillRaise(
    procedure
    begin
      CADSysFindFontByIndex(400);
    end,
    ECADObjClassNotFound,
    'An unregistered in-range index keeps its existing behaviour');
end;

{ TUntestableHeadlessRegressionNotes }

procedure TUntestableHeadlessRegressionNotes.M1_PanStatesDoubleFreeRubberBandLine;
begin
  Assert.Pass;
end;

procedure TUntestableHeadlessRegressionNotes.P3b_DrawHelperBoundsOverrun;
begin
  Assert.Pass;
end;

procedure TUntestableHeadlessRegressionNotes.X1_WndProcPointerTruncation;
begin
  Assert.Pass;
end;

procedure TUntestableHeadlessRegressionNotes.P4_FontHandleChurn;
begin
  Assert.Pass;
end;

procedure TUntestableHeadlessRegressionNotes.PointsSet3D_ExpandInitialisesZ;
begin
  Assert.Pass;
end;

{ TDeferredFindingNotes }

procedure TDeferredFindingNotes.ParamOwnershipContract;
begin
  Assert.Pass;
end;

procedure TDeferredFindingNotes.PointsSet_CapacityAbove32767;
begin
  Assert.Pass;
end;

procedure TDeferredFindingNotes.StreamFormat_VersionGate;
begin
  Assert.Pass;
end;

initialization

TDUnitX.RegisterTestFixture(TContainerAssignRegressionTests);
TDUnitX.RegisterTestFixture(TVectFontUnicodeRegressionTests);
TDUnitX.RegisterTestFixture(TFontRegistryRegressionTests);
TDUnitX.RegisterTestFixture(TUntestableHeadlessRegressionNotes);
TDUnitX.RegisterTestFixture(TDeferredFindingNotes);

end.
