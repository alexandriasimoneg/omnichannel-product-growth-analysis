# Project: Omnichannel Product Growth Strategy
# Author: Alexandria Green
# Description: End-to-end analysis including segmentation, attribution,
# marketing mix modeling, churn prediction, and demand forecasting.

#Installing packages after new update
install.packages(c("tidyverse", "readxl", "cluster", "factoextra", 
                   "nnet", "caret", "forecast", "tm", "topicmodels"))

#Load libraries
library(tidyverse)
library(readxl)

#Load xlsx
file_path <- "Final_Project_Data_MBA_Marketing_Analytics.xlsx"
customers <- read_excel(file_path, sheet = "customers")
journeys <- read_excel(file_path, sheet = "journeys")
weekly_marketing <- read_excel(file_path, sheet = "weekly_marketing")
demand_ts <- read_excel(file_path, sheet = "demand_ts")
reviews <- read_excel(file_path, sheet = "reviews")

#Check data
glimpse(customers)
summary(customers)

glimpse(journeys)
glimpse(weekly_marketing)
glimpse(demand_ts)
glimpse(reviews)

#Get segmentation variables
seg_data <- customers %>%
  select(
    total_spend_12m,
    avg_order_value,
    num_transactions_12m,
    online_visits,
    email_click_rate,
    avg_usage_minutes,
    recency_days,
    num_support_tickets,
    satisfaction_score
  ) %>%
  drop_na()

#Standardize/ scale & cluster for k-means
seg_scaled <- scale(seg_data)

set.seed(123)
kmeans_model <- kmeans(seg_scaled, centers = 4, nstart = 25)

customers$segment <- kmeans_model$cluster

#Profile segments
segment_profile <- customers %>%
  group_by(segment) %>%
  summarise(
    avg_spend = mean(total_spend_12m),
    avg_aov = mean(avg_order_value),
    freq = mean(num_transactions_12m),
    visits = mean(online_visits),
    engagement = mean(email_click_rate),
    usage = mean(avg_usage_minutes),
    recency = mean(recency_days),
    support = mean(num_support_tickets),
    satisfaction = mean(satisfaction_score),
    churn_rate = mean(churned),
    clv = mean(clv_net)
  )

segment_profile

#Journey path data
head(journeys$path, 10)

#Clean paths
journeys_clean <- journeys %>%
  mutate(path_list = str_split(path, " > "))

#1st touch attribution
journeys_clean <- journeys_clean %>%
  mutate(first_touch = map_chr(path_list, 1))

first_touch_summary <- journeys_clean %>%
  group_by(first_touch) %>%
  summarise(
    conversions = sum(conversions),
    revenue = sum(revenue)
  ) %>%
  arrange(desc(revenue))

first_touch_summary

#Last touch attribution
journeys_clean <- journeys_clean %>%
  mutate(last_touch = map_chr(path_list, ~ tail(.x, 1)))

last_touch_summary <- journeys_clean %>%
  group_by(last_touch) %>%
  summarise(
    conversions = sum(conversions),
    revenue = sum(revenue)
  ) %>%
  arrange(desc(revenue))

last_touch_summary

#Multi-touch attribution
multi_touch <- journeys_clean %>%
  mutate(n_touches = map_int(path_list, length)) %>%
  unnest(path_list) %>%
  group_by(path_list) %>%
  summarise(
    revenue = sum(revenue / n_touches),
    conversions = sum(conversions / n_touches)
  ) %>%
  arrange(desc(revenue))

multi_touch

#MMM and budget allocation
model <- lm(
  sales_k ~ tv_spend_k + search_spend_k + social_spend_k +
    display_spend_k + email_spend_k +
    price_index + promotion + competitor_price_index,
  data = weekly_marketing
)

summary(model)

#Pricing and promo
price_model <- lm(
  log(sales_k) ~ log(price_index) + promotion,
  data = weekly_marketing
)

summary(price_model)

#Churn and retention
churn_model <- glm(
  churned ~ total_spend_12m + num_transactions_12m + recency_days +
    satisfaction_score + num_support_tickets + email_click_rate,
  data = customers,
  family = "binomial"
)

summary(churn_model)

#Text analysis
library(tidytext)

reviews_clean <- reviews %>%
  unnest_tokens(word, review)

word_counts <- reviews_clean %>%
  count(word, sort = TRUE)

head(word_counts, 20)
# clean
data("stop_words")

reviews_clean <- reviews %>%
  unnest_tokens(word, review) %>%
  anti_join(stop_words, by = "word")

word_counts <- reviews_clean %>%
  count(word, sort = TRUE)

head(word_counts, 20)

#Forecasting
library(forecast)

ts_data <- ts(demand_ts$units_sold, frequency = 52)

model_arima <- auto.arima(ts_data)

forecast_values <- forecast(model_arima, h = 12)

plot(forecast_values)
forecast_values

#Export to use in Tableau
write.csv(customers, "customers_with_segments.csv", row.names = FALSE)
