package com.onetouch.football

import android.app.Activity
import android.app.AlertDialog
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class NativeActionSheetBridge(activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "onetouch/action_sheet")
    private var dialog: AlertDialog? = null

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "show") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (dialog != null) {
                result.error("choice_open", null, null)
                return@setMethodCallHandler
            }
            val args = call.arguments as Map<*, *>
            val actions = (args["actions"] as List<*>).map { it as Map<*, *> }
            dialog = showNativeActionSheet(
                nativeControlContext(activity, args["dark"] == true),
                actions.map { it["title"] as String }.toTypedArray(),
            ) { index ->
                dialog = null
                result.success(index?.let { actions[it]["id"] as String })
            }
        }
    }

    fun dispose() {
        dialog?.dismiss()
        channel.setMethodCallHandler(null)
    }
}
