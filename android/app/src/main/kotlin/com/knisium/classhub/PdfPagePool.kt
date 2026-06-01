package com.knisium.classhub

import android.graphics.Bitmap
import android.util.LruCache

class PdfPagePool(maxSizeBytes: Int = 32 * 1024 * 1024) { // 32MB default

    private val cache = object : LruCache<Int, Bitmap>(maxSizeBytes) {
        override fun sizeOf(key: Int, bitmap: Bitmap) = bitmap.byteCount
    }

    fun get(page: Int): Bitmap? = cache.get(page)

    fun put(page: Int, bitmap: Bitmap) = cache.put(page, bitmap)

    fun evict(page: Int) = cache.remove(page)

    fun clear() = cache.evictAll()
}