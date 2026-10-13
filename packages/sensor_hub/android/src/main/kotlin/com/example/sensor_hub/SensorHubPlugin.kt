package com.example.sensor_hub

import android.app.Activity
import android.app.Application
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SensorHubPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    Application.ActivityLifecycleCallbacks, Runnable {

    val mainHandler = Handler(Looper.getMainLooper())
    var lastSessionId = 0

    var controlChannel: MethodChannel? = null
    var dataChannel: BasicMessageChannel<Any?>? = null
    var thread: HandlerThread? = null
    var handler: Handler? = null
    var engine: SensorEngine? = null
    var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        thread = HandlerThread("sensor_hub")
        thread!!.start()
        handler = Handler(thread!!.looper)
        engine = SensorEngine(this)

        dataChannel = BasicMessageChannel(binding.binaryMessenger, "sensor_hub/data", SensorHubCodec)
        controlChannel = MethodChannel(binding.binaryMessenger, "sensor_hub/control")
        controlChannel!!.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        controlChannel!!.setMethodCallHandler(null)
        controlChannel = null
        dataChannel = null
        handler!!.removeCallbacks(this)
        thread!!.quitSafely()
        thread = null
        handler = null
    }

    fun now(): Long {
        return SystemClock.elapsedRealtimeNanos()
    }

    override fun run() {
        engine!!.tick(now())
        if (engine!!.isGenerating()) {
            handler?.postDelayed(this, 10)
        }
    }

    fun startTicking() {
        handler?.removeCallbacks(this)
        handler?.post(this)
    }

    fun sendBatch(sessionId: Int, batch: SensorBatch) {
        mainHandler.post {
            dataChannel?.send(listOf(sessionId, batch)) {
                handler?.post { engine!!.onReply(sessionId, now()) }
            }
        }
    }

    fun sendFault(sessionId: Int, code: String, message: String) {
        val fault = mapOf("code" to code, "message" to message)
        mainHandler.post { dataChannel?.send(listOf(sessionId, fault)) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "attach" -> {
                handler?.post { engine!!.stop() }
                result.success(null)
            }
            "describe" -> {
                val model = Build.MANUFACTURER + " " + Build.MODEL + " (synthetic)"
                result.success(mapOf("model" to model, "maxHz" to SensorEngine.MAX_HZ))
            }
            "start" -> {
                val hz = (call.argument<Any>("hz") as Number).toLong()
                if (hz < 1 || hz > SensorEngine.MAX_HZ) {
                    result.error("invalid_rate", "hz must be between 1 and " + SensorEngine.MAX_HZ, null)
                    return
                }
                lastSessionId++
                val sessionId = lastSessionId
                val startMicros = System.currentTimeMillis() * 1000
                handler?.post {
                    engine!!.start(sessionId, hz.toInt(), startMicros, now())
                    startTicking()
                }
                result.success(sessionId)
            }
            "stop" -> {
                handler?.post { engine!!.stop() }
                result.success(null)
            }
            "injectFault" -> {
                val message = call.argument<String>("message") ?: "injected"
                handler?.post { engine!!.injectFault(message) }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activity!!.application.registerActivityLifecycleCallbacks(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onDetachedFromActivity() {
        activity?.application?.unregisterActivityLifecycleCallbacks(this)
        activity = null
    }

    override fun onActivityStopped(a: Activity) {
        if (a != activity) return
        val stoppedAt = now()
        handler?.postAtFrontOfQueue {
            engine!!.pause(stoppedAt)
            handler?.removeCallbacks(this)
            Log.i("SensorHub", "paused " + (now() - stoppedAt) / 1_000_000.0 + " ms after going to background")
        }
    }

    override fun onActivityStarted(a: Activity) {
        if (a != activity) return
        handler?.post {
            engine!!.resume(now())
            if (engine!!.isGenerating()) {
                startTicking()
            }
        }
    }

    override fun onActivityCreated(a: Activity, savedInstanceState: Bundle?) {}
    override fun onActivityResumed(a: Activity) {}
    override fun onActivityPaused(a: Activity) {}
    override fun onActivitySaveInstanceState(a: Activity, outState: Bundle) {}
    override fun onActivityDestroyed(a: Activity) {}
}
