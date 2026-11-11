# Rebuild the tables and figures from the archived Radiance Light Trends exports.
# Run from the repository root with: Rscript analysis.R

cities <- c("Aleppo", "Homs", "Damascus")
analysis_years <- 2024:2026
first_month <- as.Date("2012-04-01")
last_month <- as.Date("2026-08-01")
export_columns <- c("rasterColumn", "count", "sum", "mean", "sum_area_weighted")

read_city <- function(city) {
  file <- file.path("data", paste0(tolower(city), "-viirs.csv"))
  raw <- read.csv(file, na.strings = c("", "NA"), check.names = FALSE)
  stopifnot(identical(names(raw), export_columns), !anyDuplicated(raw$rasterColumn))

  # Keep one instrument throughout. The source sometimes substitutes other
  # satellites, including NOAA-20 in August 2022 and NOAA-21 in November 2025.
  npp <- raw[grepl("^viirs_npp_[0-9]{6}$", raw$rasterColumn), ]
  date <- as.Date(paste0(sub("^viirs_npp_", "", npp$rasterColumn), "01"), "%Y%m%d")
  stopifnot(length(date) > 0, !anyNA(date), !anyDuplicated(date))

  calendar <- seq(first_month, last_month, by = "month")
  index <- match(calendar, date)
  count <- npp$count[index]
  radiance <- npp$mean[index]
  observed <- is.finite(radiance) & is.finite(count) & count > 0
  radiance[!observed] <- NA_real_
  data.frame(
    city = city,
    date = calendar,
    year = as.integer(format(calendar, "%Y")),
    month = as.integer(format(calendar, "%m")),
    pixels = count,
    radiance = radiance
  )
}

monthly <- do.call(rbind, lapply(cities, read_city))
write.csv(monthly, "data/monthly-npp.csv", row.names = FALSE, na = "")

# Intersect calendar months with usable data in every city-year.
matched_months <- function(data, years, allowed = 1:12) {
  eligible <- subset(data, year %in% years & month %in% allowed)
  available <- split(eligible, list(eligible$city, eligible$year))
  stopifnot(length(available) == length(cities) * length(years))
  sort(Reduce(intersect, lapply(available, function(x) x$month[is.finite(x$radiance)])))
}

latest_month <- as.integer(format(last_month, "%m"))
common <- matched_months(monthly, analysis_years, seq_len(latest_month))
matched <- subset(monthly, year %in% analysis_years & month %in% common)
stopifnot(length(common) > 0, nrow(matched) == length(cities) * length(analysis_years) * length(common))

means <- aggregate(radiance ~ city + year, matched, mean)
names(means)[3] <- "mean_radiance"
means$months_observed <- length(common)
means$calendar_months <- paste(month.abb[common], collapse = " ")
baseline <- setNames(means$mean_radiance[means$year == 2024], means$city[means$year == 2024])
stopifnot(all(baseline > 0))
means$pct_vs_2024 <- 100 * (means$mean_radiance / baseline[means$city] - 1)
means <- means[order(match(means$city, cities), means$year), ]
write.csv(means, "data/matched-means.csv", row.names = FALSE)

compare_years <- function(city, earlier, later, months, comparison) {
  stopifnot(length(months) > 0)
  window <- monthly[monthly$city == city & monthly$month %in% months, ]
  before <- window[window$year == earlier, ]
  after <- window[window$year == later, ]
  before <- before[match(months, before$month), ]
  after <- after[match(months, after$month), ]
  stopifnot(all(is.finite(before$radiance)), all(is.finite(after$radiance)),
            all(before$radiance > 0))
  pct_by_month <- 100 * (after$radiance / before$radiance - 1)
  data.frame(
    city = city,
    comparison = comparison,
    earlier_year = earlier,
    later_year = later,
    calendar_months = paste(month.abb[months], collapse = " "),
    n_months = length(months),
    pct_change_in_means = 100 * (mean(after$radiance) / mean(before$radiance) - 1),
    months_brighter = sum(after$radiance > before$radiance),
    min_monthly_pct = min(pct_by_month),
    max_monthly_pct = max(pct_by_month)
  )
}

