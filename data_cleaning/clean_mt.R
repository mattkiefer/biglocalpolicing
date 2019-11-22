# imports

library(tidyverse)
library(lubridate)
library(janitor)
library(hashmap)
library(stringr)

# generalized functions

RAW_DATA_PATH <- "combined_mt.csv"
OUTPUT_PATH <- "cleaned_mt.csv"

clean_excess_whitespace <- function(str_to_clean) {
    return(str_trim(gsub("\\s+", " ", str_to_clean)))
}

# load data

load_raw <- function(path_to_raw_data) {
    raw_mt_data_types <- cols(
        .default = col_character(),
        StopTime = col_datetime(format=""),
        LinkedNumber = col_character(),
        Location = col_character(),
        City = col_character(),
        County = col_character(),
        Latitude = col_double(),
        Longitude = col_double(),
        # make sure to filter this if you analyze with it bc according to the data over 3,000 babies between 0 and 1 yrs old were stopped by MHP
        Age = col_double(),
        # data is real dirty -- anything that isn't `M` or `F` should be made null on cleaning
        Sex = col_factor(),
        # race field is fairly clean but has some nulls
        Race = col_character(),
        # ethnicity field also fairly clean but has some nulls
        Ethnicity = col_character(),
        # non-numeric need to be made null or UNK
        VehicleYear = col_character(),
        VehicleMake = col_character(),
        VehicleModel = col_character(),
        VehicleStyle = col_character(),
        VehicleTagNoState = col_character(),
        # this is really a logical (boolean) column, but there are a bunch of values written as e.g. 0.0 instead of "0"
        VehicleIsCommercial = col_double(),
        # this is really a logical (boolean) column, but there are a bunch of values written as e.g. 0.0 instead of "0"
        VehicleIsMotorcycle = col_double(),
        ReasonForStop = col_character(),
        Violation1 = col_character(),
        EnforcementAction1 = col_character(),
        Violation2 = col_character(),
        Violation3 = col_character(),
        EnforcementAction2 = col_character(),
        EnforcementAction3 = col_character(),
        SearchType = col_character(),
        SearchRationale1 = col_character(),
        SearchRationale2 = col_character(),
        SearchRationale3 = col_character(),
        SearchRationale4 = col_character(),
        ViolationDescription = col_character(),
        # this is really a logical (boolean) column, but there are a bunch of values written as e.g. 0.0 instead of "0"
        ViolationUnlawfulSpeed = col_double(),
        # this is really a logical (boolean) column, but there are a bunch of values written as e.g. 0.0 instead of "0"
        AggressiveDriving = col_double(),
        FaultyOtherDescription = col_character(),
        WarningOtherViolations1 = col_character(),
        WarningOtherViolations2 = col_character(),
        CitationsThisRecord = col_double(),
        WarningsThisRecord = col_double()
    )
    
    return(read_csv(
        path_to_raw_data, 
        na = c("", "NA", "NULL"),
        col_types = raw_mt_data_types
    ))
}

load_violation_codes <- function() {
    violations_codes <- read_csv("violation_codes.csv") %>%
        clean_names() %>%
        mutate(
            lowercase_offense = gsub("\\s+", " ", str_trim(str_to_lower(system_offense))),
            lowercase_offense_category = gsub("\\s+", " ", str_trim(str_to_lower(offense_categories_description)))
        )
    # the only duplicates have duplicate offense names have the same category, so this mapping is safe
    return(hashmap(violations_codes$lowercase_offense, violations_codes$lowercase_offense_category))
}

# clean data

clean_subject_race <- function(raw_race, raw_ethnicity) {
    race_or_eth <- ifelse(raw_ethnicity == "H", "H", raw_race)
    return(case_when(
        race_or_eth == "A" ~ "asian",
        race_or_eth == "B" ~ "black",
        race_or_eth == "H" ~ "hispanic",
        race_or_eth == "I" ~ "indigenous",
        race_or_eth == "U" ~ "unknown",
        race_or_eth == "W" ~ "white"
    ))
}

clean_stop_reason <- function(stop_reason) {
    lowercase <- str_to_lower(stop_reason)
    cleaned_num <- sub("^\\d+\\s*-\\s*", "", lowercase)
    removed_parentheses <- gsub("\\(|\\)", "", cleaned_num)
    return(str_trim(gsub("\\s+", " ", removed_parentheses)))
}

raw_data <- load_raw(RAW_DATA_PATH)
violation_map <- load_violation_codes()

str_c_na <- function(sep, ...) {
    return(if_else(anyNA(...), NA_character_, str_c(..., sep=sep)))
}

cleaned_data <- raw_data %>%
    rename(
        lat = Latitude,
        lng = Longitude,
        raw_search_type = SearchType
    ) %>%
    mutate(
        datetime = ymd_hms(StopTime)
        date = as_date(datetime),
        time = hms::as_hms(datetime),
        year = year(date),
        subject_race = clean_subject_race(Race, Ethnicity),
        # from https://github.com/stanford-policylab/opp/blob/master/lib/states/mt/statewide.R
        search_conducted = !(raw_search_type %in% c("NO SEARCH REQUESTED", "NO SEARCH / CONSENT DENIED")),
        # from opp
        county_name = str_c(str_to_title(County), " County")
        reason_for_stop = clean_stop_reason(ReasonForStop),
        violation_type = violation_map$find(reason_for_stop),
        consent_search_conducted = (raw_search_type == "CONSENT SEARCH CONDUCTED")
    ) %>%
    select(
        date,
        time,
        year,
        lat,
        lng,
        subject_race,
        search_conducted,
        reason_for_stop,
        violation_type,
        consent_search_conducted,
        raw_search_type
    )

cleaned_data %>%
    write_csv(OUTPUT_PATH)