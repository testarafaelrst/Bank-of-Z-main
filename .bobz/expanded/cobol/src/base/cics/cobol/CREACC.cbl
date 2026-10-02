       CBL CICS('SP,EDF')
       CBL SQL
      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      ******************************************************************
      ******************************************************************
      * This program takes account information from the BMS
      * application (cust no, name, address and DOB) and then enqueues
      * the Named Counter for ACCOUNT, increments the counter and takes
      * the new account number, & attempt to update the ACCOUNT
      * datastore on DB2. If that is successful, write a rec to
      * the PROCTRAN datastore. Then, if all of that works, DEQUEUE
      * the named counter and return the ACCOUNT number.
      * If for any reason the write to the ACCOUNT or PROCTRAN
      * datatsore is unsuccessful, then we need to decrement the Named
      * Counter (restoring it to the start position) and DEQUEUE the
      * Named Counter.
      *
      *
      ******************************************************************

       IDENTIFICATION DIVISION.
       PROGRAM-ID. CREACC.
       AUTHOR. Jon Collett.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      * SOURCE-COMPUTER.  IBM-370 WITH DEBUGGING MODE.
       SOURCE-COMPUTER.  IBM-370.
       OBJECT-COMPUTER.  IBM-370.

       INPUT-OUTPUT SECTION.

       DATA DIVISION.
       FILE SECTION.

       WORKING-STORAGE SECTION.


      *COPY SORTCODE.

      * Copybook Location: 
      * file:///Users/rafaeltesta.rt/Library/CloudStorage/OneDrive-IBM/B
      * ank-of-Z-main/src/base/cics/copy/SORTCODE.cpy

      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      *                                                                *
      ******************************************************************
       77 SORTCODE           PIC 9(6) VALUE 987654.



       77 SYSIDERR-RETRY                PIC 999.

      * Get the ACCOUNT DB2 copybook
      *    EXEC SQL
      *       INCLUDE ACCDB2
      *    END-EXEC.

      * Copybook Location: 
      * file:///Users/rafaeltesta.rt/Library/CloudStorage/OneDrive-IBM/B
      * ank-of-Z-main/src/base/cics/copy/ACCDB2.cpy

      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      *                                                                *
      ******************************************************************
           EXEC SQL DECLARE ACCOUNT TABLE
              ( ACCOUNT_EYECATCHER             CHAR(4),
                ACCOUNT_CUSTOMER_NUMBER        CHAR(10),
                ACCOUNT_SORTCODE               CHAR(6) NOT NULL,
                ACCOUNT_NUMBER                 CHAR(8) NOT NULL,
                ACCOUNT_TYPE                   CHAR(8),
                ACCOUNT_INTEREST_RATE          DECIMAL(4, 2),
                ACCOUNT_OPENED                 DATE,
                ACCOUNT_OVERDRAFT_LIMIT        INTEGER,
                ACCOUNT_LAST_STATEMENT         DATE,
                ACCOUNT_NEXT_STATEMENT         DATE,
                ACCOUNT_AVAILABLE_BALANCE      DECIMAL(10, 2),
                ACCOUNT_ACTUAL_BALANCE         DECIMAL(10, 2) )
           END-EXEC.

      * ACCOUNT Host variables for DB2
       01 HOST-ACCOUNT-ROW.
          03 HV-ACCOUNT-EYECATCHER      PIC X(4).
          03 HV-ACCOUNT-CUST-NO         PIC X(10).
          03 HV-ACCOUNT-SORTCODE        PIC X(6).
          03 HV-ACCOUNT-ACC-NO          PIC X(8).
          03 HV-ACCOUNT-ACC-TYPE        PIC X(8).
          03 HV-ACCOUNT-INT-RATE        PIC S9(4)V99 COMP-3.
          03 HV-ACCOUNT-OPENED          PIC X(10).
          03 HV-ACCOUNT-OPENED-GROUP REDEFINES HV-ACCOUNT-OPENED.
             05 HV-ACCOUNT-OPENED-DAY   PIC XX.
             05 HV-ACCOUNT-OPENED-DELIM1
                                        PIC X.
             05 HV-ACCOUNT-OPENED-MONTH PIC XX.
             05 HV-ACCOUNT-OPENED-DELIM2
                                        PIC X.
             05 HV-ACCOUNT-OPENED-YEAR  PIC X(4).
          03 HV-ACCOUNT-OVERDRAFT-LIM   PIC S9(9) COMP.
          03 HV-ACCOUNT-LAST-STMT       PIC X(10).
          03 HV-ACCOUNT-LAST-STMT-GROUP
                REDEFINES HV-ACCOUNT-LAST-STMT.
             05 HV-ACCOUNT-LAST-STMT-DAY
                                        PIC XX.
             05 HV-ACCOUNT-LAST-STMT-DELIM1
                                        PIC X.
             05 HV-ACCOUNT-LAST-STMT-MONTH
                                        PIC XX.
             05 HV-ACCOUNT-LAST-STMT-DELIM2
                                        PIC X.
             05 HV-ACCOUNT-LAST-STMT-YEAR
                                        PIC X(4).
          03 HV-ACCOUNT-NEXT-STMT       PIC X(10).
          03 HV-ACCOUNT-NEXT-STMT-GROUP
                REDEFINES HV-ACCOUNT-NEXT-STMT.
             05 HV-ACCOUNT-NEXT-STMT-DAY
                                        PIC XX.
             05 HV-ACCOUNT-NEXT-STMT-DELIM1
                                        PIC X.
             05 HV-ACCOUNT-NEXT-STMT-MONTH
                                        PIC XX.
             05 HV-ACCOUNT-NEXT-STMT-DELIM2
                                        PIC X.
             05 HV-ACCOUNT-NEXT-STMT-YEAR
                                        PIC X(4).
          03 HV-ACCOUNT-AVAIL-BAL       PIC S9(10)V99 COMP-3.
          03 HV-ACCOUNT-ACTUAL-BAL      PIC S9(10)V99 COMP-3.


       01 SQLCODE-DISPLAY               PIC S9(8) DISPLAY
             SIGN LEADING SEPARATE.

      * PROCTRAN DB2 copybook
      *    EXEC SQL
      *      INCLUDE PROCDB2
      *    END-EXEC.

      * Copybook Location: 
      * file:///Users/rafaeltesta.rt/Library/CloudStorage/OneDrive-IBM/B
      * ank-of-Z-main/src/base/cics/copy/PROCDB2.cpy

      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      *                                                                *
      ******************************************************************
           EXEC SQL DECLARE PROCTRAN TABLE
              (
               PROCTRAN_EYECATCHER             CHAR(4),
               PROCTRAN_SORTCODE               CHAR(6) NOT NULL,
               PROCTRAN_NUMBER                 CHAR(8) NOT NULL,
               PROCTRAN_DATE                   CHAR(8),
               PROCTRAN_TIME                   CHAR(6),
               PROCTRAN_REF                    CHAR(12),
               PROCTRAN_TYPE                   CHAR(3),
               PROCTRAN_DESC                   CHAR(40),
               PROCTRAN_AMOUNT                 DECIMAL(12, 2)
              )
           END-EXEC.

      * PROCTRAN host variables for DB2
       01 HOST-PROCTRAN-ROW.
          03 HV-PROCTRAN-EYECATCHER     PIC X(4).
          03 HV-PROCTRAN-SORT-CODE      PIC X(6).
          03 HV-PROCTRAN-ACC-NUMBER     PIC X(8).
          03 HV-PROCTRAN-DATE           PIC X(10).
          03 HV-PROCTRAN-TIME           PIC X(6).
          03 HV-PROCTRAN-REF            PIC X(12).
          03 HV-PROCTRAN-TYPE           PIC X(3).
          03 HV-PROCTRAN-DESC           PIC X(40).
          03 HV-PROCTRAN-AMOUNT         PIC S9(10)V99 COMP-3.

      * CONTROL Host variables for DB2
       01 HOST-CONTROL-ROW.
          03 HV-CONTROL-NAME            PIC X(32).
          03 HV-CONTROL-VALUE-NUM       PIC S9(9) COMP.
          03 HV-CONTROL-VALUE-STR       PIC X(40).


      * Pull in the SQL COMMAREA
           EXEC SQL
          INCLUDE SQLCA
           END-EXEC.

       01 PROCTRAN-AREA.
      *   COPY PROCTRAN.

      * Copybook Location: 
      * file:///Users/rafaeltesta.rt/Library/CloudStorage/OneDrive-IBM/B
      * ank-of-Z-main/src/base/cics/copy/PROCTRAN.cpy

      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      *                                                                *
      ******************************************************************
           03 PROC-TRAN-DATA.
              05 PROC-TRAN-EYE-CATCHER        PIC X(4).
              88 PROC-TRAN-VALID VALUE 'PRTR'.
              05 PROC-TRAN-LOGICAL-DELETE-AREA REDEFINES
                 PROC-TRAN-EYE-CATCHER.
                 07 PROC-TRAN-LOGICAL-DELETE-FLAG PIC X.
                 88 PROC-TRAN-LOGICALLY-DELETED VALUE X'FF'.
                 07 FILLER PIC X(3).
              05 PROC-TRAN-ID.
                 07 PROC-TRAN-SORT-CODE       PIC 9(6).
                 07 PROC-TRAN-NUMBER          PIC 9(8).
              05 PROC-TRAN-DATE               PIC 9(8).
              05 PROC-TRAN-DATE-GRP REDEFINES PROC-TRAN-DATE.
                 07 PROC-TRAN-DATE-GRP-YYYY   PIC 9999.
                 07 PROC-TRAN-DATE-GRP-MM     PIC 99.
                 07 PROC-TRAN-DATE-GRP-DD     PIC 99.
              05 PROC-TRAN-TIME               PIC 9(6).
              05 PROC-TRAN-TIME-GRP REDEFINES PROC-TRAN-TIME.
                 07 PROC-TRAN-TIME-GRP-HH     PIC 99.
                 07 PROC-TRAN-TIME-GRP-MM     PIC 99.
                 07 PROC-TRAN-TIME-GRP-SS     PIC 99.
              05 PROC-TRAN-REF                PIC 9(12).
              05 PROC-TRAN-TYPE               PIC X(3).
              88 PROC-TY-CHEQUE-ACKNOWLEDGED      VALUE 'CHA'.
              88 PROC-TY-CHEQUE-FAILURE           VALUE 'CHF'.
              88 PROC-TY-CHEQUE-PAID-IN           VALUE 'CHI'.
              88 PROC-TY-CHEQUE-PAID-OUT          VALUE 'CHO'.
              88 PROC-TY-CREDIT                   VALUE 'CRE'.
              88 PROC-TY-DEBIT                    VALUE 'DEB'.
              88 PROC-TY-WEB-CREATE-ACCOUNT       VALUE 'ICA'.
              88 PROC-TY-WEB-CREATE-CUSTOMER      VALUE 'ICC'.
              88 PROC-TY-WEB-DELETE-ACCOUNT       VALUE 'IDA'.
              88 PROC-TY-WEB-DELETE-CUSTOMER      VALUE 'IDC'.
              88 PROC-TY-BRANCH-CREATE-ACCOUNT    VALUE 'OCA'.
              88 PROC-TY-BRANCH-CREATE-CUSTOMER   VALUE 'OCC'.
              88 PROC-TY-BRANCH-DELETE-ACCOUNT    VALUE 'ODA'.
              88 PROC-TY-BRANCH-DELETE-CUSTOMER   VALUE 'ODC'.
              88 PROC-TY-CREATE-SODD              VALUE 'OCS'.
              88 PROC-TY-PAYMENT-CREDIT           VALUE 'PCR'.
              88 PROC-TY-PAYMENT-DEBIT            VALUE 'PDR'.
              88 PROC-TY-TRANSFER                 VALUE 'TFR'.
              05 PROC-TRAN-DESC               PIC X(40).
              05 PROC-TRAN-DESC-XFR REDEFINES PROC-TRAN-DESC.
                07 PROC-TRAN-DESC-XFR-HEADER PIC X(26).
                88 PROC-TRAN-DESC-XFR-FLAG
                   VALUE 'TRANSFER'.
                07 PROC-TRAN-DESC-XFR-SORTCODE
                   PIC 9(6).
                07 PROC-TRAN-DESC-XFR-ACCOUNT
                   PIC 9(8).
              05 PROC-TRAN-DESC-DELACC REDEFINES PROC-TRAN-DESC.
                07 PROC-DESC-DELACC-CUSTOMER PIC 9(10).
                07 PROC-DESC-DELACC-ACCTYPE PIC X(8).
                07 PROC-DESC-DELACC-LAST-DD PIC 99.
                07 PROC-DESC-DELACC-LAST-MM PIC 99.
                07 PROC-DESC-DELACC-LAST-YYYY PIC 9999.
                07 PROC-DESC-DELACC-NEXT-DD PIC 99.
                07 PROC-DESC-DELACC-NEXT-MM PIC 99.
                07 PROC-DESC-DELACC-NEXT-YYYY PIC 9999.
                07 PROC-DESC-DELACC-FOOTER PIC X(6).
                88 PROC-DESC-DELACC-FLAG
                   VALUE 'DELETE'.
              05 PROC-TRAN-DESC-CREACC REDEFINES PROC-TRAN-DESC.
                07 PROC-DESC-CREACC-CUSTOMER PIC 9(10).
                07 PROC-DESC-CREACC-ACCTYPE PIC X(8).
                07 PROC-DESC-CREACC-LAST-DD PIC 99.
                07 PROC-DESC-CREACC-LAST-MM PIC 99.
                07 PROC-DESC-CREACC-LAST-YYYY PIC 9999.
                07 PROC-DESC-CREACC-NEXT-DD PIC 99.
                07 PROC-DESC-CREACC-NEXT-MM PIC 99.
                07 PROC-DESC-CREACC-NEXT-YYYY PIC 9999.
                07 PROC-DESC-CREACC-FOOTER PIC X(6).
                88 PROC-DESC-CREACC-FLAG
                   VALUE 'CREATE'.
              05 PROC-TRAN-DESC-DELCUS REDEFINES PROC-TRAN-DESC.
                07 PROC-DESC-DELCUS-SORTCODE PIC 9(6).
                07 PROC-DESC-DELCUS-CUSTOMER PIC 9(10).
                07 PROC-DESC-DELCUS-NAME     PIC X(14).
                07 PROC-DESC-DELCUS-DOB-YYYY  PIC 9999.
                07 PROC-DESC-DELCUS-FILLER    PIC X.
                88 PROC-DESC-DELCUS-FILLER-SET VALUE '-'.
                07 PROC-DESC-DELCUS-DOB-MM    PIC 99.
                07 PROC-DESC-DELCUS-FILLER2   PIC X.
                88 PROC-DESC-DELCUS-FILLER2-SET VALUE '-'.
                07 PROC-DESC-DELCUS-DOB-DD    PIC 99.
              05 PROC-TRAN-DESC-CRECUS REDEFINES PROC-TRAN-DESC.
                07 PROC-DESC-CRECUS-SORTCODE PIC 9(6).
                07 PROC-DESC-CRECUS-CUSTOMER PIC 9(10).
                07 PROC-DESC-CRECUS-NAME     PIC X(14).
                07 PROC-DESC-CRECUS-DOB-YYYY  PIC 9999.
                07 PROC-DESC-CRECUS-FILLER    PIC X.
                88 PROC-DESC-CRECUS-FILLER-SET VALUE '-'.
                07 PROC-DESC-CRECUS-DOB-MM    PIC 99.
                07 PROC-DESC-CRECUS-FILLER2   PIC X.
                88 PROC-DESC-CRECUS-FILLER2-SET VALUE '-'.
                07 PROC-DESC-CRECUS-DOB-DD    PIC 99.
              05 PROC-TRAN-AMOUNT             PIC S9(10)V99.

       01 PROCTRAN-RIDFLD               PIC S9(8) COMP.

       01 PROCTRAN-RETRY                PIC 999.
       01 WS-EXIT-RETRY-LOOP            PIC X         VALUE ' '.

       01 WS-CICS-WORK-AREA.
          05 WS-CICS-RESP               PIC S9(8) COMP.
          05 WS-CICS-RESP2              PIC S9(8) COMP.
          05 WS-EIBRESP-DISPLAY         PIC S9(8) DISPLAY
                SIGN LEADING SEPARATE.

       01 WS-CUSTOMER-NO-NUM            PIC 9(10).

       LOCAL-STORAGE SECTION.
       01 FILE-RETRY                    PIC 999.

       01 OUTPUT-DATA.
      *    COPY ACCOUNT.

      * Copybook Location: 
      * file:///Users/rafaeltesta.rt/Library/CloudStorage/OneDrive-IBM/B
      * ank-of-Z-main/src/base/cics/copy/ACCOUNT.cpy

      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      *                                                                *
      ******************************************************************
              03 ACCOUNT-DATA.
                 05 ACCOUNT-EYE-CATCHER        PIC X(4).
                 88 ACCOUNT-EYECATCHER-VALUE        VALUE 'ACCT'.
                 05 ACCOUNT-CUST-NO            PIC 9(10).
                 05 ACCOUNT-KEY.
                    07 ACCOUNT-SORT-CODE       PIC 9(6).
                    07 ACCOUNT-NUMBER          PIC 9(8).
                 05 ACCOUNT-TYPE               PIC X(8).
                 05 ACCOUNT-INTEREST-RATE      PIC 9(4)V99.
                 05 ACCOUNT-OPENED             PIC 9(8).
                 05 ACCOUNT-OPENED-GROUP REDEFINES ACCOUNT-OPENED.
                    07 ACCOUNT-OPENED-DAY       PIC 99.
                    07 ACCOUNT-OPENED-MONTH     PIC 99.
                    07 ACCOUNT-OPENED-YEAR      PIC 9999.
                 05 ACCOUNT-OVERDRAFT-LIMIT    PIC 9(8).
                 05 ACCOUNT-LAST-STMT-DATE     PIC 9(8).
                 05 ACCOUNT-LAST-STMT-GROUP
                    REDEFINES ACCOUNT-LAST-STMT-DATE.
                    07 ACCOUNT-LAST-STMT-DAY   PIC 99.
                    07 ACCOUNT-LAST-STMT-MONTH PIC 99.
                    07 ACCOUNT-LAST-STMT-YEAR  PIC 9999.
                 05 ACCOUNT-NEXT-STMT-DATE     PIC 9(8).
                 05 ACCOUNT-NEXT-STMT-GROUP
                   REDEFINES ACCOUNT-NEXT-STMT-DATE.
                    07 ACCOUNT-NEXT-STMT-DAY   PIC 99.
                    07 ACCOUNT-NEXT-STMT-MONTH PIC 99.
                    07 ACCOUNT-NEXT-STMT-YEAR  PIC 9999.
                 05 ACCOUNT-AVAILABLE-BALANCE  PIC S9(10)V99.
                 05 ACCOUNT-ACTUAL-BALANCE     PIC S9(10)V99.

       01 OUTPUTC-DATA.
      *    COPY CUSTOMER.

      * Copybook Location: 
      * file:///Users/rafaeltesta.rt/Library/CloudStorage/OneDrive-IBM/B
      * ank-of-Z-main/src/base/cics/copy/CUSTOMER.cpy

      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *
      *                                                                *
      ******************************************************************
           03 CUSTOMER-RECORD.
              05 CUSTOMER-EYECATCHER                 PIC X(4).
                 88 CUSTOMER-EYECATCHER-VALUE        VALUE 'CUST'.
              05 CUSTOMER-KEY.
                 07 CUSTOMER-SORTCODE                PIC 9(6) DISPLAY.
                 07 CUSTOMER-NUMBER                  PIC 9(10) DISPLAY.
              05 CUSTOMER-NAME.
                 07 CUSTOMER-TITLE                   PIC X(10).
                 07 CUSTOMER-FIRST-NAME              PIC X(50).
                 07 CUSTOMER-LAST-NAME               PIC X(50).
              05 CUSTOMER-DOB.
                 07 CUSTOMER-DOB-DAY                 PIC 99 DISPLAY.
                 07 CUSTOMER-DOB-MONTH               PIC 99 DISPLAY.
                 07 CUSTOMER-DOB-YEAR                PIC 9999 DISPLAY.
              05 CUSTOMER-PHONE                      PIC X(20).
              05 CUSTOMER-ADDRESS.
                 07 CUSTOMER-ADDR-LINE1              PIC X(50).
                 07 CUSTOMER-ADDR-LINE2              PIC X(50).
                 07 CUSTOMER-CITY                    PIC X(50).
                 07 CUSTOMER-POSTCODE                PIC X(10).
                 07 CUSTOMER-COUNTRY                 PIC X(50).
              05 CUSTOMER-STATUS                     PIC X(10).
                 88 CUSTOMER-STATUS-ACTIVE           VALUE 'ACTIVE'.
                 88 CUSTOMER-STATUS-INACTIVE         VALUE 'INACTIVE'.
                 88 CUSTOMER-STATUS-SUSPENDED        VALUE 'SUSPENDED'.
              05 CUSTOMER-CREATED-DATE.
                 07 CUSTOMER-CREATED-DAY             PIC 99 DISPLAY.
                 07 CUSTOMER-CREATED-MONTH           PIC 99 DISPLAY.
                 07 CUSTOMER-CREATED-YEAR            PIC 9999 DISPLAY.
              05 CUSTOMER-CREDIT-SCORE               PIC 999.
              05 CUSTOMER-CS-REVIEW-DATE.
                 07 CUSTOMER-CS-REVIEW-DAY           PIC 99 DISPLAY.
                 07 CUSTOMER-CS-REVIEW-MONTH         PIC 99 DISPLAY.
                 07 CUSTOMER-CS-REVIEW-YEAR          PIC 9999 DISPLAY.

       01 RETURN-DATA.
          03 RETURN-DATA-EYECATCHER     PIC X(4).
          03 RETURN-DATA-NUMBER         PIC 9(10) DISPLAY.
          03 RETURN-DATA-NAME           PIC X(60).
          03 RETURN-DATA-ADDRESS        PIC X(160).
          03 RETURN-DATA-DATE-OF-BIRTH  PIC 9(8).


       01 CUSTOMER-KY.
          03 REQUIRED-SORT-CODE         PIC 9(6)      VALUE 0.
          03 REQUIRED-CUST-NUMBER       PIC 9(10)     VALUE 0.

       01 ACCOUNT-KY.
          03 REQUIRED-SORT-CODE2        PIC 9(6)      VALUE 0.
          03 REQUIRED-ACC-NUMBER        PIC 9(8)      VALUE 0.

       01 RANDOM-CUSTOMER               PIC 9(10)     VALUE 0.
       01 HIGHEST-CUST-NUMBER           PIC 9(10)     VALUE 0.

       01 EXIT-VSAM-READ                PIC X         VALUE 'N'.
       01 EXIT-DB2-READ                 PIC X         VALUE 'N'.

       01 WS-V-RETRIED                  PIC X         VALUE 'N'.
       01 WS-D-RETRIED                  PIC X         VALUE 'N'.

       01 WS-ERROR                      PIC X(40)     VALUE ALL '#'.

      *
      * CUSTOMER NCS definitions
      *
       01 NCS-ACC-NO-STUFF.
          03 NCS-ACC-NO-NAME.
             05 NCS-ACC-NO-ACT-NAME     PIC X(9)
                                                      VALUE 'BANKZACCT'.
             05 NCS-ACC-NO-TEST-SORT    PIC X(6)
                                                      VALUE '      '.
             05 NCS-ACC-NO-FILL         PIC XX
                                                      VALUE '  '.

          03 NCS-ACC-NO-INC             PIC 9(16) COMP
                                                      VALUE 0.
          03 NCS-ACC-NO-VALUE           PIC 9(16) COMP
                                                      VALUE 0.

          03 NCS-ACC-NO-RESP            PIC XX        VALUE '00'.



       01 WS-DISP-CUST-NO-VAL           PIC S9(18) DISPLAY.

       01 WS-ACC-REC-LEN                PIC S9(4) COMP
                                                      VALUE 0.

       01 NCS-UPDATED                   PIC X         VALUE 'N'.

       01 WS-U-TIME                     PIC S9(15) COMP-3.
       01 WS-ORIG-DATE                  PIC X(10).
       01 WS-ORIG-DATE-GRP REDEFINES WS-ORIG-DATE.
          03 WS-ORIG-DATE-DD            PIC 99.
          03 FILLER                     PIC X.
          03 WS-ORIG-DATE-MM            PIC 99.
          03 FILLER                     PIC X.
          03 WS-ORIG-DATE-YYYY          PIC 9999.

       01 DONT-CARE                     PIC 9(8) BINARY.
       01 LEAP-YEAR                     PIC 9(8) BINARY.

       01 WS-ORIG-DATE-GRP-X.
          03 WS-ORIG-DATE-DD-X          PIC XX.
          03 FILLER                     PIC X         VALUE '.'.
          03 WS-ORIG-DATE-MM-X          PIC XX.
          03 FILLER                     PIC X         VALUE '.'.
          03 WS-ORIG-DATE-YYYY-X        PIC X(4).

       01 WS-STDT-X                     PIC X(8).
       01 WS-STDT-9 REDEFINES WS-STDT-X.
          03 WS-STDT-9-NUM              PIC 9(8).
       01 WS-STDT-9-NUMERIC             PIC 9(8).

       01 WS-INTEGER                    PIC S9(9) COMP
                                                      VALUE 0.

       01 WS-FUTURE-DATE                PIC 9(8).
       01 WS-FUT REDEFINES WS-FUTURE-DATE.
          03 WS-FUTURE-YY               PIC 9(4).
          03 WS-FUTURE-MM               PIC 99.
          03 WS-FUTURE-DD               PIC 99.

       01 WS-FUTURE-CONV.
          03 WS-FUT-9                   PIC 9(8).
          03 WS-FUT-X REDEFINES WS-FUT-9.
             05 WS-FUT-X-YY             PIC X(4).
             05 WS-FUT-X-MM             PIC XX.
             05 WS-FUT-X-DD             PIC XX.

       01 NCS-ACC-NO-DISP               PIC 9(16)     VALUE 0.

       01 STORED-SORTCODE               PIC X(6)      VALUE SPACES.
       01 STORED-CUSTNO                 PIC X(10)     VALUE SPACES.
       01 STORED-ACCTYPE                PIC X(8)      VALUE SPACES.
       01 STORED-LST-STMT               PIC X(8)      VALUE SPACES.
       01 STORED-NXT-STMT               PIC X(8)      VALUE SPACES.
       01 STORED-ACCNO                  PIC X(8)      VALUE SPACES.

       01 WS-EIBTASKN12                 PIC 9(12)     VALUE 0.

       01 ACCOUNT-KY3.
          03 REQUIRED-SORT-CODE3        PIC 9(6)      VALUE 0.
          03 REQUIRED-ACCT-NUMBER3      PIC 9(8)      VALUE 0.

       01 ACCOUNT-KY3-BYTES REDEFINES ACCOUNT-KY3
                                        PIC X(14).

       01 INQCUST-COMMAREA.
      *   COPY INQCUSTZ.

      * Copybook Location: 
      * file:///Users/rafaeltesta.rt/Library/CloudStorage/OneDrive-IBM/B
      * ank-of-Z-main/src/base/cics/copy/INQCUSTZ.cpy

      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      ******************************************************************
          03 INQCUST-EYE                  PIC X(4).
          03 INQCUST-SCODE                PIC X(6).
          03 INQCUST-CUSTNO               PIC 9(10).
          03 INQCUST-NAME.
             05 INQCUST-TITLE             PIC X(10).
             05 INQCUST-FIRST-NAME        PIC X(50).
             05 INQCUST-LAST-NAME         PIC X(50).
          03 INQCUST-DOB.
             05 INQCUST-DOB-DD            PIC 99 DISPLAY.
             05 INQCUST-DOB-MM            PIC 99 DISPLAY.
             05 INQCUST-DOB-YYYY          PIC 9999 DISPLAY.
          03 INQCUST-PHONE                PIC X(20).
          03 INQCUST-ADDR.
             05 INQCUST-ADDR-LINE1        PIC X(50).
             05 INQCUST-ADDR-LINE2        PIC X(50).
             05 INQCUST-CITY              PIC X(50).
             05 INQCUST-POSTCODE          PIC X(10).
             05 INQCUST-COUNTRY           PIC X(50).
          03 INQCUST-STATUS               PIC X(10).
          03 INQCUST-CREATED-DATE.
             05 INQCUST-CREATED-DD        PIC 99 DISPLAY.
             05 INQCUST-CREATED-MM        PIC 99 DISPLAY.
             05 INQCUST-CREATED-YYYY      PIC 9999 DISPLAY.
          03 INQCUST-CREDIT-SCORE         PIC 999.
          03 INQCUST-CS-REVIEW-DT.
             05 INQCUST-CS-REVIEW-DD      PIC 99 DISPLAY.
             05 INQCUST-CS-REVIEW-MM      PIC 99 DISPLAY.
             05 INQCUST-CS-REVIEW-YYYY    PIC 9999 DISPLAY.
          03 INQCUST-INQ-SUCCESS          PIC X.
          03 INQCUST-INQ-FAIL-CD          PIC X.
          03 INQCUST-PCB-POINTER          PIC X(4).

       01 INQACCCU-COMMAREA.
      *    COPY INQACCCU REPLACING ==NUMBER-OF-ACCOUNTS.==
      *    BY ==NUMBER-OF-ACCOUNTS IN INQACCCU-COMMAREA.==.

      * Copybook Location: 
      * file:///Users/rafaeltesta.rt/Library/CloudStorage/OneDrive-IBM/B
      * ank-of-Z-main/src/base/cics/copy/INQACCCU.cpy

      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      *                                                                *
      ******************************************************************
          03 NUMBER-OF-ACCOUNTS        PIC S9(8) BINARY.
          03 CUSTOMER-NUMBER           PIC 9(10).
          03 COMM-SUCCESS              PIC X.
          03 COMM-FAIL-CODE            PIC X.
          03 CUSTOMER-FOUND            PIC X.
          03 COMM-PCB-POINTER          POINTER.
          03 ACCOUNT-DETAILS OCCURS 1 TO 20 DEPENDING ON
              NUMBER-OF-ACCOUNTS IN INQACCCU-COMMAREA.
            05 COMM-EYE                  PIC X(4).
            05 COMM-CUSTNO               PIC X(10).
            05 COMM-SCODE                PIC X(6).
            05 COMM-ACCNO                PIC 9(8).
            05 COMM-ACC-TYPE             PIC X(8).
            05 COMM-INT-RATE             PIC 9(4)V99.
            05 COMM-OPENED               PIC 9(8).
            05 COMM-OPENED-GROUP REDEFINES COMM-OPENED.
              07 COMM-OPENED-DAY PIC 99.
              07 COMM-OPENED-MONTH PIC 99.
              07 COMM-OPENED-YEAR PIC 9999.
            05 COMM-OVERDRAFT            PIC 9(8).
            05 COMM-LAST-STMT-DT         PIC 9(8).
            05 COMM-LAST-STMT-GROUP REDEFINES COMM-LAST-STMT-DT.
              07 COMM-LAST-STMT-DAY PIC 99.
              07 COMM-LAST-STMT-MONTH PIC 99.
              07 COMM-LAST-STMT-YEAR PIC 9999.
            05 COMM-NEXT-STMT-DT         PIC 9(8).
            05 COMM-NEXT-STMT-GROUP REDEFINES COMM-NEXT-STMT-DT.
              07 COMM-NEXT-STMT-DAY PIC 99.
              07 COMM-NEXT-STMT-MONTH PIC 99.
              07 COMM-NEXT-STMT-YEAR PIC 9999.
            05 COMM-AVAIL-BAL            PIC S9(10)V99.
            05 COMM-ACTUAL-BAL           PIC S9(10)V99.

       01 STORM-DRAIN-CONDITION         PIC X(20).

       01 ACCOUNT-CONTROL.
      *   COPY ACCTCTRL.

      * Copybook Location: 
      * file:///Users/rafaeltesta.rt/Library/CloudStorage/OneDrive-IBM/B
      * ank-of-Z-main/src/base/cics/copy/ACCTCTRL.cpy

      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      *                                                                *
      ******************************************************************
              03 ACCOUNT-CONTROL-RECORD.
                 05 ACCOUNT-CONTROL-EYE-CATCHER        PIC X(4).
                 88 ACCOUNT-CONTROL-EYECATCHER-V   VALUE 'CTRL'.
                 05 FILLER                     PIC 9(10).
                 05 ACCOUNT-CONTROL-KEY.
                    07 ACCOUNT-CONTROL-SORT-CODE       PIC 9(6).
                    07 ACCOUNT-CONTROL-NUMBER          PIC 9(8).
                 05 NUMBER-OF-ACCOUNTS                 PIC 9(8).
                 05 LAST-ACCOUNT-NUMBER                PIC 9(8).
                 05 ACCOUNT-CONTROL-SUCCESS-FLAG       PIC X.
                 88 ACCOUNT-CONTROL-SUCCESS VALUE 'Y'.
                 05 ACCOUNT-CONTROL-FAIL-CODE PIC X.
                 05 FILLER                     PIC 9(4)V99.
                 05 FILLER                     PIC 9(8).
                 05 FILLER                     PIC 9(8).
                 05 FILLER                     PIC 9(8).
                 05 FILLER                     PIC 9(8).
                 05 FILLER                     PIC S9(10)V99.
                 05 FILLER                     PIC X(2).


       01 WS-TIME-DATA.
          03 WS-TIME-NOW                PIC 9(6).
          03 WS-TIME-NOW-GRP REDEFINES WS-TIME-NOW.
             05 WS-TIME-NOW-GRP-HH      PIC 99.
             05 WS-TIME-NOW-GRP-MM      PIC 99.
             05 WS-TIME-NOW-GRP-SS      PIC 99.

       01 WS-ABEND-PGM                  PIC X(8)      VALUE 'ABNDPROC'.

       01 ABNDINFO-REC.
      *    COPY ABNDINFO.

      * Copybook Location: 
      * file:///Users/rafaeltesta.rt/Library/CloudStorage/OneDrive-IBM/B
      * ank-of-Z-main/src/base/cics/copy/ABNDINFO.cpy

      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      *                                                                *
      ******************************************************************
           03 ABND-VSAM-KEY.
              05 ABND-UTIME-KEY                  PIC S9(15) COMP-3.
              05 ABND-TASKNO-KEY                 PIC 9(4).
           03 ABND-APPLID                        PIC X(8).
           03 ABND-TRANID                        PIC X(4).
           03 ABND-DATE                          PIC X(10).
           03 ABND-TIME                          PIC X(8).
           03 ABND-CODE                          PIC X(4).
           03 ABND-PROGRAM                       PIC X(8).
           03 ABND-RESPCODE                      PIC S9(8) DISPLAY
                  SIGN LEADING SEPARATE.
           03 ABND-RESP2CODE                     PIC S9(8) DISPLAY
                  SIGN LEADING SEPARATE.
           03 ABND-SQLCODE                       PIC S9(8) DISPLAY
                  SIGN LEADING SEPARATE.
           03 ABND-FREEFORM                      PIC X(600).

       LINKAGE SECTION.
       01 DFHCOMMAREA.
      *    COPY CREACC.

      * Copybook Location: 
      * file:///Users/rafaeltesta.rt/Library/CloudStorage/OneDrive-IBM/B
      * ank-of-Z-main/src/base/cics/copy/CREACC.cpy

      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      *                                                                *
      ******************************************************************
          03 COMM-EYECATCHER                 PIC X(4).
          03 COMM-CUSTNO                     PIC 9(10).
          03 COMM-KEY.
             05 COMM-SORTCODE                PIC 9(6) DISPLAY.
             05 COMM-NUMBER                  PIC 9(8) DISPLAY.
          03 COMM-ACC-TYPE                   PIC X(8).
          03 COMM-INT-RT                     PIC 9(4)V99.
          03 COMM-OPENED                     PIC 9(8).
          03 COMM-OPENED-GROUP REDEFINES COMM-OPENED.
             05 COMM-OPENED-DAY              PIC 99.
             05 COMM-OPENED-MONTH            PIC 99.
             05 COMM-OPENED-YEAR             PIC 9999.
          03 COMM-OVERDR-LIM                 PIC 9(8).
          03 COMM-LAST-STMT-DT               PIC 9(8).
          03 COMM-LAST-STMNT-GROUP REDEFINES COMM-LAST-STMT-DT.
             05 COMM-LASTST-DAY               PIC 99.
             05 COMM-LASTST-MONTH             PIC 99.
             05 COMM-LASTST-YEAR              PIC 9999.
          03 COMM-NEXT-STMT-DT               PIC 9(8).
          03 COMM-NEXT-STMNT-GROUP REDEFINES COMM-NEXT-STMT-DT.
             05 COMM-NEXTST-DAY               PIC 99.
             05 COMM-NEXTST-MONTH             PIC 99.
             05 COMM-NEXTST-YEAR              PIC 9999.
          03 COMM-AVAIL-BAL                  PIC S9(10)V99.
          03 COMM-ACT-BAL                    PIC S9(10)V99.
          03 COMM-SUCCESS                    PIC X.
          03 COMM-FAIL-CODE                  PIC X.


       PROCEDURE DIVISION USING DFHCOMMAREA.
       PREMIERE SECTION.
       P010.

           DISPLAY 'CREACC: Starting account creation'
           DISPLAY 'CREACC: Customer number='
                   COMM-CUSTNO
              IN DFHCOMMAREA

           MOVE SORTCODE TO
              REQUIRED-SORT-CODE
              REQUIRED-SORT-CODE2.

           MOVE ZERO TO ACCOUNT-NUMBER.
           INITIALIZE INQCUST-COMMAREA

      *
      *    We need to validate that the supplied CUSTOMER actually
      *    exists by linking to INQCUST.
      *

           MOVE COMM-CUSTNO IN DFHCOMMAREA TO INQCUST-CUSTNO.

           DISPLAY 'CREACC: Linking to INQCUST for customer='
                   INQCUST-CUSTNO

           EXEC CICS LINK PROGRAM('INQCUST ')
                COMMAREA(INQCUST-COMMAREA)
                RESP(WS-CICS-RESP)
                END-EXEC.

           DISPLAY 'CREACC: INQCUST returned RESP=' WS-CICS-RESP
           DISPLAY 'CREACC: INQCUST-INQ-SUCCESS='
                   INQCUST-INQ-SUCCESS

      *
      *    If the link failed for some reason, or the link to INQCUST
      *    indicated that customer information could not be
      *    successfully retrieved then set fail flags and finished.
      *
           IF EIBRESP IS NOT EQUAL TO DFHRESP(NORMAL)
              OR INQCUST-INQ-SUCCESS IS NOT EQUAL TO 'Y'

              MOVE 'N' TO COMM-SUCCESS IN DFHCOMMAREA
              MOVE '1' TO COMM-FAIL-CODE IN DFHCOMMAREA

              PERFORM GET-ME-OUT-OF-HERE

           END-IF

      *
      *    Link to INQACCCU to  get account information
      *
           DISPLAY 'CREACC: Performing customer account count'
           PERFORM CUSTOMER-ACCOUNT-COUNT.

           DISPLAY 'CREACC: Account count returned RESP='
                   WS-CICS-RESP
           DISPLAY 'CREACC: Number of accounts='
                   NUMBER-OF-ACCOUNTS IN INQACCCU-COMMAREA

           IF WS-CICS-RESP IS NOT EQUAL TO DFHRESP(NORMAL)
              DISPLAY 'CREACC: Error counting accounts'
              MOVE 'N' TO COMM-SUCCESS IN DFHCOMMAREA
              MOVE 'N' TO COMM-SUCCESS IN INQACCCU-COMMAREA
              MOVE '9' TO COMM-FAIL-CODE IN DFHCOMMAREA

              PERFORM GET-ME-OUT-OF-HERE
           END-IF

           IF COMM-SUCCESS IN INQACCCU-COMMAREA = 'N'
              DISPLAY 'Error counting accounts'
              MOVE 'N' TO COMM-SUCCESS IN DFHCOMMAREA
              MOVE '9' TO COMM-FAIL-CODE IN DFHCOMMAREA

              PERFORM GET-ME-OUT-OF-HERE
           END-IF


           IF NUMBER-OF-ACCOUNTS IN INQACCCU-COMMAREA > 9
              DISPLAY 'CREACC: Customer has too many accounts (>9)'
              MOVE 'N' TO COMM-SUCCESS IN DFHCOMMAREA
              MOVE '8' TO COMM-FAIL-CODE IN DFHCOMMAREA

              PERFORM GET-ME-OUT-OF-HERE
           END-IF

      *
      *    Validate the type of account e.g. MORTGAGE etc.
      *
           DISPLAY 'CREACC: Performing account type check'
           PERFORM ACCOUNT-TYPE-CHECK

           DISPLAY 'CREACC: Account type check result='
                   COMM-SUCCESS OF DFHCOMMAREA

           IF COMM-SUCCESS OF DFHCOMMAREA = 'N'
              PERFORM GET-ME-OUT-OF-HERE
           END-IF


      *
      *    Having verified that the CUSTOMER exists we can now process
      *    the ACCOUNT information.  Enqueue the Named Counter for
      *    ACCOUNT.
      *
           DISPLAY 'CREACC: Enqueuing named counter'
           PERFORM ENQ-NAMED-COUNTER.

           DISPLAY 'CREACC: Named counter enqueued successfully'

      *
      *    Get the next ACCOUNT number from the ACCOUNT CONTROL Table
      *
           DISPLAY 'CREACC: Finding next account number'
           PERFORM FIND-NEXT-ACCOUNT.

           DISPLAY 'CREACC: Next account number=' ACCOUNT-NUMBER

           DISPLAY 'CREACC: Writing account to DB2'
           PERFORM WRITE-ACCOUNT-DB2

           DISPLAY 'CREACC: Account creation completed successfully'


           PERFORM GET-ME-OUT-OF-HERE.

       P999.
           EXIT.


       ENQ-NAMED-COUNTER SECTION.
       ENC010.

           MOVE SORTCODE TO NCS-ACC-NO-TEST-SORT.

           EXEC CICS ENQ
                RESOURCE(NCS-ACC-NO-NAME)
                LENGTH(16)
                RESP(WS-CICS-RESP)
                RESP2(WS-CICS-RESP2)
                END-EXEC.

           IF WS-CICS-RESP NOT = DFHRESP(NORMAL)
              MOVE 'N' TO COMM-SUCCESS IN DFHCOMMAREA
              MOVE '3' TO COMM-FAIL-CODE IN DFHCOMMAREA
              PERFORM GET-ME-OUT-OF-HERE
           END-IF.

       ENC999.
           EXIT.


       DEQ-NAMED-COUNTER SECTION.
       DNC010.

           MOVE SORTCODE TO NCS-ACC-NO-TEST-SORT.

           EXEC CICS DEQ
                RESOURCE(NCS-ACC-NO-NAME)
                LENGTH(16)
                RESP(WS-CICS-RESP)
                RESP2(WS-CICS-RESP2)
                END-EXEC.

           IF WS-CICS-RESP NOT = DFHRESP(NORMAL)
              MOVE 'N' TO COMM-SUCCESS IN DFHCOMMAREA
              MOVE '5' TO COMM-FAIL-CODE IN DFHCOMMAREA
              PERFORM GET-ME-OUT-OF-HERE
           END-IF.

       DNC999.
           EXIT.


       FIND-NEXT-ACCOUNT SECTION.
       FNA010.

           MOVE 1 TO NCS-ACC-NO-INC.

           INITIALIZE OUTPUT-DATA.

      * <<sortcode>>-ACCOUNT-LAST
           MOVE SPACES TO HV-CONTROL-NAME
           MOVE ZERO TO HV-CONTROL-VALUE-NUM
           MOVE SPACES TO HV-CONTROL-VALUE-STR
           STRING REQUIRED-SORT-CODE DELIMITED BY SIZE
                  '-' DELIMITED BY SIZE
                  'ACCOUNT-LAST' DELIMITED BY SIZE
              INTO HV-CONTROL-NAME

           DISPLAY 'CREACC: Selecting CONTROL for name='
                   HV-CONTROL-NAME

           EXEC SQL
              SELECT CONTROL_NAME,
                       CONTROL_VALUE_NUM,
                       CONTROL_VALUE_STR
              INTO :HV-CONTROL-NAME,
                      :HV-CONTROL-VALUE-NUM,
                      :HV-CONTROL-VALUE-STR
              FROM CONTROL
              WHERE CONTROL_NAME = :HV-CONTROL-NAME
           END-EXEC.

           MOVE SQLCODE TO SQLCODE-DISPLAY
           DISPLAY 'CREACC: SELECT CONTROL SQLCODE=' SQLCODE-DISPLAY
           DISPLAY 'CREACC: HV-CONTROL-VALUE-NUM='
                   HV-CONTROL-VALUE-NUM

           IF SQLCODE IS NOT EQUAL TO ZERO

              MOVE SQLCODE TO SQLCODE-DISPLAY

      *
      *      Preserve the RESP and RESP2, then set up the
      *      standard ABEND info before getting the applid,
      *      date/time etc. and linking to the Abend Handler
      *      program.
      *
              INITIALIZE ABNDINFO-REC
              MOVE EIBRESP TO ABND-RESPCODE
              MOVE EIBRESP2 TO ABND-RESP2CODE
      *
      *      Get supplemental information
      *
              EXEC CICS ASSIGN APPLID(ABND-APPLID)
                   END-EXEC

              MOVE EIBTASKN TO ABND-TASKNO-KEY
              MOVE EIBTRNID TO ABND-TRANID

              PERFORM POPULATE-TIME-DATE2

              MOVE WS-ORIG-DATE TO ABND-DATE
              STRING WS-TIME-NOW-GRP-HH DELIMITED BY SIZE,
                     ':' DELIMITED BY SIZE,
                     WS-TIME-NOW-GRP-MM DELIMITED BY SIZE,
                     ':' DELIMITED BY SIZE,
                     WS-TIME-NOW-GRP-MM DELIMITED BY SIZE
                 INTO ABND-TIME
              END-STRING

              MOVE WS-U-TIME TO ABND-UTIME-KEY
              MOVE 'HNCS' TO ABND-CODE

              EXEC CICS ASSIGN PROGRAM(ABND-PROGRAM)
                   END-EXEC

              MOVE SQLCODE-DISPLAY TO ABND-SQLCODE

              STRING 'FNAND010 - ACCOUNT NCS '
                 DELIMITED BY SIZE,
                     NCS-ACC-NO-NAME DELIMITED BY SIZE,
                     ' Cannot be accessed and DB2 SELECT failed.'
                 DELIMITED BY SIZE,
                     ' EIBRESP=' DELIMITED BY SIZE,
                     ABND-RESPCODE DELIMITED BY SIZE,
                     ' RESP2=' DELIMITED BY SIZE,
                     ABND-RESP2CODE DELIMITED BY SIZE
                 INTO ABND-FREEFORM
              END-STRING

              EXEC CICS LINK PROGRAM(WS-ABEND-PGM)
                   COMMAREA(ABNDINFO-REC)
                   END-EXEC


              DISPLAY 'CREACC - ACCOUNT NCS '
                      NCS-ACC-NO-NAME

                 ' CANNOT BE ACCESSED AND DB2 SELECT FAILED. SQLCODE='
                      SQLCODE-DISPLAY

              EXEC CICS ABEND
                   ABCODE('HNCS')
                   NODUMP
                   END-EXEC
           ELSE
              DISPLAY 'CREACC: SELECT successful, current value='
                      HV-CONTROL-VALUE-NUM
              ADD 1 TO HV-CONTROL-VALUE-NUM GIVING
                 COMM-NUMBER
                 ACCOUNT-NUMBER
                 REQUIRED-ACCT-NUMBER3
                 NCS-ACC-NO-VALUE
                 HV-CONTROL-VALUE-NUM

              DISPLAY 'CREACC: New account number will be='
                      ACCOUNT-NUMBER
              DISPLAY 'CREACC: Updating CONTROL table'

             EXEC SQL
               UPDATE CONTROL
               SET CONTROL_VALUE_NUM = :HV-CONTROL-VALUE-NUM
               WHERE (CONTROL_NAME = :HV-CONTROL-NAME)
             END-EXEC

              MOVE SQLCODE TO SQLCODE-DISPLAY
              DISPLAY 'CREACC: UPDATE CONTROL SQLCODE='
                      SQLCODE-DISPLAY

              IF SQLCODE IS NOT EQUAL TO ZERO
                 MOVE SQLCODE TO SQLCODE-DISPLAY

      *
      *        Preserve the RESP and RESP2, then set up the
      *        standard ABEND info before getting the applid,
      *        date/time etc. and linking to the Abend Handler
      *        program.
      *
                 INITIALIZE ABNDINFO-REC
                 MOVE EIBRESP TO ABND-RESPCODE
                 MOVE EIBRESP2 TO ABND-RESP2CODE
      *
      *        Get supplemental information
      *
                 EXEC CICS ASSIGN APPLID(ABND-APPLID)
                      END-EXEC

                 MOVE EIBTASKN TO ABND-TASKNO-KEY
                 MOVE EIBTRNID TO ABND-TRANID

                 PERFORM POPULATE-TIME-DATE2

                 MOVE WS-ORIG-DATE TO ABND-DATE
                 STRING WS-TIME-NOW-GRP-HH DELIMITED BY SIZE,
                        ':' DELIMITED BY SIZE,
                        WS-TIME-NOW-GRP-MM DELIMITED BY SIZE,
                        ':' DELIMITED BY SIZE,
                        WS-TIME-NOW-GRP-MM DELIMITED BY SIZE
                    INTO ABND-TIME
                 END-STRING

                 MOVE WS-U-TIME TO ABND-UTIME-KEY
                 MOVE 'HNCS' TO ABND-CODE

                 EXEC CICS ASSIGN PROGRAM(ABND-PROGRAM)
                      END-EXEC

                 MOVE SQLCODE-DISPLAY TO ABND-SQLCODE

                 STRING 'FNAND010(2) - ACCOUNT NCS '
                    DELIMITED BY SIZE,
                        NCS-ACC-NO-NAME DELIMITED BY SIZE,
                        ' Cannot be accessed and DB2 UPDATE failed.'
                    DELIMITED BY SIZE,
                        ' EIBRESP=' DELIMITED BY SIZE,
                        ABND-RESPCODE DELIMITED BY SIZE,
                        ' RESP2=' DELIMITED BY SIZE,
                        ABND-RESP2CODE DELIMITED BY SIZE
                    INTO ABND-FREEFORM
                 END-STRING

                 EXEC CICS LINK PROGRAM(WS-ABEND-PGM)
                      COMMAREA(ABNDINFO-REC)
                      END-EXEC


                 DISPLAY 'CREACC - ACCOUNT NCS '
                         NCS-ACC-NO-NAME

                  ' CANNOT BE ACCESSED AND DB2 UPDATE FAILED. SQLCODE='
                         SQLCODE-DISPLAY

                 EXEC CICS ABEND
                      ABCODE('HNCS')
                      NODUMP
                      END-EXEC
              END-IF
           END-IF

           MOVE NCS-ACC-NO-VALUE TO
              COMM-NUMBER ACCOUNT-NUMBER REQUIRED-ACCT-NUMBER3.
           MOVE SPACES TO HV-CONTROL-NAME
           MOVE ZERO TO HV-CONTROL-VALUE-NUM
           MOVE SPACES TO HV-CONTROL-VALUE-STR
           STRING SORTCODE DELIMITED BY SIZE
                  '-' DELIMITED BY SIZE
                  'ACCOUNT-COUNT' DELIMITED BY SIZE
              INTO HV-CONTROL-NAME

           DISPLAY 'CREACC: Selecting ACCOUNT-COUNT for name='
                   HV-CONTROL-NAME

           EXEC SQL
              SELECT CONTROL_NAME,
                       CONTROL_VALUE_NUM,
                       CONTROL_VALUE_STR
              INTO :HV-CONTROL-NAME,
                      :HV-CONTROL-VALUE-NUM,
                      :HV-CONTROL-VALUE-STR
              FROM CONTROL
              WHERE CONTROL_NAME = :HV-CONTROL-NAME
           END-EXEC.

           MOVE SQLCODE TO SQLCODE-DISPLAY
           DISPLAY 'CREACC: SELECT ACCOUNT-COUNT SQLCODE='
                   SQLCODE-DISPLAY

           IF SQLCODE IS NOT EQUAL TO ZERO
              MOVE SQLCODE TO SQLCODE-DISPLAY

      *
      *      Preserve the RESP and RESP2, then set up the
      *      standard ABEND info before getting the applid,
      *      date/time etc. and linking to the Abend Handler
      *      program.
      *
              INITIALIZE ABNDINFO-REC
              MOVE EIBRESP TO ABND-RESPCODE
              MOVE EIBRESP2 TO ABND-RESP2CODE
      *
      *      Get supplemental information
      *
              EXEC CICS ASSIGN APPLID(ABND-APPLID)
                   END-EXEC

              MOVE EIBTASKN TO ABND-TASKNO-KEY
              MOVE EIBTRNID TO ABND-TRANID

              PERFORM POPULATE-TIME-DATE2

              MOVE WS-ORIG-DATE TO ABND-DATE
              STRING WS-TIME-NOW-GRP-HH DELIMITED BY SIZE,
                     ':' DELIMITED BY SIZE,
                     WS-TIME-NOW-GRP-MM DELIMITED BY SIZE,
                     ':' DELIMITED BY SIZE,
                     WS-TIME-NOW-GRP-MM DELIMITED BY SIZE
                 INTO ABND-TIME
              END-STRING

              MOVE WS-U-TIME TO ABND-UTIME-KEY
              MOVE 'HNCS' TO ABND-CODE

              EXEC CICS ASSIGN PROGRAM(ABND-PROGRAM)
                   END-EXEC

              MOVE SQLCODE-DISPLAY TO ABND-SQLCODE

              STRING 'FNAND010(3) - ACCOUNT NCS '
                 DELIMITED BY SIZE,
                     NCS-ACC-NO-NAME DELIMITED BY SIZE,
                     ' Cannot be accessed and DB2 SELECT failed.'
                 DELIMITED BY SIZE,
                     ' EIBRESP=' DELIMITED BY SIZE,
                     ABND-RESPCODE DELIMITED BY SIZE,
                     ' RESP2=' DELIMITED BY SIZE,
                     ABND-RESP2CODE DELIMITED BY SIZE
                 INTO ABND-FREEFORM
              END-STRING

              EXEC CICS LINK PROGRAM(WS-ABEND-PGM)
                   COMMAREA(ABNDINFO-REC)
                   END-EXEC


              DISPLAY 'CREACC - ACCOUNT NCS '
                      NCS-ACC-NO-NAME

                 ' CANNOT BE ACCESSED AND DB2 SELECT FAILED. SQLCODE='
                      SQLCODE-DISPLAY

              EXEC CICS ABEND
                   ABCODE('HNCS')
                   NODUMP
                   END-EXEC
           ELSE
              DISPLAY 'CREACC: ACCOUNT-COUNT current value='
                      HV-CONTROL-VALUE-NUM
              ADD 1 TO HV-CONTROL-VALUE-NUM GIVING
                 HV-CONTROL-VALUE-NUM

              DISPLAY 'CREACC: Updating ACCOUNT-COUNT to='
                      HV-CONTROL-VALUE-NUM

             EXEC SQL
               UPDATE CONTROL
               SET CONTROL_VALUE_NUM = :HV-CONTROL-VALUE-NUM
               WHERE (CONTROL_NAME = :HV-CONTROL-NAME)
             END-EXEC

              MOVE SQLCODE TO SQLCODE-DISPLAY
              DISPLAY 'CREACC: UPDATE ACCOUNT-COUNT SQLCODE='
                      SQLCODE-DISPLAY

              IF SQLCODE IS NOT EQUAL TO ZERO
                 MOVE SQLCODE TO SQLCODE-DISPLAY

      *
      *        Preserve the RESP and RESP2, then set up the
      *        standard ABEND info before getting the applid,
      *        date/time etc. and linking to the Abend Handler
      *        program.
      *
                 INITIALIZE ABNDINFO-REC
                 MOVE EIBRESP TO ABND-RESPCODE
                 MOVE EIBRESP2 TO ABND-RESP2CODE
      *
      *        Get supplemental information
      *
                 EXEC CICS ASSIGN APPLID(ABND-APPLID)
                      END-EXEC

                 MOVE EIBTASKN TO ABND-TASKNO-KEY
                 MOVE EIBTRNID TO ABND-TRANID

                 PERFORM POPULATE-TIME-DATE2

                 MOVE WS-ORIG-DATE TO ABND-DATE
                 STRING WS-TIME-NOW-GRP-HH DELIMITED BY SIZE,
                        ':' DELIMITED BY SIZE,
                        WS-TIME-NOW-GRP-MM DELIMITED BY SIZE,
                        ':' DELIMITED BY SIZE,
                        WS-TIME-NOW-GRP-MM DELIMITED BY SIZE
                    INTO ABND-TIME
                 END-STRING

                 MOVE WS-U-TIME TO ABND-UTIME-KEY
                 MOVE 'HNCS' TO ABND-CODE

                 EXEC CICS ASSIGN PROGRAM(ABND-PROGRAM)
                      END-EXEC

                 MOVE SQLCODE-DISPLAY TO ABND-SQLCODE

                 STRING 'FNAND010(4) - ACCOUNT NCS '
                    DELIMITED BY SIZE,
                        NCS-ACC-NO-NAME DELIMITED BY SIZE,
                        ' Cannot be accessed and DB2 UPDATE failed.'
                    DELIMITED BY SIZE,
                        ' EIBRESP=' DELIMITED BY SIZE,
                        ABND-RESPCODE DELIMITED BY SIZE,
                        ' RESP2=' DELIMITED BY SIZE,
                        ABND-RESP2CODE DELIMITED BY SIZE
                    INTO ABND-FREEFORM
                 END-STRING

                 EXEC CICS LINK PROGRAM(WS-ABEND-PGM)
                      COMMAREA(ABNDINFO-REC)
                      END-EXEC


                 DISPLAY 'CREACC - ACCOUNT NCS '
                         NCS-ACC-NO-NAME

                  ' CANNOT BE ACCESSED AND DB2 UPDATE FAILED. SQLCODE='
                         SQLCODE-DISPLAY

                 EXEC CICS ABEND
                      ABCODE('HNCS')
                      NODUMP
                      END-EXEC
              END-IF
           END-IF.

       FNA999.
           EXIT.


      *
      * Write the DB2 ACCOUNT table
      *
       WRITE-ACCOUNT-DB2 SECTION.
       WAD010.

           INITIALIZE HOST-ACCOUNT-ROW.
           MOVE 'ACCT' TO HV-ACCOUNT-EYECATCHER.
           MOVE COMM-CUSTNO IN DFHCOMMAREA TO HV-ACCOUNT-CUST-NO.
           MOVE SORTCODE TO HV-ACCOUNT-SORTCODE.

           MOVE NCS-ACC-NO-VALUE TO NCS-ACC-NO-DISP.
           MOVE NCS-ACC-NO-DISP(9:8) TO HV-ACCOUNT-ACC-NO.
           MOVE COMM-ACC-TYPE IN DFHCOMMAREA TO HV-ACCOUNT-ACC-TYPE.
           MOVE COMM-INT-RT TO HV-ACCOUNT-INT-RATE.
           MOVE COMM-OVERDR-LIM TO HV-ACCOUNT-OVERDRAFT-LIM.
           MOVE COMM-AVAIL-BAL IN DFHCOMMAREA TO HV-ACCOUNT-AVAIL-BAL.
           MOVE COMM-ACT-BAL TO HV-ACCOUNT-ACTUAL-BAL.

           PERFORM CALCULATE-DATES.

      *
      *    Convert gregorian date (YYYYMMDD) to an integer
      *
           STRING WS-ORIG-DATE-YYYY DELIMITED BY SIZE,
                  WS-ORIG-DATE-MM DELIMITED BY SIZE,
                  WS-ORIG-DATE-DD DELIMITED BY SIZE
              INTO WS-STDT-X.

           MOVE WS-STDT-9-NUM TO WS-STDT-9-NUMERIC.

           COMPUTE WS-INTEGER =
              FUNCTION INTEGER-OF-DATE(WS-STDT-9-NUMERIC).

      *
      *    Add 30 days to the date
      *
           COMPUTE WS-INTEGER = WS-INTEGER + 30.

      *
      *    Convert integer date back to a Gregorian date (YYYYMMDD)
      *
           COMPUTE WS-FUTURE-DATE =
              FUNCTION DATE-OF-INTEGER(WS-INTEGER).

      *
      *    Store the answer back in the  Next Statement Date
      *
           MOVE WS-FUTURE-DATE TO WS-FUT-9.
           MOVE WS-FUT-X-YY TO HV-ACCOUNT-NEXT-STMT-YEAR.
           MOVE '.' TO HV-ACCOUNT-NEXT-STMT-DELIM2.
           MOVE WS-FUT-X-MM TO HV-ACCOUNT-NEXT-STMT-MONTH.
           MOVE '.' TO HV-ACCOUNT-NEXT-STMT-DELIM1.
           MOVE WS-FUT-X-DD TO HV-ACCOUNT-NEXT-STMT-DAY.

           EXEC SQL
              INSERT INTO ACCOUNT
                     (ACCOUNT_EYECATCHER,
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
                      )
              VALUES(:HV-ACCOUNT-EYECATCHER,
                      :HV-ACCOUNT-CUST-NO,
                      :HV-ACCOUNT-SORTCODE,
                      :HV-ACCOUNT-ACC-NO,
                      :HV-ACCOUNT-ACC-TYPE,
                      :HV-ACCOUNT-INT-RATE,
                      :HV-ACCOUNT-OPENED,
                      :HV-ACCOUNT-OVERDRAFT-LIM,
                      :HV-ACCOUNT-LAST-STMT,
                      :HV-ACCOUNT-NEXT-STMT,
                      :HV-ACCOUNT-AVAIL-BAL,
                      :HV-ACCOUNT-ACTUAL-BAL
                     )
           END-EXEC.

      *
      *    Check if the INSERT was unsuccessful and take action.
      *
           IF SQLCODE NOT = 0
              MOVE SQLCODE TO SQLCODE-DISPLAY
              MOVE 'N' TO COMM-SUCCESS IN DFHCOMMAREA
              MOVE '7' TO COMM-FAIL-CODE IN DFHCOMMAREA
              PERFORM DEQ-NAMED-COUNTER
              MOVE SQLCODE TO SQLCODE-DISPLAY

              PERFORM GET-ME-OUT-OF-HERE
           END-IF.

      *
      *    If the INSERT was successful the WRITE to PROCTRAN datastore
      *
           MOVE HV-ACCOUNT-SORTCODE TO STORED-SORTCODE.
           MOVE HV-ACCOUNT-ACC-NO TO STORED-ACCNO.
           MOVE HV-ACCOUNT-CUST-NO TO STORED-CUSTNO.
           MOVE HV-ACCOUNT-ACC-TYPE TO STORED-ACCTYPE.
           MOVE HV-ACCOUNT-LAST-STMT(1:2) TO STORED-LST-STMT(1:2).
           MOVE HV-ACCOUNT-LAST-STMT(4:2) TO STORED-LST-STMT(3:2).
           MOVE HV-ACCOUNT-LAST-STMT(7:4) TO STORED-LST-STMT(5:4).
           MOVE HV-ACCOUNT-NEXT-STMT(1:2) TO STORED-NXT-STMT(1:2).
           MOVE HV-ACCOUNT-NEXT-STMT(4:2) TO STORED-NXT-STMT(3:2).
           MOVE HV-ACCOUNT-NEXT-STMT(7:4) TO STORED-NXT-STMT(5:4).

           PERFORM WRITE-PROCTRAN.

           PERFORM DEQ-NAMED-COUNTER.

      *
      *    Set up the missing data in the COMMAREA ready for return
      *
           MOVE HV-ACCOUNT-SORTCODE TO COMM-SORTCODE.
           MOVE HV-ACCOUNT-ACC-NO TO COMM-NUMBER.

           MOVE HV-ACCOUNT-OPENED-DAY(1:2)
              TO COMM-OPENED IN DFHCOMMAREA(1:2).
           MOVE HV-ACCOUNT-OPENED-MONTH(1:2)
              TO COMM-OPENED IN DFHCOMMAREA(3:2).
           MOVE HV-ACCOUNT-OPENED-YEAR(1:4)
              TO COMM-OPENED IN DFHCOMMAREA(5:4).
           MOVE HV-ACCOUNT-LAST-STMT-DAY(1:2)
              TO COMM-LAST-STMT-DT IN DFHCOMMAREA(1:2).
           MOVE HV-ACCOUNT-LAST-STMT-MONTH(1:2)
              TO COMM-LAST-STMT-DT IN DFHCOMMAREA(3:2).
           MOVE HV-ACCOUNT-LAST-STMT-YEAR(1:4)
              TO COMM-LAST-STMT-DT IN DFHCOMMAREA(5:4).
           MOVE HV-ACCOUNT-NEXT-STMT-DAY(1:2)
              TO COMM-NEXT-STMT-DT IN DFHCOMMAREA(1:2).
           MOVE HV-ACCOUNT-NEXT-STMT-MONTH(1:2)
              TO COMM-NEXT-STMT-DT IN DFHCOMMAREA(3:2).
           MOVE HV-ACCOUNT-NEXT-STMT-YEAR(1:4)
              TO COMM-NEXT-STMT-DT IN DFHCOMMAREA(5:4).

           MOVE 'ACCT' TO COMM-EYECATCHER.
           MOVE 'Y' TO COMM-SUCCESS IN DFHCOMMAREA.
           MOVE ' ' TO COMM-FAIL-CODE IN DFHCOMMAREA.

       WAD999.
           EXIT.


       WRITE-PROCTRAN SECTION.
       WP010.

           PERFORM WRITE-PROCTRAN-DB2.
       WP999.
           EXIT.


       WRITE-PROCTRAN-DB2 SECTION.
       WPD010.
      *
      *    Write the successfully processed transaction to the PROCTRAN
      *    table.
      *
           INITIALIZE HOST-PROCTRAN-ROW.
           INITIALIZE WS-EIBTASKN12.

           MOVE 'PRTR' TO HV-PROCTRAN-EYECATCHER.
           MOVE SORTCODE TO HV-PROCTRAN-SORT-CODE.
           MOVE STORED-ACCNO TO HV-PROCTRAN-ACC-NUMBER.
           MOVE EIBTASKN TO WS-EIBTASKN12.
           MOVE WS-EIBTASKN12 TO HV-PROCTRAN-REF.

      *
      *    Populate the time and date
      *
           EXEC CICS ASKTIME
                ABSTIME(WS-U-TIME)
                END-EXEC.

           EXEC CICS FORMATTIME
                ABSTIME(WS-U-TIME)
                DDMMYYYY(WS-ORIG-DATE)
                TIME(HV-PROCTRAN-TIME)
                DATESEP('.')
                END-EXEC.

           MOVE WS-ORIG-DATE TO WS-ORIG-DATE-GRP-X.
           MOVE WS-ORIG-DATE-GRP-X TO HV-PROCTRAN-DATE.

           MOVE STORED-CUSTNO TO HV-PROCTRAN-DESC(1:10).
           MOVE STORED-ACCTYPE TO HV-PROCTRAN-DESC(11:8).
           MOVE STORED-LST-STMT TO HV-PROCTRAN-DESC(19:8).
           MOVE STORED-NXT-STMT TO HV-PROCTRAN-DESC(27:8).
           MOVE SPACES TO HV-PROCTRAN-DESC(35:6).

           MOVE 'OCA' TO HV-PROCTRAN-TYPE.
           MOVE 0 TO HV-PROCTRAN-AMOUNT.

           EXEC SQL
              INSERT INTO PROCTRAN
                     (
                      PROCTRAN_EYECATCHER,
                      PROCTRAN_SORTCODE,
                      PROCTRAN_NUMBER,
                      PROCTRAN_DATE,
                      PROCTRAN_TIME,
                      PROCTRAN_REF,
                      PROCTRAN_TYPE,
                      PROCTRAN_DESC,
                      PROCTRAN_AMOUNT
                     )
              VALUES
                     (
                      :HV-PROCTRAN-EYECATCHER,
                      :HV-PROCTRAN-SORT-CODE,
                      :HV-PROCTRAN-ACC-NUMBER,
                      :HV-PROCTRAN-DATE,
                      :HV-PROCTRAN-TIME,
                      :HV-PROCTRAN-REF,
                      :HV-PROCTRAN-TYPE,
                      :HV-PROCTRAN-DESC,
                      :HV-PROCTRAN-AMOUNT
                     )
           END-EXEC.

      *
      *    Check the SQLCODE
      *
           IF SQLCODE NOT = 0
              DISPLAY 'In CREACC (WPD010) '
                      'UNABLE TO WRITE TO PROCTRAN ROW DATASTORE'
                      ' RESP CODE='
                      WS-CICS-RESP,
                      ' RESP2='
                      WS-CICS-RESP2
                      'WITH THE FOLLOWING DATA:'
                      HOST-PROCTRAN-ROW


              PERFORM DEQ-NAMED-COUNTER
              MOVE SQLCODE TO SQLCODE-DISPLAY

      *
      *       Preserve the RESP and RESP2, then set up the
      *       standard ABEND info before getting the applid,
      *       date/time etc. and linking to the Abend Handler
      *       program.
      *
              INITIALIZE ABNDINFO-REC
              MOVE EIBRESP TO ABND-RESPCODE
              MOVE EIBRESP2 TO ABND-RESP2CODE
      *
      *       Get supplemental information
      *
              EXEC CICS ASSIGN APPLID(ABND-APPLID)
                   END-EXEC

              MOVE EIBTASKN TO ABND-TASKNO-KEY
              MOVE EIBTRNID TO ABND-TRANID

              PERFORM POPULATE-TIME-DATE2

              MOVE WS-ORIG-DATE TO ABND-DATE
              STRING WS-TIME-NOW-GRP-HH DELIMITED BY SIZE,
                     ':' DELIMITED BY SIZE,
                     WS-TIME-NOW-GRP-MM DELIMITED BY SIZE,
                     ':' DELIMITED BY SIZE,
                     WS-TIME-NOW-GRP-MM DELIMITED BY SIZE
                 INTO ABND-TIME
              END-STRING

              MOVE WS-U-TIME TO ABND-UTIME-KEY
              MOVE 'HWPT' TO ABND-CODE

              EXEC CICS ASSIGN PROGRAM(ABND-PROGRAM)
                   END-EXEC

              MOVE SQLCODE-DISPLAY TO ABND-SQLCODE

              STRING 'WPD010  - PROCTRAN DB2 INSERT issue.'
                 DELIMITED BY SIZE,
                     ' EIBRESP=' DELIMITED BY SIZE,
                     ABND-RESPCODE DELIMITED BY SIZE,
                     ' RESP2=' DELIMITED BY SIZE,
                     ABND-RESP2CODE DELIMITED BY SIZE
                 INTO ABND-FREEFORM
              END-STRING

              EXEC CICS LINK PROGRAM(WS-ABEND-PGM)
                   COMMAREA(ABNDINFO-REC)
                   END-EXEC

              EXEC CICS ABEND
                   ABCODE('HWPT')
                   END-EXEC
           END-IF.

       WPD999.
           EXIT.


       GET-ME-OUT-OF-HERE SECTION.
       GMOFH010.
      *
      *    Finish
      *
           EXEC CICS RETURN
                END-EXEC.

       GMOFH999.
           EXIT.


       CUSTOMER-ACCOUNT-COUNT SECTION.
       CAC010.
           MOVE 20 TO NUMBER-OF-ACCOUNTS IN INQACCCU-COMMAREA.
           MOVE COMM-CUSTNO IN DFHCOMMAREA
              TO CUSTOMER-NUMBER IN INQACCCU-COMMAREA.

           SET COMM-PCB-POINTER TO NULL

           EXEC CICS LINK PROGRAM('INQACCCU')
                COMMAREA(INQACCCU-COMMAREA)
                RESP(WS-CICS-RESP)
                SYNCONRETURN
                END-EXEC.

       CAC999.
           EXIT.


       CALCULATE-DATES SECTION.
       CD010.
      *
      *    Store today's date as the ACCOUNT-OPENED date and calculate
      *    the LAST-STMT-DATE (which should be today) and the
      *    NEXT-STMT-DATE (which should be today + 30 days).
      *

      *
      *    Populate the time and date
      *
           EXEC CICS ASKTIME
                ABSTIME(WS-U-TIME)
                END-EXEC.

           EXEC CICS FORMATTIME
                ABSTIME(WS-U-TIME)
                DDMMYYYY(WS-ORIG-DATE)
                TIME(PROC-TRAN-TIME OF PROCTRAN-AREA)
                DATESEP
                END-EXEC.

      *
      *    Convert gregorian date (YYYYMMDD) to an integer
      *

           STRING WS-ORIG-DATE-YYYY DELIMITED BY SIZE,
                  WS-ORIG-DATE-MM DELIMITED BY SIZE,
                  WS-ORIG-DATE-DD DELIMITED BY SIZE
              INTO WS-STDT-X.

           MOVE WS-STDT-9-NUM TO WS-STDT-9-NUMERIC.

           COMPUTE WS-INTEGER =
              FUNCTION INTEGER-OF-DATE(WS-STDT-9-NUMERIC).

      *
      *    Add 30 days to the date
      *
           EVALUATE WS-ORIG-DATE-MM
           WHEN 1
           WHEN 3
           WHEN 5
           WHEN 7
           WHEN 8
           WHEN 10
           WHEN 12
                COMPUTE WS-INTEGER = WS-INTEGER + 30
           WHEN 9
           WHEN 4
           WHEN 6
           WHEN 11
                COMPUTE WS-INTEGER = WS-INTEGER + 30
           WHEN 2
                COMPUTE WS-INTEGER = WS-INTEGER + 28
                DIVIDE WS-ORIG-DATE-YYYY BY 4 GIVING DONT-CARE
                   REMAINDER LEAP-YEAR

                IF LEAP-YEAR = ZERO
                   DIVIDE WS-ORIG-DATE-YYYY BY 100 GIVING DONT-CARE
                      REMAINDER LEAP-YEAR

                   IF LEAP-YEAR > 0
                      ADD 1 TO WS-INTEGER GIVING WS-INTEGER
                   ELSE
                      DIVIDE WS-ORIG-DATE-YYYY BY 400 GIVING DONT-CARE
                         REMAINDER LEAP-YEAR
                      IF LEAP-YEAR = ZERO
                         ADD 1 TO WS-INTEGER GIVING WS-INTEGER
                      END-IF
                   END-IF
                END-IF

           END-EVALUATE.


      *
      *    Convert integer date back to a Gregorian date (YYYYMMDD)
      *
           COMPUTE WS-FUTURE-DATE =
              FUNCTION DATE-OF-INTEGER(WS-INTEGER).

      *
      *    Store the answer back in the Next Statement Date
      *

           MOVE WS-FUTURE-DATE(1:4) TO ACCOUNT-NEXT-STMT-DATE(5:4).
           MOVE WS-FUTURE-DATE(5:2) TO ACCOUNT-NEXT-STMT-DATE(3:2).
           MOVE WS-FUTURE-DATE(7:2) TO ACCOUNT-NEXT-STMT-DATE(1:2).

           MOVE WS-ORIG-DATE-DD TO ACCOUNT-OPENED(1:2).
           MOVE WS-ORIG-DATE-MM TO ACCOUNT-OPENED(3:2).
           MOVE WS-ORIG-DATE-YYYY TO ACCOUNT-OPENED(5:4).
           MOVE ACCOUNT-OPENED TO ACCOUNT-LAST-STMT-DATE.

           MOVE WS-ORIG-DATE-DD TO HV-ACCOUNT-OPENED-DAY.
           MOVE '.' TO HV-ACCOUNT-OPENED-DELIM1.
           MOVE WS-ORIG-DATE-MM TO HV-ACCOUNT-OPENED-MONTH.
           MOVE '.' TO HV-ACCOUNT-OPENED-DELIM2.
           MOVE WS-ORIG-DATE-YYYY TO HV-ACCOUNT-OPENED-YEAR.

           MOVE WS-ORIG-DATE-DD TO HV-ACCOUNT-LAST-STMT-DAY.
           MOVE '.' TO HV-ACCOUNT-LAST-STMT-DELIM1.
           MOVE WS-ORIG-DATE-MM TO HV-ACCOUNT-LAST-STMT-MONTH.
           MOVE '.' TO HV-ACCOUNT-LAST-STMT-DELIM2.
           MOVE WS-ORIG-DATE-YYYY TO HV-ACCOUNT-LAST-STMT-YEAR.

       CD999.
           EXIT.


       ACCOUNT-TYPE-CHECK SECTION.
       ATC010.
      *
      *    Validate that only ISA, MORTGAGE, SAVING, CURRENT and LOAN
      *    are the only account types available.
      *
           EVALUATE TRUE
           WHEN COMM-ACC-TYPE IN DFHCOMMAREA(1:3) = 'ISA'
           WHEN COMM-ACC-TYPE IN DFHCOMMAREA(1:8) = 'MORTGAGE'
           WHEN COMM-ACC-TYPE IN DFHCOMMAREA(1:6) = 'SAVING'
           WHEN COMM-ACC-TYPE IN DFHCOMMAREA(1:7) = 'CURRENT'
           WHEN COMM-ACC-TYPE IN DFHCOMMAREA(1:4) = 'LOAN'
                MOVE 'Y' TO COMM-SUCCESS OF DFHCOMMAREA
           WHEN OTHER
                MOVE 'N' TO COMM-SUCCESS OF DFHCOMMAREA
                MOVE 'A' TO COMM-FAIL-CODE IN DFHCOMMAREA
           END-EVALUATE.

       ATC999.
           EXIT.


       POPULATE-TIME-DATE2 SECTION.
       PTD2010.
      D    DISPLAY 'POPULATE-TIME-DATE2 SECTION'.

           EXEC CICS ASKTIME
                ABSTIME(WS-U-TIME)
                END-EXEC.

           EXEC CICS FORMATTIME
                ABSTIME(WS-U-TIME)
                DDMMYYYY(WS-ORIG-DATE)
                TIME(WS-TIME-NOW)
                DATESEP
                END-EXEC.

       PTD2999.
           EXIT.
