import androidx.compose.animation.core.EaseInOutCubic
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ExitToApp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.google.gson.annotations.SerializedName
import com.pii.mts.ApiClient
import ir.ehsannarmani.compose_charts.LineChart
import ir.ehsannarmani.compose_charts.models.AnimationMode
import ir.ehsannarmani.compose_charts.models.DrawStyle
import ir.ehsannarmani.compose_charts.models.LabelHelperProperties
import ir.ehsannarmani.compose_charts.models.Line
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

data class Module(
    @SerializedName("id") val id: Int,
    @SerializedName("inputs") val inputs: List<ModuleInput>,
    @SerializedName("outputs") val outputs: List<ModuleOutput>,
    @SerializedName("analog-inputs") val analogInputs: List<ModuleAnalogInput>,
    @SerializedName("pulse-counters") val pulseCounters: List<ModulePulseCounter>?,
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
    @SerializedName("value") var _value: Int,
    @SerializedName("manual") val manual: Boolean,
) {
    var value: Boolean
        // Convert Int to Boolean
        get() = _value != 0
        set(newValue) {
            _value = if (newValue) 1 else 0
        }
}

data class ModuleAnalogInput(
    @SerializedName("pin") val pin: Int,
    @SerializedName("value") val value: String
)

data class ModulePulseCounter(
    @SerializedName("pin") val pin: Int,
    @SerializedName("value") val value: Int,
    @SerializedName("open") val isOpen: Boolean
)

data class WeatherObject(
    @SerializedName("temperature") val temperature: String,
    @SerializedName("humidity") val humidity: String,
    @SerializedName("pressure") val pressure: String,
)

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
            Row(
                modifier = Modifier.fillMaxSize(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                    Text(
                        "Module ID: ${module.id}",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = Color.LightGray,
                    )

                    Row(modifier = Modifier.fillMaxHeight(), verticalAlignment = Alignment.CenterVertically) {
                        // Circle indicator for on/off state
                        Box(
                            modifier = Modifier
                                .size(16.dp)
                                .clip(CircleShape)
                                .background(if (module.online) Color.Green else Color.Gray) // Green if ON, Gray if OFF
                        )

                        if (module.id == 0) {
                            InterruptButton()
                        }
                    }
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
                    Text(
                        "GPIO ${analogInput.pin}: ${String.format("%.3f", analogInput.value.toDouble())}V",
                        style = MaterialTheme.typography.bodySmall
                    )
                    AnalogInputGraph(analogInput)
                }
            }

            // Pulse Counters
            Column(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(2.dp) // Space between inputs
            ) {
                Text("Pulse Counters:")
                module.pulseCounters?.let { pulseCounters ->
                    for ((index, pulseCounter) in pulseCounters.withIndex()) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 5.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("${index + 1} | GPIO: ${pulseCounter.pin} | Count: ${pulseCounter.value}")

                            // Circle indicator for open/closed state
                            Box(
                                modifier = Modifier
                                    .size(16.dp)
                                    .clip(CircleShape)
                                    .background(if (pulseCounter.isOpen) Color.Green else Color.Gray) // Green if open, Gray if closed
                            )
                        }
                    }
                } ?: run {
                    Text("No pulse counters available")
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
    var active by remember { mutableStateOf(output.value) }

    LaunchedEffect(output.value) {
        active = output.value // Sync state when output.value changes
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 5.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("${index + 1} | GPIO: ${output.pin} | ${output.value}")

        if (output.manual) {
            Box(
                modifier = Modifier.border(width = 1.dp, color = Color.Red)
            ) {
                Text(
                    text = "F",
                    fontWeight = FontWeight.Bold,
                    color = Color.Red,
                    modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp)
                )
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

                        ApiClient.api.toggleModuleOutput(module.id, toggleRequest)

                        // Update state to reflect the API request
                        output.value = active
                    } catch (e: Exception) {
                        active = !active // revert back
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
    val maxPoints = 100 // Keep last 100 points

    // Add new value at each refresh interval
    LaunchedEffect(analogInput.value.toDouble()) {
        val newValue = analogInput.value.toDouble()
        values.add(newValue) // Add to the right (end of list)
        
        // Keep only the last maxPoints (remove from left)
        if (values.size > maxPoints) {
            values.removeAt(0) // Remove oldest point from left
        }
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

    LineChart(
        modifier = Modifier
            .fillMaxWidth()
            .height(120.dp)
            .padding(bottom = 16.dp),
        data = listOf(line.value),
        animationMode = AnimationMode.OneByOne,
        labelHelperProperties = LabelHelperProperties(false),
        minValue = 0.0,
        maxValue = 3.3
    )
}

@Composable
fun InterruptButton() {
    var showDialog by remember { mutableStateOf(false) }

    IconButton(
        onClick = { showDialog = true }
    ) {
        Icon(
            imageVector = Icons.Default.ExitToApp, // Power off icon
            contentDescription = "Interrupt",
            tint = Color.Red // Red color for power-off button
        )
    }

    if (showDialog) {
        AlertDialog(
            onDismissRequest = { showDialog = false },
            title = { Text("Confirm Interrupt") },
            text = { Text("Are you sure you want to turn off/interrupt the module?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDialog = false
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                ApiClient.api.callInterrupt() // Call the API to turn off the module
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }
                    }
                ) {
                    Text("Yes", color = Color.Red)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

