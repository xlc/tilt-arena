import UIKit

/// Owns the loading artwork and its short presentation lifecycle.
final class GameLoadingOverlayView: UIView {
    private static let assetName = "LoadingScreen"
    private static let minimumDisplayDuration: CFTimeInterval = 0.75

    private var installedAt: CFTimeInterval?
    private var isHiding = false

    private init(compatibleWith traitCollection: UITraitCollection) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .black
        isUserInteractionEnabled = false
        accessibilityIdentifier = "game-loading-screen"

        let imageView = makeLoadingImageView(compatibleWith: traitCollection)
        let scrimView = makeLoadingScrimView()
        let stackView = makeLoadingStackView()
        for subview in [imageView, scrimView, stackView] {
            addSubview(subview)
        }
        activateContentConstraints(imageView: imageView, scrimView: scrimView, stackView: stackView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("GameLoadingOverlayView does not support storyboard initialization.")
    }

    static func install(
        in containerView: UIView,
        compatibleWith traitCollection: UITraitCollection
    ) -> GameLoadingOverlayView {
        let overlayView = GameLoadingOverlayView(compatibleWith: traitCollection)
        containerView.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: containerView.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        overlayView.installedAt = CACurrentMediaTime()
        return overlayView
    }

    func hideWhenReady() {
        guard !isHiding, let installedAt else {
            return
        }

        let elapsed = CACurrentMediaTime() - installedAt
        let delay = max(0, Self.minimumDisplayDuration - elapsed)
        isHiding = true

        UIView.animate(
            withDuration: 0.25,
            delay: delay,
            options: [.beginFromCurrentState, .curveEaseOut],
            animations: {
                self.alpha = 0
            },
            completion: { [weak self] _ in
                self?.removeFromSuperview()
                self?.installedAt = nil
                self?.isHiding = false
            }
        )
    }

    private func makeLoadingImageView(compatibleWith traitCollection: UITraitCollection) -> UIImageView {
        let image = UIImage(
            named: Self.assetName,
            in: Bundle(for: Self.self),
            compatibleWith: traitCollection
        )
        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }

    private func makeLoadingScrimView() -> UIView {
        let scrimView = UIView()
        scrimView.translatesAutoresizingMaskIntoConstraints = false
        scrimView.backgroundColor = UIColor.black.withAlphaComponent(0.26)
        return scrimView
    }

    private func makeLoadingStackView() -> UIStackView {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = UIColor(red: 0.18, green: 0.86, blue: 1, alpha: 1)
        spinner.startAnimating()

        let stackView = UIStackView(arrangedSubviews: [
            makeLoadingTitleLabel(),
            makeLoadingLabel(),
            spinner
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 8
        return stackView
    }

    private func makeLoadingTitleLabel() -> UILabel {
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 34, weight: .heavy)
        titleLabel.text = "TILT ARENA"
        titleLabel.textAlignment = .center
        titleLabel.textColor = .white
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.65
        titleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 420).isActive = true
        return titleLabel
    }

    private func makeLoadingLabel() -> UILabel {
        let loadingLabel = UILabel()
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        loadingLabel.text = "LOADING"
        loadingLabel.textAlignment = .center
        loadingLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        return loadingLabel
    }

    private func activateContentConstraints(
        imageView: UIView,
        scrimView: UIView,
        stackView: UIView
    ) {
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            scrimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrimView.topAnchor.constraint(equalTo: topAnchor),
            scrimView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: -26
            ),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])
    }
}
