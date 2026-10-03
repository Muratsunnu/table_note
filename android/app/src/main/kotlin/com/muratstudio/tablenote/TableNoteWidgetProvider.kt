package com.muratstudio.tablenote

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.util.Locale

object TableNoteWidgetStore {
    fun preferences(context: Context) = context.getSharedPreferences("table_note_widgets", Context.MODE_PRIVATE)
    fun snapshot(context: Context): JSONObject = try {
        JSONObject(preferences(context).getString("snapshot", "{}") ?: "{}")
    } catch (_: Exception) { JSONObject() }
    fun entries(snapshot: JSONObject): List<JSONObject> {
        val array = snapshot.optJSONArray("entries") ?: return emptyList()
        return (0 until array.length()).mapNotNull { array.optJSONObject(it) }
    }
    fun metrics(entry: JSONObject): List<JSONObject> {
        val array = entry.optJSONArray("metrics") ?: return emptyList()
        return (0 until array.length()).mapNotNull { array.optJSONObject(it) }
    }
    /// Absent in a snapshot written by an older app build.
    fun rows(entry: JSONObject): List<JSONObject> {
        val array = entry.optJSONArray("rows") ?: return emptyList()
        return (0 until array.length()).mapNotNull { array.optJSONObject(it) }
    }
    fun text(snapshot: JSONObject, key: String, tr: String, en: String): String {
        val fallback = if (snapshot.optString("language", Locale.getDefault().language) == "en") en else tr
        return snapshot.optJSONObject("strings")?.optString(key, fallback) ?: fallback
    }
    /// Uygulamanin kendi renkleri. Anahtar yoksa widget kendi yedegini kullanir,
    /// yani eski bir anlik goruntu de calisir.
    fun color(snapshot: JSONObject, key: String, fallback: Int): Int {
        val palette = snapshot.optJSONObject("palette") ?: return fallback
        return if (palette.has(key)) palette.optInt(key, fallback) else fallback
    }
    /// Dizideki bos deger JSON'da null olarak gelir; optInt onu 0 yapar ve 0
    /// gecerli bir renk oldugu icin bu fark onemli.
    fun colorAt(row: JSONObject, key: String, index: Int): Int? {
        val array = row.optJSONArray(key) ?: return null
        if (index < 0 || index >= array.length() || array.isNull(index)) return null
        return array.optInt(index)
    }
    fun wash(color: Int, alpha: Int): Int =
        Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
}

class TableNoteWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager,
        appWidgetId: Int, newOptions: Bundle) { update(context, manager, appWidgetId) }
    override fun onDeleted(context: Context, ids: IntArray) {
        val edit = TableNoteWidgetStore.preferences(context).edit()
        ids.forEach { edit.remove("entry_$it").remove("metric_$it") }
        edit.apply()
    }
    override fun onRestored(context: Context, oldIds: IntArray, newIds: IntArray) {
        val preferences = TableNoteWidgetStore.preferences(context)
        val edit = preferences.edit()
        oldIds.zip(newIds).forEach { (old, new) ->
            edit.putString("entry_$new", preferences.getString("entry_$old", null))
            edit.putString("metric_$new", preferences.getString("metric_$old", ""))
            edit.remove("entry_$old").remove("metric_$old")
        }
        edit.commit()
        onUpdate(context, AppWidgetManager.getInstance(context), newIds)
    }

    companion object {
        private val CELLS = listOf(
            R.id.grid_cell_0, R.id.grid_cell_1, R.id.grid_cell_2,
            R.id.grid_cell_3, R.id.grid_cell_4,
        )

        /// En fazla govde satiri. Uzerinde bir yerde RemoteViews'in bellek
        /// siniri var ve daha fazlasi zaten okunmuyor.
        private const val MAX_ROWS = 6

        /// Widget'in cizecegi bir sutun. `source` satirin cells dizisine bakar;
        /// secilen toplam icin eklenen sutunun kaynagi yoktur, degerini
        /// metricId ile values'tan alir.
        private class GridColumn(
            val label: String,
            val numeric: Boolean,
            val source: Int?,
            val metricId: String?,
        )

        /// RemoteViews olcum yapamaz, bu yuzden hem satir hem sutun sayisi
        /// launcher'in bildirdigi boyuttan cikarilir.
        private fun rowCapacity(manager: AppWidgetManager, id: Int): Int {
            val options = manager.getAppWidgetOptions(id)
            val height = maxOf(
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0),
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0),
            )
            // Hicbir sey bildirmeyen launcher'da tablo tek satirla da olsa cizilsin.
            if (height <= 0) return 1
            // Baslik, alt yazi, izgara basligi ve dugme icin ayrilan pay.
            return ((height - 140) / 22).coerceIn(1, MAX_ROWS)
        }

        private fun columnBudget(manager: AppWidgetManager, id: Int, isTally: Boolean): Int {
            val options = manager.getAppWidgetOptions(id)
            val width = maxOf(
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0),
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0),
            )
            val wide = width >= 250
            // Gun hucrelerinde bir iki karakter var; tablonun genis sutunlarindan
            // daha fazlasi ayni yere sigar.
            return if (isTally) (if (wide) 5 else 4) else (if (wide) 4 else 3)
        }

        /// Kullanicinin bastaki sutunlari, arasinda yoksa sectigi toplam da
        /// eklenerek. Cetele sagdan okunur: dar widget en eski gunu atar,
        /// bugunu degil.
        private fun gridColumns(
            entry: JSONObject,
            metric: JSONObject?,
            limit: Int,
            isTally: Boolean,
        ): List<GridColumn> {
            val payload = entry.optJSONArray("columns") ?: return emptyList()
            var columns = (0 until payload.length()).mapNotNull { index ->
                payload.optJSONObject(index)?.let {
                    GridColumn(
                        label = it.optString("label"),
                        numeric = it.optBoolean("numeric"),
                        source = index,
                        metricId = it.optString("metricId").ifEmpty { null },
                    )
                }
            }
            if (columns.isEmpty()) return emptyList()
            if (isTally) {
                return listOf(columns.first()) + columns.drop(1).takeLast(limit - 1)
            }
            if (metric != null) {
                val metricId = metric.optString("id")
                // Secilen toplam zaten sutunlarin arasindaysa ikinci kez eklenmez.
                if (metricId.isNotEmpty() && columns.none { it.metricId == metricId }) {
                    columns = columns.take(limit - 1) +
                        GridColumn(metric.optString("label"), true, null, metricId)
                }
            }
            return columns.take(limit)
        }

        private fun cellValue(row: JSONObject, column: GridColumn): String {
            val source = column.source
            if (source != null) {
                val cells = row.optJSONArray("cells") ?: return ""
                return if (source < cells.length()) cells.optString(source) else ""
            }
            return column.metricId?.let { row.optJSONObject("values")?.optString(it, "") }.orEmpty()
        }

        /// Isaretin yazildigi renk: uygulama durum rengini okunur kalsin diye
        /// koyultup aciyor ve sonucu inks olarak gonderiyor.
        private fun ink(row: JSONObject, column: GridColumn): Int? {
            val source = column.source ?: return null
            return TableNoteWidgetStore.colorAt(row, "inks", source)
                ?: TableNoteWidgetStore.colorAt(row, "colors", source)
        }

        /// Uygulamanin toplamlar kutusuyla ayni kural: sutunun toplami varsa o,
        /// ilk sutun sayisal degilse oraya "Toplam".
        private fun footerCells(
            snapshot: JSONObject,
            entry: JSONObject,
            metric: JSONObject?,
            columns: List<GridColumn>,
        ): List<String>? {
            if (entry.optString("kind") != "table") return null
            val footer = entry.optJSONArray("footer")
            var hasTotal = false
            val cells = columns.map { column ->
                val source = column.source
                when {
                    source != null && footer != null && source < footer.length() -> {
                        val text = footer.optString(source)
                        if (column.numeric && text.isNotEmpty()) hasTotal = true
                        text
                    }
                    column.metricId != null && metric != null -> {
                        hasTotal = true
                        metric.optString("value")
                    }
                    else -> ""
                }
            }
            if (!hasTotal) return null
            val total = TableNoteWidgetStore.text(snapshot, "total", "Toplam", "Total")
            return if (columns.first().numeric) cells else listOf(total) + cells.drop(1)
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            manager.getAppWidgetIds(ComponentName(context, TableNoteWidgetProvider::class.java))
                .forEach { update(context, manager, it) }
        }

        fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val preferences = TableNoteWidgetStore.preferences(context)
            val snapshot = TableNoteWidgetStore.snapshot(context)
            val selection = preferences.getString("entry_$id", null)
            val entry = TableNoteWidgetStore.entries(snapshot).firstOrNull { it.optString("id") == selection }
            val metricId = preferences.getString("metric_$id", "") ?: ""
            val metric = entry?.let { TableNoteWidgetStore.metrics(it).firstOrNull { m -> m.optString("id") == metricId } }
            val views = RemoteViews(context.packageName, R.layout.table_note_widget)
            val dark = snapshot.optBoolean("dark", false)

            val foreground = TableNoteWidgetStore.color(
                snapshot, "text", if (dark) Color.rgb(239, 244, 255) else Color.rgb(23, 37, 84))
            val secondary = TableNoteWidgetStore.color(
                snapshot, "muted", if (dark) Color.rgb(174, 189, 217) else Color.rgb(87, 104, 133))
            val accent = TableNoteWidgetStore.color(
                snapshot, "accent", if (dark) Color.rgb(96, 165, 250) else Color.rgb(37, 99, 235))

            views.setInt(R.id.widget_root, "setBackgroundResource",
                if (dark) R.drawable.widget_background_dark else R.drawable.widget_background)
            listOf(R.id.widget_title, R.id.widget_settings).forEach { views.setTextColor(it, foreground) }
            listOf(R.id.widget_count, R.id.widget_rows_footer).forEach { views.setTextColor(it, secondary) }

            val choose = TableNoteWidgetStore.text(snapshot, "choose", "Tablo veya çetele seç", "Choose a table or tally")
            val missing = TableNoteWidgetStore.text(snapshot, "missing", "Widget seçimini değiştir.", "Edit the widget selection.")
            views.setTextViewText(R.id.widget_title, entry?.optString("name") ?: "Table Note")

            // Iri sayinin yerine tek satirlik ozet: kac kayit, secilmisse toplam.
            val total = TableNoteWidgetStore.text(snapshot, "total", "Toplam", "Total")
            val summary = when {
                entry == null -> if (selection == null) choose else missing
                metric != null ->
                    "${entry.optString("countText")} · $total ${metric.optString("label")} " +
                        metric.optString("value")
                metricId.isNotEmpty() -> "${entry.optString("countText")} · $missing"
                else -> entry.optString("countText")
            }
            views.setTextViewText(R.id.widget_count, summary)

            val add = entry?.let {
                if (it.optString("kind") == "tally") TableNoteWidgetStore.text(snapshot, "addItem", "+ Öğe ekle", "+ Add item")
                else TableNoteWidgetStore.text(snapshot, "add", "+ Kayıt ekle", "+ Add record")
            } ?: TableNoteWidgetStore.text(snapshot, "open", "Uygulamayı aç", "Open app")
            views.setTextViewText(R.id.widget_add, add)

            views.removeAllViews(R.id.widget_grid)
            val isTally = entry?.optString("kind") == "tally"
            val columns = entry?.let {
                gridColumns(it, metric, columnBudget(manager, id, isTally), isTally)
            }.orEmpty()
            // Satirlar ekrandaki sirayla geliyor, burada yeniden siralanmaz.
            val rows = entry?.let { TableNoteWidgetStore.rows(it) }
                .orEmpty().take(rowCapacity(manager, id))

            if (columns.isNotEmpty() && rows.isNotEmpty()) {
                val header = TableNoteWidgetStore.color(snapshot, "header", Color.TRANSPARENT)
                val onHeader = TableNoteWidgetStore.color(snapshot, "onHeader", secondary)
                val todayColumn = entry?.optInt("todayColumn", -1) ?: -1
                fun isToday(column: GridColumn) = todayColumn >= 0 && column.source == todayColumn

                fun gravityFor(column: GridColumn, index: Int): Int {
                    val horizontal = when {
                        column.numeric -> Gravity.END
                        // Gun sutunlari bir blok halinde okunur, ortada dursunlar.
                        isTally && index > 0 -> Gravity.CENTER_HORIZONTAL
                        else -> Gravity.START
                    }
                    return horizontal or Gravity.CENTER_VERTICAL
                }

                fun row(strong: Boolean): RemoteViews = RemoteViews(
                    context.packageName,
                    if (strong) R.layout.widget_grid_row_strong else R.layout.widget_grid_row,
                )

                // Baslik
                val headerRow = row(true)
                columns.forEachIndexed { index, column ->
                    val cell = CELLS[index]
                    headerRow.setTextViewText(cell, column.label)
                    headerRow.setTextColor(cell, onHeader)
                    headerRow.setInt(cell, "setGravity", gravityFor(column, index))
                    headerRow.setInt(cell, "setBackgroundColor", if (isToday(column))
                        TableNoteWidgetStore.color(snapshot, "todayHeader",
                            TableNoteWidgetStore.wash(accent, 89))
                    else Color.TRANSPARENT)
                }
                for (index in columns.size until CELLS.size) {
                    headerRow.setViewVisibility(CELLS[index], View.GONE)
                }
                headerRow.setInt(R.id.grid_row, "setBackgroundColor", header)
                views.addView(R.id.widget_grid, headerRow)

                // Govde
                rows.forEachIndexed { rowIndex, source ->
                    val line = row(false)
                    columns.forEachIndexed { index, column ->
                        val cell = CELLS[index]
                        line.setTextViewText(cell, cellValue(source, column))
                        line.setTextColor(cell, ink(source, column) ?: foreground)
                        line.setInt(cell, "setGravity", gravityFor(column, index))
                        val status = column.source?.let {
                            TableNoteWidgetStore.colorAt(source, "colors", it)
                        }
                        line.setInt(cell, "setBackgroundColor", when {
                            status != null -> TableNoteWidgetStore.wash(status, 38)
                            isToday(column) -> TableNoteWidgetStore.color(snapshot, "todayCell",
                                TableNoteWidgetStore.wash(accent, 31))
                            else -> Color.TRANSPARENT
                        })
                    }
                    for (index in columns.size until CELLS.size) {
                        line.setViewVisibility(CELLS[index], View.GONE)
                    }
                    // Ekrandaki tablonun kendisiyle ayni sirali zemin.
                    line.setInt(R.id.grid_row, "setBackgroundColor",
                        TableNoteWidgetStore.color(snapshot,
                            if (rowIndex % 2 == 0) "rowEven" else "rowOdd", Color.TRANSPARENT))
                    views.addView(R.id.widget_grid, line)
                }

                // Toplam satiri yalnizca yer varken; kisa widget'ta veri satiri
                // daha degerli.
                val footer = if (rows.size < 3) null else
                    entry?.let { footerCells(snapshot, it, metric, columns) }
                if (footer != null) {
                    val line = row(true)
                    columns.forEachIndexed { index, column ->
                        val cell = CELLS[index]
                        line.setTextViewText(cell, footer[index])
                        line.setTextColor(cell, foreground)
                        line.setInt(cell, "setGravity", gravityFor(column, index))
                    }
                    for (index in columns.size until CELLS.size) {
                        line.setViewVisibility(CELLS[index], View.GONE)
                    }
                    line.setInt(R.id.grid_row, "setBackgroundColor",
                        TableNoteWidgetStore.wash(header, 140))
                    views.addView(R.id.widget_grid, line)
                }
            }

            val marked = entry?.optString("todayMarked").orEmpty()
            views.setViewVisibility(R.id.widget_rows_footer,
                if (marked.isEmpty() || rows.isEmpty()) View.GONE else View.VISIBLE)
            views.setTextViewText(R.id.widget_rows_footer, marked)

            views.setContentDescription(R.id.widget_settings,
                TableNoteWidgetStore.text(snapshot, "edit", "Widget’ı düzenle", "Edit widget"))
            views.setOnClickPendingIntent(R.id.widget_root, open(context, id, entry, false))
            views.setOnClickPendingIntent(R.id.widget_add, open(context, id, entry, true))
            val configure = Intent(context, TableNoteWidgetConfigureActivity::class.java)
                .setData(Uri.parse("tablenote-config://widget/$id"))
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            views.setOnClickPendingIntent(R.id.widget_settings, PendingIntent.getActivity(context, id, configure,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            manager.updateAppWidget(id, views)
        }

        private fun open(context: Context, widgetId: Int, entry: JSONObject?, add: Boolean): PendingIntent {
            val uri = Uri.Builder().scheme("com.muratstudio.tablenote").authority("widget")
                .path(if (add && entry != null) "/add" else "/open")
                .appendQueryParameter("instance", widgetId.toString())
            if (entry != null) uri.appendQueryParameter("kind", entry.optString("kind"))
                .appendQueryParameter("id", entry.optString("tableId"))
            val intent = Intent(Intent.ACTION_VIEW, uri.build(), context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            return PendingIntent.getActivity(context, widgetId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
    }
}
