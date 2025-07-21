package com.pii.mts

import Module
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.SignalWifi4Bar
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.AcUnit
import androidx.compose.material.icons.filled.Opacity
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import java.text.SimpleDateFormat
import java.util.*

// Data models for system status
data class SystemStatusData(
    val networkStatus: NetworkStatus,
    val moduleHealth: ModuleHealth,
    val weatherData: WeatherData,
    val systemInfo: SystemInfo
)

data class NetworkStatus(
    val isConnected: Boolean,
    val ssid: String,
    val ipAddress: String,
    val signalStrength: Int = -1,
    val deviceReachable: Boolean
)

data class ModuleHealth(
    val totalModules: Int,
    val onlineModules: Int,
    val offlineModules: Int,
    val lastSeen: Map<String, String>
)

data class WeatherData(
    val temperature: String,
    val humidity: String,
    val pressure: String,
    val isAvailable: Boolean
)

data class SystemInfo(
    val uptime: String,
    val lastUpdate: String,
    val refreshRate: String
)

@Composable
fun SystemStatusSection(
    modules: List<Module>,
    isConnected: Boolean,
    deviceReachable: Boolean,
    refreshRate: kotlin.time.Duration,
    modifier: Modifier = Modifier
) {
    val systemStatus = remember(modules, isConnected, deviceReachable, refreshRate) {
        createSystemStatusData(modules, isConnected, deviceReachable, refreshRate)
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Network Status Card
        NetworkStatusCard(systemStatus.networkStatus)
        
        // Module Health Card
        ModuleHealthCard(systemStatus.moduleHealth)
        
        // Weather Data Card
        WeatherDataCard(systemStatus.weatherData)
        
        // System Info Card
        SystemInfoCard(systemStatus.systemInfo)
    }
}

@Composable
fun NetworkStatusCard(networkStatus: NetworkStatus) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(4.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.SignalWifi4Bar,
                    contentDescription = "Network",
                    tint = MaterialTheme.colorScheme.primary
                )
                Text(
                    text = "Network Status",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
            }

            // Connection Status
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Connection Status",
                    style = MaterialTheme.typography.bodyMedium
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(12.dp)
                            .clip(CircleShape)
                            .background(
                                if (networkStatus.isConnected) Color.Green else Color.Red
                            )
                    )
                    Text(
                        text = if (networkStatus.isConnected) "Connected" else "Disconnected",
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (networkStatus.isConnected) Color.Green else Color.Red
                    )
                }
            }

            // Device Reachability
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Device Reachable",
                    style = MaterialTheme.typography.bodyMedium
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(12.dp)
                            .clip(CircleShape)
                            .background(
                                if (networkStatus.deviceReachable) Color.Green else Color.Red
                            )
                    )
                    Text(
                        text = if (networkStatus.deviceReachable) "Yes" else "No",
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (networkStatus.deviceReachable) Color.Green else Color.Red
                    )
                }
            }

            // Network Details
            if (networkStatus.isConnected) {
                StatusDetailRow("SSID", networkStatus.ssid)
                StatusDetailRow("IP Address", networkStatus.ipAddress)
                if (networkStatus.signalStrength > -1) {
                    StatusDetailRow("Signal Strength", "${networkStatus.signalStrength} dBm")
                }
            }
        }
    }
}

@Composable
fun ModuleHealthCard(moduleHealth: ModuleHealth) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(4.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Storage,
                    contentDescription = "Modules",
                    tint = MaterialTheme.colorScheme.primary
                )
                Text(
                    text = "Module Health",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
            }

            // Module Status Overview
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                SystemStatusIndicator(
                    icon = Icons.Outlined.CheckCircle,
                    label = "Online",
                    value = moduleHealth.onlineModules.toString(),
                    color = Color.Green
                )
                
                SystemStatusIndicator(
                    icon = Icons.Outlined.Warning,
                    label = "Offline",
                    value = moduleHealth.offlineModules.toString(),
                    color = Color.Red
                )
                
                SystemStatusIndicator(
                    icon = Icons.Default.Storage,
                    label = "Total",
                    value = moduleHealth.totalModules.toString(),
                    color = MaterialTheme.colorScheme.primary
                )
            }

            // Last Seen Information
            if (moduleHealth.lastSeen.isNotEmpty()) {
                Text(
                    text = "Last Seen",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold
                )
                
                moduleHealth.lastSeen.forEach { (moduleId, lastSeen) ->
                    StatusDetailRow("Module $moduleId", formatLastSeen(lastSeen))
                }
            }
        }
    }
}

