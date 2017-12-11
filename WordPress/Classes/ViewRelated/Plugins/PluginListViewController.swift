import UIKit
import WordPressKit
import WordPressFlux

class PluginListViewController: UITableViewController, ImmuTablePresenter {
    let site: JetpackSiteRef

    fileprivate var viewModel: PluginListViewModel
    fileprivate var tableViewModel = ImmuTable.Empty

    fileprivate let noResultsView = WPNoResultsView()
    var viewModelReceipt: Receipt?

    init(site: JetpackSiteRef, store: PluginStore = StoreContainer.shared.plugin) {
        self.site = site
        viewModel = PluginListViewModel(site: site, store: store)

        super.init(style: .grouped)

        title = NSLocalizedString("Plugins", comment: "Title for the plugin manager")
        noResultsView.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc convenience init?(blog: Blog) {
        guard let site = JetpackSiteRef(blog: blog) else {
            return nil
        }

        self.init(site: site)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        WPStyleGuide.configureColors(for: view, andTableView: tableView)
        ImmuTable.registerRows(PluginListViewModel.immutableRows, tableView: tableView)
        viewModelReceipt = viewModel.onStateChange { [weak self] (change) in
            self?.refreshModel(change: change)
        }
        refreshModel(change: .replace)
    }

    func updateNoResults() {
        if let noResultsViewModel = viewModel.noResultsViewModel {
            showNoResults(noResultsViewModel)
        } else {
            hideNoResults()
        }
    }

    func showNoResults(_ viewModel: WPNoResultsView.Model) {
        noResultsView.bindViewModel(viewModel)
        if noResultsView.isDescendant(of: tableView) {
            noResultsView.centerInSuperview()
        } else {
            tableView.addSubview(withFadeAnimation: noResultsView)
        }
    }

    func hideNoResults() {
        noResultsView.removeFromSuperview()
    }

    func refreshModel(change: PluginListViewModel.StateChange) {
        updateNoResults()
        tableViewModel = viewModel.tableViewModel(presenter: self)
        switch change {
        case .replace:
            tableView.reloadData()
        case .selective(let changedRows):
            let indexPaths = changedRows.map({ IndexPath(row: $0, section: 0) })
            tableView.reloadRows(at: indexPaths, with: .none)
        }
    }
}

// MARK: - Table View Data Source
extension PluginListViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return tableViewModel.sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableViewModel.sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = tableViewModel.rowAtIndexPath(indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: row.reusableIdentifier, for: indexPath)

        row.configureCell(cell)

        return cell
    }
}

// MARK: - Table View Delegate
extension PluginListViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = tableViewModel.rowAtIndexPath(indexPath)
        row.action?(row)
    }
}

// MARK: - WPNoResultsViewDelegate

extension PluginListViewController: WPNoResultsViewDelegate {
    func didTap(_ noResultsView: WPNoResultsView!) {
        let supportVC = SupportViewController()
        supportVC.showFromTabBar()
    }
}

// MARK: - PluginPresenter

extension PluginListViewController: PluginPresenter {
    func present(plugin: Plugin, capabilities: SitePluginCapabilities) {
        let controller = PluginViewController(plugin: plugin, capabilities: capabilities, site: site)
        navigationController?.pushViewController(controller, animated: true)
    }
}
