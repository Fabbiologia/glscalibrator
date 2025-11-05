# glscalibrator: Automated GLS Calibration and Analysis

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

An R package for fully automated calibration and analysis of Global Location Sensor (GLS) data from seabirds and other wildlife. `glscalibrator` streamlines the traditionally manual and time-consuming process of GLS data analysis by auto-discovering devices, detecting calibration periods, and batch processing multiple individuals.

## Key Features

- **Fully Automated Workflow**: Process entire datasets with a single command
- **Auto-Discovery**: Automatically finds all GLS devices in your directory structure
- **Intelligent Calibration**: Auto-detects calibration periods from the first days of deployment
- **Batch Processing**: Handles multiple individuals without manual intervention
- **Quality Control**: Automated hemisphere checks, twilight filtering, and diagnostic plots
- **Standardized Outputs**: Produces consistent data formats (GLSmergedata.csv) and visualizations
- **Built on Proven Methods**: Uses SGAT gamma calibration and threshold-crossing approaches

## Installation

```r
# Install from GitHub
# install.packages("devtools")
devtools::install_github("fabbiologia/glscalibrator")
```

## Quick Start

```r
library(glscalibrator)

# Process all GLS devices in a directory
results <- calibrate_gls_batch(
  data_dir = system.file("extdata", package = "glscalibrator"),
  output_dir = "data/processed/calibration",
  colony_lat = 27.85178,  # Colony latitude
  colony_lon = -115.17390  # Colony longitude
)

# Check summary
print(results$summary)

# Access individual bird results
bird_positions <- results$results$BW154_05Jul24_225805
```

## What It Does

Traditional GLS analysis requires:
1. Manual identification of each bird's data file
2. Manual selection of calibration period
3. Custom scripting for twilight detection
4. Individual processing of each bird
5. Manual creation of output formats and plots

`glscalibrator` automates all of this:

```r
# Traditional approach (hours of work)
# Read file → Find calibration dates → Detect twilights →
# Filter twilights → Calibrate → Calculate positions →
# Create plots → Repeat for each bird → Combine outputs

# glscalibrator approach (one command)
results <- calibrate_gls_batch(data_dir, output_dir, colony_lat, colony_lon)
```

## Output Structure

```
output_dir/
├── data/
│   ├── GLSmergedata.csv              # Combined data (standard format)
│   ├── all_birds_calibrated.csv     # Combined positions
│   ├── calibration_summary.csv      # Summary statistics
│   ├── BW154_calibrated.csv         # Individual bird data
│   └── BW154_GLSmergedata.csv       # Individual bird (standard format)
└── figures/
    ├── all_tracks_combined.png      # All tracks on one map
    ├── BW154_track.png              # Individual track
    └── BW154_calibration.png        # Calibration diagnostics
```

## Advanced Usage

### Excluding Equinox Periods

```r
# Define equinox exclusion periods
equinoxes <- list(
  c("2024-08-24", "2024-10-23"),  # Autumn equinox
  c("2024-02-19", "2024-04-19")   # Spring equinox
)

results <- calibrate_gls_batch(
  data_dir = "data/raw/birds",
  output_dir = "data/processed/calibration",
  colony_lat = 27.85,
  colony_lon = -115.17,
  exclude_equinoxes = equinoxes
)
```

### Processing Individual Birds

```r
# Read light data bundled with the package
light_data <- read_lux_file(gls_example("W086"))

# Auto-detect calibration period
calib <- auto_detect_calibration(
  light_data,
  colony_lat = 27.85,
  colony_lon = -115.17
)

# Detect twilights
twilights <- detect_twilights(light_data, threshold = 2)

# Filter twilights
twilights_clean <- filter_twilights(twilights, light_data, threshold = 2)
```

## Methodology

The package implements a proven workflow:

1. **Twilight Detection**: Threshold-crossing method (light > 2 lux = day)
2. **Auto-Calibration**: Searches first 1-5 days for stable period at colony
3. **SGAT Gamma Calibration**: Calculates sun elevation angle using `SGAT::thresholdCalibration()`
4. **Position Estimation**: Threshold method via `GeoLight::coord()`
5. **Quality Filtering**:
   - Removes twilights < 1 hour apart
   - Filters unusual intervals (not ~12 or ~24 hours)
   - Checks light quality around transitions
   - Validates hemisphere (Western vs Eastern)
   - Excludes equinox periods

## Bundled Example Data

`glscalibrator` ships with three `.lux` files in `inst/extdata/` that power the
documentation, tests, and vignettes. You can explore them programmatically:

```r
# List available example datasets and their metadata
glscalibrator_example_metadata

# Retrieve the path to a specific file
w086_path <- gls_example("W086")

# See summary information
list_gls_examples()
```

Use these datasets in tutorials, automated tests, or live demonstrations without
needing external files.

## Dependencies

- `GeoLight` – Position estimation from twilight times
- `TwGeos` – Gamma calibration implementation
- `dplyr` / `magrittr` / `lubridate` / `stringr` – Data manipulation utilities
- `maps` – Basemap rendering for diagnostic plots
- Base R packages `stats`, `graphics`, `grDevices`, `utils`

## Citation

If you use `glscalibrator` in your research, please cite.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Acknowledgments

Built on the excellent work of:
- `SGAT` package authors
- `GeoLight` and `TwGeos` developers
- The seabird tracking community

## Support

For issues and questions:
- GitHub Issues: https://github.com/fabbiologia/glscalibrator/issues
- Email: favoretto.fabio@gmail.com
