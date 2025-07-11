################################################################################
# FILE: 03_AvgIncomebyRaceCvilleAC1999.R
# PURPOSE: Use gridded EIF data to create a bar chart on average income decile by
# race/ethnicity in Charlottesville and Albemarle County in 1999.
# AUTHOR: Elizabeth Shiker
# CREATED: June 10th, 2025
################################################################################
# INPUTS: raceincome_1999.rda
# OUTPUTS: avg_income_by_race_1999.png
################################################################################

# Load in race and income data from 1999

raceincome_1999 <- load("data/processed/raceincome_rda/raceincome_1999.rda")
raceincome1999 <- get(raceincome_1999)

#Filter for Cville/AC
raceincome2023 <- raceincome2023 %>%
  filter(
    STATEFP == "51" & COUNTYFP %in% c("540", "003")
  )



#Calculating average income for each race in Cville/AC

avg_income_by_race <- raceincome1999 %>%
  filter(!is.na(race_ethnicity), race_ethnicity != "Other/Unknown") %>%
  group_by(race_ethnicity) %>%
  summarise(
    avg_income_decile = weighted.mean(income_decile, w = n_noise_postprocessed, na.rm = TRUE),
    .groups = "drop"
  )

# Save bar chart of average income by race in Cville/AC in 1999
ggsave(
  "output/raceincome/avg_income_by_race_1999.png",
  plot = ggplot(avg_income_by_race, aes(x = reorder(race_ethnicity, -avg_income_decile), y = avg_income_decile)) +
    geom_bar(stat = "identity", fill = "steelblue") +
    labs(
      title = "Average Income Decile by Race/Ethnicity (1999)",
      x = "Race/Ethnicity",
      y = "Average Income Decile (Weighted by Population)"
    ) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)),
  width = 8,
  height = 6
)

