# Code Samples — Bank of Z Coding Standards

Real examples extracted from the codebase. Use these as canonical references.

---

## COBOL CICS — Complete Program Header

**Source:** `src/base/cics/cobol/XFRFUN.cbl` (lines 1–50)

```cobol
       PROCESS CICS,NODYNAM,NSYMBOL(NATIONAL),TRUNC(STD)
       CBL CICS('SP,EDF')
       CBL SQL
      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      ******************************************************************

      ******************************************************************
      * This program gets called when someone initiates a transfer
      * of funds...
      *
      ******************************************************************

       IDENTIFICATION DIVISION.
       PROGRAM-ID. XFRFUN.
       AUTHOR. Jon Collett.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *SOURCE-COMPUTER.   IBM-370 WITH DEBUGGING MODE.
       SOURCE-COMPUTER.  IBM-370.
       OBJECT-COMPUTER.  IBM-370.

       INPUT-OUTPUT SECTION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       COPY SORTCODE.

      * Get the ACCOUNT DB2 copybook
            EXEC SQL
              INCLUDE ACCDB2
            END-EXEC.
      * ACCOUNT Host variables for DB2
       01 HOST-ACCOUNT-ROW.
          03 HV-ACCOUNT-EYECATCHER      PIC X(4).
          03 HV-ACCOUNT-CUST-NO         PIC X(10).
          03 HV-ACCOUNT-KEY.
             05 HV-ACCOUNT-SORTCODE     PIC X(6).
             05 HV-ACCOUNT-ACC-NO       PIC X(8).
          03 HV-ACCOUNT-ACC-TYPE        PIC X(8).
          03 HV-ACCOUNT-INT-RATE        PIC S9(4)V99 COMP-3.
          ...

      * Pull in the SQL COMMAREA
        EXEC SQL
          INCLUDE SQLCA
        END-EXEC.

       01 SQLCODE-DISPLAY               PIC S9(8) DISPLAY
             SIGN LEADING SEPARATE.

       01 WS-CICS-WORK-AREA.
          05 WS-CICS-RESP               PIC S9(8) COMP.
          05 WS-CICS-RESP2              PIC S9(8) COMP.
```

---

## COBOL CICS — Abend Info Declaration

**Source:** `src/base/cics/cobol/INQCUST.cbl` (lines 185–188)

```cobol
       01 WS-ABEND-PGM                 PIC X(8) VALUE 'ABNDPROC'.

       01 ABNDINFO-REC.
           COPY ABNDINFO.
```

---

## COBOL CICS — LINKAGE SECTION

**Source:** `src/base/cics/cobol/INQCUST.cbl` (lines 191–196)

```cobol
       LINKAGE SECTION.
       01 DFHCOMMAREA.
           COPY INQCUSTZ.


       PROCEDURE DIVISION USING DFHCOMMAREA.
       PREMIERE SECTION.
       P010.
```

---

## COBOL CICS — CICS RESP Pattern

**Source:** `src/base/cics/cobol/CRECUST.cbl` (lines 544–556)

```cobol
           EXEC CICS ENQ
                RESOURCE(NCS-CUST-NO-NAME)
                LENGTH(16)
                RESP(WS-CICS-RESP)
                RESP2(WS-CICS-RESP2)
           END-EXEC.

           IF WS-CICS-RESP NOT = DFHRESP(NORMAL)
              MOVE 'N' TO COMM-SUCCESS
              MOVE '3' TO COMM-FAIL-CODE
              PERFORM GET-ME-OUT-OF-HERE
           END-IF.
```

---

## COBOL CICS — DB2 SELECT with SQLCODE Check

**Source:** `src/base/cics/cobol/INQCUST.cbl` (lines 310–395)

```cobol
           EXEC SQL
              SELECT CUSTOMER_EYECATCHER,
                     CUSTOMER_SORTCODE,
                     CUSTOMER_NUMBER,
                     ...all columns listed explicitly...
                INTO :HV-CUSTOMER-EYECATCHER,
                     :HV-CUSTOMER-SORTCODE,
                     :HV-CUSTOMER-NUMBER,
                     ...
                FROM CUSTOMER
               WHERE CUSTOMER_SORTCODE = :HV-CUSTOMER-SORTCODE
                 AND CUSTOMER_NUMBER = :HV-CUSTOMER-NUMBER
           END-EXEC.

           IF SQLCODE = 0
              MOVE 'Y' TO EXIT-VSAM-READ
              MOVE 'Y' TO INQCUST-INQ-SUCCESS
              ...populate output...
              GO TO RCD999
           END-IF.

           IF SQLCODE = 100 AND INQCUST-CUSTNO = 9999999999 ...
              ...handle not-found case...
           END-IF.

           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
              INITIALIZE ABNDINFO-REC
              MOVE SQLCODE TO ABND-SQLCODE
              EXEC CICS ASSIGN APPLID(ABND-APPLID) END-EXEC
              MOVE EIBTASKN   TO ABND-TASKNO-KEY
              MOVE EIBTRNID   TO ABND-TRANID
              PERFORM POPULATE-TIME-DATE
              ...fill ABND fields...
              EXEC CICS LINK PROGRAM(WS-ABEND-PGM) ...
              END-EXEC
           END-IF.
```

