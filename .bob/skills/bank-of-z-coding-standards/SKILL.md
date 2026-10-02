---
name: bank-of-z-coding-standards
description: >
  Enforces Bank of Z coding standards for COBOL (CICS, IMS), PL/I (IMS, batch), and HLASM (PSB/DBD).
  Discovered from codebase analysis of src/base/. Use when "review code", "check standards",
  "generate code", "write a new program", "refactor code", or "does this follow our conventions".
metadata:
  author: Discovered by Bob — Coding Standards Builder
  version: 1.0.0
  enforcement-level: moderate
  target-languages: COBOL, PL/I, HLASM
  discovery-date: 2025-07
  files-analyzed: 18
  confidence-threshold: 80%
---

# Bank of Z Coding Standards

Enforces coding conventions discovered from `src/base/` analysis.
Apply these standards when generating new programs, reviewing existing ones, or refactoring code.

## Confidence Levels

- **MUST** — High confidence (≥80%), non-negotiable
- **SHOULD** — Medium confidence (60–79%), follow unless there is explicit reason not to
- **MAY** — Advisory only

---

## COBOL — CICS Programs (`src/base/cics/cobol/`)

### Compiler Directives (MUST)

Every CICS COBOL program MUST begin with exactly these two lines:

```cobol
       PROCESS CICS,NODYNAM,NSYMBOL(NATIONAL),TRUNC(STD)
       CBL CICS('SP,EDF')
```

If the program also uses embedded SQL, add a third line:

```cobol
       CBL SQL
```

If the program uses DLI (rare in CICS), use `CBL CICS('SP,EDF,DLI')`.

### Program Header (MUST)

After the compiler directives, every program MUST have this copyright block followed by a description block:

```cobol
      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      ******************************************************************
      ******************************************************************
      * <One-paragraph description of what the program does>
      ******************************************************************

       IDENTIFICATION DIVISION.
       PROGRAM-ID. <PROGNAME>.
       AUTHOR. <Developer Name>.
```

- `PROGRAM-ID` value MUST match the filename (uppercase, ≤8 chars)
- `AUTHOR` MUST be included with the developer's name

### ENVIRONMENT DIVISION (MUST)

```cobol
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *SOURCE-COMPUTER.   IBM-370 WITH DEBUGGING MODE.
       SOURCE-COMPUTER.  IBM-370.
       OBJECT-COMPUTER.  IBM-370.

       INPUT-OUTPUT SECTION.
```

The `WITH DEBUGGING MODE` line MUST remain commented out in production. The `D` debug directive can be used inline on individual lines during development.

### DATA DIVISION Structure (MUST)

Order within DATA DIVISION:

1. `FILE SECTION.` (even if empty)
2. `WORKING-STORAGE SECTION.`
   - `COPY SORTCODE.` first if needed
   - `EXEC SQL INCLUDE <TABLE>DB2 END-EXEC.` with comment `* <TABLE> DB2 copybook` above each include
   - `HOST-<TABLE>-ROW` 01-level with `HV-<TABLE>-<FIELD>` fields for each DB2 table used
   - `EXEC SQL INCLUDE SQLCA END-EXEC.` (last SQL include)
   - `SQLCODE-DISPLAY PIC S9(8) DISPLAY SIGN LEADING SEPARATE.`
   - `WS-CICS-WORK-AREA` with `WS-CICS-RESP` and `WS-CICS-RESP2`
   - Application working variables
   - `WS-ABEND-PGM PIC X(8) VALUE 'ABNDPROC'.`
   - `ABNDINFO-REC.` with `COPY ABNDINFO.`
3. `LOCAL-STORAGE SECTION.` (SHOULD use for transaction-scoped data)
4. `LINKAGE SECTION.`
   - `01 DFHCOMMAREA.` with `COPY <PROGNAME>.`

### Variable Naming (MUST)

| Prefix | Purpose |
|--------|---------|
| `WS-` | All WORKING-STORAGE variables |
| `HV-` | DB2 host variables within `HOST-<TABLE>-ROW` |
| `HOST-<TABLE>-ROW` | 01-level container for DB2 host variables |
| `NCS-` | Named Counter Service variables |
| `ABND-` | Abend information fields (from `ABNDINFO` copybook) |

Constants: ALL-CAPS-WITH-HYPHENS, declared as `77` or `01` levels with `VALUE` literal.

### PROCEDURE DIVISION Structure (MUST)

```cobol
       PROCEDURE DIVISION USING DFHCOMMAREA.
       PREMIERE SECTION.
       P010.
           ...main logic (PERFORM calls to sections)...
           PERFORM GET-ME-OUT-OF-HERE.

       P999.
           EXIT.
```

