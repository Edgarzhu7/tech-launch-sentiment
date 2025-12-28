# (Optional personal link)  # https://github.com/edgarzhu7
# UChicago MADS Programming Supplement (Python)
# This script: 
# 1) Creates a small CSV 
# 2) Ingests it 
# 3) Manages data types 
# 4) Wrangles data 
# 5) Defines a reusable function 
# 6) Prints outputs 
# 7) Visualizes data 
# 8) Exports everything into a TWO-PAGE PDF (code + outputs + plot)

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from matplotlib.backends.backend_pdf import PdfPages
from textwrap import wrap
from datetime import datetime, timedelta
import os

# ------------------------------------------------------------------------------
# 0) Create a small CSV dataset to ingest
# ------------------------------------------------------------------------------
np.random.seed(42)
n = 120
dates = [datetime(2024, 1, 1) + timedelta(days=i) for i in range(n)]

df = pd.DataFrame({
    "date": dates,
    "user_id": np.random.randint(1000, 1050, size=n),
    "channel": np.random.choice(["organic", "ads", "referral"], size=n, p=[0.5, 0.3, 0.2]),
    "sessions": np.random.poisson(5, size=n).astype(int),
    "conversion_rate": np.round(np.random.beta(2, 10, size=n), 3),
    "avg_order_value": np.round(np.random.normal(45, 8, size=n).clip(5, 200), 2),
})

csv_path = "mini_ecommerce.csv"
df.to_csv(csv_path, index=False)

# ------------------------------------------------------------------------------
# 1) Ingest CSV and manage data types
# ------------------------------------------------------------------------------
raw = pd.read_csv(csv_path)

raw["date"] = pd.to_datetime(raw["date"])
raw["user_id"] = raw["user_id"].astype("int64")
raw["channel"] = raw["channel"].astype("category")
raw["sessions"] = raw["sessions"].astype("int64")
raw["conversion_rate"] = raw["conversion_rate"].astype("float64")
raw["avg_order_value"] = raw["avg_order_value"].astype("float64")

# ------------------------------------------------------------------------------
# 2) Data wrangling
# ------------------------------------------------------------------------------
raw["orders"] = (raw["sessions"] * raw["conversion_rate"]).round(2)
raw["revenue"] = (raw["orders"] * raw["avg_order_value"]).round(2)

daily = raw.groupby("date", as_index=False).agg(
    sessions=("sessions", "sum"),
    orders=("orders", "sum"),
    revenue=("revenue", "sum"),
)

daily["revenue_lag"] = daily["revenue"].shift(1)
daily["rev_growth"] = (daily["revenue"] / daily["revenue_lag"] - 1.0).replace([np.inf, -np.inf], np.nan)

# ------------------------------------------------------------------------------
# 3) A reusable analysis function
# ------------------------------------------------------------------------------
def summarize_channel_performance(frame: pd.DataFrame, top_k: int = 2) -> pd.DataFrame:
    """
    Summarize performance by acquisition channel and return top_k channels based on revenue.
    Includes revenue share and conversion-rate lift vs overall mean.
    """
    grp = frame.groupby("channel", as_index=False).agg(
        sessions=("sessions", "sum"),
        orders=("orders", "sum"),
        revenue=("revenue", "sum"),
        aov=("avg_order_value", "mean"),
        cr=("conversion_rate", "mean"),
    )

    overall_rev = grp["revenue"].sum()
    overall_cr = frame["conversion_rate"].mean()

    grp["revenue_share"] = grp["revenue"] / overall_rev
    grp["cr_lift_vs_overall"] = grp["cr"] / overall_cr - 1.0

    return grp.sort_values("revenue", ascending=False).head(top_k).round(4)

channel_summary = summarize_channel_performance(raw, top_k=3)

# Previews for PDF output
head_preview = raw.head(5).to_string(index=False)
daily_preview = daily.head(7)[["date", "sessions", "orders", "revenue", "rev_growth"]].to_string(index=False)
summary_preview = channel_summary.to_string(index=False)

# ------------------------------------------------------------------------------
# 4) Visualization (no custom colors, as required)
# ------------------------------------------------------------------------------
fig_plot = plt.figure(figsize=(7.5, 4.2))
ax = plt.gca()

ax.plot(daily["date"], daily["revenue"])
ax.set_title("Daily Revenue")
ax.set_xlabel("Date")
ax.set_ylabel("Revenue")

# Fix overlapping date labels
locator = mdates.AutoDateLocator(minticks=5, maxticks=8)
formatter = mdates.ConciseDateFormatter(locator)
ax.xaxis.set_major_locator(locator)
ax.xaxis.set_major_formatter(formatter)

plt.tight_layout()
plot_path = "daily_revenue_plot.png"
fig_plot.savefig(plot_path, dpi=200)
plt.close(fig_plot)

