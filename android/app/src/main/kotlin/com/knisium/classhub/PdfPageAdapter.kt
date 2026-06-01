package com.knisium.classhub

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.view.ViewGroup
import android.widget.ImageView
import androidx.recyclerview.widget.RecyclerView
import kotlinx.coroutines.*

class PdfPageAdapter(
    private val context: Context,
    private val renderer: PdfRenderer,
    private val pool: PdfPagePool,
    private var isDark: Boolean
) : RecyclerView.Adapter<PdfPageAdapter.PageHolder>() {

    private val scale = context.resources.displayMetrics.density * 1.5f

    // Coroutine scope for background rendering
    private val renderScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    inner class PageHolder(val imageView: ImageView) : RecyclerView.ViewHolder(imageView)

    override fun getItemCount() = renderer.pageCount

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): PageHolder {
        val imageView = ImageView(context).apply {
            layoutParams = RecyclerView.LayoutParams(
                RecyclerView.LayoutParams.MATCH_PARENT,
                RecyclerView.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = 8 }
            scaleType = ImageView.ScaleType.FIT_XY
            adjustViewBounds = true
            setBackgroundColor(if (isDark) Color.parseColor("#121212") else Color.parseColor("#F5F5F5"))
        }
        return PageHolder(imageView)
    }

    override fun onBindViewHolder(holder: PageHolder, position: Int) {
        // Show cached bitmap immediately if available
        val cached = pool.get(position)
        if (cached != null) {
            holder.imageView.setImageBitmap(cached)
            return
        }

        // Placeholder while rendering
        holder.imageView.setImageBitmap(null)
        holder.imageView.setBackgroundColor(
            if (isDark) Color.parseColor("#2C2C2C") else Color.parseColor("#E0E0E0")
        )

        // Render off main thread
        renderScope.launch {
            val bitmap = renderPage(position)
            pool.put(position, bitmap)

            withContext(Dispatchers.Main) {
                // Only update if view is still showing this page
                if (holder.bindingAdapterPosition == position) {
                    holder.imageView.setImageBitmap(bitmap)
                }
            }
        }
    }

    override fun onViewRecycled(holder: PageHolder) {
        super.onViewRecycled(holder)
        // Cancel any in-flight render for this holder
        holder.imageView.setImageBitmap(null)
    }

    // ─── Page rendering ──────────────────────────────────────────────────────

    private fun renderPage(pageIndex: Int): Bitmap {
        val page = renderer.openPage(pageIndex)
        val width = (page.width * scale).toInt()
        val height = (page.height * scale).toInt()
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.WHITE)
        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
        page.close()
        return bitmap
    }

    // ─── Theme ───────────────────────────────────────────────────────────────

    fun setDarkMode(dark: Boolean) {
        isDark = dark
        notifyItemRangeChanged(0, itemCount)   // re-bind all visible items
    }

    fun destroy() {
        renderScope.cancel()
        pool.clear()
    }
}