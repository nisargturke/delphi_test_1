unit unitPaymentObject;

interface

uses
  DB, Dialogs;

type
  TOverrideOption = (ooNone, ooCreate, ooManual, ooImport);

  TPaymentObject = class
  private
    FCapitalElement: Real;
    FFirstLetter: Char;
    FFirstLetterIndex: Integer;
    FFirstPayment: Boolean;
    FFreePayMultiplier: Integer;
    FGadReviewDate: TDateTime;
    FGrossAnnuityYear1: Real;
    FICFP: Boolean;
    FInitPayMethod: string;
    FInstalments: Integer;
    FInstalmentsYear1: Integer;
    FInstalmentType: string;
    FMonthOne: Boolean;
    FMonthStep: Integer;
    FNow3: TDateTime;
    FNow5: TDateTime;
    FP45GrossPay: Real;
    FP45Received: TDateTime;
    FP45TaxPaid: Real;
    FPayeMaxDeduction: Real;
    FPayInAdvance: Boolean;
    FPayKey: Real;
    FPaymentMethod: string;
    FPaymentMatMethod: string;  //1066775_MN_Flexi payment
    FPlanCode: string;
    FPLAType: Boolean;
    FPostAdj: Real;
    FReason: string;
    FSecondLetter: Char;
    FSecondLetterIndex: Integer;
    FSourceCompany: TDataSet;
    FSourceMasterArchive: TDataSet;
    FSourcePayHeader: TDataSet;
    FStartDate: TDateTime;
    FSuspended: Boolean;
    FSuspendedString: string;
    FTaxCode: string;
    FTaxFree: Boolean;
    FWithProfit: Boolean;
    FMaturityDate : TDateTime ;
    FTax_Free_Override: Boolean;
    procedure SetInstalmentType(const Value: string);
    procedure SetPlanCode(const Value: string);
    procedure SetReason(const Value: string);
    procedure SetSuspended(Value: Boolean);
    procedure SetTaxCode(const Value: string);
    procedure SetInstalments(Value: Integer);
    function GetIsFirstYear: Boolean;
    function GetInstalments: integer;
    function GetGrossAnnuity: Real;
    function GetDependantsAnnuity: Real;
  public
    _PayDate: TDateTime;
    CalcNetPay: Real;
    CalcTaxDue: Real;
    PE_CumFreePay: Real;
    PE_CumInstalments: Real;
    PE_Gross: Real;
    PE_InstalmentN: Integer;
    PE_TaxablePay: Real;
    PE_TaxDeduction: Real;
    PE_TaxLiability: Real;
    PH_BalCapitalElement: Real;
    PH_BalGrossAnnuity: Real;
    PH_CapitalElementDue: Real;
    PH_DependantsAnnuity: Real;
    PH_GrossAnnuity: Real;
    PH_GrossAnnuityDue: Real;
    PH_InstalmentsDue: Integer;
    PH_InstalmentsRemaining: Integer;
    PH_NextAnniversary: TDateTime;
    PH_AnniversaryYear1: TDateTime;
    PH_NextPayDue: TDateTime;
    PH_Status: string;
    str_glb_OptionName: TOverrideOption;
    Temp_AnnuityGross: Real;
    Temp_CapitalElement: Real;
    Temp_ID: Integer;
    Temp_InstalmentsPaid: Integer;
    Temp_MonthOneDeduction: Real;
    Temp_Net: Real;
    Temp_TaxYearOfLastPayment: Integer;
    class function IsICFP(const PlanCode: string): Boolean;
    class function IsPayInAdvance(const InstalmentType: string): Boolean;
    class function TaxMonthOf(Date: TDateTime): Integer;
    class function TaxYearOf(Date: TDateTime): Integer;
    class function Trunc2DP(Value: Real): Real;
    constructor Create(MasterArchive, PayHeader, Company: TDataSet);
    function CalculateInstalment(TotalAmount, RemainingAmount: Real): Real;
    function CalculateNextAnniversaryDate(first: Boolean = False): TDateTime;
    function CalculateNextPaymentDate: TDateTime;
    function SelectPayDate(FirstLine: Boolean): TDateTime;
    procedure CalcInstalmentN;
    procedure GetPaymentRecord(const Reason: string);
    property RO_CapitalElement: Real read FCapitalElement;
    property RO_FirstLetter: Char read FFirstLetter;
    property RO_FirstPayment: Boolean read FFirstPayment;
    property RO_FreePayMultiplier: Integer read FFreePayMultiplier;
    property RO_GadReviewDate: TDateTime read FGadReviewDate;
    property RO_GrossAnnuityYear1: Real read FGrossAnnuityYear1;
    property RO_ICFP: Boolean read FICFP;
    property RO_InitPayMethod: string read FInitPayMethod;
    property RO_Instalments: Integer read FInstalments;
    property RO_InstalmentsYear1: Integer read FInstalmentsYear1;
    property RO_InstalmentType: string read FInstalmentType;
    property RO_MonthOne: Boolean read FMonthOne;
    property RO_MonthStep: Integer read FMonthStep;
    property RO_Now5: TDateTime read FNow5;
    property RO_Now3: TDateTime read FNow3;
    property RO_P45GrossPay: Real read FP45GrossPay;
    property RO_P45Received: TDateTime read FP45Received;
    property RO_P45TaxPaid: Real read FP45TaxPaid;
    property RO_PayeMaxDeduction: Real read FPayeMaxDeduction;
    property RO_PayInAdvance: Boolean read FPayInAdvance;
    property RO_PayKey: Real read FPayKey;
    property RO_PaymentMethod: string read FPaymentMethod write FPaymentMethod ;
    property RO_PaymentMatMethod: string read FPaymentMatMethod write FPaymentMatMethod ; //1066775_MN_Flexi payment    
    property RO_PlanCode: string read FPlanCode;
    property RO_PLAType: Boolean read FPLAType;
    property RO_PostAdj: Real read FPostAdj;
    property RO_Reason: string read FReason;
    property RO_SecondLetter: Char read FSecondLetter;
    property RO_StartDate: TDateTime read FStartDate;
    property RO_SuspendedString: string read FSuspendedString;
    property RO_TaxCode: string read FTaxCode;
    property RO_TaxFree: Boolean read FTaxFree;
    property RO_WithProfit: Boolean read FWithProfit;
    property RO_Tax_Free_Override: Boolean read FTax_Free_Override;
    property Suspended: Boolean read FSuspended write SetSuspended;
    property IsFirstYear: Boolean read GetIsFirstYear;
    property Instalments: integer read GetInstalments;
    property GrossAnnuity: Real read GetGrossAnnuity;
    property DependantsAnnuity: Real read GetDependantsAnnuity;
    property MaturityDate : TDateTime  read FMaturityDate;

    property SourceMasterArchive: TDataSet read FSourceMasterArchive;
    property SourcePayHeader: TDataSet read FSourcePayHeader;
    property SourceCompany: TDataSet read FSourceCompany;
  end;

