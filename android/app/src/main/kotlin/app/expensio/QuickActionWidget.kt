package app.expensio

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlin.math.abs
import java.text.NumberFormat
import java.util.Locale

/**
 * AppWidgetProvider for Widget 1 — Quick Finance Action Widget.
 *
 * Displays the total account balance and one-tap buttons for:
 *   • Add Expense / Add Income / Add Transfer
 *   • Scan QR / receipt
 *   • Voice entry
 *
 * Data is read from the home_widget SharedPreferences store via
 * [HomeWidgetPlugin.getData], written from Flutter via [home_widget].
 */
class QuickActionWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    companion object {

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
        ) {
            try {
                val prefs = HomeWidgetPlugin.getData(context)

                val hasData = prefs.contains(WidgetConstants.KEY_LAST_SYNCED)
                // home_widget stores Double values as raw Long bits.
                val rawLong = prefs.getLong(
                    WidgetConstants.KEY_TOTAL_BALANCE,
                    java.lang.Double.doubleToRawLongBits(0.0),
                )
                val rawBalance = java.lang.Double.longBitsToDouble(rawLong)
                val symbol = prefs.getString(WidgetConstants.KEY_CURRENCY_SYMBOL, "₹") ?: "₹"

                val balanceText = if (hasData) {
                    formatBalance(symbol, rawBalance)
                } else {
                    "Open Expensio"
                }

                val views = RemoteViews(context.packageName, R.layout.widget_quick_action)

                views.setTextViewText(R.id.widget_qa_balance, balanceText)

                // Balance area taps → open app home
                views.setOnClickPendingIntent(
                    R.id.widget_qa_header,
                    buildActionIntent(context, "open_app"),
                )

                // Individual action buttons
                views.setOnClickPendingIntent(
                    R.id.widget_qa_add_Expense,
                    buildActionIntent(context, "add_Expense"),
                )
                views.setOnClickPendingIntent(
                    R.id.widget_qa_add_income,
                    buildActionIntent(context, "add_income"),
                )
                views.setOnClickPendingIntent(
                    R.id.widget_qa_add_transfer,
                    buildActionIntent(context, "add_transfer"),
                )
                views.setOnClickPendingIntent(
                    R.id.widget_qa_scanner,
                    buildActionIntent(context, "scanner"),
                )
                views.setOnClickPendingIntent(
                    R.id.widget_qa_voice,
                    buildActionIntent(context, "voice"),
                )

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
                // Fallback: push a minimal RemoteViews so the launcher never shows
                // "Can't load widget" due to an unexpected runtime exception.
                try {
                    val fallback = RemoteViews(context.packageName, R.layout.widget_quick_action)
                    fallback.setTextViewText(R.id.widget_qa_balance, "Open Expensio")
                    appWidgetManager.updateAppWidget(widgetId, fallback)
                } catch (_: Exception) {
                    // Nothing further we can do.
                }
            }
        }

        /** Build a PendingIntent that launches [MainActivity] via the home_widget action URI. */
        private fun buildActionIntent(
            context: Context,
            widgetAction: String,
        ): PendingIntent {
            return HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("expensio://widget?action=$widgetAction"),
            )
        }

        private fun formatBalance(symbol: String, amount: Double): String {
            val absVal = abs(amount)
            val formatted = NumberFormat.getNumberInstance(Locale.getDefault()).apply {
                maximumFractionDigits = 2
                minimumFractionDigits = 0
            }.format(absVal)
            return if (amount < 0) "-$symbol$formatted" else "$symbol$formatted"
        }
    }
}
