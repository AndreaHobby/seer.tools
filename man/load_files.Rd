% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/load_data.R
\name{load_files}
\alias{load_files}
\title{Load SEER tumor group files}
\usage{
load_files(group = "", setup_file, vars = NULL)
}
\arguments{
\item{group}{Name of the SEER group file to retrieve.  Uses grepl on a list of the SEER group filenames so the string can be written flexibly.  Use "." to get all files.}

\item{setup_file}{Setup file generated by setup_incidence() function.}

\item{vars}{Character vector of variable names to be extracted (default NULL gives all variables).}
}
\value{
This function returns a dataframe of the files across SEER years.
}
\description{
This function gets tumor group files by name and binds them into a data.frame.  Subset the output for the tumor(s) of interest.
Use one of the following group files: "BREAST", "COLRECT", "DIGOTHR", "FEMGEN", "LYMYLEUK", "MALEGEN", "RESPIR", "URINARY", and "OTHER" (names do NOT have to be in caps).  Select variables to be included in the output file by putting them in a character vector.  For example, you could select the following variables:  varnames <- c("pubcsnum", "year_dx", "primsite", "histo3v", "beho3v", "grade", "lateral", "dx_conf", "rept_src", "seq_num")
}
\examples{
\dontrun{
# get AML data and use data.table to subset and select.  Need to run setup_incidence() first.
s <- setup_incidence()
seer <- load_files("LYMYLEUK", s)
aml <-
    setDT(seer) \%>\%
    setkey(., siterwho) \%>\%
    .[J(35021)] \%>\%
    .[, type := "aml"]
setkey(aml, casenum)
aml <- unique(aml) # removes duplicate aml records (only taking first of each)
}
}
