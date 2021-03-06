#' Read SAS input statement
#'
#' This function reads the SEER SAS input statements file to create fwf input specs.
#'
#' @param textdoc The text document to be read in.  Must be of a very specific format.
#' @param ... To pass parameters to the readLines() function.
#' @return Returns specifications from SAS input statements that can be used by R
#' @export
read_sas_specs <- function(textdoc, ...) {
    z <- readLines(textdoc, ...) %>% # allows for encoding or other arguments to readLines
        .[grepl("^\\s*@", .)]  # pick lines starting with @
    colstart <- stringr::str_extract(z, "@\\s*\\d+\\s+") %>%
        gsub("@", "", .) %>%
        as.numeric
    varname <- stringr::str_extract(z, "[:Alpha:]+\\d*\\S*") %>% # caps + maybe a number + maybe any non-whitespace char
        tolower
    char <- stringr::str_detect(z, "\\$(CHAR|char)?\\d+")
    num <- stringr::str_detect(z, "\\s+\\d+\\.\\d+\\s+") # spaces followed by number followed by . followed by number followed by spaces
    width <- stringr::str_extract(z, "\\d+\\.\\d*") %>% # number followed by . maybe followed by number
        gsub("\\.\\d*", "", .) %>%
        as.numeric
    desc <- stringr::str_extract(z, "/\\*.+\\*/") %>% # characters contained between /* and */
        gsub("/\\*\\s*", "", .) %>%
        gsub("\\s*\\*/", "", .)
    colstop <- colstart + width - 1
    specs <- data.frame(colstart, colstop, varname, char, num, width, desc, stringsAsFactors = FALSE) # file of database specs
    return(specs)
}

#' Gets the current SEER download URL
#'
#' Gets URL for download file (zip file) for use with curl_download.  Loaded from the SEER webpage.
#'
#' @return Returns a URL
#' @export
.get_file_url <- function() {
    u <-
        rvest::html("http://seer.cancer.gov/data/options.html") %>%
        rvest::html_node("#content a:nth-child(5)") %>%
        rvest::html_attr("href")
    return(u)
}

#' Download SEER data
#'
#' Function to download and unzip latest seer file.
#'
#' @param user This is your username for the most current SEER data
#' @param pw This is your password for the most current SEER data
#' @param data_dir This is the data directory in which the unzipped data will be saved.
#' The zipped file will be downloaded to a temporary file location.
#' @return This function results in a saved file at the location in data_dir.
#' @examples
#' \dontrun{
#' # Set up download details and then download file from internet and unzip it to data_dir
#' # note file is over 300 MB and takes about 5 min to download
#' user <- "uuuuu-Nov2014"
#' pw <- "ppppp"
#' data_dir <- "./data/"
#' download_seer(user, pw, data_dir)
#' }
#' @export
download_seer <- function(user, pw, data_dir) {
    message("Getting URL for download. . . ")
    loc <- .get_file_url()
    message("Starting download.  This may take several minutes.  File is over 300 MB")
    tmp <- tempfile()
    h <- curl::new_handle()
    curl::handle_setopt(h, username = user, password = pw)
    curl::curl_download(loc, tmp, handle = h)
    message("Download complete.\nUnzipping. . .")
    unzip(tmp, overwrite = TRUE, exdir = data_dir)
    message("Unzip complete.")
}