const
  pmBACS     = 'B';
  pmCheque   = 'C';
  pmTT       = 'T';
  pmREVERSE  = 'R'; {NjC}
  ReasonLast = 'LAST';
  ReasonLump = 'LUMP';
  ReasonFirst = 'FIRST';
  ReasonOneOff = 'ONEOFF';
  ReasonImport = 'IMPORT';

implementation

uses
  SysUtils, StrUtils, DateUtils, Math, unitCommonConst, NonProcess;

constructor TPaymentObject.Create(MasterArchive, PayHeader, Company: TDataSet);
begin
  FSourceMasterArchive := MasterArchive;
  FSourcePayHeader := PayHeader;
  FSourceCompany := Company;
  inherited Create;
end;

procedure TPaymentObject.SetReason(const Value: string);
begin
  FReason := Value;
  FFirstPayment := FReason = 'FIRST';
  FNow5 := AddWorkingDays(FFirstPayment, Today, 5);
  FNow3 := AddWorkingDays(FFirstPayment, Today, 3);
end;

class function TPaymentObject.IsPayInAdvance(const InstalmentType: string): Boolean;
begin
  Result := InstalmentType = 'AD';
end;

procedure TPaymentObject.SetInstalmentType(const Value: string);
begin
  FInstalmentType := Value;
  FPayInAdvance := IsPayInAdvance(FInstalmentType);
