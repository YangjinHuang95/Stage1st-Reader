//
//  ReportComposeViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 8/9/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Result
import ReactiveCocoa
import ReactiveSwift
import SnapKit
import CocoaLumberjack
import YYKeyboardManager
import TextAttributes

final class ReportComposeViewModel {
    let apiManager: DiscuzAPIManager
    let topic: S1Topic
    let floor: Floor
    let content = MutableProperty("")

    let canSubmit = MutableProperty(false)
    let submiting = MutableProperty(false)

    init(apiManager: DiscuzAPIManager, topic: S1Topic, floor: Floor) {
        self.apiManager = apiManager
        self.topic = topic
        self.floor = floor

        canSubmit <~ content.producer
            .map { $0.characters.count > 0 }
            .combineLatest(with: submiting.producer)
            .map { $0 && !$1 }
    }

    func submit(_ completion: @escaping (NSError?) -> Void) {
        DDLogDebug("submit")
        guard let forumID = topic.fID, let formhash = topic.formhash else {
            return
        }
        submiting.value = true
        _ = apiManager.report("\(topic.topicID)", floorID: "\(floor.ID)", forumID: "\(forumID)", reason: content.value, formhash: formhash) { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.submiting.value = false
            completion(error)
        }
    }
}

final class ReportComposeViewController: UIViewController {
    let textView = UITextView(frame: .zero, textContainer: nil)
    let loadingHUD = S1HUD(frame: .zero)
    let keyboardManager = YYKeyboardManager.default()
    var textViewBottomConstraint: Constraint? = nil

    let viewModel: ReportComposeViewModel

    init(viewModel: ReportComposeViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("ReportComposeViewController.title", comment: "")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self._dismiss))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.submit))

        view.addSubview(textView)
        textView.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalTo(self.view)
            self.textViewBottomConstraint = make.bottom.equalTo(self.view.snp.bottom).constraint
        }

        view.addSubview(loadingHUD)
        loadingHUD.snp.makeConstraints { (make) in
            make.center.equalTo(self.view.snp.center)
        }

        view.layoutIfNeeded()

        // Binding
        viewModel.content <~ textView.reactive.continuousTextValues

        viewModel.canSubmit.producer.startWithValues { [weak self] (canSubmit) in
            guard let strongSelf = self else { return }
            strongSelf.navigationItem.rightBarButtonItem?.isEnabled = canSubmit
        }

        viewModel.submiting.producer.startWithValues { [weak self] (submiting) in
            guard let strongSelf = self else { return }
            if submiting {
                strongSelf.loadingHUD.showActivityIndicator()
            } else {
                strongSelf.loadingHUD.hide(withDelay: 0.0)
            }
        }

        keyboardManager.add(self)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ReportComposeViewController.didReceivePaletteChangeNotification(_:)),
                                               name: .APPaletteDidChangeNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .APPaletteDidChangeNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        textView.becomeFirstResponder()
        didReceivePaletteChangeNotification(nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        view.endEditing(true)
    }
}

// MARK: - YYKeyboardObserver
extension ReportComposeViewController: YYKeyboardObserver {
    func keyboardChanged(with transition: YYKeyboardTransition) {
         let offset = transition.toFrame.minY - view.frame.maxY

        self.textViewBottomConstraint?.update(offset: offset)

        UIView.animate(withDuration: transition.animationDuration, delay: 0.0, options: transition.animationOption, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
}

// MARK: - Actions
extension ReportComposeViewController {
    func submit() {
        view.endEditing(true)
        viewModel.submit { [weak self] (error) in
            guard let strongSelf = self else { return }
            if let error = error {
                // FIXME: Alert Error
                DDLogError("Report Submit Error: \(error)")
            } else {
                strongSelf.dismiss(animated: true, completion: nil)
            }
        }
    }

    func _dismiss() {
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: - Notification
    override func didReceivePaletteChangeNotification(_ notification: Notification?) {
        textView.backgroundColor = APColorManager.shared.colorForKey("report.background")
        textView.tintColor = APColorManager.shared.colorForKey("report.tint")
        textView.textColor = APColorManager.shared.colorForKey("report.text")
        textView.typingAttributes = TextAttributes().font(UIFont.systemFont(ofSize: 15.0)).foregroundColor(APColorManager.shared.colorForKey("report.text")).dictionary
        textView.keyboardAppearance = APColorManager.shared.isDarkTheme() ? .dark : .light

        self.navigationController?.navigationBar.barStyle = APColorManager.shared.isDarkTheme() ? .black : .default
    }
}

// MARK: - Style
extension ReportComposeViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return APColorManager.shared.isDarkTheme() ? .lightContent : .default
    }
}
