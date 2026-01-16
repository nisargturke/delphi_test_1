unit Validator;

interface

uses
  Controls,
  Variants,
  ComCtrls,
  Forms,
  Dialogs,
  Graphics,
  DBCtrls,
  StdCtrls,
  //RTI Phase 1 02/2012
  StrUtils,
  Classes;
  //End RTI Phase 1
const
  listGender = ['M', 'F'];

type
  TValidator = class;

  TValidationEvent = procedure(Sender: TValidator; var isValid: Boolean; var msg: string; var cntrl: TWinControl) of object;

  TCharSet = set of Char;

  TValidator = class
  private
    FLastColoredCntrl: TWinControl;
    FLastColoredCntrlOldColor: TColor;

    FParent: TForm;
    FOnValidate: TValidationEvent;
    FFocusControl: Boolean;
    FShowErrorMessage: Boolean;
    FChangeControlColor: Boolean;
    FInvalidControlColor: TColor;

    FGenderList: TCharSet;
    FSetAList: TCharSet;
    FSetBList: TCharSet;
    FSetCList: TCharSet;
    FSetDList: TCharSet;
    FSetEList: TCharSet;
    FSetFList: TCharSet;
//    FSetGList: TCharSet;
    FSetHList: TCharSet;
    //FNIString: string;
    //FNIList: TStringList;

    procedure SetFocus(c: TWinControl);
    procedure SetColor(c: TWinControl);
    procedure ChangeColor(c: TWinControl; color: TColor);
  protected
    procedure DoValidate(var isValid: Boolean; var msg: string; var cntrl: TWinControl); virtual;
  public
    constructor Create(parent: TForm);
    destructor Destroy; override;

    property OnValidate: TValidationEvent read FOnValidate write FOnValidate;

    property ShowErrorMessage: Boolean read FShowErrorMessage write FShowErrorMessage default True;
    property FocusInvalidControl: Boolean read FFocusControl write FFocusControl default True;
    property ChangeInvalidControlColor: Boolean read FChangeControlColor write FChangeControlColor default False;
    property InvalidControlColor: TColor read FInvalidControlColor write FInvalidControlColor default clRed;

    //Common character lists
    property GenderList: TCharSet read FGenderList;
    property SetAList: TCharSet read FSetAList; //Full Character Set
    property SetBList: TCharSet read FSetBList; //Surname or Family Name Character Set
    property SetCList: TCharSet read FSetCList; //First Name, Second Name and Title Character Set
    property SetDList: TCharSet read FSetDList; //Postcode Character Set
    property SetEList: TCharSet read FSetEList; // Alpha only
    property SetFlist: TCharSet read FSetFList; // Alpha and numeric only 
//    property SetGlist: TCharSet read FSetGList; // Alpha, numeric, certain characters only
    property SetHlist: TCharSet read FSetHList;  


    function Validate: Boolean;
    procedure RestoreColor;

    function ValidateValue(cntrl: TWinControl; value: Variant; fieldTitle: string; const CharList: TCharSet; Mandatory: Boolean; var msg: string; var returnCntrl: TWinControl): Boolean; overload;
    function ValidateMandatory(value: Variant; fieldTitle: string; var msg: string): Boolean;

    function ValidateDBEdit(cntrl: TDBEdit; fieldTitle: string; const CharList: TCharSet; Mandatory: Boolean; var msg: string): Boolean; overload;
    function ValidateDBEdit(cntrl: TDBEdit; fieldTitle: string; const CharList: TCharSet; Mandatory: Boolean; var msg: string; var returnCntrl: TWinControl): Boolean; overload;

    function ValidateEdit(cntrl: TEdit; fieldTitle: string; const CharList: TCharSet; Mandatory: Boolean; var msg: string; var returnCntrl: TWinControl): Boolean; overload;
    function IsNullOrEmpty(field: Variant): Boolean;
    function IsNumber(const value: string): Boolean;
    function ConsistOf(Value: Variant; const list: TCharSet; Mandatory: Boolean = False): Boolean; overload;

    function ValidatePostCode(Value: string; var msg: string): Boolean;
    function ValidateTaxCode(Value: string; var msg: string): Boolean;
    function ValidateBankAccount(sortCode, accountNo: integer; var msg: string): Boolean;
    function ValidateSurname(Surname: string; var msg: string): boolean; {KG}
    function ValidateForename(Forename: string; var Msg: string): boolean; {KG}
    function ValidateAddressLine(addressLine : integer; addressValue : string; var msg : string; addressType : String = '';
                                 Mandatory: Boolean = True) : Boolean ; 
    function ValidateDateOfBirth(DateOfBirth : TDateTime; DOBType : string; var msg : string) : Boolean ; {NjC}
    function ValidateDateOfDeath(ADateOfBirth : TDateTime; ADateOfDeath : TDateTime; APolicyStart : TDateTime; var msg : string) : Boolean ; {NjC RTI}
  end;

