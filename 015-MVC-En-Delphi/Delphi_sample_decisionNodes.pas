unit SampleUnit;

interface

type
  TCalculator = class
  public
    function Add(a, b: Integer): Integer;
	function Add1(a, b: Integer): Integer;
    procedure PrintResult(value: Integer);

    function ClassifyNumber(n: Integer): string;   // switch-case type
    function NestedCheck(x, y: Integer): string;   // nested if-else
    function GradeMarks(marks: Integer): string;   // if-else ladder
  end;

implementation

function TCalculator.Add(a, b: Integer): Integer;
begin
  if a > b then
    Result := a - b
  else
    Result := a + b;
end;

function TCalculator.Add1(a, b: Integer): Integer;
begin
  // First if-else block
  if a > b then
    Writeln('a is greater than b')
  else
    Writeln('a is not greater than b');

  // Second if-else block
  if (a + b) > 10 then
    Writeln('Sum is greater than 10')
  else
    Writeln('Sum is 10 or less');

  // Just return something so function compiles
  Result := a + b;
end;


procedure TCalculator.PrintResult(value: Integer);
begin
  if value = 0 then
    Writeln('Zero')
  else
    Writeln('Non-zero');
end;

// Example of switch-case
function TCalculator.ClassifyNumber(n: Integer): string;
begin
  case n of
    0: Result := 'Zero';
    1..9: Result := 'Single digit';
    10..99: Result := 'Double digit';
  else
    Result := 'Large number';
  end;
end;

// Example of nested if-else
function TCalculator.NestedCheck(x, y: Integer): string;
begin
  if x > 0 then
  begin
    if y > 0 then
      Result := 'Both positive'
    else
      Result := 'x positive, y non-positive';
  end
  else
  begin
    if y < 0 then
      Result := 'x non-positive, y negative'
    else
      Result := 'x non-positive, y non-negative';
  end;
end;

// Example of if-else ladder
function TCalculator.GradeMarks(marks: Integer): string;
begin
  if marks >= 90 then
    Result := 'A+'
  else if marks >= 75 then
    Result := 'A'
  else if marks >= 60 then
    Result := 'B'
  else if marks >= 40 then
    Result := 'C'
  else
    Result := 'Fail';
end;

end.
