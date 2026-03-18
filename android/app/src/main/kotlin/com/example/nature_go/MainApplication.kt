package com.example.nature_go
import android.app.Application
import com.yandex.mapkit.MapKitFactory

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        MapKitFactory.setApiKey("06f03346-42b9-46b5-af30-46b8f6ebdfb5")
    }
}