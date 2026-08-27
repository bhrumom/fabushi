package com.ombhrum.fabushi

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

private const val WEB_MCP_ORIGIN = "fabushi.ombhrum.com"

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun MiniAppWebMcpSurface(
    plugin: MarketplacePlugin,
    onClose: () -> Unit,
) {
    val context = LocalContext.current
    var status by remember(plugin.pluginId) { mutableStateOf("正在加载 WebMCP…") }
    val encodedId = URLEncoder.encode(plugin.pluginId, StandardCharsets.UTF_8.toString())
    val url = "https://fabushi.ombhrum.com/miniapps/$encodedId/"

    BackHandler(onBack = onClose)

    Column(modifier = Modifier.fillMaxSize().testTag("miniapp-webmcp-surface")) {
        Row(modifier = Modifier.fillMaxWidth().padding(12.dp)) {
            Button(onClick = onClose, modifier = Modifier.testTag("miniapp-webmcp-close")) {
                Text("返回")
            }
            Column(modifier = Modifier.padding(start = 12.dp)) {
                Text(plugin.displayName, style = MaterialTheme.typography.titleMedium)
                Text(status, style = MaterialTheme.typography.labelSmall)
            }
        }

        val webView = remember(plugin.pluginId) {
            WebView(context).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.allowFileAccess = false
                settings.allowContentAccess = false
                settings.javaScriptCanOpenWindowsAutomatically = false
                settings.setSupportMultipleWindows(false)
                webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                        val uri = request.url
                        return uri.scheme != "https" || uri.host != WEB_MCP_ORIGIN
                    }

                    override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
                        status = "正在加载 WebMCP…"
                    }

                    override fun onPageFinished(view: WebView, url: String?) {
                        val probe = """
                            (() => {
                              const report = () => {
                                const tools = window.__fabushiWebMcp?.list?.() || [];
                                return JSON.stringify({ ready: tools.length > 0, tools: tools.map(t => t.name) });
                              };
                              return report();
                            })()
                        """.trimIndent()
                        view.evaluateJavascript(probe) { value ->
                            status = if (value.contains("\\\"ready\\\":true")) {
                                "WebMCP 已连接"
                            } else {
                                "WebMCP 页面已打开"
                            }
                        }
                    }
                }
                loadUrl(url)
            }
        }

        AndroidView(
            factory = { webView },
            modifier = Modifier.fillMaxSize().testTag("miniapp-webmcp-webview"),
        )

        DisposableEffect(webView) {
            onDispose {
                webView.stopLoading()
                webView.loadUrl("about:blank")
                webView.removeAllViews()
                webView.destroy()
            }
        }
    }
}
