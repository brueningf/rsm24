package com.pii.mts

import Module
import ModulesSection
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.google.gson.annotations.SerializedName
import com.pii.mts.ui.theme.MTSCTheme
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Body

import android.view.WindowManager;
import androidx.annotation.RequiresApi
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.runtime.livedata.observeAsState
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlin.time.Duration.Companion.milliseconds
import java.net.InetSocketAddress
import java.net.Socket
import java.net.SocketTimeoutException


// Network reachability check function
suspend fun isDeviceReachable(host: String, port: Int = 80, timeout: Int = 3000): Boolean {
    return try {
        withContext(Dispatchers.IO) {
            val socket = Socket()
            socket.connect(InetSocketAddress(host, port), timeout)
            socket.close()
            true
        }
    } catch (e: Exception) {
        false
    }
}

// Retrofit API Interface
interface ApiService {
    @GET("/api/modules")
    suspend fun fetchModules(): List<Module>

    @POST("/api/rmt/{moduleId}")
    suspend fun toggleModuleOutput(
        @Path("moduleId") moduleId: Int,
        @Body request: Map<String, Int>
    )

    @GET("/api/settings")
    suspend fun fetchSettings(): Map<String, Int>

    @POST("/api/settings")
    suspend fun updateSettings(@Body updatedSettings: Map<String, Int>)

    @GET("tanks")
    suspend fun fetchTanks(): List<Tank>

    @GET("/api/interrupt")
    suspend fun callInterrupt()
}

// Data Model

data class Tank(
    @SerializedName("id") val id: Int,
    @SerializedName("name") val name: String,
    @SerializedName("threshold") val threshold: Float,
    @SerializedName("volume") val volume: Float,
    @SerializedName("currentLevel") val currentLevel: Float
)