---

## COBOL CICS — Section Structure

**Source:** `src/base/cics/cobol/CRECUST.cbl` (lines 540–599)

```cobol
       ENQ-NAMED-COUNTER SECTION.
       ENC010.
           MOVE SORTCODE TO NCS-CUST-NO-TEST-SORT.

           EXEC CICS ENQ
                ...
           END-EXEC.

           IF WS-CICS-RESP NOT = DFHRESP(NORMAL)
              ...
           END-IF.

       ENC999.
           EXIT.


       DEQ-NAMED-COUNTER SECTION.
       DNC010.
           ...

       DNC999.
           EXIT.
```

---

## COBOL IMS — Constants Block

**Source:** `src/base/ims/cobol/IBGCUDAT.cbl` (lines 20–57)

```cobol
      ******************************************************************
      *CONSTANTS
      ******************************************************************
      * RS.NEXT FAILED TO GET A ROW
       77  NOCUSTOMER        PIC  X(23) VALUE "CUSTOMER DOES NOT EXIST".

      * MESSAGE PROCESSING
       77  TERM-IO             PIC 9 VALUE 0.
       77  TERM-LOOP           PIC 9 VALUE 0.
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

      ******************************************************************
      *ERROR STATUS CODE AREA
      ******************************************************************

       01  BAD-STATUS.
           05  SC-MSG  PIC X(30) VALUE "BAD STATUS CODE WAS RECEIVED: ".
           05  SC             PIC X(2).
```

---

## COBOL IMS — Segment Definition (`-SEG` naming)

**Source:** `src/base/ims/cobol/IBGCUDAT.cbl` (lines 62–75)

```cobol
       01 CUSTOMER-SEG.
           05  CUSTID-CD       PIC  S9(9) COMP-5.
           05  LASTNAME-CD     PIC  X(50).
           05  FIRSTNAME-CD    PIC  X(50).
           05  ADDRESS-CD      PIC  X(80).
           05  CITY-CD         PIC  X(25).
           05  STATE-CD        PIC  X(2).
           05  ZIPCODE-CD      PIC  X(15).
           05  PHONE-CD        PIC  X(12).
           05  STATUS-CD       PIC  X(1).
           05  PASSWORD-CD     PIC  X(16).
           05  CUSTOMERTYPE-CD PIC  X(1).
           05  LASTLOGIN-CD    PIC  X(23).
```

---

## COBOL IMS — SSA Definition

**Source:** `src/base/ims/cobol/IBLOGIN1.cbl` (lines 105–112)

```cobol
       01  CUSTOMER-SSA1.
           05  FILLER          PIC  X(08)        VALUE "CUSTOMER".
           05  FILLER          PIC  X(01)        VALUE "(".
           05  FILLER          PIC  X(08)        VALUE "CUSTID  ".
           05  FILLER          PIC  X(02)        VALUE "EQ".
           05  CUSTID          PIC  S9(9) COMP-5 VALUE +0.
           05  FILLER          PIC  X(01)        VALUE ")".
           05  FILLER          PIC  X(01)        VALUE ' '.
```

---

## COBOL IMS — DL/I Call and Status Check

**Source:** `src/base/ims/cobol/IBLOGIN1.cbl` (lines 218–270)

```cobol
           CALL "CBLTDLI"
             USING GHU, DBPCB, CUST-SEG, CUSTOMER-SSA1.

           IF DBSTAT NOT = SPACES
             IF DBSTAT = GB OR DBSTAT = GE
               MOVE NOCUSTOMER TO MSG-OUT
               DISPLAY "NO CUSTOMER"
             ELSE
               MOVE DBSTAT TO SC
               MOVE BAD-STATUS TO MSG-OUT
               DISPLAY "Bad status code: " SC
             END-IF
           ELSE
             ...process successful retrieval...
           END-IF.
```

---

## COBOL IMS — PROCEDURE DIVISION Entry

**Source:** `src/base/ims/cobol/IBLOGIN1.cbl` (lines 182–208)

```cobol
       PROCEDURE DIVISION.
             ENTRY "DLITCBL"
             USING  IOPCBA, DBPCB1.

       BEGIN.
           MOVE 0 TO TERM-IO.
           SET ADDRESS OF LTERMPCB TO ADDRESS OF IOPCBA.
           PERFORM WITH TEST BEFORE UNTIL TERM-IO = 1
              CALL 'CBLTDLI' USING GU, LTERMPCB, INPUT-AREA
              IF TPSTAT  = '  ' OR TPSTAT = MESSAGE-EXIST
              THEN
                PERFORM LOGIN thru LOGIN-END
                PERFORM INSERT-IO THRU INSERT-IO-END
              ELSE
                IF TPSTAT = NO-MORE-MESSAGE
                THEN
                  MOVE 1 TO TERM-IO
                ELSE
                  DISPLAY 'GU FROM IOPCB FAILED WITH STATUS CODE: '
                    TPSTAT
                END-IF
              END-IF
           END-PERFORM.
           STOP RUN.
```

