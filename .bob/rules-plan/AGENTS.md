# Project Architecture Rules (Non-Obvious Only)

- **Transaction routing is UI-driven**: the frontend parses the customer ID prefix (`C` → CICS, `I` → IMS) and calls the appropriate backend endpoint — there is no server-side routing logic
- CICS and IMS share the same DB2 database for account/customer data; IMS additionally writes transaction history via the Java JMP (`nazare.jmp`) which is called by the COBOL bridge `IBTRAN.cbl` using 31→64-bit JNI
- z/OS Connect and the Frontend are **two separate Liberty instances** (`BAQ<SHORT>` on 9080/9444 and `FE<SHORT>` on 9081/9445) — CORS is explicitly configured on z/OS Connect to allow frontend origin
- DBB build has two build lifecycles: `full` (all languages + frontend + z/OS Connect) and `file` (single program, no frontend/zOSConnect tasks); user build (`user` lifecycle) only covers `src/base`
- Custom Groovy tasks (`VanillaFrontend`, `ServerXmlPackager`, `ImsJavaBuilder`) extend DBB — defined in `.setup/build/groovy/CustomTasks.yaml` (not in `dbb-app.yaml`); `dbb-app.yaml` only declares their variables
- IMS PSBs and DBDs are **assembled** (not compiled) and have separate deploy types (`PSBLOAD`, `DBDLOAD`); they must be regenerated via ACBGEN utility after any PSB/DBD change
- The `IBTRAN.cbl` IMS bridge is `RECURSIVE` and `DLL`-style — it cannot be placed in a standard batch load library; it must go to `IMSLOAD` with `DYNAM(DLL),CASE(MIXED)` link parms
- Adding a new CICS program: create `.cbl` in `src/base/cics/cobol/`, add a `COPY` of the relevant BMS copybook (`BNK1*DM.cpy`) — DBB picks it up automatically via the glob pattern `**/src/base/**/cobol/*.cbl`
- Adding a new IMS DL/I batch program: add `.cbl`, then add a `linkEditStream` entry in `dbb-app.yaml` with `CBLTDLI` include and `ENTRY DLITCBL`, and set `deployType: IMSLOAD`
- `config.yaml` uses Jinja2 template syntax (`{{ }}`) — it is rendered by the Python-based setup scripts on z/OS, not by any local tool; never edit generated files like `setenv.sh` directly
