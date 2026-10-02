# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Project Overview

Bank of Z is a mainframe banking demo that routes transactions via **CICS** or **IMS** based on customer ID prefix:
- `C<digits>` → CICS path (DB2 backend)
- `I<9 digits>` → IMS path (IMS DB/DC backend; must be exactly 9 digits)

## Stack

| Layer | Technology |
|-------|-----------|
| z/OS programs | COBOL (CICS + IMS + batch), PL/I (IMS + batch), HLASM (PSB/DBD) |
| API gateway | z/OS Connect (Liberty, Gradle plugin `com.ibm.zosconnect.gradle`) |
| Frontend | Vanilla JS / HTML — zero npm dependencies; served by separate Liberty instance |
| IMS bridge | Java 21 (Gradle), package `nazare.jmp`, compiled to `nazare-ims-jmp.jar` |
| Build | IBM DBB (`dbb-app.yaml`) + zBuilder (`dbb-build.yaml`) — runs **on z/OS USS**, not locally |
| Deploy | Wazi Deploy |
| Static analysis | ZCodeScan (rules in `zcodescan/zcodescan-rules.yaml`) |
| Secrets scan | detect-secrets pre-commit hook (`.pre-commit-config.yaml`) |

## Build Commands (run on z/OS USS, not locally)

```bash
# Full build (all languages + frontend + z/OS Connect)
$DBB_HOME/bin/dbb build full --hlq <HLQ>

# Single file build
$DBB_HOME/bin/dbb build file <path/to/file.cbl> --hlq <HLQ>

# User build (only src/base COBOL/PL/I/HLASM — no frontend/zOSConnect)
$DBB_HOME/bin/dbb build --hlq <HLQ> --errPrefix <prefix> --verbose
```

Local orchestration (runs scripts remotely via Zowe CLI):
```bash
bash .setup/setup-local.sh      # Initial z/OS environment setup
bash .setup/pipeline-local.sh   # Rebuild and redeploy
```

## Integration Tests

Tests are shell scripts that hit the live deployed API; they require a running z/OS environment:
```bash
# Run all tests
BASE_URL=http://<host>:9080/api FRONTEND_URL=http://<host>:9081 bash tests/run-all.sh

# Run a single test
BASE_URL=http://<host>:9080/api bash tests/test_get_customer_cics.sh

# Skip IMS tests
IMS_DISABLED=true bash tests/run-all.sh
```
Test scripts source `tests/test-setup.sh` which reads port values from `.setup/config/setenv.sh` (generated from `config.yaml`).

## Source Layout

```
src/base/cics/cobol/   CICS COBOL programs (.cbl)
src/base/cics/copy/    CICS copybooks (.cpy)
src/base/cics/bms/     BMS map sources (.bms)
src/base/ims/cobol/    IMS COBOL programs
src/base/ims/pli/      IMS PL/I programs
src/base/ims/PSB/      IMS PSBs (assembled → deployType PSBLOAD)
src/base/ims/DBD/      IMS DBDs (assembled → deployType DBDLOAD)
src/base/ims/java/     IMS JMP Java project (Gradle, Java 21)
src/base/batch/pli/    Batch PL/I (DB2, no IMS)
src/base/batch/jcl/    JCL for batch jobs
src/api/               z/OS Connect Gradle project (openapi.yaml → api.war)
src/frontend/          Vanilla JS frontend (no bundler, no framework)
```

## COBOL Code Style (observed patterns)

- First line is always a compiler directive: `PROCESS CICS,...` or `CBL CICS('SP,EDF')` / `CBL SQL`
- CICS programs use `RESP`/`RESP2` pattern (never `HANDLE CONDITION`) — enforced by ZCodeScan `CicsNoHandleRule`
- Abend handling centralised via `ABNDPROC` program; error info logged via `ABNDINFO` copybook
- `WS-` prefix for WORKING-STORAGE items; `88` level condition names use descriptive names without a mandated prefix
- Reentrant programs must be RENT; IMS COBOL batch programs require `ENTRY DLITCBL` link-edit card
- `IBTRAN.cbl` (IMS Java bridge) requires special compile parms: `LP(32),JAVAIOP(JAVA64),DLL,RENT,PGMNAME(LONGMIXED)`

## PL/I Code Style (observed patterns)

- IMS PL/I: first line is `*PROCESS SYSTEM(IMS);`; procedure declared with PCB pointers as parameters
- Batch PL/I: `EXEC SQL INCLUDE SQLCA;` at top; DB2 connection handled externally via JCL DSN RUN
- Constants declared as `DCL <name> CHAR(<n>) INIT('...')` — no `%DECLARE`

## Frontend (src/frontend)

- **No bundler, no transpiler, no npm packages** — pure ES modules loaded directly in browser
- API URL is computed at runtime in `config.js`: port 3001 → `/api` (Docker proxy), else `protocol//host:9080|9444/api`
- Customer IDs parsed by `parseCustomerId()` in `src/frontend/js/utils.js` — strips prefix before API call
- UI components are Carbon Web Components (`cds-modal`, etc.) loaded from the bundled `carbon-web-components.min.js`

## ZCodeScan Rules (non-default settings)

- `ConditionNamePrefixRule` expects prefix `TEST` (not the project's actual prefix — likely a placeholder)
- `InlinePerformLineLimitRule`: max 30 lines per inline PERFORM
- `ProcedureRule`: max 100 lines per paragraph
- `NestedIfLimitRule`: max 6 levels of nesting
- `SqlAvoidSelectStarRule` is HIGH severity — never use `SELECT *` in embedded SQL
