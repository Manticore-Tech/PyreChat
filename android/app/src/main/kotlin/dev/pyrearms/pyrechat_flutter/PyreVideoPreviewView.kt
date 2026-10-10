package dev.pyrearms.pyrechat_flutter

import android.content.Context
import android.graphics.Color
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.ProgressBar
import android.widget.VideoView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class PyreVideoPreviewFactory :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(
        context: Context,
        viewId: Int,
        args: Any?,
    ): PlatformView {
        val params = args as? Map<*, *>
        val path = params?.get("path") as? String ?: ""
        return PyreVideoPreviewView(context, path)
    }
}

private class PyreVideoPreviewView(
    context: Context,
    path: String,
) : PlatformView {
    private val root = FrameLayout(context)
    private val video = VideoView(context)
    private val progress = ProgressBar(context)
    private var prepared = false

    init {
        root.setBackgroundColor(Color.BLACK)

        root.addView(
            video,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER,
            ),
        )
        root.addView(
            progress,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ),
        )

        if (path.isBlank()) {
            progress.visibility = View.GONE
        } else {
            video.setVideoPath(path)
            video.setOnPreparedListener { player ->
                prepared = true
                progress.visibility = View.GONE
                player.isLooping = true
                video.start()
            }
            video.setOnErrorListener { _, _, _ ->
                prepared = false
                progress.visibility = View.GONE
                true
            }
            video.setOnClickListener {
                if (!prepared) return@setOnClickListener
                if (video.isPlaying) {
                    video.pause()
                } else {
                    video.start()
                }
            }
        }
    }

    override fun getView(): View = root

    override fun dispose() {
        prepared = false
        video.stopPlayback()
    }
}
