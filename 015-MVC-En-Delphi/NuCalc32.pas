unit NuCalc32;

interface

uses
  Math, SysUtils, WinTypes, WinProcs, Messages, Classes, DB, Forms,
  shellapi, UCrpe32, Dialogs, nonProcess, General, wwquery, TCSSimpleDataSet,
  TCSSQLConnection, FMTBCD, SimpleDS, Controls, unitPaymentObject, unitPaymentRecord,
  TaxCalcServiceCall, SQLExpr;

function CalcNextPaymentDue(X: TPaymentObject; InitialPay: Boolean): TDateTime;
function CalculatePLATax(Gross, Capital: Double; const TaxCode: string): Double;
function LastPayUnderGuarantee(dtStartDate: TDateTime; strGuarantee, strInstalmentType: string; Instalments: Integer): TDateTime;
function MoveMonth_OBSOLETE(MoveMonthDate, OrigDate: TdateTime; NthFactor: Integer): TdateTime;
function Round2DP(myDouble: Double): Double;
function RoundUp2DP(myDouble: Double): Double;
function Trunc2DP(myDouble: Double): Double;
procedure CalculateAndPostPayments(X: TPaymentObject; PayHeader, PaPayHis, PayeHist:TDataSet; MasterSource:TDataSet=nil; SetTransDate: Boolean=False;PaymentType:String='');
procedure InitialiseRoutine(Source: TDataSet);
function SetPAYEValues(X: TPaymentObject; PayHeader, PayeHist: TDataSet; FirstLine: Boolean; LastLine : Boolean; var ErrorMsg: string; Query: TSQLQuery): Boolean;
procedure UpdatePaymentHistory(X: TPaymentObject; PaPayHis: TDataSet; const PaymentMethod: string; PayDate: TDateTime; SetTransDate: Boolean=False; MasterArch:TDataSet=nil);
function LastPaymentDate(dtStartDate: TDateTime; strInstalmentType: string; strInstalments: Integer; ATerm : integer): TDateTime; {NjC}
function RejectPayment(v_paymentHeader : TPaymentHeader; v_paymentRow : TPaymentRow; APaPayHis, APayeHist, APayHeader : TDataset) :integer ; {NjC}
function RepayPayment(v_paymentHeader : TPaymentHeader; v_paymentRow : TPaymentRow; APaPayHis, APayeHist, APayHeader : TDataset; APayMethod : string ) :integer ; {NjC}
function CheckForValidInstalments(PolicyRef : String) : boolean; {NjC}
procedure RecalculateCumulatives(AInsertedRef : integer; APaPayHis,APayeHist,APayHeader : TDataset);


implementation

uses
  Contnrs, StrUtils, Gross, Variants, Windows, DateUtils, unitCommonConst, HashCodes;

const
  PLA_TAX_RATE = 0.2;

type
  TPayeTaxBand = record
    TaxRate: Real;
    UpperLimit: Real;
    CumTax: Real;
    ProportionalUpperLimit: Real; // Temp variable
    ProportionalCumTax: Real; // Temp variable
  end;

  TPayeTaxTable = class
  private
    FTaxRateAdditional: Real;
    FTaxRateBasic: Real;
    FTaxRateHigher: Real;
    FTaxTable: array of TPayeTaxBand;
    FYear: Integer;
  public
    constructor Create(Year: Integer);
    function CalclateTaxDue(Proportion, TaxablePay: Real): Real;
    procedure AddBand(RateIndex: Integer; TaxRate, UpperLimit, CumTax: Real);
    property TaxRateAdditional: Real read FTaxRateAdditional;
    property TaxRateBasic: Real read FTaxRateBasic;
    property TaxRateHigher: Real read FTaxRateHigher;
    property Year: Integer read FYear;
  end;

  TPayeTaxObject = class
  private
    FTaxTables: TList;
  public
    constructor Create;
    destructor Destroy; override;
    function GetTaxTable(Year: Integer): TPayeTaxTable;
    procedure AddBand(Year, RateIndex: Integer; TaxRate, UpperLimit, CumTax: Real);
  end;

function GrossPayments(X: TPaymentObject; Gross_temp: Double): Double; forward;
function CalculateTaxDue(PayObj: TPaymentObject; var ErrorMsg: String; Query: TSQLQuery): boolean; forward;
procedure UpdateICFPPaymentHistory(X: TPaymentObject; PaPayHis: TDataSet; Gross: Double; const PaymentMethod: string); forward;
function GetTaxFreePay(X: TPaymentObject): Real; forward;
procedure UpdatePayHeader(X: TPaymentObject; PayHeader: TDataSet; Gross: Double); forward;

var
  PayeTaxObject: TPayeTaxObject;

procedure InitialiseRoutine(Source: TDataSet);
begin
  Source.First;
  while not Source.Eof do
  begin
    PayeTaxObject.AddBand(
      Source.FieldByName('YEAR').AsInteger,
      Source.FieldByName('RATEINDEX').AsInteger,
      Source.FieldByName('TAX_RATE').AsFloat / 100.0,
      Source.FieldByName('CUM_BAND').AsFloat,
      Source.FieldByName('CUM_TAX').AsFloat
      );
    Source.Next;
  end;
end;

function SetPAYEValues(X: TPaymentObject; PayHeader, PayeHist: TDataSet; FirstLine: Boolean; LastLine: Boolean;
                       var ErrorMsg: string; Query: TSQLQuery): Boolean;
var
  NewTaxYear: Boolean;