# ------------------------------------------------------------------------------
# 5) Helper to add text pages to PDF
# ------------------------------------------------------------------------------
def add_text_page(pdf: PdfPages, title: str, content: str):
    fig = plt.figure(figsize=(8.5, 11))
    ax = fig.add_axes([0, 0, 1, 1])
    ax.axis("off")

    ax.text(0.05, 0.965, title, fontsize=12, fontweight="bold", family="monospace")

    wrapped_lines = []
    for line in content.splitlines():
        wrapped_lines += wrap(line, width=95, replace_whitespace=False, drop_whitespace=False) or [""]

    y = 0.94
    for line in wrapped_lines:
        if y < 0.06:
            break
        ax.text(0.05, y, line, fontsize=9, family="monospace")
        y -= 0.017

    pdf.savefig(fig, dpi=200)
    plt.close(fig)

# ------------------------------------------------------------------------------
# 6) Build the two-page PDF
# ------------------------------------------------------------------------------
pdf_path = "uchicago_code_snippet.pdf"

with PdfPages(pdf_path) as pp:

    # ---------------- Page 1: Code (imports, ingest, dtypes, wrangle, function)
    page1 = """# Personal link: https://github.com/edgarzhu7
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from datetime import datetime, timedelta

# Ingest CSV
raw = pd.read_csv("mini_ecommerce.csv")

# Manage data types
raw["date"] = pd.to_datetime(raw["date"])
raw["user_id"] = raw["user_id"].astype("int64")
raw["channel"] = raw["channel"].astype("category")
raw["sessions"] = raw["sessions"].astype("int64")
raw["conversion_rate"] = raw["conversion_rate"].astype("float64")
raw["avg_order_value"] = raw["avg_order_value"].astype("float64")

# Wrangle
raw["orders"] = (raw["sessions"] * raw["conversion_rate"]).round(2)
raw["revenue"] = (raw["orders"] * raw["avg_order_value"]).round(2)

daily = raw.groupby("date", as_index=False).agg(
    sessions=("sessions","sum"),
    orders=("orders","sum"),
    revenue=("revenue","sum"),
)

daily["revenue_lag"] = daily["revenue"].shift(1)
daily["rev_growth"] = (daily["revenue"]/daily["revenue_lag"] - 1.0)

# Custom function
def summarize_channel_performance(frame: pd.DataFrame, top_k: int = 2) -> pd.DataFrame:
    grp = frame.groupby("channel", as_index=False).agg(
        sessions=("sessions","sum"),
        orders=("orders","sum"),
        revenue=("revenue","sum"),
        aov=("avg_order_value","mean"),
        cr=("conversion_rate","mean"),
    )
    overall_rev = grp["revenue"].sum()
    overall_cr = frame["conversion_rate"].mean()
    grp["revenue_share"] = grp["revenue"] / overall_rev
    grp["cr_lift_vs_overall"] = grp["cr"] / overall_cr - 1.0
    return grp.sort_values("revenue", ascending=False).head(top_k).round(4)
"""
    add_text_page(pp, "Python Code Snippet — Page 1", page1)

    # ---------------- Page 2: Output + Plot
    page2 = f"""# Use function + print outputs
channel_summary = summarize_channel_performance(raw, top_k=3)

print("==== Head Preview ====")
print(raw.head(5))

print("\\n==== Daily Aggregation Preview ====")
print(daily.head(7)[["date","sessions","orders","revenue","rev_growth"]])

print("\\n==== Channel Summary (Top 3) ====")
print(channel_summary)

# Visualization
plt.plot(daily["date"], daily["revenue"])
plt.title("Daily Revenue")
plt.show()

# --- Program Output ---
==== Head Preview ====
{head_preview}

==== Daily Aggregation Preview ====
{daily_preview}

==== Channel Summary (Top 3) ====
{summary_preview}
"""

    # Draw upper text + lower plot on same page
    fig2 = plt.figure(figsize=(8.5, 11))
    ax2 = fig2.add_axes([0, 0, 1, 1])
    ax2.axis("off")
    ax2.text(0.05, 0.965, "Python Code + Outputs — Page 2", fontsize=12,
             fontweight="bold", family="monospace")

    wrapped = []
    for line in page2.splitlines():
        wrapped += wrap(line, width=95, replace_whitespace=False, drop_whitespace=False) or [""]

    y = 0.94
    for w in wrapped:
        if y < 0.37:
            break
        ax2.text(0.05, y, w, fontsize=9, family="monospace")
        y -= 0.017

    img = plt.imread(plot_path)
    ax_img = fig2.add_axes([0.1, 0.06, 0.8, 0.28])
    ax_img.imshow(img)
    ax_img.axis("off")

    pp.savefig(fig2, dpi=200)
    plt.close(fig2)

print("Saved:", pdf_path)
print("CSV:", csv_path)
print("Plot:", plot_path)
