import AppKit
import Carbon.HIToolbox

/// Phím tắt toàn cục qua Carbon `RegisterEventHotKey` (không cần quyền Input Monitoring).
/// Một event handler dùng chung, phân phối theo `EventHotKeyID.id`.
@MainActor
final class GlobalHotkeys {
    enum Hotkey: UInt32 {
        /// ⌃⌥G: kiểm tra đoạn đang bôi đen.
        case checkSelection = 1
        /// ⌃⌥C: copy câu đã sửa.
        case copyCorrection = 2

        var keyCode: Int {
            switch self {
            case .checkSelection: kVK_ANSI_G
            case .copyCorrection: kVK_ANSI_C
            }
        }

        var modifiers: Int { controlKey | optionKey }
    }

    private static let signature: OSType = 0x4752_4D52  // 'GRMR'

    private var handlerRef: EventHandlerRef?
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]

    func register(_ hotkey: Hotkey, action: @escaping () -> Void) {
        installHandlerIfNeeded()
        unregister(hotkey)
        actions[hotkey.rawValue] = action

        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: Self.signature, id: hotkey.rawValue)
        let status = RegisterEventHotKey(
            UInt32(hotkey.keyCode), UInt32(hotkey.modifiers), id, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            hotKeyRefs[hotkey.rawValue] = ref
        } else {
            NSLog("Grammar: không đăng ký được phím tắt \(hotkey) (mã \(status)), có thể đang bị app khác dùng.")
        }
    }

    func unregister(_ hotkey: Hotkey) {
        if let ref = hotKeyRefs.removeValue(forKey: hotkey.rawValue) { UnregisterEventHotKey(ref) }
        actions.removeValue(forKey: hotkey.rawValue)
    }

    private func fire(_ id: UInt32) {
        actions[id]?()
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
                guard status == noErr else { return status }
                let id = hotKeyID.id
                // Truyền địa chỉ dưới dạng số để không bắt con trỏ non-Sendable vào closure.
                let address = UInt(bitPattern: userData)
                MainActor.assumeIsolated {
                    let pointer = UnsafeMutableRawPointer(bitPattern: address)!
                    Unmanaged<GlobalHotkeys>.fromOpaque(pointer).takeUnretainedValue().fire(id)
                }
                return noErr
            },
            1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }
}
