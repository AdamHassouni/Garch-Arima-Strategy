# Ensure the necessary libraries are loaded
library(quantmod)
library(lattice)
library(timeSeries)
library(rugarch)
library(xts)
library(zoo)
library(lattice)


# Obtain the S&P500 returns and truncate the NA value
getSymbols("^GSPC", from = "2018-01-01")
spReturns = diff(log(Cl(GSPC)))
spReturns[as.character(head(index(Cl(GSPC)), 1))] = 0

# Create the forecasts vector to store the predictions
windowLength = 100
foreLength = length(spReturns) - windowLength
forecasts <- vector(mode = "character", length = foreLength)  # Change to list

for (d in 0:(foreLength - 1)) {
    # Obtain the S&P500 rolling window for this day
    spReturnsOffset = spReturns[(1 + d):(windowLength + d)]

    # Fit the ARIMA model
    final.aic <- Inf
    final.order <- c(0, 0, 0)
    for (p in 0:5) for (q in 0:5) {
        if (p == 0 && q == 0) {
            next
        }

        arimaFit = tryCatch(arima(spReturnsOffset, order = c(p, 0, q)),
                            error = function(err) FALSE,
                            warning = function(err) FALSE)

        if (!is.logical(arimaFit)) {
            current.aic <- AIC(arimaFit)
            if (current.aic < final.aic) {
                final.aic <- current.aic
                final.order <- c(p, 0, q)
                final.arima <- arima(spReturnsOffset, order = final.order)
            }
        }else{
            next
        }
    }

    # Specify and fit the GARCH model
    spec = ugarchspec(
        variance.model = list(garchOrder = c(1, 1)),
        mean.model = list(armaOrder = c(final.order[1], final.order[3]), include.mean = TRUE),
        distribution.model = "sged"
    )

    fit = tryCatch(
        ugarchfit(spec, spReturnsOffset, solver = 'hybrid'),
        error = function(e) e,
        warning = function(w) w
    )

    if(is(fit, "warning")) {
        forecasts[d+1] = paste(
            index(spReturnsOffset[windowLength]), 1, sep=","
    )
        print(
            paste(
                index(spReturnsOffset[windowLength]), 1, sep=","
                )
    )
    } else {
        fore = ugarchforecast(fit, n.ahead=1)
        ind = fore@forecast$seriesFor
        forecasts[d+1] = paste(
            colnames(ind), ifelse(ind[1] < 0, -1, 1), sep=","
     )
        print(paste(colnames(ind), ifelse(ind[1] < 0, -1, 1), sep=","))
        }
}



# Input the Python-refined CSV file AFTER CONVERSION

# Output the CSV file to "forecasts.csv"
write.csv(forecasts, file="forecasts.csv", row.names=FALSE)

spArimaGarch = as.xts(
    read.zoo(
        file="forecasts_new.csv", format="%Y-%m-%d", header=F, sep=","
    )
)
spIntersect = merge( spArimaGarch[,1], spReturns, all=F )
spArimaGarchReturns = spIntersect[,1] * spIntersect[,2]
spArimaGarchCurve = log( cumprod( 1 + spArimaGarchReturns ) )
spBuyHoldCurve = log( cumprod( 1 + spIntersect[,2] ) )
spCombinedCurve = merge( spArimaGarchCurve, spBuyHoldCurve, all=F )
#plot cummulative returns
xyplot(
    spCombinedCurve,
    superpose=T,
    col=c("purple", "darkgreen"),
    lwd=2,
    key=list(
        text=list(
        c("ARIMA+GARCH", "Buy & Hold")
    ),
    lines=list(
        lwd=2, col=c("purple", "darkgreen")
    )
    )
)
# Calculate drawdowns
install.packages("PerformanceAnalytics")
drawdown_arima_garch <- PerformanceAnalytics::Drawdowns(spArimaGarchCurve)
drawdown_buy_hold <- PerformanceAnalytics::Drawdowns(spBuyHoldCurve)

drawdowns <- merge(drawdown_arima_garch, drawdown_buy_hold, all=F)

# Plot drawdowns
xyplot(
    drawdowns,
    superpose=T,
    col=c("purple", "darkgreen"),
    lwd=2,
    key=list(
        text=list(
            c("ARIMA+GARCH", "Buy & Hold")
        ),
        lines=list(
            lwd=2, col=c("purple", "darkgreen")
        )
    ),
    main="Drawdowns"
)
# Calculate daily returns
daily_returns_arima_garch <- diff(spArimaGarchCurve)
daily_returns_buy_hold <- diff(spBuyHoldCurve)

# Calculate rolling volatility (e.g., 30-day rolling window)
rolling_vol_arima_garch <- rollapply(daily_returns_arima_garch, width=30, FUN=sd, fill=NA)
rolling_vol_buy_hold <- rollapply(daily_returns_buy_hold, width=80, FUN=sd, fill=NA)

# Merge rolling volatilities for plotting
rolling_vol <- merge(rolling_vol_arima_garch, rolling_vol_buy_hold, all=F)

# Plot rolling volatility
xyplot(
    rolling_vol,
    superpose=T,
    col=c("purple", "darkgreen"),
    lwd=2,
    key=list(
        text=list(
            c("ARIMA+GARCH", "Buy & Hold")
        ),
        lines=list(
            lwd=2, col=c("purple", "darkgreen")
        )
    ),
    main="Rolling Volatility (80-day)"
)
# Calculate rolling returns (e.g., 30-day rolling window)
rolling_returns_arima_garch <- rollapply(daily_returns_arima_garch, width=30, FUN=sum, fill=NA)
rolling_returns_buy_hold <- rollapply(daily_returns_buy_hold, width=30, FUN=sum, fill=NA)

# Merge rolling returns for plotting
rolling_returns <- merge(rolling_returns_arima_garch, rolling_returns_buy_hold, all=F)

# Plot rolling returns
xyplot(
    rolling_returns,
    superpose=T,
    col=c("purple", "darkgreen"),
    lwd=2,
    key=list(
        text=list(
            c("ARIMA+GARCH", "Buy & Hold")
        ),
        lines=list(
            lwd=2, col=c("purple", "darkgreen")
        )
    ),
    main="Rolling Returns (30-day)"
)
# Calculate rolling Sharpe ratio (e.g., 30-day rolling window)
rolling_sharpe_arima_garch <- rollapply(daily_returns_arima_garch, width=30, FUN=SharpeRatio, fill=NA)
rolling_sharpe_buy_hold <- rollapply(daily_returns_buy_hold, width=30, FUN=SharpeRatio, fill=NA)

# Merge rolling Sharpe ratios for plotting
rolling_sharpe <- merge(rolling_sharpe_arima_garch, rolling_sharpe_buy_hold, all=F)

# Plot rolling Sharpe ratios

