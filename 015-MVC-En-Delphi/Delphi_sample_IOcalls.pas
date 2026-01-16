unit IOSampleUnit;

interface

uses
  SysUtils, Classes, IOUtils;

type
  TIOSample = class
  public
    procedure RunIODemo;
    procedure ShowSummary;
  end;

implementation

{ TIOSample }

procedure TIOSample.RunIODemo;
begin
  if not TDirectory.Exists('IODemo') then
    TDirectory.CreateDirectory('IODemo');

  TFile.WriteAllText('IODemo\text.txt', 'First line' + sLineBreak, TEncoding.UTF8);
  TFile.AppendAllText('IODemo\text.txt', 'Second line' + sLineBreak, TEncoding.UTF8);
  WriteLn('Exists(text.txt)= ' + BoolToStr(TFile.Exists('IODemo\text.txt'), True));
end;

procedure TIOSample.ShowSummary;
begin
  WriteLn('I/O demo complete. Check IODemo folder for generated files.');
end;

end.
