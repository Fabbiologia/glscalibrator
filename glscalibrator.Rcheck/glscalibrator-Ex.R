pkgname <- "glscalibrator"
source(file.path(R.home("share"), "R", "examples-header.R"))
options(warn = 1)
library('glscalibrator')

base::assign(".oldSearch", base::search(), pos = 'CheckExEnv')
base::assign(".old_wd", base::getwd(), pos = 'CheckExEnv')
cleanEx()
nameEx("auto_detect_calibration")
### * auto_detect_calibration

flush(stderr()); flush(stdout())

### Name: auto_detect_calibration
### Title: Automatically Detect Calibration Period
### Aliases: auto_detect_calibration

### ** Examples





cleanEx()
nameEx("calibrate_gls_batch")
### * calibrate_gls_batch

flush(stderr()); flush(stdout())

### Name: calibrate_gls_batch
### Title: Batch Calibration of Multiple GLS Devices
### Aliases: calibrate_gls_batch

### ** Examples

## Not run: 
##D # Basic usage
##D results <- calibrate_gls_batch(
##D   data_dir = "data/raw/birds",
##D   output_dir = "data/processed/calibration",
##D   colony_lat = 27.85178,
##D   colony_lon = -115.17390
##D )
##D 
##D # With equinox exclusions
##D equinoxes <- list(
##D   c("2024-08-24", "2024-10-23"),
##D   c("2024-02-19", "2024-04-19")
##D )
##D results <- calibrate_gls_batch(
##D   data_dir = "data/raw/birds",
##D   output_dir = "data/processed/calibration",
##D   colony_lat = 27.85,
##D   colony_lon = -115.17,
##D   exclude_equinoxes = equinoxes
##D )
## End(Not run)




cleanEx()
nameEx("detect_twilights")
### * detect_twilights

flush(stderr()); flush(stdout())

### Name: detect_twilights
### Title: Detect Twilight Times from Light Data
### Aliases: detect_twilights

### ** Examples

# Detect twilights from example data
example_file <- gls_example("W086")
light_data <- read_lux_file(example_file)
twilights <- detect_twilights(light_data, threshold = 2)
head(twilights)




cleanEx()
nameEx("filter_twilights")
### * filter_twilights

flush(stderr()); flush(stdout())

### Name: filter_twilights
### Title: Filter and Clean Twilight Data
### Aliases: filter_twilights

### ** Examples

# Filter twilights from example data
example_file <- gls_example("W086")
light_data <- read_lux_file(example_file)
twilights <- detect_twilights(light_data, threshold = 2)
twilights_clean <- filter_twilights(twilights, light_data, threshold = 2)
nrow(twilights_clean)




cleanEx()
nameEx("gls_example")
### * gls_example

flush(stderr()); flush(stdout())

### Name: gls_example
### Title: Get Path to Example Data
### Aliases: gls_example

### ** Examples

# Inspect available example datasets
list_gls_examples()

# Read the bundled W086 seabird deployment
light_data <- read_lux_file(gls_example("W086"))

# Run calibration on the synthetic dataset (quick demo)
synt_path <- gls_example("synthetic")
synthetic_data <- read_lux_file(synt_path)
twl <- detect_twilights(synthetic_data, threshold = 2)




cleanEx()
nameEx("list_gls_examples")
### * list_gls_examples

flush(stderr()); flush(stdout())

### Name: list_gls_examples
### Title: List Available Example Datasets
### Aliases: list_gls_examples

### ** Examples

list_gls_examples()




cleanEx()
nameEx("read_lux_file")
### * read_lux_file

flush(stderr()); flush(stdout())

### Name: read_lux_file
### Title: Read Light Data from .lux Files
### Aliases: read_lux_file

### ** Examples

# Read example data included with package
example_file <- gls_example("W086")
light_data <- read_lux_file(example_file)
head(light_data)




### * <FOOTER>
###
cleanEx()
options(digits = 7L)
base::cat("Time elapsed: ", proc.time() - base::get("ptime", pos = 'CheckExEnv'),"\n")
grDevices::dev.off()
###
### Local variables: ***
### mode: outline-minor ***
### outline-regexp: "\\(> \\)?### [*]+" ***
### End: ***
quit('no')
