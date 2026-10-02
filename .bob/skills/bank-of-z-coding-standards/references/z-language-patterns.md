# Z Language Patterns — Bank of Z

Detection patterns and idioms for IBM Z languages as used in this project.

---

## Subsystem Detection

### CICS Programs
Look for any of:
- `CBL CICS(` directive
- `PROCESS CICS,`
- `EXEC CICS` anywhere in procedure division
- `DFHCOMMAREA` in LINKAGE SECTION

### IMS DL/I Programs  
Look for any of:
- `CALL 'CBLTDLI'` or `CALL "CBLTDLI"`
- `ENTRY "DLITCBL"`
- DL/I call codes: `GU`, `GHU`, `GN`, `GHN`, `ISRT`, `REPL`, `DLET`
- `DBSTAT`, `TPSTAT` status fields
- `CBL LIST,MAP,XREF,FLAG(I)` without CICS option

### DB2 Programs
Look for:
- `CBL SQL` directive
- `EXEC SQL` statements
- `INCLUDE SQLCA`
- `SQLCODE` variable

### PL/I IMS
- `*PROCESS SYSTEM(IMS);` first line
- `DCL PLITDLI ENTRY EXTERNAL;`

### PL/I Batch with DB2
- `EXEC SQL INCLUDE SQLCA;` early in procedure
- `EXEC SQL DECLARE ... CURSOR FOR` 

### HLASM PSB
- `PCB    TYPE=DB,` macro
- `PSBGEN` macro
- `SENSEG` macro

### HLASM DBD
- `DBD   NAME=` macro
- `SEGM  NAME=` macro
- `FIELD NAME=` macro
- `DBDGEN` / `FINISH` / `END`

---

## Code Era Detection

### Enterprise COBOL (this project's primary era)
- `END-IF`, `END-EVALUATE`, `END-EXEC`, `END-PERFORM` scope terminators
- `FUNCTION` intrinsic functions (`FUNCTION MOD`, `FUNCTION CURRENT-DATE`)
- `INVOKE` for object calls (IBTRAN only)
- `POINTER` data type
- `COMP-5` binary integer

### COBOL-85 markers (legacy, not for new code)
- `PERFORM ... THRU ...` (still present in IMS programs — acceptable)
- `GO TO` within sections for flow control (present in INQCUST — acceptable in existing code)

---

## Common COBOL Idioms in This Codebase

### Retry Loop Pattern
```cobol
MOVE 'N' TO EXIT-xxx-READ.
PERFORM READ-xxx-yyy
  UNTIL EXIT-xxx-READ = 'Y'.
```

Used for DB2 SELECTs where the first attempt may require a second try (e.g., random customer generation).

### Date/Time Stamp Pattern
```cobol
EXEC CICS ASKTIME
     ABSTIME(WS-U-TIME)
END-EXEC.

EXEC CICS FORMATTIME
     ABSTIME(WS-U-TIME)
     DDMMYYYY(WS-ORIG-DATE)
     TIME(PROC-TRAN-TIME OF PROCTRAN-AREA)
     DATESEP
END-EXEC.
```

### REDEFINES for Date Decomposition
```cobol
01 WS-ORIG-DATE                 PIC X(10).
01 WS-ORIG-DATE-GRP REDEFINES WS-ORIG-DATE.
   03 WS-ORIG-DATE-DD           PIC 99.
   03 FILLER                    PIC X.
   03 WS-ORIG-DATE-MM           PIC 99.
   03 FILLER                    PIC X.
   03 WS-ORIG-DATE-YYYY         PIC 9999.
```

### Named Counter Service (NCS) Pattern
```cobol
01 NCS-CUST-NO-STUFF.
   03 NCS-CUST-NO-NAME.
      05 NCS-CUST-NO-ACT-NAME    PIC X(9)  VALUE 'BANKZCUST'.
      05 NCS-CUST-NO-TEST-SORT   PIC X(6)  VALUE '      '.
      05 NCS-CUST-NO-FILL        PIC XX    VALUE '  '.
   03 NCS-CUST-NO-INC            PIC 9(16) COMP VALUE 0.
   03 NCS-CUST-NO-VALUE          PIC 9(16) COMP VALUE 0.
   03 NCS-CUST-NO-RESP           PIC XX    VALUE '00'.
```