end;

procedure TPaymentObject.SetTaxCode(const Value: string);
begin
  if Value = EMPTY then
  begin
    FTaxCode := 'BR';
  end
  else
  begin
    FTaxCode := UpperCase(Value);
  end;
  FMonthOne := FTaxCode[Length(FTaxCode)] = '*';
end;

procedure TPaymentObject.SetInstalments(Value: Integer);
begin
  FInstalments := Value;
  FMonthStep := 12 div FInstalments;
  if FMonthStep = ZERO then
  begin
    FMonthStep := ONE; // To avoid "division by zero" in case Instalments = 13
  end;
end;

class function TPaymentObject.IsICFP(const PlanCode: string): Boolean;
begin
  Result := PlanCode = '76';
end;

procedure TPaymentObject.SetPlanCode(const Value: string);
begin
  FPlanCode := Value;
  FWithProfit := FPlanCode[ONE] in ['W','P'];
  FICFP := IsICFP(FPlanCode);
  FFirstLetterIndex := IfThen(FWithProfit, 2, 1);
  FSecondLetterIndex := FFirstLetterIndex + ONE;
   //AzDO-51060
  if ((FPlanCode = '85') or (FPlanCode = '87') or (FPlanCode = '88')) then
  begin
       FPLAType := StrToIntDef(FPlanCode[FSecondLetterIndex], INVALID) > 9;
  end
  else
  begin
       FPLAType := StrToIntDef(FPlanCode[FSecondLetterIndex], INVALID) > 5;
  end;
  FFirstLetter := FPlanCode[FFirstLetterIndex];
  FSecondLetter := FPlanCode[FSecondLetterIndex];
  FTaxFree := (FSecondLetter = '6') or (FFirstLetter = '3') and (FSecondLetter in ['7'..'9']);
end;

procedure TPaymentObject.SetSuspended(Value: Boolean);
begin
  FSuspended := Value;
  FSuspendedString := IfThen(FSuspended, 'Y', 'N');
end;

