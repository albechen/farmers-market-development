# IMPORT LIBRARY and SOURCE DOCS ----------------------------------------

# Import Libraries
library(readr)
library(dplyr)
library(ggplot2)
library(tidyr)
library(reshape2)
library(stringr)
library(treemapify)
library(usmap)
library(RColorBrewer)
library(ggsci)

# read source documents
fm <- read_csv("data/fmarket.csv")
state_region <- read_csv("data/state_region.csv")
state_area <- read_csv("data/state_area.csv")


# DATA EXTRACTION [START----------------------------------------


# add updated year to denote estimated growth
fm$year_update <- str_match(fm$updateTime, "20\\d{2}")


# SEASONAL MONTH EXTRACTION ----------------------------------------


# Add seasons and split into months that each market was active

col_list <- list(
  "start_month", "end_month",
  "1", "2", "3",
  "4", "5", "6", "7",
  "8", "9", "10",
  "11", "12", "total_months"
)
month_num <- list(
  "1", "2", "3",
  "4", "5", "6", "7",
  "8", "9", "10",
  "11", "12"
)

for (col in col_list) {
  fm[, col] <- NA
}

# loop through each to extract starting and end months
for (row in 1:nrow(fm)) {
  season <- fm[row, "Season1Date"]
  season <- tolower(season)
  season_check_space <- gsub(" ", "", season, fixed = TRUE)

  if (is.na(season)) {
  }

  # standard format DDMMYYYY to DDMMYYYY
  else if (nchar(season) == 24) {
    fm[row, "start_month"] <- as.integer(substr(season, 1, 2))
    fm[row, "end_month"] <- as.integer(substr(season, 15, 16))
  }

  # extract other type with just "month to month" (use dict to get names)
  else if (grepl("^[A-Za-z]+$", season_check_space, perl = T) == TRUE) {
    month_list <- list(
      "january" = 1, "february" = 2, "march" = 3,
      "april" = 4, "may" = 5, "june" = 6, "july" = 7,
      "august" = 8, "september" = 9, "october" = 10, "octobsr" = 10,
      "november" = 11, "december" = 12
    )

    start_month_char <- gsub(" to .*$", "", season)
    start_month <- month_list[[start_month_char]]
    fm[row, "start_month"] <- as.integer(start_month)

    end_month_char <- gsub(".*to ", "", season)
    end_month <- month_list[[end_month_char]]
    fm[row, "end_month"] <- as.integer(end_month)
  }
  else {
  }
}

# calculate active months in array for each month
for (row in 1:nrow(fm)) {
  start_month <- as.integer(fm[row, "start_month"])
  end_month <- as.integer(fm[row, "end_month"])
  if (is.na(start_month)) {
  }

  # situation where month doesn't loop from Dec to Jan
  else if (start_month < end_month) {
    fm[row, "total_months"] <- as.character(end_month - start_month + 1)
    active_months <- list()
    for (n in start_month:end_month) {
      active_months <- append(active_months, n)
    }
    for (month in month_num) {
      if (month %in% active_months) {
        fm[row, month] <- 1
      }
      else {
        fm[row, month] <- 0
      }
    }
  }

  # Situation where month loops from Dec to Jan
  else if (end_month < start_month) {
    fm[row, "total_months"] <- as.character(12 - start_month + end_month + 1)
    active_months <- list()
    for (n in start_month:12) {
      active_months <- append(active_months, n)
    }
    for (n in 1:end_month) {
      active_months <- append(active_months, n)
    }
    for (month in month_num) {
      if (month %in% active_months) {
        fm[row, month] <- 1
      }
      else {
        fm[row, month] <- 0
      }
    }
  }

  # Situation for single month
  else if (end_month == start_month) {
    fm[row, "total_months"] <- as.character(1)
    for (month in month_num) {
      if (month == start_month) {
        fm[row, month] <- 1
      }
      else {
        fm[row, month] <- 0
      }
    }
  }
  else {
  }
}

