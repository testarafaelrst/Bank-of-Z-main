# Project Coding Rules (Non-Obvious Only)

- **Build runs on z/OS USS**, not locally — never attempt `dbb build` on a Mac/Linux workstation
- CICS COBOL programs: first two lines MUST be compiler directives (`PROCESS CICS,...` / `CBL CICS('SP,EDF')`) — the build auto-appends `CICS` to `compileParms` when `${IS_CICS}` is detected
- When adding embedded SQL to a COBOL program, add `CBL SQL` as a second compiler directive line; the build appends `SQL` to `compileParms` automatically
- New IMS COBOL batch programs need a custom `linkEditStream` in `dbb-app.yaml` with `INCLUDE RESLIB(CBLTDLI)` and `ENTRY DLITCBL` — see existing entries for `IBACSUM.cbl` etc.
- `IBTRAN.cbl` has a unique set of compile/link parms (`LP(32),JAVAIOP(JAVA64),DLL,RENT,PGMNAME(LONGMIXED)`) — do not apply standard parms to it
- Copybooks live in `src/base/cics/copy/` or `src/base/ims/copy/` — the dependency search path in `dbb-app.yaml` covers both; no manual path configuration needed
- IMS PSBs → `deployType: PSBLOAD`; DBDs → `deployType: DBDLOAD`; CICS programs → `deployType: CICSLOAD`; default is `LOAD`
- Condition name prefix rule in ZCodeScan is set to `TEST` (placeholder) — don't add `TEST`-prefixed 88-level entries; the rule fires on existing code and is informational only
- Frontend JS uses **ES module `import`/`export`** — never use CommonJS `require()` or a bundler
- `parseCustomerId()` in `src/frontend/js/utils.js` must strip the `C`/`I` prefix before passing to the API; the API endpoint only accepts numeric IDs
- IMS customer IDs at the API level must be exactly 9 digits (e.g. `000000015`), validated by `validateCustomerId()` in `utils.js`
- The IMS Java project (`src/base/ims/java/`) uses Java 21 toolchain and must produce `nazare-ims-jmp.jar`; the COBOL bridge `IBTRAN.cbl` references Java class `nazare.jmp.controller.InsertHist` — package name is fixed
- Secrets scan: `pre-commit` hook runs `detect-secrets`; run `detect-secrets audit .secrets.baseline` when adding new credential-like strings
