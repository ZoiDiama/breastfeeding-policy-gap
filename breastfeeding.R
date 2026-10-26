# Six months of breastfeeding, three months of paid leave
# 52 squares = the 52 weeks of a baby's first year, laid out like a calendar.
# In the first 26 weeks (the six months of exclusive breastfeeding WHO
# recommends) the pink part of each square shows the share of babies of that
# age who are fed only breast milk. A bracket shows the weeks of paid leave
# in the typical country.
# Data: UNICEF Global database on infant and young child feeding (2023);
#       World Bank, length of paid maternity and shared parental leave (2023)

library(tidyverse)
library(readxl)
library(ggtext)
library(showtext)
font_add_google("Playfair Display", family = "serif_t")
font_add_google("Lato", family = "lato")
showtext_auto(); showtext_opts(dpi = 288)

bg <- "#F7F2EE"; ink <- "#1E1A1C"; muted <- "#6B5A5F"
pink <- "#B0306A"; cell <- "#EADBD6"; rest <- "#E6E1DE"

# DATA ----------------------------------------------------------------------
# Paid leave a mother can take = maternity leave + shared parental leave
leave <- read_csv("data/PaidLeave.csv", show_col_types = FALSE) |>
  filter(Year == 2023) |>
  transmute(country = `Country Name`, type = Disaggregation, days = Value) |>
  pivot_wider(names_from = type, values_from = days) |>
  mutate(weeks = (female + total) / 7)
typical <- median(leave$weeks)                                  # 14 weeks
n_six   <- sum(leave$weeks >= 26); n_all <- nrow(leave)
n_upto  <- sum(leave$weeks <= typical)                         # countries paying 14 weeks or less

# Exclusive breastfeeding by baby's age, latest survey of each country
ebf <- read_excel("data/ExclusiveBF_2023.xlsx", sheet = "Exclusive Breastfeeding (2)") |>
  filter(LatestSource == "Latest Source") |>
  transmute(country = CountryName, year = as.numeric(CMRS_year),
            m01 = as.numeric(month_0_1_r), m23 = as.numeric(month_2_3_r), m45 = as.numeric(month_4_5_r)) |>
  drop_na()
n_ebf  <- nrow(ebf)
n_fall <- sum(ebf$m45 < ebf$m01)
yrs    <- range(ebf$year)
ages <- tibble(age = c("0–1 months", "2–3 months", "4–5 months"), wk = c("weeks 1–8", "weeks 9–17", "weeks 18–26"),
               rate = c(median(ebf$m01), median(ebf$m23), median(ebf$m45)),
               from = c(1, 9, 18), to = c(8, 17, 26))             # weeks of the first six months

# CALENDAR: 2 rows of 26 weeks --------------------------------------------------
gap <- 2.2                                                      # space between the two rows
cal <- tibble(w = 1:52) |>
  mutate(x = (w - 1) %% 26, y = -((w - 1) %/% 26) * gap) |>
  left_join(ages |> rowwise() |> reframe(w = from:to, rate = rate), by = "w")
s <- 0.42                                                       # half the side of a square

band_lab <- ages |> mutate(
  x = (from + to) / 2 - 1,
  label = paste0("<span style='font-family:serif_t;font-size:20pt;color:", pink, "'>", round(rate),
                 "%</span><br>of babies aged ", age, "<br>(", wk, ") fed only breast milk",
                 if_else(age == "4–5 months", paste0("<br>**Lower than at 0–1 months in ", n_fall, " of ", n_ebf,
                                                     " countries**"), "")))

