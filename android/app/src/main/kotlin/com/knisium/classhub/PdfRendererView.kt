package com.knisium.classhub

import android.content.Context
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import android.view.View
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.File

class PdfRendererView(
    context: Context,
    private val filePath: String,
    private val initialPage: Int,
    private var isDark: Boolean,
    messenger: BinaryMessenger,
    viewId: Int
) : PlatformView {

    private val recyclerView = RecyclerView(context)
    private var pdfRenderer: PdfRenderer? = null
    private var adapter: PdfPageAdapter? = null
    private val pagePool = PdfPagePool()

    // MethodChannel for Flutter ↔ Native communication
    private val channel = MethodChannel(messenger, "pdf_viewer/control/$viewId")

    init {
        setupRecyclerView(context)
        openPdf(context)
        setupMethodChannel()
    }

    // ─── Setup ───────────────────────────────────────────────────────────────

    private fun setupRecyclerView(context: Context) {
        recyclerView.apply {
            layoutManager = LinearLayoutManager(context)
            setBackgroundColor(if (isDark) Color.parseColor("#121212") else Color.parseColor("#F5F5F5"))
            setHasFixedSize(false)
        }
    }

    private fun openPdf(context: Context) {
        val file = File(filePath)
        if (!file.exists()) return

        val fd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        pdfRenderer = PdfRenderer(fd)
        val renderer = pdfRenderer ?: return

        adapter = PdfPageAdapter(
            context = context,
            renderer = renderer,
            pool = pagePool,
            isDark = isDark
        )
        recyclerView.adapter = adapter

        // Jump to initial page after layout
        recyclerView.post {
            if (initialPage > 0) scrollToPage(initialPage)
        }
    }

    private fun setupMethodChannel() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setDarkMode" -> {
                    val dark = call.argument<Boolean>("isDark") ?: false
                    setDarkMode(dark)
                    result.success(null)
                }
                "jumpToPage" -> {
                    val page = call.argument<Int>("page") ?: 0
                    scrollToPage(page)
                    result.success(null)
                }
                "getPageCount" -> {
                    result.success(pdfRenderer?.pageCount ?: 0)
                }
                "getCurrentPage" -> {
                    val lm = recyclerView.layoutManager as? LinearLayoutManager
                    result.success(lm?.findFirstVisibleItemPosition() ?: 0)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ─── Controls ────────────────────────────────────────────────────────────

    private fun setDarkMode(dark: Boolean) {
        isDark = dark
        recyclerView.setBackgroundColor(
            if (dark) Color.parseColor("#121212") else Color.parseColor("#F5F5F5")
        )
        adapter?.setDarkMode(dark)
    }

    private fun scrollToPage(page: Int) {
        val lm = recyclerView.layoutManager as? LinearLayoutManager
        lm?.scrollToPositionWithOffset(page, 0)
    }

    // ─── View ────────────────────────────────────────────────────────────────

    override fun getView(): View = recyclerView

    override fun dispose() {
        adapter?.destroy()
        pdfRenderer?.close()
        channel.setMethodCallHandler(null)
    }
}