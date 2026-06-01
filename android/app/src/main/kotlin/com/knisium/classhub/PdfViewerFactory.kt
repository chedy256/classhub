package com.knisium.classhub

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class PdfViewerFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val filePath = params?.get("filePath") as? String ?: ""
        val initialPage = (params?.get("initialPage") as? Int) ?: 0
        val isDark = (params?.get("isDark") as? Boolean) ?: false
        return PdfRendererView(context, filePath, initialPage, isDark, messenger, viewId)
    }
}