unit VariableSamples;

interface

uses
  SysUtils,
  Classes,
  Variants;

type
  // Enumerations and subranges
  TMyEnum = (meOne, meTwo, meThree);
  TSubRange = 1..100;

  // Sets (using named enum and numeric subrange)
  TEnumSet = set of TMyEnum;
  TByteSet = set of 0..7;

  // Arrays (static, dynamic alias, multi-dimensional via nesting)
  TCharArray = array[0..9] of Char;
  TOpenIntArray = array of Integer;
  // Use nested arrays instead of multi-index syntax to match many Delphi grammars
  TFixedMatrix = array[0..2] of array[0..2] of Double;

  // Records (simple and packed)
  TInnerRecord = record
    A: Integer;
    B: string;
  end;

  TPackedRec = packed record
    B1: Byte;
    B2: Byte;
  end;

  // Pointers
  PInteger = ^Integer;
  PInnerRecord = ^TInnerRecord;

  // Classes
  TBase = class
  private
    FValue: Integer;
  public
    InstanceVar: Double;
    property Value: Integer read FValue write FValue;
  end;

  // Interfaces (kept simple for grammar compatibility)
  IMyIntf = interface
    procedure DoSomething;
  end;

  // Procedural types
  TNotify = procedure;
  TFuncInt = function(X: Integer): Integer;
  TProcOfObj = procedure of object;

const
  MaxItems = 10;
  PiVal = 3.1415926535;
  TypedConstArray: array[0..2] of Integer = (1, 2, 3);

type
  // Type alias and set alias
  TMyInt = type Integer;
  TMyEnumSet = set of TMyEnum;

var
  // Global variables (common scalar and managed types)
  GInt: Integer;
  GInt64: Int64;
  GCard: Cardinal;
  GBool: Boolean;
  GByte: Byte;
  GWord: Word;
  GLongWord: LongWord;
  GChar: Char;
  GAnsiChar: AnsiChar;
  GWideChar: WideChar;
  GString: string;
  GAnsiString: AnsiString;
  GWideString: WideString;
  GShortString: ShortString;
  GCurrency: Currency;
  GSingle: Single;
  GDouble: Double;
  GExtended: Extended;
  GVariant: Variant;
  GOleVariant: OleVariant;
  GGuid: TGUID;
  GDateTime: TDateTime;

  // User-defined types
  GEnum: TMyEnum;
  GSub: TSubRange;
  GSet: TMyEnumSet;
  GByteSet: TByteSet;

  // Arrays
  GStaticArr: TCharArray;
  GFixedMatrix: TFixedMatrix;
  GDynArr: TOpenIntArray;

  // Pointers and records
  GPtr: Pointer;
  GPInt: PInteger;
  GPRec: PInnerRecord;
  GRecord: TInnerRecord;
  GPacked: TPackedRec;

  // Objects and interfaces
  GObj: TObject;
  GBase: TBase;
  GInterface: IMyIntf;

  // Files
  GTextFile: TextFile;      // text file
  GRawFile: file;           // untyped file
  GByteFile: file of Byte;  // typed file

implementation

var
  // Implementation section variables
  ImplCounter: Integer;
  ImplDyn: TOpenIntArray;

procedure DemoParams(var A: Integer; const B: string; out C: Boolean; D: array of const);
var
  // Local variables
  LInt: Integer;
  LStr: string;
  LArr: array[0..3] of Byte;     // static local array
  LDyn: array of Integer;        // dynamic local array
  LEnumSet: TEnumSet;            // set using named enum
  LFile: file of Char;           // typed file
  LText: TextFile;               // text file
  LProc: TNotify;                // procedural variable
  LFunc: TFuncInt;
  LProcOfObj: TProcOfObj;
  LClassRef: class of TBase;     // class reference
  LRec: TInnerRecord;
  LPtr: PInteger;
begin
  // Simple usage to keep parser happy
  LInt := 0;
  LStr := B;
  SetLength(LDyn, 5);
  LEnumSet := [];
  A := LInt + 10;
  C := True;
  LProc := nil;
  LFunc := nil;
  LProcOfObj := nil;
  LClassRef := TBase;
  AssignFile(LText, 'dummy.txt');

  // Touch some record and pointer vars
  LRec.A := 1;
  LRec.B := 'text';
  New(LPtr);
  Dispose(LPtr);
end;

end.