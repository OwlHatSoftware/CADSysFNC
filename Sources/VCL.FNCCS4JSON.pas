{: JSON helpers for the CADSys persistence.

   Drawings, libraries and vector fonts are stored as JSON. This unit
   holds the small conversion layer used by every SaveToJSON and
   CreateFromJSON method in the library: typed getters that survive a
   missing or mistyped member, writers that keep the file compact, and
   the geometric value types.

   Conventions used by the whole format:

   <LI=A 2D point is an array, <I=[x, y]>, or <I=[x, y, w]> when the
   homogeneous coordinate is not 1. A 3D point is <I=[x, y, z]> or
   <I=[x, y, z, w]>. A vector is <I=[x, y, z]>.>
   <LI=A transform is a flat array in row order: 9 numbers for 2D, 16
   for 3D.>
   <LI=Enumerated values are written as their Pascal identifiers, so a
   file stays readable and a new value can be added without shifting the
   meaning of the old ones.>
   <LI=A member that is missing on load takes its default. Reading is
   deliberately lenient; only a structurally wrong file (a member that
   must be an object or an array and is not) raises
   <See Class=ECADJSONError>.>

   This unit must not use any VCL, FMX, LCL or Windows unit.
}
unit VCL.FNCCS4JSON;

{$I VCL.FNCCADSys.inc}

interface

uses
{$IFDEF CADSYS_LCL}
  { NOTE (LCL): FPC has no System.JSON. Its fpjson unit spells the same
    three classes - TJSONObject, TJSONArray, TJSONData - with a different
    API (Add rather than AddPair, and Find rather than GetValue). This
    unit is deliberately the only place in the library that touches a
    JSON class, so that gap is one unit wide rather than three. }
  SysUtils, Classes, fpjson, jsonparser, VCL.FNCCS4BaseTypes;
{$ELSE}
  { System.Generics.Collections is not used directly. It is here so the
    compiler can inline TJSONArray.GetValue, which it otherwise reports
    three times per build as H2443 - noise that makes a real diagnostic
    easy to miss. }
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  VCL.FNCCS4BaseTypes;
{$ENDIF}

type
  {: Raised when a JSON document is not a valid CADSys document. }
  ECADJSONError = class(Exception);

  {: Anything that can sit in a document: an object, an array, a string,
     a number, a boolean, null.

     It exists because the two JSON implementations disagree on the name
     of that base class and on nothing else that matters here - Delphi
     calls it TJSONValue, fpjson calls it TJSONData. Code outside this
     unit should not have to know which, so the alias is what appears in
     the signatures below. }
{$IFDEF CADSYS_LCL}
  TCADJSONValue = TJSONData;
{$ELSE}
  TCADJSONValue = TJSONValue;
{$ENDIF}

const
  { : The marker every CADSys JSON document carries, so that a file
    that happens to be JSON is not mistaken for one of ours. }
  CADSysJSONFormat = 'cadsys-json';
  { : The version of the document format this library writes.

    Here rather than in VCL.FNCCADSys4 because a drawing is not the only
    kind of document any more - a saved view is one too, and it cannot
    use the unit that uses it. }
  CADSysJSONVersion = '5.0';

{ ---------------- writing ---------------- }

procedure JSetStr(const O: TJSONObject; const Name, Value: string);
procedure JSetInt(const O: TJSONObject; const Name: string; const Value: Int64);
procedure JSetReal(const O: TJSONObject; const Name: string;
  const Value: TRealType);
procedure JSetBool(const O: TJSONObject; const Name: string;
  const Value: Boolean);
{: Writes Value only when it differs from Default, which keeps the
   common case out of the file. }
procedure JSetBoolDef(const O: TJSONObject; const Name: string;
  const Value, Default: Boolean);
procedure JSetEnum(const O: TJSONObject; const Name: string;
  const Value: Integer; const Names: array of string);
procedure JSetPoint2D(const O: TJSONObject; const Name: string;
  const P: TPoint2D);
procedure JSetPoint3D(const O: TJSONObject; const Name: string;
  const P: TPoint3D);
procedure JSetVector3D(const O: TJSONObject; const Name: string;
  const V: TVector3D);
procedure JSetTransf2D(const O: TJSONObject; const Name: string;
  const T: TTransf2D);