# rename columns to known names for assignability
fm <- rename(fm,
  "Jan" = "1", "Feb" = "2", "Mar" = "3",
  "Apr" = "4", "May" = "5", "Jun" = "6",
  "Jul" = "7", "Aug" = "8", "Sep" = "9",
  "Oct" = "10", "Nov" = "11", "Dec" = "12"
)



# BINDARY MAPPING Y/N (Media, Goods, Payment) ----------------------------------------


# MEDIA - denote media used by each farmer market (Empty / Not empty)
media_list <- list("Website", "Facebook", "Twitter", "Youtube", "OtherMedia")
for (media in media_list) {
  fm[[media]][is.na(fm[[media]])] <- 0
  fm[[media]][fm[[media]] != 0] <- 1
}

# GOODS - simple Y/N system
goods_list <- list()
for (n in 1:30) {
  goods_col <- colnames(fm[, c(29:58)][n])
  goods_list <- append(goods_list, goods_col)
}
for (goods in goods_list) {
  fm[[goods]][fm[[goods]] == "Y"] <- 1
  fm[[goods]][fm[[goods]] == "N"] <- 0
}

# PAYMENT - simple Y/N system
pay_list <- list("Credit", "WIC", "WICcash", "SFMNP", "SNAP")
for (pay in pay_list) {
  fm[[pay]][fm[[pay]] == "Y"] <- 1
  fm[[pay]][fm[[pay]] == "N"] <- 0
}


# JOIN SOURCE DOC and SUM BINARY VALUES ----------------------------------------


# Joining by states to get regions and divisions
fm <- full_join(fm, state_region, by = "State")

# convert total goods columns to numeric
fm$total_goods <- rowSums(sapply(fm[, c(30:58)], as.numeric))

# Joining by states population and area to state
fm <- full_join(fm, state_area, by = "State")

# sum total payments and meida as numeric
fm$total_payment <- rowSums(sapply(fm[, c(24:28)], as.numeric))
fm$total_media <- rowSums(sapply(fm[, c(3:7)], as.numeric))


# DATA EXTRACTION [COMPLETED] ----------------------------------------







# DATA VISUALIZATION [START]----------------------------------------

# MAP and REGION ----------------------------------------

# split between region and divison
fm_graph <- fm[, c(77, 79, 78, 60)]
fm_graph <- drop_na(fm_graph)

ggplot(fm_graph, aes(Region, fill = Division)) +
  geom_bar() +
  ggtitle("Farmers Markets by Region and Division") +
  xlab("Region") +
  ylab("Count")
ggsave("images/region_division.png", dpi = 500)

# graphics of united states by population and area
fm_graph <- fm[, c(76, 80, 81)]

fm_graph <- fm_graph %>%
  group_by(`State Code`, `land_area_sqmi`, `population`) %>%
  filter(`State Code` != "DC") %>%
  drop_na() %>%
  summarise(count = n())

fm_graph <- rename(fm_graph, "state" = "State Code")
fm_graph$fm_per_sqmi <- fm_graph$count / fm_graph$land_area_sqmi * 1000
fm_graph$fm_per_pop <- fm_graph$count / fm_graph$population * 100000

plot_usmap(data = fm_graph, values = "fm_per_pop") +
  labs(title = "Farmers Markets per 100k State Population") +
  scale_fill_continuous(
    low = "white", high = "darkgreen", name = "Count per 100k People",
    limits = c(0, 20), breaks = c(0, 5, 10, 15, 20)
  ) +
  theme(plot.title = element_text(hjust = 0.5), legend.position = "bottom")
ggsave("images/fm_per_state_pop.png", dpi = 500)

plot_usmap(data = fm_graph, values = "fm_per_sqmi") +
  labs(title = "Farmers Markets per 1k sqmi per State") +
  scale_fill_continuous(
    low = "white", high = "darkgreen", name = "Count per 1000 sqmi",
    limits = c(0, 50), breaks = c(0, 10, 20, 30, 40, 50)
  ) +
  theme(plot.title = element_text(hjust = 0.5), legend.position = "bottom")
