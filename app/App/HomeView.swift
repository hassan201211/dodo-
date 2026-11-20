import UIKit

/// Rockstar Games Launcher / Soon Store styled start screen:
/// - Collapsible left black sidebar (GTA V, GTA Online, GTA VI, Soon Store)
/// - Top navigation tabs (الألعاب، المودات، البيانات وملفات الحفظ، الإعدادات)
/// - GTA V & GTA VI horizontal scrollable performance preset cards (24, 30, 60, 720p, YOUR SETTINGS)
/// - GTA Online 3-mode cards (تجول حر، استضافة، الانضمام إلى جلسة لعب) + session invite controls
/// - Soon Store social overlay (تيليجرام، انستغرام، تيك توك)
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

    // MARK: - Public Controls & Hooks (NativePortViewController)

    let playButton = HomeView.makeRockstarPlayButton()
    let settingsButton = Theme.glassButton("الإعدادات", symbol: "gearshape.fill")
    let layoutButton = Theme.glassButton("تخطيط الأزرار", symbol: "hand.tap.fill")
    let telegramButton = Theme.glassButton("تيليجرام", symbol: "paperplane.fill")
    let preloadLabel = UILabel()
    let controllerLabel = UILabel()

    var onFiles: (() -> Void)?
    var onMode: ((Int) -> Void)?
    var onMap: ((Int) -> Void)?
    var onOpenMods: (() -> Void)?
    var onImportZip: (() -> Void)?

    // MARK: - Constants & Colors

    private static let gold = UIColor(red: 0.97, green: 0.67, blue: 0.10, alpha: 1)
    private static let vicePink = UIColor(red: 0.91, green: 0.29, blue: 0.56, alpha: 1)
    private static let viceOrange = UIColor(red: 0.98, green: 0.57, blue: 0.27, alpha: 1)
    private static let onlineRed = UIColor(red: 0.89, green: 0.14, blue: 0.16, alpha: 1)

    // Edit your store links here anytime
    private let socialItems: [(title: String, url: String, kind: SocialCard.Kind)] = [
        ("تيليجرام سون", "https://t.me/fivestarport", .telegram),
        ("انستغرام سون", "https://instagram.com", .instagram),
        ("تيك توك سون", "https://tiktok.com", .tiktok)
    ]

    // MARK: - Sidebar

    private let sidebar = UIView()
    private var sidebarWidthConstraint: NSLayoutConstraint!
    private var sidebarExpanded = false
    private var sidebarButtons: [LauncherSidebarItem] = []
    private let sidebarFooterLabel = UILabel()
    private var selectedGameIndex = 0 // 0: GTA V, 1: GTA Online, 2: GTA VI

    // MARK: - Top Bar

    private let topBar = UIView()
    private var topTabButtons: [UIButton] = []
    private let topGameAvatar = UIImageView()
    private let filesPill = UIControl()
    private let filesDot = UIImageView()
    private let filesSpinner = UIActivityIndicatorView(style: .medium)
    private let filesPillLabel = UILabel()
    private var selectedTabIndex = 0

    // MARK: - Pages

    private let gamesPage = UIView()
    private let modsPage = UIView()
    private let dataPage = UIView()
    private let settingsPage = UIView()
    private let storeOverlay = UIView()

    // MARK: - Games Page (Left Hero + Right Carousel / Online)

    private let heroLogoView = GameLogoBadgeView()
    private let installGTAVIButton = HomeView.makeWhiteActionButton(title: "تثبيت", symbol: "arrow.down.circle.fill")
    private let benchmarkButton = UIButton(type: .system)

    private let onlineMetaStack = UIStackView()
    private let onlinePlayerLabel = UILabel()
    private let onlineCustomizeButton = UIButton(type: .system)

    private let gtaviMetaStack = UIStackView()

    private let perfContainer = UIView()
    private let perfScrollView = UIScrollView()
    private let perfCardsStack = UIStackView()
    private let perfScrollArrow = UIButton(type: .system)
    private var perfCards: [LauncherPerfCard] = []
    private var selectedPerfIndex = 1 // 30 FPS Balanced default

    private let onlineContainer = UIView()
    private var onlineModeCards: [OnlineModeCard] = []
    private var selectedOnlineMode = 0
    private let onlineInfoBox = UIView()
    private let onlineInfoLabel = UILabel()
    private let onlineJoinBox = UIView()
    private let onlineStatusLabel = UILabel()

    // MARK: - Store Overlay

    private var socialCards: [SocialCard] = []
    private var selectedSocialIndex = 0

    // MARK: - Secondary Pages

    private let modsSummaryLabel = UILabel()
    private let modsListStack = UIStackView()
    private let deviceSpecsLabel = UILabel()
    private var saveSlotButtons: [UIButton] = []
    private let settingsLangLabel = UILabel()
    private let settingsPerfLabel = UILabel()

    // MARK: - Toast

    private let toastBanner = UIView()
    private let toastLabel = UILabel()
    private var toastHideWork: DispatchWorkItem?

    private var testMapAvailable = true
    private var playerName: String {
        get { UserDefaults.standard.string(forKey: "launcherPlayerName") ?? "Player0101" }
        set { UserDefaults.standard.set(newValue, forKey: "launcherPlayerName") }
    }

    // MARK: - Init

    init(modes: [(title: String, symbol: String)], log: UIView) {
        super.init(frame: .zero)
        // Lock layout direction LTR so the black sidebar stays on the LEFT and cards on the RIGHT,
        // matching the Rockstar Launcher design even on Arabic iOS.
        semanticContentAttribute = .forceLeftToRight

        let backdrop = Theme.backdrop(image: "StartBackground", darken: 0.42)
        pin(backdrop, to: self)

        setupSidebar()
        setupTopBar()
        setupPages(log: log)
        setupStoreOverlay()
        setupToastBanner()

        selectSidebarGame(0, notify: false)
        selectTopTab(0)
        applyPerformancePreset(1, showToast: false)
        selectOnlineMode(0)
        selectSocialCard(0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: - Left Collapsible Black Sidebar

    private func setupSidebar() {
        sidebar.backgroundColor = .black
        sidebar.semanticContentAttribute = .forceLeftToRight
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sidebar)

        let guide = safeAreaLayoutGuide
        sidebarWidthConstraint = sidebar.widthAnchor.constraint(equalToConstant: 66)
        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: bottomAnchor),
            sidebarWidthConstraint
        ])

        // Rockstar R★ Badge
        let rBadge = UILabel()
        rBadge.text = "R★"
        rBadge.font = Theme.display(17, .black)
        rBadge.textColor = .black
        rBadge.backgroundColor = Self.gold
        rBadge.textAlignment = .center
        rBadge.layer.cornerRadius = 6
        rBadge.clipsToBounds = true
        rBadge.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(rBadge)

        let items: [(title: String, kind: LauncherSidebarItem.IconKind)] = [
            ("جراند ثفت أوتو 5", .gtaV),
            ("جراند ثفت أوتو أونلاين", .gtaOnline),
            ("جراند ثفت أوتو 6", .gtaVI),
            ("سون ستور", .store)
        ]

        let navStack = UIStackView()
        navStack.axis = .vertical
        navStack.spacing = 14
        navStack.semanticContentAttribute = .forceLeftToRight
        navStack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(navStack)

        for (idx, item) in items.enumerated() {
            let btn = LauncherSidebarItem(title: item.title, kind: item.kind)
            btn.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                if idx == 3 {
                    self.showStoreOverlay(true)
                } else {
                    self.showStoreOverlay(false)
                    self.selectSidebarGame(idx, notify: true)
                    self.selectTopTab(0)
                }
            }, for: .touchUpInside)
            sidebarButtons.append(btn)
            navStack.addArrangedSubview(btn)
        }

        // Brand footer text (visible when sidebar expands)
        sidebarFooterLabel.text = "ipasoon"
        sidebarFooterLabel.font = Theme.body(13, .medium)
        sidebarFooterLabel.textColor = UIColor(white: 1, alpha: 0.72)
        sidebarFooterLabel.textAlignment = .center
        sidebarFooterLabel.isHidden = true
        sidebarFooterLabel.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(sidebarFooterLabel)

        // Bottom Sidebar Expand/Collapse Button
        let toggleBtn = UIButton(type: .system)
        toggleBtn.setImage(UIImage(systemName: "sidebar.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)), for: .normal)
        toggleBtn.tintColor = UIColor(white: 1, alpha: 0.78)
        toggleBtn.translatesAutoresizingMaskIntoConstraints = false
        toggleBtn.addAction(UIAction { [weak self] _ in self?.toggleSidebar() }, for: .touchUpInside)
        sidebar.addSubview(toggleBtn)

        NSLayoutConstraint.activate([
            rBadge.topAnchor.constraint(equalTo: guide.topAnchor, constant: 14),
            rBadge.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 16),
            rBadge.widthAnchor.constraint(equalToConstant: 34),
            rBadge.heightAnchor.constraint(equalToConstant: 34),

            navStack.topAnchor.constraint(equalTo: rBadge.bottomAnchor, constant: 30),
            navStack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            navStack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),

            toggleBtn.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -14),
            toggleBtn.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 18),
            toggleBtn.widthAnchor.constraint(equalToConstant: 30),
            toggleBtn.heightAnchor.constraint(equalToConstant: 30),

            sidebarFooterLabel.bottomAnchor.constraint(equalTo: toggleBtn.topAnchor, constant: -18),
            sidebarFooterLabel.centerXAnchor.constraint(equalTo: sidebar.centerXAnchor)
        ])
    }

    private func toggleSidebar() {
        sidebarExpanded.toggle()
        sidebarWidthConstraint.constant = sidebarExpanded ? 210 : 66
        sidebarFooterLabel.isHidden = !sidebarExpanded
        for btn in sidebarButtons { btn.setExpanded(sidebarExpanded) }
        UIView.animate(withDuration: 0.24, delay: 0, options: .curveEaseInOut) {
            self.layoutIfNeeded()
        }
    }

    private func selectSidebarGame(_ index: Int, notify: Bool) {
        selectedGameIndex = index
        let isGTAVI = (index == 2)
        let isOnline = (index == 1)

        for (i, btn) in sidebarButtons.enumerated() {
            btn.accentColor = (i == 2) ? Self.vicePink : Self.gold
            btn.isSelected = (i == index)
        }

        // Update top circular game emblem & Mods tab visibility (hidden on GTA VI like reference)
        topGameAvatar.image = LauncherSidebarItem.makeIcon(for: index == 0 ? .gtaV : index == 1 ? .gtaOnline : .gtaVI)
        if topTabButtons.count > 1 {
            topTabButtons[1].isHidden = isGTAVI
            if isGTAVI && selectedTabIndex == 1 { selectTopTab(0) }
        }

        // Left hero column updates
        heroLogoView.setGame(index)
        playButton.isHidden = isGTAVI && !testMapAvailable
        installGTAVIButton.isHidden = !(isGTAVI && !testMapAvailable)

        benchmarkButton.isHidden = (index != 0)
        onlineMetaStack.isHidden = !isOnline
        gtaviMetaStack.isHidden = !isGTAVI

        // Right area switches between Performance Cards (GTA V / VI) and 3-card Online selector
        perfContainer.isHidden = isOnline
        onlineContainer.isHidden = !isOnline

        // Refresh card theme (Gold for GTA V, Vice Pink for GTA VI)
        for (i, card) in perfCards.enumerated() {
            card.setTheme(isGTAVI: isGTAVI, index: i)
        }
        applyPerformancePreset(selectedPerfIndex, showToast: false)

        if notify {
            switch index {
            case 0:
                onMode?(0)
                showRockstarToast("تم اختيار جراند ثفت أوتو 5")
            case 1:
                onMap?(0)
                onMode?(1)
                showRockstarToast("تم اختيار جراند ثفت أوتو أونلاين")
            default:
                onMode?(1)
                if testMapAvailable { onMap?(1) }
                showRockstarToast("تم اختيار جراند ثفت أوتو 6 (نسخة تجريبية)")
            }
        }
    }

    // MARK: - Top Navigation Bar

    private func setupTopBar() {
        topBar.semanticContentAttribute = .forceLeftToRight
        topBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topBar)

        // Compact files status pill on the left side of topBar
        filesPill.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        filesPill.layer.cornerRadius = 14
        filesPill.layer.borderWidth = 1
        filesPill.layer.borderColor = UIColor(white: 1, alpha: 0.16).cgColor
        filesPill.translatesAutoresizingMaskIntoConstraints = false
        filesPill.addAction(UIAction { [weak self] _ in self?.onFiles?() }, for: .touchUpInside)

        filesDot.contentMode = .scaleAspectFit
        filesDot.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        filesSpinner.color = Self.gold
        filesSpinner.transform = CGAffineTransform(scaleX: 0.72, y: 0.72)

        filesPillLabel.font = Theme.body(11, .semibold)
        filesPillLabel.textColor = UIColor(white: 1, alpha: 0.9)
        filesPillLabel.lineBreakMode = .byTruncatingTail

        let dotBox = UIView()
        dotBox.translatesAutoresizingMaskIntoConstraints = false
        dotBox.widthAnchor.constraint(equalToConstant: 16).isActive = true
        dotBox.heightAnchor.constraint(equalToConstant: 16).isActive = true
        for v in [filesDot, filesSpinner] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            dotBox.addSubview(v)
            NSLayoutConstraint.activate([
                v.centerXAnchor.constraint(equalTo: dotBox.centerXAnchor),
                v.centerYAnchor.constraint(equalTo: dotBox.centerYAnchor)
            ])
        }

        let pillRow = UIStackView(arrangedSubviews: [dotBox, filesPillLabel])
        pillRow.spacing = 6
        pillRow.alignment = .center
        pillRow.isUserInteractionEnabled = false
        pillRow.translatesAutoresizingMaskIntoConstraints = false
        filesPill.addSubview(pillRow)
        NSLayoutConstraint.activate([
            pillRow.leadingAnchor.constraint(equalTo: filesPill.leadingAnchor, constant: 10),
            pillRow.trailingAnchor.constraint(equalTo: filesPill.trailingAnchor, constant: -10),
            pillRow.topAnchor.constraint(equalTo: filesPill.topAnchor, constant: 5),
            pillRow.bottomAnchor.constraint(equalTo: filesPill.bottomAnchor, constant: -5),
            filesPill.widthAnchor.constraint(lessThanOrEqualToConstant: 195)
        ])
        topBar.addSubview(filesPill)

        // Top Navigation Tabs matching reference order (left -> right):
        // الألعاب   المودات   البيانات وملفات الحفظ   الإعدادات
        let tabTitles = ["الألعاب", "المودات", "البيانات وملفات الحفظ", "الإعدادات"]
        let tabsStack = UIStackView()
        tabsStack.axis = .horizontal
        tabsStack.spacing = 22
        tabsStack.alignment = .center
        tabsStack.semanticContentAttribute = .forceLeftToRight
        tabsStack.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(tabsStack)

        for (i, title) in tabTitles.enumerated() {
            var cfg = UIButton.Configuration.plain()
            cfg.title = title
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4)
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attr in
                var a = attr
                a.font = Theme.body(14, .bold)
                return a
            }
            let btn = UIButton(configuration: cfg)
            btn.addAction(UIAction { [weak self] _ in
                self?.showStoreOverlay(false)
                self?.selectTopTab(i)
            }, for: .touchUpInside)
            topTabButtons.append(btn)
            tabsStack.addArrangedSubview(btn)
        }

        // Top-right circular game emblem
        topGameAvatar.contentMode = .scaleAspectFill
        topGameAvatar.layer.cornerRadius = 17
        topGameAvatar.layer.borderWidth = 1.5
        topGameAvatar.layer.borderColor = UIColor(white: 1, alpha: 0.45).cgColor
        topGameAvatar.clipsToBounds = true
        topGameAvatar.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(topGameAvatar)

        let guide = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topBar.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 14),
            topBar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            topBar.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            topBar.heightAnchor.constraint(equalToConstant: 40),

            filesPill.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            filesPill.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            topGameAvatar.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            topGameAvatar.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            topGameAvatar.widthAnchor.constraint(equalToConstant: 34),
            topGameAvatar.heightAnchor.constraint(equalToConstant: 34),

            tabsStack.trailingAnchor.constraint(equalTo: topGameAvatar.leadingAnchor, constant: -24),
            tabsStack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor)
        ])
    }

    private func selectTopTab(_ index: Int) {
        selectedTabIndex = index
        for (i, btn) in topTabButtons.enumerated() {
            btn.configuration?.baseForegroundColor = (i == index) ? .white : UIColor(white: 1, alpha: 0.62)
        }
        gamesPage.isHidden = index != 0
        modsPage.isHidden = index != 1
        dataPage.isHidden = index != 2
        settingsPage.isHidden = index != 3

        if index == 1 { refreshModsSummary() }
        if index == 2 { refreshDeviceTelemetry() }
        if index == 3 { refreshSettingsSummary() }
    }

    // MARK: - Pages Container

    private func setupPages(log: UIView) {
        let guide = safeAreaLayoutGuide
        for page in [gamesPage, modsPage, dataPage, settingsPage] {
            page.semanticContentAttribute = .forceLeftToRight
            page.translatesAutoresizingMaskIntoConstraints = false
            addSubview(page)
            NSLayoutConstraint.activate([
                page.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 16),
                page.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -14),
                page.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 10),
                page.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -12)
            ])
        }

        buildGamesPage()
        buildModsPage()
        buildDataPage(log: log)
        buildSettingsPage()
    }

    // MARK: - Games Page (Exact Rockstar Reference Layout)

    private func buildGamesPage() {
        // Left Hero Column (Logo + Play/Install Button + Meta captions)
        let heroCol = UIView()
        heroCol.semanticContentAttribute = .forceLeftToRight
        heroCol.translatesAutoresizingMaskIntoConstraints = false
        gamesPage.addSubview(heroCol)

        heroLogoView.translatesAutoresizingMaskIntoConstraints = false
        heroCol.addSubview(heroLogoView)

        playButton.translatesAutoresizingMaskIntoConstraints = false
        heroCol.addSubview(playButton)

        installGTAVIButton.translatesAutoresizingMaskIntoConstraints = false
        installGTAVIButton.isHidden = true
        installGTAVIButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onImportZip?()
            self.showRockstarToast("اختر ملفات جراند 6 (.zip) للتثبيت")
        }, for: .touchUpInside)
        heroCol.addSubview(installGTAVIButton)

        // GTA V Benchmark Link under Play button
        var benchCfg = UIButton.Configuration.plain()
        benchCfg.title = "بدء اختبار الأداء"
        benchCfg.image = UIImage(systemName: "chart.bar.doc.horizontal", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
        benchCfg.imagePadding = 5
        benchCfg.imagePlacement = .leading
        benchCfg.baseForegroundColor = UIColor(white: 1, alpha: 0.78)
        benchCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a; a.font = Theme.body(12, .semibold); return a
        }
        benchmarkButton.configuration = benchCfg
        benchmarkButton.translatesAutoresizingMaskIntoConstraints = false
        benchmarkButton.addAction(UIAction { [weak self] _ in
            self?.showRockstarToast("اضغط تشغيل اللعبة لبدء قياس الإطارات والأداء")
        }, for: .touchUpInside)
        heroCol.addSubview(benchmarkButton)

        // GTA Online Player Info under Play button
        onlinePlayerLabel.text = "اللعب بشخصية: \(playerName)"
        onlinePlayerLabel.font = Theme.body(12, .semibold)
        onlinePlayerLabel.textColor = UIColor(white: 1, alpha: 0.85)
        onlinePlayerLabel.textAlignment = .center

        var customCfg = UIButton.Configuration.plain()
        customCfg.title = "تعديل وتخصيص شخصيتك"
        customCfg.image = UIImage(systemName: "gearshape.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
        customCfg.imagePadding = 5
        customCfg.baseForegroundColor = UIColor(white: 1, alpha: 0.72)
        customCfg.contentInsets = .zero
        customCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a; a.font = Theme.body(11, .medium); return a
        }
        onlineCustomizeButton.configuration = customCfg
        onlineCustomizeButton.addAction(UIAction { [weak self] _ in self?.promptEditPlayerName() }, for: .touchUpInside)

        onlineMetaStack.addArrangedSubviews([onlinePlayerLabel, onlineCustomizeButton])
        onlineMetaStack.axis = .vertical
        onlineMetaStack.alignment = .center
        onlineMetaStack.spacing = 2
        onlineMetaStack.isHidden = true
        onlineMetaStack.translatesAutoresizingMaskIntoConstraints = false
        heroCol.addSubview(onlineMetaStack)

        // GTA VI Beta Badge under Install button
        let devLbl = UILabel()
        devLbl.text = "قيد التطوير"
        devLbl.font = Theme.body(12, .semibold)
        devLbl.textColor = UIColor(white: 1, alpha: 0.82)

        let betaBadge = UILabel()
        betaBadge.text = "  نسخة تجريبية  "
        betaBadge.font = Theme.body(11, .bold)
        betaBadge.textColor = .white
        betaBadge.backgroundColor = Self.vicePink
        betaBadge.layer.cornerRadius = 5
        betaBadge.clipsToBounds = true
        betaBadge.heightAnchor.constraint(equalToConstant: 20).isActive = true

        gtaviMetaStack.addArrangedSubviews([betaBadge, devLbl])
        gtaviMetaStack.axis = .horizontal
        gtaviMetaStack.alignment = .center
        gtaviMetaStack.spacing = 8
        gtaviMetaStack.isHidden = true
        gtaviMetaStack.translatesAutoresizingMaskIntoConstraints = false
        heroCol.addSubview(gtaviMetaStack)

        // Controller & Preload subtle labels at bottom-left
        controllerLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        controllerLabel.textColor = UIColor(white: 1, alpha: 0.55)
        preloadLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        preloadLabel.textColor = Self.gold
        preloadLabel.isHidden = true

        let statusMini = UIStackView(arrangedSubviews: [preloadLabel, controllerLabel])
        statusMini.axis = .vertical
        statusMini.alignment = .leading
        statusMini.spacing = 2
        statusMini.translatesAutoresizingMaskIntoConstraints = false
        heroCol.addSubview(statusMini)

        // Right Area: Performance Carousel (GTA V & GTA VI)
        buildPerformanceCarousel()

        // Right Area: Online Modes & Session Panel (GTA Online)
        buildOnlinePanel()

        NSLayoutConstraint.activate([
            heroCol.leadingAnchor.constraint(equalTo: gamesPage.leadingAnchor, constant: 4),
            heroCol.topAnchor.constraint(equalTo: gamesPage.topAnchor),
            heroCol.bottomAnchor.constraint(equalTo: gamesPage.bottomAnchor),
            heroCol.widthAnchor.constraint(equalToConstant: 215),

            heroLogoView.centerXAnchor.constraint(equalTo: heroCol.centerXAnchor),
            heroLogoView.topAnchor.constraint(equalTo: heroCol.topAnchor, constant: 6),
            heroLogoView.widthAnchor.constraint(equalToConstant: 205),
            heroLogoView.heightAnchor.constraint(equalToConstant: 162),

            playButton.topAnchor.constraint(equalTo: heroLogoView.bottomAnchor, constant: 14),
            playButton.leadingAnchor.constraint(equalTo: heroCol.leadingAnchor, constant: 6),
            playButton.trailingAnchor.constraint(equalTo: heroCol.trailingAnchor, constant: -6),
            playButton.heightAnchor.constraint(equalToConstant: 46),

            installGTAVIButton.topAnchor.constraint(equalTo: playButton.topAnchor),
            installGTAVIButton.leadingAnchor.constraint(equalTo: playButton.leadingAnchor),
            installGTAVIButton.trailingAnchor.constraint(equalTo: playButton.trailingAnchor),
            installGTAVIButton.heightAnchor.constraint(equalToConstant: 46),

            benchmarkButton.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 8),
            benchmarkButton.centerXAnchor.constraint(equalTo: heroCol.centerXAnchor),

            onlineMetaStack.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 8),
            onlineMetaStack.centerXAnchor.constraint(equalTo: heroCol.centerXAnchor),

            gtaviMetaStack.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 10),
            gtaviMetaStack.centerXAnchor.constraint(equalTo: heroCol.centerXAnchor),

            statusMini.leadingAnchor.constraint(equalTo: heroCol.leadingAnchor, constant: 6),
            statusMini.bottomAnchor.constraint(equalTo: heroCol.bottomAnchor),

            perfContainer.leadingAnchor.constraint(equalTo: heroCol.trailingAnchor, constant: 18),
            perfContainer.trailingAnchor.constraint(equalTo: gamesPage.trailingAnchor),
            perfContainer.topAnchor.constraint(equalTo: gamesPage.topAnchor, constant: 10),
            perfContainer.bottomAnchor.constraint(equalTo: gamesPage.bottomAnchor, constant: -14),

            onlineContainer.leadingAnchor.constraint(equalTo: heroCol.trailingAnchor, constant: 18),
            onlineContainer.trailingAnchor.constraint(equalTo: gamesPage.trailingAnchor),
            onlineContainer.topAnchor.constraint(equalTo: gamesPage.topAnchor, constant: 10),
            onlineContainer.bottomAnchor.constraint(equalTo: gamesPage.bottomAnchor, constant: -8)
        ])
    }

    private func buildPerformanceCarousel() {
        perfContainer.semanticContentAttribute = .forceLeftToRight
        perfContainer.translatesAutoresizingMaskIntoConstraints = false
        gamesPage.addSubview(perfContainer)

        perfScrollView.showsHorizontalScrollIndicator = false
        perfScrollView.alwaysBounceHorizontal = true
        perfScrollView.semanticContentAttribute = .forceLeftToRight
        perfScrollView.translatesAutoresizingMaskIntoConstraints = false
        perfContainer.addSubview(perfScrollView)

        perfCardsStack.axis = .horizontal
        perfCardsStack.spacing = 12
        perfCardsStack.alignment = .fill
        perfCardsStack.semanticContentAttribute = .forceLeftToRight
        perfCardsStack.translatesAutoresizingMaskIntoConstraints = false
        perfScrollView.addSubview(perfCardsStack)

        let presets: [(big: String, unit: String, caption: String, recommended: Bool, wide: Bool, assetV: String, assetVI: String)] = [
            ("24", "FPS", "توفير البطارية: يحافظ على برودة الجهاز", false, false, "CardGTAV_24", "CardGTAVI_24"),
            ("30", "FPS", "متوازن: إكساء عالي وظلال", true, true, "CardGTAV_30", "CardGTAVI_30"),
            ("60", "FPS", "أداء عالي: 60 إطاراً بالثانية", false, false, "CardGTAV_60", "CardGTAVI_60"),
            ("30", "FPS", "جودة فائقة: 720p، مدى رؤية بعيد", false, false, "CardGTAV_720", "CardGTAVI_720"),
            ("YOUR", "SETTINGS", "إعدادات مخصصة", false, false, "CardGTAV_Custom", "CardGTAVI_Custom")
        ]

        for (i, item) in presets.enumerated() {
            let card = LauncherPerfCard(
                bigText: item.big,
                unitText: item.unit,
                caption: item.caption,
                recommended: item.recommended,
                assetGTAV: item.assetV,
                assetGTAVI: item.assetVI,
                paletteIndex: i
            )
            card.widthAnchor.constraint(equalToConstant: item.wide ? 235 : 152).isActive = true
            card.addAction(UIAction { [weak self] _ in
                self?.applyPerformancePreset(i, showToast: true)
            }, for: .touchUpInside)
            perfCards.append(card)
            perfCardsStack.addArrangedSubview(card)
        }

        // Floating right chevron button (>) to scroll smoothly through cards
        perfScrollArrow.setImage(UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)), for: .normal)
        perfScrollArrow.tintColor = .white
        perfScrollArrow.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        perfScrollArrow.layer.cornerRadius = 17
        perfScrollArrow.layer.borderWidth = 1
        perfScrollArrow.layer.borderColor = UIColor(white: 1, alpha: 0.25).cgColor
        perfScrollArrow.translatesAutoresizingMaskIntoConstraints = false
        perfScrollArrow.addAction(UIAction { [weak self] _ in self?.scrollPerfCarousel() }, for: .touchUpInside)
        perfContainer.addSubview(perfScrollArrow)

        NSLayoutConstraint.activate([
            perfScrollView.leadingAnchor.constraint(equalTo: perfContainer.leadingAnchor),
            perfScrollView.trailingAnchor.constraint(equalTo: perfContainer.trailingAnchor),
            perfScrollView.topAnchor.constraint(equalTo: perfContainer.topAnchor),
            perfScrollView.bottomAnchor.constraint(equalTo: perfContainer.bottomAnchor),

            perfCardsStack.leadingAnchor.constraint(equalTo: perfScrollView.contentLayoutGuide.leadingAnchor),
            perfCardsStack.trailingAnchor.constraint(equalTo: perfScrollView.contentLayoutGuide.trailingAnchor, constant: -30),
            perfCardsStack.topAnchor.constraint(equalTo: perfScrollView.contentLayoutGuide.topAnchor),
            perfCardsStack.bottomAnchor.constraint(equalTo: perfScrollView.contentLayoutGuide.bottomAnchor),
            perfCardsStack.heightAnchor.constraint(equalTo: perfScrollView.frameLayoutGuide.heightAnchor),

            perfScrollArrow.trailingAnchor.constraint(equalTo: perfContainer.trailingAnchor, constant: -4),
            perfScrollArrow.centerYAnchor.constraint(equalTo: perfContainer.centerYAnchor),
            perfScrollArrow.widthAnchor.constraint(equalToConstant: 34),
            perfScrollArrow.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    private func scrollPerfCarousel() {
        let maxX = max(0, perfScrollView.contentSize.width - perfScrollView.bounds.width)
        guard maxX > 0 else { return }
        let nextX = perfScrollView.contentOffset.x + 190
        let targetX = perfScrollView.contentOffset.x >= maxX - 10 ? 0 : min(nextX, maxX)
        perfScrollView.setContentOffset(CGPoint(x: targetX, y: 0), animated: true)
    }

    private func applyPerformancePreset(_ index: Int, showToast: Bool) {
        selectedPerfIndex = index
        for (i, card) in perfCards.enumerated() {
            card.isSelected = (i == index)
        }
        let settings = GameSettings.shared
        switch index {
        case 0:
            settings.frameRateCap = 30
            settings.graphicsPreset = .battery
            settings.renderHeight = 0
            if showToast { showRockstarToast("24 FPS · توفير البطارية: يحافظ على برودة الجهاز") }
        case 1:
            settings.frameRateCap = 30
            settings.graphicsPreset = .performance
            settings.renderHeight = 0
            if showToast { showRockstarToast("30 FPS · متوازن: إكساء عالي وظلال (موصى به)") }
        case 2:
            settings.frameRateCap = 60
            settings.graphicsPreset = .performance
            settings.renderHeight = 0
            if showToast { showRockstarToast("60 FPS · أداء عالي: 60 إطاراً بالثانية") }
        case 3:
            settings.frameRateCap = 30
            settings.graphicsPreset = .quality
            settings.renderHeight = 720
            if showToast { showRockstarToast("جودة فائقة: 720p، مدى رؤية بعيد") }
        default:
            if showToast {
                showRockstarToast("تم اختيار إعداداتك المخصصة (YOUR SETTINGS)")
            }
        }
    }

    // MARK: - GTA Online 3-Card Panel

    private func buildOnlinePanel() {
        onlineContainer.semanticContentAttribute = .forceLeftToRight
        onlineContainer.isHidden = true
        onlineContainer.translatesAutoresizingMaskIntoConstraints = false
        gamesPage.addSubview(onlineContainer)

        let cardsRow = UIStackView()
        cardsRow.axis = .horizontal
        cardsRow.spacing = 10
        cardsRow.distribution = .fillEqually
        cardsRow.semanticContentAttribute = .forceLeftToRight
        cardsRow.translatesAutoresizingMaskIntoConstraints = false
        onlineContainer.addSubview(cardsRow)

        let modes: [(caption: String, asset: String, palette: Int)] = [
            ("تجول حر: بمفردك في الخريطة", "OnlineCard_FreeRoam", 0),
            ("استضافة: ينضم إليك أصدقاؤك", "OnlineCard_Host", 1),
            ("الانضمام إلى جلسة لعب", "OnlineCard_Join", 2)
        ]

        for (i, m) in modes.enumerated() {
            let card = OnlineModeCard(caption: m.caption, assetName: m.asset, palette: m.palette)
            card.addAction(UIAction { [weak self] _ in self?.selectOnlineMode(i) }, for: .touchUpInside)
            onlineModeCards.append(card)
            cardsRow.addArrangedSubview(card)
        }

        // Info box (Free Roam / Host)
        onlineInfoBox.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        onlineInfoBox.layer.cornerRadius = 8
        onlineInfoBox.translatesAutoresizingMaskIntoConstraints = false
        onlineContainer.addSubview(onlineInfoBox)

        onlineInfoLabel.text = "شخصيتك الأونلاين في مدينة لوس سانتوس المفتوحة: بدون قصة، مع قائمة مودات لكل شيء، وسباقات ومهمات ومعارك قراند أونلاين من صفحة المهمات. يمكنك فتح الجلسة لأصدقائك في أي وقت."
        onlineInfoLabel.font = Theme.body(11.5, .medium)
        onlineInfoLabel.textColor = UIColor(white: 1, alpha: 0.88)
        onlineInfoLabel.textAlignment = .right
        onlineInfoLabel.numberOfLines = 3
        onlineInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        onlineInfoBox.addSubview(onlineInfoLabel)

        // Join Session box (Card 3)
        onlineJoinBox.backgroundColor = UIColor.black.withAlphaComponent(0.60)
        onlineJoinBox.layer.cornerRadius = 8
        onlineJoinBox.isHidden = true
        onlineJoinBox.translatesAutoresizingMaskIntoConstraints = false
        onlineContainer.addSubview(onlineJoinBox)

        let pasteBtn = makeCompactDarkButton("لصق الدعوة")
        pasteBtn.addAction(UIAction { [weak self] _ in
            if let clip = UIPasteboard.general.string, !clip.isEmpty {
                self?.onlineStatusLabel.text = "تم لصق رمز الدعوة: \(clip) — جاهز للانضمام عند تشغيل اللعبة."
                self?.showRockstarToast("تم لصق رمز الدعوة بنجاح")
            } else {
                self?.showRockstarToast("الحافظة فارغة، انسخ رمز الدعوة أولاً")
            }
        }, for: .touchUpInside)

        let enterBtn = makeCompactDarkButton("إدخال الرمز")
        enterBtn.addAction(UIAction { [weak self] _ in self?.promptInviteCode() }, for: .touchUpInside)

        let sessionsTitle = UILabel()
        sessionsTitle.text = "الجلسات"
        sessionsTitle.font = Theme.body(13, .bold)
        sessionsTitle.textColor = .white
        sessionsTitle.textAlignment = .right

        let joinTopRow = UIStackView(arrangedSubviews: [pasteBtn, enterBtn, UIView(), sessionsTitle])
        joinTopRow.axis = .horizontal
        joinTopRow.spacing = 8
        joinTopRow.alignment = .center
        joinTopRow.semanticContentAttribute = .forceLeftToRight

        onlineStatusLabel.text = "جارٍ البحث على شبكة Wi-Fi هذه... لم يُعثر على جلسات بعد. لصديق في مكان آخر: اضغط إدخال الرمز أو الصق الدعوة."
        onlineStatusLabel.font = Theme.body(11, .regular)
        onlineStatusLabel.textColor = UIColor(white: 1, alpha: 0.72)
        onlineStatusLabel.textAlignment = .right
        onlineStatusLabel.numberOfLines = 2

        let joinStack = UIStackView(arrangedSubviews: [joinTopRow, onlineStatusLabel])
        joinStack.axis = .vertical
        joinStack.spacing = 6
        joinStack.translatesAutoresizingMaskIntoConstraints = false
        onlineJoinBox.addSubview(joinStack)

        NSLayoutConstraint.activate([
            cardsRow.topAnchor.constraint(equalTo: onlineContainer.topAnchor),
            cardsRow.leadingAnchor.constraint(equalTo: onlineContainer.leadingAnchor),
            cardsRow.trailingAnchor.constraint(equalTo: onlineContainer.trailingAnchor),
            cardsRow.bottomAnchor.constraint(equalTo: onlineInfoBox.topAnchor, constant: -10),

            onlineInfoBox.leadingAnchor.constraint(equalTo: onlineContainer.leadingAnchor),
            onlineInfoBox.trailingAnchor.constraint(equalTo: onlineContainer.trailingAnchor),
            onlineInfoBox.bottomAnchor.constraint(equalTo: onlineContainer.bottomAnchor),
            onlineInfoBox.heightAnchor.constraint(equalToConstant: 66),

            onlineInfoLabel.leadingAnchor.constraint(equalTo: onlineInfoBox.leadingAnchor, constant: 12),
            onlineInfoLabel.trailingAnchor.constraint(equalTo: onlineInfoBox.trailingAnchor, constant: -12),
            onlineInfoLabel.centerYAnchor.constraint(equalTo: onlineInfoBox.centerYAnchor),

            onlineJoinBox.leadingAnchor.constraint(equalTo: onlineInfoBox.leadingAnchor),
            onlineJoinBox.trailingAnchor.constraint(equalTo: onlineInfoBox.trailingAnchor),
            onlineJoinBox.topAnchor.constraint(equalTo: onlineInfoBox.topAnchor),
            onlineJoinBox.bottomAnchor.constraint(equalTo: onlineInfoBox.bottomAnchor),

            joinStack.leadingAnchor.constraint(equalTo: onlineJoinBox.leadingAnchor, constant: 10),
            joinStack.trailingAnchor.constraint(equalTo: onlineJoinBox.trailingAnchor, constant: -12),
            joinStack.centerYAnchor.constraint(equalTo: onlineJoinBox.centerYAnchor)
        ])
    }

    private func selectOnlineMode(_ index: Int) {
        selectedOnlineMode = index
        for (i, card) in onlineModeCards.enumerated() {
            card.isSelected = (i == index)
        }
        onlineInfoBox.isHidden = (index == 2)
        onlineJoinBox.isHidden = (index != 2)
    }

    // MARK: - Soon Store Overlay (سون ستور)

    private func setupStoreOverlay() {
        storeOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.58)
        storeOverlay.semanticContentAttribute = .forceLeftToRight
        storeOverlay.isHidden = true
        storeOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(storeOverlay)

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.alpha = 0.72
        pin(blur, to: storeOverlay)

        let title = UILabel()
        title.text = "سون ستور - تابعنا على مواقع التواصل"
        title.font = Theme.display(18, .bold)
        title.textColor = .white
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false
        storeOverlay.addSubview(title)

        var closeCfg = UIButton.Configuration.filled()
        closeCfg.title = "✕ إغلاق"
        closeCfg.baseForegroundColor = .white
        closeCfg.baseBackgroundColor = UIColor(white: 1, alpha: 0.14)
        closeCfg.background.strokeColor = UIColor(white: 1, alpha: 0.35)
        closeCfg.background.strokeWidth = 1
        closeCfg.cornerStyle = .capsule
        closeCfg.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16)
        closeCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a; a.font = Theme.body(13, .semibold); return a
        }
        let closeBtn = UIButton(configuration: closeCfg)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addAction(UIAction { [weak self] _ in self?.showStoreOverlay(false) }, for: .touchUpInside)
        storeOverlay.addSubview(closeBtn)

        let cardsRow = UIStackView()
        cardsRow.axis = .horizontal
        cardsRow.spacing = 16
        cardsRow.distribution = .fillEqually
        cardsRow.semanticContentAttribute = .forceLeftToRight
        cardsRow.translatesAutoresizingMaskIntoConstraints = false
        storeOverlay.addSubview(cardsRow)

        for (i, item) in socialItems.enumerated() {
            let card = SocialCard(title: item.title, kind: item.kind)
            card.addAction(UIAction { [weak self] _ in self?.selectSocialCard(i) }, for: .touchUpInside)
            socialCards.append(card)
            cardsRow.addArrangedSubview(card)
        }

        var followCfg = UIButton.Configuration.filled()
        followCfg.title = "متابعة"
        followCfg.baseForegroundColor = .black
        followCfg.baseBackgroundColor = Self.gold
        followCfg.cornerStyle = .medium
        followCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a; a.font = Theme.display(16, .heavy); return a
        }
        let followBtn = UIButton(configuration: followCfg)
        followBtn.translatesAutoresizingMaskIntoConstraints = false
        followBtn.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let target = self.socialItems[self.selectedSocialIndex]
            if let url = URL(string: target.url) {
                UIApplication.shared.open(url)
            }
            self.showRockstarToast("جاري فتح \(target.title)...")
        }, for: .touchUpInside)
        storeOverlay.addSubview(followBtn)

        let guide = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            storeOverlay.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            storeOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            storeOverlay.topAnchor.constraint(equalTo: topAnchor),
            storeOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            title.topAnchor.constraint(equalTo: guide.topAnchor, constant: 14),
            title.centerXAnchor.constraint(equalTo: storeOverlay.centerXAnchor),

            closeBtn.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),

            cardsRow.centerXAnchor.constraint(equalTo: storeOverlay.centerXAnchor),
            cardsRow.centerYAnchor.constraint(equalTo: storeOverlay.centerYAnchor, constant: -14),
            cardsRow.widthAnchor.constraint(lessThanOrEqualTo: storeOverlay.widthAnchor, multiplier: 0.78),
            cardsRow.widthAnchor.constraint(greaterThanOrEqualToConstant: 420),
            cardsRow.heightAnchor.constraint(equalToConstant: 184),

            followBtn.topAnchor.constraint(equalTo: cardsRow.bottomAnchor, constant: 14),
            followBtn.centerXAnchor.constraint(equalTo: storeOverlay.centerXAnchor),
            followBtn.widthAnchor.constraint(equalToConstant: 210),
            followBtn.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func showStoreOverlay(_ visible: Bool) {
        storeOverlay.isHidden = !visible
        if visible {
            bringSubviewToFront(storeOverlay)
            bringSubviewToFront(sidebar)
            bringSubviewToFront(toastBanner)
        }
    }

    private func selectSocialCard(_ index: Int) {
        selectedSocialIndex = index
        for (i, card) in socialCards.enumerated() {
            card.isSelected = (i == index)
        }
    }

    // MARK: - Mods Page

    private func buildModsPage() {
        let card = Theme.panel(cornerRadius: 14)
        card.translatesAutoresizingMaskIntoConstraints = false
        modsPage.addSubview(card)

        let title = UILabel()
        title.text = "مدير المودات والإضافات (Mods)"
        title.font = Theme.display(20, .bold)
        title.textColor = Theme.text
        title.textAlignment = .right

        modsSummaryLabel.font = Theme.body(14)
        modsSummaryLabel.textColor = Theme.secondaryText
        modsSummaryLabel.textAlignment = .right
        modsSummaryLabel.numberOfLines = 2

        let openModsBtn = Theme.primaryButton("إدارة وتثبيت المودات", symbol: "shippingbox.fill")
        openModsBtn.addAction(UIAction { [weak self] _ in
            if let onOpenMods = self?.onOpenMods { onOpenMods() }
            else { self?.settingsButton.sendActions(for: .touchUpInside) }
        }, for: .touchUpInside)

        let importBtn = Theme.glassButton("استيراد مود (.zip)", symbol: "plus.circle.fill")
        importBtn.addAction(UIAction { [weak self] _ in self?.onImportZip?() }, for: .touchUpInside)

        let btns = UIStackView(arrangedSubviews: [UIView(), importBtn, openModsBtn])
        btns.spacing = 10

        modsListStack.axis = .vertical
        modsListStack.spacing = 6

        let stack = UIStackView(arrangedSubviews: [title, modsSummaryLabel, btns, modsListStack, UIView()])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: modsPage.topAnchor),
            card.leadingAnchor.constraint(equalTo: modsPage.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: modsPage.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: modsPage.bottomAnchor),

            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -18)
        ])
    }

    private func refreshModsSummary() {
        let installed = ModInstaller.installed()
        let activeCount = installed.filter(\.enabled).count
        modsSummaryLabel.text = installed.isEmpty
            ? "لا توجد مودات مثبتة حالياً. يمكنك إضافة مودات السيارات، السكنات، أو السكربتات بصيغة .zip."
            : "إجمالي المودات المثبتة: \(installed.count) · المفعّلة حالياً: \(activeCount)"

        modsListStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for mod in installed.prefix(5) {
            let row = UILabel()
            row.font = Theme.body(13, .medium)
            row.textAlignment = .right
            row.textColor = mod.enabled ? Theme.ok : Theme.tertiaryText
            row.text = (mod.enabled ? "● مفعّل: " : "○ متوقف: ") + mod.name
            modsListStack.addArrangedSubview(row)
        }
    }

    // MARK: - Data & Saves Page

    private func buildDataPage(log: UIView) {
        let leftCol = UIStackView()
        leftCol.axis = .vertical
        leftCol.spacing = 10
        leftCol.translatesAutoresizingMaskIntoConstraints = false

        let specsPanel = Theme.panel(cornerRadius: 12)
        deviceSpecsLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        deviceSpecsLabel.textColor = Theme.text
        deviceSpecsLabel.textAlignment = .right
        deviceSpecsLabel.numberOfLines = 0
        deviceSpecsLabel.translatesAutoresizingMaskIntoConstraints = false
        specsPanel.contentView.addSubview(deviceSpecsLabel)
        NSLayoutConstraint.activate([
            deviceSpecsLabel.topAnchor.constraint(equalTo: specsPanel.contentView.topAnchor, constant: 10),
            deviceSpecsLabel.bottomAnchor.constraint(equalTo: specsPanel.contentView.bottomAnchor, constant: -10),
            deviceSpecsLabel.leadingAnchor.constraint(equalTo: specsPanel.contentView.leadingAnchor, constant: 12),
            deviceSpecsLabel.trailingAnchor.constraint(equalTo: specsPanel.contentView.trailingAnchor, constant: -12)
        ])

        let slotsTitle = UILabel()
        slotsTitle.text = "خانات الحفظ السريع (16 خانة)"
        slotsTitle.font = Theme.body(13, .bold)
        slotsTitle.textColor = Self.gold
        slotsTitle.textAlignment = .right

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 6
        grid.distribution = .fillEqually

        for row in 0..<4 {
            let hRow = UIStackView()
            hRow.axis = .horizontal
            hRow.spacing = 6
            hRow.distribution = .fillEqually
            for col in 0..<4 {
                let slotNum = row * 4 + col + 1
                var cfg = UIButton.Configuration.gray()
                cfg.title = String(format: "Slot %02d", slotNum)
                cfg.cornerStyle = .small
                cfg.baseForegroundColor = Theme.text
                cfg.baseBackgroundColor = UIColor(white: 1, alpha: 0.08)
                cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
                    var a = a; a.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold); return a
                }
                let btn = UIButton(configuration: cfg)
                btn.addAction(UIAction { [weak self] _ in self?.selectSaveSlot(slotNum) }, for: .touchUpInside)
                saveSlotButtons.append(btn)
                hRow.addArrangedSubview(btn)
            }
            grid.addArrangedSubview(hRow)
        }

        let manageFilesBtn = Theme.glassButton("إدارة وفحص ملفات اللعبة", symbol: "folder.fill")
        manageFilesBtn.addAction(UIAction { [weak self] _ in self?.onFiles?() }, for: .touchUpInside)

        leftCol.addArrangedSubviews([specsPanel, slotsTitle, grid, manageFilesBtn])

        log.isHidden = false
        log.translatesAutoresizingMaskIntoConstraints = false

        dataPage.addSubview(leftCol)
        dataPage.addSubview(log)

        NSLayoutConstraint.activate([
            leftCol.leadingAnchor.constraint(equalTo: dataPage.leadingAnchor),
            leftCol.topAnchor.constraint(equalTo: dataPage.topAnchor),
            leftCol.bottomAnchor.constraint(equalTo: dataPage.bottomAnchor),
            leftCol.widthAnchor.constraint(equalTo: dataPage.widthAnchor, multiplier: 0.52),

            log.leadingAnchor.constraint(equalTo: leftCol.trailingAnchor, constant: 12),
            log.trailingAnchor.constraint(equalTo: dataPage.trailingAnchor),
            log.topAnchor.constraint(equalTo: dataPage.topAnchor),
            log.bottomAnchor.constraint(equalTo: dataPage.bottomAnchor)
        ])
    }

    private func selectSaveSlot(_ slot: Int) {
        for (i, btn) in saveSlotButtons.enumerated() {
            let active = (i + 1 == slot)
            btn.configuration?.baseBackgroundColor = active ? Self.gold.withAlphaComponent(0.28) : UIColor(white: 1, alpha: 0.08)
            btn.configuration?.baseForegroundColor = active ? Self.gold : Theme.text
        }
        showRockstarToast(String(format: "تم تحديد خانة الحفظ رقم %02d (Slot %02d)", slot, slot))
    }

    private func refreshDeviceTelemetry() {
        let free = (try? GameFolder.appFolder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage).flatMap { $0 }
        let freeText = free.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "غير معروف"
        let memMB = GameSettings.shared.tier.memoryLimitMB
        let filesText = GameFolder.isChosen ? "متوفرة (\(GameFolder.name))" : "غير محددة بعد"
        deviceSpecsLabel.text = """
        الجهاز: iOS \(UIDevice.current.systemVersion) · الذاكرة المتاحة: \(memMB) MB
        المساحة الفارغة: \(freeText)
        حالة ملفات اللعبة: \(filesText)
        """
    }

    // MARK: - Settings Overview Page

    private func buildSettingsPage() {
        let card = Theme.panel(cornerRadius: 14)
        card.translatesAutoresizingMaskIntoConstraints = false
        settingsPage.addSubview(card)

        let title = UILabel()
        title.text = "إعدادات اللانشر واللعبة"
        title.font = Theme.display(20, .bold)
        title.textColor = Theme.text
        title.textAlignment = .right

        settingsLangLabel.font = Theme.body(14, .medium)
        settingsLangLabel.textColor = Theme.secondaryText
        settingsLangLabel.textAlignment = .right

        settingsPerfLabel.font = Theme.body(14, .medium)
        settingsPerfLabel.textColor = Theme.secondaryText
        settingsPerfLabel.textAlignment = .right

        let openFullSettings = Theme.primaryButton("فتح الإعدادات الكاملة (الجرافيكس، الصوت، الشفرات)", symbol: "slider.horizontal.3")
        openFullSettings.addAction(UIAction { [weak self] _ in
            self?.settingsButton.sendActions(for: .touchUpInside)
        }, for: .touchUpInside)

        let openTouchEditor = Theme.glassButton("تخصيص أماكن أزرار اللمس (HUD)", symbol: "hand.tap.fill")
        openTouchEditor.addAction(UIAction { [weak self] _ in
            self?.layoutButton.sendActions(for: .touchUpInside)
        }, for: .touchUpInside)

        #if targetEnvironment(macCatalyst)
        let row = UIStackView(arrangedSubviews: [UIView(), openFullSettings])
        #else
        let row = UIStackView(arrangedSubviews: [UIView(), openTouchEditor, openFullSettings])
        #endif
        row.spacing = 10

        let stack = UIStackView(arrangedSubviews: [title, settingsLangLabel, settingsPerfLabel, row, UIView()])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: settingsPage.topAnchor),
            card.leadingAnchor.constraint(equalTo: settingsPage.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: settingsPage.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: settingsPage.bottomAnchor),

            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -18)
        ])
    }

    private func refreshSettingsSummary() {
        let s = GameSettings.shared
        settingsLangLabel.text = "اللغة النشطة: \(AppLanguage.current.name)"
        settingsPerfLabel.text = "الجودة الحالية: \(s.graphicsPreset.title) · الإطارات: \(GameSettings.frameRateTitle(s.frameRateCap))"
    }

    // MARK: - Rockstar Toast & Popups

    private func setupToastBanner() {
        toastBanner.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 0.95)
        toastBanner.layer.cornerRadius = 10
        toastBanner.layer.borderWidth = 1
        toastBanner.layer.borderColor = Self.gold.withAlphaComponent(0.65).cgColor
        toastBanner.alpha = 0
        toastBanner.isUserInteractionEnabled = false
        toastBanner.translatesAutoresizingMaskIntoConstraints = false

        let badge = UILabel()
        badge.text = "R★"
        badge.font = Theme.display(11, .black)
        badge.textColor = .black
        badge.backgroundColor = Self.gold
        badge.textAlignment = .center
        badge.layer.cornerRadius = 4
        badge.clipsToBounds = true
        badge.widthAnchor.constraint(equalToConstant: 20).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 20).isActive = true

        toastLabel.font = Theme.body(12, .semibold)
        toastLabel.textColor = .white

        let row = UIStackView(arrangedSubviews: [badge, toastLabel])
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        toastBanner.addSubview(row)
        addSubview(toastBanner)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: toastBanner.leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: toastBanner.trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: toastBanner.topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: toastBanner.bottomAnchor, constant: -6),

            toastBanner.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 32),
            toastBanner.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    private func showRockstarToast(_ message: String) {
        toastHideWork?.cancel()
        toastLabel.text = message
        bringSubviewToFront(toastBanner)
        UIView.animate(withDuration: 0.2) { self.toastBanner.alpha = 1 }
        let work = DispatchWorkItem { [weak self] in
            UIView.animate(withDuration: 0.35) { self?.toastBanner.alpha = 0 }
        }
        toastHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6, execute: work)
    }

    private func promptEditPlayerName() {
        guard let vc = parentViewController() else { return }
        let alert = UIAlertController(title: "تخصيص الشخصية", message: "أدخل اسم شخصيتك في جراند أونلاين", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = self.playerName
            tf.placeholder = "Player0101"
        }
        alert.addAction(UIAlertAction(title: "إلغاء", style: .cancel))
        alert.addAction(UIAlertAction(title: "حفظ", style: .default) { [weak self] _ in
            guard let self else { return }
            let trimmed = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                self.playerName = trimmed
                self.onlinePlayerLabel.text = "اللعب بشخصية: \(trimmed)"
                self.showRockstarToast("تم تحديث اسم الشخصية إلى \(trimmed)")
            }
        })
        vc.present(alert, animated: true)
    }

    private func promptInviteCode() {
        guard let vc = parentViewController() else { return }
        let alert = UIAlertController(title: "الانضمام إلى جلسة لعب", message: "أدخل رمز الدعوة أو عنوان الجلسة", preferredStyle: .alert)
        alert.addTextField { tf in tf.placeholder = "مثال: GTA-4829" }
        alert.addAction(UIAlertAction(title: "إلغاء", style: .cancel))
        alert.addAction(UIAlertAction(title: "اتصال", style: .default) { [weak self] _ in
            let code = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !code.isEmpty else { return }
            self?.onlineStatusLabel.text = "تم تعيين رمز الجلسة: \(code) — اضغط تشغيل اللعبة للانضمام."
            self?.showRockstarToast("جاري تحضير الجلسة \(code)...")
        })
        vc.present(alert, animated: true)
    }

    private func parentViewController() -> UIViewController? {
        var r: UIResponder? = next
        while let current = r {
            if let vc = current as? UIViewController { return vc }
            r = current.next
        }
        return nil
    }

    // MARK: - NativePortViewController Hooks

    func refreshLanguage() {
        playButton.configuration?.title = "تشغيل اللعبة"
    }

    func setFiles(_ state: FilesState, title: String, detail: String) {
        filesPillLabel.text = title
        filesSpinner.isHidden = state != .busy
        filesDot.isHidden = state == .busy
        if state == .busy { filesSpinner.startAnimating() } else { filesSpinner.stopAnimating() }

        let (symbol, color): (String, UIColor) = switch state {
        case .ready: ("checkmark.circle.fill", Theme.ok)
        case .attention: ("folder.badge.plus", Theme.warning)
        case .problem: ("exclamationmark.triangle.fill", Theme.problem)
        case .busy: ("", .white)
        }
        filesDot.image = symbol.isEmpty ? nil : UIImage(systemName: symbol)
        filesDot.tintColor = color
        filesPill.layer.borderColor = color.withAlphaComponent(0.45).cgColor
    }

    func setMap(_ index: Int, visible: Bool, enabled: Bool, testMapAvailable: Bool = true) {
        self.testMapAvailable = testMapAvailable
        if selectedGameIndex == 2 {
            selectSidebarGame(2, notify: false)
        }
    }

    func setMode(_ index: Int?, detail: String, enabled: Bool) {
        if let index, index != selectedGameIndex, selectedGameIndex != 2 {
            selectSidebarGame(index, notify: false)
        }
    }

    // MARK: - Button Factories & Helpers

    private static func makeRockstarPlayButton() -> UIButton {
        var cfg = UIButton.Configuration.filled()
        cfg.title = "تشغيل اللعبة"
        cfg.image = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(weight: .heavy))
        cfg.imagePlacement = .trailing
        cfg.imagePadding = 10
        cfg.cornerStyle = .fixed
        cfg.background.cornerRadius = 7
        cfg.baseForegroundColor = UIColor(red: 0.08, green: 0.05, blue: 0.01, alpha: 1)
        cfg.background.backgroundColor = UIColor(white: 0.96, alpha: 1)

        let button = UIButton(configuration: cfg)
        button.clipsToBounds = true
        button.layer.cornerRadius = 7

        // Signature Rockstar bottom golden accent strip
        let bottomStrip = UIView()
        bottomStrip.backgroundColor = gold
        bottomStrip.isUserInteractionEnabled = false
        bottomStrip.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(bottomStrip)
        NSLayoutConstraint.activate([
            bottomStrip.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            bottomStrip.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            bottomStrip.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            bottomStrip.heightAnchor.constraint(equalToConstant: 4)
        ])

        button.configurationUpdateHandler = { btn in
            let enabled = btn.isEnabled
            btn.configuration?.background.backgroundColor = enabled
                ? (btn.isHighlighted ? UIColor(white: 0.84, alpha: 1) : UIColor(white: 0.96, alpha: 1))
                : UIColor(white: 1, alpha: 0.16)
            bottomStrip.alpha = enabled ? 1.0 : 0.35
        }
        return button
    }

    private static func makeWhiteActionButton(title: String, symbol: String) -> UIButton {
        var cfg = UIButton.Configuration.filled()
        cfg.title = title
        cfg.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold))
        cfg.imagePlacement = .trailing
        cfg.imagePadding = 8
        cfg.cornerStyle = .fixed
        cfg.background.cornerRadius = 7
        cfg.baseForegroundColor = .black
        cfg.background.backgroundColor = UIColor(white: 0.96, alpha: 1)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a; a.font = Theme.display(17, .heavy); return a
        }
        let btn = UIButton(configuration: cfg)
        btn.clipsToBounds = true
        btn.layer.cornerRadius = 7

        let strip = UIView()
        strip.backgroundColor = gold
        strip.isUserInteractionEnabled = false
        strip.translatesAutoresizingMaskIntoConstraints = false
        btn.addSubview(strip)
        NSLayoutConstraint.activate([
            strip.leadingAnchor.constraint(equalTo: btn.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: btn.trailingAnchor),
            strip.bottomAnchor.constraint(equalTo: btn.bottomAnchor),
            strip.heightAnchor.constraint(equalToConstant: 4)
        ])
        return btn
    }

    private func makeCompactDarkButton(_ title: String) -> UIButton {
        var cfg = UIButton.Configuration.filled()
        cfg.title = title
        cfg.baseForegroundColor = .white
        cfg.baseBackgroundColor = UIColor(white: 1, alpha: 0.14)
        cfg.background.strokeColor = UIColor(white: 1, alpha: 0.25)
        cfg.background.strokeWidth = 1
        cfg.cornerStyle = .small
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a; a.font = Theme.body(11, .bold); return a
        }
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

