# eBay used car sales Project

# Directory setting
setwd("D:/Data/R/eBay kleinanzeigen")

# Data
df <- read.csv("autos.csv", header = T)

# Libraries
library(tidyverse)
library(naniar)

# EDA
str(df)
summary(df)
vis_miss(df)

# Wrangling
df %>% 
  mutate(price = parse_number(price), odometer = parse_number(odometer)) %>% 
  mutate(gearbox = if_else(gearbox == "", NA, gearbox),
         notRepairedDamage = if_else(notRepairedDamage == "", NA, notRepairedDamage)) %>% 
  mutate(notRepairedDamage = recode(notRepairedDamage,
                                    "ja" = "Yes",
                                    "nein" = "No"),
         gearbox = recode(gearbox,
                          "manuell" = "Manual",
                          "automatik" = "Automatic"), 
         gearbox = replace_na_with(gearbox, "Unknown"),
         notRepairedDamage = replace_na_with(notRepairedDamage, "Unknown")) %>% 
  filter(yearOfRegistration >1900, yearOfRegistration < 2020) -> df_clean

# Creating brand category
German <- c("Volkswagen", "Opel", "Smart")
Europ_econ <- c("Renault", "Peugeot", "Fiat", "Citroen", "Seat", "Skoda", "Dacia")
Asian_econ <- c("Toyota", "Honda", "Nissan", "Mazda", "Hyundai", "Kia", "Mitsubishi", "Subaru", "Suzuki", "Daihatsu", "Daewoo")
American <- c("Ford", "Chevrolet", "Rover", "Lancia", "Lada")

# Creating price category
High_end_luxury <- c("Porsche", "Jaguar", "Land Rover")
Premium_exec <- c("Audi", "Bmw", "Mercedes-Benz", "Volvo")
Premium_niche <- c("Alfa Romeo", "Saab", "Jeep", "Chrysler")

# Adding different categories to the data
df_clean %>% 
  mutate(brand = str_to_sentence(brand)) %>% 
  mutate(br_category = if_else(brand %in% German, "German",
                               if_else(brand %in% Europ_econ, "European Economy",
                                       if_else(brand %in% Asian_econ, "Asian Economy",
                                               if_else(brand %in% American, "American", "Other")))),
         pr_category = if_else(brand %in% High_end_luxury, "High End Luxury",
                               if_else(brand %in% Premium_exec, "Premium Executive",
                                       if_else(brand %in% Premium_niche, "Premium Niche", "Common")))) -> df_clean


table(df_clean$gearbox) # There is a category without any name. It is not NA
table(df_clean$notRepairedDamage) # There is a category without any name. It is not NA

summary(df_clean$price) # There is a price at 0 value and 99999999 value in USD, likely to be outliers
summary(df_clean$odometer) # Appears normal

# Removing outliers
df_clean %>% 
  filter(price <= quantile(price, 0.75) + 1.5*IQR(price),
         price > 100) -> df_trim

summary(df_clean$price)
summary(df_trim$price) # Worked

# Data Analysis

# Top 6 brands (most sold)
df_trim %>% 
  count(brand, sort = T) %>% 
  head(6) %>% 
  select(brand) -> top6

# Checking the trend of the effect of mileage (Odometer) on the car's cost (Only top 6 at present)
df_trend <- df_trim %>% 
  filter(brand %in% top6$brand) %>% 
  group_by(brand, odometer) %>% 
  summarise(cost = mean(price, na.rm = T)) %>% 
  arrange(brand, odometer)

# Visualizing the trend
df_trend %>% 
  ggplot(aes(x = odometer, y = cost, col = brand)) + geom_line(linewidth=1) +
  labs(title = "Car price depriciation by brand",
       x = "Mileage (Odometer)",
       y = "Average price ($)",
       color = "Brand") +
  theme_minimal()

# Price Retention by Brand (Retention rate)
retention <- df_trim %>% 
  filter(odometer %in% c(5000, 50000)) %>% 
  group_by(brand) %>% 
  summarise(start_price = mean(price[odometer == 5000], na.rm = T),
            mid_price = mean(price[odometer == 50000], na.rm = T),
            ret_rate = (mid_price / start_price)*100) %>% 
  arrange(-ret_rate) %>% 
  head(10) %>% 
  ggplot(aes(x = reorder(brand, ret_rate), y = ret_rate, fill = brand)) + geom_bar(stat = 'identity') +
  coord_flip() +
  geom_text(aes(label = paste0(round(ret_rate,1),"%")), position = position_dodge(width = 0.5), hjust = -0.15) +
  labs(title = "Cost retention of cars after 50K kms",
       subtitle = "Compared to 5K kms",
       x = "",
       y = "Retention rate (%)") +
theme_minimal() +
  theme(legend.position = "",
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.text.x = element_blank(),
        plot.title = element_text(face = 'bold', size = 18),
        axis.text.y = element_text(size = 10))

retention

# Retention by Brand category
retention2 <- df_trim %>% 
  filter(odometer %in% c(5000, 50000)) %>% 
  group_by(br_category) %>% 
  summarise(start_price = mean(price[odometer == 5000], na.rm = T),
            mid_price = mean(price[odometer == 50000], na.rm = T),
            ret_rate = (mid_price / start_price)*100) %>% 
  arrange(-ret_rate) %>% 
  head(10) %>% 
  ggplot(aes(x = reorder(br_category, ret_rate), y = ret_rate, fill = br_category)) + geom_bar(stat = 'identity') +
  coord_flip() +
  geom_text(aes(label = paste0(round(ret_rate,1),"%")), position = position_dodge(width = 0.5), hjust = -0.15) +
  labs(title = "Cost retention of cars after 50K kms",
       subtitle = "Compared to 5K kms",
       x = "Brand category",
       y = "Retention rate (%)") +
  theme_minimal() +
  theme(legend.position = "",
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.text.x = element_blank(),
        plot.title = element_text(face = 'bold', size = 18),
        axis.text.y = element_text(size = 10))

retention2 # German cars retain most value

# Retention by Price category
retention3 <- df_trim %>% 
  filter(odometer %in% c(5000, 50000)) %>% 
  group_by(pr_category) %>% 
  summarise(start_price = mean(price[odometer == 5000], na.rm = T),
            mid_price = mean(price[odometer == 50000], na.rm = T),
            ret_rate = (mid_price / start_price)*100) %>% 
  arrange(-ret_rate) %>% 
  head(10) %>% 
  ggplot(aes(x = reorder(pr_category, ret_rate), y = ret_rate, fill = pr_category)) + geom_bar(stat = 'identity') +
  coord_flip() +
  geom_text(aes(label = paste0(round(ret_rate,1),"%")), position = position_dodge(width = 0.5), hjust = -0.15) +
  labs(title = "Cost retention of cars after 50K kms",
       subtitle = "Compared to 5K kms",
       x = "Price category",
       y = "Retention rate (%)") +
  theme_minimal() +
  theme(legend.position = "",
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.text.x = element_blank(),
        plot.title = element_text(face = 'bold', size = 18),
        axis.text.y = element_text(size = 10))

retention3
