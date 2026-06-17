package com.kakonzone.lumio

import android.content.Context
import android.util.Log
import com.google.android.play.integrity.IntegrityManager
import com.google.android.play.integrity.IntegrityManagerFactory
import com.google.android.play.integrity.IntegrityTokenRequest
import com.google.android.play.integrity.IntegrityTokenResponse
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

object PlayIntegrityBridge {
    private const val TAG = "PlayIntegrityBridge"
    private var integrityManager: IntegrityManager? = null
    private var lastToken: String? = null
    private var lastTokenTimestamp: Long = 0L
    private const val TOKEN_TTL_MS = 10 * 60 * 1000 // 10 minutes

    fun initialize(context: Context) {
        try {
            integrityManager = IntegrityManagerFactory.create(context)
            Log.i(TAG, "Play Integrity API initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Play Integrity API: ${e.message}")
        }
    }

    fun isInitialized(): Boolean = integrityManager != null

    suspend fun requestIntegrityToken(cloudProjectNumber: Long): Result<String> = withContext(Dispatchers.IO) {
        try {
            val manager = integrityManager ?: return@withContext Result.failure(
                IllegalStateException("IntegrityManager not initialized")
            )

            // Check if cached token is still valid
            val now = System.currentTimeMillis()
            if (lastToken != null && (now - lastTokenTimestamp) < TOKEN_TTL_MS) {
                Log.i(TAG, "Using cached integrity token")
                return@withContext Result.success(lastToken!!)
            }

            // Request new token
            val tokenRequest = IntegrityTokenRequest.builder()
                .setCloudProjectNumber(cloudProjectNumber)
                .build()

            Log.i(TAG, "Requesting integrity token...")
            val tokenResponse: IntegrityTokenResponse = manager.requestIntegrityToken(tokenRequest)
            
            lastToken = tokenResponse.token()
            lastTokenTimestamp = now
            
            Log.i(TAG, "Integrity token received successfully")
            Result.success(tokenResponse.token())
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request integrity token: ${e.message}")
            Result.failure(e)
        }
    }

    fun clearCache() {
        lastToken = null
        lastTokenTimestamp = 0L
    }

    fun getCachedToken(): String? = lastToken

    fun isCacheValid(): Boolean {
        val now = System.currentTimeMillis()
        return lastToken != null && (now - lastTokenTimestamp) < TOKEN_TTL_MS
    }
}