procedure TPaymentObject.GetPaymentRecord(const Reason: string);
begin
  PH_GrossAnnuity := FSourcePayHeader.FieldByName('GROSS_ANNUITY').AsFloat;
  PH_BalGrossAnnuity := FSourcePayHeader.FieldByName('BAL_GROSS_ANNUITY').AsFloat;
  PH_GrossAnnuityDue := FSourcePayHeader.FieldByName('GROSS_ANNUITY_DUE').AsFloat;
  Temp_AnnuityGross := ZERO;

  FCapitalElement := FSourcePayHeader.FieldByName('CAPITAL_ELEMENT').AsFloat;
  PH_BalCapitalElement := FSourcePayHeader.FieldByName('BAL_CAPITAL_ELEMENT').AsFloat;
  PH_CapitalElementDue := FSourcePayHeader.FieldByName('CAPITAL_ELEMENT_DUE').AsFloat;
  Temp_CapitalElement := ZERO;

  CalcNetPay := ZERO;
  CalcTaxDue := ZERO;
  PE_CumInstalments := FSourcePayHeader.FieldByName('CUM_INSTALMENTS').AsFloat;
  PH_DependantsAnnuity := FSourcePayHeader.FieldByName('DEPENDANTS_ANNUITY').AsFloat;
  FInitPayMethod := FSourcePayHeader.FieldByName('INITPAYMETHOD').AsString;

  if (Reason = ReasonLast) or (Reason =  ReasonOneOff) then
    SetInstalments(12) //Treat LAST and ONEOFF as a monthly payment for tax calc
  else
    SetInstalments(FSourcePayHeader.FieldByName('INSTALMENTS').AsInteger);

  FInstalmentsYear1 := FSourcePayHeader.FieldByName('INSTALMENTS_YEAR1').AsInteger;
  FGrossAnnuityYear1 := FSourcePayHeader.FieldByName('GROSS_ANNUITY_YEAR1').AsFloat;
  PH_InstalmentsDue := FSourcePayHeader.FieldByName('INSTALMENTS_DUE').AsInteger;
  Temp_InstalmentsPaid := ZERO; // Number of payment calculated by forecast
  PH_InstalmentsRemaining := FSourcePayHeader.FieldByName('INSTALMENTS_REMAINING').AsInteger;
  SetInstalmentType(FSourcePayHeader.FieldByName('INSTALMENT_TYPE').AsString);
  PH_NextAnniversary := FSourcePayHeader.FieldByName('NEXT_ANNIVERSARY').AsDateTime;
  PH_AnniversaryYear1 := FSourcePayHeader.FieldByName('ANNIVERSARY_DATE_YEAR1').AsDateTime;
  PH_NextPayDue := FSourcePayHeader.FieldByName('NEXT_PAYMENT_DUE').AsDateTime;
  FPayeMaxDeduction := FSourceCompany.FieldByName('PAYE_MAX_DEDUCTION').AsFloat;
  FPayKey := FSourcePayHeader.FieldByName('PAYKEY').AsFloat;
  SetPlanCode(FSourcePayHeader.FieldByName('PLAN_CODE').AsString);
  SetReason(Reason);
  FStartDate := FSourcePayHeader.FieldByName('START_DATE').AsDateTime;
  PH_Status := FSourcePayHeader.FieldByName('STATUS').AsString;
  SetTaxCode(FSourcePayHeader.FieldByName('PAYE_CODE').AsString);
  PE_TaxLiability := FSourcePayHeader.FieldByName('TAX_LIABILITY').AsFloat;
  Temp_TaxYearOfLastPayment := ZERO;
  _PayDate := ZERO;
  PE_CumFreePay := ZERO;
  PE_InstalmentN := ZERO;
  PE_TaxablePay := ZERO;
  PE_Gross := ZERO;
  Temp_ID := ZERO;
  FFreePayMultiplier := ZERO;
  PE_TaxDeduction := ZERO;
  Temp_MonthOneDeduction := ZERO;
  Suspended := FSourcePayHeader.FieldByName('PAYMENTS_SUSPENDED').AsString = 'Y';
  FPaymentMethod := FSourcePayHeader.FieldByName('PAYMENT_METHOD').AsString;
  FPaymentMatMethod:= FSourceMasterArchive.FieldByName('MAT_PAYMENT_METHOD').AsString;//1066775_MN_Flexi payment
  FPostAdj := FSourcePayHeader.FieldByName('POST_ADJ').AsFloat;
  Temp_Net := ZERO;
  FGadReviewDate := FSourcePayHeader.FieldByName('GAD_REVIEW_DATE').AsDateTime;
  FP45Received := FSourceMasterArchive.FieldByName('P45_RECEIVED').AsDateTime;
  FP45TaxPaid := FSourcePayHeader.FieldByName('P45_TAX_PAID').AsFloat;
  FP45GrossPay := FSourcePayHeader.FieldByName('P45_GROSS_PAY').AsFloat;
  FMaturityDate := FSourceMasterArchive.FieldByName('MATURITY_DATE').AsDateTime;
  FTax_Free_Override := FSourceMasterArchive.FieldByName('TAX_FREE_OVERRIDE').AsString = 'Y';

end;

class function TPaymentObject.Trunc2DP(Value: Real): Real;
var
  SuperValue: Double;
begin
  SuperValue := Value * 100;
  Result := Int(SuperValue + 0.0004) / 100;
end;

