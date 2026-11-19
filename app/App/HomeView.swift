import UIKit

/// Rockstar Games Launcher styled start screen with collapsible left game sidebar,
/// top category tabs (Games, Mods, Data & Saves, Settings), horizontal performance cards
/// (24 FPS, 30 FPS, 60 FPS, 720p, YOUR SETTINGS), Rockstar bottom toast notifications,
/// 16 save slots, device telemetry, and .zip archive import.
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

    // Public controls expected by NativePortViewController
    let playButton = Theme.primaryButton("تشغيل اللعبة", symbol: "play.fill")
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

    // Sidebar state
    private let sidebar = UIView()
    private var sidebarWidthConstraint: NSLayoutConstraint!
    private var sidebarExpanded = true
    private let sidebarBrandLabel = UILabel()
    private var sidebarButtons: [SidebarGameButton] = []
    private var selectedGameIndex = 0 // 0: GTA V, 1: GTA Online, 2: GTA VI

    // Top Navigation Tabs
    private var topTabButtons: [UIButton] = []
    private let tabIndicator = UIView()
    private var tabIndicatorLeading: NSLayoutConstraint!
    private var tabIndicatorWidth: NSLayoutConstraint!
    private var selectedTabIndex = 0

    // Tab Pages
    private let gamesPage = UIView()
    private let modsPage = UIView()
    private let dataPage = UIView()
    private let settingsPage = UIView()

    // Files Card & Status
    private let filesCard = UIControl()
    private let filesIcon = UIImageView()
    private let filesTitle = UILabel()
    private let filesDetail = UILabel()
    private let filesSpinner = UIActivityIndicatorView(style: .medium)

    // Games Page Elements
    private let heroGameTitle = UILabel()
    private let heroGameTag = UILabel()
    private let heroGameSubtitle = UILabel()
    private var perfCards: [PerformancePresetCard] = []
    private var selectedPerfIndex = 1 // Default: 30 FPS Balanced
    private let importZipButton = Theme.glassButton("استيراد ملفات (.zip)", symbol: "archivebox.fill")

    // Mods & Data Dynamic Labels
    private let modsSummaryLabel = UILabel()
    private let modsListStack = UIStackView()
    private let deviceSpecsLabel = UILabel()
    private var saveSlotButtons: [UIButton] = []
    private let settingsLangLabel = UILabel()
    private let settingsPerfLabel = UILabel()

    // Rockstar Bottom Toast Notification
    private let toastBanner = UIView()
    private let toastLabel = UILabel()
    private var toastHideWork: DispatchWorkItem?

    private var testMapAvailable = true

    init(modes: [(title: String, symbol: String)], log: UIView) {
        super.init(frame: .zero)
        let backdrop = Theme.backdrop(image: "StartBackground", darken: 0.62)
        pin(backdrop, to: self)

        setupSidebar()
        setupTopTabs()
        setupPages(log: log)
        setupToastBanner()

        // Default selection: GTA V Story Mode & 30 FPS Balanced
        selectSidebarGame(0, notify: false)
        selectTopTab(0)
        applyPerformancePreset(1, showToast: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: - Left Collapsible Sidebar

    private func setupSidebar() {
        sidebar.backgroundColor = Theme.sidebarBg
        sidebar.layer.borderWidth = 1
        sidebar.layer.borderColor = Theme.panelStroke.cgColor
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sidebar)

        let guide = safeAreaLayoutGuide
        sidebarWidthConstraint = sidebar.widthAnchor.constraint(equalToConstant: 184)
        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: bottomAnchor),
            sidebarWidthConstraint
        ])

        // Rockstar "R★" Emblem
        let rBadge = UILabel()
        rBadge.text = "R★"
        rBadge.font = Theme.display(17, .black)
        rBadge.textColor = .black
        rBadge.backgroundColor = Theme.accent
        rBadge.textAlignment = .center
        rBadge.layer.cornerRadius = 8
        rBadge.clipsToBounds = true
        rBadge.translatesAutoresizingMaskIntoConstraints = false
        rBadge.widthAnchor.constraint(equalToConstant: 32).isActive = true
        rBadge.heightAnchor.constraint(equalToConstant: 32).isActive = true

        sidebarBrandLabel.text = "ROCKSTAR"
        sidebarBrandLabel.font = Theme.display(14, .heavy)
        sidebarBrandLabel.textColor = Theme.text

        let toggleBtn = UIButton(type: .system)
        toggleBtn.setImage(UIImage(systemName: "sidebar.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)), for: .normal)
        toggleBtn.tintColor = Theme.secondaryText
        toggleBtn.addAction(UIAction { [weak self] _ in self?.toggleSidebar() }, for: .touchUpInside)

        let topRow = UIStackView(arrangedSubviews: [rBadge, sidebarBrandLabel, toggleBtn])
        topRow.spacing = 8
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(topRow)

        let items: [(title: String, subtitle: String, symbol: String)] = [
            ("جراند 5", "GTA V · القصة", "car.fill"),
            ("جراند أونلاين", "GTA Online · مفتوح", "globe.americas.fill"),
            ("جراند 6", "GTA VI · تجريبي", "sparkles"),
            ("المتجر والتواصل", "تيليجرام والتحديثات", "bag.fill")
        ]

        let navStack = UIStackView()
        navStack.axis = .vertical
        navStack.spacing = 8
        navStack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(navStack)

        for (idx, item) in items.enumerated() {
            let btn = SidebarGameButton(title: item.title, subtitle: item.subtitle, symbol: item.symbol)
            btn.addAction(UIAction { [weak self] _ in
                if idx == 3 {
                    UIApplication.shared.open(Theme.telegramURL)
                    self?.showRockstarToast("جاري فتح قناة Rockstar / Five Star Port الرسمية...")
                } else {
                    self?.selectSidebarGame(idx, notify: true)
                }
            }, for: .touchUpInside)
            sidebarButtons.append(btn)
            navStack.addArrangedSubview(btn)
        }

        let versionLabel = UILabel()
        versionLabel.text = Theme.appVersion
        versionLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        versionLabel.textColor = Theme.tertiaryText
        versionLabel.textAlignment = .center
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(versionLabel)

        NSLayoutConstraint.activate([
            topRow.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            topRow.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 14),
            topRow.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -10),

            navStack.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 18),
            navStack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 10),
            navStack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -10),

            versionLabel.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -10),
            versionLabel.centerXAnchor.constraint(equalTo: sidebar.centerXAnchor)
        ])
    }

    private func toggleSidebar() {
        sidebarExpanded.toggle()
        sidebarWidthConstraint.constant = sidebarExpanded ? 184 : 62
        sidebarBrandLabel.isHidden = !sidebarExpanded
        for btn in sidebarButtons { btn.setExpanded(sidebarExpanded) }
        UIView.animate(withDuration: 0.24, delay: 0, options: .curveEaseInOut) {
            self.layoutIfNeeded()
        }
    }

    private func selectSidebarGame(_ index: Int, notify: Bool) {
        selectedGameIndex = index
        for (i, btn) in sidebarButtons.enumerated() {
            btn.isSelected = (i == index)
        }
        switch index {
        case 0:
            heroGameTag.text = "ROCKSTAR GAMES PRESENTS · STORY MODE"
            heroGameTitle.text = "Grand Theft Auto V"
            heroGameSubtitle.text = "وضع القصة الكامل مع المهام والشخصيات الثلاث في لوس سانتوس."
            importZipButton.isHidden = true
            if notify {
                onMode?(0)
                showRockstarToast("تم اختيار جراند 5 (وضع القصة)")
            }
        case 1:
            heroGameTag.text = "ROCKSTAR GAMES · OPEN WORLD SANDBOX"
            heroGameTitle.text = "Grand Theft Auto Online"
            heroGameSubtitle.text = "تجوال حر في كامل الخريطة مع فتح جميع الأسلحة والمركبات."
            importZipButton.isHidden = true
            if notify {
                onMap?(0)
                onMode?(1)
                showRockstarToast("تم اختيار جراند أونلاين (العالم المفتوح)")
            }
        default:
            heroGameTag.text = "NEXT-GEN PREVIEW · LEONIDA / TEST MAP"
            heroGameTitle.text = "Grand Theft Auto VI"
            heroGameSubtitle.text = testMapAvailable
                ? "خريطة جراند 6 التجريبية جاهزة للتشغيل أو استيراد حزم التعديل (.zip)."
                : "قم باستيراد ملفات خريطة جراند 6 (.zip) لتفعيل هذا الوضع."
            importZipButton.isHidden = false
            if notify {
                onMode?(1)
                if testMapAvailable { onMap?(1) }
                showRockstarToast("تم اختيار جراند 6 (الوضع التجريبي)")
            }
        }
    }

    // MARK: - Top Category Tabs

    private let topBar = UIView()

    private func setupTopTabs() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topBar)

        let tabTitles = ["الألعاب", "المودات", "البيانات وملفات الحفظ", "الإعدادات"]
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 18
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(stack)

        for (i, title) in tabTitles.enumerated() {
            var cfg = UIButton.Configuration.plain()
            cfg.title = title
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 8, trailing: 6)
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attr in
                var a = attr
                a.font = Theme.body(14, .bold)
                return a
            }
            let btn = UIButton(configuration: cfg)
            btn.addAction(UIAction { [weak self] _ in self?.selectTopTab(i) }, for: .touchUpInside)
            topTabButtons.append(btn)
            stack.addArrangedSubview(btn)
        }

        tabIndicator.backgroundColor = Theme.accent
        tabIndicator.layer.cornerRadius = 1.5
        tabIndicator.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(tabIndicator)

        let guide = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topBar.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 20),
            topBar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            topBar.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            topBar.heightAnchor.constraint(equalToConstant: 38),

            stack.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            stack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            tabIndicator.bottomAnchor.constraint(equalTo: topBar.bottomAnchor),
            tabIndicator.heightAnchor.constraint(equalToConstant: 3)
        ])

        tabIndicatorLeading = tabIndicator.leadingAnchor.constraint(equalTo: topTabButtons[0].leadingAnchor)
        tabIndicatorWidth = tabIndicator.widthAnchor.constraint(equalTo: topTabButtons[0].widthAnchor)
        NSLayoutConstraint.activate([tabIndicatorLeading, tabIndicatorWidth])
    }

    private func selectTopTab(_ index: Int) {
        selectedTabIndex = index
        for (i, btn) in topTabButtons.enumerated() {
            btn.configuration?.baseForegroundColor = (i == index) ? Theme.accent : Theme.secondaryText
        }
        let target = topTabButtons[index]
        tabIndicatorLeading.isActive = false
        tabIndicatorWidth.isActive = false
        tabIndicatorLeading = tabIndicator.leadingAnchor.constraint(equalTo: target.leadingAnchor)
        tabIndicatorWidth = tabIndicator.widthAnchor.constraint(equalTo: target.widthAnchor)
        NSLayoutConstraint.activate([tabIndicatorLeading, tabIndicatorWidth])

        gamesPage.isHidden = index != 0
        modsPage.isHidden = index != 1
        dataPage.isHidden = index != 2
        settingsPage.isHidden = index != 3

        if index == 1 { refreshModsSummary() }
        if index == 2 { refreshDeviceTelemetry() }
        if index == 3 { refreshSettingsSummary() }

        UIView.animate(withDuration: 0.2) { self.layoutIfNeeded() }
    }

    // MARK: - Pages Setup

    private func setupPages(log: UIView) {
        let guide = safeAreaLayoutGuide
        for page in [gamesPage, modsPage, dataPage, settingsPage] {
            page.translatesAutoresizingMaskIntoConstraints = false
            addSubview(page)
            NSLayoutConstraint.activate([
                page.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 20),
                page.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
                page.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 10),
                page.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -14)
            ])
        }

        buildGamesPage()
        buildModsPage()
        buildDataPage(log: log)
        buildSettingsPage()
    }

    private func buildGamesPage() {
        buildFilesCard()

        controllerLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        controllerLabel.textColor = Theme.secondaryText
        preloadLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        preloadLabel.textColor = Theme.accent
        preloadLabel.isHidden = true

        let statusPills = UIStackView(arrangedSubviews: [controllerLabel, preloadLabel])
        statusPills.axis = .vertical
        statusPills.alignment = .trailing
        statusPills.spacing = 2

        let topStrip = UIStackView(arrangedSubviews: [filesCard, UIView(), statusPills])
        topStrip.alignment = .center
        topStrip.spacing = 12
        topStrip.translatesAutoresizingMaskIntoConstraints = false
        gamesPage.addSubview(topStrip)

        // Hero Title Block
        heroGameTag.font = Theme.body(11, .heavy)
        heroGameTag.textColor = Theme.accent
        heroGameTitle.font = Theme.display(32, .black)
        heroGameTitle.textColor = Theme.text
        heroGameTitle.adjustsFontSizeToFitWidth = true
        heroGameTitle.minimumScaleFactor = 0.75

        heroGameSubtitle.font = Theme.body(13, .medium)
        heroGameSubtitle.textColor = Theme.secondaryText
        heroGameSubtitle.numberOfLines = 2

        let heroStack = UIStackView(arrangedSubviews: [heroGameTag, heroGameTitle, heroGameSubtitle])
        heroStack.axis = .vertical
        heroStack.spacing = 4
        heroStack.translatesAutoresizingMaskIntoConstraints = false
        gamesPage.addSubview(heroStack)

        // Horizontal Performance Preset Cards
        let presets: [(fps: String, tag: String)] = [
            ("24 FPS", "توفير البطارية"),
            ("30 FPS", "متوازن · موصى به"),
            ("60 FPS", "أداء عالي"),
            ("720p", "جودة فائقة"),
            ("YOUR SETTINGS", "إعداداتك المخصصة")
        ]

        let cardsRow = UIStackView()
        cardsRow.axis = .horizontal
        cardsRow.spacing = 10
        cardsRow.distribution = .fillEqually
        cardsRow.translatesAutoresizingMaskIntoConstraints = false

        for (i, item) in presets.enumerated() {
            let card = PerformancePresetCard(headline: item.fps, badge: item.tag)
            card.addAction(UIAction { [weak self] _ in
                self?.applyPerformancePreset(i, showToast: true)
            }, for: .touchUpInside)
            perfCards.append(card)
            cardsRow.addArrangedSubview(card)
        }
        gamesPage.addSubview(cardsRow)

        // Bottom CTA Action Bar
        importZipButton.isHidden = true
        importZipButton.addAction(UIAction { [weak self] _ in self?.onImportZip?() }, for: .touchUpInside)

        telegramButton.addAction(UIAction { _ in UIApplication.shared.open(Theme.telegramURL) }, for: .touchUpInside)
        for btn in [telegramButton, layoutButton, settingsButton] {
            btn.configuration?.title = nil
        }
        settingsButton.accessibilityLabel = AppLanguage.choose("Settings")
        layoutButton.accessibilityLabel = AppLanguage.choose("Controls layout")
        telegramButton.accessibilityLabel = "Telegram"

        #if targetEnvironment(macCatalyst)
        let actionBar = UIStackView(arrangedSubviews: [playButton, importZipButton, UIView(), telegramButton, settingsButton])
        #else
        let actionBar = UIStackView(arrangedSubviews: [playButton, importZipButton, UIView(), telegramButton, layoutButton, settingsButton])
        #endif
        actionBar.axis = .horizontal
        actionBar.spacing = 10
        actionBar.alignment = .center
        actionBar.translatesAutoresizingMaskIntoConstraints = false
        gamesPage.addSubview(actionBar)

        NSLayoutConstraint.activate([
            topStrip.topAnchor.constraint(equalTo: gamesPage.topAnchor),
            topStrip.leadingAnchor.constraint(equalTo: gamesPage.leadingAnchor),
            topStrip.trailingAnchor.constraint(equalTo: gamesPage.trailingAnchor),
            filesCard.widthAnchor.constraint(lessThanOrEqualToConstant: 360),

            actionBar.bottomAnchor.constraint(equalTo: gamesPage.bottomAnchor, constant: -4),
            actionBar.leadingAnchor.constraint(equalTo: gamesPage.leadingAnchor),
            actionBar.trailingAnchor.constraint(equalTo: gamesPage.trailingAnchor),

            cardsRow.bottomAnchor.constraint(equalTo: actionBar.topAnchor, constant: -14),
            cardsRow.leadingAnchor.constraint(equalTo: gamesPage.leadingAnchor),
            cardsRow.trailingAnchor.constraint(equalTo: gamesPage.trailingAnchor),
            cardsRow.heightAnchor.constraint(equalToConstant: 64),

            heroStack.bottomAnchor.constraint(equalTo: cardsRow.topAnchor, constant: -14),
            heroStack.leadingAnchor.constraint(equalTo: gamesPage.leadingAnchor),
            heroStack.trailingAnchor.constraint(equalTo: gamesPage.trailingAnchor)
        ])
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
            if showToast { showRockstarToast("تم تفعيل وضع 24 FPS · توفير البطارية") }
        case 1:
            settings.frameRateCap = 30
            settings.graphicsPreset = .performance
            settings.renderHeight = 0
            if showToast { showRockstarToast("تم تفعيل وضع 30 FPS · متوازن (موصى به)") }
        case 2:
            settings.frameRateCap = 60
            settings.graphicsPreset = .performance
            settings.renderHeight = 0
            if showToast { showRockstarToast("تم تفعيل وضع 60 FPS · أداء عالي") }
        case 3:
            settings.frameRateCap = 60
            settings.graphicsPreset = .quality
            settings.renderHeight = 720
            if showToast { showRockstarToast("تم تفعيل وضع 720p · جودة فائقة") }
        default:
            if showToast { showRockstarToast("تم اختيار إعداداتك المخصصة (YOUR SETTINGS)") }
        }
    }

    // MARK: - Mods Page

    private func buildModsPage() {
        let card = Theme.panel(cornerRadius: 16)
        card.translatesAutoresizingMaskIntoConstraints = false
        modsPage.addSubview(card)

        let title = UILabel()
        title.text = "مدير المودات والإضافات (Mods)"
        title.font = Theme.display(20, .bold)
        title.textColor = Theme.text

        modsSummaryLabel.font = Theme.body(14)
        modsSummaryLabel.textColor = Theme.secondaryText
        modsSummaryLabel.numberOfLines = 2

        let openModsBtn = Theme.primaryButton("إدارة وتثبيت المودات", symbol: "shippingbox.fill")
        openModsBtn.addAction(UIAction { [weak self] _ in
            if let onOpenMods = self?.onOpenMods { onOpenMods() }
            else { self?.settingsButton.sendActions(for: .touchUpInside) }
        }, for: .touchUpInside)

        let importBtn = Theme.glassButton("استيراد مود (.zip)", symbol: "plus.circle.fill")
        importBtn.addAction(UIAction { [weak self] _ in self?.onImportZip?() }, for: .touchUpInside)

        let btns = UIStackView(arrangedSubviews: [openModsBtn, importBtn, UIView()])
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
        for mod in installed.prefix(4) {
            let row = UILabel()
            row.font = Theme.body(13, .medium)
            row.textColor = mod.enabled ? Theme.ok : Theme.tertiaryText
            row.text = (mod.enabled ? "● مفعّل: " : "○ متوقف: ") + mod.name
            modsListStack.addArrangedSubview(row)
        }
    }

    // MARK: - Data, Telemetry & 16 Save Slots Page

    private func buildDataPage(log: UIView) {
        let leftCol = UIStackView()
        leftCol.axis = .vertical
        leftCol.spacing = 10
        leftCol.translatesAutoresizingMaskIntoConstraints = false

        // Device Specs Card
        let specsPanel = Theme.panel(cornerRadius: 14)
        deviceSpecsLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        deviceSpecsLabel.textColor = Theme.text
        deviceSpecsLabel.numberOfLines = 0
        deviceSpecsLabel.translatesAutoresizingMaskIntoConstraints = false
        specsPanel.contentView.addSubview(deviceSpecsLabel)
        NSLayoutConstraint.activate([
            deviceSpecsLabel.topAnchor.constraint(equalTo: specsPanel.contentView.topAnchor, constant: 12),
            deviceSpecsLabel.bottomAnchor.constraint(equalTo: specsPanel.contentView.bottomAnchor, constant: -12),
            deviceSpecsLabel.leadingAnchor.constraint(equalTo: specsPanel.contentView.leadingAnchor, constant: 12),
            deviceSpecsLabel.trailingAnchor.constraint(equalTo: specsPanel.contentView.trailingAnchor, constant: -12)
        ])

        // 16 Save Slots Grid (4x4)
        let slotsTitle = UILabel()
        slotsTitle.text = "خانات الحفظ السريع (16 خانة)"
        slotsTitle.font = Theme.body(13, .bold)
        slotsTitle.textColor = Theme.accent

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
                btn.addAction(UIAction { [weak self] _ in
                    self?.selectSaveSlot(slotNum)
                }, for: .touchUpInside)
                saveSlotButtons.append(btn)
                hRow.addArrangedSubview(btn)
            }
            grid.addArrangedSubview(hRow)
        }

        let manageFilesBtn = Theme.glassButton("إدارة وفحص ملفات اللعبة", symbol: "folder.fill")
        manageFilesBtn.addAction(UIAction { [weak self] _ in self?.onFiles?() }, for: .touchUpInside)

        leftCol.addArrangedSubviews([specsPanel, slotsTitle, grid, manageFilesBtn])

        // Right Column: Live Engine Log
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
            btn.configuration?.baseBackgroundColor = active ? Theme.accent.withAlphaComponent(0.28) : UIColor(white: 1, alpha: 0.08)
            btn.configuration?.baseForegroundColor = active ? Theme.accent : Theme.text
        }
        showRockstarToast(String(format: "تم تحديد خانة الحفظ رقم %02d (Slot %02d)", slot, slot))
    }

    private func refreshDeviceTelemetry() {
        let free = (try? GameFolder.appFolder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage).flatMap { $0 }
        let freeText = free.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "غير معروف"
        let memMB = GameSettings.shared.tier.memoryLimitMB
        let filesText = GameFolder.isChosen ? "متوفرة (\(GameFolder.name))" : "غير محددة بعد"
        deviceSpecsLabel.text = """
        الجهاز: iOS \(UIDevice.current.systemVersion) · حد الذاكرة المتاح: \(memMB) MB
        المساحة الفارغة: \(freeText)
        حالة ملفات اللعبة: \(filesText)
        """
    }

    // MARK: - Settings Overview Page

    private func buildSettingsPage() {
        let card = Theme.panel(cornerRadius: 16)
        card.translatesAutoresizingMaskIntoConstraints = false
        settingsPage.addSubview(card)

        let title = UILabel()
        title.text = "إعدادات اللانشر واللعبة"
        title.font = Theme.display(20, .bold)
        title.textColor = Theme.text

        settingsLangLabel.font = Theme.body(14, .medium)
        settingsLangLabel.textColor = Theme.secondaryText

        settingsPerfLabel.font = Theme.body(14, .medium)
        settingsPerfLabel.textColor = Theme.secondaryText

        let openFullSettings = Theme.primaryButton("فتح الإعدادات الكاملة (الجرافيكس، الصوت، الشفرات)", symbol: "slider.horizontal.3")
        openFullSettings.addAction(UIAction { [weak self] _ in
            self?.settingsButton.sendActions(for: .touchUpInside)
        }, for: .touchUpInside)

        let openTouchEditor = Theme.glassButton("تخصيص أماكن أزرار اللمس (HUD)", symbol: "hand.tap.fill")
        openTouchEditor.addAction(UIAction { [weak self] _ in
            self?.layoutButton.sendActions(for: .touchUpInside)
        }, for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [openFullSettings, openTouchEditor, UIView()])
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
        settingsLangLabel.text = "ملف اللغة النشط: launcher_ar.json (\(AppLanguage.current.name))"
        settingsPerfLabel.text = "الجودة الحالية: \(s.graphicsPreset.title) · الإطارات: \(GameSettings.frameRateTitle(s.frameRateCap))"
    }

    // MARK: - Files Card & Rockstar Toast

    private func buildFilesCard() {
        let panel = Theme.panel(cornerRadius: 12)
        panel.isUserInteractionEnabled = false
        pin(panel, to: filesCard)

        filesIcon.contentMode = .scaleAspectFit
        filesIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        filesTitle.font = Theme.body(13, .bold)
        filesTitle.textColor = Theme.text
        filesDetail.font = Theme.body(11)
        filesDetail.textColor = Theme.secondaryText
        filesDetail.numberOfLines = 1

        let texts = UIStackView(arrangedSubviews: [filesTitle, filesDetail])
        texts.axis = .vertical
        texts.spacing = 1

        filesSpinner.color = Theme.accent
        let iconHolder = UIView()
        for v in [filesIcon, filesSpinner] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            iconHolder.addSubview(v)
            NSLayoutConstraint.activate([
                v.centerXAnchor.constraint(equalTo: iconHolder.centerXAnchor),
                v.centerYAnchor.constraint(equalTo: iconHolder.centerYAnchor)
            ])
        }
        iconHolder.widthAnchor.constraint(equalToConstant: 24).isActive = true

        let row = UIStackView(arrangedSubviews: [iconHolder, texts])
        row.spacing = 10
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        filesCard.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: filesCard.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: filesCard.trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: filesCard.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: filesCard.bottomAnchor, constant: -8)
        ])
        filesCard.addAction(UIAction { [weak self] _ in self?.onFiles?() }, for: .touchUpInside)
    }

    private func setupToastBanner() {
        toastBanner.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.11, alpha: 0.96)
        toastBanner.layer.cornerRadius = 12
        toastBanner.layer.borderWidth = 1
        toastBanner.layer.borderColor = Theme.accent.withAlphaComponent(0.6).cgColor
        toastBanner.alpha = 0
        toastBanner.isUserInteractionEnabled = false
        toastBanner.translatesAutoresizingMaskIntoConstraints = false

        let badge = UILabel()
        badge.text = "R★"
        badge.font = Theme.display(12, .black)
        badge.textColor = .black
        badge.backgroundColor = Theme.accent
        badge.textAlignment = .center
        badge.layer.cornerRadius = 5
        badge.clipsToBounds = true
        badge.widthAnchor.constraint(equalToConstant: 22).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 22).isActive = true

        toastLabel.font = Theme.body(12, .semibold)
        toastLabel.textColor = Theme.text

        let row = UIStackView(arrangedSubviews: [badge, toastLabel])
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        toastBanner.addSubview(row)
        addSubview(toastBanner)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: toastBanner.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: toastBanner.trailingAnchor, constant: -14),
            row.topAnchor.constraint(equalTo: toastBanner.topAnchor, constant: 7),
            row.bottomAnchor.constraint(equalTo: toastBanner.bottomAnchor, constant: -7),

            toastBanner.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 70),
            toastBanner.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -86)
        ])
    }

    private func showRockstarToast(_ message: String) {
        toastHideWork?.cancel()
        toastLabel.text = message
        UIView.animate(withDuration: 0.2) { self.toastBanner.alpha = 1 }
        let work = DispatchWorkItem { [weak self] in
            UIView.animate(withDuration: 0.35) { self?.toastBanner.alpha = 0 }
        }
        toastHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8, execute: work)
    }

    // MARK: - NativePortViewController Hooks

    func refreshLanguage() {
        playButton.configuration?.title = "تشغيل اللعبة"
        settingsButton.configuration?.title = nil
        layoutButton.configuration?.title = nil
        telegramButton.configuration?.title = nil
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
        case .busy: ("", Theme.text)
        }
        filesIcon.image = symbol.isEmpty ? nil : UIImage(systemName: symbol)
        filesIcon.tintColor = color
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

