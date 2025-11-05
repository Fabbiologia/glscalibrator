# Example Data for glscalibrator

This directory contains example GLS data files for testing and demonstration purposes.

## Files

### Real Bird Data

#### `W086_24May17_215116.lux`
- **Species**: Seabird (tropical species)
- **Deployment**: Started April 12, 2016
- **Size**: ~203 KB
- **Duration**: ~34 twilights detected during deployment
- **Status**: Successfully calibrated
- **Location**: Colony at approximately 27.85°N, 115.17°W

A small, clean example of real GLS data showing clear day/night cycles.

#### `W592_24May17_211818.lux`
- **Species**: Seabird (tropical species)
- **Deployment**: Started May 24, 2017
- **Size**: ~877 KB
- **Duration**: ~126 twilights detected during deployment
- **Status**: Successfully calibrated
- **Location**: Colony at approximately 27.85°N, 115.17°W

A medium-sized example with longer deployment period.

### Synthetic Data

#### `synthetic_example.lux`
- **Type**: Synthetic/simulated data
- **Purpose**: Simple testing and demonstration
- **Colony**: 27.85°N, 115.17°W
- **Duration**: 2 days
- **Features**:
  - Clear day/night transitions
  - Idealized light curves
  - Minimal noise
  - Perfect for testing twilight detection algorithms

## Usage

### Basic Example

```r
library(glscalibrator)

# Read example data
light_data <- read_lux_file(
  system.file("extdata", "W086_24May17_215116.lux", package = "glscalibrator")
)

# Auto-detect calibration period
calib <- auto_detect_calibration(
  light_data,
  colony_lat = 27.85178,
  colony_lon = -115.17390
)

# Detect twilights
twilights <- detect_twilights(light_data, threshold = 2)
```

### Batch Processing Example

```r
# Process all example files
example_dir <- system.file("extdata", package = "glscalibrator")

results <- calibrate_gls_batch(
  data_dir = example_dir,
  output_dir = "test_output",
  colony_lat = 27.85178,
  colony_lon = -115.17390
)
```

### Test Individual Functions

```r
# Test with synthetic data
synthetic_file <- system.file("extdata", "synthetic_example.lux",
                             package = "glscalibrator")

light_data <- read_lux_file(synthetic_file)
twilights <- detect_twilights(light_data, threshold = 2)
twilights_clean <- filter_twilights(twilights, light_data, threshold = 2)

print(head(twilights_clean))
```

## Data Format

All .lux files follow the Migrate Technology Ltd logger format:

```
Header information (metadata)
...
DD/MM/YYYY HH:MM:SS	light(lux)
12/04/2016 16:55:26	364.513
12/04/2016 17:00:26	346.344
...
```

## Notes

- Real bird data (W086, W592) are from published research and can be shared for demonstration
- Synthetic data is generated for testing purposes only
- Colony coordinates are real but approximate
- Data has been validated and successfully processed with glscalibrator

## Data Sharing and Citation

If you use these example datasets:

**Real bird data**: These data are provided as examples for the glscalibrator package. For research use, please cite the package.

**Synthetic data**: Freely available for any purpose, no citation required.

## Privacy and Ethics

Real bird data has been:
- Approved for sharing by data owners
- Collected under appropriate permits
- De-identified where necessary
- Used in accordance with ethical guidelines

For questions about data use, contact: [favoretto.fabio@gmail.com]
