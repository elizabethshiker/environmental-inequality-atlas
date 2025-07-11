################################################################################
# FILE: 02_clean_ageracesex.R
# PURPOSE: Download ageracesex files as rda and dta for 1999-2023, save long and
# reshaped versions.
# AUTHOR: Arnav Dharmagadda
# CREATED: June 9th, 2025
################################################################################
# INPUTS: gridded_eif_pop_ageracesex files (1999-2023)
# OUTPUTS: ageracesex_{YEAR}.dta/.rda, ageracesex_combined.rda/.dta,
#          ageracesex_year_long.rda/.dta
################################################################################

# Fix 2024 parquet file first

ageracesexparquet2024_path <- paste0(data_path, "/ageracesex/gridded_v5a_pop_ageracesexeif_2024_realtime.parquet copy")
ageracesexparquet2024 <- read_parquet(ageracesexparquet2024_path)

#Change variables within parquet2024

colnames(ageracesexparquet2024) <- c("grid_lon", "grid_lat", "age_group", "race_ethnicity", "sex", "n_noise", "n_noise_postprocessed")

# Write new parquet

ageracesexoutput2024_path <- paste0(data_path, "/ageracesex/gridded_eif_pop_ageracesex_2024.parquet")

write_parquet(ageracesexparquet2024, ageracesexoutput2024_path)

# Loop 1999 through 2024

for (year in 1999:2024) {
  # Construct path to parquet file
  parquet_path <- paste0(data_path, "/ageracesex/gridded_eif_pop_ageracesex_", year, ".parquet")
  
  # Read the parquet file
  ageracesex_year <- read_parquet(parquet_path)
  
  # Merge with filtered gridpoints
  merged_year <- left_join(gridpoints, ageracesex_year, by = c("grid_lon", "grid_lat"))

  # Replace NAs in numeric columns (e.g., population counts) with 0, but do not modify grid_lon or grid_lat
  num_cols <- sapply(merged_year, is.numeric)
  num_cols[names(num_cols) %in% c("grid_lon", "grid_lat")] <- FALSE
  merged_year[num_cols] <- lapply(merged_year[num_cols], function(x) ifelse(is.na(x), 0, x))
  
  # Write to Stata .dta
  output_file <- paste0(dta_path_ars, "ageracesex_", year, ".dta")
  write_dta(merged_year, output_file)
  
  # Write to .rda
  output_file_rda <- paste0(rda_path_ars, "ageracesex_", year, ".rda")
  save(merged_year, file = output_file_rda)
}

for (year in 2024) {
  # Construct path to parquet file
  parquet_path <- paste0(data_path, "ageracesex/gridded_eif_pop_ageracesex_", year, ".parquet")
  
  # Read the parquet file
  ageracesex_year <- read_parquet(parquet_path)
  
  # Merge with filtered gridpoints
  merged_year <- left_join(gridpoints_nat, ageracesex_year, by = c("grid_lon", "grid_lat"))

  # Replace NAs in numeric columns (e.g., population counts) with 0, but do not modify grid_lon or grid_lat
  num_cols <- sapply(merged_year, is.numeric)
  num_cols[names(num_cols) %in% c("grid_lon", "grid_lat")] <- FALSE
  merged_year[num_cols] <- lapply(merged_year[num_cols], function(x) ifelse(is.na(x), 0, x))
  
  # Write to Stata .dta
  output_file <- paste0(dta_path_ars, "nat_ageracesex_", year, ".dta")
  write_dta(merged_year, output_file)
  
  # Write to .rda
  output_file_rda <- paste0(rda_path_ars, "nat_ageracesex_", year, ".rda")
  save(merged_year, file = output_file_rda)
}

# Append

rda_files <- list.files(path = rda_path_ars, pattern = "^ageracesex_\\d{4}\\.rda$", full.names = TRUE)
all_ageracesex <- list()

for (file in rda_files) {
  load(file)  # loads object called `merged_year`
  
  # Extract year from filename and add as a column
  year <- as.numeric(gsub(".*_(\\d{4})\\.rda$", "\\1", file))
  merged_year$year <- year
  
  all_ageracesex[[length(all_ageracesex) + 1]] <- merged_year

}

# Combine all into a single dataframe
ageracesex_combined <- do.call(rbind, all_ageracesex)

save(ageracesex_combined, file = paste0(rda_path_ars, "ageracesex_long.rda"))
write_dta(ageracesex_combined, paste0(dta_path_ars, "ageracesex_long.dta"))

# Reshape

# Rename values for variable compatibility