// MARK: - Sidebar Game Button

private final class SidebarGameButton: UIControl {
    private let icon = UIImageView()
    private let titleLabel = UILabel()
    private let subLabel = UILabel()
    private let labelsStack = UIStackView()
    private let indicator = UIView()

    init(title: String, subtitle: String, symbol: String) {
        super.init(frame: .zero)
        layer.cornerRadius = 10
        clipsToBounds = true

        indicator.backgroundColor = Theme.accent
        indicator.layer.cornerRadius = 1.5
        indicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(indicator)

        icon.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true

        titleLabel.text = title
        titleLabel.font = Theme.body(13, .bold)
        subLabel.text = subtitle
        subLabel.font = Theme.body(10, .medium)
        subLabel.textColor = Theme.tertiaryText

        labelsStack.addArrangedSubviews([titleLabel, subLabel])
        labelsStack.axis = .vertical
        labelsStack.spacing = 1
        labelsStack.isUserInteractionEnabled = false

        let row = UIStackView(arrangedSubviews: [icon, labelsStack])
        row.spacing = 10
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 46),
            indicator.leadingAnchor.constraint(equalTo: leadingAnchor),
            indicator.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            indicator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            indicator.widthAnchor.constraint(equalToConstant: 3),

            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            row.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        update()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func setExpanded(_ expanded: Bool) {
        labelsStack.isHidden = !expanded
    }

