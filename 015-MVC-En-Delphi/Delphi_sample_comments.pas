unit SampleComments;

interface

uses
  System.SysUtils;

type
  TSample = class
  public
    procedure DoSomething;
    function Add(A, B: Integer): Integer;
  end;

implementation

// This is a standalone single-line comment using double slashes

{ This is a standalone block comment using braces }

(* This is a standalone block comment using paren-star *)

procedure TSample.DoSomething;
var
  I: Integer;
begin
  // Standalone single-line comment inside a method

  I := 42; // Inline comment after code
  Writeln('Value: ' + IntToStr(I)); // Another inline comment after code

  {
    Multi-line block comment using braces.
    It can span multiple lines to describe complex logic,
    assumptions, or notes for future changes.
  }

  (*
    Multi-line block comment using paren-star.
    Also spans multiple lines with similar semantics.
  *)
end;

function TSample.Add(A, B: Integer): Integer;
begin
  Result := A + B; // Inline comment explaining the simple addition
end;

// Another standalone // comment at the end of the implementation

end.