- Entry point section is always `PREMIERE SECTION.` / `P010.`
- Every section ends with `<PREFIX>999. EXIT.` (e.g., `RCD999. EXIT.`)
- Paragraphs within sections use `<3-letter prefix><3-digit number>` (e.g., `P010`, `ENC010`)
- Use `PERFORM <SECTION-NAME>` to call sections; never fall through

### CICS Error Handling (MUST)

```cobol
           EXEC CICS <COMMAND>
                <PARAMETERS>
                RESP(WS-CICS-RESP)
                RESP2(WS-CICS-RESP2)
           END-EXEC.

           IF WS-CICS-RESP NOT = DFHRESP(NORMAL)
              MOVE 'N' TO COMM-SUCCESS
              MOVE '<code>' TO COMM-FAIL-CODE
              PERFORM GET-ME-OUT-OF-HERE
           END-IF.
```

- **NEVER use `EXEC CICS HANDLE CONDITION`** — always use `RESP`/`RESP2` (ZCodeScan `CicsNoHandleRule`)
- Always supply `RESP(WS-CICS-RESP) RESP2(WS-CICS-RESP2)` on every `EXEC CICS` command
- For critical failures, populate `ABNDINFO-REC` fields and `EXEC CICS LINK PROGRAM(WS-ABEND-PGM)`

### DB2 SQL (MUST)

- **NEVER use `SELECT *`** — always enumerate columns explicitly
- Always check SQLCODE in three cases: `= 0` (success), `= 100` (not found), `NOT = 0 AND NOT = 100` (error)
- Error case MUST populate `ABNDINFO-REC`, `ABND-SQLCODE`, and link to `ABNDPROC`
- Host variable references in SQL: prefix with `:` (e.g., `:HV-CUSTOMER-SORTCODE`)
- Comment above each `EXEC SQL INCLUDE`: `* <TABLE> DB2 copybook`

### `GET-ME-OUT-OF-HERE` Pattern (MUST)

Every CICS program MUST have a terminal section that performs `GOBACK` (or `EXEC CICS RETURN`). The standard name is `GET-ME-OUT-OF-HERE`. Any abnormal exit routes through this section, not directly to GOBACK.

---

## COBOL — IMS Programs (`src/base/ims/cobol/`)

### Compiler Directives (MUST)

```cobol
       CBL LIST,MAP,XREF,FLAG(I)
```

No `CICS` or `SQL` options. `IBTRAN.cbl` is the sole exception (special bridge parms — do not modify).

### Program Header (MUST)

```cobol
       IDENTIFICATION DIVISION.
       PROGRAM-ID. <PROGNAME>

      ******************************************************************
      * Licensed Materials - Property of IBM
      *
      * (c) Copyright IBM Corp. 2026.
      *
      * US Government Users Restricted Rights - Use, duplication or
      * disclosure restricted by GSA ADP Schedule Contract
      * with IBM Corp.
      ******************************************************************
```

- IMS programs omit `AUTHOR` and `ENVIRONMENT DIVISION` entirely
- The copyright block comes **after** `PROGRAM-ID`, not before

### Constants Block (MUST)

Declare all constants as `77` levels grouped under a titled comment block:

```cobol
      ******************************************************************
      *CONSTANTS
      ******************************************************************
      * ERROR MESSAGES
       77  NOCUSTOMER        PIC  X(23) VALUE "CUSTOMER DOES NOT EXIST".
       77  NOACCOUNT         PIC  X(22) VALUE "ACCOUNT DOES NOT EXIST".

      * MESSAGE PROCESSING
       77  TERM-IO             PIC 9 VALUE 0.
       77  MESSAGE-EXIST       PIC X(2) VALUE 'CF'.
       77  NO-MORE-MESSAGE     PIC X(2) VALUE 'QC'.

      ******************************************************************
      *DATABASE CALL CODES
      ******************************************************************
       77  GU                  PIC  X(04)        VALUE "GU  ".
       77  GHU                 PIC  X(04)        VALUE "GHU ".
       77  GN                  PIC  X(04)        VALUE "GN  ".
       77  GHN                 PIC  X(04)        VALUE "GHN ".
       77  ISRT                PIC  X(04)        VALUE "ISRT".
       77  REPL                PIC  X(04)        VALUE "REPL".

      ******************************************************************
      *IMS STATUS CODES
      ******************************************************************
       77  GE                  PIC  X(02)        VALUE "GE".
       77  GB                  PIC  X(02)        VALUE "GB".
```