### Asynchronous CICS Child Transaction Pattern
Uses `EXEC CICS RUN TRANSID(WS-RUN-TRANSID) CHANNEL(WS-CHANNEL-NAME)` to spawn credit agency checks (CRDTAGY1–5).

### Abend Population Pattern
```cobol
INITIALIZE ABNDINFO-REC
MOVE SQLCODE TO ABND-SQLCODE
EXEC CICS ASSIGN APPLID(ABND-APPLID) END-EXEC
MOVE EIBTASKN   TO ABND-TASKNO-KEY
MOVE EIBTRNID   TO ABND-TRANID
PERFORM POPULATE-TIME-DATE
MOVE WS-ORIG-DATE TO ABND-DATE
STRING ...time fields... INTO ABND-TIME END-STRING
MOVE WS-U-TIME   TO ABND-UTIME-KEY
MOVE '<code>'    TO ABND-CODE
EXEC CICS ASSIGN PROGRAM(ABND-PROGRAM) END-EXEC
STRING '<description>' DELIMITED BY SIZE,
       ...diagnostic fields...
       INTO ABND-FREEFORM END-STRING
EXEC CICS LINK PROGRAM(WS-ABEND-PGM)
     COMMAREA(ABNDINFO-REC)
     LENGTH(LENGTH OF ABNDINFO-REC)
END-EXEC
```

### `D` Debug Directive Lines
Lines beginning with `D` in column 7 (COBOL debug lines) are compiled only when `DEBUGGING MODE` is active. They appear in several programs for diagnostic DISPLAYs. These should be left in place; they do not execute in production.

---

## PL/I Idioms

### `ON ENDFILE` for File Handling (batch programs)
```pli
ON ENDFILE(DATECARD)
  BEGIN;
    PUT SKIP LIST('DATECARD NOT FOUND - USING DEFAULT');
    ...default logic...
    GO TO END_PROC;
  END;
OPEN FILE(DATECARD);
READ FILE(DATECARD) INTO(INPUT_VAR);
CLOSE FILE(DATECARD);
```

### Procedure Internal Declaration Convention
```pli
PROC_NAME: PROCEDURE;
  DCL LOCAL_VAR CHAR(10);
  ...logic...
  RETURN;
END PROC_NAME;
```

---

## HLASM Idioms

### Line Continuation
Place `C` in column 72 (not a space, not `X`) to continue a macro parameter onto the next line. Continuation line starts at column 16.

### PSB PROCOPT Values
- `AP` — All, Position (read and update with position held)
- `A` — All (no position)
- `OP` — Insert only with position

### DBD Access Method
- `(HDAM,OSAM)` — Hash Direct Access, standard for this application
- `RMNAME=(DFSHDC40,5,10)` — IBM standard randomising module

---

## ZCodeScan Rules in Effect

Key rules from `zcodescan/zcodescan-rules.yaml` that affect this codebase:

| Rule | Severity | Impact |
|------|----------|--------|
| `SqlAvoidSelectStarRule` | HIGH | Never SELECT * |
| `CicsNoHandleRule` | MEDIUM | No HANDLE CONDITION |
| `OccursDependingOnRule` | HIGH | Be careful with ODO tables |
| `UnprotectedAuthCredentialRule` | HIGH | No hardcoded passwords |
| `CheckSqlcodeAfterExecSqlRule` | HIGH | Always check SQLCODE |
| `DebugFeaturesInProdRule` | HIGH | No debug in production |
| `InlinePerformLineLimitRule` | MEDIUM | Max 30 lines per inline PERFORM |
| `ProcedureRule` | MEDIUM | Max 100 lines per paragraph |
| `NestedIfLimitRule` | MEDIUM | Max 6 levels of nesting |
| `RequireEndClauseRule` | MEDIUM | IF/EVALUATE/READ/CALL must have END-xxx |
| `ImplicitDeclarationRule` (PL/I) | HIGH | No implicit declarations |
| `GoToRule` (PL/I) | HIGH | Avoid GO TO in PL/I |