---

## Copybook — Eye-Catcher Pattern

**Source:** `src/base/cics/copy/CUSTOMER.cpy` (lines 7–12)

```cobol
           03 CUSTOMER-RECORD.
              05 CUSTOMER-EYECATCHER                 PIC X(4).
                 88 CUSTOMER-EYECATCHER-VALUE        VALUE 'CUST'.
              05 CUSTOMER-KEY.
                 07 CUSTOMER-SORTCODE                PIC 9(6) DISPLAY.
                 07 CUSTOMER-NUMBER                  PIC 9(10) DISPLAY.
```

---

## PL/I IMS — Program Structure

**Source:** `src/base/ims/pli/IBLOGIN.pli` (lines 1–60)

```pli
*PROCESS SYSTEM(IMS);

  /*------------------------------------------------------------*
   * Licensed Materials - Property of IBM
   * (c) Copyright IBM Corp. 2026.
  *------------------------------------------------------------*/

  /*------------------------------------------------------------*
  * Procedure: IBLOGIN
  * Description: PL/I pgm for IMS Bank App Demo
  *------------------------------------------------------------*/

  IBLOGIN: PROCEDURE(IOPCB_PTR, DBPCB_PTR) OPTIONS(MAIN);

  DCL PLITDLI ENTRY EXTERNAL;
  DCL IOPCB_PTR POINTER;
  DCL DBPCB_PTR POINTER;

  /*------------------------------------------------------------*
  * CONSTANTS
  *------------------------------------------------------------*/
  DCL  LOGINSUCCESSFUL  CHAR(16)   INIT('LOGIN SUCCESSFUL');
  DCL  NOCUSTOMER       CHAR(23)   INIT('CUSTOMER DOES NOT EXIST');

  /*---------------------------------------------------------*
  * DATABASE CALL CODES
  *----------------------------------------------------------*/
  DCL  GU     CHAR(4)    INIT('GU  ');
  DCL  GN     CHAR(4)    INIT('GN  ');
  DCL  GHU    CHAR(4)    INIT('GHU ');
  DCL  ISRT   CHAR(4)    INIT('ISRT');
  DCL  REPL   CHAR(4)    INIT('REPL');
```

---

## PL/I Batch — Cursor Declaration

**Source:** `src/base/batch/pli/BNKSTMT.pli` (lines 142–157)

```pli
  EXEC SQL DECLARE ACCT_CURSOR CURSOR FOR
    SELECT ACCOUNT_EYECATCHER,
           ACCOUNT_CUSTOMER_NUMBER,
           ACCOUNT_SORTCODE,
           ACCOUNT_NUMBER,
           ACCOUNT_TYPE,
           ACCOUNT_INTEREST_RATE,
           ACCOUNT_OPENED,
           ACCOUNT_OVERDRAFT_LIMIT,
           ACCOUNT_LAST_STATEMENT,
           ACCOUNT_NEXT_STATEMENT,
           ACCOUNT_AVAILABLE_BALANCE,
           ACCOUNT_ACTUAL_BALANCE
    FROM ACCOUNT
    WHERE ACCOUNT_SORTCODE = :HV_ACCT_SORTCODE
    ORDER BY ACCOUNT_NUMBER;
```

---

## HLASM PSB — Structure

**Source:** `src/base/ims/PSB/IB.asm`

```hlasm
         PCB    TYPE=DB,DBDNAME=ACCOUNT,PROCOPT=AP,KEYLEN=8,            C
                PCBNAME=ACCOUNT
         SENSEG NAME=ACCOUNT,PARENT=0
         ...
         PSBGEN PSBNAME=IB,LANG=COBOL
         END
```

## HLASM DBD — Structure

**Source:** `src/base/ims/DBD/CUSTOMER.asm`

```hlasm
      DBD   NAME=CUSTOMER,                                             C
               ENCODING=Cp1047,                                        C
               ACCESS=(HDAM,OSAM),                                     C
               RMNAME=(DFSHDC40,5,10),                                 C
               PASSWD=NO

      DATASET  DD1=CUSTOMER, DEVICE=3390, SIZE=(2048), SCAN=0

      SEGM  NAME=CUSTOMER, PARENT=0, BYTES=(279), RULES=(LLL,HERE)

      FIELD NAME=(CUSTID,SEQ,U), BYTES=4, START=1, TYPE=C, DATATYPE=INT
      FIELD NAME=LASTNAME,       BYTES=50, START=5, TYPE=C, DATATYPE=CHAR

      DBDGEN
      FINISH
      END
```