    override var isSelected: Bool { didSet { update() } }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.7 : 1 } }

    private func update() {
        backgroundColor = isSelected ? Theme.accent.withAlphaComponent(0.16) : UIColor(white: 1, alpha: 0.04)
        icon.tintColor = isSelected ? Theme.accent : Theme.secondaryText
        titleLabel.textColor = isSelected ? Theme.accent : Theme.text
        indicator.isHidden = !isSelected
    }
}

// MARK: - Horizontal Performance Preset Card

private final class PerformancePresetCard: UIControl {
    private let headlineLabel = UILabel()
    private let badgeLabel = UILabel()

    init(headline: String, badge: String) {
        super.init(frame: .zero)
        layer.cornerRadius = 11
        layer.cornerCurve = .continuous
        clipsToBounds = true

        headlineLabel.text = headline
        headlineLabel.font = Theme.display(14, .heavy)
        headlineLabel.textAlignment = .center
        headlineLabel.adjustsFontSizeToFitWidth = true
        headlineLabel.minimumScaleFactor = 0.7

        badgeLabel.text = badge
        badgeLabel.font = Theme.body(10, .semibold)
        badgeLabel.textAlignment = .center
        badgeLabel.adjustsFontSizeToFitWidth = true
        badgeLabel.minimumScaleFactor = 0.75

        let stack = UIStackView(arrangedSubviews: [headlineLabel, badgeLabel])
        stack.axis = .vertical
        stack.spacing = 3
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        update()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isSelected: Bool { didSet { update() } }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.75 : 1 } }

    private func update() {
        backgroundColor = isSelected ? Theme.accent.withAlphaComponent(0.20) : Theme.cardBg
        layer.borderWidth = isSelected ? 1.8 : 1
        layer.borderColor = (isSelected ? Theme.accent : Theme.panelStroke).cgColor
        headlineLabel.textColor = isSelected ? Theme.accent : Theme.text
        badgeLabel.textColor = isSelected ? Theme.text : Theme.secondaryText
    }
}

private extension UIStackView {
    func addArrangedSubviews(_ views: [UIView]) { views.forEach(addArrangedSubview) }
}