ageracesex_combined <- ageracesex_combined %>%
  mutate(age_group = case_when(
    age_group == "Over 65" ~ "over_65",
    age_group == "19-65" ~ "bet_19_65",
    age_group == "Under 18" ~ "under_18",
    TRUE ~ age_group  # keep all other values unchanged
  )) %>%
  mutate(race_ethnicity = case_when(
    race_ethnicity == "Other/Unknown" ~ "other_race",
    TRUE ~ race_ethnicity  # keep all other values unchanged
  )) %>%
  mutate(age_group = case_when(
    age_group == "Missing Age" ~ "na_age",
    TRUE ~ age_group  # keep all other values unchanged
  )) %>%
  mutate(sex = case_when(
    sex == "Missing Gender" ~ "na_sex",
    TRUE ~ sex  # keep all other values unchanged
  )) %>%
  mutate(race_age_sex = paste(race_ethnicity, age_group, sex, sep = "_"))

# Reshape for ageracesex variables

ageracesex_wide <- ageracesex_combined %>%
  select(year, grid_lon, grid_lat, STATEFP, COUNTYFP, NAME, race_age_sex, n_noise_postprocessed) %>%
  pivot_wider(
    names_from = race_age_sex,
    values_from = n_noise_postprocessed
  )

agerace_combined <- ageracesex_combined %>%
  mutate(race_age = paste(race_ethnicity, age_group, sep = "_"))

# Reshape for agerace variables

agerace_wide <- agerace_combined %>%
  group_by(year, grid_lon, grid_lat, race_age) %>%
  summarise(total_pop = sum(n_noise_postprocessed, na.rm = TRUE), .groups = "drop") %>%
  select(year, grid_lon, grid_lat, race_age, total_pop) %>%
  pivot_wider(
    names_from = race_age,
    values_from = total_pop
  )

# Reshape for race variables

race_wide <- ageracesex_combined %>%
  group_by(year, grid_lon, grid_lat, race_ethnicity) %>%
  summarise(total_race_pop = sum(n_noise_postprocessed, na.rm = TRUE), .groups = "drop") %>%
  select(year, grid_lon, grid_lat, race_ethnicity, total_race_pop) %>%
  pivot_wider(
    names_from = race_ethnicity,
    values_from = total_race_pop
  ) %>%
  {if("NA" %in% names(.)) rename(., NA_race = `NA`) else .}

# Reshape for age_group variables

age_group_wide <- ageracesex_combined %>%
  group_by(year, grid_lon, grid_lat, age_group) %>%
  summarise(total_age_pop = sum(n_noise_postprocessed, na.rm = TRUE), .groups = "drop") %>%
  select(year, grid_lon, grid_lat, age_group, total_age_pop) %>%
  pivot_wider(
    names_from = age_group,
    values_from = total_age_pop
  ) %>%
  {if("NA" %in% names(.)) rename(., NA_age = `NA`) else .}

# Reshape for sex variables

sex_wide <- ageracesex_combined %>%
  group_by(year, grid_lon, grid_lat, sex) %>%
  summarise(total_sex_pop = sum(n_noise_postprocessed, na.rm = TRUE), .groups = "drop") %>%
  select(year, grid_lon, grid_lat, sex, total_sex_pop) %>%
  pivot_wider(
    names_from = sex,
    values_from = total_sex_pop
  ) %>%
  {if("NA" %in% names(.)) rename(., NA_sex = `NA`) else .}

# Combine all reshaped dataframes into a long format

ageracesex_year_long <- ageracesex_wide %>%
  left_join(agerace_wide,   by = c("grid_lon", "grid_lat", "year")) %>%
  left_join(race_wide, by = c("grid_lon", "grid_lat", "year")) %>%
  left_join(age_group_wide, by = c("grid_lon", "grid_lat", "year")) %>%
  left_join(sex_wide, by = c("grid_lon", "grid_lat", "year"))

# Set all numeric columns except grid_lon, grid_lat, and year to 0 if NA
num_cols <- sapply(ageracesex_year_long, is.numeric)
num_cols[names(num_cols) %in% c("grid_lon", "grid_lat", "year")] <- FALSE
ageracesex_year_long[num_cols] <- lapply(ageracesex_year_long[num_cols], function(x) ifelse(is.na(x), 0, x))

save(ageracesex_year_long, file = paste0(rda_path_ars, "ageracesex_year_long.rda"))
write_dta(ageracesex_year_long, paste0(dta_path_ars, "ageracesex_year_long.dta"))

