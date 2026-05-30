package app.xpens.finance

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage
import androidx.core.app.NotificationCompat
import java.net.URLEncoder

/**
 * Listens for incoming SMS messages in the background.
 * Filters for transactional keywords (e.g. debited, spent, Rs.) and triggers
 * a system notification linking to the AppShell with the SMS body.
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL_ID = "transactions_channel"
        private const val CHANNEL_NAME = "XPens Transactions"
        private const val CHANNEL_DESC = "Notifications for auto-detected SMS bank transactions"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages: Array<SmsMessage> = try {
            Telephony.Sms.Intents.getMessagesFromIntent(intent)
        } catch (e: Exception) {
            return
        }

        for (sms in messages) {
            val sender = sms.displayOriginatingAddress ?: sms.originatingAddress ?: continue
            val body = sms.messageBody ?: continue
            
            // Check if this is a transaction
            if (isTransactional(body)) {
                processTransaction(context, sender, body)
            }
        }
    }

    private fun isTransactional(body: String): Boolean {
        val cleanBody = body.lowercase()
        // Ignore OTP / passwords / verification codes
        if (cleanBody.contains("otp") || 
            cleanBody.contains("code") || 
            cleanBody.contains("verification") || 
            cleanBody.contains("password") ||
            cleanBody.contains("one time password")) {
            return false
        }

        // Must contain key banking transaction words
        val containsKeywords = cleanBody.contains("debited") || 
                               cleanBody.contains("spent") || 
                               cleanBody.contains("charged") || 
                               cleanBody.contains("withdrawn") || 
                               cleanBody.contains("paid") || 
                               cleanBody.contains("sent") ||
                               cleanBody.contains("credited") || 
                               cleanBody.contains("received") || 
                               cleanBody.contains("added")

        // Must contain amount hint (Rs, Rs., INR, or currency symbols)
        val containsAmountHint = cleanBody.contains("rs") || 
                                 cleanBody.contains("inr") || 
                                 cleanBody.contains("rupees") || 
                                 cleanBody.contains("₹")

        return containsKeywords && containsAmountHint
    }

    private fun processTransaction(context: Context, sender: String, body: String) {
        // Extract Amount
        val amountRegex = Regex("""(?i)(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)""")
        val amountMatch = amountRegex.find(body)
        val amountStr = amountMatch?.groups?.get(1)?.value?.replace(",", "")
        val amount = amountStr?.toDoubleOrNull() ?: 0.0

        if (amount <= 0.0) return // Skip if no amount is detected

        // Extract Merchant hint
        val merchantRegex = Regex("""(?i)(?:at|to|vpa|info|transfer to)\s+([a-zA-Z0-9\s\.\*#\-]{3,20})""")
        val merchantMatch = merchantRegex.find(body)
        var merchant = merchantMatch?.groups?.get(1)?.value?.trim() ?: "Merchant"
        
        // Clean merchant name from dates, times, trailing newlines, etc.
        merchant = merchant.split("\n", "\r", " on ", " date ", " at ").first().trim()
        if (merchant.length > 20) {
            merchant = merchant.substring(0, 20).trim()
        }

        val isDebit = body.lowercase().let { 
            it.contains("debited") || it.contains("spent") || it.contains("charged") || it.contains("withdrawn") || it.contains("paid") || it.contains("sent")
        }

        // Construct App deep link
        val encodedBody = try {
            URLEncoder.encode(body, "UTF-8")
        } catch (e: Exception) {
            body
        }
        val encodedSender = try {
            URLEncoder.encode(sender, "UTF-8")
        } catch (e: Exception) {
            sender
        }

        val deepLinkUri = "xpens://widget?action=sms&body=$encodedBody&sender=$encodedSender"

        // Trigger Notification
        triggerNotification(context, isDebit, amount, merchant, deepLinkUri)
    }

    private fun triggerNotification(
        context: Context,
        isDebit: Boolean,
        amount: Double,
        merchant: String,
        deepLinkUri: String
    ) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        // Create Notification Channel (required on Android 8.0+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_DEFAULT
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance).apply {
                description = CHANNEL_DESC
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Build Intent
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLinkUri)).apply {
            `package` = context.packageName
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            System.currentTimeMillis().toInt(),
            intent,
            pendingIntentFlags
        )

        // Resolve App Icon
        val iconRes = context.resources.getIdentifier("ic_launcher", "mipmap", context.packageName).let {
            if (it != 0) it else android.R.drawable.ic_dialog_info
        }

        // Content details
        val title = if (isDebit) "Debit Transaction Detected" else "Credit Transaction Detected"
        val formattedAmount = String.format("%,.0f", amount)
        val text = if (isDebit) {
            "Spent ₹$formattedAmount at $merchant. Tap to log."
        } else {
            "Received ₹$formattedAmount. Tap to log."
        }

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(iconRes)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }
}
