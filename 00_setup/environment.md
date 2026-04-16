# Environment Setup

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| Teradata Vantage | 17.20+ | VantageCloud Lake or on-prem |
| Python | 3.10+ | For data generation and loading |
| `teradataml` | 20.0+ | `pip install teradataml` |
| `pandas` | 2.0+ | |
| `faker` | 24.0+ | For synthetic data generation |
| BTEQ | 17.20+ | See installation instructions below |

## Installing BTEQ

BTEQ (Basic Teradata Query) is the command-line utility used to run all SQL deployment scripts in this repo. There are two ways to get it.

### Option 1 — Docker (recommended, no registration required)

The official Teradata Docker image is the simplest path, especially on macOS or Linux. It requires [Docker Desktop](https://www.docker.com/products/docker-desktop/) to be installed first.

**Pull and start the container:**

```bash
docker pull teradata/bteq
docker run -d -e "accept_license=Y" -it --name bteq teradata/bteq:latest
```

**Run a BTEQ script from your host machine:**

```bash
docker exec -i bteq bteq < logon.txt 00_setup/create_databases.sql
```

To use the `cat logon.txt <script>.sql | bteq` pattern shown in the Quick Start, wrap it as:

```bash
cat logon.txt 00_setup/create_databases.sql | docker exec -i bteq bteq
```

Or define a shell alias to make it transparent:

```bash
alias bteq="docker exec -i bteq bteq"
```

With the alias set, all Quick Start commands work exactly as written with no further changes.

**Stop/restart the container:**

```bash
docker stop bteq
docker start bteq
```

> By accepting the license (`accept_license=Y`) you confirm you have a valid Teradata Tools and Utilities licence. The full licence agreement is at https://downloads.teradata.com/download/license/download-agreement-teradata-tools-utilities.

---

### Option 2 — Teradata Tools and Utilities (TTU) native install

TTU includes BTEQ as a native executable alongside FastLoad, MultiLoad, and other client tools. A **free Teradata account** is required to download.

**Step 1 — Create a free account:**

Go to https://downloads.teradata.com and register. Approval is typically instant.

**Step 2 — Download TTU 20.00 for your platform:**

| Platform | Download page |
|----------|--------------|
| Windows | https://downloads.teradata.com/download/database/teradata-tools-and-utilities-13-10 |
| Linux (x86-64) | https://downloads.teradata.com/download/tools/teradata-tools-and-utilities-linux-installation-package-0 |
| macOS | https://downloads.teradata.com/download/tools/teradata-tools-and-utilities-mac-osx-installation-package |

**Step 3 — Install:**

- **Windows:** Run the `.exe` installer. BTEQ is added to `PATH` automatically.
- **Linux:** Extract the tarball and run the installer script:
  ```bash
  tar -xf TeradataToolsAndUtilitiesBase__linux_x8664.20.00.*.tar
  sudo ./setup.sh bteq
  ```
- **macOS:** Open the `.pkg` installer and follow the prompts.

**Step 4 — Verify installation:**

```bash
bteq
# Should print: Teradata BTEQ 20.xx.xx.xx ...
# Press Ctrl+C or type .QUIT to exit
```


## Teradata Connection

### logon.txt (BTEQ)

Create a file named `logon.txt` in the **repo root directory** (it is gitignored):

```
.LOGON your-vantage-host/your-username,your-password;
```

All BTEQ commands in this repo use the pattern:

```bash
cat logon.txt <script>.sql | bteq
```

This keeps credentials out of every SQL script so they stay portable and safe to commit.

### Python scripts

```bash
export TD_HOST=your-vantage-host
export TD_USER=your-username
export TD_PASSWORD=your-password
export TD_LOGMECH=TD2          # or LDAP, TDNEGO as appropriate
```

Alternatively, create a `.env` file in the repo root (it is gitignored):

```
TD_HOST=your-vantage-host
TD_USER=your-username
TD_PASSWORD=your-password
TD_LOGMECH=TD2
```

## Databases Required

The setup script creates these databases (all owned by the user running the scripts):

| Database | Purpose |
|----------|---------|
| `MortgagePlatform_Staging` | Raw source data — staging area |
| `MortgagePlatform_Memory` | Agent memory, documentation, ADRs |
| `MortgagePlatform_Semantic` | Discovery metadata, data product map |
| `MortgagePlatform_Domain` | Core business entities |
| `MortgagePlatform_Observability` | Change events, data quality, lineage, agent outcomes |

## Freddie Mac Data Download

The Origination and Monthly Performance files require a **free registration** at Freddie Mac:

1. Go to: https://www.freddiemac.com/research/datasets/sf-loanlevel-dataset
2. Register for access (free, usually approved same day)
3. Download **Sample Data** (not the full dataset — sample is ~50k loans, sufficient for demo)
4. Place the unzipped files in `01_source_data/raw/`:
   - `sample_orig_YYYY.txt` → rename to `freddie_origination.csv`
   - `sample_svcg_YYYY.txt` → rename to `freddie_performance.csv`

> **Note:** The Freddie Mac files are pipe-delimited (`|`) with no header row.
> The load scripts handle this automatically using the column order documented in
> `01_source_data/data_dictionary/freddie_mac_origination.md`.

## Synthetic Data

The borrower profile and property valuation files are **generated programmatically**
— no download required. Run the generator scripts after loading the Freddie Mac data,
as they use `LOAN_SEQUENCE_NUMBER` as a join key to ensure referential consistency.

```bash
python 01_source_data/load_scripts/03_generate_borrower_profile.py
python 01_source_data/load_scripts/04_generate_property_valuation.py
```

## Teardown

To fully reset the environment:

```bash
cat logon.txt 00_setup/teardown.sql | bteq
```

This drops all four databases. It is safe to re-run `create_databases.sql` and the
module scripts after teardown to rebuild from scratch.
