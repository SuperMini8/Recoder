//
//  AlertFactory.swift
//  Record_02
//
//  Creates reusable UIKit alerts.
//

import UIKit

enum AlertFactory {
    /// 製作一般的 Alert （2 個按鈕上限）
    static func make(title: String?,
                     message: String?,
                     preferredStyle: UIAlertController.Style = .alert,
                     action1Title: String? = nil,
                     action1Style: UIAlertAction.Style = .default,
                     action1Handler: ((UIAlertAction) -> Void)? = nil,
                     action2Title: String? = nil,
                     action2Style: UIAlertAction.Style = .default,
                     action2Handler: ((UIAlertAction) -> Void)? = nil,
                     sourceView: UIView? = nil,
                     sourceRect: CGRect? = nil) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: preferredStyle)
        let action1 = UIAlertAction(title: action1Title ?? "確認", style: action1Style, handler: action1Handler)
        alert.addAction(action1)

        if action2Title != nil {
            let action2 = UIAlertAction(title: action2Title, style: action2Style, handler: action2Handler)
            alert.addAction(action2)
        }

        if preferredStyle == .actionSheet, let sourceView {
            alert.popoverPresentationController?.sourceView = sourceView
            alert.popoverPresentationController?.sourceRect = sourceRect ?? CGRect(x: sourceView.bounds.midX,
                                                                                   y: sourceView.bounds.midY,
                                                                                   width: 0,
                                                                                   height: 0)
            alert.popoverPresentationController?.permittedArrowDirections = []
        }

        return alert
    }

    static func micNoPermission() -> UIAlertController {
        let openSettings: (UIAlertAction) -> Void = { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, completionHandler: nil)
            }
        }

        return make(title: "麥克風權限受限",
                    message: "必須要授權麥克風才能錄音",
                    action1Title: "設置",
                    action1Style: .destructive,
                    action1Handler: openSettings,
                    action2Title: "拒絕",
                    action2Style: .cancel)
    }

    static func renameRecord(currentTitle: String, onConfirm: @escaping (String) -> Void) -> UIAlertController {
        let alert = UIAlertController(title: "請輸入標題", message: nil, preferredStyle: .alert)
        let ok = UIAlertAction(title: "確定", style: .default) { _ in
            guard let text = alert.textFields?.first?.text else { return }
            onConfirm(text)
        }
        let cancel = UIAlertAction(title: "取消", style: .cancel, handler: nil)

        alert.addTextField { textField in
            textField.text = currentTitle
        }
        alert.addAction(ok)
        alert.addAction(cancel)

        return alert
    }
}