procedure JSetTransf3D(const O: TJSONObject; const Name: string;
  const T: TTransf3D);

function Point2DToJSON(const P: TPoint2D): TJSONArray;
function Point3DToJSON(const P: TPoint3D): TJSONArray;

{: Attaches Value to O under Name; O takes ownership of it.

   This is the writing counterpart of JGetObject and JGetArray, and the
   reason it exists is portability rather than convenience: attaching a
   member is AddPair on Delphi and Add on fpjson. Keeping the two
   spellings behind one name is what lets the rest of the library name
   no JSON method at all. }
procedure JSetValue(const O: TJSONObject; const Name: string;
  const Value: TCADJSONValue);
{: Appends Value to A; A takes ownership of it. AddElement on Delphi,
   Add on fpjson - same reasoning as JSetValue. }
procedure JAddItem(const A: TJSONArray; const Value: TCADJSONValue);

{ ---------------- reading ---------------- }

function JHas(const O: TJSONObject; const Name: string): Boolean;
function JGetStr(const O: TJSONObject; const Name: string;
  const Default: string = ''): string;
function JGetInt(const O: TJSONObject; const Name: string;
  const Default: Int64 = 0): Int64;
function JGetReal(const O: TJSONObject; const Name: string;
  const Default: TRealType = 0.0): TRealType;
function JGetBool(const O: TJSONObject; const Name: string;
  const Default: Boolean = False): Boolean;
{: Returns the index of the name stored under Name, or Default when the
   member is missing or holds an unknown name. }
function JGetEnum(const O: TJSONObject; const Name: string;
  const Default: Integer; const Names: array of string): Integer;
function JGetPoint2D(const O: TJSONObject; const Name: string): TPoint2D;
function JGetPoint3D(const O: TJSONObject; const Name: string): TPoint3D;
function JGetVector3D(const O: TJSONObject; const Name: string): TVector3D;
function JGetTransf2D(const O: TJSONObject; const Name: string): TTransf2D;
function JGetTransf3D(const O: TJSONObject; const Name: string): TTransf3D;

{: Returns the member as an object, or nil when it is missing. Raises
   ECADJSONError when the member exists but is not an object. }
function JGetObject(const O: TJSONObject; const Name: string): TJSONObject;
{: Returns the member as an array, or nil when it is missing. Raises
   ECADJSONError when the member exists but is not an array. }
function JGetArray(const O: TJSONObject; const Name: string): TJSONArray;
function JRequireObject(const O: TJSONObject; const Name: string): TJSONObject;
function JRequireArray(const O: TJSONObject; const Name: string): TJSONArray;
{: Element Index of A as an object. Raises ECADJSONError when the
   element is not an object. }
function JItemObject(const A: TJSONArray; const Index: Integer): TJSONObject;
function JItemArray(const A: TJSONArray; const Index: Integer): TJSONArray;
function JItemReal(const A: TJSONArray; const Index: Integer;
  const Default: TRealType = 0.0): TRealType;

function JSONToPoint2D(const A: TJSONArray): TPoint2D;
function JSONToPoint3D(const A: TJSONArray): TPoint3D;

{ ---------------- documents ---------------- }

{: Renders O as text. Pretty output is the default because a CAD drawing
   is usually kept in version control. }
function JSONToText(const O: TCADJSONValue;
  const Pretty: Boolean = True): string;
{: Parses Text. The caller owns the result. Raises ECADJSONError when the
   text is not a JSON object. }
function TextToJSONObject(const Text: string): TJSONObject;
{: Writes O to Stream as UTF-8 text, without a byte order mark. }
procedure JSONToStream(const O: TCADJSONValue; const Stream: TStream;
  const Pretty: Boolean = True);
{: Reads a JSON object from the current position to the end of Stream.
   The caller owns the result. }
function JSONFromStream(const Stream: TStream): TJSONObject;
procedure JSONToFile(const O: TCADJSONValue; const FileName: string;
  const Pretty: Boolean = True);
function JSONFromFile(const FileName: string): TJSONObject;

implementation

{ ---------------- writing ---------------- }

procedure JSetStr(const O: TJSONObject; const Name, Value: string);
begin
  O.AddPair(Name, TJSONString.Create(Value));
