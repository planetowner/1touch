package com.onetouch.football

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.util.TypedValue
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.MenuItem
import android.view.View
import android.widget.ImageView
import android.widget.Toolbar
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

// Flutter의 구형 호스트 테마 대신 OS에 포함된 Material 기본 컨트롤을 사용해요.
private fun avatarControlContext(context: Context, options: Map<*, *>): Context {
    val dark = options["dark"] == true
    val configuration = Configuration(context.resources.configuration).apply {
        uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
            if (dark) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
    }
    return ContextThemeWrapper(context.createConfigurationContext(configuration),
        if (dark) android.R.style.Theme_Material_NoActionBar else android.R.style.Theme_Material_Light_NoActionBar)
}

class AvatarPickerHeaderFactory(private val messenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        AvatarPickerHeader(avatarControlContext(context, args as Map<*, *>), viewId, args, messenger)
}

private class AvatarPickerHeader(context: Context, id: Int, options: Map<*, *>, messenger: BinaryMessenger) : PlatformView {
    private val toolbar = object : Toolbar(context) {
        override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
            super.onLayout(changed, l, t, r, b)
            // 바의 크기가 같아도 내부 버튼 배치가 바뀌면 다시 측정해요.
            reportLayout()
        }
    }
    private val titleAnchor = View(context)
    private val done = toolbar.menu.add(options["done"] as String)
    private val channel = MethodChannel(messenger, "onetouch/avatar_header/$id")
    private val height = TypedValue().also {
        context.theme.resolveAttribute(android.R.attr.actionBarSize, it, true)
    }.getDimension(context.resources.displayMetrics) / context.resources.displayMetrics.density

    init {
        // 제목 렌더링은 Flutter에 두고, 세로 위치만 네이티브 툴바에서 받아요.
        toolbar.addView(titleAnchor, Toolbar.LayoutParams(1, 1, Gravity.CENTER))
        toolbar.setNavigationIcon(android.R.drawable.ic_menu_close_clear_cancel)
        // 시스템 아이콘 원본은 흰색이라 OS 테마의 기본 아이콘 색을 적용해요.
        val colors = context.obtainStyledAttributes(intArrayOf(android.R.attr.colorControlNormal))
        toolbar.navigationIcon?.mutate()?.setTintList(colors.getColorStateList(0))
        colors.recycle()
        // Android에는 iOS의 시스템 완료 아이템이 없어 기본 텍스트 액션을 사용해요.
        done.setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
        done.setOnMenuItemClickListener { channel.invokeMethod("done", null); true }
        update(options)
        channel.setMethodCallHandler { call, result ->
            if (call.method == "update") {
                update(call.arguments as Map<*, *>)
                result.success(null)
            } else result.notImplemented()
        }
    }

    override fun getView(): View = toolbar
    override fun dispose() { channel.setMethodCallHandler(null) }

    private fun update(options: Map<*, *>) {
        toolbar.setBackgroundColor((options["background"] as Number).toInt())
        toolbar.navigationContentDescription = options["cancel"] as String
        toolbar.setNavigationOnClickListener {
            if (options["cancelEnabled"] == true) channel.invokeMethod("cancel", null)
        }
        done.title = options["done"] as String
        done.isEnabled = options["doneEnabled"] == true
        toolbar.requestLayout()
    }

    private fun reportLayout() {
        val density = toolbar.resources.displayMetrics.density
        channel.invokeMethod("layout", mapOf(
            "height" to height.toDouble(),
            "titleCenterY" to ((titleAnchor.y + titleAnchor.height / 2f) / density).toDouble(),
            "closeIconLeft" to (closeIconLeft() / density).toDouble()))
    }

    private fun closeIconLeft(): Float {
        val button = (0 until toolbar.childCount)
            .map { toolbar.getChildAt(it) }
            .filterIsInstance<ImageView>()
            .first { it.drawable === toolbar.navigationIcon }
        // 터치 영역과 아이콘의 투명 여백을 빼고, 실제 X 픽셀의 끝에 맞춰요.
        // ImageView와 같은 배치로 아이콘만 그려 눌렀을 때의 배경은 측정에서 제외해요.
        val bitmap = Bitmap.createBitmap(button.width, button.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.translate(button.paddingLeft.toFloat(), button.paddingTop.toFloat())
        canvas.concat(button.imageMatrix)
        button.drawable.draw(canvas)
        val pixels = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        val left = (0 until bitmap.width).first { x ->
            (0 until bitmap.height).any { y -> (pixels[y * bitmap.width + x] ushr 24) != 0 }
        }
        bitmap.recycle()
        return button.x + left
    }
}
