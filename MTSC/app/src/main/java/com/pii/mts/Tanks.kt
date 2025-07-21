package com.pii.mts

import Module
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Settings
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
import kotlin.math.min
import kotlinx.coroutines.launch
import androidx.compose.runtime.rememberCoroutineScope

// Tank data models
data class TankData(
    val id: String,
    val name: String,
    val currentLevel: Float, // in mV
    val lowerBound: Float,
    val middleBound: Float,
    val upperBound: Float,
    val pumpActive: Boolean,
    val pumpName: String,
    val flowRate: Float = 0f,
    val isOnline: Boolean = true
)

enum class TankLevelStatus {
    CRITICAL_LOW,
    LOW,
    NORMAL,
    CRITICAL_HIGH
}

@Composable
fun TanksSection(
    modules: List<Module>,
    settings: Map<String, Int>?,
    modifier: Modifier = Modifier
) {
    val tankData = remember(modules, settings) {
        createTankData(modules, settings)
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // System Status Card (now includes mode toggle)
        SystemStatusCard(tankData)
        
        // Tank Cards
        tankData.forEach { tank ->
            TankCard(tankData = tank, settings = settings)
        }
        
        // Settings Summary
        if (settings != null) {
            SettingsSummaryCard(settings)
        }
    }
}

@Composable
fun SystemStatusCard(tanks: List<TankData>) {
    val onlineTanks = tanks.count { it.isOnline }
    val totalTanks = tanks.size
    val activePumps = tanks.count { it.pumpActive }
    val criticalTanks = tanks.count { 
        it.currentLevel <= it.lowerBound || it.currentLevel >= it.upperBound 
    }
    
    var isAutomaticMode by remember { mutableStateOf(true) }
    var isLoading by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

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
            Text(
                text = "System Status",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                StatusIndicator(
                    icon = Icons.Default.CheckCircle,
                    label = "Online Tanks",
                    value = "$onlineTanks/$totalTanks",
                    color = if (onlineTanks == totalTanks) Color.Green else Color(0xFFFF9800) // Orange
                )
                
                StatusIndicator(
                    icon = Icons.Default.CheckCircle,
                    label = "Active Pumps",
                    value = activePumps.toString(),
                    color = if (activePumps > 0) Color.Blue else Color.Gray
                )
                
                StatusIndicator(
                    icon = Icons.Default.Warning,
                    label = "Critical Tanks",
                    value = criticalTanks.toString(),
                    color = if (criticalTanks > 0) Color.Red else Color.Green
                )
            }
            
            // Manual/Automatic Mode Toggle
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = if (isAutomaticMode) "Automatic Mode" else "Manual Mode",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Medium
                    )
                    Text(
                        text = if (isAutomaticMode) 
                            "System automatically controls pumps based on tank levels" 
                        else 
                            "Manual control enabled - pumps require manual activation",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                
                Button(
                    onClick = {
                        isLoading = true
                        // TODO: Call API endpoint here
                        // For now, just toggle the state after a delay to simulate API call
                        scope.launch {
                            kotlinx.coroutines.delay(1000) // Simulate API call delay
                            isAutomaticMode = !isAutomaticMode
                            isLoading = false
                        }
                    },
                    enabled = !isLoading,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isAutomaticMode) 
                            MaterialTheme.colorScheme.tertiary 
                        else 
                            MaterialTheme.colorScheme.secondary
                    ),
                    modifier = Modifier.height(48.dp)
                ) {
                    if (isLoading) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            color = MaterialTheme.colorScheme.onTertiary,
                            strokeWidth = 2.dp
                        )
                    } else {
                        Icon(
                            imageVector = if (isAutomaticMode) Icons.Default.Settings else Icons.Default.PlayArrow,
                            contentDescription = if (isAutomaticMode) "Switch to Manual" else "Switch to Automatic",
                            modifier = Modifier.size(20.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = if (isAutomaticMode) "Manual" else "Auto",
                        fontWeight = FontWeight.Bold
                    )
                }
            }
            
            // Status indicator
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(12.dp)
                        .clip(CircleShape)
                        .background(
                            if (isAutomaticMode) Color.Green else Color(0xFFFF9800) // Orange for manual
                        )
                )
                Text(
                    text = if (isAutomaticMode) "AUTOMATIC" else "MANUAL",
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Bold,
                    color = if (isAutomaticMode) Color.Green else Color(0xFFFF9800)
                )
            }
        }
    }
}