// MARK: - Sidebar Game Item

private final class LauncherSidebarItem: UIControl {
    enum IconKind { case gtaV, gtaOnline, gtaVI, store }

    var accentColor: UIColor = UIColor(red: 0.97, green: 0.67, blue: 0.10, alpha: 1) { didSet { update() } }
    private let indicator = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    init(title: String, kind: IconKind) {
        super.init(frame: .zero)
        semanticContentAttribute = .forceLeftToRight

        indicator.layer.cornerRadius = 1.5
        indicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(indicator)

        iconView.image = Self.makeIcon(for: kind)
        iconView.contentMode = .scaleAspectFit
        iconView.layer.cornerRadius = (kind == .store) ? 16 : 6
        iconView.clipsToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        titleLabel.text = title
        titleLabel.font = Theme.body(13, .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .right
        titleLabel.isHidden = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 40),

            indicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            indicator.widthAnchor.constraint(equalToConstant: 3),
            indicator.heightAnchor.constraint(equalToConstant: 24),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 17),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        update()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func setExpanded(_ expanded: Bool) {
        titleLabel.isHidden = !expanded
    }

    override var isSelected: Bool { didSet { update() } }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.65 : 1 } }

    private func update() {
        indicator.isHidden = !isSelected
        indicator.backgroundColor = accentColor
        iconView.alpha = isSelected ? 1.0 : 0.72
        titleLabel.textColor = isSelected ? .white : UIColor(white: 1, alpha: 0.75)
    }

    static func makeIcon(for kind: IconKind) -> UIImage {
        let assetName: String = switch kind {
        case .gtaV: "SidebarGTAV"
        case .gtaOnline: "SidebarGTAOnline"
        case .gtaVI: "SidebarGTAVI"
        case .store: "SidebarStore"
        }
        if let custom = UIImage(named: assetName) { return custom }

        let size = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            switch kind {
            case .gtaV:
                UIColor(white: 0.08, alpha: 1).setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
                drawCenteredText("GTA\nV", in: rect, font: .systemFont(ofSize: 20, weight: .black), color: .white)
                let dot = UIBezierPath(ovalIn: CGRect(x: 42, y: 40, width: 14, height: 14))
                UIColor(red: 0.25, green: 0.72, blue: 0.30, alpha: 1).setFill()
                dot.fill()
            case .gtaOnline:
                UIColor(white: 0.08, alpha: 1).setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
                drawCenteredText("GTA", in: CGRect(x: 0, y: 6, width: 64, height: 30), font: .systemFont(ofSize: 19, weight: .black), color: .white)
                UIColor(red: 0.89, green: 0.14, blue: 0.16, alpha: 1).setFill()
                UIBezierPath(roundedRect: CGRect(x: 8, y: 38, width: 48, height: 18), cornerRadius: 4).fill()
                drawCenteredText("ONLINE", in: CGRect(x: 8, y: 38, width: 48, height: 18), font: .systemFont(ofSize: 10, weight: .black), color: .white)
            case .gtaVI:
                let colors = [
                    UIColor(red: 0.45, green: 0.25, blue: 0.90, alpha: 1).cgColor,
                    UIColor(red: 0.91, green: 0.29, blue: 0.56, alpha: 1).cgColor,
                    UIColor(red: 0.98, green: 0.57, blue: 0.27, alpha: 1).cgColor
                ] as CFArray
                if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1]) {
                    ctx.cgContext.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 10).cgPath)
                    ctx.cgContext.clip()
                    ctx.cgContext.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 64, y: 64), options: [])
                }
                drawCenteredText("VI", in: rect, font: .systemFont(ofSize: 32, weight: .black), color: .white)
            case .store:
                UIColor.white.setFill()
                UIBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2)).fill()
                UIColor(red: 0.78, green: 0.11, blue: 0.15, alpha: 1).setStroke()
                let ring = UIBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 4))
                ring.lineWidth = 4
                ring.stroke()
                drawCenteredText("S", in: rect, font: .systemFont(ofSize: 32, weight: .black), color: .black)
            }
        }
    }

    private static func drawCenteredText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineHeightMultiple = 0.88
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
        let size = (text as NSString).boundingRect(with: rect.size, options: .usesLineFragmentOrigin, attributes: attrs, context: nil).size
        let target = CGRect(x: rect.minX, y: rect.midY - size.height / 2, width: rect.width, height: size.height)
        (text as NSString).draw(in: target, withAttributes: attrs)
    }
}