begin
  Result := True;

  PayeHist.Refresh;
  PayeHist.Last;
  X.Temp_TaxYearOfLastPayment := X.TaxYearOf(PayeHist.FieldByName('PAY_DATE').AsDateTime);
  X.Temp_ID := PayeHist.FieldByName('REF').AsInteger + ONE;

  // Determine if this is the first payment in tax year
  NewTaxYear := X.Temp_TaxYearOfLastPayment <> X.TaxYearOf(X._PayDate);

  // Calculate gross payment
  if FirstLine or LastLine then
  begin
    X.PE_Gross := X.Temp_AnnuityGross;
  end
  else
  begin
    if X.str_glb_OptionName <> ooImport then
    begin
      X.PE_Gross := X.CalculateInstalment(X.GrossAnnuity + X.PH_DependantsAnnuity, X.PH_BalGrossAnnuity);
    end ;

    // Override (Manual / Create)
    if X.str_glb_OptionName = ooCreate then
    begin
      X.PE_Gross := GrossPayments(X, X.PE_Gross);
    end
    else if X.str_glb_OptionName = ooImport then
    begin
      if X.Suspended then
      begin
          X.Suspended := False;
          X.PH_GrossAnnuityDue := ZERO;
          PayHeader.Edit;
          PayHeader.FieldByName('PAYMENTS_SUSPENDED').AsString := X.RO_SuspendedString;
          PayHeader.FieldByName('GROSS_ANNUITY_DUE').AsFloat := X.PH_GrossAnnuityDue;
          PayHeader.Post;
      end ;
    end
    else if X.str_glb_OptionName = ooManual then
    begin
      X.PE_Gross := GrossPayments(X, X.PH_GrossAnnuityDue);
      if X.Suspended then
      begin
        if MessageDlg(Format('Payments will be unsuspended and Gross Payment of %g will be created. Do you wish to continue?', [X.PE_Gross]), mtConfirmation, [mbYes, mbNo], NO_HELP) = mrYes then
        begin
          X.Suspended := False;
          X.PH_GrossAnnuityDue := ZERO;
          PayHeader.Edit;
          PayHeader.FieldByName('PAYMENTS_SUSPENDED').AsString := X.RO_SuspendedString;
          PayHeader.FieldByName('GROSS_ANNUITY_DUE').AsFloat := X.PH_GrossAnnuityDue;
          PayHeader.Post;
        end
        else
        begin
          X.str_glb_OptionName := ooNone;
          Abort;
        end;
      end
      else
      begin
        if MessageDlg(Format('Gross Payment of %g will be created. Do you wish to continue?', [X.PE_Gross]), mtConfirmation, [mbYes, mbNo], NO_HELP) <> mrYes then
        begin
          X.str_glb_OptionName := ooNone;
          Abort;
        end;
      end;
    end
  end;

  // Determine Installment N and Freepay multiplier
  X.CalcInstalmentN;

  // Reset or get cumulated instalment / tax
  if NewTaxYear then
  begin
    if X.TaxYearOf(X.RO_P45Received) = X.TaxYearOf(X._PayDate) then
    begin
      X.PE_CumInstalments := X.RO_P45GrossPay;
      X.PE_TaxLiability := X.RO_P45TaxPaid;
    end
    else
    begin
      X.PE_CumInstalments := ZERO;
      X.PE_TaxLiability := ZERO;
    end;
  end;

  if not X.Suspended then
  begin
    X.PE_CumFreePay := GetTaxFreePay(X) * X.RO_FreePayMultiplier;
    X.PE_CumInstalments := X.PE_CumInstalments + X.PE_Gross;

    if X.RO_MonthOne then
      X.PE_TaxablePay := X.PE_Gross - X.PE_CumFreePay
    else
      X.PE_TaxablePay := X.PE_CumInstalments - X.PE_CumFreePay;

    X.Temp_MonthOneDeduction := IfThen(X.RO_MonthOne, ZERO, -X.PE_TaxLiability);

    if CalculateTaxDue(X, ErrorMsg, Query) then
    begin
      if X.PE_Gross <> 0 then
      begin
        PayeHist.Insert;
        PayeHist.FieldByName('POLICY_NO').AsFloat := X.RO_PayKey;
        PayeHist.FieldByName('REF').AsInteger := X.Temp_ID;
        PayeHist.FieldByName('PAYE_CODE').AsString := X.RO_TaxCode;
        PayeHist.FieldByName('GROSS').AsFloat := X.PE_Gross;
        PayeHist.FieldByName('INSTALMENT_N').AsInteger := X.PE_InstalmentN;
        PayeHist.FieldByName('CUM_INSTALMENTS').AsFloat := X.PE_CumInstalments;
        PayeHist.FieldByName('PAY_DATE').AsDateTime := X._PayDate;
        PayeHist.FieldByName('CUM_FREE_PAY').AsFloat := X.PE_CumFreePay;
        PayeHist.FieldByName('TAXABLE_PAY').AsFloat := X.PE_TaxablePay;
        PayeHist.FieldByName('TAX_LIABILITY').AsFloat := X.PE_TaxLiability;
        PayeHist.FieldByName('TAX_DEDUCTION').AsFloat := X.PE_TaxDeduction;
        PayeHist.Post;
        PayeHist.Refresh;
      
        PayHeader.Edit;
        PayHeader.FieldByName('CUM_FREE_PAY').AsFloat := X.PE_CumFreePay;
        PayHeader.FieldByName('CUM_INSTALMENTS').AsFloat := X.PE_CumInstalments;
        PayHeader.FieldByName('TAXABLE_PAY').AsFloat := X.PE_TaxablePay;
        PayHeader.FieldByName('TAX_DEDUCTION').AsFloat := X.PE_TaxDeduction;
        PayHeader.FieldByName('TAX_LIABILITY').AsFloat := X.PE_TaxLiability;
        PayHeader.FieldByName('INSTALMENT_N').AsInteger := X.PE_InstalmentN;
        PayHeader.Post;
			end;
    end
    else
    begin
      Result := False;
    end;
  end;

end;

function Trunc2DP(myDouble: Double): Double;
var
  SuperValue: Double;
begin
  SuperValue := myDouble * 100;
  Result := Int(superValue + 0.0004) / 100;
end;

function MoveMonth_OBSOLETE(MoveMonthDate, OrigDate: TdateTime; NthFactor: Integer): TdateTime;
var
  Day, month, year, MyVar: Integer;
begin
  //KH
  Result := -1;
  begin
    Month := StrToInt(FormatDateTime('m', MoveMonthDate));
    Year := StrToInt(FormatDateTime('yyyy', MoveMonthDate));

    MyVar := Month + (12 * Year);
    MyVar := MyVar + NthFactor;

    Year := Trunc((MyVar - 1) / 12);
    Month := ((MyVar - 1) mod 12) + 1;
    Day := StrToInt(FormatDateTime('d', OrigDate));
  end;

  repeat
    try
      Result := EncodeDate(Year, Month, Day);
      Break;
    except
      Dec(Day);
    end;
  until False;
end;

function GetTaxFreePay(X: TPaymentObject): Real;
var
  i, NumPart: Integer;
begin
  NumPart := ZERO;
  for i := ONE to Length(X.RO_TaxCode) do
  begin
    if X.RO_TaxCode[i] in ['0'..'9'] then
    begin
      NumPart := NumPart * 10 + Ord(X.RO_TaxCode[i]) - Ord('0');
    end;
  end;
  if NumPart <= ONE then // ZERO = D0, ONE = D1
  begin
    Result := ZERO;
  end
  else
  begin
    Result := Round2DP((RoundUp2DP((NumPart mod 500 * 10 + 9) / 12) + NumPart div 500 * RoundUp2DP(5000 / 12)) * 12 / X.RO_Instalments);

    if (Copy(X.RO_TaxCode, 1, 1) = 'K') or (Copy(X.RO_TaxCode, 2, 1) = 'K') then
    begin
      Result := -Result;
    end;
  end;
