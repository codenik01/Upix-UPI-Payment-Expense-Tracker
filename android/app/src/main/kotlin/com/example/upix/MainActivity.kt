package com.example.upix

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log
import androidx.core.content.ContextCompat
import android.Manifest
import android.content.pm.PackageManager

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.upi.expense.tracker/sms"
    private val EVENT_CHANNEL = "com.upi.expense.tracker/sms_stream"
    
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var smsReceiver: SmsBroadcastReceiver
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d("SmsPlugin", "=== CONFIGURING FLUTTER ENGINE ===")
        
        // Setup Method Channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            Log.d("SmsPlugin", "Method called: ${call.method}")
            when (call.method) {
                "readExistingSms" -> {
                    val limit = call.argument<Int>("limit") ?: 100
                    Log.d("SmsPlugin", "Reading existing SMS with limit: $limit")
                    result.success(emptyList<Map<String, Any>>())
                }
                "checkPermissions" -> {
                    val hasPermission = checkSmsPermissions()
                    Log.d("SmsPlugin", "Permission check result: $hasPermission")
                    result.success(hasPermission)
                }
                "testConnection" -> {
                    Log.d("SmsPlugin", "Test connection received from Flutter")
                    result.success("Connected to Android successfully!")
                }
                else -> result.notImplemented()
            }
        }
        
        // Setup Event Channel
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                Log.d("SmsPlugin", "=== EVENT CHANNEL: onListen called ===")
                eventSink = events
                
                // Test connection immediately
                events?.success("EVENT_CHANNEL_CONNECTED")
                Log.d("SmsPlugin", "Sent connection test to Flutter")
                
                // Register SMS receiver
                smsReceiver = SmsBroadcastReceiver(events)
                val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
                filter.priority = 999
                
                try {
                    registerReceiver(smsReceiver, filter)
                    Log.d("SmsPlugin", "SMS Receiver registered successfully")
                    events?.success("RECEIVER_REGISTERED")
                } catch (e: Exception) {
                    Log.e("SmsPlugin", "Failed to register receiver: $e")
                    events?.error("ERROR", "Failed to register receiver: $e", null)
                }
            }
            
            override fun onCancel(arguments: Any?) {
                Log.d("SmsPlugin", "=== EVENT CHANNEL: onCancel called ===")
                eventSink = null
                try {
                    unregisterReceiver(smsReceiver)
                    Log.d("SmsPlugin", "SMS Receiver unregistered")
                } catch (e: Exception) {
                    Log.e("SmsPlugin", "Error unregistering receiver: $e")
                }
            }
        })
        
        Log.d("SmsPlugin", "Flutter engine configuration complete")
    }
    
    inner class SmsBroadcastReceiver(private val eventSink: EventChannel.EventSink?) : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            Log.d("SmsReceiver", "=== SMS RECEIVED ===")
            Log.d("SmsReceiver", "Intent action: ${intent.action}")
            
            if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
                val bundle = intent.extras
                if (bundle != null) {
                    val pdus = bundle.get("pdus") as Array<*>?
                    Log.d("SmsReceiver", "PDUs received: ${pdus?.size ?: 0}")
                    
                    if (pdus != null) {
                        for (i in pdus.indices) {
                            try {
                                val smsMessage = SmsMessage.createFromPdu(pdus[i] as ByteArray)
                                val messageBody = smsMessage?.messageBody ?: ""
                                val sender = smsMessage?.originatingAddress ?: ""
                                
                                Log.d("SmsReceiver", "Sender: $sender")
                                Log.d("SmsReceiver", "Message: $messageBody")
                                
                                // Send to Flutter
                                if (eventSink != null) {
                                    Log.d("SmsReceiver", "Sending to Flutter via eventSink")
                                    eventSink.success(messageBody)
                                    Log.d("SmsReceiver", "Successfully sent to Flutter")
                                } else {
                                    Log.e("SmsReceiver", "ERROR: eventSink is NULL!")
                                }
                            } catch (e: Exception) {
                                Log.e("SmsReceiver", "Error processing PDU: $e")
                            }
                        }
                    }
                } else {
                    Log.e("SmsReceiver", "Bundle is null!")
                }
            } else {
                Log.d("SmsReceiver", "Not an SMS_RECEIVED_ACTION")
            }
        }
    }
    
    private fun checkSmsPermissions(): Boolean {
        val permissions = arrayOf(
            Manifest.permission.READ_SMS,
            Manifest.permission.RECEIVE_SMS
        )
        
        return permissions.all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d("SmsPlugin", "Activity destroyed")
        try {
            if (::smsReceiver.isInitialized) {
                unregisterReceiver(smsReceiver)
            }
        } catch (e: Exception) {
            Log.e("SmsPlugin", "Error in onDestroy", e)
        }
    }
}