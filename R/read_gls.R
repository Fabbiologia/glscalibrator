#' Read a raw GLS logger deployment (light, temperature, wet/dry)
#'
#' A single entry point that reads the raw channels a light-level geologger
#' records, returning them in the tidy shapes the rest of the pipeline expects.
#' The light channel feeds twilight detection and calibration; the temperature
#' and wet/dry channels feed \code{\link{deduce_sst}} and the activity input of
#' the particle model.
#'
#' Format is auto-detected from the file extensions present in \code{path}:
#' \describe{
#'   \item{\code{"migrate"}}{Migrate Technology Intigeo: \code{.lux} (light),
#'     \code{.sst} (immersion sea temperature), \code{.act} and/or \code{.deg}
#'     (wet/dry immersion). NOTE: a \code{.deg} file usually holds WET/DRY, not
#'     temperature; it is routed to \code{wetdry} unless it really is a
#'     temperature channel. See \code{\link{read_deg_file}}.}
#'   \item{\code{"bas"}}{British Antarctic Survey / Biotrack: \code{.lig}
#'     (light), \code{.tem} (temperature). Requires \code{GeoLight}.}
#' }
#' The reader contract is deliberately simple, so new formats can be added by
#' returning the same list structure.
#'
#' @param path A directory containing one deployment's files, or the path to a
#'   single light file (its siblings are discovered automatically).
#' @param type One of \code{"auto"}, \code{"migrate"}, \code{"bas"}.
#' @param id Optional deployment/individual id; defaults to the light file stem.
#'
#' @return A list of class \code{"gls_deployment"} with elements:
#'   \item{id}{deployment id}
#'   \item{light}{data.frame(Date, Light)}
#'   \item{temperature}{data.frame(Date, Temp) or NULL}
#'   \item{wetdry}{data.frame(Date, wet) or NULL}
#'   \item{sst_raw}{data.frame(Date, SST) if the logger stored SST, else NULL}
#'   \item{files}{named paths that were read}
#'
#' @seealso \code{\link{read_lux_file}}, \code{\link{deduce_sst}},
#'   \code{\link{run_gls_pipeline}}
#' @examples
#' \dontrun{
#' dep <- read_gls("birds/BW148")
#' str(dep$light)
#' }
#' @export
read_gls <- function(path, type = c("auto", "migrate", "bas"), id = NULL) {
  type <- match.arg(type)

  # resolve a directory of files vs a single light file
  if (dir.exists(path)) {
    dir_files <- list.files(path, full.names = TRUE)
  } else if (file.exists(path)) {
    dir_files <- list.files(dirname(path), full.names = TRUE)
  } else {
    stop("Path does not exist: ", path)
  }

  ext <- tolower(tools::file_ext(dir_files))
  pick <- function(e) dir_files[ext %in% e][1]

  if (type == "auto") {
    type <- if (any(ext == "lux")) "migrate" else if (any(ext == "lig")) "bas"
            else stop("Could not auto-detect logger type in: ", path,
                      " (no .lux or .lig found).")
  }

  if (type == "migrate") {
    lux <- pick("lux"); if (is.na(lux)) stop("No .lux light file found in ", path)
    if (is.null(id)) id <- tools::file_path_sans_ext(basename(lux))
    light <- read_lux_file(lux)
    degf  <- pick(c("deg", "tem"))
    degd  <- if (!is.na(degf)) read_deg_file(degf) else NULL
    # a .deg file usually carries WET/DRY, not temperature - route it correctly
    ch    <- if (!is.null(degd)) attr(degd, "channel") else NA_character_
    temp  <- if (identical(ch, "temperature")) degd else NULL
    wet   <- if (!is.na(pick("act"))) read_act_file(pick("act"))
             else if (!is.null(degd) && ch %in% c("wet_count", "wet_bout")) degd
             else NULL
    sst   <- if (!is.na(pick("sst"))) read_sst_file(pick("sst")) else NULL
    files <- c(light = lux, temperature = pick(c("deg", "tem")),
               wetdry = pick("act"), sst = pick("sst"))
  } else if (type == "bas") {
    if (!requireNamespace("GeoLight", quietly = TRUE))
      stop("Reading BAS/Biotrack '.lig' files requires the 'GeoLight' package.")
    lig <- pick("lig"); if (is.na(lig)) stop("No .lig light file found in ", path)
    if (is.null(id)) id <- tools::file_path_sans_ext(basename(lig))
    ld    <- GeoLight::ligTrans(lig)
    light <- data.frame(Date = ld$datetime, Light = ld$light)
    temp  <- if (!is.na(pick("tem"))) {
      td <- GeoLight::degTrans(pick("tem")); data.frame(Date = td$datetime, Temp = td$temp)
    } else NULL
    wet <- NULL; sst <- NULL
    files <- c(light = lig, temperature = pick("tem"))
  }

  out <- list(id = id, light = light, temperature = temp,
              wetdry = wet, sst_raw = sst, files = files)
  class(out) <- c("gls_deployment", "list")
  out
}