p <- ggplot() +
  # rest of the year
  geom_rect(data = filter(cal, w > 26), aes(xmin = x - s, xmax = x + s, ymin = y - s, ymax = y + s),
            fill = rest) +
  # first six months: empty square, pink part = share of babies fed only breast milk
  geom_rect(data = filter(cal, w <= 26), aes(xmin = x - s, xmax = x + s, ymin = y - s, ymax = y + s),
            fill = cell) +
  geom_rect(data = filter(cal, w <= 26),
            aes(xmin = x - s, xmax = x + s, ymin = y - s, ymax = y - s + 2 * s * rate / 100), fill = pink) +
  geom_text(data = cal, aes(x - s + 0.06, y + s - 0.06, label = w), family = "lato", size = 1.9,
            colour = "#7D6F6B", hjust = 0, vjust = 1) +
  # age bands: a line at the end of each band, the label right-aligned against it
  geom_segment(data = ages, aes(x = to - 1 + 0.5, xend = to - 1 + 0.5, y = -s, yend = 2.55),
               colour = muted, linewidth = 0.35) +
  geom_richtext(data = band_lab, aes(to - 1 + 0.35, 2.55, label = label), hjust = 1, vjust = 1,
                family = "lato", size = 2.9, colour = muted, fill = NA, label.colour = NA, lineheight = 1.15,
                label.padding = unit(c(0, 2, 0, 0), "pt")) +
  # paid leave bracket under the first row
  annotate("segment", x = -s, xend = typical - 1 + s, y = -0.68, yend = -0.68, colour = ink, linewidth = 1.2) +
  annotate("richtext", x = -s, y = -0.8, hjust = 0, vjust = 1, family = "lato", size = 3, colour = ink,
           fill = NA, label.colour = NA, lineheight = 1.2,
           label = paste0("**Paid leave: ", typical, " weeks** (about three months) in the typical country, 2023.<br>",
                          "<span style='color:", pink, "'>**", n_upto, " of ", n_all, "**</span> countries pay ", typical, " weeks or less")) +
  annotate("segment", x = typical - s, xend = 25 + s, y = -0.68, yend = -0.68, colour = ink,
           linewidth = 0.5, linetype = "22") +
  annotate("richtext", x = typical - s, y = -0.8, hjust = 0, vjust = 1, family = "lato", size = 3, colour = ink,
           fill = NA, label.colour = NA, lineheight = 1.2,
           label = paste0("**No paid leave: ", 26 - typical, " weeks** of the six months.<br>Only <span style='color:", pink,
                          "'>**", n_six, " of ", n_all, "**</span> countries pay leave that lasts to week 26")) +
  # row labels
  annotate("richtext", x = 25.75, y = 0, hjust = 0, family = "lato", size = 3, colour = ink, fill = NA,
           label.colour = NA, lineheight = 1.2,
           label = "**Weeks 1–26**<br>the six months WHO<br>recommends feeding<br>only breast milk") +
  annotate("richtext", x = 25.75, y = -gap, hjust = 0, family = "lato", size = 3, colour = muted, fill = NA,
           label.colour = NA, lineheight = 1.2, label = "**Weeks 27–52**<br>the rest of the<br>first year") +
  # how to read a square
  annotate("rect", xmin = -s, xmax = s, ymin = -3.9 - s, ymax = -3.9 + s, fill = cell) +
  annotate("rect", xmin = -s, xmax = s, ymin = -3.9 - s, ymax = -3.9 - s + 2 * s * 0.6, fill = pink) +
  annotate("richtext", x = 0.75, y = -3.9, hjust = 0, family = "lato", size = 3, colour = muted, fill = NA,
           label.colour = NA, lineheight = 1.25,
           label = paste0("**How to read it:** each square is one week of a baby's first year.<br>",
                          "The <span style='color:", pink, "'>**pink part**</span> is the share of babies of that ",
                          "age fed only breast milk (here 60%).")) +
  scale_x_continuous(limits = c(-0.5, 28.8), expand = c(0, 0)) +
  scale_y_continuous(limits = c(-4.6, 2.75), expand = c(0, 0)) +
  coord_fixed(clip = "off") +
  labs(
    title = "Asked to breastfeed for six months, paid for three (2023)",
    subtitle = paste0(
      "WHO recommends feeding babies only breast milk for their first six months (26 weeks). Most mothers start: ",
      "in household surveys in ", n_ebf, " countries (", yrs[1], "–", yrs[2], "), ", round(ages$rate[1]),
      "% of babies aged 0–1 months were fed only breast milk. At 4–5 months, ", round(ages$rate[3]),
      "% were. In 2023, national laws in the typical country gave mothers ", typical,
      " weeks of paid leave, about three months. Breastfeeding needs time and support, not only a mother's will."),
    caption = paste0(
      "**Breastfeeding:** UNICEF Global database on infant and young child feeding (October 2023). Latest nationally ",
      "representative household survey in each country, mostly MICS and DHS, in which mothers are asked everything their ",
      "baby ate or drank the day before. Median of ", n_ebf, " countries with results by age, ", yrs[1], "–", yrs[2],
      ", mostly low and middle-income. Each age group is different babies interviewed at the same time, not the same ",
      "babies followed over time.<br>",
      "**Paid leave:** World Bank. Weeks of paid maternity leave plus shared parental leave a mother can take under ",
      "national law, ", n_all, " economies, 2023. It is what the law provides, not what every mother receives: women in ",
      "informal work are often not covered. The two happen at the same time; the data do not show that one causes the other.<br>",
      "**Creator:** Zoi Diamantakou")) +
  theme_void(base_family = "lato") +
  theme(plot.background = element_rect(fill = bg, colour = NA),
        plot.title = element_textbox_simple(family = "serif_t", size = 25, colour = ink, lineheight = 1.05,
                                            margin = margin(b = 14)),
        plot.subtitle = element_textbox_simple(size = 11.5, colour = muted, lineheight = 1.4, margin = margin(b = 16)),
        plot.caption = element_textbox_simple(size = 7.5, colour = muted, lineheight = 1.4, margin = margin(t = 12)),
        plot.title.position = "plot", plot.caption.position = "plot",
        plot.margin = margin(36, 50, 30, 50))

ggsave("breastfeeding.png", p, width = 11.5, height = 6.6, dpi = 288, bg = bg)