// MARK: - Big Hero Game Logo (GTA V / GTA Online / GTA VI)

private final class GameLogoBadgeView: UIView {
    private let customImageView = UIImageView()
    private let fallbackContainer = UIView()
    private let bgRomanLabel = UILabel()
    private let gtaStackLabel = UILabel()
    private let badgePill = UILabel()
    private let viGradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        customImageView.contentMode = .scaleAspectFit
        customImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(customImageView)

        fallbackContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fallbackContainer)

        bgRomanLabel.textAlignment = .center
        bgRomanLabel.translatesAutoresizingMaskIntoConstraints = false
        fallbackContainer.addSubview(bgRomanLabel)

        gtaStackLabel.numberOfLines = 3
        gtaStackLabel.textAlignment = .center
        gtaStackLabel.translatesAutoresizingMaskIntoConstraints = false
        fallbackContainer.addSubview(gtaStackLabel)

        badgePill.textAlignment = .center
        badgePill.clipsToBounds = true
        badgePill.translatesAutoresizingMaskIntoConstraints = false
        fallbackContainer.addSubview(badgePill)

        NSLayoutConstraint.activate([
            customImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            customImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            customImageView.topAnchor.constraint(equalTo: topAnchor),
            customImageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            fallbackContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            fallbackContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            fallbackContainer.topAnchor.constraint(equalTo: topAnchor),
            fallbackContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            bgRomanLabel.centerXAnchor.constraint(equalTo: fallbackContainer.centerXAnchor),
            bgRomanLabel.centerYAnchor.constraint(equalTo: fallbackContainer.centerYAnchor, constant: -4),

            gtaStackLabel.centerXAnchor.constraint(equalTo: fallbackContainer.centerXAnchor),
            gtaStackLabel.topAnchor.constraint(equalTo: fallbackContainer.topAnchor, constant: 6),
            gtaStackLabel.leadingAnchor.constraint(equalTo: fallbackContainer.leadingAnchor),
            gtaStackLabel.trailingAnchor.constraint(equalTo: fallbackContainer.trailingAnchor),

            badgePill.centerXAnchor.constraint(equalTo: fallbackContainer.centerXAnchor),
            badgePill.bottomAnchor.constraint(equalTo: fallbackContainer.bottomAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func setGame(_ index: Int) {
        let assetName = index == 0 ? "LogoGTAV" : index == 1 ? "LogoGTAOnline" : "LogoGTAVI"
        if let img = UIImage(named: assetName) {
            customImageView.image = img
            customImageView.isHidden = false
            fallbackContainer.isHidden = true
            return
        }
        customImageView.isHidden = true
        fallbackContainer.isHidden = false

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.maximumLineHeight = 36
        let gtaAttr = NSAttributedString(string: "grand\ntheft\nauto", attributes: [
            .font: UIFont.systemFont(ofSize: 38, weight: .black),
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black,
            .strokeWidth: -5.0,
            .paragraphStyle: style
        ])
        gtaStackLabel.attributedText = gtaAttr

        switch index {
        case 0: // GTA V
            bgRomanLabel.isHidden = true
            badgePill.isHidden = false
            badgePill.text = "  FIVE  "
            badgePill.font = .systemFont(ofSize: 20, weight: .black)
            badgePill.textColor = .white
            badgePill.backgroundColor = UIColor(red: 0.24, green: 0.56, blue: 0.24, alpha: 1)
            badgePill.layer.cornerRadius = 5
            badgePill.layer.borderWidth = 2
            badgePill.layer.borderColor = UIColor.white.cgColor
        case 1: // GTA Online
            bgRomanLabel.isHidden = true
            badgePill.isHidden = false
            badgePill.text = "  ONLINE  "
            badgePill.font = .systemFont(ofSize: 22, weight: .black)
            badgePill.textColor = .white
            badgePill.backgroundColor = UIColor(red: 0.86, green: 0.12, blue: 0.14, alpha: 1)
            badgePill.layer.cornerRadius = 5
            badgePill.layer.borderWidth = 2
            badgePill.layer.borderColor = UIColor.black.cgColor
        default: // GTA VI
            bgRomanLabel.isHidden = false
            badgePill.isHidden = true
            bgRomanLabel.attributedText = NSAttributedString(string: "VI", attributes: [
                .font: UIFont.systemFont(ofSize: 130, weight: .black),
                .foregroundColor: UIColor(red: 0.91, green: 0.29, blue: 0.56, alpha: 0.92),
                .strokeColor: UIColor(red: 0.98, green: 0.65, blue: 0.26, alpha: 1),
                .strokeWidth: -3.0
            ])
        }
    }
}

// MARK: - Horizontal Scrollable Performance Card

private final class LauncherPerfCard: UIControl {
    private let bgImage = UIImageView()
    private let artGradient = CAGradientLayer()
    private let bottomShade = CAGradientLayer()
    private let activeBadge = UILabel()
    private let recBadge = UILabel()
    private let bigLabel = UILabel()
    private let unitLabel = UILabel()
    private let captionBar = UIView()
    private let captionLabel = UILabel()

    private let assetGTAV: String
    private let assetGTAVI: String
    private let paletteIndex: Int
    private var isGTAVI = false

    init(bigText: String, unitText: String, caption: String, recommended: Bool, assetGTAV: String, assetGTAVI: String, paletteIndex: Int) {
        self.assetGTAV = assetGTAV
        self.assetGTAVI = assetGTAVI
        self.paletteIndex = paletteIndex
        super.init(frame: .zero)

        clipsToBounds = true
        layer.cornerRadius = 3
        layer.borderWidth = 1.5
        layer.borderColor = UIColor(white: 1, alpha: 0.2).cgColor

        layer.addSublayer(artGradient)

        bgImage.contentMode = .scaleAspectFill
        bgImage.clipsToBounds = true
        bgImage.isUserInteractionEnabled = false
        bgImage.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bgImage)

        bottomShade.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.75).cgColor]
        bottomShade.locations = [0.35, 1.0]
        layer.addSublayer(bottomShade)

        // Active badge (top-left)
        activeBadge.text = "  نشط  "
        activeBadge.font = Theme.body(11, .bold)
        activeBadge.layer.cornerRadius = 2
        activeBadge.clipsToBounds = true
        activeBadge.isHidden = true
        activeBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(activeBadge)

        // Recommended badge (top-right)
        recBadge.text = "  موصى به  "
        recBadge.font = Theme.body(11, .bold)
        recBadge.textColor = .black
        recBadge.backgroundColor = .white
        recBadge.layer.cornerRadius = 2
        recBadge.clipsToBounds = true
        recBadge.isHidden = !recommended
        recBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(recBadge)

        // Big FPS / YOUR SETTINGS typography
        let isCustom = (bigText == "YOUR")
        bigLabel.text = bigText
        bigLabel.font = isCustom ? Theme.display(26, .heavy) : .systemFont(ofSize: 48, weight: .light)
        bigLabel.textColor = .white
        bigLabel.layer.shadowColor = UIColor.black.cgColor
        bigLabel.layer.shadowOpacity = 0.7
        bigLabel.layer.shadowRadius = 4
        bigLabel.layer.shadowOffset = CGSize(width: 0, height: 1)

        unitLabel.text = unitText
        unitLabel.font = isCustom ? Theme.display(22, .heavy) : .systemFont(ofSize: 15, weight: .bold)
        unitLabel.textColor = .white

        let metricStack = UIStackView(arrangedSubviews: [bigLabel, unitLabel])
        metricStack.axis = isCustom ? .vertical : .horizontal
        metricStack.alignment = isCustom ? .leading : .lastBaseline
        metricStack.spacing = isCustom ? 0 : 4
        metricStack.isUserInteractionEnabled = false
        metricStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(metricStack)

        // Bottom black caption bar
        captionBar.backgroundColor = UIColor.black.withAlphaComponent(0.88)
        captionBar.isUserInteractionEnabled = false
        captionBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(captionBar)

        captionLabel.text = caption
        captionLabel.font = Theme.body(11, .semibold)
        captionLabel.textColor = UIColor(white: 1, alpha: 0.92)
        captionLabel.textAlignment = .center
        captionLabel.adjustsFontSizeToFitWidth = true
        captionLabel.minimumScaleFactor = 0.72
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        captionBar.addSubview(captionLabel)

        NSLayoutConstraint.activate([
            bgImage.leadingAnchor.constraint(equalTo: leadingAnchor),
            bgImage.trailingAnchor.constraint(equalTo: trailingAnchor),
            bgImage.topAnchor.constraint(equalTo: topAnchor),
            bgImage.bottomAnchor.constraint(equalTo: captionBar.topAnchor),

            activeBadge.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            activeBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            activeBadge.heightAnchor.constraint(equalToConstant: 20),

            recBadge.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            recBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            recBadge.heightAnchor.constraint(equalToConstant: 20),

            captionBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            captionBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            captionBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            captionBar.heightAnchor.constraint(equalToConstant: 32),

            captionLabel.leadingAnchor.constraint(equalTo: captionBar.leadingAnchor, constant: 6),
            captionLabel.trailingAnchor.constraint(equalTo: captionBar.trailingAnchor, constant: -6),
            captionLabel.centerYAnchor.constraint(equalTo: captionBar.centerYAnchor),

            metricStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            metricStack.bottomAnchor.constraint(equalTo: captionBar.topAnchor, constant: -8)
        ])

        setTheme(isGTAVI: false, index: paletteIndex)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        artGradient.frame = bounds
        bottomShade.frame = CGRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - 32))
    }

    func setTheme(isGTAVI: Bool, index: Int) {
        self.isGTAVI = isGTAVI
        let imgName = isGTAVI ? assetGTAVI : assetGTAV
        bgImage.image = UIImage(named: imgName) ?? UIImage(named: "StartBackground")
        bgImage.alpha = UIImage(named: imgName) != nil ? 1.0 : 0.42

        let gtaVPalettes: [[UIColor]] = [
            [UIColor(red: 0.52, green: 0.44, blue: 0.24, alpha: 1), UIColor(red: 0.14, green: 0.18, blue: 0.24, alpha: 1)],
            [UIColor(red: 0.65, green: 0.46, blue: 0.20, alpha: 1), UIColor(red: 0.16, green: 0.11, blue: 0.08, alpha: 1)],
            [UIColor(red: 0.16, green: 0.48, blue: 0.56, alpha: 1), UIColor(red: 0.48, green: 0.14, blue: 0.16, alpha: 1)],
            [UIColor(red: 0.36, green: 0.46, blue: 0.62, alpha: 1), UIColor(red: 0.12, green: 0.14, blue: 0.20, alpha: 1)],
            [UIColor(red: 0.34, green: 0.50, blue: 0.28, alpha: 1), UIColor(red: 0.14, green: 0.18, blue: 0.14, alpha: 1)]
        ]
        let gtaVIPalettes: [[UIColor]] = [
            [UIColor(red: 0.72, green: 0.32, blue: 0.48, alpha: 1), UIColor(red: 0.16, green: 0.26, blue: 0.34, alpha: 1)],
            [UIColor(red: 0.50, green: 0.26, blue: 0.62, alpha: 1), UIColor(red: 0.18, green: 0.16, blue: 0.36, alpha: 1)],
            [UIColor(red: 0.48, green: 0.62, blue: 0.44, alpha: 1), UIColor(red: 0.18, green: 0.24, blue: 0.20, alpha: 1)],
            [UIColor(red: 0.78, green: 0.42, blue: 0.46, alpha: 1), UIColor(red: 0.24, green: 0.14, blue: 0.30, alpha: 1)],
            [UIColor(red: 0.32, green: 0.48, blue: 0.64, alpha: 1), UIColor(red: 0.14, green: 0.14, blue: 0.24, alpha: 1)]
        ]
        let palette = (isGTAVI ? gtaVIPalettes : gtaVPalettes)[index % 5]
        artGradient.colors = palette.map(\.cgColor)
        artGradient.startPoint = CGPoint(x: 0.5, y: 0)
        artGradient.endPoint = CGPoint(x: 0.5, y: 1)
        update()
    }

    override var isSelected: Bool { didSet { update() } }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.82 : 1 } }

    private func update() {
        let accent = isGTAVI
            ? UIColor(red: 0.91, green: 0.29, blue: 0.56, alpha: 1)
            : UIColor(red: 0.97, green: 0.67, blue: 0.10, alpha: 1)
        activeBadge.isHidden = !isSelected
        activeBadge.backgroundColor = accent
        activeBadge.textColor = isGTAVI ? .white : .black
        layer.borderWidth = isSelected ? 2.4 : 1.0
        layer.borderColor = (isSelected ? accent : UIColor(white: 1, alpha: 0.22)).cgColor
    }
}