ggsave("images/fm_per_sqmi.png", dpi = 500)

plot_usmap(data = fm_graph, values = "count") +
  labs(title = "Farmers Markets per State") +
  scale_fill_continuous(
    low = "white", high = "darkgreen", name = "Count",
    limits = c(0, 900), breaks = c(0, 200, 400, 600, 800)
  ) +
  theme(plot.title = element_text(hjust = 0.5), legend.position = "bottom")
ggsave("images/fm_per_state.png", dpi = 500)


# PRODUCT POPULARITY ----------------------------------------


# total goods density plot split by region

fm_tot_goods <- fm[, c(77, 79, 78, 60)]
fm_tot_goods <- filter(fm_tot_goods, year_update > 2011)

fm_tot_goods <- drop_na(fm_tot_goods)

ggplot(data = fm_tot_goods, aes(x = total_goods, fill = Region)) +
  geom_density(alpha = 0.30) +
  scale_fill_aaas() +
  ggtitle("Total Types of Products of Farmers Markets by Region") +
  xlab("Total Types of Products") +
  ylab("Density")
ggsave("images/goods_total_density.png", dpi = 500)


# gather goods by each region and analyze
fm_food <- fm[, c(30:58, 77)]
fm_food <- gather(fm_food, key = "goods", value = measurement, -Region)

# calculate number yes/no then join to get percentage / "popularity"
fm_yes_food <- fm_food %>%
  filter(measurement == 1) %>%
  group_by(goods, Region) %>%
  drop_na() %>%
  summarise(Yes = n())

fm_no_food <- fm_food %>%
  filter(measurement == 0) %>%
  group_by(goods, Region) %>%
  drop_na() %>%
  summarise(No = n())

food_join <- merge(fm_yes_food, fm_no_food, by = c("goods", "Region"), all = TRUE)
food_join[is.na(food_join)] <- 0
food_join$Percent_Yes <- food_join$Yes / (food_join$Yes + food_join$No)
food_join$Percent_No <- 1 - food_join$Percent_Yes

# top 10 popular product per region into a treemap plot
Rank <- function(x) rank(x, ties.method = "first")
food_top10 <- transform(food_join, rank = ave(Percent_No, Region, FUN = Rank))
food_top10 <- filter(food_top10, rank <= 10)

ggplot(food_top10, aes(
  area = Percent_Yes,
  fill = Region,
  label = goods,
  subgroup = Region
)) +
  scale_fill_aaas() +
  ggtitle("Top 10 Majority Products Available at Farmers Markets by Region") +
  geom_treemap(aes(alpha = Yes)) +
  geom_treemap_subgroup_border(colour = "white") +
  geom_treemap_text(
    place = "topright",
    alpha = .9,
    colour = "grey95",
    size = 10,
    fontface = "bold"
  ) +
  geom_treemap_subgroup_text(
    place = "bottomleft",
    alpha = .4,
    colour = "grey90",
    fontface = "bold",
    size = 30
  ) +
  scale_alpha(name = "Count", limits = c(750, 1750))
ggsave("images/total_goods_tree.png", dpi = 500)

# speciality items - set the mean to compare which products have an realive outlier
food_dist_check <- food_join %>%
  group_by(goods) %>%
  summarise(mean = mean(Percent_Yes)) %>%
  merge(food_join, by = "goods", all = TRUE) %>%
  filter(abs(Percent_Yes - mean) > 0.08) %>%
  distinct(goods)
food_dist_v <- food_dist_check$goods

food_special <- food_join %>%
  filter(goods %in% food_dist_v)

ggplot(food_special, aes(fill = Region, y = Percent_Yes, x = goods)) +
  geom_bar(position = "dodge", stat = "identity") +
  scale_fill_aaas() +
  ggtitle("Products with Regional Difference in Avalibility") +
  xlab("Products") +
  ylab("Percent Avalibility")
ggsave("images/goods_speciality.png", dpi = 500)


