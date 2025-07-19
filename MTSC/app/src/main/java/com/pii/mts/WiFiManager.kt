package com.pii.mts

import android.content.Context
import android.content.Intent
import android.net.*
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.livedata.observeAsState
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewmodel.compose.viewModel


import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiConfiguration
import android.provider.Settings
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.rememberCoroutineScope
import androidx.lifecycle.ViewModelProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class WiFiManager(private val context: Context) : ViewModel() {
    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val wifiManager =
        context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

    private val _isConnected = MutableLiveData(false)
    val isConnected: LiveData<Boolean> = _isConnected

    private val manufacturer: String = Build.MANUFACTURER
    private var currentNetwork: Network? = null
    private var targetSsid: String? = null

    fun checkWiFiConnection(ssid: String) {
        targetSsid = ssid
        if (manufacturer.equals("HUAWEI", ignoreCase = true)) {
            _isConnected.postValue(true)
            return;
        }
        if (currentNetwork == null) {
            _isConnected.postValue(false)
            return;
        }
        val activeNetwork = connectivityManager.activeNetwork
        val networkCapabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
        val currentSsid = wifiManager.connectionInfo?.ssid?.replace("\"", "") ?: ""

        _isConnected.postValue(networkCapabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true && currentSsid == targetSsid)
    }

    fun connectToWiFi(ssid: String, password: String) {
        targetSsid = ssid

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !manufacturer.equals("HUAWEI", ignoreCase = true)) {
            val specifier = WifiNetworkSpecifier.Builder()
                .setSsid(ssid)
                .setWpa2Passphrase(password)
                .build()

            val networkRequest = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .setNetworkSpecifier(specifier)
                .build()

            connectivityManager.requestNetwork(networkRequest, object :
                ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    super.onAvailable(network)
                    currentNetwork = network;
                    connectivityManager.bindProcessToNetwork(network)
                    _isConnected.postValue(true)
                }

                override fun onUnavailable() {
                    super.onUnavailable()
                    currentNetwork = null;
                    _isConnected.postValue(false)
                }

                override fun onLost(network: Network) {
                    super.onLost(network)
                    if (currentNetwork == network) {
                        currentNetwork = null;
                        connectivityManager.bindProcessToNetwork(null)
                        _isConnected.postValue(false)
                    }

                }
            })
        }
        else if (manufacturer.equals("HUAWEI", ignoreCase = true)) {
            val wifiIntent = Intent(Settings.ACTION_WIFI_SETTINGS)
            context.startActivity(wifiIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
        else {
            println("ATTEMPT CONNECT TO WIFI")
            // For API levels below Q, use WifiConfiguration
            val wifiConfig = WifiConfiguration().apply {
                this.SSID = "\"$ssid\""
                this.preSharedKey = "\"$password\""
            }

            val netId = wifiManager.addNetwork(wifiConfig)
            if (netId != -1) {
                wifiManager.disconnect()
                wifiManager.enableNetwork(netId, true)
                wifiManager.reconnect()
                _isConnected.postValue(true) // Assumes connection success. Add better checking.
            } else {
                _isConnected.postValue(false)
            }
        }
    }

    // Public method to set connection state (for when device is reachable on current network)
    fun setConnected(connected: Boolean) {
        _isConnected.postValue(connected)
    }
}

class WiFiManagerHelperFactory(private val context: Context) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(WiFiManager::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return WiFiManager(context) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}


@Composable
fun WiFiConnectButton(ssid: String, password: String, wifiHelper: WiFiManager) {
    val scope = rememberCoroutineScope()
    val isConnected by wifiHelper.isConnected.observeAsState(initial = false)

    val coroutineScope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        wifiHelper.checkWiFiConnection(ssid)
    }

    // Only show the button when not connected
    if (!isConnected) {
        IconButton(
            onClick = {
                scope.launch(Dispatchers.IO) {
                    wifiHelper.connectToWiFi(ssid, password)
                    withContext(Dispatchers.Main) {
                        wifiHelper.checkWiFiConnection(ssid)
                    }
                }
            },
            modifier = Modifier.size(48.dp)
        ) {
            Icon(
                imageVector = Icons.Outlined.Warning,
                contentDescription = "WiFi Connection",
                tint = Color.Red
            )
        }
    }
}