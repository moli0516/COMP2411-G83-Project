# Local repair-centre Web UI — additive patch

Copy webui/ into the COMP2411-Project root alongside queries/, operations/ and sql/. No existing SQL files are replaced. This is a local-development tool, not a production server.

## Start

python -m pip install -r webui/requirements.txt
python webui/server.py --user root --database comp2411_oscar_dev

Type the MySQL password in the terminal (never the browser). Open http://127.0.0.1:8080. Optional: --host 127.0.0.1 --port 3306 --web-port 8080. Password is kept in process memory only, not written to configuration files. Do not embed credentials in scripts or commit them. Stop with Ctrl-C. The app binds only 127.0.0.1 and does not enable debug/reloader/CORS. Do not expose it through a public tunnel or reverse proxy. Prefer a project-specific least-privilege database account over root once configured.

## Interface

- Queries: run local queries/Q01.sql through Q08.sql, one SELECT per file, inside a read-only transaction. Export displayed results as CSV with headers and SQL NULL as \N. Empty strings remain empty. Dates come from the SQL files. Downloads do not overwrite project evidence automatically.
- Operations: discovers only the named operations 01–12 from the earlier review package. Requires named Connector/Python placeholders and an initial validation SELECT ending AS ok. Comment-only placeholders and incompatible scripts are disabled with a reason.
- Preview: runs an eligible operation in a transaction and rolls it back. Auto-increment IDs can still be consumed. A successful preview gives a one-use, five-minute commit ticket tied to the operation, exact inputs and SQL content. Commit requires browser confirmation; the server revalidates and reruns against current data, rather than persisting the old preview transaction. IDs/results may differ. UI input changes invalidate the local ticket.
- Records: first 100 rows of an allowlisted project table, read-only.
- Connection: test actual server/account/database identity. 1045 still requires fixing MySQL authentication; the app does not reset root.

## Operation compatibility

The main-branch repository operations were placeholders when inspected. Installing this UI does not finish them. If you have installed and reviewed the previously supplied parameterized operation templates locally, those can be used. This patch intentionally does not replace the templates or claim every business rule is enforced. Local trusted developers must review all SQL; the SQL parser checks are not a sandbox for untrusted repository code. No arbitrary SQL, filesystem paths or database passwords are accepted through the browser. Do not run the app against an untrusted checkout.

## Validation and tests

The included test script checks SQL parsing/allowlists, host/CSRF rejection and commit-token rejection with a fake database; it does not connect to MySQL. Run: python -m unittest discover -s webui -p 'test_*.py'. Real MySQL testing is still required. Test authentication failure, each query output/CSV, intentional empty results, incompatible operations, validation rejection, rollback state and successful commit on disposable data. Do not label tests PASS until executed. Browser rendering and MySQL execution were not tested in the generation environment.

Export required baseline query evidence on a freshly built seed database before operation tests change records. This optional UI does not replace required SQL test scripts, CSV evidence or the live database demonstration.

## Design and assistance

Visual style adapted from the user's moli0516/COMP4423_A2 webui: #8c1d2f header, #f5f6f8 background, system font, white bordered cards, compact tables, primary/secondary controls, responsive forms and status messages. No model/image-classification code is copied. Record retained Perplexity assistance, affected files and your actual checks in ai_usage.md. This patch was drafted by AI and must be reviewed and understood by the group.
