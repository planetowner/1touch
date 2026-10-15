package com.onetouch.football

import android.app.AlertDialog
import android.content.Context
import android.content.res.Configuration
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.WindowManager

// Flutter의 구형 호스트 테마 대신 OS의 Material 기본 컨트롤을 사용해요.
internal fun nativeControlContext(context: Context, dark: Boolean): Context {
    val configuration = Configuration(context.resources.configuration).apply {
        uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
            if (dark) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
    }
    // 원래 Context를 유지해야 다이얼로그가 Activity의 윈도우에 연결돼요.
    return ContextThemeWrapper(context,
        if (dark) android.R.style.Theme_Material_NoActionBar else android.R.style.Theme_Material_Light_NoActionBar
    ).apply { applyOverrideConfiguration(configuration) }
}

internal fun showNativeActionSheet(
    context: Context,
    labels: Array<String>,
    onChoice: (Int?) -> Unit,
): AlertDialog {
    var selected: Int? = null
    val dialog = AlertDialog.Builder(context)
        .setItems(labels) { _, index -> selected = index }
        .create()
    // 선택과 바깥 터치·뒤로 가기 모두 닫힌 뒤 한 번만 결과를 전달해요.
    dialog.setOnDismissListener { onChoice(selected) }
    dialog.show()
    dialog.window?.apply {
        setGravity(Gravity.BOTTOM)
        setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.WRAP_CONTENT)
    }
    return dialog
}
