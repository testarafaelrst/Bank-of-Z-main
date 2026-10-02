# Discovered Patterns — Bank of Z Coding Standards

**Analysis date:** 2025-07  
**Files analyzed:** 18  
**Source directory:** `src/base/`

## File Inventory

| File | Type | Subsystem | Era |
|------|------|-----------|-----|
| `src/base/cics/cobol/CRECUST.cbl` | COBOL | CICS+DB2 | Enterprise |
| `src/base/cics/cobol/INQCUST.cbl` | COBOL | CICS+DB2 | Enterprise |
| `src/base/cics/cobol/UPDCUST.cbl` | COBOL | CICS+DB2 | Enterprise |
| `src/base/cics/cobol/XFRFUN.cbl` | COBOL | CICS+DB2 | Enterprise |
| `src/base/cics/cobol/DBCRFUN.cbl` | COBOL | CICS+DB2 | Enterprise |
| `src/base/cics/cobol/ABNDPROC.cbl` | COBOL | CICS | Enterprise |
| `src/base/cics/cobol/BNK1CRA.cbl` | COBOL | CICS (BMS) | Enterprise |
| `src/base/ims/cobol/IBLOGIN1.cbl` | COBOL | IMS DL/I | Enterprise |
| `src/base/ims/cobol/IBGCUDAT.cbl` | COBOL | IMS DL/I | Enterprise |
| `src/base/ims/cobol/IBACSUM.cbl` | COBOL | IMS DL/I | Enterprise |
| `src/base/ims/cobol/IBTRAN.cbl` | COBOL | IMS+Java | Enterprise (special) |
| `src/base/ims/pli/IBLOGIN.pli` | PL/I | IMS DL/I | Modern |
| `src/base/batch/pli/BNKSTMT.pli` | PL/I | Batch+DB2 | Modern |
| `src/base/ims/PSB/IB.asm` | HLASM | IMS PSB | — |
| `src/base/ims/DBD/CUSTOMER.asm` | HLASM | IMS DBD | — |
| `src/base/cics/copy/CUSTOMER.cpy` | Copybook | CICS | — |
| `src/base/cics/copy/ACCOUNT.cpy` | Copybook | CICS | — |
| `src/base/cics/copy/PROCTRAN.cpy` | Copybook | CICS | — |
| `src/base/cics/copy/INQCUSTZ.cpy` | Copybook | CICS | — |

---

## Pattern Analysis — COBOL CICS

### Compiler Directives

| Pattern | Files | Confidence |
|---------|-------|-----------|
| `CBL CICS('SP,EDF')` present | 10/10 | 100% ✅ |
| `CBL SQL` when SQL used | 8/8 | 100% ✅ |
| `PROCESS CICS,NODYNAM,NSYMBOL(NATIONAL),TRUNC(STD)` | 5/10 | 50% ⚠️ **resolved: MUST use both lines** |
| `CBL CICS('SP,EDF,DLI')` when DLI used | 1/1 | 100% ✅ |

### Program Header

| Pattern | Files | Confidence |
|---------|-------|-----------|
| Copyright block `* Copyright IBM Corp.` | 10/10 | 100% ✅ |
| Program description paragraph | 10/10 | 100% ✅ |
| `SOURCE-COMPUTER. IBM-370.` | 10/10 | 100% ✅ |
| `AUTHOR. Jon Collett.` present | 10/10 | 100% ✅ (resolved: include with developer name) |
| Debugging MODE commented out | 10/10 | 100% ✅ |

### Variable Prefixes

| Prefix | Usage | Confidence |
|--------|-------|-----------|
| `WS-` | Working-storage general vars | 100% ✅ |
| `HV-` | DB2 host variable fields | 100% ✅ |
| `HOST-<TABLE>-ROW` | 01-level DB2 host var container | 100% ✅ |
| `NCS-` | Named Counter Service | 100% ✅ |
| `ABND-` | Abend info (ABNDINFO copybook) | 100% ✅ |

### PROCEDURE DIVISION

| Pattern | Files | Confidence |
|---------|-------|-----------|
| `PREMIERE SECTION.` + `P010.` entry | 10/10 | 100% ✅ |
| `GET-ME-OUT-OF-HERE` terminal section | 9/10 | 90% ✅ |
| `<PREFIX>999. EXIT.` end of section | 14/16 | 88% ✅ |
| `<3-letter><3-digit>` paragraph names | 14/16 | 88% ✅ |
| Sections called via PERFORM (no fall-through) | 10/10 | 100% ✅ |

### CICS Error Handling

