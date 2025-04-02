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
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
    // State for local edits
    val editableSettings = remember { mutableStateMapOf<String, Int>() }

    // Initialize editable settings when data is fetched
    LaunchedEffect(settings) {
        if (settings != null) {
            editableSettings.clear()
            editableSettings.putAll(settings)

        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Card(
            modifier = Modifier
                .fillMaxWidth(),
            elevation = CardDefaults.cardElevation(4.dp)
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text("Device Settings", style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(12.dp))
                UpdateRateDropdown()
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.cardElevation(4.dp)
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text("Remote Settings", style = MaterialTheme.typography.titleMedium)

                if (settings == null) {
                    Text("Loading remote settings...")
                } else {
                    Column {
                        editableSettings.forEach { (key, value) ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 4.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
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
}

@Composable
fun UpdateRateDropdown() {
    val context = LocalContext.current
    val refreshRate by SettingsRepository.getRefreshRateFlow(context)
        .collectAsState(initial = 5000L)

    // Dropdown for selecting update rate
    var expanded by remember { mutableStateOf(false) }
    val refreshRates = listOf(500, 1000, 2000, 3000, 4000, 5000).map { it.milliseconds }

    Box {
        Button(onClick = { expanded = true }) {
            Text("Refresh Rate: $refreshRate")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            refreshRates.forEach { rate ->
                DropdownMenuItem(
                    text = { Text("$rate") },
                    onClick = {
                        expanded = false

                        // Save new update rate
                        CoroutineScope(Dispatchers.IO).launch {
                            SettingsRepository.saveRefreshRate(context, rate)
                        }
                    }
                )
            }
        }
    }
}

