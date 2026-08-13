#' Read a probGLS parameter sheet into a pipeline configuration
#'
#' Field teams often maintain movement-model settings in a shared spreadsheet:
#' one row per \code{probGLS::prob_algorithm()} argument, one column per study
#' or species. This reader ingests that sheet directly (Excel or CSV) and
#' returns a validated \code{\link{probgls_config}}, so expert-provided values
#' flow into the pipeline without hand-copying.
#'
#' The expected layout has a component-name column (e.g. "Nombre del
#' componente" / "parameter") holding the dotted \code{prob_algorithm} argument
#' names, and one or more value columns. Values may be written R-style
#' (\code{c(-6,-2)}, \code{TRUE}, \code{T}, \code{"ellipsoid"}, plain numbers).
#' Non-literal entries (formulas like \code{min(trn$tFirst)}, blanks, NaN) are
#' skipped, so the corresponding \code{\link{probgls_config}} defaults are kept.
#'
#' Two common spreadsheet slips are detected and repaired with a warning:
#' \itemize{
#'   \item \code{tagging.location} written as (lat, lon): if the second element
#'     cannot be a latitude (|value| > 90) the pair is swapped to (lon, lat).
#'   \item \code{boundary.box} in a non-canonical order (for example
#'     interleaved as (ymin, xmin, ymax, xmax)): the four numbers are re-split
#'     into a longitude pair and a latitude pair and rebuilt as
#'     c(xmin, xmax, ymin, ymax). Candidate splits are scored on validity and,
#'     decisively, on whether the resulting box contains the deployment site -
#'     a box that excludes its own colony is not the intended box.
#' }
#' A speed triple whose maximum is smaller than its optimum or standard
#' deviation triggers a warning (likely (optimal, sd, max) ordering mistake),
#' but the values are used as given.
#'
#' @param path Path to an \code{.xlsx} (requires \pkg{readxl}) or \code{.csv}
#'   parameter sheet.
#' @param value_col Value column to use: a name or index. Default \code{NULL}
#'   picks the first column that is not recognised as sheet metadata (order,
#'   component name, units, type, example, description) - i.e. the
#'   study/species column.
#' @param sheet Sheet name or index for Excel input (default first sheet).
#' @param base A \code{\link{probgls_config}} to override; defaults to
#'   \code{probgls_config()} general defaults.
#' @param quiet Logical; suppress the per-field ingestion messages.
#'
#' @return A validated (structurally) \code{\link{probgls_config}}. Runtime
#'   completeness (environment folder etc.) is checked later at
#'   \code{\link{run_probgls}} time.
#'
#' @examples
#' sheet <- system.file("extdata", "probgls_params_example.csv",
#'                      package = "glscalibrator")
#' cfg <- read_probgls_params(sheet)
#' cfg[["range.solar"]]
#'
#' @seealso \code{\link{probgls_config}}, \code{\link{read_probgls_config}}
#' @export
read_probgls_params <- function(path, value_col = NULL, sheet = 1,
                                base = probgls_config(), quiet = FALSE) {

  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("xlsx", "xls")) {
    if (!requireNamespace("readxl", quietly = TRUE))
      stop("Reading Excel sheets requires the 'readxl' package. install.packages('readxl').")
    tab <- as.data.frame(readxl::read_excel(path, sheet = sheet))
  } else if (ext == "csv") {
    tab <- utils::read.csv(path, check.names = FALSE)
  } else {
    stop("Unsupported file type: .", ext, " (use .xlsx or .csv).")
  }

  # --- locate the component-name column ---
  name_pat <- "componente|component|parameter|argumento|argument|^name$"
  ncol_i <- grep(name_pat, names(tab), ignore.case = TRUE)[1]
  if (is.na(ncol_i))
    stop("Could not find a component-name column (looked for: ", name_pat, ").")

  # --- locate the value column ---
  # metadata columns to skip when auto-picking the value column. Patterns are
  # deliberately specific ("ejemplo de valor", "example value") so a study
  # column such as "Study values (example: ...)" is not mistaken for metadata.
  meta_pat <- paste0(name_pat,
    "|^orden$|^order$|unidad|^unit|formato|^format|^tipo|^type",
    "|ejemplo de valor|example value|resumen|^summary|descri")
  if (is.null(value_col)) {
    cand <- setdiff(seq_along(tab), grep(meta_pat, names(tab), ignore.case = TRUE))
    if (!length(cand))
      stop("No value column found; pass `value_col` explicitly.")
    vcol_i <- cand[1]
  } else if (is.numeric(value_col)) {
    vcol_i <- as.integer(value_col)
  } else {
    vcol_i <- which(names(tab) == value_col)[1]
    if (is.na(vcol_i)) stop("Column not found: ", value_col)
  }
  if (!isTRUE(quiet))
    message("Reading parameter values from column: '", names(tab)[vcol_i], "'")

  cfg <- base
  known <- names(cfg)
  skipped <- character(0)

  for (i in seq_len(nrow(tab))) {
    key <- trimws(as.character(tab[[ncol_i]][i]))
    if (!nzchar(key) || is.na(key)) next
    if (!key %in% known) { skipped <- c(skipped, key); next }
    if (key %in% c("trn", "sensor", "act")) next            # run-time data, never from sheet

    val <- .parse_sheet_value(as.character(tab[[vcol_i]][i]))
    if (is.null(val)) next                                   # blank / formula -> keep default

    cfg[[key]] <- val
    if (!isTRUE(quiet))
      message("  ", key, " <- ", paste(format(val), collapse = ", "))
  }
  if (length(skipped) && !isTRUE(quiet))
    message("Ignored unknown component(s): ", paste(unique(skipped), collapse = ", "))

  cfg <- .normalise_coords(cfg)
  .warn_speed_order(cfg, "speed.dry")
  .warn_speed_order(cfg, "speed.wet")

  validate_probgls_config(cfg, require_runtime = FALSE)
  cfg
}

