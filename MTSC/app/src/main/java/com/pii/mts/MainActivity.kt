package com.pii.mts

import Module
import ModulesSection
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
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Body

import android.view.WindowManager;
import androidx.compose.ui.platform.LocalContext
import kotlin.time.Duration.Companion.milliseconds

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
    val tanksState = remember { mutableStateListOf<Tank>() }
    val modulesState = remember { mutableStateListOf<Module>() } // State for modules
    val settingsState = remember { mutableStateOf<Map<String, Int>?>(null) }
    val coroutineScope = rememberCoroutineScope()

    val context = LocalContext.current
    val refreshRate by SettingsRepository.getRefreshRateFlow(context).collectAsState(initial = 5000.milliseconds)


    // Poll modules data every few seconds
    LaunchedEffect(Unit) {
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

            kotlinx.coroutines.delay(refreshRate) // Update every 5 seconds
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

    val tabTitles = listOf("Modules", "Tanks", "Settings")

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Multi-Tank System") },
                modifier = Modifier.statusBarsPadding()
            )
        },
        modifier = Modifier.fillMaxSize()
    ) { innerPadding ->

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // Tabs
            TabRow(selectedTabIndex = selectedTabIndex) {
                tabTitles.forEachIndexed { index, title ->
                    Tab(
                        selected = selectedTabIndex == index,
                        onClick = { selectedTabIndex = index },
                        text = { Text(title) }
                    )
                }
            }

            // Tab Content
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
            ) {
                when (selectedTabIndex) {
                    0 -> ModulesSection(modulesState)
                    1 -> TankInfoSection(tanksState)
                    2 -> SettingsSection(settingsState.value, saveSettings)
                }
            }
        }
    }
}


// Tank Info Section
@Composable
fun TankInfoSection(tanks: List<Tank>) {
    if (tanks.isEmpty()) {
        Text(
            text = "Loading tanks...",
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
    } else {
        for (tank in tanks) {
            TankCard(tank)
        }
    }
}

// Individual Tank Card
@Composable
fun TankCard(tank: Tank) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(4.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Tank: ${tank.name}", style = MaterialTheme.typography.titleMedium)
            Text("Threshold: ${tank.threshold}L")
            Text("Volume: ${tank.volume}L")
            Text("Current Level: ${tank.currentLevel}L")

            LinearProgressIndicator(
                progress = tank.currentLevel / tank.volume,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
            )
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
