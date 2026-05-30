package app.xpens.finance

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import android.app.PendingIntent
import android.content.Context
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterFragmentActivity() {

    // ── Voice recognition ──────────────────────────────────────────────
    private var voiceResultCallback: MethodChannel.Result? = null
    private val voiceRequestCode = 0xA1CE

    // ── SMS receiver ───────────────────────────────────────────────────
    private var smsReceiverPlugin: SmsReceiverPlugin? = null

    // ── MethodChannel ─────────────────────────────────────────────────
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WidgetConstants.CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                // Flutter → Android: launch the system speech recogniser
                "startVoiceInput" -> {
                    voiceResultCallback = result
                    startVoiceRecognition()
                }

                // Flutter → Android: enable live SMS monitoring
                "startSmsMonitoring" -> {
                    if (smsReceiverPlugin == null) {
                        smsReceiverPlugin = SmsReceiverPlugin(flutterEngine)
                        smsReceiverPlugin!!.register(applicationContext)
                    }
                    result.success(null)
                }

                // Flutter → Android: disable live SMS monitoring
                "stopSmsMonitoring" -> {
                    smsReceiverPlugin?.unregister(applicationContext)
                    smsReceiverPlugin = null
                    result.success(null)
                }

                // Flutter → Android: trigger a mock transaction notification
                "triggerMockNotification" -> {
                    val amount = call.argument<Double>("amount") ?: 1250.0
                    val merchant = call.argument<String>("merchant") ?: "Mock Retail Shop"
                    val isDebit = call.argument<Boolean>("isDebit") ?: true
                    triggerMockNotification(amount, merchant, isDebit)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun triggerMockNotification(amount: Double, merchant: String, isDebit: Boolean) {
        val channelId = "transactions_channel"
        val channelName = "XPens Transactions"
        val channelDesc = "Notifications for auto-detected SMS bank transactions"
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val importance = android.app.NotificationManager.IMPORTANCE_DEFAULT
            val channel = android.app.NotificationChannel(channelId, channelName, importance).apply {
                description = channelDesc
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Deep link pointing to SMS parser ingestion
        val bodyText = if (isDebit) {
            "Your a/c no. XXX123 is debited by Rs.$amount on 2026-05-30 at $merchant."
        } else {
            "Your a/c no. XXX123 is credited by Rs.$amount on 2026-05-30 from $merchant."
        }
        val encodedBody = java.net.URLEncoder.encode(bodyText, "UTF-8")
        val encodedSender = java.net.URLEncoder.encode("BANK-SMS", "UTF-8")
        val deepLinkUri = "xpens://widget?action=sms&body=$encodedBody&sender=$encodedSender"

        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLinkUri)).apply {
            `package` = packageName
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntentFlags = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            intent,
            pendingIntentFlags
        )

        val iconRes = resources.getIdentifier("ic_launcher", "mipmap", packageName).let {
            if (it != 0) it else android.R.drawable.ic_dialog_info
        }

        val title = if (isDebit) "Debit Transaction Detected" else "Credit Transaction Detected"
        val formattedAmount = String.format("%,.0f", amount)
        val text = if (isDebit) {
            "Spent ₹$formattedAmount at $merchant. Tap to log."
        } else {
            "Received ₹$formattedAmount. Tap to log."
        }

        val notification = androidx.core.app.NotificationCompat.Builder(this, channelId)
            .setSmallIcon(iconRes)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }

    override fun onDestroy() {
        smsReceiverPlugin?.unregister(applicationContext)
        smsReceiverPlugin = null
        super.onDestroy()
    }

    // ── Voice recognition ──────────────────────────────────────────────

    private fun startVoiceRecognition() {
        val speechIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Say your transaction…")
        }
        @Suppress("DEPRECATION")
        startActivityForResult(speechIntent, voiceRequestCode)
    }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == voiceRequestCode) {
            val text = if (resultCode == Activity.RESULT_OK) {
                data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
            } else {
                null
            }
            voiceResultCallback?.success(text)
            voiceResultCallback = null
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
