import SwiftUI
import UIKit

/// LAST CALL's native tab-bar treatment: near-black, edge-to-edge, quiet labels,
/// warm white navigation icons and a bright centre compose action.
final class LastCallTabBarAppearanceInstaller {
  static func install() {
    let appearance = UITabBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = UIColor(red: 0.025, green: 0.025, blue: 0.022, alpha: 0.98)
    appearance.shadowColor = UIColor(white: 1, alpha: 0.10)

    let normal = appearance.stackedLayoutAppearance.normal
    normal.iconColor = UIColor(white: 0.62, alpha: 1)
    normal.titleTextAttributes = [
      .foregroundColor: UIColor(white: 0.62, alpha: 1),
      .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
    ]

    let selected = appearance.stackedLayoutAppearance.selected
    selected.iconColor = UIColor.white
    selected.titleTextAttributes = [
      .foregroundColor: UIColor.white,
      .font: UIFont.systemFont(ofSize: 10, weight: .bold)
    ]

    UITabBar.appearance().standardAppearance = appearance
    if #available(iOS 15.0, *) {
      UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    UITabBar.appearance().tintColor = .white
    UITabBar.appearance().unselectedItemTintColor = UIColor(white: 0.62, alpha: 1)
  }
}

private struct LastCallTabBarBootstrap: ViewModifier {
  func body(content: Content) -> some View {
    content.onAppear {
      LastCallTabBarAppearanceInstaller.install()
    }
  }
}

extension View {
  func installLastCallTabBarAppearance() -> some View {
    modifier(LastCallTabBarBootstrap())
  }
}