function TPaymentObject.CalculateInstalment(TotalAmount, RemainingAmount: Real): Real;
begin
  if PH_InstalmentsRemaining < ONE then
  begin
    Result := ZERO;
  end
  else if PH_InstalmentsRemaining = ONE then
  begin
    Result := RemainingAmount;
  end
  else
  begin
    Result := Trunc2DP(TotalAmount / Instalments);
  end;
end;

function TPaymentObject.CalculateNextPaymentDate: TDateTime;
begin
  if FInstalments = 13 then
  begin
    Result := IncDay(PH_NextPayDue, 28);
  end
  else
  begin
    Result := IncMonth(FStartDate, Round(MonthSpan(FStartDate, PH_NextPayDue)) + FMonthStep);
  end;
end;

function TPaymentObject.CalculateNextAnniversaryDate(first: Boolean = False): TDateTime;
var
  gad_year, gad_month, gad_day,
    start_year, start_month, start_day: Word;
  tmpNextAnniversary: TDateTime;
begin
  if first then
  begin
    if RO_PlanCode = '82' then
    begin
      DecodeDate(RO_GadReviewDate, gad_year, gad_month, gad_day);
      DecodeDate(RO_StartDate, start_year, start_month, start_day);
      tmpNextAnniversary := IncYear(RO_GadReviewDate, start_year - gad_year); //  EncodeDate(start_year, start_month, start_day);
      if tmpNextAnniversary > RO_StartDate then
        tmpNextAnniversary := IncYear(tmpNextAnniversary, -1);
    end
    else
    begin
      tmpNextAnniversary := RO_StartDate;
    end;
  end
  else
  begin
    tmpNextAnniversary := PH_NextAnniversary;
  end;

  if FInstalments = 13 then
  begin
    Result := IncDay(tmpNextAnniversary, 364);
  end
  else
  begin
    Result := IncYear(tmpNextAnniversary);
  end;
end;

class function TPaymentObject.TaxMonthOf(Date: TDateTime): Integer;
begin
  Result := MonthOf(Date) - 3;
  if DayOf(Date) <= 5 then
  begin
    Dec(Result);
  end;
  if Result < ONE then
  begin
    Inc(Result, 12);
  end;
end;

class function TPaymentObject.TaxYearOf(Date: TDateTime): Integer;
var
  EndOfTaxYear: TDateTime;
begin
  Result := YearOf(Date);
  EndOfTaxYear := EncodeDate(Result, 4, 5);
  if Date <= EndOfTaxYear then
  begin
    Dec(Result);
  end;
end;

procedure TPaymentObject.CalcInstalmentN;
begin
  if FMonthOne then
  begin
    FFreePayMultiplier := ONE;
  end
  else
  begin
    FFreePayMultiplier := ((TaxMonthOf(_PayDate) - ONE) div FMonthStep + ONE);
  end;

  PE_InstalmentN := FMonthStep * FFreePayMultiplier;
end;

function TPaymentObject.SelectPayDate(FirstLine: Boolean): TDateTime;
begin
  if FirstLine then
  begin
    Result := FNow3 ;
  end
  else if str_glb_OptionName = ooManual then
  begin
    Result := Today;
  end
  else
  begin
    Result := PH_NextPayDue;
  end;
end;

function TPaymentObject.GetIsFirstYear: Boolean;
begin
  Result := PH_NextAnniversary = PH_AnniversaryYear1;
end;

function TPaymentObject.GetInstalments: integer;
begin
  Result := IfThen((RO_PlanCode = '82') and IsFirstYear, RO_InstalmentsYear1, RO_Instalments);
end;

function TPaymentObject.GetGrossAnnuity: Real;
begin
  Result := IfThen((RO_PlanCode = '82') and IsFirstYear, RO_GrossAnnuityYear1, PH_GrossAnnuity);
end;

function TPaymentObject.GetDependantsAnnuity: Real;
begin
  Result := PH_DependantsAnnuity;
end;

end.
