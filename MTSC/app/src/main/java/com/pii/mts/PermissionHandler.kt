package com.pii.mts

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import android.content.pm.PackageManager
import androidx.compose.runtime.DisposableEffect

@Composable
fun WiFiPermissionCheck(
    onPermissionsGranted: () -> Unit,
    onPermissionsDenied: () -> Unit
) {
    val context = LocalContext.current
    var writeSettingsPermission by remember { mutableStateOf(false) }
    var fineLocationPermission by remember { mutableStateOf(false) }
    var changeWifiStatePermission by remember { mutableStateOf(false) }
    var changeNetworkStatePermission by remember { mutableStateOf(false) }

    val writeSettingsLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) {
        writeSettingsPermission = Settings.System.canWrite(context)
        checkAllPermissions(
            fineLocationPermission,
            changeWifiStatePermission,
            changeNetworkStatePermission,
            onPermissionsGranted,
            onPermissionsDenied
        )
    }

    val fineLocationLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted ->
        fineLocationPermission = isGranted
        checkAllPermissions(
            fineLocationPermission,
            changeWifiStatePermission,
            changeNetworkStatePermission,
            onPermissionsGranted,
            onPermissionsDenied
        )
    }

    LaunchedEffect(Unit) {
        changeWifiStatePermission = ContextCompat.checkSelfPermission(context, Manifest.permission.CHANGE_WIFI_STATE) == PackageManager.PERMISSION_GRANTED
        changeNetworkStatePermission = ContextCompat.checkSelfPermission(context, Manifest.permission.CHANGE_NETWORK_STATE) == PackageManager.PERMISSION_GRANTED

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            fineLocationLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
        } else {
            fineLocationPermission = true
        }

        checkAllPermissions(
            fineLocationPermission,
            changeWifiStatePermission,
            changeNetworkStatePermission,
            onPermissionsGranted,
            onPermissionsDenied
        )
    }

    DisposableEffect(Unit){
        onDispose {
        }
    }
}

private fun checkAllPermissions(
    fineLocationPermission: Boolean,
    changeWifiStatePermission: Boolean,
    changeNetworkStatePermission: Boolean,
    onPermissionsGranted: () -> Unit,
    onPermissionsDenied: () -> Unit
) {
    if (fineLocationPermission && changeWifiStatePermission && changeNetworkStatePermission) {
        onPermissionsGranted()
    } else {
        onPermissionsDenied()
    }
}