// MARK: - GTA Online Mode Card

private final class OnlineModeCard: UIControl {
    private let artGradient = CAGradientLayer()
    private let bgImage = UIImageView()
    private let selectedBadge = UILabel()
    private let captionBar = UIView()
    private let captionLabel = UILabel()

    init(caption: String, assetName: String, palette: Int) {
        super.init(frame: .zero)
        clipsToBounds = true
        layer.cornerRadius = 3
        layer.borderWidth = 1.5
        layer.borderColor = UIColor(white: 1, alpha: 0.2).cgColor

        let palettes: [[UIColor]] = [
            [UIColor(red: 0.70, green: 0.58, blue: 0.46, alpha: 1), UIColor(red: 0.16, green: 0.14, blue: 0.16, alpha: 1)],
            [UIColor(red: 0.24, green: 0.44, blue: 0.62, alpha: 1), UIColor(red: 0.10, green: 0.16, blue: 0.24, alpha: 1)],
            [UIColor(red: 0.44, green: 0.56, blue: 0.44, alpha: 1), UIColor(red: 0.14, green: 0.18, blue: 0.16, alpha: 1)]
        ]
        artGradient.colors = palettes[palette % 3].map(\.cgColor)
        layer.addSublayer(artGradient)

        bgImage.image = UIImage(named: assetName) ?? UIImage(named: "StartBackground")
        bgImage.alpha = UIImage(named: assetName) != nil ? 1.0 : 0.42
        bgImage.contentMode = .scaleAspectFill
        bgImage.clipsToBounds = true
        bgImage.isUserInteractionEnabled = false
        bgImage.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bgImage)

