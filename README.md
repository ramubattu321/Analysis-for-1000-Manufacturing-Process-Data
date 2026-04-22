# Manufacturing Process Analysis & EDA

## Overview
This project analyzes manufacturing process data to understand machine performance, detect anomalies, and identify patterns affecting production quality.

The analysis combines exploratory data analysis (EDA), cluster sampling, and statistical process control (SPC) techniques to support data-driven decision-making in manufacturing operations.

---

## Business Problem
Manufacturing systems generate large volumes of process and sensor data, but it can be difficult to identify performance issues and quality risks.

This project addresses that by:
- Cleaning and structuring raw process data  
- Analyzing machine behavior and performance patterns  
- Detecting anomalies using statistical methods  
- Supporting quality monitoring and operational efficiency  

---

## Dataset
The dataset contains manufacturing process data including:
- Machine IDs  
- Sensor readings  
- Production measurements  

---

## Methodology

### Data Preparation
- Cleaned and standardized dataset  
- Normalized column names  
- Prepared data for analysis  

### Exploratory Data Analysis
- Analyzed distributions of sensor values  
- Identified correlations between variables  
- Detected outliers using boxplots  

### Statistical Process Control (SPC)
- Implemented 3-sigma control chart  
- Calculated mean, upper control limit (UCL), and lower control limit (LCL)  
- Identified abnormal machine behavior (anomalies)  

---

## Key Insights
- Sensor readings follow a consistent distribution with some outliers  
- Control chart analysis detected machines operating outside acceptable limits  
- Statistical thresholds (3σ) effectively highlight abnormal process behavior  
- Data-driven monitoring can help prevent machine failures and quality issues  

---

## Visualizations

### Control Chart (Anomaly Detection)
![Control Chart](images/control_chart.png)

### Correlation Heatmap
![Correlation Heatmap](images/correlation_heatmap.png)

### Outlier Detection (Boxplot)
![Outlier Boxplot](images/outlier_boxplot.png)

---

## Business Impact
- Enables early detection of machine anomalies  
- Supports manufacturing quality control  
- Improves operational efficiency through data monitoring  
- Provides a foundation for predictive maintenance  

---

## Tools & Technologies
- Python  
- Pandas  
- NumPy  
- Matplotlib  
- Seaborn  

---

## Project Structure
manufacturing-process-analysis-eda
│
├── README.md  
├── requirements.txt  
├── images/  
│   ├── control_chart.png  
│   ├── correlation_heatmap.png  
│   └── outlier_boxplot.png  
├── manufacturing_insights.ipynb  
└── cluster_sample.csv  

---

## Author
Ramu Battu  
MS Data Analytics, California State University, Fresno