end;

procedure AllowMaximumTaxDeduction(X: TPaymentObject);
begin
  X.PE_TaxDeduction := Max(X.PE_TaxDeduction, -Trunc2DP(X.PE_Gross * X.RO_PayeMaxDeduction / 100));
end;

function CalculateTaxDue(PayObj: TPaymentObject; var ErrorMsg: String; Query: TSQLQuery): boolean;
var
  TaxCalc: TTaxCalcServiceCallDataModule;
  TaxDue: Double;
begin
  Result := False;
  ErrorMsg := '';

  if (PayObj.RO_PlanCode = '81') or (PayObj.RO_PlanCode = '83') or (PayObj.RO_PlanCode = '85') or (PayObj.RO_PlanCode = '88') or (PayObj.ro_tax_free_override) then
  begin
    PayObj.PE_TaxDeduction := 0;
    Result := True;
    Exit;
  end;

  TaxCalc := TTaxCalcServiceCallDataModule.Create(nil);

  try
    try
      if TaxCalc.CallTaxCalcService(PayObj.RO_TaxCode,
                                    PayObj.PE_Gross,
                                    PayObj.PE_CumInstalments,
                                    PayObj.PE_TaxLiability * -1, //
                                    PayObj._PayDate,
                                    PayObj.Instalments,
                                    TaxDue,
                                    ErrorMsg,
                                    Query)
      then
      begin
        PayObj.PE_TaxDeduction := -1 * TaxDue;

        if IsIn(PayObj.RO_TaxCode, ['NT', 'NT*']) then
          PayObj.PE_TaxablePay := 0;

        PayObj.PE_TaxLiability := PayObj.PE_TaxLiability + PayObj.PE_TaxDeduction;
        Result := True;
      end;
    except
      on e: Exception do
      begin
        ErrorMsg := e.message;
      end;
    end;
  finally
    TaxCalc.Free;
  end;
end;


    {

procedure CalculateTaxDue(X: TPaymentObject);
var
  TaxCalculated: Boolean;
  PayeTaxTable: TPayeTaxTable;
begin
  TaxCalculated := False;

  if (X.RO_PlanCode = '81') or (X.RO_PlanCode = '83') or (X.RO_PlanCode = '85') or (X.RO_PlanCode = '88') or (x.ro_tax_free_override) then
  begin
    X.PE_TaxDeduction := 0;
    TaxCalculated := True;
  end
  else
  begin
    if X.RO_MonthOne or (X.PE_CumInstalments <= X.PE_CumFreePay) then
    begin
      if X.PE_TaxablePay <= ZERO then
      begin
        X.PE_TaxDeduction := X.Temp_MonthOneDeduction;
        X.PE_TaxLiability := X.PE_TaxLiability + X.PE_TaxDeduction;          //IS THIS OK WITH LIFELITE ?
        TaxCalculated := True;
      end;
      if Pos('*', X.RO_TaxCode) > ZERO then
      begin
        if GetTaxFreePay(X) >= X.PE_Gross then
        begin
          X.PE_TaxDeduction := X.Temp_MonthOneDeduction;
          TaxCalculated := True;
        end;
      end;
    end;
  end;

  if TaxCalculated then
  begin
    Exit;
  end;


  PayeTaxTable := PayeTaxObject.GetTaxTable(X.TaxYearOf(X._PayDate));
  if not Assigned(PayeTaxTable) then
  begin
    MessageDlg(Format('Tax rates for year %d have not been updated yet! Please update them first. Application will now terminate.', [X.TaxYearOf(X._PayDate)]), mtError, [mbOk], NO_HELP);
    Application.Terminate;
    Abort;
  end;

  if X.RO_TaxCode = 'NT' then
  begin
    X.PE_TaxablePay := ZERO;
    X.PE_TaxDeduction := X.Temp_MonthOneDeduction - Trunc2DP(Int(X.PE_TaxablePay) * PayeTaxTable.TaxRateBasic);
  end
  else if X.RO_TaxCode = 'NT*' then
  begin
    X.PE_TaxablePay := ZERO;
    X.PE_TaxDeduction := X.Temp_MonthOneDeduction - Trunc2DP(Int(X.PE_TaxablePay) * PayeTaxTable.TaxRateBasic);
  end
  else if X.RO_TaxCode = 'D0' then
  begin
    X.PE_TaxDeduction := X.Temp_MonthOneDeduction - Trunc2DP(Int(X.PE_TaxablePay) * PayeTaxTable.TaxRateHigher);
  end
  else if X.RO_TaxCode = 'D0*' then
  begin
    X.PE_TaxDeduction := X.Temp_MonthOneDeduction - Trunc2DP(Int(X.PE_Gross) * PayeTaxTable.TaxRateHigher);
  end
  else if X.RO_TaxCode = 'D1' then
  begin
    X.PE_TaxDeduction := X.Temp_MonthOneDeduction - Trunc2DP(Int(X.PE_TaxablePay) * PayeTaxTable.TaxRateAdditional);
  end
  else if X.RO_TaxCode = 'D1*' then
  begin
    X.PE_TaxDeduction := X.Temp_MonthOneDeduction - Trunc2DP(Int(X.PE_Gross) * PayeTaxTable.TaxRateAdditional);
  end
  else if X.RO_TaxCode = 'BR' then
  begin
    X.PE_TaxDeduction := X.Temp_MonthOneDeduction - Trunc2DP(Int(X.PE_TaxablePay) * PayeTaxTable.TaxRateBasic);
  end
  else if X.RO_TaxCode = 'BR*' then
  begin
    X.PE_TaxDeduction := X.Temp_MonthOneDeduction - Trunc2DP(Int(X.PE_Gross) * PayeTaxTable.TaxRateBasic);
  end
  else
  begin
    X.PE_TaxDeduction := X.Temp_MonthOneDeduction - PayeTaxTable.CalclateTaxDue(IfThen(X.RO_MonthOne, X.RO_Instalments, 12 / X.PE_InstalmentN), X.PE_TaxablePay);
  end;
  AllowMaximumTaxDeduction(X);
  X.PE_TaxLiability := X.PE_TaxLiability + X.PE_TaxDeduction;
end;    }

