# Data and methods

[Article](../README.md) · [R script](../analysis.R)

## Source and boundaries

The CSVs ending in `-viirs.csv` are unedited area exports from [Radiance Light Trends](https://lighttrends.lightpollutionmap.info/), retrieved November 11, 2026. They contain monthly VIIRS Day/Night Band radiance from the Earth Observation Group’s night-lights composites, with the app’s zero-point correction for background light. The exact analysis windows are saved as WGS84 polygons, in longitude–latitude order. Each is about 10 km by 10 km. The coordinates describe urban samples rather than administrative boundaries.

| City | Window center, lon / lat | WKT polygon | Raw export | Reported pixels per nonempty layer |
| --- | --- | --- | --- | ---: |
| Aleppo | 37.1601 / 36.2001 | [aleppo.wkt](aleppo.wkt) | [aleppo-viirs.csv](aleppo-viirs.csv) | 546 |
| Homs | 36.7100 / 34.7300 | [homs.wkt](homs.wkt) | [homs-viirs.csv](homs-viirs.csv) | 546 |
| Damascus | 36.2900 / 33.5100 | [damascus.wkt](damascus.wkt) | [damascus-viirs.csv](damascus-viirs.csv) | 572 |

To recreate an export, use the area analysis tool in Radiance Light Trends, upload the city’s WKT, and select **VIIRS DNB (zero point correction)**, **Monthly**, **Average radiance**, and **None** for the mask. Leave satellite series and months at their all-series and all-months defaults. The export here used the full year interval offered by the app. Generate the chart and export **data** as **CSV**. Use the archived files to reproduce the results, since the live app can add or update observations.

## Variables and sample

| Field | Meaning |
| --- | --- |
| `rasterColumn` | App layer name. The suffix gives the year and month, and the prefix identifies the instrument. |
| `count` | App’s number of selected pixels for the layer. This field measures spatial support in the export. Cloud-free observation counts per pixel are unavailable here. |
| `mean` | Mean pixel radiance in nW/cm²/sr. This is the analysis outcome. |
| `sum`, `sum_area_weighted` | App totals provided in the raw export. The analysis uses the mean. |

The script restricts the data to `viirs_npp_YYYYMM` layers. The export includes alternate-satellite layers in August 2022 (NOAA-20) and November 2025 (NOAA-21). Excluding them leaves those months blank in the Suomi NPP series. Months with absent or unusable layers remain missing. The script keeps dates from April 2012 through August 2026 and adds one row per city and calendar month, even where a reading is missing. The regular early-summer gaps are consistent with the seasonal coverage limits of monthly night-light composites. Pixel counts alone cannot verify the number of cloud-free overpasses. [EOG product documentation](https://eogdata.mines.edu/products/vnl/) · [Monthly VIIRS catalog and coverage notes](https://developers.google.com/earth-engine/datasets/catalog/NOAA_VIIRS_DNB_MONTHLY_V1_VCMCFG).

For the recent comparison, the script selects calendar months from January through August that have an observed mean in all three cities in each of 2024, 2025, and 2026. It gives each retained month equal weight. It reports percentage change as 100 × (later mean / earlier mean − 1). The figure with dots uses that same formula for each individual calendar month. Its diamonds use the five-month means, so they can differ from a simple average of the five dots.

## Generated tables

| File | Rows represent | Contents |
| --- | --- | --- |
| [monthly-npp.csv](monthly-npp.csv) | City × calendar month | Date, year, month, reported pixel count, and mean radiance. |
| [matched-means.csv](matched-means.csv) | City × year, 2024–26 | Mean radiance for shared months, number and names of months, and percent change versus 2024. |
| [comparison-checks.csv](comparison-checks.csv) | City × comparison | Included months, change in means, count of brighter months, and range of month-specific percent changes. The range describes observed variation across months. |

## Attribution

This project uses VIIRS Nighttime Lights data produced by the Earth Observation Group, Payne Institute for Public Policy, Colorado School of Mines. EOG VNL data are distributed under [CC BY 4.0](https://eogdata.mines.edu/files/EOG_products_CC_License.pdf). The analysis filters and aggregates the archived exports and renders derived figures. The source files are credited below.

- Elvidge, C. D., Baugh, K., Zhizhin, M., Hsu, F.-C., and Ghosh, T. (2017). *VIIRS night-time lights*. [DOI](https://doi.org/10.1080/01431161.2017.1342050).
- Stare, J., and Kyba, C. C. M. (2019). *Radiance Light Trends*. GFZ Data Services. [DOI](https://doi.org/10.5880/GFZ.1.4.2019.001).
- Coesfeld, J., Kuester, T., Kuechly, H. U., and Kyba, C. C. M. (2020). *Reducing variability and removing natural light from nighttime satellite imagery*. [DOI](https://doi.org/10.3390/s20113287).
