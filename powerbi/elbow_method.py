import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler

# === STYLE SETTINGS ===
plt.style.use('default')
plt.rcParams['figure.facecolor'] = 'none'          # Transparent figure background
plt.rcParams['axes.facecolor'] = 'none'            # Transparent axes background
plt.rcParams['axes.edgecolor'] = 'white'           # White axis border
plt.rcParams['axes.labelcolor'] = 'white'          # White labels
plt.rcParams['xtick.color'] = 'white'              # White x ticks
plt.rcParams['ytick.color'] = 'white'              # White y ticks
plt.rcParams['text.color'] = 'white'               # White text color
plt.rcParams['legend.edgecolor'] = 'white'         # White legend border
plt.rcParams['legend.labelcolor'] = 'white'        # White legend text
plt.rcParams['axes.titlepad'] = 15                 # Extra padding for title

# 1️⃣ Power BI dataset
df = dataset.copy()
df = df.dropna(subset=['value_2024_usd', 'urban_population_total', 'gdp_per_capita_usd'])

# 2️⃣ Select relevant columns
X = df[['value_2024_usd', 'urban_population_total', 'gdp_per_capita_usd']].values

# 3️⃣ Compute inertia for different values of k
inertias = []
k_values = range(1, min(11, len(X) + 1))

for k in k_values:
    kmeans = KMeans(n_clusters=k, init='k-means++', n_init=10, random_state=42, max_iter=300)
    kmeans.fit(X)
    inertias.append(kmeans.inertia_)

# 4️⃣ Calculate reduction rate (optional, for reference)
reduction_rates = []
for i in range(1, len(inertias)):
    reduction = (inertias[i-1] - inertias[i]) / inertias[i-1] * 100
    reduction_rates.append(reduction)

# 5️⃣ Create the Elbow Method plot (blue dots, no numeric labels)
plt.figure(figsize=(10, 6))
plt.plot(k_values, inertias, 'bo-', linewidth=2, markersize=8)  # Blue line with dots
plt.xlabel('Number of Clusters (k)', fontsize=12)
plt.ylabel('Inertia', fontsize=12)
plt.title('Elbow Method for Determining the Optimal Number of Clusters', fontsize=14, color='white')
plt.grid(True, linestyle='--', alpha=0.6, color='white')  # White gridlines

# 🔴 Highlight the "elbow" (k=2)
if len(k_values) > 1:
    plt.scatter(2, inertias[1], s=200, c='white', marker='o', label='Elbow Point (k=2)')
    plt.legend(facecolor='none', edgecolor='white', labelcolor='white', loc='best')

plt.tight_layout()
plt.savefig('elbow_method_clean.png', dpi=300, bbox_inches='tight', transparent=True)
plt.show()

# 6️⃣ Display table with inertia and reduction values
print("\nInertia Table for Different k Values:")
print("{:<15} {:<15} {:<20}".format("Number of k", "Inertia", "Reduction (%)"))
print("-" * 50)
for i, k in enumerate(k_values):
    if i == 0:
        print("{:<15} {:<15.4f} {:<20}".format(k, inertias[i], "-"))
    else:
        reduction = ((inertias[i-1] - inertias[i]) / inertias[i-1]) * 100
        print("{:<15} {:<15.4f} {:<20.2f}".format(k, inertias[i], reduction))