function Round2DP(myDouble: Double): Double;
var
  addValue, SuperValue, DecimalValue: Double;
begin
  SuperValue := myDouble * 100;
  DecimalValue := Frac(superValue);
  { Line below added to resolve a fractional problem }
  DecimalValue := DecimalValue + 0.000005;
  if DecimalValue >= 0.5 then
    addValue := 1
  else
    addValue := 0;
  Result := (Int(superValue) + addValue) / 100;
end;

function RoundUp2DP(myDouble: Double): Double;
var
  SuperValue: Double;
begin
  SuperValue := myDouble * 100;
  if Int(superValue) = superValue then
    Result := myDouble
  else
    Result := (Int(superValue) + 1) / 100;
end;

//New parameter MasterSource added by MN for incident 1066775_Flexi payment
procedure CalculateAndPostPayments(X: TPaymentObject; PayHeader, PaPayHis, PayeHist:TDataSet; MasterSource:TDataSet=nil; SetTransDate: Boolean=False;PaymentType:String='');
begin
  if X.RO_PLAType then
  begin
    if PayHeader.FieldByName('LIFEONEDEAD').AsString <> 'Y' then
    begin
      if X.RO_ICFP then
        X.Temp_AnnuityGross := X.CalculateInstalment(X.PH_GrossAnnuity, X.PH_BalGrossAnnuity)
      else
        X.Temp_AnnuityGross := X.PH_GrossAnnuity * X.RO_MonthStep / 12;
    end
    else
      X.Temp_AnnuityGross := 0;

    X.Temp_AnnuityGross := X.Temp_AnnuityGross + X.PH_DependantsAnnuity * X.RO_MonthStep / 12;
    if X.str_glb_OptionName = ooCreate then
    begin
      X.Temp_AnnuityGross := GrossPayments(X, X.Temp_AnnuityGross);
    end
    else if (X.str_glb_OptionName = ooManual) or (X.str_glb_OptionName = ooImport) then
    begin
      X.Temp_AnnuityGross := GrossPayments(X, X.PH_GrossAnnuityDue);
      if X.Suspended then
      begin
        if X.str_glb_OptionName = ooImport then
        begin
          X.Suspended := False;
          X.PH_GrossAnnuityDue := ZERO;
          PayHeader.Edit;
          PayHeader.FieldByName('PAYMENTS_SUSPENDED').AsString := X.RO_SuspendedString;
          PayHeader.FieldByName('GROSS_ANNUITY_DUE').AsFloat := X.PH_GrossAnnuityDue;
          PayHeader.Post;
        end
        else
        begin
          if MessageDlg(Format('Payments will be unsuspended and Gross Payment of %g will be created. Do you wish to continue?', [X.Temp_AnnuityGross]), mtConfirmation, [mbYes, mbNo], NO_HELP) = mrYes then
          begin
            X.Suspended := False;
            X.PH_GrossAnnuityDue := ZERO;
            PayHeader.Edit;
            PayHeader.FieldByName('PAYMENTS_SUSPENDED').AsString := X.RO_SuspendedString;
            PayHeader.FieldByName('GROSS_ANNUITY_DUE').AsFloat := X.PH_GrossAnnuityDue;
            PayHeader.Post;
          end
          else
          begin
            X.str_glb_OptionName := ooNone;
            Abort;
          end;
        end;
      end
      else
      begin
        if X.str_glb_OptionName = ooManual then
        begin
          if MessageDlg(Format('Gross Payment of %g will be created. Do you wish to continue?', [X.Temp_AnnuityGross]), mtConfirmation, [mbYes, mbNo], NO_HELP) <> mrYes then
          begin
            X.str_glb_OptionName := ooNone;
            Abort;
          end;
        end;
      end
    end;
    if not X.RO_ICFP then
    begin
      X.Temp_CapitalElement := X.CalculateInstalment(X.RO_CapitalElement, X.PH_BalCapitalElement);
      X.CalcTaxDue := CalculatePLATax(X.Temp_AnnuityGross, X.Temp_CapitalElement, X.RO_TaxCode);
    end;
  end
  else
  begin
    X.Temp_AnnuityGross := IfThen(X.Suspended, ZERO, X.PE_Gross);
    X.CalcTaxDue := X.PE_TaxDeduction;
    X.Temp_CapitalElement := ZERO;
  end;

  X.CalcNetPay := X.Temp_AnnuityGross + X.CalcTaxDue;
  if not X.Suspended then
  begin
    if X.RO_PLAType and X.RO_ICFP then
    begin
      UpdateICFPPaymentHistory(X, PaPayHis, X.Temp_AnnuityGross, X.RO_PaymentMethod); //inserts papayhis record
    end
    else
    begin //1066775_MN_Flexi payment
      if UpperCase(X.RO_Reason) = ReasonLast then
         UpdatePaymentHistory(X, PaPayHis, X.RO_PaymentMatMethod, X._PayDate, SetTransDate, MasterSource)
      else
        if (UpperCase(X.RO_Reason) = ReasonOneOff) or (UpperCase(X.RO_Reason) = ReasonImport) then
           UpdatePaymentHistory(X, PaPayHis, X.RO_InitPayMethod, X._PayDate, SetTransDate)
        else
           UpdatePaymentHistory(X, PaPayHis, X.RO_PaymentMethod, X._PayDate, SetTransDate) //inserts papayhis record
    end;
  end;

  if (X.str_glb_OptionName <> ooManual) and (X.str_glb_OptionName <> ooImport) then
  begin
    UpdatePayHeader(X, PayHeader, X.Temp_AnnuityGross);
  end;
  X.str_glb_OptionName := ooNone;
end;

function CalculatePLATax(Gross, Capital: Double; const TaxCode: string): Double;
begin
  if (Gross <= Capital) or (TaxCode = 'NT') or (TaxCode = 'NT*') then
    Result := ZERO
  else
    Result := Round2DP((Capital - Gross) * PLA_TAX_RATE);
end;

