# Project Documentation Rules (Non-Obvious Only)

- `src/` contains z/OS application source — **not** a Node.js or JVM web app root
- `src/frontend/` is a **zero-dependency** vanilla JS app; there is no `node_modules`, no `npm install` needed, and `package.json` only defines a simple `node server.js` start script
- `src/api/` is a **Gradle project** for z/OS Connect, not a REST service you can run locally — it generates API artefacts for deployment to a z/OS Connect Liberty instance
- The CICS programs handle both DB2 persistence and BMS terminal maps; copybooks in `src/base/cics/copy/` ending in `DB2` (e.g. `CUSTDB2.cpy`) are DB2 DCLGEN-style includes
- CICS error handling is centralised: all programs call `ABNDPROC` on failure, which writes to a VSAM KSDS; the `ABNDINFO` copybook defines the record layout
- `WAZI.cpy` is intentionally empty — it is a placeholder copybook used during Wazi development
- Transaction routing (CICS vs IMS) happens at the **frontend** via `parseCustomerId()` — the backend API does not route; it calls the appropriate middleware based on the customer ID prefix passed by the UI
- IMS programs: `IBTRAN.cbl` is a 31-bit COBOL → 64-bit Java bridge (IMS JMP); all other IMS COBOL programs are standard DL/I batch using `CBLTDLI`
- `config.yaml` in `.setup/config/` is the single source of truth for all port numbers, HLQs, and z/OS tool paths; it is rendered into `setenv.sh` by the setup scripts
- Integration tests in `tests/` require a live deployed z/OS environment — they cannot run in a CI/CD pipeline without z/OS connectivity