        selectedBadge.text = "  محدد  "
        selectedBadge.font = Theme.body(11, .bold)
        selectedBadge.textColor = .black
        selectedBadge.backgroundColor = UIColor(red: 0.97, green: 0.67, blue: 0.10, alpha: 1)
        selectedBadge.layer.cornerRadius = 2
        selectedBadge.clipsToBounds = true
        selectedBadge.isHidden = true
        selectedBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(selectedBadge)

        captionBar.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        captionBar.isUserInteractionEnabled = false
        captionBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(captionBar)

        captionLabel.text = caption
        captionLabel.font = Theme.body(11, .bold)
        captionLabel.textColor = .white
        captionLabel.textAlignment = .center
        captionLabel.adjustsFontSizeToFitWidth = true
        captionLabel.minimumScaleFactor = 0.72
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        captionBar.addSubview(captionLabel)

        NSLayoutConstraint.activate([
            bgImage.leadingAnchor.constraint(equalTo: leadingAnchor),
            bgImage.trailingAnchor.constraint(equalTo: trailingAnchor),
            bgImage.topAnchor.constraint(equalTo: topAnchor),
            bgImage.bottomAnchor.constraint(equalTo: captionBar.topAnchor),

            selectedBadge.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            selectedBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            selectedBadge.heightAnchor.constraint(equalToConstant: 20),

            captionBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            captionBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            captionBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            captionBar.heightAnchor.constraint(equalToConstant: 30),

            captionLabel.leadingAnchor.constraint(equalTo: captionBar.leadingAnchor, constant: 6),
            captionLabel.trailingAnchor.constraint(equalTo: captionBar.trailingAnchor, constant: -6),
            captionLabel.centerYAnchor.constraint(equalTo: captionBar.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        artGradient.frame = bounds
    }

    override var isSelected: Bool { didSet { update() } }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.8 : 1 } }