//New parameter DM.qMASTER_ARCHIVE added by MN for the incident 1066775_MN_Flexi payment
procedure UpdatePaymentHistory(X: TPaymentObject; PaPayHis: TDataSet; const PaymentMethod: string; PayDate: TDateTime; SetTransDate: Boolean=False;MasterArch:TDataSet=nil);
begin
  PaPayHis.Last; //to get last ref
  if X.Temp_AnnuityGross <> 0 then
  begin
    X.Temp_ID := PaPayHis.FieldByName('REF').AsInteger + ONE;
    PaPayHis.Insert;
    PaPayHis.FieldByName('POLICY_NO').AsFloat := X.RO_PayKey;
    PaPayHis.FieldByName('REF').AsInteger := X.Temp_ID;
    PaPayHis.FieldByName('GROSS').AsFloat := X.Temp_AnnuityGross;
    PaPayHis.FieldByName('PRE_ADJ').AsFloat := ZERO;
    PaPayHis.FieldByName('CAPITAL_ELEMENT').AsFloat := X.Temp_CapitalElement;
    PaPayHis.FieldByName('TAX').AsFloat := X.CalcTaxDue;
    PaPayHis.FieldByName('POST_ADJ').AsFloat := X.RO_PostAdj;
    PaPayHis.FieldByName('NET').AsFloat := X.CalcNetPay + X.RO_PostAdj; // The only DIFFERENCE - the only difference to what?
    PaPayHis.FieldByName('PAY_DATE').AsDateTime := IfThen(X.str_glb_OptionName = ooManual, Today, PayDate);
    PaPayHis.FieldByName('BACS_DATE').AsDateTime := PreviousWorkingDay(PayDate); // Bug: not in sync with PAY_DATE -- ttd
    PaPayHis.FieldByName('PAYMENT_METHOD').AsString := PaymentMethod;
    PaPayHis.FieldByName('REASON').AsString := X.RO_Reason;
    if (PaPayHis.FieldByName('PAYMENT_METHOD').AsString = 'B') then
      PaPayHis.FieldByName('HASH_CODE').AsString := HashCodeGenerator.GenerateHashCode
    else
      PaPayHis.FieldByName('HASH_CODE').AsString := '';
    if UpperCase(X.RO_Reason)='LAST'then
    begin
      MasterArch.FieldByName('Mat_Sur_Trans_Date').AsDateTime:=Today;
      MasterArch.Post;
      MasterArch.Refresh;
    // Update the trans_date when the payment method is C or T, to pick the policy in the RTI List. Added by MN for the incident 1066775_Flexi payment.
      if not (SetTransDate)and((PaPayHis.FieldByName('PAYMENT_METHOD').AsString = 'C') or (PaPayHis.FieldByName('PAYMENT_METHOD').AsString = 'T')) then
        PaPayHis.FieldByName('TRANS_DATE').AsDateTime := Trunc(Now);
    end;
    if SetTransDate then
      PaPayHis.FieldByName('TRANS_DATE').AsDateTime := Trunc(Now);
    PaPayHis.Post;
    PaPayHis.Refresh;
  end;
end;

procedure UpdateICFPPaymentHistory(X: TPaymentObject; PaPayHis: TDataSet; Gross: Double; const PaymentMethod: string);
begin
  PaPayHis.Last;
  X.Temp_ID := PaPayHis.FieldByName('REF').AsInteger + ONE;
  PaPayHis.Insert;
  PaPayHis.FieldByName('POLICY_NO').AsFloat := X.RO_PayKey;
  PaPayHis.FieldByName('REF').AsInteger := X.Temp_ID;
  PaPayHis.FieldByName('GROSS').AsFloat := X.Temp_AnnuityGross;
  PaPayHis.FieldByName('PRE_ADJ').AsFloat := ZERO;
  PaPayHis.FieldByName('PAY_DATE').AsDateTime := IfThen(X.str_glb_OptionName = ooManual, Today, X.PH_NextPayDue);
  PaPayHis.FieldByName('NET').AsFloat := 0;
  PaPayHis.FieldByName('TAX').AsFloat := X.CalcTaxDue;
  PaPayHis.FieldByName('CAPITAL_ELEMENT').AsFloat := X.Temp_CapitalElement;
  PaPayHis.FieldByName('POST_ADJ').AsFloat := X.RO_PostAdj;
  PaPayHis.FieldByName('BACS_DATE').AsDateTime := PreviousWorkingDay(X.PH_NextPayDue);
  PaPayHis.FieldByName('PAYMENT_METHOD').AsString := PaymentMethod;
//  PaPayHis.FieldByName('PAYMENT_METHOD').AsString := IfThen(X.str_glb_OptionName = ooManual, 'C', PaymentMethod);
  PaPayHis.FieldByName('REASON').AsString := X.RO_Reason;
  if (PaPayHis.FieldByName('PAYMENT_METHOD').AsString = 'B') then
    PaPayHis.FieldByName('HASH_CODE').AsString := HashCodeGenerator.GenerateHashCode
  else
    PaPayHis.FieldByName('HASH_CODE').AsString := '';
  PaPayHis.Post;
  PaPayHis.Refresh;
end;

procedure UpdatePayHeader(X: TPaymentObject; PayHeader: TDataSet; Gross: Double);
begin
  // WARNING: Compare with AnNuClc.UpdateMaster2
  if X.Suspended then
  begin
    X.PH_GrossAnnuityDue := X.PH_GrossAnnuityDue + Gross;
    X.PH_CapitalElementDue := X.PH_CapitalElementDue + X.Temp_CapitalElement;
    X.PH_InstalmentsDue := X.PH_InstalmentsDue + ONE;
  end;
  X.PH_BalGrossAnnuity := X.PH_BalGrossAnnuity - Gross;
  X.PH_BalCapitalElement := X.PH_BalCapitalElement - X.Temp_CapitalElement;
  X.PH_InstalmentsRemaining := X.PH_InstalmentsRemaining - ONE;
  X.PH_NextPayDue := X.CalculateNextPaymentDate;

  PayHeader.Edit;