@Composable
fun WeatherDataCard(weatherData: WeatherData) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(4.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.LightMode,
                    contentDescription = "Weather",
                    tint = MaterialTheme.colorScheme.primary
                )
                Text(
                    text = "Weather Data",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
            }

            if (weatherData.isAvailable) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    WeatherIndicator(
                        icon = Icons.Default.AcUnit,
                        label = "Temperature",
                        value = weatherData.temperature,
                        unit = "°C"
                    )
                    
                    WeatherIndicator(
                        icon = Icons.Default.Opacity,
                        label = "Humidity",
                        value = weatherData.humidity,
                        unit = "%"
                    )
                    
                    WeatherIndicator(
                        icon = Icons.Default.Speed,
                        label = "Pressure",
                        value = weatherData.pressure,
                        unit = "hPa"
                    )
                }
            } else {
                Text(
                    text = "Weather sensor not available",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

@Composable
fun SystemInfoCard(systemInfo: SystemInfo) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(4.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    imageVector = Icons.Outlined.Info,
                    contentDescription = "System Info",
                    tint = MaterialTheme.colorScheme.primary
                )
                Text(
                    text = "System Information",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
            }

            StatusDetailRow("Uptime", systemInfo.uptime)
            StatusDetailRow("Last Update", systemInfo.lastUpdate)
            StatusDetailRow("Refresh Rate", systemInfo.refreshRate)
        }
    }
}

@Composable
fun SystemStatusIndicator(
    icon: ImageVector,
    label: String,
    value: String,
    color: Color
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = color,
            modifier = Modifier.size(24.dp)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = color
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
fun WeatherIndicator(
    icon: ImageVector,
    label: String,
    value: String,
    unit: String
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(24.dp)
        )
        Text(
            text = "$value $unit",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
fun StatusDetailRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium
        )
    }
}

// Helper functions
fun createSystemStatusData(
    modules: List<Module>,
    isConnected: Boolean,
    deviceReachable: Boolean,
    refreshRate: kotlin.time.Duration
): SystemStatusData {
    val networkStatus = NetworkStatus(
        isConnected = isConnected,
        ssid = "mywifi",
        ipAddress = "200.200.200.1",
        deviceReachable = deviceReachable
    )

    val moduleHealth = ModuleHealth(
        totalModules = modules.size,
        onlineModules = modules.count { it.online },
        offlineModules = modules.count { !it.online },
        lastSeen = modules.associate { it.id.toString() to it.lastSeen }
    )

    val weatherData = if (modules.isNotEmpty()) {
        val module0 = modules.find { it.id == 0 }
        WeatherData(
            temperature = module0?.weather?.temperature ?: "N/A",
            humidity = module0?.weather?.humidity ?: "N/A",
            pressure = module0?.weather?.pressure ?: "N/A",
            isAvailable = module0?.weather != null
        )
    } else {
        WeatherData("N/A", "N/A", "N/A", false)
    }

    val systemInfo = SystemInfo(
        uptime = "Running", // Could be enhanced with actual uptime tracking
        lastUpdate = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date()),
        refreshRate = "${refreshRate.inWholeMilliseconds}ms"
    )

    return SystemStatusData(networkStatus, moduleHealth, weatherData, systemInfo)
}

fun formatLastSeen(lastSeen: String): String {
    return try {
        // Assuming lastSeen is in ISO format, format it for display
        val inputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault())
        val outputFormat = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
        val date = inputFormat.parse(lastSeen)
        outputFormat.format(date ?: Date())
    } catch (e: Exception) {
        lastSeen
    }
} 