winter <- matched_months(monthly, analysis_years, 1:4)
late_2025 <- matched_months(monthly, 2024:2025, 8:10)
checks <- do.call(rbind, lapply(cities, function(city) {
  rbind(
    compare_years(city, 2024, 2026, common, "Main comparison"),
    compare_years(city, 2024, 2026, winter, "January through April"),
    compare_years(city, 2024, 2025, late_2025, "August through October"),
    compare_years(city, 2025, 2026, common, "Change since 2025")
  )
}))
write.csv(checks, "data/comparison-checks.csv", row.names = FALSE)
print(means, row.names = FALSE)
print(checks[, c("city", "comparison", "n_months", "pct_change_in_means", "months_brighter")],
      row.names = FALSE)

# Figure theme
background <- "#101C2A"
foreground <- "#F3F5FA"
muted <- "#ADC0D0"
grid_color <- "#2C3D4E"
accent <- c(Aleppo = "#FFC570", Homs = "#6BD9BD", Damascus = "#BEB7F6")
start_figure <- function(file, height) {
  png(file, width = 1600, height = height, res = 160, type = "cairo", bg = background)
  par(bg = background, fg = foreground, col.axis = muted, col.lab = muted,
      family = "sans", bty = "n", las = 1, xaxs = "i", yaxs = "i")
}

figure_text <- function(x, y, label, cex, col = foreground, font = 1) {
  par(fig = c(0, 1, 0, 1), new = TRUE, mar = rep(0, 4))
  plot.new()
  text(x, y, label, adj = c(0, 0.5), cex = cex, col = col, font = font)
}

credit <- "Source: EOG, Colorado School of Mines. Suomi NPP VIIRS DNB via Radiance Light Trends."

# Figure 1. One fixed calendar month spanning the wartime and recent periods.
august <- subset(monthly, city == "Aleppo" & month == 8)
start_figure("aleppo-in-august.png", 810)
par(fig = c(0.08, 0.97, 0.14, 0.83), mar = c(2, 3.4, 1, 0.5))
plot(august$year, august$radiance, type = "n", axes = FALSE,
     xlim = c(2011.6, 2026.6), ylim = c(0, 33), xlab = "", ylab = "")
rect(2012.6, 0, 2014.4, 33, col = "#1A2B3D", border = NA)
abline(h = seq(0, 30, 10), col = grid_color, lwd = 1)
axis(2, at = seq(0, 30, 10), tick = FALSE, cex.axis = 0.85, line = -0.35)
axis(1, at = seq(2012, 2026, 2), tick = FALSE, cex.axis = 0.85, line = -0.35)
lines(august$year, august$radiance, lwd = 2.4, col = accent["Aleppo"])
points(august$year, august$radiance, pch = 19, cex = 1.05, col = accent["Aleppo"])
key <- subset(august, year %in% c(2012, 2014, 2026))
text(key$year, key$radiance + 2.5, sprintf("%.1f", key$radiance),
     col = foreground, cex = 0.94, font = 2, xpd = NA)
text(2013.5, 30, "2013–14", col = muted, cex = 0.8, font = 2)
figure_text(0.085, 0.921, "Aleppo dimmed during the war. It is brighter again.", 1.61, font = 2)
figure_text(0.085, 0.868, "August mean radiance in the same city window, nW/cm²/sr", 0.99, muted)
figure_text(0.085, 0.072, paste(credit, "•  Gaps indicate missing Suomi NPP readings"), 0.74, muted)
invisible(dev.off())