//Added by _MN for request 1093242. Validate Nil income for RTI failures
  if UpperCase(X.RO_Reason)='LUMP' then
  begin
    if (X.PH_DependantsAnnuity > 0) or ((X.PH_DependantsAnnuity=0) and (X.PH_GrossAnnuity=0)) then
       PayHeader.FieldByName('DEPENDANTS_ANNUITY').AsFloat :=X.Temp_AnnuityGross
    else
       PayHeader.FieldByName('GROSS_ANNUITY_DUE').AsFloat :=X.Temp_AnnuityGross;
    PayHeader.FieldByName('NEXT_PAYMENT_DUE').AsVariant :=Null;
    PayHeader.FieldByName('NEXT_ANNIVERSARY').AsVariant :=Null;
  end
  else
  begin
    PayHeader.FieldByName('NEXT_PAYMENT_DUE').AsDateTime := X.PH_NextPayDue;
    PayHeader.FieldByName('GROSS_ANNUITY_DUE').AsFloat := X.PH_GrossAnnuityDue;
  end;
  //Commented the line and added it in the above RTI validation by _MN for request 1093242
  //PayHeader.FieldByName('GROSS_ANNUITY_DUE').AsFloat := X.PH_GrossAnnuityDue;
  PayHeader.FieldByName('CAPITAL_ELEMENT_DUE').AsFloat := X.PH_CapitalElementDue;
  PayHeader.FieldByName('INSTALMENTS_DUE').AsFloat := X.PH_InstalmentsDue;
  PayHeader.FieldByName('BAL_GROSS_ANNUITY').AsFloat := X.PH_BalGrossAnnuity;
  PayHeader.FieldByName('BAL_CAPITAL_ELEMENT').AsFloat := X.PH_BalCapitalElement;
  PayHeader.FieldByName('INSTALMENTS_REMAINING').AsInteger := X.PH_InstalmentsRemaining;
  //Commented the line and added it in the above RTI validation by _MN for request 1093242
  //PayHeader.FieldByName('NEXT_PAYMENT_DUE').AsDateTime := X.PH_NextPayDue;
  PayHeader.Post;
end;

function GrossPayments(X: TPaymentObject; Gross_temp: Double): Double;
begin
  Result := 0;
  frmGross.GrossPayment := Gross_temp;
  if frmGross.ShowModal = mrOk then
  begin
    Result := StrToFloat(frmGross.edtGross.Text);
  end
  else
  begin
    X.str_glb_OptionName := ooNone;
    Abort;
  end;
end;

function CalcNextPaymentDue(X: TPaymentObject; InitialPay: Boolean): TDateTime;
begin
  if InitialPay then
  begin
    Result := X.PH_NextPayDue;
  end
  else
  begin
    Result := X.CalculateNextPaymentDate;
  end;
end;

function LastPayUnderGuarantee(dtStartDate: TDateTime; strGuarantee, strInstalmentType: string; Instalments: Integer): TDateTime;
var
  intNoOfMonths: Integer;
  intGuaranteePeriod: Integer;
  strGuar:string;
begin
  if (UpperCase(strGuarantee) <> 'NONE') and (UpperCase(strGuarantee) <> 'N') and (strGuarantee <> '') and
    (strGuarantee <> '0') and (UpperCase(strGuarantee) <> 'LS') and (UpperCase(strGuarantee) <> 'CP')
    and (UpperCase(strGuarantee) <> 'GCO') and (UpperCase(strGuarantee) <> 'LUMP') then
  begin
    //Incident_1137987_MN_Guarantee of more than 10 years are not showing a LastPaymentGuaranteeDate
    strGuar:=UpperCase(strGuarantee);
    Delete(strGuar,Pos('YEAR',strGuar)-1,Length(strGuar));
    intGuaranteePeriod:=StrToIntDef(Trim(strGuar),0);
    //Incident_1137987_MN_Validate the Guarantee year from 1 to 30 years.
    if (intGuaranteePeriod > 0) and (intGuaranteePeriod <= 30)then
    begin
      intNoOfMonths := 12 * intGuaranteePeriod;
      if (UpperCase(strInstalmentType) = 'AD') then
      begin
        case Instalments of
          1: Dec(intNoOfMonths, 12);
          2: Dec(intNoOfMonths, 6);
          4: Dec(intNoOfMonths, 3);
        else
          Dec(intNoOfMonths);
        end;
      end;
      Result := IncMonth(dtStartDate, intNoOfMonths);
    end
    else
      Result := ZERO;
  end
  else
    Result := ZERO;
end;



function LastPaymentDate(dtStartDate: TDateTime; strInstalmentType: string; strInstalments: Integer; ATerm : integer): TDateTime; {NjC}
var
  PmtType : integer ;
begin
  // AR - arrears  AD-Advance
  if (Uppercase(strInstalmentType) <> 'AR') then
  begin
  end
  else //advance
  begin
  case strInstalments of
    12 : pmtType := 1;
    4  : pmtType := 3 ;
    2  : pmtType := 6;
    1  : pmtType := 12 ;
  else
    pmtType := 0 ;
  end ;
     ATerm := ATerm - pmtType ;
    end ;
  result := IncMonth(dtStartDate,ATerm) ;
end ;


function RejectPayment(v_paymentHeader : TPaymentHeader; v_paymentRow : TPaymentRow; APaPayHis, APayeHist, APayHeader : TDataset) :integer ;
var
  v_payMethod : string ;
  v_reason : string ;
  isValid : boolean ;
  RejectInCurrentTaxYear : boolean;
