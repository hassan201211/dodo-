import UIKit

/// Rockstar Games Launcher / Rom.dom styled start screen:
/// - Matches the layout and visual cards from the reference screenshots
/// - Safe layout supporting iPhone (iPhone 8 to latest) and iPad (9th gen to latest)
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

    let playButton = HomeView.makePlayButton()
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

    private static let brandName = "Rom.dom"
    private static let gold = UIColor(red: 0.97, green: 0.67, blue: 0.10, alpha: 1)
    private static let pink = UIColor(red: 0.91, green: 0.29, blue: 0.56, alpha: 1)

    private let socialItems: [(title: String, url: String)] = [
        ("تيليجرام \(HomeView.brandName)", "https://t.me/fivestarport"),
        ("انستغرام \(HomeView.brandName)", "https://instagram.com"),
        ("تيك توك \(HomeView.brandName)", "https://tiktok.com")
    ]

    private let sidebarAnchor = UIView()
    private let sidebar = UIView()
    private var sidebarWidth: NSLayoutConstraint!
    private var sidebarExpanded = false
    private var sidebarButtons: [UIButton] = []
    private let brandLabel = UILabel()
    private var selectedGameIndex = 0

    private let topBar = UIView()
    private var tabButtons: [UIButton] = []
    private let topAvatar = UIImageView()
    private let filesPill = UIControl()
    private let filesIcon = UIImageView()
    private let filesSpinner = UIActivityIndicatorView(style: .medium)
    private let filesLabel = UILabel()
    private var selectedTabIndex = 0

    private let gamesPage = UIView()
    private let modsPage = UIView()
    private let dataPage = UIView()
    private let settingsPage = UIView()
    private let storeOverlay = UIView()

    private let heroTitleLabel = UILabel()
    private let heroBadgeLabel = UILabel()
    private let heroArtImage = UIImageView()
    private let benchmarkButton = UIButton(type: .system)
    private let onlineMetaLabel = UILabel()
    private let gtaviBadgeLabel = UILabel()

    private let perfScroll = UIScrollView()
    private let perfStack = UIStackView()
    private var perfCards: [UIControl] = []
    private var perfArtViews: [UIImageView] = []
    private var perfActiveTags: [UILabel] = []
    private var selectedPerfIndex = 1
    private var didResetScrollOnce = false

    private let onlinePanel = UIView()
    private var onlineCards: [UIControl] = []
    private var selectedOnlineIndex = 0
    private let onlineInfoLabel = UILabel()

    private var socialCards: [UIControl] = []
    private var selectedSocialIndex = 0

    private let modsSummaryLabel = UILabel()
    private let deviceSpecsLabel = UILabel()
    private let settingsSummaryLabel = UILabel()
    private var testMapAvailable = true

    init(modes: [(title: String, symbol: String)], log: UIView) {
        super.init(frame: .zero)
        semanticContentAttribute = .forceLeftToRight

        let backdrop = Theme.backdrop(image: "StartBackground", darken: 0.42)
        pin(backdrop, to: self)

        setupSidebar()
        setupTopBar()
        setupPages(log: log)
        setupStoreOverlay()

        selectGame(0, notify: false)
        selectTab(0)
        selectPerf(1)
        selectOnline(0)
        selectSocial(0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !didResetScrollOnce, perfScroll.bounds.width > 0 {
            didResetScrollOnce = true
            perfScroll.setContentOffset(.zero, animated: false)
        }
    }

    private func setupSidebar() {
        sidebarAnchor.isUserInteractionEnabled = false
        sidebarAnchor.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sidebarAnchor)

        sidebar.backgroundColor = .black
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sidebar)

        let guide = safeAreaLayoutGuide
        sidebarWidth = sidebar.widthAnchor.constraint(equalToConstant: 72)

        NSLayoutConstraint.activate([
            sidebarAnchor.leadingAnchor.constraint(equalTo: leadingAnchor),
            sidebarAnchor.topAnchor.constraint(equalTo: topAnchor),
            sidebarAnchor.bottomAnchor.constraint(equalTo: bottomAnchor),
            sidebarAnchor.widthAnchor.constraint(equalToConstant: 72),

            sidebar.leadingAnchor.constraint(equalTo: leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: bottomAnchor),
            sidebarWidth
        ])

        let rBadge = UILabel()
        rBadge.text = "R★"
        rBadge.font = Theme.display(15, .black)
        rBadge.textColor = .black
        rBadge.backgroundColor = Self.gold
        rBadge.textAlignment = .center
        rBadge.layer.cornerRadius = 6
        rBadge.clipsToBounds = true
        rBadge.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(rBadge)

        let items: [(title: String, short: String)] = [
            ("جراند ثفت أوتو 5", "GTA V"),
            ("جراند ثفت أوتو أونلاين", "ONLINE"),
            ("جراند ثفت أوتو 6", "GTA VI"),
            (Self.brandName, "Rom")
        ]

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(stack)

        for (idx, item) in items.enumerated() {
            var cfg = UIButton.Configuration.filled()
            cfg.title = sidebarExpanded ? item.title : item.short
            cfg.baseBackgroundColor = UIColor(white: 1, alpha: 0.10)
            cfg.baseForegroundColor = .white
            cfg.cornerStyle = .medium
            let btn = UIButton(configuration: cfg)
            btn.titleLabel?.numberOfLines = 1
            btn.titleLabel?.lineBreakMode = .byClipping
            btn.titleLabel?.adjustsFontSizeToFitWidth = true
            btn.titleLabel?.minimumScaleFactor = 0.65
            btn.heightAnchor.constraint(equalToConstant: 36).isActive = true
            btn.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                if self.sidebarExpanded { self.toggleSidebar() }
                if idx == 3 {
                    self.showStore(true)
                } else {
                    self.showStore(false)
                    self.selectGame(idx, notify: true)
                    self.selectTab(0)
                }
            }, for: .touchUpInside)
            sidebarButtons.append(btn)
            stack.addArrangedSubview(btn)
        }

        brandLabel.text = Self.brandName
        brandLabel.font = Theme.display(13, .bold)
        brandLabel.textColor = Self.gold
        brandLabel.isHidden = true
        brandLabel.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(brandLabel)

        let toggleBtn = UIButton(type: .system)
        toggleBtn.setImage(UIImage(systemName: "sidebar.left"), for: .normal)
        toggleBtn.tintColor = .white
        toggleBtn.translatesAutoresizingMaskIntoConstraints = false
        toggleBtn.addAction(UIAction { [weak self] _ in self?.toggleSidebar() }, for: .touchUpInside)
        sidebar.addSubview(toggleBtn)

        NSLayoutConstraint.activate([
            rBadge.topAnchor.constraint(equalTo: guide.topAnchor, constant: 10),
            rBadge.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 19),
            rBadge.widthAnchor.constraint(equalToConstant: 34),
            rBadge.heightAnchor.constraint(equalToConstant: 34),

            stack.topAnchor.constraint(equalTo: rBadge.bottomAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -6),

            toggleBtn.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -10),
            toggleBtn.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 20),
            toggleBtn.widthAnchor.constraint(equalToConstant: 32),
            toggleBtn.heightAnchor.constraint(equalToConstant: 32),

            brandLabel.centerYAnchor.constraint(equalTo: toggleBtn.centerYAnchor),
            brandLabel.leadingAnchor.constraint(equalTo: toggleBtn.trailingAnchor, constant: 8)
        ])
    }

    private func toggleSidebar() {
        sidebarExpanded.toggle()
        sidebarWidth.constant = sidebarExpanded ? 195 : 72
        brandLabel.isHidden = !sidebarExpanded
        let titles = ["جراند ثفت أوتو 5", "جراند ثفت أوتو أونلاين", "جراند ثفت أوتو 6", Self.brandName]
        let shorts = ["GTA V", "ONLINE", "GTA VI", "Rom"]
        for (i, btn) in sidebarButtons.enumerated() {
            btn.configuration?.title = sidebarExpanded ? titles[i] : shorts[i]
        }
        UIView.animate(withDuration: 0.2) { self.layoutIfNeeded() }
    }

    private func selectGame(_ index: Int, notify: Bool) {
        selectedGameIndex = index
        let activeColor = (index == 2) ? Self.pink : Self.gold
        for (i, btn) in sidebarButtons.enumerated() {
            let active = (i == index)
            btn.configuration?.baseBackgroundColor = active ? activeColor : UIColor(white: 1, alpha: 0.10)
            btn.configuration?.baseForegroundColor = active ? .black : .white
        }
        if tabButtons.count > 1 {
            tabButtons[1].isHidden = (index == 2)
            if index == 2 && selectedTabIndex == 1 { selectTab(0) }
        }

        let isOnline = (index == 1)
        let isGTAVI = (index == 2)
        perfScroll.isHidden = isOnline
        onlinePanel.isHidden = !isOnline
        benchmarkButton.isHidden = (index != 0)
        onlineMetaLabel.isHidden = !isOnline
        gtaviBadgeLabel.isHidden = !isGTAVI

        switch index {
        case 0:
            heroTitleLabel.text = "GRAND THEFT AUTO V"
            heroBadgeLabel.text = "FIVE · \(Self.brandName)"
            heroBadgeLabel.textColor = Self.gold
            heroArtImage.image = UIImage(named: "CardGTAV_30") ?? UIImage(named: "StartBackground")
            topAvatar.image = UIImage(named: "CardGTAV_30") ?? UIImage(named: "StartBackground")
            if notify { onMode?(0) }
        case 1:
            heroTitleLabel.text = "GRAND THEFT AUTO ONLINE"
            heroBadgeLabel.text = "ONLINE · \(Self.brandName)"
            heroBadgeLabel.textColor = UIColor(red: 0.92, green: 0.22, blue: 0.24, alpha: 1)
            heroArtImage.image = UIImage(named: "OnlineCard_FreeRoam") ?? UIImage(named: "StartBackground")
            topAvatar.image = UIImage(named: "OnlineCard_FreeRoam") ?? UIImage(named: "StartBackground")
            if notify { onMap?(0); onMode?(1) }
        default:
            heroTitleLabel.text = "GRAND THEFT AUTO VI"
            heroBadgeLabel.text = "VI · \(Self.brandName)"
            heroBadgeLabel.textColor = Self.pink
            heroArtImage.image = UIImage(named: "CardGTAVI_30") ?? UIImage(named: "StartBackground")
            topAvatar.image = UIImage(named: "CardGTAVI_30") ?? UIImage(named: "StartBackground")
            if notify { onMode?(1); if testMapAvailable { onMap?(1) } }
        }

        let prefix = isGTAVI ? "CardGTAVI_" : "CardGTAV_"
        let suffixes = ["24", "30", "60", "720", "Custom"]
        for (i, imgView) in perfArtViews.enumerated() {
            imgView.image = UIImage(named: prefix + suffixes[i]) ?? UIImage(named: "StartBackground")
        }
        perfScroll.setContentOffset(.zero, animated: false)
    }

    private func setupTopBar() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topBar)

        filesPill.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        filesPill.layer.cornerRadius = 12
        filesPill.layer.borderWidth = 1
        filesPill.layer.borderColor = UIColor(white: 1, alpha: 0.18).cgColor
        filesPill.translatesAutoresizingMaskIntoConstraints = false
        filesPill.addAction(UIAction { [weak self] _ in self?.onFiles?() }, for: .touchUpInside)

        filesSpinner.color = Self.gold
        filesSpinner.transform = CGAffineTransform(scaleX: 0.65, y: 0.65)
        filesLabel.font = Theme.body(10.5, .semibold)
        filesLabel.textColor = .white
        filesLabel.lineBreakMode = .byTruncatingTail

        let pillStack = UIStackView(arrangedSubviews: [filesIcon, filesSpinner, filesLabel])
        pillStack.spacing = 5
        pillStack.alignment = .center
        pillStack.isUserInteractionEnabled = false
        pillStack.translatesAutoresizingMaskIntoConstraints = false
        filesPill.addSubview(pillStack)
        NSLayoutConstraint.activate([
            pillStack.leadingAnchor.constraint(equalTo: filesPill.leadingAnchor, constant: 8),
            pillStack.trailingAnchor.constraint(equalTo: filesPill.trailingAnchor, constant: -8),
            pillStack.topAnchor.constraint(equalTo: filesPill.topAnchor, constant: 4),
            pillStack.bottomAnchor.constraint(equalTo: filesPill.bottomAnchor, constant: -4),
            filesPill.widthAnchor.constraint(lessThanOrEqualToConstant: 120)
        ])
        topBar.addSubview(filesPill)

        let titles = ["الألعاب", "المودات", "البيانات وملفات الحفظ", "الإعدادات"]
        let tabsStack = UIStackView()
        tabsStack.axis = .horizontal
        tabsStack.spacing = 12
        tabsStack.alignment = .center
        tabsStack.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(tabsStack)

        for (i, t) in titles.enumerated() {
            var cfg = UIButton.Configuration.plain()
            cfg.title = t
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2)
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
                var a = a; a.font = Theme.body(12.5, .bold); return a
            }
            let btn = UIButton(configuration: cfg)
            btn.titleLabel?.adjustsFontSizeToFitWidth = true
            btn.titleLabel?.minimumScaleFactor = 0.72
            btn.setContentCompressionResistancePriority(.required, for: .horizontal)
            btn.addAction(UIAction { [weak self] _ in
                self?.showStore(false)
                self?.selectTab(i)
            }, for: .touchUpInside)
            tabButtons.append(btn)
            tabsStack.addArrangedSubview(btn)
        }

        topAvatar.contentMode = .scaleAspectFill
        topAvatar.layer.cornerRadius = 15
        topAvatar.clipsToBounds = true
        topAvatar.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(topAvatar)

        let guide = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topBar.leadingAnchor.constraint(equalTo: sidebarAnchor.trailingAnchor, constant: 10),
            topBar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            topBar.topAnchor.constraint(equalTo: guide.topAnchor, constant: 6),
            topBar.heightAnchor.constraint(equalToConstant: 34),

            filesPill.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            filesPill.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            topAvatar.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            topAvatar.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            topAvatar.widthAnchor.constraint(equalToConstant: 30),
            topAvatar.heightAnchor.constraint(equalToConstant: 30),

            tabsStack.leadingAnchor.constraint(greaterThanOrEqualTo: filesPill.trailingAnchor, constant: 8),
            tabsStack.trailingAnchor.constraint(equalTo: topAvatar.leadingAnchor, constant: -10),
            tabsStack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor)
        ])
    }

    private func selectTab(_ index: Int) {
        selectedTabIndex = index
        for (i, btn) in tabButtons.enumerated() {
            btn.configuration?.baseForegroundColor = (i == index) ? .white : UIColor(white: 1, alpha: 0.62)
        }
        gamesPage.isHidden = index != 0
        modsPage.isHidden = index != 1
        dataPage.isHidden = index != 2
        settingsPage.isHidden = index != 3

        if index == 1 { refreshMods() }
        if index == 2 { refreshData() }
        if index == 3 { refreshSettings() }
    }

    private func setupPages(log: UIView) {
        let guide = safeAreaLayoutGuide
        for page in [gamesPage, modsPage, dataPage, settingsPage] {
            page.translatesAutoresizingMaskIntoConstraints = false
            addSubview(page)
            NSLayoutConstraint.activate([
                page.leadingAnchor.constraint(equalTo: sidebarAnchor.trailingAnchor, constant: 12),
                page.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
                page.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 8),
                page.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -10)
            ])
        }
        buildGamesPage()
        buildModsPage()
        buildDataPage(log: log)
        buildSettingsPage()
    }

    private func buildGamesPage() {
        let leftCol = UIView()
        leftCol.translatesAutoresizingMaskIntoConstraints = false
        gamesPage.addSubview(leftCol)

        heroArtImage.contentMode = .scaleAspectFill
        heroArtImage.clipsToBounds = true
        heroArtImage.layer.cornerRadius = 10
        heroArtImage.layer.borderWidth = 1
        heroArtImage.layer.borderColor = UIColor(white: 1, alpha: 0.22).cgColor
        heroArtImage.translatesAutoresizingMaskIntoConstraints = false
        leftCol.addSubview(heroArtImage)

        heroTitleLabel.font = Theme.display(17, .black)
        heroTitleLabel.textColor = .white
        heroTitleLabel.adjustsFontSizeToFitWidth = true
        heroTitleLabel.minimumScaleFactor = 0.72
        heroTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        leftCol.addSubview(heroTitleLabel)

        heroBadgeLabel.font = Theme.body(11, .bold)
        heroBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        leftCol.addSubview(heroBadgeLabel)

        playButton.translatesAutoresizingMaskIntoConstraints = false
        leftCol.addSubview(playButton)

        benchmarkButton.setTitle("بدء اختبار الأداء", for: .normal)
        benchmarkButton.setTitleColor(UIColor(white: 1, alpha: 0.78), for: .normal)
        benchmarkButton.titleLabel?.font = Theme.body(11, .semibold)
        benchmarkButton.translatesAutoresizingMaskIntoConstraints = false
        benchmarkButton.addAction(UIAction { [weak self] _ in
            self?.onFiles?()
        }, for: .touchUpInside)
        leftCol.addSubview(benchmarkButton)

        onlineMetaLabel.text = "اللعب بشخصية: Player0101"
        onlineMetaLabel.font = Theme.body(11, .semibold)
        onlineMetaLabel.textColor = UIColor(white: 1, alpha: 0.85)
        onlineMetaLabel.isHidden = true
        onlineMetaLabel.translatesAutoresizingMaskIntoConstraints = false
        leftCol.addSubview(onlineMetaLabel)

        gtaviBadgeLabel.text = "قيد التطوير · نسخة تجريبية"
        gtaviBadgeLabel.font = Theme.body(11, .bold)
        gtaviBadgeLabel.textColor = Self.pink
        gtaviBadgeLabel.isHidden = true
        gtaviBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        leftCol.addSubview(gtaviBadgeLabel)

        controllerLabel.font = .monospacedDigitSystemFont(ofSize: 9.5, weight: .medium)
        controllerLabel.textColor = UIColor(white: 1, alpha: 0.55)
        controllerLabel.translatesAutoresizingMaskIntoConstraints = false
        leftCol.addSubview(controllerLabel)

        perfScroll.showsHorizontalScrollIndicator = false
        perfScroll.semanticContentAttribute = .forceLeftToRight
        perfScroll.translatesAutoresizingMaskIntoConstraints = false
        gamesPage.addSubview(perfScroll)

        perfStack.axis = .horizontal
        perfStack.spacing = 10
        perfStack.semanticContentAttribute = .forceLeftToRight
        perfStack.translatesAutoresizingMaskIntoConstraints = false
        perfScroll.addSubview(perfStack)

        let presets: [(fps: String, desc: String, badge: String?)] = [
            ("24 FPS", "توفير البطارية", nil),
            ("30 FPS", "متوازن · إكساء عالي", "موصى به"),
            ("60 FPS", "أداء عالي", nil),
            ("720p", "جودة فائقة", nil),
            ("YOUR SETTINGS", "إعدادات مخصصة", nil)
        ]

        for (i, item) in presets.enumerated() {
            let card = UIControl()
            card.clipsToBounds = true
            card.layer.cornerRadius = 6
            card.layer.borderWidth = 1.5
            card.layer.borderColor = UIColor(white: 1, alpha: 0.22).cgColor
            card.translatesAutoresizingMaskIntoConstraints = false

            let art = UIImageView()
            art.contentMode = .scaleAspectFill
            art.clipsToBounds = true
            art.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(art)
            perfArtViews.append(art)

            let shade = UIView()
            shade.backgroundColor = UIColor.black.withAlphaComponent(0.45)
            shade.isUserInteractionEnabled = false
            shade.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(shade)

            let activeTag = UILabel()
            activeTag.text = "  نشط  "
            activeTag.font = Theme.body(10, .bold)
            activeTag.backgroundColor = Self.gold
            activeTag.textColor = .black
            activeTag.layer.cornerRadius = 3
            activeTag.clipsToBounds = true
            activeTag.isHidden = true
            activeTag.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(activeTag)
            perfActiveTags.append(activeTag)

            if let bText = item.badge {
                let rec = UILabel()
                rec.text = "  \(bText)  "
                rec.font = Theme.body(10, .bold)
                rec.backgroundColor = .white
                rec.textColor = .black
                rec.layer.cornerRadius = 3
                rec.clipsToBounds = true
                rec.translatesAutoresizingMaskIntoConstraints = false
                card.addSubview(rec)
                NSLayoutConstraint.activate([
                    rec.topAnchor.constraint(equalTo: card.topAnchor, constant: 6),
                    rec.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6)
                ])
            }

            let fpsLbl = UILabel()
            fpsLbl.text = item.fps
            fpsLbl.semanticContentAttribute = .forceLeftToRight
            fpsLbl.font = Theme.display(20, .black)
            fpsLbl.textColor = .white
            fpsLbl.adjustsFontSizeToFitWidth = true
            fpsLbl.minimumScaleFactor = 0.65
            fpsLbl.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(fpsLbl)

            let descLbl = UILabel()
            descLbl.text = item.desc
            descLbl.font = Theme.body(10.5, .semibold)
            descLbl.textColor = UIColor(white: 1, alpha: 0.9)
            descLbl.backgroundColor = UIColor.black.withAlphaComponent(0.75)
            descLbl.textAlignment = .center
            descLbl.adjustsFontSizeToFitWidth = true
            descLbl.minimumScaleFactor = 0.72
            descLbl.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(descLbl)

            NSLayoutConstraint.activate([
                card.widthAnchor.constraint(equalToConstant: i == 1 ? 195 : 132),
                art.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                art.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                art.topAnchor.constraint(equalTo: card.topAnchor),
                art.bottomAnchor.constraint(equalTo: card.bottomAnchor),

                shade.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                shade.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                shade.topAnchor.constraint(equalTo: card.topAnchor),
                shade.bottomAnchor.constraint(equalTo: card.bottomAnchor),

                activeTag.topAnchor.constraint(equalTo: card.topAnchor, constant: 6),
                activeTag.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 6),

                descLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                descLbl.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                descLbl.bottomAnchor.constraint(equalTo: card.bottomAnchor),
                descLbl.heightAnchor.constraint(equalToConstant: 26),

                fpsLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
                fpsLbl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
                fpsLbl.bottomAnchor.constraint(equalTo: descLbl.topAnchor, constant: -4)
            ])

            card.addAction(UIAction { [weak self] _ in self?.selectPerf(i) }, for: .touchUpInside)
            perfCards.append(card)
            perfStack.addArrangedSubview(card)
        }

        onlinePanel.isHidden = true
        onlinePanel.translatesAutoresizingMaskIntoConstraints = false
        gamesPage.addSubview(onlinePanel)

        let onlineRow = UIStackView()
        onlineRow.axis = .horizontal
        onlineRow.spacing = 8
        onlineRow.distribution = .fillEqually
        onlineRow.translatesAutoresizingMaskIntoConstraints = false
        onlinePanel.addSubview(onlineRow)

        let onlineModes: [(title: String, img: String)] = [
            ("تجول حر: بمفردك", "OnlineCard_FreeRoam"),
            ("استضافة: مع أصدقائك", "OnlineCard_Host"),
            ("الانضمام إلى جلسة", "OnlineCard_Join")
        ]
        for (i, m) in onlineModes.enumerated() {
            let card = UIControl()
            card.clipsToBounds = true
            card.layer.cornerRadius = 6
            card.layer.borderWidth = 1.5
            card.layer.borderColor = UIColor(white: 1, alpha: 0.22).cgColor

            let img = UIImageView(image: UIImage(named: m.img) ?? UIImage(named: "StartBackground"))
            img.contentMode = .scaleAspectFill
            img.clipsToBounds = true
            pin(img, to: card)

            let lbl = UILabel()
            lbl.text = m.title
            lbl.font = Theme.body(11, .bold)
            lbl.textColor = .white
            lbl.backgroundColor = UIColor.black.withAlphaComponent(0.8)
            lbl.textAlignment = .center
            lbl.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                lbl.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                lbl.bottomAnchor.constraint(equalTo: card.bottomAnchor),
                lbl.heightAnchor.constraint(equalToConstant: 26)
            ])
            card.addAction(UIAction { [weak self] _ in self?.selectOnline(i) }, for: .touchUpInside)
            onlineCards.append(card)
            onlineRow.addArrangedSubview(card)
        }

        onlineInfoLabel.text = "اختر وضع اللعب الجماعي أو التجوال الحر في مدينة لوس سانتوس."
        onlineInfoLabel.font = Theme.body(11, .medium)
        onlineInfoLabel.textColor = .white
        onlineInfoLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        onlineInfoLabel.textAlignment = .right
        onlineInfoLabel.numberOfLines = 2
        onlineInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        onlinePanel.addSubview(onlineInfoLabel)

        NSLayoutConstraint.activate([
            leftCol.leadingAnchor.constraint(equalTo: gamesPage.leadingAnchor),
            leftCol.topAnchor.constraint(equalTo: gamesPage.topAnchor),
            leftCol.bottomAnchor.constraint(equalTo: gamesPage.bottomAnchor),
            leftCol.widthAnchor.constraint(equalTo: gamesPage.widthAnchor, multiplier: 0.28),

            heroArtImage.topAnchor.constraint(equalTo: leftCol.topAnchor),
            heroArtImage.leadingAnchor.constraint(equalTo: leftCol.leadingAnchor),
            heroArtImage.trailingAnchor.constraint(equalTo: leftCol.trailingAnchor),
            heroArtImage.heightAnchor.constraint(equalTo: leftCol.heightAnchor, multiplier: 0.36),

            heroTitleLabel.topAnchor.constraint(equalTo: heroArtImage.bottomAnchor, constant: 6),
            heroTitleLabel.leadingAnchor.constraint(equalTo: leftCol.leadingAnchor),
            heroTitleLabel.trailingAnchor.constraint(equalTo: leftCol.trailingAnchor),

            heroBadgeLabel.topAnchor.constraint(equalTo: heroTitleLabel.bottomAnchor, constant: 2),
            heroBadgeLabel.leadingAnchor.constraint(equalTo: leftCol.leadingAnchor),

            playButton.topAnchor.constraint(equalTo: heroBadgeLabel.bottomAnchor, constant: 8),
            playButton.leadingAnchor.constraint(equalTo: leftCol.leadingAnchor),
            playButton.trailingAnchor.constraint(equalTo: leftCol.trailingAnchor),
            playButton.heightAnchor.constraint(equalToConstant: 40),

            benchmarkButton.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 4),
            benchmarkButton.centerXAnchor.constraint(equalTo: leftCol.centerXAnchor),

            onlineMetaLabel.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 4),
            onlineMetaLabel.centerXAnchor.constraint(equalTo: leftCol.centerXAnchor),

            gtaviBadgeLabel.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 4),
            gtaviBadgeLabel.centerXAnchor.constraint(equalTo: leftCol.centerXAnchor),

            controllerLabel.bottomAnchor.constraint(equalTo: leftCol.bottomAnchor),
            controllerLabel.leadingAnchor.constraint(equalTo: leftCol.leadingAnchor),

            perfScroll.leadingAnchor.constraint(equalTo: leftCol.trailingAnchor, constant: 12),
            perfScroll.trailingAnchor.constraint(equalTo: gamesPage.trailingAnchor),
            perfScroll.topAnchor.constraint(equalTo: gamesPage.topAnchor, constant: 4),
            perfScroll.bottomAnchor.constraint(equalTo: gamesPage.bottomAnchor, constant: -4),

            perfStack.leadingAnchor.constraint(equalTo: perfScroll.contentLayoutGuide.leadingAnchor),
            perfStack.trailingAnchor.constraint(equalTo: perfScroll.contentLayoutGuide.trailingAnchor),
            perfStack.topAnchor.constraint(equalTo: perfScroll.contentLayoutGuide.topAnchor),
            perfStack.bottomAnchor.constraint(equalTo: perfScroll.contentLayoutGuide.bottomAnchor),
            perfStack.heightAnchor.constraint(equalTo: perfScroll.frameLayoutGuide.heightAnchor),

            onlinePanel.leadingAnchor.constraint(equalTo: leftCol.trailingAnchor, constant: 12),
            onlinePanel.trailingAnchor.constraint(equalTo: gamesPage.trailingAnchor),
            onlinePanel.topAnchor.constraint(equalTo: gamesPage.topAnchor, constant: 4),
            onlinePanel.bottomAnchor.constraint(equalTo: gamesPage.bottomAnchor, constant: -4),

            onlineRow.leadingAnchor.constraint(equalTo: onlinePanel.leadingAnchor),
            onlineRow.trailingAnchor.constraint(equalTo: onlinePanel.trailingAnchor),
            onlineRow.topAnchor.constraint(equalTo: onlinePanel.topAnchor),
            onlineRow.bottomAnchor.constraint(equalTo: onlineInfoLabel.topAnchor, constant: -8),

            onlineInfoLabel.leadingAnchor.constraint(equalTo: onlinePanel.leadingAnchor),
            onlineInfoLabel.trailingAnchor.constraint(equalTo: onlinePanel.trailingAnchor),
            onlineInfoLabel.bottomAnchor.constraint(equalTo: onlinePanel.bottomAnchor),
            onlineInfoLabel.heightAnchor.constraint(equalToConstant: 42)
        ])
    }

    private func selectPerf(_ index: Int) {
        selectedPerfIndex = index
        let activeColor = (selectedGameIndex == 2) ? Self.pink : Self.gold
        for (i, card) in perfCards.enumerated() {
            let active = (i == index)
            card.layer.borderColor = (active ? activeColor : UIColor(white: 1, alpha: 0.22)).cgColor
            card.layer.borderWidth = active ? 2.4 : 1.5
            perfActiveTags[i].isHidden = !active
            perfActiveTags[i].backgroundColor = activeColor
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

    private func selectOnline(_ index: Int) {
        selectedOnlineIndex = index
        for (i, card) in onlineCards.enumerated() {
            card.layer.borderColor = (i == index ? Self.gold : UIColor(white: 1, alpha: 0.22)).cgColor
            card.layer.borderWidth = (i == index) ? 2.4 : 1.5
        }
        let texts = [
            "تجول حر: استكشف الخريطة بمفردك مع حرية كاملة.",
            "استضافة: أنشئ جلسة وادعُ أصدقاءك للانضمام إليك.",
            "الانضمام إلى جلسة: ادخل إلى جلسة متاحة أو رمز دعوة."
        ]
        onlineInfoLabel.text = texts[index]
    }

    private func setupStoreOverlay() {
        storeOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        storeOverlay.isHidden = true
        storeOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(storeOverlay)

        let title = UILabel()
        title.text = "\(Self.brandName) - تابعنا على مواقع التواصل"
        title.font = Theme.display(16, .bold)
        title.textColor = .white
        title.translatesAutoresizingMaskIntoConstraints = false
        storeOverlay.addSubview(title)

        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("✕ إغلاق", for: .normal)
        closeBtn.setTitleColor(.white, for: .normal)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addAction(UIAction { [weak self] _ in self?.showStore(false) }, for: .touchUpInside)
        storeOverlay.addSubview(closeBtn)

        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 12
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        storeOverlay.addSubview(row)

        for (i, item) in socialItems.enumerated() {
            let card = UIControl()
            card.backgroundColor = UIColor(white: 1, alpha: 0.08)
            card.layer.cornerRadius = 10
            card.layer.borderWidth = 1.5
            card.layer.borderColor = UIColor(white: 1, alpha: 0.2).cgColor

            let lbl = UILabel()
            lbl.text = item.title
            lbl.font = Theme.body(13, .bold)
            lbl.textColor = .white
            lbl.textAlignment = .center
            lbl.adjustsFontSizeToFitWidth = true
            lbl.minimumScaleFactor = 0.75
            lbl.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 6),
                lbl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6),
                lbl.centerYAnchor.constraint(equalTo: card.centerYAnchor)
            ])
            card.addAction(UIAction { [weak self] _ in self?.selectSocial(i) }, for: .touchUpInside)
            socialCards.append(card)
            row.addArrangedSubview(card)
        }

        let followBtn = Theme.primaryButton("متابعة")
        followBtn.translatesAutoresizingMaskIntoConstraints = false
        followBtn.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if let url = URL(string: self.socialItems[self.selectedSocialIndex].url) {
                UIApplication.shared.open(url)
            }
        }, for: .touchUpInside)
        storeOverlay.addSubview(followBtn)

        let guide = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            storeOverlay.leadingAnchor.constraint(equalTo: sidebarAnchor.trailingAnchor),
            storeOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            storeOverlay.topAnchor.constraint(equalTo: topAnchor),
            storeOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            title.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            title.centerXAnchor.constraint(equalTo: storeOverlay.centerXAnchor),

            closeBtn.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -14),

            row.centerXAnchor.constraint(equalTo: storeOverlay.centerXAnchor),
            row.centerYAnchor.constraint(equalTo: storeOverlay.centerYAnchor, constant: -10),
            row.widthAnchor.constraint(equalTo: storeOverlay.widthAnchor, multiplier: 0.78),
            row.heightAnchor.constraint(equalTo: storeOverlay.heightAnchor, multiplier: 0.45),

            followBtn.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 12),
            followBtn.centerXAnchor.constraint(equalTo: storeOverlay.centerXAnchor),
            followBtn.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func showStore(_ visible: Bool) {
        storeOverlay.isHidden = !visible
        if visible {
            bringSubviewToFront(storeOverlay)
            bringSubviewToFront(sidebar)
        }
    }

    private func selectSocial(_ index: Int) {
        selectedSocialIndex = index
        for (i, card) in socialCards.enumerated() {
            card.layer.borderColor = (i == index ? Self.gold : UIColor(white: 1, alpha: 0.2)).cgColor
            card.layer.borderWidth = (i == index) ? 2.4 : 1.5
        }
    }

    private func buildModsPage() {
        modsSummaryLabel.font = Theme.body(14, .semibold)
        modsSummaryLabel.textColor = .white
        modsSummaryLabel.textAlignment = .right
        modsSummaryLabel.numberOfLines = 3
        modsSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        modsPage.addSubview(modsSummaryLabel)

        let btn = Theme.primaryButton("إدارة المودات", symbol: "shippingbox.fill")
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addAction(UIAction { [weak self] _ in
            if let action = self?.onOpenMods { action() }
            else { self?.settingsButton.sendActions(for: .touchUpInside) }
        }, for: .touchUpInside)
        modsPage.addSubview(btn)

        NSLayoutConstraint.activate([
            modsSummaryLabel.topAnchor.constraint(equalTo: modsPage.topAnchor, constant: 20),
            modsSummaryLabel.leadingAnchor.constraint(equalTo: modsPage.leadingAnchor, constant: 16),
            modsSummaryLabel.trailingAnchor.constraint(equalTo: modsPage.trailingAnchor, constant: -16),

            btn.topAnchor.constraint(equalTo: modsSummaryLabel.bottomAnchor, constant: 16),
            btn.trailingAnchor.constraint(equalTo: modsPage.trailingAnchor, constant: -16)
        ])
    }

    private func refreshMods() {
        let count = ModInstaller.installed().count
        modsSummaryLabel.text = "المودات المثبتة: \(count)"
    }

    private func buildDataPage(log: UIView) {
        deviceSpecsLabel.font = .monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
        deviceSpecsLabel.textColor = .white
        deviceSpecsLabel.textAlignment = .right
        deviceSpecsLabel.numberOfLines = 4
        deviceSpecsLabel.translatesAutoresizingMaskIntoConstraints = false
        dataPage.addSubview(deviceSpecsLabel)

        log.isHidden = false
        log.translatesAutoresizingMaskIntoConstraints = false
        dataPage.addSubview(log)

        NSLayoutConstraint.activate([
            deviceSpecsLabel.topAnchor.constraint(equalTo: dataPage.topAnchor, constant: 8),
            deviceSpecsLabel.leadingAnchor.constraint(equalTo: dataPage.leadingAnchor, constant: 8),
            deviceSpecsLabel.trailingAnchor.constraint(equalTo: dataPage.trailingAnchor, constant: -8),

            log.topAnchor.constraint(equalTo: deviceSpecsLabel.bottomAnchor, constant: 8),
            log.leadingAnchor.constraint(equalTo: dataPage.leadingAnchor, constant: 8),
            log.trailingAnchor.constraint(equalTo: dataPage.trailingAnchor, constant: -8),
            log.bottomAnchor.constraint(equalTo: dataPage.bottomAnchor, constant: -8)
        ])
    }

    private func refreshData() {
        deviceSpecsLabel.text = "iOS \(UIDevice.current.systemVersion) · ذاكرة: \(GameSettings.shared.tier.memoryLimitMB) MB"
    }

    private func buildSettingsPage() {
        settingsSummaryLabel.font = Theme.body(14, .semibold)
        settingsSummaryLabel.textColor = .white
        settingsSummaryLabel.textAlignment = .right
        settingsSummaryLabel.numberOfLines = 3
        settingsSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        settingsPage.addSubview(settingsSummaryLabel)

        let openBtn = Theme.primaryButton("فتح الإعدادات الكاملة", symbol: "slider.horizontal.3")
        openBtn.translatesAutoresizingMaskIntoConstraints = false
        openBtn.addAction(UIAction { [weak self] _ in self?.settingsButton.sendActions(for: .touchUpInside) }, for: .touchUpInside)
        settingsPage.addSubview(openBtn)

        NSLayoutConstraint.activate([
            settingsSummaryLabel.topAnchor.constraint(equalTo: settingsPage.topAnchor, constant: 20),
            settingsSummaryLabel.leadingAnchor.constraint(equalTo: settingsPage.leadingAnchor, constant: 16),
            settingsSummaryLabel.trailingAnchor.constraint(equalTo: settingsPage.trailingAnchor, constant: -16),

            openBtn.topAnchor.constraint(equalTo: settingsSummaryLabel.bottomAnchor, constant: 16),
            openBtn.trailingAnchor.constraint(equalTo: settingsPage.trailingAnchor, constant: -16)
        ])
    }

    private func refreshSettings() {
        let s = GameSettings.shared
        settingsSummaryLabel.text = "الجودة: \(s.graphicsPreset.title) · الإطارات: \(GameSettings.frameRateTitle(s.frameRateCap))"
    }

    func refreshLanguage() {
        playButton.configuration?.title = "تشغيل اللعبة"
    }

    func setFiles(_ state: FilesState, title: String, detail: String) {
        filesLabel.text = title
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
        self.testMapAvailable = testMapAvailable
        if selectedGameIndex == 2 { selectGame(2, notify: false) }
    }

    func setMode(_ index: Int?, detail: String, enabled: Bool) {
        if let index, index != selectedGameIndex, selectedGameIndex != 2 {
            selectGame(index, notify: false)
        }
    }

    private static func makePlayButton() -> UIButton {
        var cfg = UIButton.Configuration.filled()
        cfg.title = "تشغيل اللعبة"
        cfg.image = UIImage(systemName: "play.fill")
        cfg.imagePadding = 8
        cfg.cornerStyle = .medium
        cfg.baseForegroundColor = .black
        cfg.background.backgroundColor = gold
        return UIButton(configuration: cfg)
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