# Figure 2. Same vertical scale and no interpolation across missing months.
recent <- subset(monthly, date >= as.Date("2024-01-01"))
dates <- c(seq(as.Date("2024-01-01"), last_month, by = "4 months"), last_month)
transition <- as.Date("2024-12-08")
revocation <- as.Date("2025-07-01")
start_figure("three-cities-monthly.png", 1170)
panel_top <- c(0.81, 0.574, 0.338)
for (i in seq_along(cities)) {
  city <- cities[i]
  d <- recent[recent$city == city, ]
  par(fig = c(0.086, 0.97, panel_top[i] - 0.222, panel_top[i]), new = i > 1,
      mar = c(1.9, 3.45, 1.1, 0.7))
  plot(d$date, d$radiance, type = "n", axes = FALSE, xlab = "", ylab = "",
       xlim = c(as.Date("2023-12-22"), as.Date("2026-08-20")), ylim = c(0, 40))
  abline(h = seq(0, 40, 10), col = grid_color)
  abline(v = c(transition, revocation), col = "#8497A8", lty = 3, lwd = 1.2)
  axis(2, at = seq(0, 40, 10), tick = FALSE, line = -0.35, cex.axis = 0.77)
  if (i == length(cities)) {
    axis.Date(1, at = dates, format = "%b %Y", tick = FALSE, line = -0.3, cex.axis = 0.76)
  }
  lines(d$date, d$radiance, col = accent[city], lwd = 2.3)
  points(d$date, d$radiance, col = accent[city], pch = 19, cex = 0.7)
  text(as.Date("2024-01-08"), 35, city, adj = 0, cex = 1.03, col = accent[city], font = 2)
  if (i == 1L) {
    text(transition, 45, "Assad government falls", cex = 0.78, col = muted, xpd = NA)
    text(revocation, 45, "Broad U.S. sanctions end", cex = 0.78, col = muted, xpd = NA)
  }
}
figure_text(0.085, 0.935, "Three cities brightened sharply in 2026", 1.73, font = 2)
figure_text(0.085, 0.890, "Monthly mean radiance inside fixed city windows, nW/cm²/sr", 1.0, muted)
figure_text(0.085, 0.056, paste(credit, "•  Points mark available months"), 0.76, muted)
invisible(dev.off())

# Figure 3. Each dot is a matched calendar month, with its own 2024 denominator.
points_2024 <- subset(matched, year == 2024, select = c(city, month, radiance))
points_2026 <- subset(matched, year == 2026, select = c(city, month, radiance))
paired <- merge(points_2024, points_2026, by = c("city", "month"), suffixes = c("_2024", "_2026"))
paired$pct <- 100 * (paired$radiance_2026 / paired$radiance_2024 - 1)
main <- subset(checks, comparison == "Main comparison")
plot_limit <- 50 * ceiling(max(paired$pct) / 50)
start_figure("matched-months.png", 780)
par(fig = c(0.065, 0.97, 0.17, 0.79), mar = c(2.1, 5.7, 1.2, 0.8))
plot(c(0, plot_limit), c(0.7, 3.6), type = "n", axes = FALSE, xlab = "", ylab = "",
     xlim = c(0, plot_limit), ylim = c(0.65, 3.65))
abline(v = seq(0, plot_limit, 50), col = grid_color)
axis(1, at = seq(0, plot_limit, 50), labels = paste0(seq(0, plot_limit, 50), "%"),
     tick = FALSE, line = -0.35, cex.axis = 0.81)
axis(2, at = 3:1, labels = cities, tick = FALSE, line = 0.2, col.axis = foreground, cex.axis = 0.95)
for (i in seq_along(cities)) {
  city <- cities[i]
  y <- 4 - i
  values <- paired$pct[paired$city == city]
  offsets <- seq(-0.11, 0.11, length.out = length(values))
  center <- main$pct_change_in_means[main$city == city]
  segments(min(values), y, max(values), y, col = accent[city], lwd = 2)
  points(values, y + offsets, pch = 19, col = accent[city], cex = 1.12)
  points(center, y, pch = 23, bg = foreground, col = background, lwd = 1.15, cex = 1.8)
  text(center, y + 0.31, sprintf("+%.1f%%", center), col = foreground, cex = 0.9, font = 2)
}
figure_text(0.085, 0.918, "Every matched month was brighter than in 2024", 1.67, font = 2)
figure_text(0.085, 0.864, "Change from 2024 to 2026 in January, February, March, April and August", 0.97, muted)
figure_text(0.085, 0.096, "Each dot is one matched month. Diamonds show the change between five-month means.", 0.8, muted)
figure_text(0.085, 0.052, credit, 0.73, muted)
invisible(dev.off())