begin
   v_PayMethod := pmREVERSE ;
   v_reason    := 'RETURN';
  try
    with v_paymentRow do
    begin
      RejectInCurrentTaxYear := inCurrentTaxYear(v_paymentRow.pay_date) ;
      reason := v_reason ;
      isValid := reversePaymentRow(RejectInCurrentTaxYear) ;
      if isValid then
      begin
        if RejectInCurrentTaxYear then begin
          APaPayHis.Last;
        end ;
        new_ref := APaPayHis.FieldByName('REF').AsInteger + ONE;

        if (not RejectInCurrentTaxYear) then
        begin
          APaPayHis.last;
          while APaPayHis.FieldByName('REF').AsInteger >= new_ref do
          begin
            APaPayHis.Edit;
            APaPayHis.FieldByName('REF').AsInteger := APaPayHis.FieldByName('REF').AsInteger + ONE;
            APaPayHis.Prior;
          end ;
        end ;

        //PaPayHis record
        APaPayHis.Insert;
        APaPayHis.FieldByName('POLICY_NO').AsFloat       := policy_no ;
        APaPayHis.FieldByName('REF').AsInteger           := new_ref;
        APaPayHis.FieldByName('GROSS').AsFloat           := gross_val ;
        APaPayhis.FieldByName('NET').AsFloat             := gross_val - tax_deduction ;
        APaPayHis.FieldByName('PRE_ADJ').AsFloat         := pre_adj_val ;
        APaPayHis.FieldByName('CAPITAL_ELEMENT').AsFloat := capital_val;
        APaPayHis.FieldByName('TAX').AsFloat             := tax_val ;
        APaPayHis.FieldByName('POST_ADJ').AsFloat        := post_adj_val ;
        APaPayHis.FieldByName('NET').AsFloat             := net_val ;
        APaPayHis.FieldByName('PAY_DATE').AsDateTime     := pay_date ;
        APaPayHis.FieldByName('BACS_DATE').AsDateTime    := bacs_date ;

        APaPayHis.FieldByName('PAYMENT_METHOD').AsString := v_PayMethod ; // need to consider payment method
        APaPayHis.FieldByName('REASON').AsString         := v_Reason ;  // need to consider reasons

        // PAYEHIST RECORD
        if (not RejectInCurrentTaxYear) then
        begin
          APayehist.last;
          while APayehist.FieldByName('REF').AsInteger >= new_ref do
          begin
            APayeHist.edit;
            APayehist.FieldByName('REF').AsInteger := APayehist.FieldByName('REF').AsInteger + ONE;
            APayehist.prior;
          end ;
        end
        else
        begin
          APayeHist.Last ;
        end ;

        APayeHist.Insert ;
        APayehist.FieldByName('POLICY_NO').asFloat       := policy_no;
        APayehist.FieldByName('REF').AsInteger           := new_ref;
        APayehist.FieldByName('GROSS').AsFloat           := gross_val ;
        APayehist.FieldByName('CUM_INSTALMENTS').AsFloat := cum_instalments ;
        APayehist.FieldByName('CREATED_DATE').AsDateTime := created_date ;
        APayehist.FieldByName('PAYE_CODE').AsString      := paye_code ;
        APayehist.FieldByName('TAX_LIABILITY').AsFloat   := tax_liability ;
        APayehist.FieldByName('TAX_DEDUCTION').AsFloat   := tax_deduction ;
        APayehist.FieldByName('INSTALMENT_N').AsInteger  := instalmentN ;
        APayehist.FieldByName('PAY_DATE').AsDateTime     := pay_date ;
        APayehist.FieldByName('CUM_FREE_PAY').AsFloat    := cum_free_pay ;
        APayehist.FieldByName('TAXABLE_PAY').AsFloat     := cum_taxable_pay ;
      end ;
    end ;

    if (isValid) and (RejectInCurrentTaxYear) then
    begin
        //Payheader record
      with v_paymentHeader do
      begin
        ReverseHeaderRow(v_paymentRow);

        APayheader.Edit ;
        APayheader.FieldByName('NEXT_PAYMENT_DUE').AsDateTime	    := next_pmt_due ;
        APayheader.FieldByName('TAX_LIABILITY').AsFloat           := tax_liability ;
        APayheader.FieldByName('TAX_DEDUCTION').AsFloat           := v_paymentRow.tax_val ;
        APayheader.FieldByName('CUM_INSTALMENTS').AsFloat         := cum_instalments ;
        APayheader.FieldByName('CUM_FREE_PAY').AsFloat            := cum_free_pay  ;
        APayheader.FieldByName('TAXABLE_PAY').AsFloat             := taxable_pay ;
        APayHeader.FieldByName('GROSS_ANNUITY').AsFloat           := gross_annuity ;
        APayHeader.FieldByName('BAL_GROSS_ANNUITY').AsFloat       := gross_annuity_bal ;
        APayHeader.FieldByName('DEPENDANTS_ANNUITY').AsFloat      := dependant_annuity ;
        APayHeader.FieldByName('NEXT_ANNIVERSARY').AsDateTime     := next_anniversary ;
      end ;
    end ;

    if not RejectInCurrentTaxYear then begin
      RecalculateCumulatives(v_paymentRow.new_ref,APaPayHis,APayeHist, APayHeader) ;
    end ;

    if isvalid then
    begin
      result := v_paymentRow.new_ref ;
    end
    else
    begin
      result := -1 ;
    end ;

  except
    raise exception.create('There was an error rejecting this payment') ;
  end ;
end ;

{NjC}
function RepayPayment(v_paymentHeader : TPaymentHeader; v_paymentRow : TPaymentRow; APaPayHis, APayeHist, APayHeader : TDataset; APayMethod : string ) :integer ; {NjC}
var
  v_reason : string ;
  ReIssueInCurrentTaxYear : boolean ;
begin
  v_reason    := 'REISS' ;
  try
    with v_paymentRow do
    begin
      ReIssueInCurrentTaxYear := true ;

      if reason = 'RETURN' then
        reissuePaymentRow(ReIssueInCurrentTaxYear) ;

      APaPayHis.Last;
      new_ref := APaPayHis.FieldByName('REF').AsInteger + ONE;

      //PaPayHis record
      APaPayHis.Insert;
      APaPayHis.FieldByName('POLICY_NO').AsFloat       := policy_no ;
      APaPayHis.FieldByName('REF').AsInteger           := new_ref;
      APaPayHis.FieldByName('GROSS').AsFloat           := gross_val ;
      APaPayhis.FieldByName('NET').AsFloat             := gross_val - tax_deduction ;
      APaPayHis.FieldByName('PRE_ADJ').AsFloat         := pre_adj_val ;
      APaPayHis.FieldByName('CAPITAL_ELEMENT').AsFloat := capital_val;
      APaPayHis.FieldByName('TAX').AsFloat             := tax_val ;
      APaPayHis.FieldByName('POST_ADJ').AsFloat        := post_adj_val ;
      APaPayHis.FieldByName('NET').AsFloat             := net_val ;
      APaPayHis.FieldByName('PAY_DATE').AsDateTime     := pay_date ;
      APaPayHis.FieldByName('BACS_DATE').AsDateTime    := bacs_date ;

      APaPayHis.FieldByName('PAYMENT_METHOD').AsString := APayMethod ; // need to consider payment method
      APaPayHis.FieldByName('REASON').AsString         := v_Reason ;  // need to consider reasons

      if (APayMethod = 'B') then
        APaPayHis.FieldByName('HASH_CODE').AsString := HashCodeGenerator.GenerateHashCode
      else
        APaPayHis.FieldByName('HASH_CODE').AsString := '';



      // PAYEHIST RECORD
      APayeHist.Last ;
      APayeHist.Insert ;
      APayehist.FieldByName('POLICY_NO').asFloat       := policy_no;
      APayehist.FieldByName('REF').AsInteger           := new_ref;
      APayehist.FieldByName('GROSS').AsFloat           := gross_val ;
      APayehist.FieldByName('CUM_INSTALMENTS').AsFloat := cum_instalments ;
      APayehist.FieldByName('CREATED_DATE').AsDateTime := created_date ;
      APayehist.FieldByName('PAYE_CODE').AsString      := paye_code ;
      APayehist.FieldByName('TAX_LIABILITY').AsFloat   := tax_liability ;
      APayehist.FieldByName('TAX_DEDUCTION').AsFloat   := tax_deduction ;
      APayehist.FieldByName('INSTALMENT_N').AsInteger  := instalmentN ;
      APayehist.FieldByName('PAY_DATE').AsDateTime     := pay_date ;
      APayehist.FieldByName('CUM_FREE_PAY').AsFloat    := cum_free_pay ;
      APayehist.FieldByName('TAXABLE_PAY').AsFloat     := cum_taxable_pay ;
    end ;


    //Payheader record
    if (ReIssueInCurrentTaxYear) then
    begin
      with v_paymentHeader do
      begin
        if v_paymentRow.reason = 'RETURN' then
          ReissueHeaderRow(v_paymentRow);

        APayheader.Edit ;
        APayheader.FieldByName('NEXT_PAYMENT_DUE').AsDateTime	    := next_pmt_due ;
        APayheader.FieldByName('TAX_LIABILITY').AsFloat           := tax_liability  ;
        APayheader.FieldByName('TAX_DEDUCTION').AsFloat           := v_paymentRow.tax_val ;
        APayheader.FieldByName('CUM_INSTALMENTS').AsFloat         := cum_instalments ;
        APayheader.FieldByName('CUM_FREE_PAY').AsFloat            := cum_free_pay ;
        APayheader.FieldByName('TAXABLE_PAY').AsFloat             := taxable_pay  ;
        APayHeader.FieldByName('GROSS_ANNUITY').AsFloat           := gross_annuity ;
        APayHeader.FieldByName('BAL_GROSS_ANNUITY').AsFloat       := gross_annuity_bal ;
        APayHeader.FieldByName('DEPENDANTS_ANNUITY').AsFloat      := dependant_annuity ;
        APayHeader.FieldByName('NEXT_ANNIVERSARY').AsDateTime     := next_anniversary ;
      end ;
    end;
    result := v_paymentRow.new_ref ;
  except
    raise exception.create('There was an error rejecting this payment') ;
  end ;
