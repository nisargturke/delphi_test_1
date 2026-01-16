unit AuditTrail;

interface

uses SqlExpr;

type

TAuditTrail = class
  public
    constructor Create(AConnection: TSQLConnection);
    procedure StartAudit(changeReason: String);
    procedure StopAudit;
  private
    Connection: TSQLConnection;
    procedure SetAuditReason(changeReason: string);
    procedure EnableAudit;
    procedure DisableAudit;
    procedure RunStoredProc(storedProc: string); overload;
    procedure RunStoredProc(storedProc: string; const params: array of string); overload;
end;

implementation

const
  SCHEMA_NAME = 'ERIPORA';
  PROC_SET_REASON = 'AUD_SET_REASON';
  PROC_ENABLE_AUDIT = 'AUD_ENABLE_AUDIT';
  PROC_DISABLE_AUDIT = 'AUD_DISABLE_AUDIT';
  REASON_NONE = '';

{ TAuditTrail }

constructor TAuditTrail.Create(AConnection: TSQLConnection);
begin
  Connection := AConnection;
end;

procedure TAuditTrail.StartAudit(changeReason: String);
begin
  SetAuditReason(changeReason);
  EnableAudit;
end;

procedure TAuditTrail.StopAudit;
begin
  SetAuditReason(REASON_NONE);
  DisableAudit;
end;

procedure TAuditTrail.SetAuditReason(changeReason: string);
begin
  RunStoredProc(PROC_SET_REASON, changeReason);
end;

procedure TAuditTrail.DisableAudit;
begin
  RunStoredProc(PROC_DISABLE_AUDIT);
end;

procedure TAuditTrail.EnableAudit;
begin
  RunStoredProc(PROC_ENABLE_AUDIT);
end;

procedure TAuditTrail.RunStoredProc(storedProc: string);
begin
  RunStoredProc(storedProc, []);
end;

procedure TAuditTrail.RunStoredProc(storedProc: string;
  const params: array of string);
var
  proc: TSQLStoredProc;
  i, j: integer;
begin
  proc := TSQLStoredProc.Create(nil);
  try
    proc.SQLConnection := Connection;
    proc.SchemaName := SCHEMA_NAME;
    proc.StoredProcName := storedProc;
    j := 0;
    for i := low(params) to high(params) do
    begin
      proc.Params.Items[j].AsString := params[i];
      inc(j);
    end;
    proc.ExecProc;
  finally
    proc.Free;
  end;
end;

end.
