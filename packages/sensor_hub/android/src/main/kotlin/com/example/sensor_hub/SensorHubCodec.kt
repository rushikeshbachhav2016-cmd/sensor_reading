package com.example.sensor_hub

import io.flutter.plugin.common.StandardMessageCodec
import java.io.ByteArrayOutputStream

class SensorBatch(val startMicros: Long, val values: FloatArray)

object SensorHubCodec : StandardMessageCodec() {
    const val BATCH_TYPE = 128

    override fun writeValue(stream: ByteArrayOutputStream, value: Any?) {
        if (value is SensorBatch) {
            stream.write(BATCH_TYPE)
            writeLong(stream, value.startMicros)
            writeInt(stream, value.values.size)
            writeAlignment(stream, 4)
            for (v in value.values) {
                writeFloat(stream, v)
            }
        } else {
            super.writeValue(stream, value)
        }
    }
}
