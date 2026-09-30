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
        private class RowViews(val root: Int, val dot: Int, val text: Int, val value: Int)

        private val ROWS = listOf(
            RowViews(R.id.widget_row_0, R.id.widget_row_0_dot, R.id.widget_row_0_text, R.id.widget_row_0_value),
            RowViews(R.id.widget_row_1, R.id.widget_row_1_dot, R.id.widget_row_1_text, R.id.widget_row_1_value),
            RowViews(R.id.widget_row_2, R.id.widget_row_2_dot, R.id.widget_row_2_text, R.id.widget_row_2_value),
            RowViews(R.id.widget_row_3, R.id.widget_row_3_dot, R.id.widget_row_3_text, R.id.widget_row_3_value),
            RowViews(R.id.widget_row_4, R.id.widget_row_4_dot, R.id.widget_row_4_text, R.id.widget_row_4_value),
        )

        /// RemoteViews cannot measure, so the row count comes from the reported size.
        private fun rowCapacity(manager: AppWidgetManager, id: Int): Int {
            val options = manager.getAppWidgetOptions(id)
            val height = maxOf(
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0),
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0),
            )
            // A launcher that reports nothing still gets one row rather than none.
            if (height <= 0) return 1
            return ((height - 165) / 24).coerceIn(0, ROWS.size)
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
            val foreground = if (dark) Color.rgb(239, 244, 255) else Color.rgb(23, 37, 84)
            val secondary = if (dark) Color.rgb(174, 189, 217) else Color.rgb(87, 104, 133)
            views.setInt(R.id.widget_root, "setBackgroundResource",
                if (dark) R.drawable.widget_background_dark else R.drawable.widget_background)
            listOf(R.id.widget_title, R.id.widget_value, R.id.widget_settings).forEach { views.setTextColor(it, foreground) }
            listOf(R.id.widget_count, R.id.widget_metric).forEach { views.setTextColor(it, secondary) }
            val choose = TableNoteWidgetStore.text(snapshot, "choose", "Tablo veya çetele seç", "Choose a table or tally")
            val missing = TableNoteWidgetStore.text(snapshot, "missing", "Widget seçimini değiştir.", "Edit the widget selection.")
            views.setTextViewText(R.id.widget_title, entry?.optString("name") ?: "Table Note")
            views.setTextViewText(R.id.widget_count, entry?.optString("countText")
                ?: if (selection == null) choose else missing)
            views.setTextViewText(R.id.widget_metric, when {
                entry == null -> ""
                metric != null -> "${TableNoteWidgetStore.text(snapshot, "total", "Toplam", "Total")} · ${metric.optString("label")}"
                metricId.isNotEmpty() -> missing
                else -> entry.optString("typeText")
            })
            // The grouped count keeps thousands separators; older snapshots lack it.
            views.setTextViewText(R.id.widget_value, metric?.optString("value")
                ?: if (entry != null && metricId.isEmpty())
                    entry.optString("countValue", entry.optInt("count").toString())
                else "—")
            val add = entry?.let {
                if (it.optString("kind") == "tally") TableNoteWidgetStore.text(snapshot, "addItem", "+ Öğe ekle", "+ Add item")
                else TableNoteWidgetStore.text(snapshot, "add", "+ Kayıt ekle", "+ Add record")
            } ?: TableNoteWidgetStore.text(snapshot, "open", "Uygulamayı aç", "Open app")
            views.setTextViewText(R.id.widget_add, add)
            // Rows arrive in display order, so this never reorders them.
            val recent = entry?.let { TableNoteWidgetStore.rows(it) }
                .orEmpty().take(rowCapacity(manager, id))
            val header = if (recent.isEmpty()) View.GONE else View.VISIBLE
            views.setViewVisibility(R.id.widget_divider, header)
            views.setViewVisibility(R.id.widget_rows_title, header)
            views.setInt(R.id.widget_divider, "setBackgroundColor",
                if (dark) Color.rgb(51, 65, 94) else Color.rgb(220, 229, 250))
            views.setTextColor(R.id.widget_rows_title, secondary)
            // A tally covering today shows today instead of a bare list of names.
            val today = entry?.optString("todayText").orEmpty()
            views.setTextViewText(R.id.widget_rows_title, when {
                today.isNotEmpty() -> today
                entry?.optString("kind") == "tally" ->
                    TableNoteWidgetStore.text(snapshot, "items", "Öğeler", "Items")
                else -> TableNoteWidgetStore.text(snapshot, "recentRows", "Son kayıtlar", "Recent records")
            })
            val marked = entry?.optString("todayMarked").orEmpty()
            views.setViewVisibility(R.id.widget_rows_footer,
                if (marked.isEmpty() || recent.isEmpty()) View.GONE else View.VISIBLE)
            views.setTextViewText(R.id.widget_rows_footer, marked)
            views.setTextColor(R.id.widget_rows_footer, secondary)
            val accent = if (dark) Color.rgb(96, 165, 250) else Color.rgb(37, 99, 235)
            ROWS.forEachIndexed { index, slot ->
                val row = recent.getOrNull(index)
                views.setViewVisibility(slot.root, if (row == null) View.GONE else View.VISIBLE)
                if (row == null) return@forEachIndexed
                views.setTextViewText(slot.text, row.optString("text"))
                views.setTextColor(slot.text, foreground)
                val todayLabel = row.optString("todayLabel").orEmpty()
                if (todayLabel.isNotEmpty()) {
                    val hasColor = row.has("todayColor")
                    val color = if (hasColor) row.optInt("todayColor") else secondary
                    views.setViewVisibility(slot.dot, View.VISIBLE)
                    views.setInt(slot.dot, "setColorFilter", if (hasColor) color else secondary)
                    views.setTextViewText(slot.value, todayLabel)
                    views.setTextColor(slot.value, if (hasColor) color else secondary)
                } else {
                    views.setViewVisibility(slot.dot, View.GONE)
                    // The trailing number belongs to the chosen column or status only.
                    views.setTextViewText(slot.value, metric?.let {
                        row.optJSONObject("values")?.optString(it.optString("id"), "")
                    } ?: "")
                    views.setTextColor(slot.value, accent)
                }
            }
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
