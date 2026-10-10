package com.muratstudio.tablenote

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.muratstudio.tablenote/home_widget").setMethodCallHandler { call, result ->
            if (call.method != "publish") {
                result.notImplemented()
            } else {
                val snapshot = call.arguments as? String
                if (snapshot == null) result.error("invalid_snapshot", "Expected JSON", null)
                else try {
                    val data = org.json.JSONObject(snapshot)
                    require(data.optInt("version") == 1 && data.has("entries"))
                    val saved = TableNoteWidgetStore.preferences(this).edit()
                        .putString("snapshot", snapshot).commit()
                    if (!saved) result.error("widget_storage", "Could not persist snapshot", null)
                    else {
                        TableNoteWidgetProvider.updateAll(this)
                        result.success(null)
                    }
                } catch (_: Exception) {
                    result.error("widget_storage", "Could not update widget", null)
                }
            }
        }
    }
}
