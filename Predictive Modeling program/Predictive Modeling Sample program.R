library(quantmod)
library(TTR)
library(caret)
library(corrplot)
library(pROC)
library(FSelector)


## Use set.seed function to ensure the results are repeatable
set.seed(5)

## Read the stock and index data
df_stock = read.csv("Predictive Modeling program/BAJAJ-AUTO 5 Yr data.csv")
df_index = read.csv("Predictive Modeling program/NIFTY 5 Yr data.csv")

## Compute the price change for the stock and classify as UP/DOWN
price = df_stock$Last - df_stock$Open
class = ifelse(price > 0, "UP", "DOWN")

## Compute the various technical indicators that will be used
# Force Index Indicator
forceindex = (df_stock$Last - df_stock$Open) * df_stock$Vol
forceindex = c(NA, head(forceindex, -1))


# Buy & Sell signal Indicators (Williams R% and RSI)
WillR5  = WPR(df_stock[, c("High", "Low", "Last")], n = 5)
WillR5 = c(NA, head(WillR5, -1))

WillR10 = WPR(df_stock[, c("High", "Low", "Last")], n = 10)
WillR10 = c(NA, head(WillR10, -1))

WillR15 = WPR(df_stock[, c("High", "Low", "Last")], n = 15)
WillR15 = c(NA, head(WillR15, -1))


RSI5  = RSI(df_stock$Last, n = 5, maType = "WMA")
RSI5 = c(NA, head(RSI5, -1))

RSI10 = RSI(df_stock$Last, n = 10, maType = "WMA")
RSI10 = c(NA, head(RSI10, -1))

RSI15 = RSI(df_stock$Last, n = 15, maType = "WMA")
RSI15 = c(NA, head(RSI15, -1))


# Price change Indicators (ROC and Momentum)
ROC5 = ROC(df_stock$Last, n = 5, type = "discrete") * 100
ROC5 = c(NA, head(ROC5, -1))

ROC10 = ROC(df_stock$Last, n = 10, type = "discrete") * 100
ROC10 = c(NA, head(ROC10, -1))


MOM5 = momentum(df_stock$Last, n = 5, na.pad = TRUE)
MOM5 = c(NA, head(MOM5, -1))

MOM10 = momentum(df_stock$Last, n = 10, na.pad = TRUE)
MOM10 = c(NA, head(MOM10, -1))


MOM5Indx = momentum(df_index$Last, n = 5, na.pad = TRUE)
MOM5Indx = c(NA, head(MOM5Indx, -1))

MOM10Indx = momentum(df_index$Last, n = 10, na.pad = TRUE)
MOM10Indx = c(NA, head(MOM10Indx, -1))


# Volatility signal Indicator (ATR)
ATR5 = ATR(df_stock[, c("High", "Low", "Last")], n = 5, maType = "WMA")[, 1]
ATR5 = c(NA, head(ATR5, -1))

ATR10 = ATR(df_stock[, c("High", "Low", "Last")], n = 10, maType = "WMA")[, 1]
ATR10 = c(NA, head(ATR10, -1))


ATR5Indx = ATR(df_index[, c("High", "Low", "Last")], n = 5, maType = "WMA")[, 1]
ATR5Indx = c(NA, head(ATR5Indx, -1))

ATR10Indx = ATR(df_index[, c("High", "Low", "Last")], n = 10, maType = "WMA")[, 1]
ATR10Indx = c(NA, head(ATR10Indx, -1))


## Combining all the Indicators and the Class into one dataframe
dataset = data.frame(
  class,
  forceindex,
  WillR5,
  WillR10,
  WillR15,
  RSI5,
  RSI10,
  RSI15,
  ROC5,
  ROC10,
  MOM5,
  MOM10,
  ATR5,
  ATR10,
  MOM5Indx,
  MOM10Indx,
  ATR5Indx,
  ATR10Indx
)
dataset = na.omit(dataset)

## Understanding the dataset using descriptive statistics
print(head(dataset), 5)
dim(dataset)
y = dataset$class
cbind(freq = table(y), percentage = prop.table(table(y)) * 100)

summary(dataset)

##  Visualizing the dataset using a correlation matrix
correlations = cor(dataset[, c(2:18)])
print(head(correlations))
corrplot(correlations, method = "circle")

## Selecting features using the random.forest.importance function from the FSelector package
set.seed(5)
weights = random.forest.importance(class ~ ., dataset, importance.type = 1)
print(weights)

set.seed(5)
subset = cutoff.k(weights, 10)
print(subset)

## Creating a dataframe using the selected features
dataset_rf = data.frame(class,
                        forceindex,
                        WillR5,
                        WillR10,
                        RSI5,
                        RSI10,
                        RSI15,
                        ROC5,
                        ROC10,
                        MOM5,
                        MOM10Indx)
dataset_rf = na.omit(dataset_rf)

# Resampling method used - 10-fold cross validation
# with "Accuracy" as the model evaluation metric.
trainControl = trainControl(method = "cv", number = 10)
metric = "Accuracy"

## Trying four different Classification algorithms
# k-Nearest Neighbors (KNN)
set.seed(5)


fit.knn = train(
  class ~ .,
  data = dataset_rf,
  method = "knn",
  metric = metric,
  preProc = c("range"),
  trControl = trainControl
)

# Classification and Regression Trees (CART)
set.seed(5)
fit.cart = train(
  class ~ .,
  data = dataset_rf,
  method = "rpart",
  metric = metric,
  preProc = c("range"),
  trControl = trainControl
)

# Naive Bayes (NB)
set.seed(5)
fit.nb = train(
  class ~ .,
  data = dataset_rf,
  method = "nb",
  metric = metric,
  preProc = c("range"),
  trControl = trainControl
)

# Support Vector Machine with Radial Basis Function (SVM)
set.seed(5)
fit.svm = train(
  class ~ .,
  data = dataset_rf,
  method = "svmRadial",
  metric = metric,
  preProc = c("range"),
  trControl = trainControl
)

## Evaluating the algorithms using the "Accuracy" metric
results = resamples(list(
  KNN = fit.knn,
  CART = fit.cart,
  NB = fit.nb,
  SVM = fit.svm
))
summary(results)
dotplot(results)

## Tuning the shortlisted algorithm (KNN algorithm)
set.seed(5)
grid = expand.grid(.k = seq(1, 10, by = 1))
fit.knn = train(
  class ~ .,
  data = dataset_rf,
  method = "knn",
  metric = metric,
  tuneGrid = grid,
  preProc = c("range"),
  trControl = trainControl
)
print(fit.knn)
