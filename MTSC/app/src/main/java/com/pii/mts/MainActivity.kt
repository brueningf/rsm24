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


import android.view.WindowManager;
import androidx.compose.animation.core.EaseInOutCubic
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontWeight
import ir.ehsannarmani.compose_charts.LineChart
import ir.ehsannarmani.compose_charts.models.AnimationMode
import ir.ehsannarmani.compose_charts.models.DrawStyle
import ir.ehsannarmani.compose_charts.models.HorizontalIndicatorProperties
import ir.ehsannarmani.compose_charts.models.LabelHelperProperties
import ir.ehsannarmani.compose_charts.models.Line

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
    @SerializedName("weather") val weather: WeatherObject,
    @SerializedName("online") var online: Boolean,
    @SerializedName("last-seen") val lastSeen: String
)

data class ModuleInput(
    @SerializedName("pin") val pin: Int,
    @SerializedName("value") val value: String
)

data class ModuleOutput(
    @SerializedName("pin") val pin: Int,
    @SerializedName("value") var value: String,
    @SerializedName("manual") val manual: Boolean,
)

data class ModuleAnalogInput(
    @SerializedName("pin") val pin: Int,
    @SerializedName("value") val value: String
)

data class WeatherObject(
    @SerializedName("temperature") val temperature: String,
    @SerializedName("humidity") val humidity: String,
    @SerializedName("pressure") val pressure: String,
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

// Modules Section
@Composable
fun ModulesSection(modules: List<Module>) {

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()), // Enables scrolling
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        if (modules.isEmpty()) {
            Text(
                text = "Loading modules...",
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
            )
        } else {
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
        modifier = Modifier
            .fillMaxSize()
            .fillMaxHeight(),
        elevation = CardDefaults.cardElevation(4.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(modifier = Modifier.fillMaxSize(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Module ID: ${module.id}", style = MaterialTheme.typography.titleMedium, color = Color.Black)

                // Circle indicator for on/off state
                Box(
                    modifier = Modifier
                        .size(16.dp)
                        .clip(CircleShape)
                        .background(if (module.online) Color.Green else Color.Gray) // Green if ON, Gray if OFF
                )
            }
            Column {
                Text(
                    text = "Temperature: ${module.weather.temperature}°C",
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    text = "Humidity: ${module.weather.humidity}%",
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    text = "Pressure: ${module.weather.pressure} hPa",
                    style = MaterialTheme.typography.titleMedium
                )
            }

            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(2.dp) // Space between inputs
            ) {
                Text("Inputs:")
                for ((index, input) in module.inputs.withIndex()) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 5.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically


                    ) {
                        Text("${index + 1} | ${input.pin} (V: ${input.value})")

                        // Circle indicator for on/off state
                        Box(
                            modifier = Modifier
                                .size(16.dp)
                                .clip(CircleShape)
                                .background(if (input.value == "1") Color.Green else Color.Gray) // Green if ON, Gray if OFF
                        )
                    }
                }
            }

            // ADCs
            Column(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(2.dp) // Space between inputs
            ) {
                Text("Analog Inputs:")
                for (analogInput in module.analogInputs) {
                    AnalogInputGraph(analogInput)
                }
            }

            // Outputs
            Column(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(2.dp) // Space between inputs
            ) {
                Text("Outputs:")
                for ((index, output) in module.outputs.withIndex()) {
                    OutputToggle(output, index, module)
                }
            }
        }
    }
}

@Composable
fun OutputToggle(output: ModuleOutput, index: Int, module: Module) {
    var active by remember { mutableStateOf(output.value == "1") }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 5.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("${index + 1} | GPIO: ${output.pin} | Val: ${output.value}")

        if (output.manual) {
            Box(
                modifier = Modifier.border(width = 1.dp, color = Color.Red)
            ) {
                Text(text = "F", fontWeight = FontWeight.Bold, color = Color.Red, modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp))
            }
        }

        Button(
            onClick = {
                active = !active // Toggle state to trigger recomposition

                // Call the API to toggle the output
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        val toggleRequest = mapOf(
                            "index" to index,
                            "value" to if (active) 1 else 0 // Toggle logic
                        )

                        // Update state to reflect the API request
                        output.value = if (active) "1" else "0"

                        ApiClient.api.toggleModuleOutput(module.id, toggleRequest)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            },
            colors = ButtonDefaults.buttonColors(
                containerColor = if (active) Color.Green else Color.Red, // Change color based on state
                contentColor = Color.White // Text color
            ),
            modifier = Modifier.widthIn(min = 100.dp) // Set minimum width
        )
        {
            Text(if (active) "ON" else "OFF")
        }
    }
}

@Composable
fun AnalogInputGraph(analogInput: ModuleAnalogInput) {
    val values = remember { mutableStateListOf<Double>() }

    // Append values without recomposition
    LaunchedEffect(analogInput.value.toDouble()) {
        values.add(analogInput.value.toDouble())
        if (values.size > 10) values.removeAt(0)
    }

    // Use a mutable state for Line to avoid re-creating the list
    val line = remember {
        mutableStateOf(
            Line(
                label = "V",
                values = values.toList(),
                color = SolidColor(Color(0xFF23af92)),
                firstGradientFillColor = Color(0xFF2BC0A1).copy(alpha = .5f),
                secondGradientFillColor = Color.Transparent,
                strokeAnimationSpec = tween(1000, easing = EaseInOutCubic),
                gradientAnimationDelay = 500,
                drawStyle = DrawStyle.Stroke(width = 2.dp),
            )
        )
    }

    // Update only the list, not the entire line object
    LaunchedEffect(values.toList()) {
        line.value = line.value.copy(values = values.toList())
    }

    Text("GPIO: ${analogInput.pin} | V: ${analogInput.value}")

    LineChart(
        modifier = Modifier
            .fillMaxWidth()
            .height(120.dp)
            .padding(bottom = 16.dp),
        data = listOf(line.value), // Use the mutable state line object
        animationMode = AnimationMode.OneByOne, // Smooth sequential animation
        labelHelperProperties = LabelHelperProperties(false)
    )
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
                                            newValue.toIntOrNull()
                                                ?.let { editableSettings[key] = it }
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
