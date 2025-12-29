# Smartphone Launches, Sentiment, and Stock Reactions

**FIN 342 Final Project**  
**Author:** Edgar Zhu

## Project Overview

This project investigates the relationship between smartphone launch events, media sentiment, and stock market reactions for Apple Inc. (AAPL) and Alphabet Inc. (GOOGL). Using event study methodology, the analysis examines whether sentiment scores from news coverage of product launches predict cumulative abnormal returns (CARs) in the stock market.

## Research Question

How do media sentiment scores surrounding smartphone launch events relate to stock market reactions, as measured by cumulative abnormal returns? Does sentiment predict stock returns, and does this relationship vary by firm size or event window?

## Data Sources

The project integrates multiple financial and news datasets:

- **CRSP Daily Stock Data**: Daily returns, prices, and shares outstanding for AAPL and GOOGL
- **Fama-French Daily Factors**: Market risk premium (MKT-RF), risk-free rate (RF), and market return (MKT)
- **RavenPack Launch Events**: Product launch events with sentiment scores (`launch_raw.csv`)
- **Compustat Fundamentals**: Quarterly financial data for market equity calculations

## Project Structure

```
tech-launch-sentiment/
├── Project code.sas              # Main SAS analysis script
├── summary.py                    # Python script for data summary statistics
├── mads.py                       # MADS programming supplement (separate exercise)
│
├── Data Files (CSV)
├── appl.csv                      # Apple CRSP daily data
├── googl.csv                     # Google CRSP daily data
├── ff_daily.csv                  # Fama-French daily factors
├── compustat.csv                 # Compustat fundamentals
├── launch_raw.csv                # Raw RavenPack launch events
│
├── Intermediate SAS Datasets (.sas7bdat)
├── events_clean.sas7bdat         # Cleaned launch events
├── daily.sas7bdat                # Daily panel with returns and factors
├── car_m3_p3.sas7bdat            # CAR [-3,+3] window
├── car_m5_p5.sas7bdat            # CAR [-5,+5] window
├── car_m10_p10.sas7bdat          # CAR [-10,+10] window
├── car_final.sas7bdat            # Final analysis dataset
│
└── Output Files
    ├── results_report.pdf        # Main results report (tables, regressions, plots)
    ├── event_car_results.xlsx    # Event-level CAR results
    ├── daily_panel_with_factors.xlsx  # Daily panel data
    └── launch_events_cleaned.xlsx     # Cleaned launch events
```

## Methodology

### Event Study Framework

The analysis uses standard event study methodology:

1. **Event Windows**: Three symmetric windows around launch dates
   - [-3, +3] days (7-day window)
   - [-5, +5] days (11-day window)
   - [-10, +10] days (21-day window)

2. **Abnormal Returns**: Calculated using the market model with β = 1 simplification
   - `abnormal_return = return - risk_free_rate - market_risk_premium`

3. **Cumulative Abnormal Returns (CAR)**: Sum of abnormal returns over each event window

### Statistical Analysis

- **Descriptive Statistics**: Summary statistics and histograms for sentiment scores
- **t-tests**: Test whether mean CARs are significantly different from zero
- **Regression Analysis**: 
  - CAR regressed on sentiment and log market equity (firm size)
  - Separate regressions for AAPL, GOOGL, and pooled sample
  - Day-0 abnormal return regressions for immediate reaction analysis
- **Outlier Detection**: Flags for returns exceeding 3 standard deviations

## Setup and Requirements

### SAS Requirements

- SAS 9.4 or later
- Access to SAS/STAT and SAS/GRAPH procedures
- Update the `%let dir` macro variable in `Project code.sas` to point to your project directory

### Python Requirements

The Python scripts require:
- Python 3.7+
- pandas
- openpyxl (for Excel file reading)

#### Installing Python Dependencies

A virtual environment is recommended:

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # On macOS/Linux
# or
venv\Scripts\activate     # On Windows

# Install dependencies
pip install pandas openpyxl
```

## Running the Analysis

### 1. Main SAS Analysis

1. Update the directory path in `Project code.sas`:
   ```sas
   %let dir = /path/to/your/project/directory;
   libname proj "/path/to/your/project/directory";
   ```

2. Run the SAS script:
   ```sas
   %include "Project code.sas";
   ```
   Or execute it directly in SAS Studio/Enterprise Guide.

3. The script will:
   - Import and clean all data files
   - Calculate abnormal returns and CARs
   - Perform statistical tests and regressions
   - Generate `results_report.pdf` with all outputs
   - Export results to Excel/CSV files

### 2. Python Data Summary

Run the summary script to generate descriptive statistics for all data files:

```bash
# Activate virtual environment if using one
source venv/bin/activate

# Run summary script
python summary.py
```

This will:
- Process all CSV files (AAPL, GOOGL, FF_Factors, Compustat)
- Process all sheets in `launch_events_cleaned.xlsx`
- Generate `summary_statistics.csv` with combined statistics

## Key Outputs

### Results Report (`results_report.pdf`)

Contains:
- Sentiment score summary statistics and distribution
- t-tests for mean CAR = 0
- Regression results:
  - CAR on sentiment and size (AAPL only)
  - CAR on sentiment and size (GOOGL only)
  - CAR on sentiment and size (Pooled)
  - Day-0 abnormal return regressions
- Launch-day returns table with outlier flags

### Data Exports

- `event_car_results.xlsx`: Event-level CARs with sentiment and size controls
- `daily_panel_with_factors.xlsx`: Complete daily panel dataset
- `summary_statistics.csv`: Summary statistics for all input datasets

## Key Variables

### Event-Level Variables
- `firm`: Stock ticker (AAPL or GOOGL)
- `event_date`: Launch event date
- `sentiment`: RavenPack sentiment score
- `car_m3_p3`, `car_m5_p5`, `car_m10_p10`: Cumulative abnormal returns for each window
- `lme_final`: Log market equity (firm size control)

### Daily Panel Variables
- `ret`: Raw stock return
- `excess_ret`: Return minus risk-free rate
- `abn_ret`: Abnormal return (excess return minus market risk premium)
- `mktrf`: Market risk premium
- `rf`: Risk-free rate
- `mkt`: Market return

## Notes

- The analysis uses a simplified market model (β = 1) for abnormal return calculation. For more sophisticated analysis, consider estimating firm-specific betas.
- Event dates are matched to trading days; non-trading days are handled by finding the closest preceding trading day.
- Market equity is calculated from Compustat quarterly data when available, with CRSP daily data as fallback.

## Contact

For questions about this project, please contact Edgar Zhu.

---

**Course:** FIN 342  
**Institution:** University of Chicago (MADS Program)

