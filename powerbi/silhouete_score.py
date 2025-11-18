import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import silhouette_score

# === STYLE SETTINGS ===
plt.style.use('default')
plt.rcParams['figure.facecolor'] = 'none'          # Transparent figure background
plt.rcParams['axes.facecolor'] = 'none'            # Transparent axes background
plt.rcParams['axes.edgecolor'] = 'white'           # White axis border
plt.rcParams['axes.labelcolor'] = 'white'          # White labels
plt.rcParams['xtick.color'] = 'white'              # White x ticks
plt.rcParams['ytick.color'] = 'white'              # White y ticks
plt.rcParams['text.color'] = 'white'               # White annotation text
plt.rcParams['legend.edgecolor'] = 'white'         # White legend border
plt.rcParams['legend.labelcolor'] = 'white'        # White legend text
plt.rcParams['axes.titlepad'] = 15                 # Extra padding for title

# 1️⃣ Copy the dataset from Power BI
df = dataset.copy()

# 2️⃣ Inspect dataset structure
print("Dataset structure:")
print(f"Total observations: {len(df)}")
print("Available columns:", df.columns.tolist())
print("\nStatistical summary:")
print(df.describe())

# 3️⃣ Select only relevant numerical columns
X = df[['value_2024_usd', 'urban_population_total', 'gdp_per_capita_usd']].dropna()

# 4️⃣ Normalize the data
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# 5️⃣ Compute Silhouette Scores for multiple k values
k_values = range(2, 11)
silhouette_scores = []

for k in k_values:
    kmeans = KMeans(n_clusters=k, init='k-means++', n_init=10, random_state=42)
    cluster_labels = kmeans.fit_predict(X_scaled)
    score = silhouette_score(X_scaled, cluster_labels)
    silhouette_scores.append(score)
    print(f"k={k}, Silhouette Score: {score:.4f}")

# 6️⃣ Identify the optimal number of clusters
optimal_k = k_values[np.argmax(silhouette_scores)]
optimal_score = max(silhouette_scores)

print(f"\nOptimal number of clusters: k={optimal_k}")
print(f"Maximum Silhouette Score: {optimal_score:.4f}")

# 7️⃣ Plot Silhouette Scores (styled to match Elbow Method)
plt.figure(figsize=(10, 6))
plt.plot(k_values, silhouette_scores, 'bo-', linewidth=2, markersize=8)  # Blue line with dots
plt.xlabel('Number of Clusters (k)', fontsize=12)
plt.ylabel('Silhouette Score', fontsize=12)
plt.title('Silhouette Method for Determining the Optimal Number of Clusters', fontsize=14, color='white')
plt.grid(True, linestyle='--', alpha=0.6, color='white')  # White gridlines

# ❌ Disable scientific notation (just in case)
plt.ticklabel_format(style='plain', axis='y')

# 🔴 Highlight the optimal point
plt.scatter(optimal_k, optimal_score, s=200, c='white', marker='o',
            label=f'k={optimal_k} (Score={optimal_score:.4f})')
plt.legend(facecolor='none', edgecolor='white', labelcolor='white', loc='best')

# ✅ Removed numeric annotations above the points for a clean visual

plt.tight_layout()
plt.savefig('silhouette_method_clean.png', dpi=300, bbox_inches='tight', transparent=True)
plt.show()