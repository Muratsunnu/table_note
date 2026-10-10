package com.muratstudio.tablenote

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.*

class TableNoteWidgetConfigureActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) { finish(); return }
        val snapshot = TableNoteWidgetStore.snapshot(this)
        val entries = TableNoteWidgetStore.entries(snapshot)
        val prefs = TableNoteWidgetStore.preferences(this)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val padding = (24 * resources.displayMetrics.density).toInt()
            setPadding(padding, padding, padding, padding)
            fitsSystemWindows = true
        }
        setContentView(ScrollView(this).apply { fitsSystemWindows = true; addView(root) })
        fun label(text: String, size: Float = 16f) {
            root.addView(TextView(this).apply { this.text = text; textSize = size; setPadding(0, 16, 0, 16) })
        }
        label("Table Note", 26f)
        if (entries.isEmpty()) {
            label(TableNoteWidgetStore.text(snapshot, "empty", "Önce uygulamada bir tablo oluştur.", "Create a table in the app first."))
            root.addView(Button(this).apply {
                text = TableNoteWidgetStore.text(snapshot, "open", "Uygulamayı aç", "Open app")
                setOnClickListener { startActivity(Intent(this@TableNoteWidgetConfigureActivity, MainActivity::class.java)); finish() }
            })
            return
        }
        label(TableNoteWidgetStore.text(snapshot, "choose", "Tablo veya çetele seç", "Choose a table or tally"))
        val tableSpinner = Spinner(this)
        tableSpinner.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item,
            entries.map { "${it.optString("typeText")} · ${it.optString("name")}" })
        root.addView(tableSpinner)
        label(TableNoteWidgetStore.text(snapshot, "total", "Toplam", "Total"))
        val metricSpinner = Spinner(this)
        root.addView(metricSpinner)
        var metricIds = listOf("")
        val selectedEntry = prefs.getString("entry_$id", null)
        tableSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onNothingSelected(parent: AdapterView<*>?) {}
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, rowId: Long) {
                val entry = entries[position]
                val metrics = TableNoteWidgetStore.metrics(entry)
                metricIds = listOf("") + metrics.map { it.optString("id") }
                val names = listOf(TableNoteWidgetStore.text(snapshot, "countOnly", "Yalnızca kayıt sayısı", "Record count only")) + metrics.map { it.optString("label") }
                metricSpinner.adapter = ArrayAdapter(this@TableNoteWidgetConfigureActivity,
                    android.R.layout.simple_spinner_dropdown_item, names)
                if (entry.optString("id") == selectedEntry) {
                    metricSpinner.setSelection(metricIds.indexOf(prefs.getString("metric_$id", "")).coerceAtLeast(0))
                }
            }
        }
        tableSpinner.setSelection(entries.indexOfFirst { it.optString("id") == selectedEntry }.coerceAtLeast(0))
        root.addView(Button(this).apply {
            text = TableNoteWidgetStore.text(snapshot, "save", "Kaydet", "Save")
            setOnClickListener {
                val entry = entries[tableSpinner.selectedItemPosition]
                val metric = metricIds.getOrElse(metricSpinner.selectedItemPosition) { "" }
                if (!prefs.edit().putString("entry_$id", entry.optString("id"))
                    .putString("metric_$id", metric).commit()) return@setOnClickListener
                TableNoteWidgetProvider.update(this@TableNoteWidgetConfigureActivity, AppWidgetManager.getInstance(this@TableNoteWidgetConfigureActivity), id)
                setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id))
                finish()
            }
        })
    }
}
