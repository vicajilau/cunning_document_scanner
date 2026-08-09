package biz.cunning.cunning_document_scanner

import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.SCANNER_MODE_BASE
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.SCANNER_MODE_BASE_WITH_FILTER
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.SCANNER_MODE_FULL
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ScannerArgumentsTest {
    @Test
    fun `resolveScannerMode maps every documented value`() {
        assertEquals(SCANNER_MODE_BASE, ScannerArguments.resolveScannerMode("base"))
        assertEquals(SCANNER_MODE_BASE_WITH_FILTER, ScannerArguments.resolveScannerMode("base_with_filter"))
        assertEquals(SCANNER_MODE_FULL, ScannerArguments.resolveScannerMode("full"))
    }

    @Test
    fun `resolveScannerMode falls back to full for null and unknown values`() {
        assertEquals(SCANNER_MODE_FULL, ScannerArguments.resolveScannerMode(null))
        assertEquals(SCANNER_MODE_FULL, ScannerArguments.resolveScannerMode("nonsense"))
    }

    @Test
    fun `resolveScannerSource prefers scannerSource over the deprecated flag`() {
        assertEquals("camera", ScannerArguments.resolveScannerSource("camera", true))
        assertEquals("gallery", ScannerArguments.resolveScannerSource("gallery", true))
    }

    @Test
    fun `resolveScannerSource honours the deprecated flag when scannerSource is absent`() {
        assertEquals("camera_and_gallery", ScannerArguments.resolveScannerSource(null, true))
        assertEquals("camera", ScannerArguments.resolveScannerSource(null, false))
        assertEquals("camera", ScannerArguments.resolveScannerSource(null, null))
    }

    @Test
    fun `isPluginScanFile matches only files this plugin wrote`() {
        assertTrue(ScannerArguments.isPluginScanFile("DOCUMENT_SCAN_0_20260809_120000.jpg"))
        assertTrue(ScannerArguments.isPluginScanFile("DOCUMENT_SCAN_20260809_120000.pdf"))
    }

    @Test
    fun `isPluginScanFile leaves host application files alone`() {
        // The regression this guards: matching on extension wiped the host app's own
        // images and PDFs out of the shared cache and pictures directories.
        assertFalse(ScannerArguments.isPluginScanFile("user_invoice.pdf"))
        assertFalse(ScannerArguments.isPluginScanFile("avatar.png"))
        assertFalse(ScannerArguments.isPluginScanFile("holiday.jpg"))
        assertFalse(ScannerArguments.isPluginScanFile("scan_DOCUMENT_SCAN_fake.jpg"))
    }
}
