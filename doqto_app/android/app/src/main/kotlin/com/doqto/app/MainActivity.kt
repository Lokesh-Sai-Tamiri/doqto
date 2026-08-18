package com.doqto.app

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // H4: block screenshots and task-switcher previews — PHI on screen.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