end;

procedure JSetInt(const O: TJSONObject; const Name: string; const Value: Int64);
begin
  O.AddPair(Name, TJSONNumber.Create(Value));
end;

procedure JSetReal(const O: TJSONObject; const Name: string;
  const Value: TRealType);
begin
  O.AddPair(Name, TJSONNumber.Create(Double(Value)));
end;

procedure JSetBool(const O: TJSONObject; const Name: string;
  const Value: Boolean);
begin
  O.AddPair(Name, TJSONBool.Create(Value));
end;

procedure JSetBoolDef(const O: TJSONObject; const Name: string;
  const Value, Default: Boolean);
begin
  if Value <> Default then
    JSetBool(O, Name, Value);
end;

procedure JSetEnum(const O: TJSONObject; const Name: string;
  const Value: Integer; const Names: array of string);
begin
  if (Value >= 0) and (Value <= High(Names)) then
    JSetStr(O, Name, Names[Value])
  else
    JSetInt(O, Name, Value);
end;

procedure JSetValue(const O: TJSONObject; const Name: string;
  const Value: TCADJSONValue);
begin
{$IFDEF CADSYS_LCL}
  O.Add(Name, Value);
{$ELSE}
  O.AddPair(Name, Value);
{$ENDIF}
end;

procedure JAddItem(const A: TJSONArray; const Value: TCADJSONValue);
begin
{$IFDEF CADSYS_LCL}
  A.Add(Value);
{$ELSE}
  A.AddElement(Value);
{$ENDIF}
end;

function Point2DToJSON(const P: TPoint2D): TJSONArray;
begin
  Result := TJSONArray.Create;
  Result.Add(Double(P.X));
  Result.Add(Double(P.Y));
  if P.W <> 1.0 then
    Result.Add(Double(P.W));
end;

function Point3DToJSON(const P: TPoint3D): TJSONArray;
begin
  Result := TJSONArray.Create;
  Result.Add(Double(P.X));
  Result.Add(Double(P.Y));
  Result.Add(Double(P.Z));
  if P.W <> 1.0 then
    Result.Add(Double(P.W));
end;

procedure JSetPoint2D(const O: TJSONObject; const Name: string;
  const P: TPoint2D);
begin
  O.AddPair(Name, Point2DToJSON(P));
end;

procedure JSetPoint3D(const O: TJSONObject; const Name: string;
  const P: TPoint3D);
begin
  O.AddPair(Name, Point3DToJSON(P));
end;

procedure JSetVector3D(const O: TJSONObject; const Name: string;
  const V: TVector3D);
var
  A: TJSONArray;
begin
  A := TJSONArray.Create;
  A.Add(Double(V.X));
  A.Add(Double(V.Y));
  A.Add(Double(V.Z));
  O.AddPair(Name, A);
end;

procedure JSetTransf2D(const O: TJSONObject; const Name: string;
  const T: TTransf2D);
var
  A: TJSONArray;
  R, C: Integer;
begin
  A := TJSONArray.Create;
  for R := 1 to 3 do
    for C := 1 to 3 do
      A.Add(Double(T[R, C]));
  O.AddPair(Name, A);
end;

procedure JSetTransf3D(const O: TJSONObject; const Name: string;
  const T: TTransf3D);
var
  A: TJSONArray;
  R, C: Integer;
begin
  A := TJSONArray.Create;
  for R := 1 to 4 do
    for C := 1 to 4 do
      A.Add(Double(T[R, C]));
  O.AddPair(Name, A);
end;

{ ---------------- reading ---------------- }

function JValue(const O: TJSONObject; const Name: string)
  : TCADJSONValue;
begin
  if O = nil then
    Result := nil
  else
    Result := O.GetValue(Name);
  if (Result <> nil) and (Result is TJSONNull) then
    Result := nil;
end;

function JHas(const O: TJSONObject; const Name: string): Boolean;
begin
  Result := JValue(O, Name) <> nil;
end;

function JGetStr(const O: TJSONObject; const Name: string;
  const Default: string): string;
var
  V: TCADJSONValue;
begin
  V := JValue(O, Name);
  if V is TJSONString then
    Result := TJSONString(V).Value
  else if V <> nil then
    Result := V.ToString
  else
    Result := Default;