    private func update() {
        let gold = UIColor(red: 0.97, green: 0.67, blue: 0.10, alpha: 1)
        selectedBadge.isHidden = !isSelected
        layer.borderWidth = isSelected ? 2.4 : 1.0
        layer.borderColor = (isSelected ? gold : UIColor(white: 1, alpha: 0.2)).cgColor
    }
}

// MARK: - Soon Store Social Card

private final class SocialCard: UIControl {
    enum Kind { case telegram, instagram, tiktok }

    private let box = UIView()
    private let gradient = CAGradientLayer()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    init(title: String, kind: Kind) {
        super.init(frame: .zero)

        box.layer.cornerRadius = 14
        box.layer.cornerCurve = .continuous
        box.clipsToBounds = true
        box.isUserInteractionEnabled = false
        box.translatesAutoresizingMaskIntoConstraints = false
        addSubview(box)

        switch kind {
        case .telegram:
            gradient.colors = [
                UIColor(red: 0.07, green: 0.45, blue: 0.78, alpha: 1).cgColor,
                UIColor(red: 0.04, green: 0.18, blue: 0.36, alpha: 1).cgColor
            ]
            iconView.image = UIImage(systemName: "paperplane.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 72, weight: .regular))
            iconView.tintColor = UIColor(red: 0.34, green: 0.78, blue: 1.0, alpha: 1)
        case .instagram:
            gradient.colors = [
                UIColor(red: 0.34, green: 0.12, blue: 0.46, alpha: 1).cgColor,
                UIColor(red: 0.66, green: 0.14, blue: 0.42, alpha: 1).cgColor,
                UIColor(red: 0.38, green: 0.12, blue: 0.24, alpha: 1).cgColor
            ]
            iconView.image = UIImage(systemName: "camera.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 72, weight: .light))
            iconView.tintColor = .white
        case .tiktok:
            gradient.colors = [
                UIColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1).cgColor,
                UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1).cgColor
            ]
            iconView.image = UIImage(systemName: "music.note", withConfiguration: UIImage.SymbolConfiguration(pointSize: 66, weight: .bold))
            iconView.tintColor = UIColor(red: 0.25, green: 0.92, blue: 0.90, alpha: 1)
        }
        gradient.startPoint = CGPoint(x: 0.2, y: 0)
        gradient.endPoint = CGPoint(x: 0.8, y: 1)
        box.layer.addSublayer(gradient)

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(iconView)

        titleLabel.text = title
        titleLabel.font = Theme.body(14, .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            box.topAnchor.constraint(equalTo: topAnchor),
            box.leadingAnchor.constraint(equalTo: leadingAnchor),
            box.trailingAnchor.constraint(equalTo: trailingAnchor),
            box.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -8),

            iconView.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 82),
            iconView.heightAnchor.constraint(equalToConstant: 82),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 22)
        ])
        update()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = box.bounds
    }

    override var isSelected: Bool { didSet { update() } }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.8 : 1 } }

    private func update() {
        let gold = UIColor(red: 0.97, green: 0.67, blue: 0.10, alpha: 1)
        box.layer.borderWidth = isSelected ? 2.6 : 1.0
        box.layer.borderColor = (isSelected ? gold : UIColor(white: 1, alpha: 0.22)).cgColor
        titleLabel.textColor = isSelected ? gold : .white
    }
}

private extension UIStackView {
    func addArrangedSubviews(_ views: [UIView]) { views.forEach(addArrangedSubview) }
}
