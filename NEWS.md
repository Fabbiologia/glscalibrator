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

## Key Features

* `calibrate_gls_batch()` - Main batch processing function
* `read_lux_file()` - Read and parse .lux files
* `detect_twilights()` - Threshold-crossing twilight detection
* `filter_twilights()` - Quality filtering of twilights
* `auto_detect_calibration()` - Automatic calibration period detection
* `convert_to_glsmerge()` - Standardize output format
* `plot_calibration()` - Generate calibration diagnostic plots
* `plot_track()` - Generate track maps

## Documentation

* Complete function documentation with examples
* "Getting Started" vignette with full workflow
* README with quick start guide
* JOSS paper describing methodology and use cases
