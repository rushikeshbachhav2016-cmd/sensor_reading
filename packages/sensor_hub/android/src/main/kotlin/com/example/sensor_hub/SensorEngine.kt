package com.example.sensor_hub

import java.util.Random
import kotlin.math.PI
import kotlin.math.sin

class SensorEngine(val plugin: SensorHubPlugin) {
    companion object {
        const val MAX_HZ = 1000
        const val BUFFER_SIZE = 2048
        const val BATCH_INTERVAL_NS = 50_000_000L
        const val SEED = 12345L
    }

    var random = Random(SEED)
    val buffer = ArrayDeque<Float>()
    var firstIndex = 0L
    var dropped = 0

    var sessionId = 0
    var hz = 0
    var running = false
    var paused = false
    var waitingForReply = false
    var startMicros = 0L
    var resumedAt = 0L
    var resumedIndex = 0L
    var lastSentAt = 0L

    fun isGenerating(): Boolean {
        return running && !paused
    }

    fun start(sessionId: Int, hz: Int, startMicros: Long, now: Long) {
        this.sessionId = sessionId
        this.hz = hz
        this.startMicros = startMicros
        random = Random(SEED)
        buffer.clear()
        firstIndex = 0
        dropped = 0
        resumedIndex = 0
        resumedAt = now
        lastSentAt = now
        waitingForReply = false
        running = true
    }

    fun stop() {
        running = false
        waitingForReply = false
        buffer.clear()
        firstIndex = 0
        dropped = 0
    }

    fun pause(now: Long) {
        if (running && !paused) {
            generate(now)
        }
        paused = true
    }

    fun resume(now: Long) {
        if (!paused) return
        paused = false
        resumedAt = now
        resumedIndex = nextIndex()
    }

    fun tick(now: Long) {
        if (!isGenerating()) return
        generate(now)
        sendIfReady(now)
    }

    fun onReply(sessionId: Int, now: Long) {
        if (sessionId != this.sessionId || !running) return
        waitingForReply = false
        if (!paused) {
            sendIfReady(now)
        }
    }

    fun injectFault(message: String) {
        if (running) {
            plugin.sendFault(sessionId, "injected", message)
        }
    }

    fun nextIndex(): Long {
        return firstIndex + buffer.size
    }

    fun generate(now: Long) {
        val due = resumedIndex + (now - resumedAt) * hz / 1_000_000_000L
        while (nextIndex() < due) {
            val t = nextIndex().toDouble() / hz
            val value = sin(2 * PI * t) + 0.25 * sin(2 * PI * 7 * t) + (random.nextDouble() - 0.5) * 0.2
            buffer.addLast(value.toFloat())
            if (buffer.size > BUFFER_SIZE) {
                buffer.removeFirst()
                firstIndex++
                dropped++
            }
        }
    }

    fun sendIfReady(now: Long) {
        if (waitingForReply || buffer.isEmpty() || now - lastSentAt < BATCH_INTERVAL_NS) return
        if (dropped > 0) {
            plugin.sendFault(sessionId, "overflow", "Dart was busy, dropped $dropped samples")
            dropped = 0
        }
        val batch = SensorBatch(startMicros + firstIndex * 1_000_000L / hz, buffer.toFloatArray())
        firstIndex += buffer.size
        buffer.clear()
        waitingForReply = true
        lastSentAt = now
        plugin.sendBatch(sessionId, batch)
    }
}