end;

function JGetInt(const O: TJSONObject; const Name: string;
  const Default: Int64): Int64;
var
  V: TCADJSONValue;
begin
  V := JValue(O, Name);
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsInt64
  else if V is TJSONBool then
    Result := Ord(TJSONBool(V).AsBoolean)
  else
    Result := Default;
end;

function JGetReal(const O: TJSONObject; const Name: string;
  const Default: TRealType): TRealType;
var
  V: TCADJSONValue;
begin
  V := JValue(O, Name);
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsDouble
  else
    Result := Default;
end;

function JGetBool(const O: TJSONObject; const Name: string;
  const Default: Boolean): Boolean;
var
  V: TCADJSONValue;
begin
  V := JValue(O, Name);
  if V is TJSONBool then
    Result := TJSONBool(V).AsBoolean
  else if V is TJSONNumber then
    Result := TJSONNumber(V).AsInt <> 0
  else
    Result := Default;
end;

function JGetEnum(const O: TJSONObject; const Name: string;
  const Default: Integer; const Names: array of string): Integer;
var
  V: TCADJSONValue;
  S: string;
  I: Integer;
begin
  V := JValue(O, Name);
  if V is TJSONNumber then
    Exit(TJSONNumber(V).AsInt);
  if not(V is TJSONString) then
    Exit(Default);
  S := TJSONString(V).Value;
  for I := 0 to High(Names) do
    if SameText(S, Names[I]) then
      Exit(I);
  Result := Default;
end;

function JItemReal(const A: TJSONArray; const Index: Integer;
  const Default: TRealType): TRealType;
var
  V: TCADJSONValue;
begin
  Result := Default;
  if (A = nil) or (Index < 0) or (Index >= A.Count) then
    Exit;
  V := A.Items[Index];
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsDouble;
end;

function JSONToPoint2D(const A: TJSONArray): TPoint2D;
begin
  Result.X := JItemReal(A, 0);
  Result.Y := JItemReal(A, 1);
  Result.W := JItemReal(A, 2, 1.0);
end;

function JSONToPoint3D(const A: TJSONArray): TPoint3D;
begin
  Result.X := JItemReal(A, 0);
  Result.Y := JItemReal(A, 1);
  Result.Z := JItemReal(A, 2);
  Result.W := JItemReal(A, 3, 1.0);
end;

function JGetPoint2D(const O: TJSONObject; const Name: string): TPoint2D;
begin
  Result := JSONToPoint2D(JGetArray(O, Name));
end;

function JGetPoint3D(const O: TJSONObject; const Name: string): TPoint3D;
begin
  Result := JSONToPoint3D(JGetArray(O, Name));
end;

function JGetVector3D(const O: TJSONObject; const Name: string): TVector3D;
var
  A: TJSONArray;
begin
  A := JGetArray(O, Name);
  Result.X := JItemReal(A, 0);
  Result.Y := JItemReal(A, 1);
  Result.Z := JItemReal(A, 2);
end;

function JGetTransf2D(const O: TJSONObject; const Name: string): TTransf2D;
var
  A: TJSONArray;
  R, C: Integer;
begin
  Result := IdentityTransf2D;
  A := JGetArray(O, Name);
  if (A = nil) or (A.Count < 9) then
    Exit;
  for R := 1 to 3 do
    for C := 1 to 3 do
      Result[R, C] := JItemReal(A, (R - 1) * 3 + (C - 1));
end;

function JGetTransf3D(const O: TJSONObject; const Name: string): TTransf3D;
var
  A: TJSONArray;
  R, C: Integer;
begin
  Result := IdentityTransf3D;
  A := JGetArray(O, Name);
  if (A = nil) or (A.Count < 16) then
    Exit;
  for R := 1 to 4 do
    for C := 1 to 4 do
      Result[R, C] := JItemReal(A, (R - 1) * 4 + (C - 1));
end;

function JGetObject(const O: TJSONObject; const Name: string): TJSONObject;
var
  V: TCADJSONValue;
begin
  V := JValue(O, Name);
  if V = nil then
    Result := nil
  else if V is TJSONObject then
    Result := TJSONObject(V)
  else
    Raise ECADJSONError.CreateFmt('"%s" must be an object', [Name]);
