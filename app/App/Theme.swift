import UIKit

/// Rockstar Games Launcher dark obsidian & gold/amber theme.
enum Theme {
    static let telegramURL = URL(string: "https://t.me/fivestarport")!
    static let appVersion: String = {
        let info = Bundle.main.infoDictionary
        return "v\(info?["CFBundleShortVersionString"] as? String ?? "?")" + (isLite ? " Lite" : "")
    }()
    static let isLite: Bool = (Bundle.main.object(forInfoDictionaryKey: "PGLiteMode") as? Bool ?? false)
        || (ProcessInfo.processInfo.environment["PG_LITE"].map { $0 != "0" } ?? false)

    // Rockstar Gold / Amber accents & Obsidian surfaces
    static let accent = UIColor(red: 0.98, green: 0.68, blue: 0.14, alpha: 1)        // Rockstar Gold
    static let accentDeep = UIColor(red: 0.85, green: 0.50, blue: 0.06, alpha: 1)
    static let ok = UIColor(red: 0.25, green: 0.85, blue: 0.48, alpha: 1)
    static let warning = UIColor(red: 1.0, green: 0.78, blue: 0.22, alpha: 1)
    static let problem = UIColor(red: 0.96, green: 0.34, blue: 0.34, alpha: 1)
    static let text = UIColor.white
    static let secondaryText = UIColor(white: 1, alpha: 0.72)
    static let tertiaryText = UIColor(white: 1, alpha: 0.46)
    static let night = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1)
    static let sidebarBg = UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 0.96)
    static let cardBg = UIColor(red: 0.10, green: 0.10, blue: 0.13, alpha: 0.88)
    static let panelStroke = UIColor(white: 1, alpha: 0.14)

    static func display(_ size: CGFloat, _ weight: UIFont.Weight = .heavy) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        return UIFont(descriptor: descriptor, size: size)
    }
    static func body(_ size: CGFloat = 15, _ weight: UIFont.Weight = .regular) -> UIFont {
        .systemFont(ofSize: size, weight: weight)
    }

    static func panel(cornerRadius: CGFloat = 18) -> UIVisualEffectView {
        let panel = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        panel.layer.cornerRadius = cornerRadius
        panel.layer.cornerCurve = .continuous
        panel.clipsToBounds = true
        panel.layer.borderWidth = 1
        panel.layer.borderColor = panelStroke.cgColor
        return panel
    }

    static func backdrop(image name: String, darken: CGFloat = 0.65) -> UIView {
        let view = UIView()
        view.backgroundColor = night
        let art = UIImageView(image: UIImage(named: name))
        art.contentMode = .scaleAspectFill
        art.clipsToBounds = true
        let shade = GradientView(
            colors: [night.withAlphaComponent(0.95), night.withAlphaComponent(darken), night.withAlphaComponent(0.45)],
            locations: [0, 0.5, 1],
            horizontal: true
        )
        let floor = GradientView(
            colors: [.clear, night.withAlphaComponent(0.92)],
            locations: [0.35, 1],
            horizontal: false
        )
        for layer in [art, shade, floor] as [UIView] {
            layer.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(layer)
            NSLayoutConstraint.activate([
                layer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                layer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                layer.topAnchor.constraint(equalTo: view.topAnchor),
                layer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        view.isUserInteractionEnabled = false
        return view
    }

    static func dimmedBackdrop(image name: String) -> UIView {
        let view = UIView()
        view.backgroundColor = night
        let art = UIImageView(image: UIImage(named: name))
        art.contentMode = .scaleAspectFill
        art.clipsToBounds = true
        let shade = UIView()
        shade.backgroundColor = night.withAlphaComponent(0.84)
        for layer in [art, shade] {
            layer.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(layer)
            NSLayoutConstraint.activate([
                layer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                layer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                layer.topAnchor.constraint(equalTo: view.topAnchor),
                layer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        view.isUserInteractionEnabled = false
        return view
    }

    static func styleSettingsTable(_ table: UITableView) {
        table.backgroundColor = night
        table.backgroundView = dimmedBackdrop(image: "SettingsBackground")
        table.separatorColor = UIColor(white: 1, alpha: 0.1)
    }

    static let rowBackground = UIColor(white: 1, alpha: 0.07)
    static let rowSelected = UIColor(white: 1, alpha: 0.14)

    static func primaryButton(_ title: String, symbol: String? = nil) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = symbol.map { UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(weight: .heavy)) } ?? nil
        config.imagePadding = 10
        config.cornerStyle = .medium
        config.baseForegroundColor = UIColor(red: 0.08, green: 0.05, blue: 0.01, alpha: 1)
        config.background.backgroundColor = accent
        config.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 26, bottom: 13, trailing: 26)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = display(18, .heavy)
            return attributes
        }
        let button = UIButton(configuration: config)
        button.configurationUpdateHandler = { button in
            button.configuration?.background.backgroundColor = button.isEnabled
                ? (button.isHighlighted ? accentDeep : accent)
                : UIColor(white: 1, alpha: 0.14)
            button.configuration?.baseForegroundColor = button.isEnabled
                ? UIColor(red: 0.08, green: 0.05, blue: 0.01, alpha: 1)
                : UIColor(white: 1, alpha: 0.55)
        }
        button.layer.shadowColor = accent.cgColor
        button.layer.shadowOpacity = 0.35
        button.layer.shadowRadius = 14
        button.layer.shadowOffset = .zero
        return button
    }

    static func glassButton(_ title: String, symbol: String) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.title = title
        config.image = UIImage(systemName: symbol)
        config.imagePadding = 8
        config.cornerStyle = .medium
        config.baseForegroundColor = text
        config.background.backgroundColor = UIColor(white: 1, alpha: 0.11)
        config.background.strokeColor = panelStroke
        config.background.strokeWidth = 1
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = body(14, .semibold)
            return attributes
        }
        return UIButton(configuration: config)
    }

    static func styleNavigation(_ navigation: UINavigationController) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.titleTextAttributes = [.foregroundColor: text, .font: display(18, .bold)]
        appearance.largeTitleTextAttributes = [.foregroundColor: text, .font: display(30, .heavy)]
        navigation.navigationBar.standardAppearance = appearance
        navigation.navigationBar.scrollEdgeAppearance = appearance
        navigation.navigationBar.compactAppearance = appearance
        navigation.navigationBar.tintColor = accent
        navigation.overrideUserInterfaceStyle = .dark
        navigation.view.tintColor = accent
    }
}

final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    init(colors: [UIColor], locations: [NSNumber], horizontal: Bool) {
        super.init(frame: .zero)
        let gradient = layer as! CAGradientLayer
        gradient.colors = colors.map(\.cgColor)
        gradient.locations = locations
        gradient.startPoint = horizontal ? CGPoint(x: 0, y: 0.5) : CGPoint(x: 0.5, y: 0)
        gradient.endPoint = horizontal ? CGPoint(x: 1, y: 0.5) : CGPoint(x: 0.5, y: 1)
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}