| Pattern | Files | Confidence |
|---------|-------|-----------|
| `RESP`/`RESP2` on every EXEC CICS | 10/10 | 100% ✅ |
| Never `HANDLE CONDITION` | 10/10 | 100% ✅ |
| `DFHRESP(NORMAL)` comparison | 10/10 | 100% ✅ |
| `WS-ABEND-PGM VALUE 'ABNDPROC'` declared | 9/10 | 90% ✅ |
| `ABNDINFO-REC` declared in WS | 9/10 | 90% ✅ |

### DB2 SQL

| Pattern | Files | Confidence |
|---------|-------|-----------|
| Never SELECT * | 8/8 | 100% ✅ |
| Three-case SQLCODE check | 8/8 | 100% ✅ |
| `SQLCODE-DISPLAY PIC S9(8) DISPLAY SIGN LEADING SEPARATE` | 8/8 | 100% ✅ |
| Comment above each INCLUDE | 8/8 | 100% ✅ |
| SQLCA included last | 8/8 | 100% ✅ |

---

## Pattern Analysis — COBOL IMS

| Pattern | Files | Confidence |
|---------|-------|-----------|
| `CBL LIST,MAP,XREF,FLAG(I)` | 4/4 | 100% ✅ |
| No ENVIRONMENT DIVISION | 4/4 | 100% ✅ |
| No AUTHOR | 4/4 | 100% ✅ (resolved: IMS programs keep this — copyright only) |
| Copyright after PROGRAM-ID | 4/4 | 100% ✅ |
| DL/I call codes as 77 PIC X(04) | 4/4 | 100% ✅ |
| `BAD-STATUS` 01-level | 4/4 | 100% ✅ |
| `ENTRY "DLITCBL"` for batch IMS | 4/4 | 100% ✅ |
| Segment name: `<NAME>-SEG` | resolved | — ✅ |
| SSA name: `<NAME>-SSA<n>` | 4/4 | 100% ✅ |
| LL/ZZ fields in I/O areas | 4/4 | 100% ✅ |

---

## Pattern Analysis — PL/I IMS

| Pattern | Files | Confidence |
|---------|-------|-----------|
| `*PROCESS SYSTEM(IMS);` first line | 1/1 | 100% ✅ |
| Procedure comment `/*---*/` style | 1/1 | 100% ✅ |
| `DCL name CHAR(n) INIT(...)` for constants | 1/1 | 100% ✅ |
| ALL_CAPS_UNDERSCORES for DCL names | 1/1 | 100% ✅ |
| `RETURN;` before `END procname;` | 1/1 | 100% ✅ |

---

## Pattern Analysis — PL/I Batch

| Pattern | Files | Confidence |
|---------|-------|-----------|
| `EXEC SQL INCLUDE SQLCA;` first | 1/1 | 100% ✅ |
| `HV_TABLE_FIELD` naming (underscores) | 1/1 | 100% ✅ |
| Never SELECT * | 1/1 | 100% ✅ |
| Named cursors DECLARE near top | 1/1 | 100% ✅ |
| `ON ENDFILE` for file handling | 1/1 | 100% ✅ |
| DB2 connection via JCL DSN RUN (no CONNECT) | 1/1 | 100% ✅ |

---

## Pattern Analysis — HLASM PSB/DBD

| Pattern | Files | Confidence |
|---------|-------|-----------|
| `PROCOPT=AP` for all PCBs | 1/1 | 100% ✅ |
| `PSBGEN PSBNAME=...,LANG=COBOL` | 1/1 | 100% ✅ |
| Line continuation `C` in col 72 | 2/2 | 100% ✅ |
| `ENCODING=Cp1047` in DBDs | 1/1 | 100% ✅ |
| `ACCESS=(HDAM,OSAM)` standard | 1/1 | 100% ✅ |
| Copyright at top | 2/2 | 100% ✅ |

---

## Pattern Analysis — Copybooks

| Pattern | Files | Confidence |
|---------|-------|-----------|
| Start at level 03 (no 01) | 4/4 | 100% ✅ |
| Eye-catcher field first | 3/4 | 75% SHOULD |
| 88-level for eye-catcher value | 3/4 | 75% SHOULD |
| Date subgroups DD/MM/YYYY DISPLAY | 4/4 | 100% ✅ |
| Copyright block at top | 4/4 | 100% ✅ |

---

## Conflicts Resolved

| Conflict | Resolution |
|----------|-----------|
| `PROCESS` + `CBL` vs `CBL` only | MUST use both lines: `PROCESS CICS,...` then `CBL CICS(...)` |
| Segment naming: `X-SEG` vs `X-AB` | MUST use `<SEGNAME>-SEG` (full name + `-SEG`) |
| `AUTHOR` present/absent | Include `AUTHOR` with developer name |