end;

function JGetArray(const O: TJSONObject; const Name: string): TJSONArray;
var
  V: TCADJSONValue;
begin
  V := JValue(O, Name);
  if V = nil then
    Result := nil
  else if V is TJSONArray then
    Result := TJSONArray(V)
  else
    Raise ECADJSONError.CreateFmt('"%s" must be an array', [Name]);
end;

function JRequireObject(const O: TJSONObject; const Name: string): TJSONObject;
begin
  Result := JGetObject(O, Name);
  if Result = nil then
    Raise ECADJSONError.CreateFmt('"%s" is missing', [Name]);
end;

function JRequireArray(const O: TJSONObject; const Name: string): TJSONArray;
begin
  Result := JGetArray(O, Name);
  if Result = nil then
    Raise ECADJSONError.CreateFmt('"%s" is missing', [Name]);
end;

function JItemObject(const A: TJSONArray; const Index: Integer): TJSONObject;
var
  V: TCADJSONValue;
begin
  if (A = nil) or (Index < 0) or (Index >= A.Count) then
    Raise ECADJSONError.CreateFmt('no element %d', [Index]);
  V := A.Items[Index];
  if not(V is TJSONObject) then
    Raise ECADJSONError.CreateFmt('element %d must be an object', [Index]);
  Result := TJSONObject(V);
end;

function JItemArray(const A: TJSONArray; const Index: Integer): TJSONArray;
var
  V: TCADJSONValue;
begin
  if (A = nil) or (Index < 0) or (Index >= A.Count) then
    Raise ECADJSONError.CreateFmt('no element %d', [Index]);
  V := A.Items[Index];
  if not(V is TJSONArray) then
    Raise ECADJSONError.CreateFmt('element %d must be an array', [Index]);
  Result := TJSONArray(V);
end;

{ ---------------- documents ---------------- }

function JSONToText(const O: TCADJSONValue; const Pretty: Boolean): string;
begin
  if O = nil then
    Exit('');
  if Pretty then
    Result := O.Format(2)
  else
    Result := O.ToJSON;
end;

function TextToJSONObject(const Text: string): TJSONObject;
var
  V: TCADJSONValue;
begin
  V := nil;
  try
    V := TJSONObject.ParseJSONValue(Text);
  except
    on E: Exception do
      Raise ECADJSONError.Create('Invalid JSON: ' + E.Message);
  end;
  if V = nil then
    Raise ECADJSONError.Create('Invalid JSON: nothing to parse');
  if not(V is TJSONObject) then
  begin
    V.Free;
    Raise ECADJSONError.Create('Invalid JSON: the document is not an object');
  end;
  Result := TJSONObject(V);
end;

procedure JSONToStream(const O: TCADJSONValue; const Stream: TStream;
  const Pretty: Boolean);
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes(JSONToText(O, Pretty));
  if Length(Bytes) > 0 then
    Stream.WriteBuffer(Bytes[0], Length(Bytes));
end;

function JSONFromStream(const Stream: TStream): TJSONObject;
var
  Bytes: TBytes;
  Len: Integer;
begin
  Len := Stream.Size - Stream.Position;
  SetLength(Bytes, Len);
  if Len > 0 then
    Stream.ReadBuffer(Bytes[0], Len);
  { TEncoding.UTF8.GetString skips no BOM, so strip one if present. }
  if (Len >= 3) and (Bytes[0] = $EF) and (Bytes[1] = $BB) and (Bytes[2] = $BF)
  then
    Result := TextToJSONObject(TEncoding.UTF8.GetString(Bytes, 3, Len - 3))
  else
    Result := TextToJSONObject(TEncoding.UTF8.GetString(Bytes));
end;

procedure JSONToFile(const O: TCADJSONValue; const FileName: string;
  const Pretty: Boolean);
var
  Strm: TFileStream;
begin
  Strm := TFileStream.Create(FileName, fmCreate);
  try
    JSONToStream(O, Strm, Pretty);
  finally
    Strm.Free;
  end;
end;

function JSONFromFile(const FileName: string): TJSONObject;
var
  Strm: TFileStream;
begin
  Strm := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := JSONFromStream(Strm);
  finally
    Strm.Free;
  end;
end;

end.
