package com.pii.mts

import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.google.gson.annotations.SerializedName
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds

data class Settings(
    @SerializedName("setting_name") val settingName: String,
    @SerializedName("setting_value") val settingValue: Int,
)

// Define known settings with their display names and units
data class SettingInfo(
    val key: String,
    val displayName: String,
    val unit: String,
    val description: String,
    val order: Int
)

val KNOWN_SETTINGS = mapOf(
    "lvs1-lower-bound" to SettingInfo(
        key = "lvs1-lower-bound",
        displayName = "Tank A Lower Bound",
        unit = "mV",
        description = "Minimum level threshold for Tank A (LVS1 sensor)",
        order = 1
    ),
    "lvs1-middle-bound" to SettingInfo(
        key = "lvs1-middle-bound", 
        displayName = "Tank A Middle Bound",
        unit = "mV",
        description = "Medium level threshold for Tank A (LVS1 sensor)",
        order = 2
    ),
    "lvs1-upper-bound" to SettingInfo(
        key = "lvs1-upper-bound",
        displayName = "Tank A Upper Bound", 
        unit = "mV",
        description = "Maximum level threshold for Tank A (LVS1 sensor)",
        order = 3
    ),
    "lvs2-lower-bound" to SettingInfo(
        key = "lvs2-lower-bound",
        displayName = "Tank B Lower Bound",
        unit = "mV", 
        description = "Minimum level threshold for Tank B (LVS2 sensor)",
        order = 4
    ),
    "lvs2-middle-bound" to SettingInfo(
        key = "lvs2-middle-bound",
        displayName = "Tank B Middle Bound",
        unit = "mV",
        description = "Medium level threshold for Tank B (LVS2 sensor)", 
        order = 5
    ),
    "lvs2-upper-bound" to SettingInfo(
        key = "lvs2-upper-bound",
        displayName = "Tank B Upper Bound",
        unit = "mV",
        description = "Maximum level threshold for Tank B (LVS2 sensor)",
        order = 6
    ),
    "prs1-max" to SettingInfo(
        key = "prs1-max",
        displayName = "Pressure Max",
        unit = "mV",
        description = "Maximum pressure threshold (PRS1 sensor)",
        order = 7
    )
)

val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

object SettingsRepository {
    private val REFRESH_RATE = longPreferencesKey("refresh_rate")

    fun getRefreshRateFlow(context: Context): Flow<Duration> {
        return context.dataStore.data.map { preferences ->
            (preferences[REFRESH_RATE] ?: 5000L).milliseconds
        }
    }

    suspend fun saveRefreshRate(context: Context, rate: Duration) {
        context.dataStore.edit { preferences ->
            preferences[REFRESH_RATE] = rate.inWholeMilliseconds
        }
    }
}

