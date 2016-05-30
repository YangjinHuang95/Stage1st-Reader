//
//  S1UserViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 3/3/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit
import Alamofire
import Kingfisher

final class S1UserViewController: UIViewController {
    private(set) var user: User {
        didSet {
            self.usernameLabel.text = user.name
            if let avatarURL = user.avatarURL {
                self.avatarView.kf_setImageWithURL(avatarURL)
            }
            self.customStatusLabel.text = user.customStatus
            self.infoLabel.attributedText = infoLabelAttributedText(user)
        }
    }

    private let scrollView = UIScrollView(frame: CGRect.zero)
    private let containerView = UIView(frame: CGRect.zero)
    private let avatarView = UIImageView(image: nil) // FIXME: placeholder image.
    private let usernameLabel = UILabel(frame: CGRect.zero)
    private let customStatusLabel = UILabel(frame: CGRect.zero)
    private let infoLabel = UILabel(frame: CGRect.zero)

    // MARK: - Life Cycle
    init(user: User) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
//        self.modalPresentationStyle = .Popover
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = APColorManager.sharedInstance.colorForKey("content.background")

        self.view.addSubview(scrollView)
        scrollView.snp_makeConstraints { (make) in
            make.edges.equalTo(self.view)
        }

        scrollView.addSubview(containerView)
        containerView.snp_makeConstraints { (make) in
            make.edges.equalTo(scrollView) // To decide scrollView's content size
            make.width.equalTo(scrollView.snp_width) // To decide containerView's width
        }

        containerView.addSubview(avatarView)

        avatarView.snp_makeConstraints { (make) in
            make.leading.equalTo(self.containerView.snp_leading).offset(10.0)
            make.top.equalTo(self.containerView.snp_top).offset(10.0)
            make.width.height.equalTo(80.0)
        }

        containerView.addSubview(usernameLabel)
        usernameLabel.snp_makeConstraints { (make) in
            make.top.equalTo(self.avatarView.snp_top)
            make.leading.equalTo(self.avatarView.snp_trailing).offset(10.0)
            make.trailing.equalTo(self.containerView.snp_trailing).offset(-10)
        }

        customStatusLabel.numberOfLines = 0
        containerView.addSubview(customStatusLabel)
        customStatusLabel.snp_makeConstraints { (make) in
            make.top.equalTo(self.usernameLabel.snp_bottom).offset(10.0)
            make.leading.trailing.equalTo(self.usernameLabel)
        }

        infoLabel.numberOfLines = 0
        containerView.addSubview(infoLabel)
        infoLabel.snp_makeConstraints { (make) in
            make.top.greaterThanOrEqualTo(self.avatarView.snp_bottom).offset(10.0)
            make.top.greaterThanOrEqualTo(self.customStatusLabel.snp_bottom).offset(10.0)
            make.leading.equalTo(avatarView.snp_leading)
            make.trailing.equalTo(usernameLabel.snp_trailing)
        }

        // FIXME: base URL should not be hard coded.
        let apiManager = DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b")
        apiManager.profile(self.user.ID) { [weak self] (result) in
            guard let strongSelf = self else { return }
            switch result {
            case .Success(let user):
                strongSelf.user = user
            case .Failure(let error):
                strongSelf.s1_presentAlertView("Error", message: error.description)
            }
        }
    }

    private func infoLabelAttributedText(user: User) -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        if let lastVisitDateString = user.lastVisitDateString {
            attributedString.appendAttributedString(NSAttributedString(string: "最后访问：\n\(lastVisitDateString)\n"))
        }
        if let registerDateString = user.registerDateString {
            attributedString.appendAttributedString(NSAttributedString(string: "注册日期：\n\(registerDateString)\n"))
        }
        if let threadCount = user.threadCount {
            attributedString.appendAttributedString(NSAttributedString(string: "发帖数：\n\(threadCount)\n"))
        }
        if let postCount = user.postCount {
            attributedString.appendAttributedString(NSAttributedString(string: "回复数：\n\(postCount)\n"))
        }
        if let sigHTML = user.sigHTML {
            attributedString.appendAttributedString(NSAttributedString(string: "签名：\n\(sigHTML)\n"))
        }
        return attributedString
    }
}
