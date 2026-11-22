import UIKit

final class HomeView: UIView {
    enum FilesState { case ready, attention, problem, busy }

    #if targetEnvironment(macCatalyst)
    static func macScale(forHeight height: CGFloat) -> CGFloat { min(max(height / 1000, 1), 2) }
    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = (window?.screen.scale ?? 2) * transform.a
        func sharpen(_ view: UIView) {
            if view.contentScaleFactor != scale { view.contentScaleFactor = scale }
            view.subviews.forEach(sharpen)
        }
        sharpen(self)
    }
    #endif

    let playButton = Theme.primaryButton("تشغيل اللعبة", symbol: "play.fill")
    let settingsButton = Theme.glassButton("الإعدادات", symbol: "gearshape.fill")
    let layoutButton = Theme.glassButton("تخطيط الأزرار", symbol: "hand.tap.fill")
    let telegramButton = Theme.glassButton("Rom.dom", symbol: "paperplane.fill")
    let preloadLabel = UILabel()
    let controllerLabel = UILabel()

    var onFiles: (() -> Void)?
    var onMode: ((Int) -> Void)?
    var onMap: ((Int) -> Void)?
    var onOpenMods: (() -> Void)?
    var onImportZip: (() -> Void)?

    private let sidebar = UIView()
    private var sidebarWidthConstraint: NSLayoutConstraint!
    private var sidebarExpanded = false
    private var sidebarButtons: [UIButton] = []
    private let brandLabel = UILabel()
    private var selectedGameIndex = 0

    private let heroTitle = UILabel()
    private let heroSubtitle = UILabel()
    private var perfButtons: [UIButton] = []
    private var selectedPerfIndex = 1

    private let filesCard = UIControl()
    private let filesIcon = UIImageView()
    private let filesTitle = UILabel()
    private let filesDetail = UILabel()
    private let filesSpinner = UIActivityIndicatorView(style: .medium)

    init(modes: [(title: String, symbol: String)], log: UIView) {
        super.init(frame: .zero)
        semanticContentAttribute = .forceLeftToRight

        let backdrop = Theme.backdrop(image: "StartBackground", darken: 0.55)
        pin(backdrop, to: self)

        setupSidebar()
        setupMainContent()
        selectGame(0, notify: false)
        selectPerf(1)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func setupSidebar() {
        sidebar.backgroundColor = UIColor.black.withAlphaComponent(0.92)
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sidebar)

        let guide = safeAreaLayoutGuide
        sidebarWidthConstraint = sidebar.widthAnchor.constraint(equalToConstant: 64)
        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: bottomAnchor),
            sidebarWidthConstraint
        ])

        brandLabel.text = "Rom.dom"
        brandLabel.font = Theme.display(13, .heavy)
        brandLabel.textColor = Theme.accent
        brandLabel.isHidden = true
        brandLabel.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(brandLabel)

        let toggleBtn = UIButton(type: .system)
        toggleBtn.setImage(UIImage(systemName: "sidebar.left"), for: .normal)
        toggleBtn.tintColor = .white
        toggleBtn.translatesAutoresizingMaskIntoConstraints = false
        toggleBtn.addAction(UIAction { [weak self] _ in self?.toggleSidebar() }, for: .touchUpInside)
        sidebar.addSubview(toggleBtn)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(stack)

        let items = ["GTA V", "Online", "GTA VI", "Rom.dom"]
        for (idx, title) in items.enumerated() {
            var cfg = UIButton.Configuration.filled()
            cfg.title = title
            cfg.baseBackgroundColor = UIColor(white: 1, alpha: 0.10)
            cfg.baseForegroundColor = .white
            cfg.cornerStyle = .medium
            let btn = UIButton(configuration: cfg)
            btn.titleLabel?.adjustsFontSizeToFitWidth = true
            btn.titleLabel?.minimumScaleFactor = 0.75
            btn.heightAnchor.constraint(equalToConstant: 36).isActive = true
            btn.addAction(UIAction { [weak self] _ in
                if idx == 3 {
                    UIApplication.shared.open(Theme.telegramURL)
                } else {
                    self?.selectGame(idx, notify: true)
                }
            }, for: .touchUpInside)
            sidebarButtons.append(btn)
            stack.addArrangedSubview(btn)
        }

        NSLayoutConstraint.activate([
            toggleBtn.topAnchor.constraint(equalTo: guide.topAnchor, constant: 10),
            toggleBtn.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 16),
            toggleBtn.widthAnchor.constraint(equalToConstant: 32),
            toggleBtn.heightAnchor.constraint(equalToConstant: 32),

            brandLabel.centerYAnchor.constraint(equalTo: toggleBtn.centerYAnchor),
            brandLabel.leadingAnchor.constraint(equalTo: toggleBtn.trailingAnchor, constant: 8),

            stack.topAnchor.constraint(equalTo: toggleBtn.bottomAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -8)
        ])
    }

    private func toggleSidebar() {
        sidebarExpanded.toggle()
        sidebarWidthConstraint.constant = sidebarExpanded ? 175 : 64
        brandLabel.isHidden = !sidebarExpanded
        UIView.animate(withDuration: 0.2) { self.layoutIfNeeded() }
    }

    private func selectGame(_ index: Int, notify: Bool) {
        selectedGameIndex = index
        for (i, btn) in sidebarButtons.enumerated() {
            let active = (i == index)
            btn.configuration?.baseBackgroundColor = active ? Theme.accent : UIColor(white: 1, alpha: 0.10)
            btn.configuration?.baseForegroundColor = active ? .black : .white
        }
        switch index {
        case 0:
            heroTitle.text = "Grand Theft Auto V"
            heroSubtitle.text = "Rom.dom Launcher · Story Mode"
            if notify { onMode?(0) }
        case 1:
            heroTitle.text = "Grand Theft Auto Online"
            heroSubtitle.text = "Rom.dom Launcher · Free Roam"
            if notify { onMap?(0); onMode?(1) }
        default:
            heroTitle.text = "Grand Theft Auto VI"
            heroSubtitle.text = "Rom.dom Launcher · Preview"
            if notify { onMode?(1); onMap?(1) }
        }
    }

    private func setupMainContent() {
        let guide = safeAreaLayoutGuide
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 14),
            container.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -14),
            container.topAnchor.constraint(equalTo: guide.topAnchor, constant: 10),
            container.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -10)
        ])

        buildFilesCard()
        filesCard.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(filesCard)

        heroTitle.font = Theme.display(26, .black)
        heroTitle.textColor = .white
        heroTitle.adjustsFontSizeToFitWidth = true
        heroTitle.minimumScaleFactor = 0.7

        heroSubtitle.font = Theme.body(13, .semibold)
        heroSubtitle.textColor = Theme.accent
        heroSubtitle.adjustsFontSizeToFitWidth = true
        heroSubtitle.minimumScaleFactor = 0.75

        let heroStack = UIStackView(arrangedSubviews: [heroTitle, heroSubtitle])
        heroStack.axis = .vertical
        heroStack.spacing = 3
        heroStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(heroStack)

        let presets = ["24 FPS", "30 FPS", "60 FPS", "720p", "Custom"]
        let perfStack = UIStackView()
        perfStack.axis = .horizontal
        perfStack.spacing = 8
        perfStack.distribution = .fillEqually
        perfStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(perfStack)

        for (i, title) in presets.enumerated() {
            var cfg = UIButton.Configuration.filled()
            cfg.title = title
            cfg.cornerStyle = .medium
            let btn = UIButton(configuration: cfg)
            btn.titleLabel?.adjustsFontSizeToFitWidth = true
            btn.titleLabel?.minimumScaleFactor = 0.7
            btn.heightAnchor.constraint(equalToConstant: 42).isActive = true
            btn.addAction(UIAction { [weak self] _ in self?.selectPerf(i) }, for: .touchUpInside)
            perfButtons.append(btn)
            perfStack.addArrangedSubview(btn)
        }

        telegramButton.addAction(UIAction { _ in UIApplication.shared.open(Theme.telegramURL) }, for: .touchUpInside)
        for b in [telegramButton, layoutButton, settingsButton] {
            b.configuration?.title = nil
        }

        playButton.translatesAutoresizingMaskIntoConstraints = false
        let bottomBar = UIStackView(arrangedSubviews: [playButton, UIView(), telegramButton, layoutButton, settingsButton])
        bottomBar.axis = .horizontal
        bottomBar.spacing = 8
        bottomBar.alignment = .center
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bottomBar)

        controllerLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        controllerLabel.textColor = Theme.secondaryText
        controllerLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(controllerLabel)

        NSLayoutConstraint.activate([
            filesCard.topAnchor.constraint(equalTo: container.topAnchor),
            filesCard.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            filesCard.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, multiplier: 0.65),

            controllerLabel.centerYAnchor.constraint(equalTo: filesCard.centerYAnchor),
            controllerLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            heroStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            heroStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            heroStack.bottomAnchor.constraint(equalTo: perfStack.topAnchor, constant: -14),

            perfStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            perfStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            perfStack.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -14),

            bottomBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 46)
        ])
    }

    private func selectPerf(_ index: Int) {
        selectedPerfIndex = index
        for (i, btn) in perfButtons.enumerated() {
            let active = (i == index)
            btn.configuration?.baseBackgroundColor = active ? Theme.accent : UIColor(white: 1, alpha: 0.12)
            btn.configuration?.baseForegroundColor = active ? .black : .white
        }
        let s = GameSettings.shared
        switch index {
        case 0: s.frameRateCap = 30; s.graphicsPreset = .battery; s.renderHeight = 0
        case 1: s.frameRateCap = 30; s.graphicsPreset = .performance; s.renderHeight = 0
        case 2: s.frameRateCap = 60; s.graphicsPreset = .performance; s.renderHeight = 0
        case 3: s.frameRateCap = 60; s.graphicsPreset = .quality; s.renderHeight = 720
        default: break
        }
    }

    private func buildFilesCard() {
        let panel = Theme.panel(cornerRadius: 10)
        panel.isUserInteractionEnabled = false
        pin(panel, to: filesCard)

        filesIcon.contentMode = .scaleAspectFit
        filesTitle.font = Theme.body(12, .bold)
        filesTitle.textColor = .white
        filesDetail.font = Theme.body(10.5)
        filesDetail.textColor = Theme.secondaryText

        let textStack = UIStackView(arrangedSubviews: [filesTitle, filesDetail])
        textStack.axis = .vertical
        textStack.spacing = 1

        let row = UIStackView(arrangedSubviews: [filesIcon, filesSpinner, textStack])
        row.spacing = 8
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        filesCard.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: filesCard.leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: filesCard.trailingAnchor, constant: -10),
            row.topAnchor.constraint(equalTo: filesCard.topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: filesCard.bottomAnchor, constant: -6)
        ])
        filesCard.addAction(UIAction { [weak self] _ in self?.onFiles?() }, for: .touchUpInside)
    }

    func refreshLanguage() {
        playButton.configuration?.title = "تشغيل اللعبة"
    }

    func setFiles(_ state: FilesState, title: String, detail: String) {
        filesTitle.text = title
        filesDetail.text = detail
        filesDetail.isHidden = detail.isEmpty
        filesSpinner.isHidden = state != .busy
        filesIcon.isHidden = state == .busy
        if state == .busy { filesSpinner.startAnimating() } else { filesSpinner.stopAnimating() }

        let (symbol, color): (String, UIColor) = switch state {
        case .ready: ("checkmark.circle.fill", Theme.ok)
        case .attention: ("folder.badge.plus", Theme.warning)
        case .problem: ("exclamationmark.triangle.fill", Theme.problem)
        case .busy: ("", .white)
        }
        filesIcon.image = symbol.isEmpty ? nil : UIImage(systemName: symbol)
        filesIcon.tintColor = color
    }

    func setMap(_ index: Int, visible: Bool, enabled: Bool, testMapAvailable: Bool = true) {
        if selectedGameIndex == 2 { selectGame(2, notify: false) }
    }

    func setMode(_ index: Int?, detail: String, enabled: Bool) {
        if let index, index != selectedGameIndex, selectedGameIndex != 2 {
            selectGame(index, notify: false)
        }
    }

    private func pin(_ view: UIView, to parent: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            view.topAnchor.constraint(equalTo: parent.topAnchor),
            view.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])
    }
}
