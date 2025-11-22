# Forecasting with Prophet in Power BI

from prophet import Prophet
import pandas as pd
import matplotlib.pyplot as plt

# Rename Power BI columns
df = dataset.rename(columns={'data': 'ds', 'valor_total': 'y'})
df['ds'] = pd.to_datetime(df['ds'])

# 1) Daily aggregation
df_daily = df.groupby('ds', as_index=False).sum()
df_daily = df_daily[df_daily['y'] < df_daily['y'].quantile(0.95)]

# 2) Prophet
model = Prophet()
model.fit(df_daily)

future = model.make_future_dataframe(periods=120)
forecast = model.predict(future)

# 3) Plot
fig, ax = plt.subplots(figsize=(12, 7))

# Historical data
ax.scatter(df_daily['ds'], df_daily['y'],
           label="Historical Data",
           color='blue', alpha=0.6)

# Forecast line
ax.plot(forecast['ds'], forecast['yhat'],
        label="Forecast",
        color='red', linewidth=2)

# Confidence interval
ax.fill_between(
    forecast['ds'],
    forecast['yhat_lower'],
    forecast['yhat_upper'],
    color='red',
    alpha=0.2,
    label="Confidence Interval"
)

# Cosmetics
ax.grid(True, linestyle='--', alpha=0.5)
ax.set_title("Prophet Forecast", fontsize=14)
ax.set_xlabel("Date")
ax.set_ylabel("Sales")
ax.legend()

plt.tight_layout()
plt.show()

## Tendency and Sazonality Analysis with Prophet

import pandas as pd
from prophet import Prophet
import matplotlib.pyplot as plt

# Prepare the data
# Rename the columns to fit Prophet's required format: 'ds' for date and 'y' for the target variable
df = dataset.rename(columns={'data': 'ds', 'valor_total': 'y'})

# Ensure 'ds' is a datetime column
df['ds'] = pd.to_datetime(df['ds'])

# Remove top 5% outliers
df = df[df['y'] < df['y'].quantile(0.95)]  

# Initialize and fit the Prophet model
model = Prophet()
model.fit(df)

# Create a future dataframe for 90 days
future = model.make_future_dataframe(periods = 90)

# Make predictions
forecast = model.predict(future)

# Plot the actual sales and forecast
# Prophet's built-in plotting function
fig = model.plot(forecast)

# Customize the plot (optional)
plt.title("Actual Sales and Forecasted Sales (90 Days)")
plt.xlabel("Date")
plt.ylabel("Sales Units")

fig2 = model.plot_components(forecast)
# Display the plot
plt.show()