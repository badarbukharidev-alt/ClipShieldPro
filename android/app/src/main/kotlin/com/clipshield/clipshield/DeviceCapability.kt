package com.clipshield.clipshield

import android.app.ActivityManager
import android.content.Context
import android.os.Build

/**
 * What this phone can actually cope with.
 *
 * Rendering was tuned for the machine it was developed on. On a 2 GB phone the
 * same job asks for more memory than the device has and Android kills the
 * process, which the user sees as "ClipShield isn't responding" or the app
 * simply vanishing mid-render.
 *
 * The numbers reported here are the ones that actually decide that: total RAM,
 * the per-app heap ceiling (which is far smaller than total RAM and is what an
 * allocation is really measured against), the core count, and Android's own
 * low-RAM flag.
 */
object DeviceCapability {

    fun describe(context: Context): Map<String, Any> {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager

        val memoryInfo = ActivityManager.MemoryInfo()
        am?.getMemoryInfo(memoryInfo)

        // memoryClass is the heap an ordinary app may use, in MB. largeMemoryClass
        // is what it gets with android:largeHeap. Both are much smaller than
        // total RAM, and the smaller one is what an OutOfMemoryError is measured
        // against.
        val heapMb = am?.memoryClass ?: 0
        val largeHeapMb = am?.largeMemoryClass ?: 0

        return mapOf(
            "totalMemoryBytes" to memoryInfo.totalMem,
            "availableMemoryBytes" to memoryInfo.availMem,
            "lowMemory" to memoryInfo.lowMemory,
            // Android's own verdict, set by the manufacturer. Trusted over the
            // raw total: a device flagged low-RAM has a stricter killer
            // regardless of what the spec sheet says.
            "isLowRamDevice" to (am?.isLowRamDevice ?: false),
            "heapLimitMb" to heapMb,
            "largeHeapLimitMb" to largeHeapMb,
            "processors" to Runtime.getRuntime().availableProcessors(),
            "sdkInt" to Build.VERSION.SDK_INT,
            "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
            // 64-bit matters: a 32-bit process cannot address much regardless of
            // how much RAM is fitted, and hits its ceiling far earlier.
            "is64Bit" to (Build.SUPPORTED_64_BIT_ABIS?.isNotEmpty() ?: false)
        )
    }
}