The DL/I call codes (`GU`, `GHU`, `GN`, `GHN`, `ISRT`, `REPL`) MUST be declared with their 4-character padded values including trailing spaces.

### Segment and SSA Naming (MUST)

- Segment areas: `<SEGNAME>-SEG` (e.g., `CUSTOMER-SEG`, `ACCOUNT-SEG`) — full name + `-SEG`
- Segment Search Arguments: `<SEGNAME>-SSA<n>` (e.g., `CUSTOMER-SSA1`)
- PCB pointers in LINKAGE: `<NAME>PCB_PTR POINTER` and `<NAME>PCB` structure

### I/O Message Area (MUST)

```cobol
       01  INPUT-AREA.
           05  LL-IN           PIC  9(04) COMP.
           05  ZZ-IN           PIC  9(04) COMP.
           05  TRAN-CODE       PIC  X(08).
           05  ...application fields...

       01  OUTPUT-AREA.
           05  LL-OUT          PIC  9(04) COMP VALUE <output-len>.
           05  ZZ-OUT          PIC  9(04) COMP.
           05  MSG-OUT         PIC  X(<n>).
```

### IMS Error Handling (MUST)

Check `DBSTAT` after every DL/I call:

```cobol
           CALL "CBLTDLI" USING GHU, DBPCB, CUST-SEG, CUSTOMER-SSA1.

           IF DBSTAT NOT = SPACES
              IF DBSTAT = GB OR DBSTAT = GE
                 MOVE NOCUSTOMER TO MSG-OUT
              ELSE
                 MOVE DBSTAT TO SC
                 MOVE BAD-STATUS TO MSG-OUT
              END-IF
           END-IF.
```

`BAD-STATUS` structure MUST be declared:

```cobol
       01  BAD-STATUS.
           05  SC-MSG  PIC X(30) VALUE "BAD STATUS CODE WAS RECEIVED: ".
           05  SC             PIC X(2).
```

### PROCEDURE DIVISION Entry (MUST)

IMS DL/I batch programs MUST use:

```cobol
       PROCEDURE DIVISION.
             ENTRY "DLITCBL"
             USING  IOPCBA, DBPCB1.
```

The main loop uses `PERFORM WITH TEST BEFORE UNTIL TERM-IO = 1`.

---

## PL/I — IMS Programs (`src/base/ims/pli/`)

### Process Directive (MUST)

```pli
*PROCESS SYSTEM(IMS);
```

First line, before all comments.

### Program Header (MUST)

```pli
  /*------------------------------------------------------------*
   * Licensed Materials - Property of IBM
   * (c) Copyright IBM Corp. 2026.
   * US Government Users Restricted Rights...
  *------------------------------------------------------------*/

  /*------------------------------------------------------------*
  * Procedure: <PROGNAME>
  * Description: <Description>
  *------------------------------------------------------------*/
  <PROGNAME>: PROCEDURE(<PCB_PTR_PARAMS>) OPTIONS(MAIN);
```

### Variable Declarations (MUST)

- Constants: `DCL <NAME> CHAR(<n>) INIT('<value>');` — ALL_CAPS_WITH_UNDERSCORES for names
- DL/I call codes: same 4-char padded values as COBOL
- Procedure declarations: `<PROC_NAME>: PROCEDURE;` with `RETURN;` before `END <PROC_NAME>;`
- All procedures end with `  RETURN;` then `  END <PROCNAME>;`
- Section comment headers: `/*---...---*/` style with `* PROCEDURE:` title

### Error Handling (MUST)

Use `ON ENDFILE(<file>)` for end-of-file; `ON ERROR` for other conditions.

---

## PL/I — Batch Programs (`src/base/batch/pli/`)

### Header (MUST)

No `*PROCESS` directive. Start with copyright block then `<PROGNAME>: PROCEDURE OPTIONS(MAIN);`.

### DB2 in Batch (MUST)

```pli
  EXEC SQL INCLUDE SQLCA;
```

First statement of the program. No explicit `CONNECT` — DB2 connection is established by DSN RUN in JCL.

### Host Variable Naming (MUST)

`HV_<TABLE>_<FIELD>` with underscores (not hyphens — PL/I convention).
Null indicators: `HV_<TABLE>_NULL_IND` structure.

### Cursor Pattern (MUST)

Declare cursors near the top of the procedure:

```pli
  EXEC SQL DECLARE <NAME>_CURSOR CURSOR FOR
    SELECT <columns>
    FROM <table>
    WHERE <conditions>
    ORDER BY <key>;
```