# UPDATE YEAR CHECK ----------------------------------------

# update years split by region
fm_graph <- fm[, c(60, 77)]

fm_graph <- fm_graph %>%
  group_by(year_update, Region) %>%
  drop_na() %>%
  summarise(count = n())

ggplot(fm_graph, aes(x = year_update, y = count, fill = Region)) +
  geom_bar(position = "fill", stat = "identity") +
  scale_fill_aaas() +
  ggtitle("Year Updated Split by Region") +
  xlab("Year Updated") +
  ylab("Percent Region")

ggplot(fm_graph, aes(x = year_update, y = count, fill = Region)) +
  geom_bar(stat = "identity") +
  scale_fill_aaas() +
  ggtitle("Update Year of Farmers Markets Entries by Region") +
  xlab("Year Updated") +
  ylab("Count")


# SEASON and ACTIVE MONTHS ----------------------------------------


# total active months
fm_graph <- fm[, c(75, 77)]
fm_graph <- fm_graph %>%
  group_by(total_months, Region) %>%
  drop_na() %>%
  summarise(count = n())

fm_graph$total_months <- factor(fm_graph$total_months,
  levels =
    c(
      "1", "2", "3", "4", "5", "6",
      "7", "8", "9", "10", "11", "12"
    )
)

ggplot(fm_graph, aes(x = total_months, y = count, fill = Region)) +
  geom_bar(stat = "identity") +
  scale_fill_aaas() +
  ggtitle("Total Active Months of Farmers Markets by Region") +
  xlab("Total Active Months") +
  ylab("Count")

# Active months split by month
fm_graph <- fm[, c(63:74, 77)]
fm_graph <- gather(fm_graph, key = "months", value = measurement, -Region)

fm_graph <- fm_graph %>%
  filter(measurement == 1) %>%
  group_by(months, Region) %>%
  drop_na() %>%
  summarise(count = n())

fm_graph$months <- factor(fm_graph$months,
  levels =
    c(
      "Jan", "Feb", "Mar", "Apr",
      "May", "Jun", "Jul", "Aug",
      "Sep", "Oct", "Nov", "Dec"
    )
)

ggplot(fm_graph, aes(x = months, y = count, fill = Region)) +
  geom_bar(stat = "identity") +
  scale_fill_aaas() +
  ggtitle("Active Months of Farmers Markets by Region") +
  xlab("Active Months") +
  ylab("Count")
ggsave("images/active_months_per_region.png", dpi = 500)



# MEDIA PLATFORMS ----------------------------------------


# media analysis over years of update
fm_media <- fm[, c(3:7, 60)]
fm_media <- gather(fm_media, key = "media", value = measurement, -year_update)

# split into simple analysis of number of markets for each platform
fm_yes_media <- fm_media %>%
  filter(measurement == 1) %>%
  group_by(media, year_update) %>%
  drop_na() %>%
  summarise(Yes = n())

fm_ct_media <- fm_yes_media

fm_ct_media$media <- factor(fm_ct_media$media,
  levels =
    c(
      "Website", "Facebook", "Twitter",
      "OtherMedia", "Youtube"
    )
)

ggplot(fm_ct_media, aes(x = media, y = Yes, fill = media)) +
  geom_bar(stat = "identity") +
  scale_fill_manual(values = c(
    "#55C53B", "#3b5998", "#00aced",
    "#D6CE3D", "#bb0000"
  ), name = "Media") +
  ggtitle("Farmers Markets Media Platform Usage") +
  xlab("Media Platforms") +
  ylab("Count")
ggsave("images/media_count.png", dpi = 500)

# look at markets without platform and join to compare percentage / "popularity"
fm_no_media <- fm_media %>%
  filter(measurement == 0) %>%
  group_by(media, year_update) %>%
  drop_na() %>%
  summarise(No = n())

media_join <- merge(fm_yes_media, fm_no_media, by = c("media", "year_update"), all = TRUE)
media_join[is.na(media_join)] <- 0
media_join$Percent_Yes <- media_join$Yes / (media_join$Yes + media_join$No)
media_no2020 <- filter(media_join, year_update != 2020)

