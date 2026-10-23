package com.naturego.app

import android.app.Application
import com.yandex.mapkit.MapKitFactory

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        if (BuildConfig.YANDEX_MAPKIT_API_KEY.isNotEmpty()) {
            MapKitFactory.setApiKey(BuildConfig.YANDEX_MAPKIT_API_KEY)
        }
    }
}