@Composable
fun SettingsSection(settings: Map<String, Int>?, onSave: (Map<String, Int>) -> Unit) {
    val snackbarHostState = remember { SnackbarHostState() }
    val coroutineScope = rememberCoroutineScope()

    // State for local edits
    val editableSettings = remember { mutableStateMapOf<String, Int>() }

    // Initialize editable settings when data is fetched
    LaunchedEffect(settings) {
        if (settings != null) {
            editableSettings.clear()
            editableSettings.putAll(settings)
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(hostState = snackbarHostState) }
    ) { paddingValues ->
        Column(
            modifier = Modifier.padding(paddingValues)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                elevation = CardDefaults.cardElevation(4.dp)
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text("Device Settings", style = MaterialTheme.typography.titleSmall)
                    Spacer(modifier = Modifier.height(12.dp))
                    UpdateRateDropdown(snackbarHostState)
                }
            }

            Card(
                modifier = Modifier.fillMaxWidth(),
                elevation = CardDefaults.cardElevation(4.dp)
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text("Remote Settings", style = MaterialTheme.typography.titleSmall)

                    if (settings == null) {
                        Text("Loading remote settings...")
                    } else {
                        Column {
                            // Sort settings by order (known settings first, then unknown ones)
                            val sortedSettings = editableSettings.entries.sortedBy { (key, _) ->
                                KNOWN_SETTINGS[key]?.order ?: Int.MAX_VALUE
                            }
                            
                            // Group settings by category
                            val tankASettings = sortedSettings.filter { (key, _) ->
                                key.startsWith("lvs1")
                            }
                            val tankBSettings = sortedSettings.filter { (key, _) ->
                                key.startsWith("lvs2")
                            }
                            val pressureSettings = sortedSettings.filter { (key, _) ->
                                key.startsWith("prs")
                            }
                            val otherSettings = sortedSettings.filter { (key, _) ->
                                !key.startsWith("lvs1") && !key.startsWith("lvs2") && !key.startsWith("prs")
                            }
                            
                            // Tank A Section
                            if (tankASettings.isNotEmpty()) {
                                Card(
                                    modifier = Modifier.fillMaxWidth(),
                                    elevation = CardDefaults.cardElevation(2.dp),
                                ) {
                                    Column(modifier = Modifier.padding(12.dp)) {
                                        Text(
                                            text = "Tank A",
                                            style = MaterialTheme.typography.titleMedium,
                                            modifier = Modifier.padding(bottom = 8.dp)
                                        )
                                        tankASettings.forEach { (key, value) ->
                                            SettingItem(key, value, editableSettings)
                                        }
                                    }
                                }
                                Spacer(modifier = Modifier.height(12.dp))
                            }
                            
                            // Tank B Section
                            if (tankBSettings.isNotEmpty()) {
                                Card(
                                    modifier = Modifier.fillMaxWidth(),
                                    elevation = CardDefaults.cardElevation(2.dp),
                                ) {
                                    Column(modifier = Modifier.padding(12.dp)) {
                                        Text(
                                            text = "Tank B",
                                            style = MaterialTheme.typography.titleMedium,
                                            modifier = Modifier.padding(bottom = 8.dp)
                                        )
                                        tankBSettings.forEach { (key, value) ->
                                            SettingItem(key, value, editableSettings)
                                        }
                                    }
                                }
                                Spacer(modifier = Modifier.height(12.dp))
                            }
                            
                            // Pressure Section
                            if (pressureSettings.isNotEmpty()) {
                                Card(
                                    modifier = Modifier.fillMaxWidth(),
                                    elevation = CardDefaults.cardElevation(2.dp),
                                ) {
                                    Column(modifier = Modifier.padding(12.dp)) {
                                        Text(
                                            text = "Pressure",
                                            style = MaterialTheme.typography.titleMedium,
                                            modifier = Modifier.padding(bottom = 8.dp)
                                        )
                                        pressureSettings.forEach { (key, value) ->
                                            SettingItem(key, value, editableSettings)
                                        }
                                    }
                                }
                                Spacer(modifier = Modifier.height(12.dp))
                            }
                            
                            // Other Settings
                            if (otherSettings.isNotEmpty()) {
                                Card(
                                    modifier = Modifier.fillMaxWidth(),
                                    elevation = CardDefaults.cardElevation(2.dp),
                                ) {
                                    Column(modifier = Modifier.padding(12.dp)) {
                                        Text(
                                            text = "Other",
                                            style = MaterialTheme.typography.titleMedium,
                                            modifier = Modifier.padding(bottom = 8.dp)
                                        )
                                        otherSettings.forEach { (key, value) ->
                                            SettingItem(key, value, editableSettings)
                                        }
                                    }
                                }
                                Spacer(modifier = Modifier.height(12.dp))
                            }
                            
                            Button(
                                onClick = {
                                    coroutineScope.launch {
                                        try {
                                            onSave(editableSettings)
                                            snackbarHostState.showSnackbar(
                                                "Settings saved!", 
                                                duration = SnackbarDuration.Short
                                            )
                                        } catch (e: Exception) {
                                            snackbarHostState.showSnackbar(
                                                "Failed to save settings!", 
                                                duration = SnackbarDuration.Short
                                            )
                                        }
                                    }
                                },
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
    }
}

@Composable
fun UpdateRateDropdown(snackbarHostState: SnackbarHostState) {
    val context = LocalContext.current
    val refreshRate by SettingsRepository.getRefreshRateFlow(context)
        .collectAsState(initial = 5000L.milliseconds)

    var expanded by remember { mutableStateOf(false) }
    val refreshRates = listOf(500, 1000, 2000, 3000, 4000, 5000).map { it.milliseconds }

    Box {
        Button(onClick = { expanded = true }) {
            Text("Refresh Rate: ${refreshRate.inWholeMilliseconds}ms")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            refreshRates.forEach { rate ->
                DropdownMenuItem(
                    text = { Text("${rate.inWholeMilliseconds}ms") },
                    onClick = {
                        expanded = false
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                SettingsRepository.saveRefreshRate(context, rate)
                                snackbarHostState.showSnackbar(
                                    "Settings saved!", 
                                    duration = SnackbarDuration.Short
                                )
                            } catch (e: Exception) {
                                snackbarHostState.showSnackbar(
                                    "Failed to save settings!", 
                                    duration = SnackbarDuration.Short
                                )
                            }
                        }
                    }
                )
            }
        }
    }
}

@Composable
fun SettingItem(key: String, value: Int, editableSettings: MutableMap<String, Int>) {
    val settingInfo = KNOWN_SETTINGS[key]
    val displayName = settingInfo?.displayName ?: key
    val unit = settingInfo?.unit ?: ""
    val description = settingInfo?.description ?: ""
    
    // Remove redundant section names from display names
    val cleanDisplayName = when {
        displayName.startsWith("Tank A ") -> displayName.substringAfter("Tank A ")
        displayName.startsWith("Tank B ") -> displayName.substringAfter("Tank B ")
        displayName.startsWith("Pressure ") -> displayName.substringAfter("Pressure ")
        else -> displayName
    }
    
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
    ) {
        // Setting name and description
        Text(
            text = cleanDisplayName,
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.fillMaxWidth()
        )
        if (description.isNotEmpty()) {
            Text(
                text = description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.fillMaxWidth()
            )
        }
        
        // Input field with unit
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 2.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            TextField(
                value = editableSettings[key].toString(),
                onValueChange = { newValue ->
                    newValue.toIntOrNull()?.let { 
                        editableSettings[key] = it 
                    }
                },
                modifier = Modifier.weight(1f),
                colors = androidx.compose.material3.TextFieldDefaults.colors(
                    focusedContainerColor = MaterialTheme.colorScheme.surface,
                    unfocusedContainerColor = MaterialTheme.colorScheme.surface
                )
            )
            
            if (unit.isNotEmpty()) {
                Spacer(modifier = Modifier.padding(horizontal = 8.dp))
                Text(
                    text = unit,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }
    }
}