# parse one spreadsheet cell written R-style; NULL = not a usable literal
.parse_sheet_value <- function(x) {
  x <- trimws(x)
  # \u2013 is an en dash: sheets often use it to mean "not applicable"
  if (!nzchar(x) || x %in% c("NA", "NaN", "\u2013", "-")) return(NULL)

  # c(...) numeric vector
  if (grepl("^c\\(", x)) {
    inner <- sub("^c\\(", "", sub("\\)$", "", x))
    v <- suppressWarnings(as.numeric(strsplit(inner, ",")[[1]]))
    if (anyNA(v)) return(NULL)
    return(v)
  }
  # logicals (T / F / TRUE / FALSE, case-insensitive)
  if (toupper(x) %in% c("T", "TRUE"))  return(TRUE)
  if (toupper(x) %in% c("F", "FALSE")) return(FALSE)
  # quoted string
  if (grepl('^".*"$', x) || grepl("^'.*'$", x)) return(gsub('^["\']|["\']$', "", x))
  # plain number
  n <- suppressWarnings(as.numeric(x))
  if (!is.na(n)) return(n)
  # anything else (formulas, prose) is not a literal
  NULL
}

# repair (lat, lon) swaps and mixed-order boundary boxes, with warnings
.normalise_coords <- function(cfg) {
  tl <- cfg[["tagging.location"]]
  if (is.numeric(tl) && length(tl) == 2) {
    if (abs(tl[2]) > 90 && abs(tl[1]) <= 90) {
      warning("tagging.location looked like (lat, lon); swapped to (lon, lat): c(",
              tl[2], ", ", tl[1], ")", call. = FALSE)
      cfg[["tagging.location"]] <- c(tl[2], tl[1])
    }
  }
  bb <- cfg[["boundary.box"]]
  if (is.numeric(bb) && length(bb) == 4 && !anyNA(bb)) {
    fixed <- .infer_boundary_box(bb, cfg[["tagging.location"]])
    if (!isTRUE(all.equal(fixed, bb, check.attributes = FALSE))) {
      warning("boundary.box interpreted as c(xmin, xmax, ymin, ymax): c(",
              paste(fixed, collapse = ", "), ")", call. = FALSE)
      cfg[["boundary.box"]] <- fixed
    }
  }
  cfg
}

# Work out which two of the four numbers are longitudes and which are latitudes.
# Sheets vary: c(xmin,xmax,ymin,ymax), c(ymin,xmin,ymax,xmax) (interleaved), or
# other orders. Candidate splits are scored on validity, on containing the
# tagging location (the decisive test - a deployment must lie inside its own
# boundary box), and on requiring the least reordering.
.infer_boundary_box <- function(bb, tagging_location = NULL) {
  splits <- list(c(1, 2, 3, 4), c(1, 3, 2, 4), c(1, 4, 2, 3))
  best <- NULL; best_score <- -Inf

  for (si in seq_along(splits)) {
    idx <- splits[[si]]
    p1 <- bb[idx[1:2]]; p2 <- bb[idx[3:4]]
    for (swap in c(FALSE, TRUE)) {
      lon <- if (swap) p2 else p1
      lat <- if (swap) p1 else p2
      if (any(abs(lat) > 90) || any(abs(lon) > 180)) next   # impossible
      cand <- c(sort(lon), sort(lat))

      score <- 0
      if (any(abs(lon) > 90)) score <- score + 2            # unambiguous longitude
      if (!is.null(tagging_location) && length(tagging_location) == 2) {
        inside <- tagging_location[1] >= cand[1] && tagging_location[1] <= cand[2] &&
                  tagging_location[2] >= cand[3] && tagging_location[2] <= cand[4]
        if (inside) score <- score + 10                     # decisive
      }
      if (si == 1 && !swap) score <- score + 1              # prefer canonical order
      if (score > best_score) { best_score <- score; best <- cand }
    }
  }
  if (is.null(best)) c(sort(bb[1:2]), sort(bb[3:4])) else best
}

.warn_speed_order <- function(cfg, field) {
  v <- cfg[[field]]
  if (is.numeric(v) && length(v) == 3 && (v[3] < v[1] || v[3] < v[2])) {
    warning(field, ": max (", v[3], ") is smaller than optimal/sd (",
            v[1], ", ", v[2], ") - check the (optimal, sd, max) ordering. ",
            "Values used as given.", call. = FALSE)
  }
  invisible(NULL)
}
