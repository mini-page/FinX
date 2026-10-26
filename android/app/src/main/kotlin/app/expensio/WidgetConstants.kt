package app.expensio

internal object WidgetConstants {
    // Data keys (stored in home_widget's SharedPreferences: "HomeWidgetPreferences")
    const val KEY_TOTAL_BALANCE = "total_balance"
    const val KEY_CURRENCY_SYMBOL = "currency_symbol"
    const val KEY_TRANSACTIONS = "transactions"
    const val KEY_LAST_SYNCED = "last_synced"

    // Per-widget filter key prefix: "txn_filter_<widgetId>"
    const val KEY_TXN_FILTER_PREFIX = "txn_filter_"

    // Intent action for filter-chip broadcasts (widget-internal only)
    const val ACTION_SET_TXN_FILTER = "app.expensio.ACTION_SET_TXN_FILTER"

    // Intent extras for filter-chip broadcasts
    const val EXTRA_WIDGET_ID = "widget_id"
    const val EXTRA_FILTER_VALUE = "filter_value"

    // Filter values
    const val FILTER_TODAY = "today"
    const val FILTER_WEEK = "week"
    const val FILTER_MONTH = "month"

    // Flutter MethodChannel name (kept for the voice-input channel)
    const val CHANNEL_NAME = "app.expensio/widget"
}
