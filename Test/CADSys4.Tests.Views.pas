{ : DUnitX tests for saved views (unit FNCCS4Views).

  Scope: TCADViewSpec as a value - its defaults, its JSON round trip, the
  layer list's text form, and the relative-in-the-file, absolute-in-memory
  rule for the drawing path.

  Not covered here: TFNCCADViewport.CaptureView and ApplyView. Those need a
  live viewport, and nothing in this suite instantiates one - a
  TTMSFNCCustomControl wants a window and a canvas, which a console test
  runner has no business creating. They are exercised by both demos
  instead, through Save view and Open view.
}
unit CADSys4.Tests.Views;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  DUnitX.TestFramework,
  FNCCS4BaseTypes,
  FNCCS4JSON,
  FNCCS4Views;

type
  [TestFixture]
  TCADViewSpecTests = class(TObject)
  private
    fDir: String;
    function TempFile(const AName: String): String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ADefaultViewOverridesNothing;
    [Test]
    procedure ARoundTripThroughJSONKeepsEveryField;
    [Test]
    procedure TheLayerListSurvivesItsTextForm;
    [Test]
    procedure ADamagedLayerListIsSkippedRatherThanFatal;
    [Test]
    procedure ADocumentOfAnotherKindIsRefused;
    [Test]
    procedure WithNoOverrideTheLayerListIsNotWrittenAtAll;
    [Test]
    procedure TheDrawingIsRelativeInTheFileAndAbsoluteInMemory;
    [Test]
    procedure AViewOfAMissingDrawingStillLoads;
  end;

implementation

function TCADViewSpecTests.TempFile(const AName: String): String;
begin
  Result := TPath.Combine(fDir, AName);
end;