@RequiresApi(Build.VERSION_CODES.Q)
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MTSCTheme {
                DashboardScreen()
            }
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen() {
    val context = LocalContext.current
    val tanksState = remember { mutableStateListOf<Tank>() }
    val modulesState = remember { mutableStateListOf<Module>() } // State for modules
    val settingsState = remember { mutableStateOf<Map<String, Int>?>(null) }
    val deviceReachableState = remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()

    val wifiHelper: WiFiManager = viewModel(factory = WiFiManagerHelperFactory(context))
    val isConnected by wifiHelper.isConnected.observeAsState(initial = false)
    val ssid = "mywifi"
    val password = "12345678"

    val refreshRate by SettingsRepository.getRefreshRateFlow(context)
        .collectAsState(initial = 5000.milliseconds)

    WiFiPermissionCheck(
        onPermissionsGranted = {
            // All permissions granted, proceed with Wi-Fi operations
            println("Permissions Granted")
        },
        onPermissionsDenied = {
            // Permissions denied, handle accordingly
            println("Permissions Denied")
        }
    )

    // Poll modules data every few seconds
    LaunchedEffect(Unit) {
        while (true) {
            // First check if the device is already reachable on current network
            val deviceReachable = isDeviceReachable("200.200.200.1")
            deviceReachableState.value = deviceReachable
            
            if (deviceReachable) {
                // Device is reachable, mark as connected and start data polling
                wifiHelper.setConnected(true)
                
                coroutineScope.launch(Dispatchers.IO) {
                    try {
                        val settings = ApiClient.api.fetchSettings()
                        settingsState.value = settings
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }

                while (true) {
                    coroutineScope.launch(Dispatchers.IO) {
                        try {
                            val modules = ApiClient.api.fetchModules()
                            modulesState.clear()
                            modulesState.addAll(modules)
                        } catch (e: Exception) {
                            e.printStackTrace() // Handle exceptions (e.g., network issues)
                            modulesState.forEach { module ->
                                module.online = false
                            }
                        }
                    }

                    kotlinx.coroutines.delay(refreshRate)
                }
            } else if (isConnected) {
                // Already connected to WiFi but device not reachable, continue polling
                coroutineScope.launch(Dispatchers.IO) {
                    try {
                        val settings = ApiClient.api.fetchSettings()
                        settingsState.value = settings
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }

                while (true) {
                    coroutineScope.launch(Dispatchers.IO) {
                        try {
                            val modules = ApiClient.api.fetchModules()
                            modulesState.clear()
                            modulesState.addAll(modules)
                        } catch (e: Exception) {
                            e.printStackTrace() // Handle exceptions (e.g., network issues)
                            modulesState.forEach { module ->
                                module.online = false
                            }
                        }
                    }

                    kotlinx.coroutines.delay(refreshRate)
                }
            } else {
                // Device not reachable and not connected to WiFi, attempt WiFi connection
                wifiHelper.connectToWiFi(ssid, password)
            }

            kotlinx.coroutines.delay(5000)
        }
    }


    // Save Updated Settings
    val saveSettings: (Map<String, Int>) -> Unit = { updatedSettings ->
        coroutineScope.launch(Dispatchers.IO) {
            try {
                ApiClient.api.updateSettings(updatedSettings)
                // Re-fetch settings after saving to refresh the UI
                val settings = ApiClient.api.fetchSettings()
                settingsState.value = settings
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    var selectedTabIndex by remember { mutableStateOf(0) }

    val tabTitles = listOf("Tanks", "Modules", "System")

    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    if (selectedTabIndex == 3) {
                        Text("Settings")
                    } else {
                        Text("Multi-Tank System")
                    }
                },
                modifier = Modifier.statusBarsPadding(),
                navigationIcon = {
                    if (selectedTabIndex == 3) {
                        IconButton(onClick = {
                            selectedTabIndex = 0 // Go back to Tanks (default view)
                        }) {
                            Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                        }
                    }
                },
                actions = {
                    if (selectedTabIndex != 3) {
                        IconButton(onClick = {
                            selectedTabIndex = 3
                        }) {
                            Icon(Icons.Filled.Settings, contentDescription = "Settings")
                        }
                    }

                    WiFiConnectButton(ssid, password, wifiHelper)
                }
            )
        },
        modifier = Modifier.fillMaxSize()
    ) { innerPadding ->

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // Tabs - only show for main content (Tanks, Modules, and System)
            if (selectedTabIndex < 3) {
                TabRow(selectedTabIndex = selectedTabIndex) {
                    tabTitles.forEachIndexed { index, title ->
                        Tab(
                            selected = selectedTabIndex == index,
                            onClick = { selectedTabIndex = index },
                            text = { Text(title) }
                        )
                    }
                }
            }

            // Tab Content
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .weight(1f)
                    .padding(
                        start = if (selectedTabIndex == 3) 8.dp else 16.dp,
                        end = if (selectedTabIndex == 3) 8.dp else 16.dp,
                        top = if (selectedTabIndex == 3) 8.dp else 16.dp,
                        bottom = if (selectedTabIndex == 3) 8.dp else 16.dp
                    ),
            ) {
                when (selectedTabIndex) {
                    0 -> TanksSection(modulesState, settingsState.value)
                    1 -> ModulesSection(modulesState)
                    2 -> SystemStatusSection(modulesState, isConnected, deviceReachableState.value, refreshRate)
                    3 -> SettingsSection(settingsState.value, saveSettings)
                }
            }
        }
    }
}

// Retrofit Client
object ApiClient {
    private val retrofit = Retrofit.Builder()
        .baseUrl("http://200.200.200.1/") // Replace with your API base URL
        .addConverterFactory(GsonConverterFactory.create())
        .build()

    val api: ApiService = retrofit.create(ApiService::class.java)
}

// Preview Section
@Preview(showBackground = true)
@Composable
fun DashboardPreview() {
    MTSCTheme {
        DashboardScreen()
    }
}
