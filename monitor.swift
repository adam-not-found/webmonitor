import Cocoa
import Vision
import ScreenCaptureKit

_ = NSApplication.shared
_ = CGMainDisplayID()

let configPath = NSString(string: "~/.webmonitor/config.json").expandingTildeInPath

struct WebMonitorConfig: Codable {
    let trigger_words: [String]
    let whitelist: [String]?
}

func loadTriggerWords() -> [String] {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
          let config = try? JSONDecoder().decode(WebMonitorConfig.self, from: data) else {
        return []
    }
    return config.trigger_words.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
}

// Low-overhead AppleScript execution to pull native text directly from Safari's DOM layer
func fetchSafariDOMText() -> String {
    let scriptSource = "tell application \"Safari\" to if (count of documents) > 0 then return text of front document"
    if let appleScript = NSAppleScript(source: scriptSource) {
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        if error == nil {
            return result.stringValue ?? ""
        }
    }
    return ""
}

var windowAlertTimestamps: [String: Date] = [:]
let cooldownDuration: TimeInterval = 60.0

Task {
    while true {
        do {
            guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                continue
            }
            let pid = frontmostApp.processIdentifier
            let appName = frontmostApp.localizedName ?? "Unknown App"
            
            if appName == "Terminal" || appName == "Xcode" {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                continue
            }
            
            let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            guard let targetWindow = shareableContent.windows.first(where: {
                $0.owningApplication?.processID == pid &&
                $0.title != nil && !$0.title!.isEmpty &&
                $0.frame.width > 100 && $0.frame.height > 100
            }) else {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                continue
            }
            
            let windowTitle = targetWindow.title ?? "Active Window"
            var textBuffer = ""
            
            // --- HYBRID ROUTING LAYER ---
            if appName == "Safari" {
                // Route A: Fast, 0-CPU document text dump
                textBuffer = fetchSafariDOMText().lowercased()
            } else {
                // Route B: Fallback to hardware accelerated OCR for Chrome, DuckDuckGo, and other apps
                let filter = SCContentFilter(desktopIndependentWindow: targetWindow)
                let config = SCStreamConfiguration()
                config.showsCursor = false
                config.width = Int(targetWindow.frame.width)
                config.height = Int(targetWindow.frame.height)
                
                let screenshot = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                
                let requestHandler = VNImageRequestHandler(cgImage: screenshot, options: [:])
                let textRequest = VNRecognizeTextRequest()
                textRequest.recognitionLevel = .fast
                textRequest.usesLanguageCorrection = false
                
                try requestHandler.perform([textRequest])
                
                if let observations = textRequest.results {
                    for observation in observations {
                        if let topCandidate = observation.topCandidates(1).first {
                            textBuffer += topCandidate.string.lowercased() + " "
                        }
                    }
                }
            }
            
            // --- EVALUATION & DISPATCH ---
            let triggerWords = loadTriggerWords()
            var matchFound = false
            var matchedWord = ""
            
            for word in triggerWords {
                if !word.isEmpty && textBuffer.contains(word) {
                    matchFound = true
                    matchedWord = word
                    break
                }
            }
            
            if matchFound {
                let now = Date()
                if let lastAlertDate = windowAlertTimestamps[windowTitle],
                   now.timeIntervalSince(lastAlertDate) < cooldownDuration {
                    // Silently block repeats during cooldown
                } else {
                    windowAlertTimestamps[windowTitle] = now
                    
                    let pythonPayload = "Trigger Word: \(matchedWord)\nApplication: \(appName)\nCaptured Window Context: \(windowTitle)"
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    process.arguments = ["python3", "\(NSHomeDirectory())/.webmonitor/monitor.py", "--alert", "word_found", pythonPayload]
                    try? process.run()
                }
            }
            
        } catch {
            // Context safety wrap
        }
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }
}

RunLoop.main.run()