#' Load SEER tumor group files
#'
#' This function gets tumor group files by name and binds them into a data.frame.  Subset the output for the tumor(s) of interest.
#' Use one of the following group files: "BREAST", "COLRECT", "DIGOTHR", "FEMGEN", "LYMYLEUK", "MALEGEN", "RESPIR", "URINARY", and "OTHER" (names do NOT have to be in caps).  Select variables to be included in the output file by putting them in a character vector.  For example, you could select the following variables:  varnames <- c("pubcsnum", "year_dx", "primsite", "histo3v", "beho3v", "grade", "lateral", "dx_conf", "rept_src", "seq_num")
#'
#' @param group Name of the SEER group file to retrieve.  Uses grepl on a list of the SEER group filenames so the string can be written flexibly.  Use "." to get all files.
#' @param setup_file Setup file generated by setup_incidence() function.
#' @param vars Character vector of variable names to be extracted (default NULL gives all variables).
#' @return This function returns a dataframe of the files across SEER years.
#' @examples
#' \dontrun{
#' # get AML data and use data.table to subset and select.  Need to run setup_incidence() first.
#' s <- setup_incidence()
#' seer <- load_files("LYMYLEUK", s)
#' aml <-
#'     setDT(seer) %>%
#'     setkey(., siterwho) %>%
#'     .[J(35021)] %>%
#'     .[, type := "aml"]
#' setkey(aml, casenum)
#' aml <- unique(aml) # removes duplicate aml records (only taking first of each)
#' }
#' @export
load_files <- function(group = "", setup_file, vars = NULL) {
    d <- setup_file$datafiles
    if(is.null(vars)) {
        vars <- setup_file$input_specs$col_names
    }
    cols <- setup_file$input_specs$col_names %in% vars
    ispecs <- lapply(setup_file$input_specs, function(a) a[cols]) # selected cols -- how to select all as default?
    x <-
        lapply(
            d[grepl(group, d, ignore.case = TRUE)],
            function(x) {
                readr::read_fwf(x, ispecs, progress = FALSE)
            }
            )
    y <- data.table::rbindlist(x)
    return(y)
}

#' Setup to Load Fixed-width Incidence Files
#'
#' Reads in file specs and sets up information to load desired incidence files.  These files come in groups, and specific tumors are within the groups.
#'
#' @param inc_dir Directory on user's system that contains the incidence data.
#' @param yr Year of release.  Defaults to 2013 (2016 release).  Note that incidence function is for 2013 only.
#' @return xxx
#' @examples
#' \dontrun{
#' # simple script read in files with types using above inputs
#' # remove col_types to have it choose types automatically
#' s <- setup_incidence()
#' seer <- load_files("LYMYLEUK", s)
#' }
#' @export
setup_incidence <- function(inc_dir = "./data/raw/", yr = 2013){
    inc_path <- paste0(inc_dir, "SEER_1973_", yr, "_TEXTDATA/incidence")
    f <- dir(inc_path, recursive = TRUE, include.dirs = FALSE, full.names = TRUE)
    specsfile <- f[stringr::str_detect(f, "\\.sas$")] # get fixed width specs
    datafiles <- f[stringr::str_detect(f, "\\.(txt|TXT)$")] # find data files
    specs <-    read_sas_specs(specsfile)
    coltype <-  ifelse(specs$char, "c",
                    ifelse(specs$num, "d", "i")) %>% paste0(., collapse = "") # one character per column for classes
    input_specs <-  readr::fwf_positions(specs$colstart, specs$colstop, specs$varname) # set fwf specs
    details <- list(coltype = coltype, input_specs = input_specs, datafiles = datafiles)
    return(details)
}


#' Load Population (Denominator) Data
#'
#' Loads the population files for denominators based on web version of (could also use file on system at "./data/raw/SEER_1973_2013_TEXTDATA/populations/popdic.html").  Note that this does not support 2012 and earlier files yet.  Need to use file on system for this.
#'
#' @return Returns a list of specifications:  input_specs and col_type to use to read in the fixed width file population data.  Need to access each item in list separately for read_fwf() function.
#' @export
gen_pop_specs <- function(){
    pop_specs <- rvest::html("http://seer.cancer.gov/manuals/Text.Data.popdic.html") %>%
        rvest::html_table() %>%
        do.call(rbind, .)
    names(pop_specs) <- c("varname", "colstart", "widths", "type")
    pop_specs$varname <-  # trim text to usable variable names
        gsub("\\n.*$", "", pop_specs$varname) %>%
        gsub("\\s+$", "", .) %>%
        gsub("\\s+", "_", .) %>%
        gsub("\\W", "", .) %>%
        tolower()
    pop_coltype <-
        ifelse(grepl("numeric", pop_specs$type), "d",
                    ifelse(grepl("character", pop_specs$type), "c", "c")) %>%
        paste0(., collapse = "") # one character per column for classes
    pop_input_specs <-  readr::fwf_widths(floor(pop_specs$widths), pop_specs$varname)
    details <- list(pop_input_specs, pop_coltype)
    return(pop_input_specs)
}