procedure TCADViewSpecTests.Setup;
begin
  fDir := TPath.Combine(TPath.GetTempPath, 'cadsysfnc-views-'
    + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(fDir);
end;

procedure TCADViewSpecTests.TearDown;
begin
  if (fDir <> '') and TDirectory.Exists(fDir) then
    TDirectory.Delete(fDir, True);
end;

procedure TCADViewSpecTests.ADefaultViewOverridesNothing;
var
  TmpView: TCADViewSpec;
begin
  TmpView := TCADViewSpec.Default;
  Assert.IsFalse(TmpView.UseLayerOverride,
    'a view that was never told about layers must not claim to know');
  Assert.IsFalse(TmpView.Locked);
  Assert.AreEqual('', TmpView.DrawingFile);
  { The homogeneous components matter: the viewport transform multiplies
    by them, and a zero there puts the drawing nowhere. }
  Assert.AreEqual(1.0, TmpView.Window.W1, 1E-9);
  Assert.AreEqual(1.0, TmpView.Window.W2, 1E-9);
end;

procedure TCADViewSpecTests.ARoundTripThroughJSONKeepsEveryField;
var
  TmpView, TmpBack: TCADViewSpec;
  TmpDoc: TJSONObject;
begin
  TmpView := TCADViewSpec.Default;
  TmpView.Name := 'Detail A';
  TmpView.DrawingFile := 'plans\house.json';
  TmpView.Window.Left := -12.5;
  TmpView.Window.Bottom := -7.25;
  TmpView.Window.Right := 130.75;
  TmpView.Window.Top := 64.5;
  TmpView.AspectRatio := 1.0;
  TmpView.Locked := True;
  TmpView.UseLayerOverride := True;
  TmpView.HiddenLayers := [0, 3, 255];

  TmpDoc := TmpView.SaveToJSON;
  try
    TmpBack.LoadFromJSON(TmpDoc);
  finally
    TmpDoc.Free;
  end;

  Assert.AreEqual('Detail A', TmpBack.Name);
  Assert.AreEqual('plans\house.json', TmpBack.DrawingFile);
  Assert.AreEqual(-12.5, TmpBack.Window.Left, 1E-9);
  Assert.AreEqual(-7.25, TmpBack.Window.Bottom, 1E-9);
  Assert.AreEqual(130.75, TmpBack.Window.Right, 1E-9);
  Assert.AreEqual(64.5, TmpBack.Window.Top, 1E-9);
  Assert.AreEqual(1.0, TmpBack.AspectRatio, 1E-9);
  Assert.IsTrue(TmpBack.Locked);
  Assert.IsTrue(TmpBack.UseLayerOverride);
  Assert.IsTrue(0 in TmpBack.HiddenLayers, 'layer 0');
  Assert.IsTrue(3 in TmpBack.HiddenLayers, 'layer 3');
  Assert.IsTrue(255 in TmpBack.HiddenLayers, 'layer 255');
  Assert.IsFalse(1 in TmpBack.HiddenLayers, 'layer 1 was never hidden');
end;

procedure TCADViewSpecTests.TheLayerListSurvivesItsTextForm;
var
  TmpSet: TCADLayerSet;
begin
  { Both ends of the range, because a set of Byte and a loop to 255 is
    exactly where an off-by-one lives. }
  TmpSet := CADTextToLayerSet(CADLayerSetToText([0, 17, 255]));
  Assert.IsTrue(0 in TmpSet);
  Assert.IsTrue(17 in TmpSet);
  Assert.IsTrue(255 in TmpSet);
  Assert.IsFalse(16 in TmpSet);
  Assert.AreEqual('', CADLayerSetToText([]), 'an empty set is an empty string');
  Assert.IsTrue(CADTextToLayerSet('') = [], 'and back again');
end;

procedure TCADViewSpecTests.ADamagedLayerListIsSkippedRatherThanFatal;
var
  TmpSet: TCADLayerSet;
begin
  TmpSet := CADTextToLayerSet('3, oops, 999, -1, 7');
  Assert.IsTrue(3 in TmpSet);
  Assert.IsTrue(7 in TmpSet);
  Assert.IsFalse(0 in TmpSet, 'a number out of range must not wrap to 0');
end;

procedure TCADViewSpecTests.ADocumentOfAnotherKindIsRefused;
var
  TmpDoc: TJSONObject;
  TmpView: TCADViewSpec;
begin
  TmpDoc := TJSONObject.Create;
  try
    JSetStr(TmpDoc, 'format', CADSysJSONFormat);
    JSetStr(TmpDoc, 'version', CADSysJSONVersion);
    JSetStr(TmpDoc, 'kind', 'drawing');
    Assert.WillRaise(
      procedure
      begin
        TmpView.LoadFromJSON(TmpDoc);
      end, ECADViewError, 'a drawing is not a view');
  finally
    TmpDoc.Free;
  end;
end;

procedure TCADViewSpecTests.WithNoOverrideTheLayerListIsNotWrittenAtAll;
var
  TmpView: TCADViewSpec;
  TmpDoc: TJSONObject;
begin
  TmpView := TCADViewSpec.Default;
  TmpView.HiddenLayers := [5];
  TmpView.UseLayerOverride := False;
  TmpDoc := TmpView.SaveToJSON;
  try
    Assert.IsFalse(JHas(TmpDoc, 'hiddenLayers'),
      'a set nobody asked for must not travel');
  finally
    TmpDoc.Free;
  end;
end;

procedure TCADViewSpecTests.TheDrawingIsRelativeInTheFileAndAbsoluteInMemory;
var
  TmpView, TmpBack: TCADViewSpec;
  TmpViewFile, TmpDrawing, TmpText: String;
begin
  TmpViewFile := TempFile('overview' + CADViewExtension);
  TmpDrawing := TempFile('house.json');
  TFile.WriteAllText(TmpDrawing, '{}');

  TmpView := TCADViewSpec.Default;
  TmpView.DrawingFile := TmpDrawing;
  TmpView.SaveToFile(TmpViewFile);

  TmpText := TFile.ReadAllText(TmpViewFile);
  Assert.IsFalse(TmpText.Contains(fDir),
    'the file must not hold the folder it happens to live in today');
  Assert.IsTrue(TmpText.Contains('house.json'));

  TmpBack.LoadFromFile(TmpViewFile);
  Assert.AreEqual(TmpDrawing, TmpBack.DrawingFile,
    'and in memory it is absolute again');
  Assert.IsTrue(TmpBack.DrawingExists);
end;

procedure TCADViewSpecTests.AViewOfAMissingDrawingStillLoads;
var
  TmpView, TmpBack: TCADViewSpec;
  TmpViewFile: String;
begin
  TmpViewFile := TempFile('gone' + CADViewExtension);
  TmpView := TCADViewSpec.Default;
  TmpView.DrawingFile := TempFile('never-written.json');
  TmpView.SaveToFile(TmpViewFile);

  { Opening must succeed - a view whose drawing has moved is still a view,
    and the application is what tells the user about it. }
  TmpBack.LoadFromFile(TmpViewFile);
  Assert.IsFalse(TmpBack.DrawingExists);
  Assert.IsTrue(TmpBack.DrawingFile <> '');
end;

initialization

TDUnitX.RegisterTestFixture(TCADViewSpecTests);

end.