end ;

function CheckForValidInstalments(PolicyRef : String) : boolean; {NjC}
begin
  result := true ;
end ;

procedure RecalculateCumulatives(AInsertedRef : integer; APaPayHis,APayeHist,APayHeader : TDataset);
var
  PaymentRow : TPaymentRow ;
begin
    APaPayHis.Locate('REF',AInsertedRef,[]);
    APayeHist.Locate('REF',AInsertedRef,[]);
    PaymentRow := TPaymentRow.Create(APaPayHis,APayeHist);
    PaymentRow.UpdateSubsequentPayments(StartOfCurrentTaxYear, APayHeader);
end ;

{function GetTaxFreePayForLine(X: TPaymentObject): Real;
var
  i, NumPart: Integer;
begin
  NumPart := ZERO;
  for i := ONE to Length(X.RO_TaxCode) do
  begin
    if X.RO_TaxCode[i] in ['0'..'9'] then
    begin
      NumPart := NumPart * 10 + Ord(X.RO_TaxCode[i]) - Ord('0');
    end;
  end;
  if NumPart <= ONE then // ZERO = D0, ONE = D1
  begin
    Result := ZERO;
  end
  else
  begin
    Result := Round2DP((RoundUp2DP((NumPart mod 500 * 10 + 9) / 12) + NumPart div 500 * RoundUp2DP(5000 / 12)) * 12 / X.RO_Instalments);
    if X.RO_TaxCode[ONE] = 'K' then
    begin
      Result := -Result;
    end;
  end;
end;}
     

constructor TPayeTaxTable.Create(Year: Integer);
begin
  inherited Create;
  FYear := Year;
  AddBand(INVALID, ZERO, ZERO, ZERO);
end;

procedure TPayeTaxTable.AddBand(RateIndex: Integer; TaxRate, UpperLimit, CumTax: Real);
begin
  SetLength(FTaxTable, Length(FTaxTable) + ONE);
  FTaxTable[Length(FTaxTable) - ONE].TaxRate := TaxRate;
  FTaxTable[Length(FTaxTable) - ONE].UpperLimit := UpperLimit;
  FTaxTable[Length(FTaxTable) - ONE].CumTax := CumTax;
  FTaxTable[Length(FTaxTable) - ONE].ProportionalUpperLimit := ZERO;
  FTaxTable[Length(FTaxTable) - ONE].ProportionalCumTax := ZERO;
  case RateIndex of
    1: FTaxRateBasic := TaxRate;
    2: FTaxRateHigher := TaxRate;
    3: FTaxRateAdditional := TaxRate;
  end;
end;

function TPayeTaxTable.CalclateTaxDue(Proportion, TaxablePay: Real): Real;
var
  i: Integer;
begin
  Result := ZERO;
  for i := Low(FTaxTable) to High(FTaxTable) do
  begin
    FTaxTable[i].ProportionalUpperLimit := Trunc2DP(FTaxTable[i].UpperLimit / Proportion);
    FTaxTable[i].ProportionalCumTax := Trunc2DP(FTaxTable[i].CumTax / Proportion);
  end;
  FTaxTable[High(FTaxTable)].ProportionalUpperLimit := MaxDouble;
  for i := ONE to High(FTaxTable) do
  begin
    if TaxablePay <= FTaxTable[i].ProportionalUpperLimit then
    begin
      Result := Trunc2DP(FTaxTable[i - ONE].ProportionalCumTax + (Int(TaxablePay) - FTaxTable[i - ONE].ProportionalUpperLimit) * FTaxTable[i].TaxRate);
      Break;
    end;
  end;
end;

constructor TPayeTaxObject.Create;
begin
  inherited Create;
  FTaxTables := TObjectList.Create;
end;

destructor TPayeTaxObject.Destroy;
begin
  FTaxTables.Free;
  inherited Create;  // eh?
end;

procedure TPayeTaxObject.AddBand(Year, RateIndex: Integer; TaxRate, UpperLimit, CumTax: Real);
var
  X: TPayeTaxTable;
begin
  X := GetTaxTable(Year);
  if not Assigned(X) then
  begin
    X := TPayeTaxTable.Create(Year);
    FTaxTables.Add(X);
  end;
  X.AddBand(RateIndex, TaxRate, UpperLimit, CumTax);
end;

function TPayeTaxObject.GetTaxTable(Year: Integer): TPayeTaxTable;
var
  i: Integer;
begin
  Result := nil;
  for i := ZERO to FTaxTables.Count - ONE do
  begin
    if TPayeTaxTable(FTaxTables[i]).Year = Year then
    begin
      Result := FTaxTables[i];
      Break;
    end;
  end;
end;

initialization
  PayeTaxObject := TPayeTaxObject.Create;

finalization
  PayeTaxObject.Free;

end.