#' Read a Migrate Technology .deg / .tem file
#'
#' Despite the extension, a Migrate Technology \code{.deg} file usually holds
#' the WET/DRY IMMERSION record, not temperature - sea temperature lives in the
#' \code{.sst} file (see \code{\link{read_sst_file}}). This reader inspects the
#' column header and returns whichever channel the file actually contains, so a
#' wet/dry file is never silently mistaken for temperature.
#'
#' Three layouts are recognised:
#' \describe{
#'   \item{\code{wets0-20}}{count of 30-s samples wet per block (mode 6B)}
#'   \item{\code{duration} + \code{wet/dry}}{run-length encoded wet/dry bouts}
#'   \item{temperature}{a genuine temperature column (\code{.tem} files)}
#' }
#'
#' @param file_path Path to a \code{.deg} or \code{.tem} file.
#' @return A data.frame with column \code{Date} plus either \code{Temp}
#'   (degrees Celsius) or the immersion columns \code{wet_raw} and
#'   \code{channel}. The attribute \code{"channel"} is set to
#'   \code{"temperature"}, \code{"wet_count"} or \code{"wet_bout"}.
#' @export
read_deg_file <- function(file_path) {
  lines <- readLines(file_path, warn = FALSE)
  hdr <- grep("DD/MM/YYYY", lines)[1]
  if (is.na(hdr)) stop("Could not find data header in: ", file_path)
  d <- utils::read.delim(text = paste(lines[(hdr):length(lines)], collapse = "\n"),
                         sep = "\t", check.names = FALSE)
  nm <- tolower(names(d))
  Date <- as.POSIXct(d[[1]], format = "%d/%m/%Y %H:%M:%S", tz = "UTC")

  if (any(grepl("^wets", nm))) {
    j <- which(grepl("^wets", nm))[1]
    out <- data.frame(Date = Date,
                      wet_raw = suppressWarnings(as.numeric(d[[j]])),
                      channel = "wet_count", stringsAsFactors = FALSE)
    attr(out, "channel") <- "wet_count"
  } else if (any(nm == "wet/dry")) {
    out <- data.frame(Date = Date,
                      duration = suppressWarnings(as.numeric(d[[which(nm == "duration")]])),
                      wet_raw  = tolower(trimws(as.character(d[[which(nm == "wet/dry")]]))),
                      channel  = "wet_bout", stringsAsFactors = FALSE)
    attr(out, "channel") <- "wet_bout"
  } else {
    out <- data.frame(Date = Date,
                      Temp = suppressWarnings(as.numeric(d[[2]])),
                      stringsAsFactors = FALSE)
    attr(out, "channel") <- "temperature"
  }
  ch <- attr(out, "channel")
  out <- out[!is.na(out$Date), ]
  attr(out, "channel") <- ch
  out
}

#' Read a Migrate Technology immersion SST (.sst) file
#'
#' The \code{.sst} file stores wet min/max/mean temperature per interval; the
#' wet mean is the usable in-situ sea-surface temperature.
#'
#' @param file_path Path to a \code{.sst} file.
#' @param min_samples Minimum number of wet samples to keep a record (QC).
#' @return data.frame(Date, SST, n_samples).
#' @export
read_sst_file <- function(file_path, min_samples = 1) {
  lines <- readLines(file_path, warn = FALSE)
  hdr <- grep("DD/MM/YYYY", lines)[1]
  if (is.na(hdr)) stop("Could not find data header in: ", file_path)
  d <- utils::read.delim(text = paste(lines[(hdr):length(lines)], collapse = "\n"),
                         sep = "\t", check.names = FALSE)
  out <- data.frame(
    Date      = as.POSIXct(d[[1]], format = "%d/%m/%Y %H:%M:%S", tz = "UTC"),
    SST       = suppressWarnings(as.numeric(d[[4]])),   # wet mean 'C
    n_samples = suppressWarnings(as.numeric(d[[5]]))
  )
  out <- out[!is.na(out$Date) & !is.na(out$SST), ]
  out[out$n_samples >= min_samples, ]
}

#' Read a Migrate Technology wet/dry activity (.act) file
#'
#' @param file_path Path to a \code{.act} file.
#' @return data.frame(Date, wet) where \code{wet} is the conductivity count.
#' @export
read_act_file <- function(file_path) {
  lines <- readLines(file_path, warn = FALSE)
  hdr <- grep("DD/MM/YYYY", lines)[1]
  if (is.na(hdr)) stop("Could not find data header in: ", file_path)
  d <- utils::read.delim(text = paste(lines[(hdr):length(lines)], collapse = "\n"),
                         sep = "\t", check.names = FALSE)
  data.frame(
    Date = as.POSIXct(d[[1]], format = "%d/%m/%Y %H:%M:%S", tz = "UTC"),
    wet  = suppressWarnings(as.numeric(d[[2]]))
  ) -> out
  out[!is.na(out$Date), ]
}
