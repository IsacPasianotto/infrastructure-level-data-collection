# SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
# SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>
#
# SPDX-License-Identifier: GPL-3.0-or-later

# pip install polars[rt64]
# ---- Imports -----
import os
import polars as pl
import numpy as np
import gc
from pathlib import Path
import subprocess


# ---- Costants -----
PRJ_ROOT_DIR = Path(
    subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"],
        text=True
    ).strip()
)
DATA_DIR = Path(PRJ_ROOT_DIR, "data")
TABLES = os.listdir(DATA_DIR)


# ---- Functions -----

def print_separator(table=None):
    if table:
        print(f"\n{'=' * 20} {table.upper()} {'=' * 20}\n")
    else :
        print("\n" + "-" * 50 + "\n")
    
def get_stats_lazy(loaded_frame, timestamp_col="timestamp"):
    return (
        loaded_frame
        .group_by_dynamic(
            index_column=timestamp_col,
            every="1s",
            period="1s"
        )
        .agg(pl.len().alias("count"))
        .select([
            pl.col("count").mean().alias("mean"),
            pl.col("count").median().alias("median"),
            pl.col("count").quantile(0.25).alias("q25"),
            pl.col("count").quantile(0.75).alias("q75"),
            pl.col("count").min().alias("min"),
            pl.col("count").max().alias("max"),
            pl.col("count").std().alias("std"),
        ])
    )

def get_df_with_deltas(loaded_frame, timestamp_col="timestamp", time_round="1s"):
    return (
        loaded_frame
        .with_columns(
            (pl.col(timestamp_col) - pl.col(timestamp_col).dt.round(time_round))
            .abs()
            .alias("delta")
        )
        .drop_nulls()
    )
    
def get_delta_counts_lazy(df_with_deltas):
    return (
        df_with_deltas
        .group_by("delta")
        .agg(pl.len().alias("count"))
        .sort("delta")
    )
    
def get_delta_stats_lazy(df_with_deltas):
    return (
        df_with_deltas
        .select([
            pl.col("delta").mean().alias("mean"),
            pl.col("delta").median().alias("median"),
            pl.col("delta").quantile(0.25).alias("q25"),
            pl.col("delta").quantile(0.75).alias("q75"),
            pl.col("delta").min().alias("min"),
            pl.col("delta").max().alias("max"),
            pl.col("delta").std().alias("std"),
        ])
    )

# ----- Main logic -----

def main():
    for table in TABLES:
        if os.path.isdir(os.path.join(DATA_DIR, table)):
            
            print_separator(table)
            
            lf = pl.scan_parquet(f"{DATA_DIR}/{table}/*.parquet").select("timestamp").sort("timestamp")
            
            # ---- 1. Build all lazy graphs ----
            total_count_lazy = lf.select(pl.len())
            stats_lazy = get_stats_lazy(loaded_frame=lf, timestamp_col="timestamp")
            df_with_deltas = get_df_with_deltas(loaded_frame=lf, timestamp_col="timestamp", time_round="1s")
            delta_counts_lazy = get_delta_counts_lazy(df_with_deltas)
            delta_stats_lazy = get_delta_stats_lazy(df_with_deltas)

            # ---- 2. Execute all lazy graphs simultaneously
            collected_results = pl.collect_all([
                total_count_lazy,
                stats_lazy,
                delta_counts_lazy,
                delta_stats_lazy
            ])

            # ---- 3. Unpack the returned list of concrete DataFrames
            total_count_df, stats, delta_counts, delta_stats = collected_results
            total_count = total_count_df.item()
            
            # ---- 4. Print the results
            print(f"Table {table} has {total_count} rows")

            print("\nPer-second stats:")
            print(stats)

            print("\nDistance from rounded second (summary stats):")
            print(delta_stats)

            # ---- 5. Explicitly delete variables and force garbage collection
            del lf, df_with_deltas, total_count_lazy, stats_lazy, delta_counts_lazy, delta_stats_lazy
            del collected_results, total_count_df, stats, delta_counts, delta_stats
            gc.collect()

if __name__ == "__main__":
    main()