implementation

uses
  SysUtils, BankAccountValidator, UMessage, DateUtils, general;

{ TValidator }

constructor TValidator.Create(parent: TForm);
begin
  inherited Create;
  FShowErrorMessage := True;
  FFocusControl := True;
  FChangeControlColor := False;
  FInvalidControlColor := clRed;
  FParent := parent;
  FGenderList := ['M', 'F'];
  FSetAList := ['a'..'z', 'A'..'Z', '0'..'9',
    ' ', '.', ',', '-', '(', ')', '/', '=',
    '!', '"', '%', '&', '*', ';', '<', '>',
    '''', '+', ':', '?'];
  FSetBList := ['a'..'z', 'A'..'Z',
    ' ', '-', ''''];
  FSetCList := ['a'..'z', 'A'..'Z',
    ' ', '-', '.', ''''];
  FSetDList := ['a'..'z', 'A'..'Z', '0'..'9', ' '];
  // RTI Phase 1 - KG: Set B and set D seem to switch usage
  FSetElist := ['a'..'z', 'A'..'Z'];
  FSetFList := ['a'..'z', 'A'..'Z', '0'..'9'];
//  FSetGList := ['a'..'z', 'A'..'Z', '0'..'9', ' ', '-', ''''] ;
  FSetHList := ['a'..'z', 'A'..'Z', '0'..'9', ' ', '-', '''', '&', '.', '/'] ;

  
end;

destructor TValidator.Destroy;
begin
  RestoreColor;
  inherited;
end;

procedure TValidator.DoValidate(var isValid: Boolean; var msg: string; var cntrl: TWinControl);
begin
  if assigned(FOnValidate) then
  begin
    OnValidate(self, isValid, msg, cntrl);
  end;
end;

function TValidator.IsNullOrEmpty(field: Variant): Boolean;
begin
  if (field = Null) then
  begin
    Result := True;
  end
  else if (VarType(field) = varString) and (field = '') then
  begin
    Result := True;
  end
  else if (VarType(field) = varDate) and (field = 0) then
  begin
    Result := True;
  end
  else
    Result := False;
end;

procedure TValidator.RestoreColor;
begin
  if (Assigned(FLastColoredCntrl)) then
  begin
    ChangeColor(FLastColoredCntrl, FLastColoredCntrlOldColor);
    FLastColoredCntrl := nil;
  end;
end;

procedure TValidator.SetColor(c: TWinControl);
begin
  if (assigned(c)) then
  begin
    FLastColoredCntrl := c;
    FLastColoredCntrlOldColor := c.Brush.Color;
    ChangeColor(c, FInvalidControlColor);
  end;
end;

procedure TValidator.ChangeColor(c: TWinControl; color: TColor);
begin
  c.Brush.Color := color;
  c.Invalidate;
end;

procedure TValidator.SetFocus(c: TWinControl);
var
  temp: TWinControl;
begin
  temp := c;
  while ((temp <> nil) and (not (temp is TTabSheet))) do
    temp := temp.Parent;
  if (temp <> nil) then
  begin
    TTabSheet(temp).PageControl.ActivePage := TTabSheet(temp);
  end;
  if (c.CanFocus) then
    c.SetFocus;
end;

function TValidator.Validate: Boolean;
var
  cntrl: TWinControl;
  msg: string;
  currentActive: TWinControl;
  NINumber : string ;
begin
  if (Assigned(FParent)) then
  begin
    currentActive := FParent.ActiveControl;

    {NjC  override mask validation for NInsurance fields if field is blank}
    if assigned(currentActive) then
    begin

     {NjC Gad ignore grid dbedits}
     if (currentActive.Name <> 'dbNextGadReviewDate') and (currentActive.Name <> 'dbNewGadMax') and
        (currentActive.Name <> 'cbIncomeRestricted') and (currentActive.Name <> 'dbNewAnnuityAmt') and (currentActive.Name <> 'dbWithheldIncome') then
     begin
        if (currentActive.Name = 'NI1') or (currentActive.Name = 'NI2') then
        begin
          NINumber := (currentActive As TDBEdit).Text;
          NINumber := Copy(NINumber, 1,2) + Copy(NINumber, 4,2) + Copy(NINumber, 7,2) + Copy(NINumber, 10,2) + Copy (NINumber, 13,1);

          if trim(NINumber) = '' then
            (currentActive as TDBEdit).EditText := '';
        end ;
        FParent.ActiveControl := nil;
        FParent.ActiveControl := currentActive;
      end ;
    end;
  end;

  RestoreColor;

  Result := True;
  cntrl := nil;
  msg := '';

  DoValidate(Result, msg, cntrl);

  if (not Result) then
  begin
    if (Assigned(cntrl)) then
    begin
      if (FocusInvalidControl) then
      begin
        SetFocus(cntrl);
      end;
      if (ChangeInvalidControlColor) then
      begin
        SetColor(cntrl);
      end;
    end;
    if (ShowErrorMessage) and (msg <> '') then
    begin
      MessageDlg(msg, mtInformation, [mbOK], 0);
    end;
  end;
end;

{function TValidator.IsIn(Value: Variant; const list: array of Variant; Mandatory: Boolean = False): Boolean;
var
  i: Integer;
begin
  if (IsNullOrEmpty(Value)) then
  begin
    Result := not Mandatory;
  end
  else
  begin
    Result := False;
    for i := 0 to Length(list) - 1 do
    begin
      if (list[i] = Value) then
      begin
        Result := True;
        Break;
      end
    end;
  end;
end;

function TValidator.IsIn(Value: Variant; const list: TCharSet; Mandatory: Boolean = False): Boolean;
var
  str: string;
begin
  if (IsNullOrEmpty(Value)) then
  begin
    Result := not Mandatory;
  end
  else
  begin
    str := VarToStr(Value);
    if (Length(str) = 1) then
      Result := str[1] in list
    else
      Result := False;
  end;
end;

function TValidator.IsIn(Value: string; const list: array of string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Length(list) - 1 do
  begin
    if (list[i] = Value) then
    begin
      Result := True;
      Break;
    end
  end;
end;}

function TValidator.ConsistOf(Value: Variant; const list: TCharSet; Mandatory: Boolean): Boolean;
var
  str: string;
  i: Integer;
begin
  if (IsNullOrEmpty(Value)) then
  begin
    Result := not Mandatory;
  end
  else
  begin
    str := VarToStr(Value);
    Result := True;
    for i := 1 to Length(str) do
    begin
      if (not (str[i] in list)) then
      begin
        Result := False;
        Break;
      end;
    end;
  end;
end;

function TValidator.ValidateDBEdit(cntrl: TDBEdit; fieldTitle: string; const CharList: TCharSet; Mandatory: Boolean; var msg: string): Boolean;
var
  c: TWinControl;
begin
  Result := ValidateDBEdit(cntrl, fieldTitle, CharList, Mandatory, msg, c);
end;

{$HINTS OFF}
function TValidator.IsNumber(const value: string): Boolean;
var
  code: Integer;
  number: Double;
begin
  Val(value, number, code);
  Result := code = 0;
end;
{$HINTS ON}

function TValidator.ValidateDBEdit(cntrl: TDBEdit; fieldTitle: string; const CharList: TCharSet; Mandatory: Boolean; var msg: string; var returnCntrl: TWinControl): Boolean;
var
  Value: Variant;
begin
  Value := cntrl.Field.Value;
  Result := ValidateValue(cntrl, Value, fieldTitle, CharList, Mandatory, msg, returnCntrl);
end;

function TValidator.ValidateEdit(cntrl: TEdit; fieldTitle: string; const CharList: TCharSet; Mandatory: Boolean; var msg: string; var returnCntrl: TWinControl): Boolean;
begin
  Result := ValidateValue(cntrl, cntrl.Text, fieldTitle, CharList, Mandatory, msg, returnCntrl);
end;

function TValidator.ValidateMandatory(value: Variant; fieldTitle: string; var msg: string): Boolean;
begin
  Result := True;
  if (IsNullOrEmpty(Value)) then
  begin
    msg := Format('Must enter %s!', [fieldTitle]);
    Result := False;
  end;
end;

function TValidator.ValidateValue(cntrl: TWinControl; value: Variant; fieldTitle: string; const CharList: TCharSet; Mandatory: Boolean; var msg: string; var returnCntrl: TWinControl): Boolean;
begin
  Result := True;
  if (Mandatory and not ValidateMandatory(Value, fieldTitle, msg)) then
  begin
    Result := False;
    returnCntrl := cntrl;
  end
  else if (CharList <> []) and (not ConsistOf(Value, CharList)) then
  begin
    msg := Format('Invalid %s!', [fieldTitle]);
    Result := False;
    returnCntrl := cntrl;
  end;
end;

//function TValidator.ValidateNINumber(cntrl: TWinControl; value: string; var msg: string; var returnCntrl: TWinControl): Boolean;
//begin
//  Result := False;

//  If length(value) = 8 then
//     value:= value + ' ';


//  If length(value) = 9 then
//      Begin
//        FNIList.CommaText:= FNIString;
//        If (FNIList.IndexOf(LeftStr(value,2)) > -1)
//        and (IsNumber(Midstr(value, 3,6)))
//        and (Pos(value[9], 'ABCD ') > 0)
//        then
//           Result:= True;
//    End;
//  If result = false then
//     msg := 'Invalid NI Number';
//end;

function TValidator.ValidateTaxCode(Value: string; var msg: string): Boolean;
var
  NumericPart: integer;
  ScottishCode,WelshCode:boolean;
  i: integer;
begin
  Result := False;
  ScottishCode := false;
  WelshCode:=False;
  //23025 Taxcode space handled
  for i := 1 to Length(Value) do
    begin
      if Value[i] = ' ' then
      begin
        msg     := 'Invalid Tax Code - Space not allowed' ;
        result  := false;
        exit;
      end
    end;
  //till this
  if (copy(Value, length(Value),1)) = '*' then
  begin
    Value := copy(Value, 1,length(Value)-1) ;
  end;
  if (copy(Value, 1, 1)) = 'S' then
  begin
    ScottishCode := true ;
    Value := copy(Value, 2, length(Value));
  end
  else
  if (copy(Value, 1, 1)) = 'C' then
  begin
    WelshCode:= true;
    Value := copy(Value, 2, length(Value));
  end;
  if (copy(Value, 1, 1)) = 'C' then
  begin
    WelshCode:= true ;
    Value := copy(Value, 2, length(Value));
  end;
  if Length(Value) < 2 then
     Result:= False
  else
    if (Value = 'BR') or (Value = 'NT') or (Value = 'D0') or (Value = 'D1') or (ScottishCode and (Value ='D2')) or (WelshCode)then
     Result:= True
     {else
      if (Value[1] = 'K') and (Value[2] <> '0') and  TryStrToInt(RightStr(Value, Length(Value) - 1), NumericPart) then
      begin
        if NumericPart < 10000 then
        Result:= True;
      end}
    {Begin RSKC-685 tp63370}
    else
      if (Value[1] = 'K') and  TryStrToInt(RightStr(Value, Length(Value) - 1), NumericPart) then
      begin
        if NumericPart < 100000 then
           Result:= True;
      end
      else if (Value[2] <> '0') and  TryStrToInt(RightStr(Value, Length(Value) - 1), NumericPart) then
        begin
          if NumericPart < 10000 then
             Result:= True;
        end
    {--End RSKC-685 tp63370}  
      else
        if (AnsiPos(RightStr(Value,1),'LTPYMN') > 0) and TryStrToInt(LeftStr(Value, Length(Value) -1), NumericPart) then
          if NumericPart < 1000000 then
        Result:= True;

  if not Result then
  begin
      msg := 'Invalid Tax Code' ;
  end;
end;

function TValidator.ValidatePostCode(value: string; var msg: string): Boolean;
var
   i: integer;
   strNew: string;
begin
  strNew := '';
  for i := 1 to Length(Value) do
    begin
      if  Value[i] in ['0'..'9'] then
        strNew := strNew + '9'
      else if Value[i] = ' ' then
        strNew := strNew + ' '
        //Space
      else If Consistof(Value[i], FSetDList) and (Value[i] = UpCase(Value[i])) then
        strNew := strNew + 'A'
        //Letter in upper case ie not numeric or space
      else
        strNew := strNew + 'X';
        //Not valid
    end;

  if (strNew = 'AA9A 9AA') or
     (strNew = 'A9A 9AA') or
     (strNew = 'A9 9AA') or
     (strNew = 'A99 9AA') or
     (strNew = 'AA9 9AA') or
     (strNew = 'AA99 9AA')
  then
        result := True
  else
     begin
     msg := 'Invalid post code.';
     result := False;
     end;
end;

function TValidator.ValidateBankAccount(sortCode, accountNo: integer; var msg: string): Boolean;
var bankValidator: TBankAccountValidator;
begin
  bankValidator := TBankAccountValidator.Create;
  try
    Result := bankValidator.Validate(sortCode, accountNo);
  finally
    bankValidator.Free;
  end;
  if not Result then
  begin
    msg := 'Invalid Bank Account / Sort Code entered. Please Amend.';
    Result := False;
  end;
end;

{KG}
function TValidator.ValidateSurname(surname: string; var msg: string): boolean;
begin
  result := true;
  if (not ConsistOf(copy(surname,1,1), FSetEList)) then
  begin
    msg := SURNAME_FIRST_CHARACTER_INVALID;
    result := false;
  end
  else
  begin
    if (length(surname) < 2) then
    begin
      msg := SURNAME_TOO_SMALL;
      result := false;
    end
    else
    begin
      // assuming Set E is subset of Set B
      if (not ConsistOf(surname, FSetBList)) then
      begin
        msg := SURNAME_CHARACTER_INVALID;
        result := false;
      end;
    end;
  end;
end;

function TValidator.ValidateForename(Forename: string; var Msg: string): boolean;
begin
  result := true;
  if (not ConsistOf(copy(Forename,1,1), FSetEList)) then
  begin
    msg := FORENAME_FIRST_CHARACTER_INVALID;
    result := false;
  end
  else
  begin
    if (length(Forename) < 2) then
    begin
      msg := FORENAME_TOO_SMALL;
      result := false;
    end
    else
    begin
      // assuming Set E is subset of Set B
      if (not ConsistOf(Forename, FSetBList)) then
      begin
        msg := FORENAME_CHARACTER_INVALID;
        result := false;
      end;
    end;
  end;
end;

{NjC}
function TValidator.ValidateAddressLine(addressLine : integer; addressValue : string; var msg : string; addressType : String = '';
                                        Mandatory: Boolean = True) : Boolean ;
begin
  Result := true ;

  if Mandatory then
    if not self.ValidateMandatory(addressValue, addressType + ' Address Line ' + intToStr(addressLine), msg) then
  begin
        Result := False;
        Exit;
      end;

    if (not ConsistOf(copy(addressValue,1,1), FSetFList)) then
    begin
      msg := format(FIRST_CHARACTER_INVALID,[addressType + ' Address Line ' + intToStr(addressLine)]);
      result := false;
    end
    else
    begin
    if (length(addressValue) < 2) and (length(addressValue) > 0) then
      begin
        msg := format(ADDRESS_LINE_TOO_SMALL,[addressType + ' Address Line ' + intToStr(addressLine)]);
        result := false ;
      end
      else
      begin
        if (not ConsistOf(addressValue, FSetAList)) then
        begin
          msg := addressType + ' Address Line ' + intToStr(addressLine) + ADDRESS_INVALID_CHARACTER;
          result := false;
        end
      end ;
    end ;
end ;

function TValidator.ValidateDateOfBirth(DateOfBirth : TDateTime; DOBType : string; var msg : string) : Boolean ;
begin
  result := true ;
  if (YearsBetween(DateofBirth, Now) > 120) then
  begin
    msg := format(BIRTH_DATE_TOO_OLD,[DOBType]) ;
    result := false ;
  end ;
end ;

function TValidator.ValidateDateOfDeath(ADateOfBirth : TDateTime; ADateOfDeath : TDateTime; APolicyStart : TDateTime;
                                        var msg : string) : Boolean ;
var
  taxCurrentYearStart : TDateTime ;
  taxCurrentYearStartMinus6Yrs : TDateTime ;

begin
  result := true ;
  if (ADateOfDeath > Today) then
  begin
    msg := 'Invalid Date of Death. Date must be today or earlier.';
    result := false;
  end
  else
  // check 'early' dates
  if (ADateOfDeath < ADateOfBirth) then
  begin
    msg     := 'A date of death cannot be less than the Annuitant date of birth!' ;
    result  := false ;
  end
  else if (ADateOfDeath < APolicyStart) then
  begin
    msg     := 'A date of death cannot be less than the policy start date!' ;
    result  := false ;
  end
  else
  begin

    // tax dates
    taxCurrentYearStart  := StartOfCurrentTaxYear;
    taxCurrentYearStartMinus6Yrs := incYear(taxCurrentYearStart,-6) ;

    if (ADateOfDeath < taxCurrentYearStartMinus6Yrs) then
    begin
      msg     := 'A date of death cannot be more than the start of the current tax year minus six years!' ;
      result  := false ;
    end
    else if ((ADateOfDeath >= taxCurrentYearStartMinus6Yrs) and
            (ADateOfDeath < taxCurrentYearStart)) then
    begin
      msg := '#Please Note.  There are additional tax implications because the date of death is a prior tax year.'+ #13 +
              'Please contact the Annuity Product Technical Team / Finance.' ;
      {result remains true}
    end ;
  end ;
end ;


end.
