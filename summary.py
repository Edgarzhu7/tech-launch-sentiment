import pandas as pd
import os

# ====== File paths ======
DIR = ""  # use r"path" if needed

files = {
    "AAPL": DIR + "appl.csv",
    "GOOGL": DIR + "googl.csv",
    "FF_Factors": DIR + "ff_daily.csv",
    "Compustat": DIR + "compustat.csv",
}

excel_file = DIR + "launch_events_cleaned.xlsx"

# List to collect all summary dataframes
all_summaries = []

# ====== Helper function ======
def collect_summary(df, name):
    print(f"Processing: {name}...")
    
    # 1. Generate basic describe stats (fixes the datetime_is_numeric error)
    stats = df.describe(include='all')
    
    # 2. Add 'dtype' and 'missing' counts as new rows to the stats
    stats.loc['dtype'] = df.dtypes
    stats.loc['missing'] = df.isna().sum()
    
    # 3. Transpose so that Variables are rows and Stats (mean, count, etc) are columns
    # This makes it easier to combine datasets with different column names
    stats = stats.transpose()
    
    # 4. Add the dataset name as the first column
    stats.insert(0, 'dataset', name)
    
    # 5. Add the variable name (index) as a column
    stats.reset_index(inplace=True)
    stats.rename(columns={'index': 'variable'}, inplace=True)
    
    all_summaries.append(stats)

# ====== 1. CSV files ======
for name, path in files.items():
    try:
        df = pd.read_csv(path)
        collect_summary(df, name)
    except FileNotFoundError:
        print(f"⚠️ Warning: Could not find {path}")

# ====== 2. Excel (multiple sheets) ======
if os.path.exists(excel_file):
    print(f"Processing Excel: {excel_file}")
    xls = pd.ExcelFile(excel_file)
    for sheet in xls.sheet_names:
        df_sheet = pd.read_excel(excel_file, sheet_name=sheet)
        collect_summary(df_sheet, f"Launch_Events_{sheet}")
else:
    print(f"⚠️ Warning: Could not find {excel_file}")

# ====== 3. Combine and Save ======
if all_summaries:
    final_df = pd.concat(all_summaries, ignore_index=True)
    
    output_filename = "summary_statistics.csv"
    final_df.to_csv(output_filename, index=False)
    
    print("\n" + "="*70)
    print(f"✅ DONE! Statistics saved to: {output_filename}")
    print("="*70)
else:
    print("No data was processed.")