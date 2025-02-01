package com.pii.mts

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
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
}

// Data Model
data class Module(
    @SerializedName("id") val id: Int,
    @SerializedName("inputs") val inputs: List<ModuleInput>,
    @SerializedName("outputs") val outputs: List<ModuleOutput>,
    @SerializedName("analog-inputs") val analogInputs: List<ModuleAnalogInput>,
)

data class ModuleInput(
    @SerializedName("pin") val pin: Int,
    @SerializedName("value") val value: String
)

data class ModuleOutput(
    @SerializedName("pin") val pin: Int,
    @SerializedName("value") var value: String
)

data class ModuleAnalogInput(
    @SerializedName("pin") val pin: Int,
    @SerializedName("value") val value: String
)

data class Settings(
    @SerializedName("setting_name") val settingName: String,
    @SerializedName("setting_value") val settingValue: Int,
)


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
    }
}

@Composable
fun DashboardScreen() {
    val tanksState = remember { mutableStateListOf<Tank>() }
    val modulesState = remember { mutableStateListOf<Module>() } // State for modules
    val settingsState = remember { mutableStateOf<Map<String, Int>?>(null) }
    val coroutineScope = rememberCoroutineScope()

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
                }
            }
            kotlinx.coroutines.delay(5000) // Update every 5 seconds
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

    Scaffold(
        topBar = {
            Text(
                text = "Multi-Tank System",
                modifier = Modifier
                    .statusBarsPadding() // Automatically accounts for system status bar height
                    .padding(start = 16.dp, top = 10.dp, end = 16.dp) // Add horizontal padding
            )
        },
        modifier = Modifier.fillMaxSize()
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item { SettingsSection(settingsState.value, saveSettings) }
            //item { TriggerButtonsSection() }
            // Display Modules Section
            item { ModulesSection(modulesState) }
            // Display Tanks Section
            item { TankInfoSection(tanksState) }
        }
    }
}

// Modules Section
@Composable
fun ModulesSection(modules: List<Module>) {
    if (modules.isEmpty()) {
        Text(
            text = "Loading modules...",
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
    } else {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text("Modules", style = MaterialTheme.typography.titleMedium)
            for (module in modules) {
                ModuleCard(module)
            }
        }
    }
}

// Individual Module Card
@Composable
fun ModuleCard(module: Module) {
    val coroutineScope = rememberCoroutineScope() // Use inside the composable

    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(4.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Module ID: ${module.id}", style = MaterialTheme.typography.titleMedium)

            Text("Inputs:")
            for (input in module.inputs) {
                Text(" - ${input.pin} (V: ${input.value})")
            }

            Text("Analog Inputs:")
            for (analogInput in module.analogInputs) {
                Text(" - ${analogInput.pin} (V: ${analogInput.value})")
            }

            Text("Outputs:")
            for ((index, output) in module.outputs.withIndex()) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("GPIO: ${output.pin}, Value: ${output.value}")
                    Button(onClick = {
                        // Call the API to toggle the output
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val toggleRequest = mapOf(
                                    "index" to index,
                                    "value" to if (output.value == "0") 1 else 0 // Toggle logic
                                )
                                ApiClient.api.toggleModuleOutput(module.id, toggleRequest)

                                if (output.value == "0") {
                                    output.value = "1"
                                } else {
                                    output.value = "0"
                                }
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }
                    })
                    {
                        Text("Toggle")
                    }
                }
            }


        }
    }
}


// Settings Section
@Composable
fun SettingsSection(settings: Map<String, Int>?, onSave: (Map<String, Int>) -> Unit) {
    // State for local edits
    val editableSettings = remember { mutableStateMapOf<String, Int>() }

    // Initialize editable settings when data is fetched
    LaunchedEffect(settings) {
        if (settings != null) {
            editableSettings.clear()
            editableSettings.putAll(settings)
        }
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(4.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Settings", style = MaterialTheme.typography.titleMedium)

            if (settings == null) {
                Text("Loading settings...")
            } else {
                Column {
                    editableSettings.forEach { (key, value) ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 8.dp),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(key, modifier = Modifier.weight(2f))
                            when (value) {
                                is Int -> {
                                    TextField(
                                        value = editableSettings[key].toString(),
                                        onValueChange = { newValue ->
                                            newValue.toIntOrNull()?.let { editableSettings[key] = it }
                                        },
                                        modifier = Modifier.weight(1f)
                                    )
                                }
                                else -> {
                                    Text("Unsupported type", modifier = Modifier.weight(1f))
                                }
                            }
                        }
                    }
                    Button(
                        onClick = { onSave(editableSettings) },
                        modifier = Modifier
                            .padding(top = 16.dp)
                            .align(Alignment.End)
                    ) {
                        Text("Save Changes")
                    }
                }
            }
        }
    }
}


// Trigger Buttons Section
@Composable
fun TriggerButtonsSection() {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(4.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text("Triggers", style = MaterialTheme.typography.titleMedium)
            Button(onClick = { /* Trigger 1 */ }) {
                Text("Trigger 1")
            }
            Button(onClick = { /* Trigger 2 */ }) {
                Text("Trigger 2")
            }
            Button(onClick = { /* Trigger 3 */ }) {
                Text("Trigger 3")
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
