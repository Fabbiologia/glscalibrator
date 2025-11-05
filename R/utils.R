# Suppress R CMD check notes about undefined global variables
# These are column names used in dplyr pipelines and data.frames

utils::globalVariables(c(
  # Column names from data processing
  ".", "Date", "Light", "Twilight", "Rise", "datetime",
  "Latitude", "Longitude", "date", "sun_elevation",

  # Intermediate variables in pipelines
  "time_since_last", "expected_interval", "light_quality",
  "tSecond",

  # GLSmerge format variables
  "Index", "ID", "sex", "sexn", "GLS", "First", "mese",
  "Quality_1", "Second", "Quality_2", "Type", "ElevAngle"
))