Never use `SELECT *` (same rule as COBOL).

---

## HLASM — PSBs (`src/base/ims/PSB/`)

```hlasm
         PCB    TYPE=DB,DBDNAME=<name>,PROCOPT=AP,KEYLEN=<n>,            C
                PCBNAME=<name>
         SENSEG NAME=<name>,PARENT=0
         ...repeat for each database...
         PSBGEN PSBNAME=<psb-name>,LANG=COBOL
         END
```

- `PROCOPT=AP` is the standard option (All, Position)
- Line continuation: uppercase `C` in column 72
- `LANG=COBOL` unless program is PL/I

## HLASM — DBDs (`src/base/ims/DBD/`)

```hlasm
      DBD   NAME=<NAME>,                                             C
               ENCODING=Cp1047,                                      C
               ACCESS=(HDAM,OSAM),                                   C
               RMNAME=(DFSHDC40,5,10),                               C
               PASSWD=NO

      DATASET  DD1=<NAME>,                                           C
               DEVICE=3390, SIZE=(2048), SCAN=0

      SEGM  NAME=<NAME>, PARENT=0, BYTES=(<n>), RULES=(LLL,HERE)

      FIELD NAME=(<fieldname>,SEQ,U), BYTES=<n>, START=<n>, TYPE=C, ...

      DBDGEN
      FINISH
      END
```

- `ENCODING=Cp1047` MUST be specified (EBCDIC codepage)
- Sequence field declares `SEQ,U` in the `NAME=()` triple

---

## Copybooks (`src/base/cics/copy/`, `src/base/ims/copy/`)

- Copybooks start at level **03** (never 01) — they are embedded within caller's 01 structure
- Every entity copybook MUST begin with an eye-catcher field:
  `05 <TABLE>-EYECATCHER PIC X(4).` with `88 <TABLE>-EYECATCHER-VALUE VALUE '<4CHAR>'.`
- Dates: separate subgroups `DD`, `MM`, `YYYY` (all `DISPLAY`)
- Monetary amounts: `S9(10)V99` (no COMP — display format for portability)
- Copyright block at top (asterisk comment, 68 chars wide) — **mandatory**

---

## Enforcement Level Summary

| Category | Level |
|----------|-------|
| Compiler directives (PROCESS + CBL) | MUST |
| Copyright header | MUST |
| `WS-` prefix for working-storage | MUST |
| `HV-` prefix for DB2 host variables | MUST |
| RESP/RESP2 on all EXEC CICS | MUST |
| Never SELECT * | MUST |
| SQLCODE three-case check | MUST |
| ABNDPROC for critical failures | MUST |
| `GET-ME-OUT-OF-HERE` pattern | MUST |
| PREMIERE SECTION / P010 entry | MUST |
| `<SIG>999. EXIT.` section end | MUST |
| `CBL LIST,MAP,XREF,FLAG(I)` for IMS | MUST |
| DL/I call code declarations | MUST |
| `ENTRY "DLITCBL"` for IMS batch | MUST |
| Eye-catcher in copybooks | MUST |
| LOCAL-STORAGE for transaction scope | SHOULD |
| Retry loops with EXIT flag | SHOULD |
| Procedure comments above sections | SHOULD |

---

## ZCodeScan Validation

**MANDATORY**: After generating or modifying any COBOL or PL/I file, always instruct the user to validate with ZCodeScan.

Before running ZCodeScan, note there is a rules file at `zcodescan/zcodescan-rules.yaml` in this project.
The schema for rules files is at: https://github.com/IBM/zopeneditor-about/blob/main/zcodescan/zcodescan-rules-1.4.0.json

Add this to every code generation response:

---

**IMPORTANT: Validate the generated code with ZCodeScan**

For the current file open in the editor:

```xml
<use_mcp_tool>
<server_name>zopeneditor-sample</server_name>
<tool_name>zcodescan-check-current-program</tool_name>
<arguments>{}</arguments>
</use_mcp_tool>
```

For all COBOL/PL/I files in the workspace:

```xml
<use_mcp_tool>
<server_name>zopeneditor-sample</server_name>
<tool_name>zcodescan-check-list-of-local-programs</tool_name>
<arguments>{"searchPatterns": "**/*.cbl **/*.cob **/*.pli"}</arguments>
</use_mcp_tool>
```

Review the scan results and address any issues before finalising the code.

---

## References

See the `references/` directory alongside this skill for:
- `discovered-patterns.md` — Full pattern analysis with confidence scores
- `code-samples.md` — Actual code examples from the codebase
- `z-language-patterns.md` — Z language pattern detection guide
