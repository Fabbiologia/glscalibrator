# glscalibrator 0.2.1

## Bug fix: `.deg` files are wet/dry immersion, not temperature

A Migrate Technology `.deg` file holds the **wet/dry immersion** record; sea
temperature lives in the `.sst` file. Version 0.2.0's `read_deg_file()` returned
column 2 as `Temp`, so an immersion channel could be silently mistaken for
temperature and fed to `deduce_sst()`.

* `read_deg_file()` now inspects the column header and returns whichever channel
  the file actually holds, setting a `"channel"` attribute. Three layouts are
  recognised:
  * `wets0-20` — count of 30-s samples wet per block (mode 6B loggers)
  * `duration` + `wet/dry` — run-length encoded wet/dry bouts
  * a genuine temperature column (`.tem` files)
* `read_gls()` routes a `.deg` file to the `wetdry` slot unless it really is a
  temperature channel, so the immersion stream is now available to downstream
  models instead of being lost.
* `deduce_sst()` no longer treats a wet/dry `.deg` as temperature; it fails with
  an explicit message pointing to the `.sst` file.

Verified against both layouts in a real archive: a `wets0-20` logger yielded
51,061 ten-minute bins and a `duration`/`wet/dry` logger 4,969 bins.

---

# glscalibrator 0.2.0

## Major feature: end-to-end, taxon-agnostic pipeline

Version 0.1.0 stopped at raw threshold positions (light-based latitude only),
which are dominated by latitude error. 0.2.0 adds a complete movement-model
pipeline that constrains latitude with the logger's own temperature, matched to
satellite SST, plus a movement/speed prior and a land mask — reconstructing
most-probable tracks with credible intervals via `probGLS`.

The pipeline is **configuration-driven and species-agnostic**: all biology lives
in a validated `probgls_config` object with general defaults, so the package
applies to any GLS deployment.

### New functions

* `read_gls()` — one reader for a deployment's light / temperature / wet-dry /
  SST channels. Migrate Technology (`.lux/.deg/.sst/.act`) implemented;
  BAS/Biotrack (`.lig/.tem`) via `GeoLight`. Helpers: `read_deg_file()`,
  `read_sst_file()`, `read_act_file()`.
* `deduce_sst()` — turn the temperature/wet-dry channels into the SST `sensor`
  input, flagging untrustworthy readings (`SST.remove`).
* `read_probgls_params()` — ingest a collaborator's parameter **spreadsheet**
  (Excel/CSV: one row per `prob_algorithm` argument, one column per study) into a
  validated config. Parses R-style cells (`c(-6,-2)`, `T`, `"ellipsoid"`), skips
  formulas/blanks so defaults survive, and repairs two common sheet slips —
  `tagging.location` given as (lat, lon), and `boundary.box` given interleaved —
  using the deployment site as the decisive test. Suspect speed triples are
  warned about, never silently altered. Example sheet in
  `inst/extdata/probgls_params_example.csv`.
* `probgls_config()`, `validate_probgls_config()`, `print.probgls_config()`,
  `read_probgls_config()`, `write_probgls_config()` — build/validate/persist the
  29-parameter `probGLS::prob_algorithm()` configuration. YAML template in
  `inst/extdata/probgls_config_template.yml`.
* `get_environmental_data()` — fetch NOAA OI SST v2.1 (and sea-ice) fields for a
  deployment's date span.
* `prepare_trn()` — bridge detected twilights to the GeoLight `trn` format.
* `run_probgls()` — version-safe wrapper around `prob_algorithm()` (passes only
  the arguments the installed version declares); `tidy_probgls_track()`.
* `run_gls_pipeline()` / `run_gls_pipeline_batch()` — single-deployment and
  batch orchestration from raw files to reconstructed tracks.
* `summarise_tracks()`, `plot_probgls_track()` — batch summaries and maps.

### Dependencies

* New optional (`Suggests`) dependencies used only by the new pipeline, with
  runtime guards so the core stays light: `probGLS` (via `Remotes:
  benjamin-merkel/probGLS`), `GeoLight`, `ncdf4`, `terra`, `sf`, `yaml`, `curl`.

### Compatibility

* Fully backward compatible. The 0.1.0 calibration workflow
  (`calibrate_gls_batch()` etc.) is unchanged; the pipeline is additive.

---

# glscalibrator 0.1.0

## Initial Release

* First public release of glscalibrator
* Implements fully automated GLS calibration workflow
* Auto-discovery of birds from directory structures
* Automatic calibration period detection
* Batch processing with single command
* Internal NOAA-based twilight calibration replaces archived TwGeos dependency
* Standardized output formats (GLSmergedata.csv)
* Automatic diagnostic plot generation
* Quality control metrics and validation
* Comprehensive documentation and vignettes
* Unit tests for core functions