@Composable
fun StatusIndicator(
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
fun TankCard(
    tankData: TankData,
    settings: Map<String, Int>?
) {
    val levelPercentage = remember(tankData.currentLevel, tankData.upperBound) {
        min(tankData.currentLevel / tankData.upperBound, 1.0f)
    }
    
    val levelStatus = remember(tankData.currentLevel, tankData.lowerBound, tankData.middleBound, tankData.upperBound) {
        when {
            tankData.currentLevel <= tankData.lowerBound -> TankLevelStatus.CRITICAL_LOW
            tankData.currentLevel <= tankData.middleBound -> TankLevelStatus.LOW
            tankData.currentLevel >= tankData.upperBound -> TankLevelStatus.CRITICAL_HIGH
            else -> TankLevelStatus.NORMAL
        }
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(4.dp),
        colors = CardDefaults.cardColors(
            containerColor = when (levelStatus) {
                TankLevelStatus.CRITICAL_LOW -> MaterialTheme.colorScheme.errorContainer
                TankLevelStatus.LOW -> MaterialTheme.colorScheme.tertiaryContainer
                TankLevelStatus.CRITICAL_HIGH -> MaterialTheme.colorScheme.errorContainer
                TankLevelStatus.NORMAL -> MaterialTheme.colorScheme.surface
            }
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = tankData.name,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    // Online status indicator
                    Box(
                        modifier = Modifier
                            .size(12.dp)
                            .clip(CircleShape)
                            .background(
                                if (tankData.isOnline) Color.Green else Color.Gray
                            )
                    )
                    
                    // Level status indicator
                    Icon(
                        imageVector = when (levelStatus) {
                            TankLevelStatus.CRITICAL_LOW -> Icons.Default.Warning
                            TankLevelStatus.LOW -> Icons.Default.Warning
                            TankLevelStatus.CRITICAL_HIGH -> Icons.Default.Warning
                            TankLevelStatus.NORMAL -> Icons.Default.CheckCircle
                        },
                        contentDescription = "Level Status",
                        tint = when (levelStatus) {
                            TankLevelStatus.CRITICAL_LOW -> MaterialTheme.colorScheme.error
                            TankLevelStatus.LOW -> MaterialTheme.colorScheme.tertiary
                            TankLevelStatus.CRITICAL_HIGH -> MaterialTheme.colorScheme.error
                            TankLevelStatus.NORMAL -> MaterialTheme.colorScheme.primary
                        },
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            // Tank details
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                TankDetailRow("Current Level", "${String.format("%.1f", tankData.currentLevel)} mV")
                TankDetailRow("Lower Bound", "${String.format("%.1f", tankData.lowerBound)} mV")
                TankDetailRow("Middle Bound", "${String.format("%.1f", tankData.middleBound)} mV")
                TankDetailRow("Upper Bound", "${String.format("%.1f", tankData.upperBound)} mV")
                TankDetailRow("Level Percentage", "${(levelPercentage * 100).toInt()}%")
                
                Spacer(modifier = Modifier.height(8.dp))
                
                // Pump status
                PumpStatusIndicator(
                    pumpName = tankData.pumpName,
                    isActive = tankData.pumpActive,
                    flowRate = tankData.flowRate
                )
            }

            // Simple level indicator
            LinearProgressIndicator(
                progress = levelPercentage,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(8.dp),
                color = when (levelStatus) {
                    TankLevelStatus.CRITICAL_LOW -> MaterialTheme.colorScheme.error
                    TankLevelStatus.LOW -> MaterialTheme.colorScheme.tertiary
                    TankLevelStatus.CRITICAL_HIGH -> MaterialTheme.colorScheme.error
                    TankLevelStatus.NORMAL -> MaterialTheme.colorScheme.primary
                },
                trackColor = MaterialTheme.colorScheme.surfaceVariant
            )
        }
    }
}

@Composable
fun TankDetailRow(label: String, value: String) {
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

@Composable
fun PumpStatusIndicator(
    pumpName: String,
    isActive: Boolean,
    flowRate: Float
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = if (isActive) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(12.dp)
                        .clip(CircleShape)
                        .background(if (isActive) Color.Green else Color.Gray)
                )
                Text(
                    text = pumpName,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }
            
            Text(
                text = if (isActive) "ACTIVE" else "INACTIVE",
                style = MaterialTheme.typography.bodySmall,
                color = if (isActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
            )
            
            if (isActive && flowRate > 0) {
                Text(
                    text = "Flow: ${String.format("%.1f", flowRate)} L/min",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }
        }
    }
}

@Composable
fun SettingsSummaryCard(settings: Map<String, Int>) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(2.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = "Current Settings",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
            
            settings.entries
                .filter { it.key.startsWith("lvs") || it.key.startsWith("prs") }
                .sortedBy { it.key }
                .forEach { (key, value) ->
                    val displayName = when (key) {
                        "lvs1-lower-bound" -> "Tank A Lower Bound"
                        "lvs1-middle-bound" -> "Tank A Middle Bound"
                        "lvs1-upper-bound" -> "Tank A Upper Bound"
                        "lvs2-lower-bound" -> "Tank B Lower Bound"
                        "lvs2-middle-bound" -> "Tank B Middle Bound"
                        "lvs2-upper-bound" -> "Tank B Upper Bound"
                        "prs1-max" -> "Pressure Max"
                        else -> key
                    }
                    
                    TankDetailRow(displayName, "$value mV")
                }
        }
    }
}

