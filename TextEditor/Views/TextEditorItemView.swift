//
//  TextEditorItemView.swift
//  TextEditor
//
//  Created by Ueoka Kazuya on 2022/06/21.
//

import Combine
import UIKit

public protocol TextEditorItemViewDelegate: AnyObject {
    func itemView(_ itemView: TextEditorItemView, didStartDraggingAt point: CGPoint)
    func itemView(_ itemView: TextEditorItemView, didChangeDraggingAt point: CGPoint)
    func itemView(_ itemView: TextEditorItemView, didEndDraggingAt point: CGPoint)
}

/// TextEditorStackViewにSubViewとして追加することを想定しているView
/// テキスト、画像などを収められる。
/// ユーザーのドラッグ開始・停止などのイベントをdelegateで受け取れる(UILongPressGestureRecognizerを利用)。
@MainActor public final class TextEditorItemView: UIView {
    public weak var delegate: TextEditorItemViewDelegate?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    @MainActor override public func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setUp()
    }

    private lazy var setUp: () -> Void = {
        isUserInteractionEnabled = true
        backgroundColor = TextEditorConstant.Color.background
        replaceContentView()
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPress(gesture:)))
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tap(gesture:)))
        _ = tapGestureRecognizer.shouldRequireFailure(of: longPressGestureRecognizer)
        addGestureRecognizer(tapGestureRecognizer)
        addGestureRecognizer(longPressGestureRecognizer)
        return {}
    }()

    @objc private func tap(gesture _: UITapGestureRecognizer) {
        // 子要素がテキストであれば、テキストにフォーカスを合わせキーボードを開ける
        if let textView = contentView as? TextEditorTextView {
            _ = textView.becomeFirstResponder()
        }
    }

    @objc private func longPress(gesture: UILongPressGestureRecognizer) {
        let currentPosition = gesture.location(in: gesture.view)
        switch gesture.state {
        case .began:
            delegate?.itemView(self, didStartDraggingAt: currentPosition)
        case .changed:
            delegate?.itemView(self, didChangeDraggingAt: currentPosition)
        case .ended:
            delegate?.itemView(self, didEndDraggingAt: currentPosition)
        default:
            break
        }
    }

    public var item: TextEditorItemRepresentable? {
        didSet {
            replaceContentView()
        }
    }

    private func resetContentView() {
        contentView?.removeFromSuperview()
        contentView = nil
        contentViewConstraints.forEach { $0.isActive = false }
        contentViewConstraints = []
        cancellables.removeAll()
        contentViewHeightConstraint = nil
    }

    private func replaceContentView() {
        resetContentView()
        guard let item = item else { return }
        contentView = item.contentView
        addContentView(item.contentView)
        subscribeContentSize()
    }

    /// item(TextEditorItemRepresentable)のcontentViewを保持しておくための変数
    /// viewにaddSubViewしたりremoveFromSuperViewしたりする。
    public var contentView: UIView?

    /// contentViewの制約（高さも含む）
    private lazy var contentViewConstraints: [NSLayoutConstraint] = []
    /// contentViewの高さの制約
    private var contentViewHeightConstraint: NSLayoutConstraint?

    private func addContentView(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        let heightConstraint = view.heightAnchor.constraint(equalToConstant: TextEditorConstant.minimumItemHeight)
        contentViewConstraints = [
            view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 16),
            view.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 8),
            heightConstraint
        ]
        NSLayoutConstraint.activate(contentViewConstraints)
        contentViewHeightConstraint = heightConstraint
    }

    private var cancellables: Set<AnyCancellable> = .init()

    private func subscribeContentSize() {
        guard let item = item else { return }
        // 子要素のサイズが変更されたときに呼ばれる
        item.contentSizeDidChangePublisher
            .map { max(TextEditorConstant.minimumItemHeight, $0.height) }
            .removeDuplicates()// 無駄な更新防止
            .sink { [weak self] height in
                // contentViewの高さの制約更新
                self?.contentViewHeightConstraint?.constant = height
                self?.invalidateIntrinsicContentSize()
            }
            .store(in: &cancellables)
    }
}
