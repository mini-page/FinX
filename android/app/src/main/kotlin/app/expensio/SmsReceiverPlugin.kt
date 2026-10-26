package app.expensio

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives incoming SMS broadcasts and forwards them to the Flutter layer via
 * the `app.expensio/sms_receiver` MethodChannel.
 *
 * Registration / unregistration is handled by [MainActivity] so the receiver
 * only runs while the Flutter engine is live.
 */
class SmsReceiverPlugin(
    private val flutterEngine: FlutterEngine,
) : BroadcastReceiver() {

    companion object {
        const val CHANNEL_NAME = "app.expensio/sms_receiver"
    }

    private val channel: MethodChannel by lazy {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages: Array<SmsMessage> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            Telephony.Sms.Intents.getMessagesFromIntent(intent)
        } else {
            @Suppress("DEPRECATION")
            val pdus = intent.extras?.get("pdus") as? Array<*> ?: return
            pdus.mapNotNull { pdu ->
                @Suppress("DEPRECATION")
                SmsMessage.createFromPdu(pdu as ByteArray)
            }.toTypedArray()
        }

        for (sms in messages) {
            val sender = sms.displayOriginatingAddress ?: sms.originatingAddress ?: continue
            val body = sms.messageBody ?: continue
            val timestamp = sms.timestampMillis.takeIf { it > 0L } ?: System.currentTimeMillis()

            channel.invokeMethod(
                "onSmsReceived",
                mapOf(
                    "sender" to sender,
                    "body" to body,
                    "timestamp" to timestamp,
                ),
            )
        }
    }

    fun register(context: Context) {
        val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION).apply {
            priority = IntentFilter.SYSTEM_HIGH_PRIORITY
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(this, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(this, filter)
        }
    }

    fun unregister(context: Context) {
        try {
            context.unregisterReceiver(this)
        } catch (_: IllegalArgumentException) {
            // Already unregistered — safe to ignore
        }
    }
}