// Helper function to create tank data from modules and settings
fun createTankData(modules: List<Module>, settings: Map<String, Int>?): List<TankData> {
    val module0 = modules.find { it.id == 0 }
    val module1 = modules.find { it.id == 1 }
    
    val tankA = TankData(
        id = "A",
        name = "Tank A",
        currentLevel = module0?.analogInputs?.getOrNull(2)?.value?.toFloatOrNull() ?: 0f,
        lowerBound = (settings?.get("lvs1-lower-bound") ?: 500) / 1000f,
        middleBound = (settings?.get("lvs1-middle-bound") ?: 700) / 1000f,
        upperBound = (settings?.get("lvs1-upper-bound") ?: 1050) / 1000f,
        pumpActive = module0?.outputs?.getOrNull(0)?.value == true,
        pumpName = "P3 (Valve + Remote Pump)",
        flowRate = module0?.pulseCounters?.getOrNull(0)?.value?.toFloat() ?: 0f,
        isOnline = module0?.online ?: false
    )
    
    val tankB = TankData(
        id = "B",
        name = "Tank B",
        currentLevel = module1?.analogInputs?.getOrNull(0)?.value?.toFloatOrNull() ?: 0f,
        lowerBound = (settings?.get("lvs2-lower-bound") ?: 500) / 1000f,
        middleBound = (settings?.get("lvs2-middle-bound") ?: 700) / 1000f,
        upperBound = (settings?.get("lvs2-upper-bound") ?: 1200) / 1000f,
        pumpActive = module0?.outputs?.getOrNull(5)?.value == false, // Inverted for Tank B: 0 = active, 1 = inactive
        pumpName = "P1 (Local Pump)",
        flowRate = module0?.pulseCounters?.getOrNull(1)?.value?.toFloat() ?: 0f,
        isOnline = module1?.online ?: false
    )
    
    return listOf(tankA, tankB)
} 