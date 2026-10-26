package app.expensio

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kotlin.math.abs

/**
 * AppWidgetProvider for Widget 2 — Recent Transactions Widget.
 *
 * Shows the last 5 transactions for the selected time filter
 * (Today / Week / Month). The filter is persisted per-widget-instance
 * in the home_widget SharedPreferences store.
 *
 * Filter buttons send a broadcast back to this receiver so the widget
 * updates without opening the app.
 */
class RecentTransactionsWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == WidgetConstants.ACTION_SET_TXN_FILTER) {
            val widgetId = intent.getIntExtra(
                WidgetConstants.EXTRA_WIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            )
            val filter = intent.getStringExtra(WidgetConstants.EXTRA_FILTER_VALUE)
                ?: WidgetConstants.FILTER_TODAY

            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                val prefs = HomeWidgetPlugin.getData(context)
                prefs.edit()
                    .putString("${WidgetConstants.KEY_TXN_FILTER_PREFIX}$widgetId", filter)
                    .apply()

                val manager = AppWidgetManager.getInstance(context)
                updateWidget(context, manager, widgetId)
            }
        }
    }

    companion object {

        private const val MAX_ROWS = 5
        private const val MILLIS_PER_DAY = 24L * 60 * 60 * 1000

        /** Called both from [onUpdate] and from filter-chip broadcast handling. */
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
        ) {
            try {
                val prefs = HomeWidgetPlugin.getData(context)

                val currentFilter = prefs.getString(
                    "${WidgetConstants.KEY_TXN_FILTER_PREFIX}$widgetId",
                    WidgetConstants.FILTER_TODAY,
                ) ?: WidgetConstants.FILTER_TODAY

                val symbol = prefs.getString(WidgetConstants.KEY_CURRENCY_SYMBOL, "₹") ?: "₹"
                val txnJson = prefs.getString(WidgetConstants.KEY_TRANSACTIONS, "[]") ?: "[]"
                val hasData = prefs.contains(WidgetConstants.KEY_LAST_SYNCED)

                val allTxns = parseTransactions(txnJson)
                val filtered = filterTransactions(allTxns, currentFilter)

                val views = RemoteViews(context.packageName, R.layout.widget_recent_transactions)

                // ── Filter chip appearance ────────────────────────────────
                applyFilterChipStates(views, currentFilter)

                // ── Filter chip click intents (broadcast back to this receiver) ──
                views.setOnClickPendingIntent(
                    R.id.widget_rt_filter_today,
                    buildFilterIntent(context, widgetId, WidgetConstants.FILTER_TODAY),
                )
                views.setOnClickPendingIntent(
                    R.id.widget_rt_filter_week,
                    buildFilterIntent(context, widgetId, WidgetConstants.FILTER_WEEK),
                )
                views.setOnClickPendingIntent(
                    R.id.widget_rt_filter_month,
                    buildFilterIntent(context, widgetId, WidgetConstants.FILTER_MONTH),
                )

                // ── "Open" button taps the app home ──────────────────────
                views.setOnClickPendingIntent(
                    R.id.widget_rt_open_app,
                    buildAppActionIntent(context, "open_app"),
                )

                // ── Populate rows ─────────────────────────────────────────
                val rowIds = listOf(
                    RowViews(
                        R.id.widget_rt_row_0,
                        R.id.widget_rt_row_0_icon,
                        R.id.widget_rt_row_0_title,
                        R.id.widget_rt_row_0_date,
                        R.id.widget_rt_row_0_amount,
                    ),
                    RowViews(
                        R.id.widget_rt_row_1,
                        R.id.widget_rt_row_1_icon,
                        R.id.widget_rt_row_1_title,
                        R.id.widget_rt_row_1_date,
                        R.id.widget_rt_row_1_amount,
                    ),
                    RowViews(
                        R.id.widget_rt_row_2,
                        R.id.widget_rt_row_2_icon,
                        R.id.widget_rt_row_2_title,
                        R.id.widget_rt_row_2_date,
                        R.id.widget_rt_row_2_amount,
                    ),
                    RowViews(
                        R.id.widget_rt_row_3,
                        R.id.widget_rt_row_3_icon,
                        R.id.widget_rt_row_3_title,
                        R.id.widget_rt_row_3_date,
                        R.id.widget_rt_row_3_amount,
                    ),
                    RowViews(
                        R.id.widget_rt_row_4,
                        R.id.widget_rt_row_4_icon,
                        R.id.widget_rt_row_4_title,
                        R.id.widget_rt_row_4_date,
                        R.id.widget_rt_row_4_amount,
                    ),
                )

                val showEmpty = !hasData || filtered.isEmpty()
                views.setViewVisibility(
                    R.id.widget_rt_empty,
                    if (showEmpty) View.VISIBLE else View.GONE,
                )

                val displayCount = minOf(filtered.size, MAX_ROWS)

                for (i in 0 until MAX_ROWS) {
                    val row = rowIds[i]
                    if (i < displayCount) {
                        val txn = filtered[i]
                        views.setViewVisibility(row.container, View.VISIBLE)
                        views.setTextViewText(row.icon, categoryEmoji(txn.category))
                        val title = if (txn.note.isNotBlank()) txn.note else txn.category
                        views.setTextViewText(row.title, title)
                        views.setTextViewText(row.date, formatDate(txn.dateMs))
                        val (amtText, amtColor) = formatAmount(symbol, txn.amount, txn.type)
                        views.setTextViewText(row.amount, amtText)
                        views.setTextColor(row.amount, amtColor)
                        // Row tap opens app
                        views.setOnClickPendingIntent(
                            row.container,
                            buildAppActionIntent(context, "open_app"),
                        )
                    } else {
                        views.setViewVisibility(row.container, View.GONE)
                    }
                }

                // "and N more" footer
                val extra = filtered.size - MAX_ROWS
                if (extra > 0) {
                    views.setViewVisibility(R.id.widget_rt_more, View.VISIBLE)
                    views.setTextViewText(R.id.widget_rt_more, "+$extra more")
                } else {
                    views.setViewVisibility(R.id.widget_rt_more, View.GONE)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
                // Fallback: push a minimal RemoteViews so the launcher never shows
                // "Can't load widget" due to an unexpected runtime exception.
                try {
                    val fallback = RemoteViews(context.packageName, R.layout.widget_recent_transactions)
                    fallback.setViewVisibility(R.id.widget_rt_empty, View.VISIBLE)
                    appWidgetManager.updateAppWidget(widgetId, fallback)
                } catch (_: Exception) {
                    // Nothing further we can do.
                }
            }
        }

        // ── Helpers ────────────────────────────────────────────────────

        private fun applyFilterChipStates(views: RemoteViews, activeFilter: String) {
            val filters = listOf(
                Triple(R.id.widget_rt_filter_today, WidgetConstants.FILTER_TODAY, "Today"),
                Triple(R.id.widget_rt_filter_week, WidgetConstants.FILTER_WEEK, "Week"),
                Triple(R.id.widget_rt_filter_month, WidgetConstants.FILTER_MONTH, "Month"),
            )
            for ((id, value, _) in filters) {
                val isSelected = value == activeFilter
                views.setInt(
                    id,
                    "setBackgroundResource",
                    if (isSelected) R.drawable.widget_chip_selected_bg
                    else R.drawable.widget_chip_unselected_bg,
                )
                views.setTextColor(
                    id,
                    if (isSelected) Color.WHITE else Color.parseColor("#48607E"),
                )
            }
        }

        private data class RowViews(
            val container: Int,
            val icon: Int,
            val title: Int,
            val date: Int,
            val amount: Int,
        )

        private data class Transaction(
            val amount: Double,
            val category: String,
            val type: String,
            val dateMs: Long,
            val note: String,
        )

        private fun parseTransactions(json: String): List<Transaction> {
            return try {
                val arr = JSONArray(json)
                (0 until arr.length()).map { i ->
                    val obj: JSONObject = arr.getJSONObject(i)
                    Transaction(
                        amount = obj.getDouble("amount"),
                        category = obj.optString("category", "Other"),
                        type = obj.optString("type", "Expense"),
                        dateMs = obj.getLong("dateMs"),
                        note = obj.optString("note", ""),
                    )
                }
            } catch (_: Exception) {
                emptyList()
            }
        }

        private fun filterTransactions(txns: List<Transaction>, filter: String): List<Transaction> {
            val cutoffMs: Long = when (filter) {
                WidgetConstants.FILTER_TODAY -> {
                    Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, 0)
                        set(Calendar.MINUTE, 0)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    }.timeInMillis
                }
                WidgetConstants.FILTER_WEEK -> {
                    Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, 0)
                        set(Calendar.MINUTE, 0)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                        add(Calendar.DAY_OF_YEAR, -6)
                    }.timeInMillis
                }
                WidgetConstants.FILTER_MONTH -> {
                    Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, 0)
                        set(Calendar.MINUTE, 0)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                        add(Calendar.DAY_OF_YEAR, -29)
                    }.timeInMillis
                }
                else -> 0L
            }
            return txns.filter { it.dateMs >= cutoffMs }
                .sortedByDescending { it.dateMs }
        }

        private fun formatAmount(
            symbol: String,
            amount: Double,
            type: String,
        ): Pair<String, Int> {
            val formatted = NumberFormat.getNumberInstance(Locale.getDefault()).apply {
                maximumFractionDigits = 2
                minimumFractionDigits = 0
            }.format(abs(amount))

            return when (type) {
                "income" -> Pair("+$symbol$formatted", Color.parseColor("#1DAA63"))
                "transfer" -> Pair("→$symbol$formatted", Color.parseColor("#0A6BE8"))
                else -> Pair("-$symbol$formatted", Color.parseColor("#FF446D"))
            }
        }

        private fun formatDate(dateMs: Long): String {
            val itemCal = Calendar.getInstance().apply { timeInMillis = dateMs }
            val todayCal = Calendar.getInstance()
            val yesterdayCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -1) }

            return when {
                isSameDay(itemCal, todayCal) ->
                    SimpleDateFormat("h:mm a", Locale.getDefault()).format(itemCal.time)

                isSameDay(itemCal, yesterdayCal) -> "Yesterday"

                else -> {
                    val diffDays = ((todayCal.timeInMillis - itemCal.timeInMillis) /
                            MILLIS_PER_DAY).toInt()
                    if (diffDays < 7) {
                        SimpleDateFormat("EEE", Locale.getDefault()).format(itemCal.time)
                    } else {
                        SimpleDateFormat("MMM d", Locale.getDefault()).format(itemCal.time)
                    }
                }
            }
        }

        private fun isSameDay(c1: Calendar, c2: Calendar): Boolean =
            c1.get(Calendar.YEAR) == c2.get(Calendar.YEAR) &&
                    c1.get(Calendar.DAY_OF_YEAR) == c2.get(Calendar.DAY_OF_YEAR)

        private fun categoryEmoji(category: String): String {
            return when (category.lowercase(Locale.getDefault())) {
                "food & dining", "food" -> "🍽"
                "transportation", "transport" -> "🚗"
                "shopping" -> "🛍"
                "beauty & care", "beauty" -> "💅"
                "social" -> "👥"
                "travel" -> "✈️"
                "accessories" -> "⌚"
                "salary" -> "💼"
                "award" -> "🏆"
                "coupon" -> "🎟"
                "grant" -> "🎓"
                "lottery" -> "🎰"
                "refund" -> "↩️"
                "sale" -> "🏷"
                "transfer" -> "🔄"
                else -> "💰"
            }
        }

        private fun buildFilterIntent(
            context: Context,
            widgetId: Int,
            filterValue: String,
        ): PendingIntent {
            val intent = Intent(context, RecentTransactionsWidget::class.java).apply {
                action = WidgetConstants.ACTION_SET_TXN_FILTER
                putExtra(WidgetConstants.EXTRA_WIDGET_ID, widgetId)
                putExtra(WidgetConstants.EXTRA_FILTER_VALUE, filterValue)
            }
            val filterIndex = when (filterValue) {
                WidgetConstants.FILTER_TODAY -> 0
                WidgetConstants.FILTER_WEEK -> 1
                else -> 2
            }
            val requestCode = widgetId * 3 + filterIndex
            val flags = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            return PendingIntent.getBroadcast(context, requestCode, intent, flags)
        }

        private fun buildAppActionIntent(
            context: Context,
            action: String,
        ): PendingIntent {
            return HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("expensio://widget?action=$action"),
            )
        }
    }
}