media_no2020$media <- factor(media_no2020$media,
  levels =
    c(
      "Website", "Facebook", "Twitter",
      "OtherMedia", "Youtube"
    )
)


ggplot(media_no2020, aes(x = year_update, y = Percent_Yes, group = media)) +
  geom_line(aes(color = media), size = 1) +
  geom_point(aes(color = media), size = 2) +
  scale_color_manual(values = c(
    "#55C53B", "#3b5998", "#00aced",
    "#D6CE3D", "#bb0000"
  ), name = "Media") +
  ggtitle("Farmers Markets Media Platform Usage (2009-2019)") +
  xlab("Year Updated") +
  ylab("Percent Using Media Platform")
ggsave("images/media_percent_year.png", dpi = 500)


# media usage per region analysis
fm_pay_region <- fm[, c(24:28, 77)]
fm_pay_region <- gather(fm_pay_region, key = "payment", value = measurement, -Region)

fm_pay_region <- fm_pay_region %>%
  filter(measurement == 1) %>%
  group_by(payment, Region) %>%
  drop_na() %>%
  summarise(count = n())

ggplot(fm_pay_region, aes(x = payment, y = count, fill = Region)) +
  geom_bar(position = "fill", stat = "identity") +
  scale_fill_aaas() +
  ggtitle("Payment Types by Region") +
  xlab("Payment Types") +
  ylab("Percent Region")
ggsave("images/payment_percent.png", dpi = 500)


# PAYMENT TYPES ----------------------------------------

# pay analysis populairty analysis
fm_just_payment <- fm[, c(24:28, 60)]

# Sum if payment = 0
fm_no_pay <- gather(fm_just_payment, key = "payment", value = measurement, -year_update)

fm_no_pay <- fm_no_pay %>%
  filter(measurement != 1) %>%
  group_by(payment, year_update) %>%
  drop_na() %>%
  summarise(No = n())

# Sum if payment = 1
fm_pay <- gather(fm_just_payment, key = "payment", value = measurement, -year_update)

fm_pay <- fm_pay %>%
  filter(measurement != 0) %>%
  group_by(payment, year_update) %>%
  drop_na() %>%
  summarise(Yes = n())
fm_ct_pay <- fm_pay

fm_ct_pay$payment <- factor(fm_ct_pay$payment,
  levels =
    c("Credit", "SNAP", "SFMNP", "WIC", "WICcash")
)


ggplot(fm_ct_pay, aes(x = payment, y = Yes, fill = payment)) +
  geom_bar(stat = "identity") +
  scale_fill_nejm(name = "Payment") +
  ggtitle("Farmers Markets Payment Types Acceptance") +
  xlab("Payment Types") +
  ylab("Count")
ggsave("images/payment_count.png", dpi = 500)

# compare payment count vs no payment
pay_join <- merge(fm_pay, fm_no_pay, by = c("payment", "year_update"), all = TRUE)
pay_join[is.na(pay_join)] <- 0
pay_join$Percent_Yes <- pay_join$Yes / (pay_join$Yes + pay_join$No)
pay_no2020 <- filter(pay_join, year_update != 2020)
pay_no2020 <- filter(pay_no2020, year_update > 2010)

pay_no2020$payment <- factor(pay_no2020$payment,
  levels =
    c("Credit", "SNAP", "SFMNP", "WIC", "WICcash")
)

ggplot(data = pay_no2020, aes(x = year_update, y = Percent_Yes, group = payment)) +
  geom_line(aes(color = payment), size = 1) +
  geom_point(aes(color = payment), size = 2) +
  scale_fill_nejm() +
  scale_color_nejm(name = "Payment") +
  ggtitle("Farmers Markets Payment Types Acceptance (2011-2019)") +
  xlab("Year Updated") +
  ylab("Percent Accepting Payment")
ggsave("images/payment_vs_years.png", dpi = 500)
