import SwiftUI
#if SWIFT_PACKAGE
import ParcelCore
#endif

struct ContractBoardView: View {
    @Bindable var model: TycoonModel
    let packCustomer: (TycoonCustomer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("The contract board").font(.title2.bold())
                Text("Bigger jobs for \(model.account.progression.district.title). Take one at a time and finish at your own pace.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            if let active = model.account.progression.activeContract {
                contract(active, active: true)
            } else {
                ForEach(model.account.contractOffers, id: \.id) { offer in
                    contract(offer, active: false)
                }
                if model.account.contractOffers.isEmpty {
                    Text("Serve a customer here to find your next contract.")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                }
            }
            if let receipt = model.account.progression.lastContract {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Contract delivered", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.accent)
                    Text("\(receipt.title) · \(ProgressionCopy.money(receipt.reward)) banked")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func contract(_ job: TycoonContract, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: ProgressionCopy.contractSymbol(job.kind))
                    .font(.title2).foregroundStyle(Palette.accent)
                    .frame(width: 40, height: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.title).font(.headline)
                    Text("\(job.customer.title) · \(job.kind.title)")
                        .font(.caption.weight(.medium)).foregroundStyle(Palette.muted)
                }
            }
            Text(job.kind == .supply
                 ? "Ship \(job.target) orders yourself or let this customer's crew help."
                 : "Pack and ship \(job.target) orders yourself. No deadline; hints are welcome.")
                .font(.footnote).foregroundStyle(Palette.muted)
            if active {
                ProgressView(value: Double(job.progress), total: Double(max(1, job.target)))
                    .tint(Palette.accent)
                    .accessibilityLabel("\(job.title) contract progress")
                    .accessibilityValue("\(job.progress) of \(job.target) orders")
            }
            HStack(alignment: .firstTextBaseline) {
                Text(active ? "\(job.progress)/\(job.target) delivered" : "\(job.target) deliveries")
                    .font(.caption.weight(.medium)).foregroundStyle(Palette.muted)
                Spacer(minLength: 8)
                Text("+\(ProgressionCopy.money(job.reward))")
                    .font(.headline).monospacedDigit().foregroundStyle(Palette.accent)
            }
            if job.kind != .supply {
                Text(job.kind == .landmark
                     ? "Finish this landmark job to qualify for your next franchise."
                     : "Completion earns a permanent blueprint (+2% manual pay, up to +20%) and 12 boosted crew deliveries.")
                    .font(.caption).foregroundStyle(Palette.accent)
            }
            if active {
                Button { packCustomer(job.customer) } label: {
                    Label("Pack for \(job.customer.title)", systemImage: "shippingbox")
                }
                .buttonStyle(PillButtonStyle(filled: true))
                .accessibilityHint("Your current partial box asks for confirmation before switching customers.")
            } else {
                Button { model.acceptContract(job) } label: {
                    Text("Accept contract")
                }
                .buttonStyle(PillButtonStyle())
                .disabled(!model.account.canAcceptContract(job))
                .accessibilityLabel("Accept \(job.title), reward \(ProgressionCopy.money(job.reward))")
                .accessibilityHint("Accepting keeps your current packing box. The reward banks automatically on completion.")
            }
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(active ? Palette.accent : Palette.grid, lineWidth: active ? 2 : 1))
    }
}

struct PackingProgressView: View {
    let account: TycoonAccount
    let customer: TycoonCustomer
    var compact = false
    let viewContracts: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let job = account.progression.activeContract {
                Button(action: viewContracts) {
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(job.title).font(.caption.weight(.semibold))
                                .lineLimit(compact ? 1 : nil)
                            Text(job.customer == customer
                                 ? (compact ? "This box counts toward your contract" : "This shipment counts · \(job.progress)/\(job.target) delivered")
                                 : (compact ? "For \(job.customer.title)" : "For \(job.customer.title) · \(job.progress)/\(job.target) delivered"))
                                .font(.caption2).foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 4)
                        if compact {
                            Text("\(job.progress)/\(job.target)")
                                .font(.caption.weight(.semibold)).monospacedDigit()
                        }
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(job.title). \(job.progress) of \(job.target) delivered. View contract.")
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "bolt.circle").foregroundStyle(Palette.accent).accessibilityHidden(true)
                Text(compact
                     ? (account.progression.manualBoostOrders > 0
                        ? "\(account.progression.manualBoostOrders) crew deliveries boosted · +20% pay"
                        : "Each box boosts 2 crew deliveries (+20% pay)")
                     : (account.progression.manualBoostOrders > 0
                        ? "Crew dispatch boost: +20% pay for \(account.progression.manualBoostOrders) more deliveries. Your next box adds 2."
                        : "Every box you ship adds 2 crew deliveries at +20% pay."))
                    .font(.caption).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct WorldView: View {
    @Bindable var model: TycoonModel
    let viewDepot: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("A city to deliver").font(.title2.bold())
                Text("Build branches, meet new customers, and grow beyond your first depot. Every owned location keeps earning while you visit another.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            VStack(spacing: 0) {
                ForEach(Neighborhood.allCases, id: \.self) { neighborhood in
                    neighborhoodRow(neighborhood)
                    if neighborhood != Neighborhood.allCases.last { Divider().overlay(Palette.grid.opacity(0.5)) }
                }
            }
            headOffice
            franchise
            lifetimeRecord
            if !model.message.isEmpty {
                Text(model.message).font(.footnote.weight(.medium)).foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func neighborhoodRow(_ neighborhood: Neighborhood) -> some View {
        let selected = model.account.progression.district == neighborhood
        let unlocked = model.account.progression.franchises >= neighborhood.requiredFranchises
        let branch = model.account.progression.branches[neighborhood]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: unlocked ? ProgressionCopy.neighborhoodSymbol(neighborhood) : "lock")
                    .font(.title2).foregroundStyle(unlocked ? Palette.accent : Palette.muted)
                    .frame(width: 40, height: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(neighborhood.title).font(.headline)
                    Text(neighborhood.detail).font(.footnote).foregroundStyle(Palette.muted)
                    if selected {
                        Text("You're visiting here").font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
                    }
                }
            }
            if neighborhood == .oldTown {
                Text("Your main \(model.account.stage.title.lowercased()) · crew income continues everywhere")
                    .font(.caption).foregroundStyle(Palette.muted)
                visitButton(neighborhood, selected: selected)
            } else if let branch {
                HStack(alignment: .firstTextBaseline) {
                    Text("Branch level \(branch.level)/10").font(.caption.weight(.semibold))
                    Spacer(minLength: 8)
                    Text("\(ProgressionCopy.money(model.account.branchPayout(neighborhood)))/min")
                        .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(Palette.accent)
                }
                ProgressView(value: min(60, max(0, branch.progressSeconds)), total: 60)
                    .tint(Palette.accent)
                    .accessibilityLabel("\(neighborhood.title) branch shipping progress")
                visitButton(neighborhood, selected: selected)
                if let cost = model.account.branchCost(neighborhood) {
                    Button { model.upgradeBranch(neighborhood) } label: {
                        Text("Grow branch · \(ProgressionCopy.money(cost))")
                    }
                    .buttonStyle(PillButtonStyle())
                    .disabled(!model.account.canUpgradeBranch(neighborhood))
                    .accessibilityLabel("Upgrade \(neighborhood.title) branch to level \(branch.level + 1), \(ProgressionCopy.money(cost))")
                    if cost > model.account.cash {
                        Text("Save \(ProgressionCopy.money(cost - model.account.cash)) more to grow this branch.")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                } else {
                    Label("Branch fully grown", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
                }
            } else if !unlocked {
                Label("Unlocks after \(neighborhood.requiredFranchises) \(neighborhood.requiredFranchises == 1 ? "franchise" : "franchises")", systemImage: "star")
                    .font(.caption.weight(.medium)).foregroundStyle(Palette.muted)
                Text("\(model.account.progression.franchises)/\(neighborhood.requiredFranchises) franchises established")
                    .font(.caption).monospacedDigit().foregroundStyle(Palette.muted)
            } else if let cost = model.account.branchCost(neighborhood) {
                Text("Open a satellite branch for \(ProgressionCopy.money(cost)). It banks income automatically and brings local contracts.")
                    .font(.caption).foregroundStyle(Palette.muted)
                Button { model.openBranch(neighborhood) } label: {
                    Text("Open branch · \(ProgressionCopy.money(cost))")
                }
                .buttonStyle(PillButtonStyle())
                .disabled(!model.account.canOpenBranch(neighborhood))
                if model.account.stage != .hub {
                    Text("Grow your main depot into a Shipping hub first.").font(.caption).foregroundStyle(Palette.muted)
                } else if cost > model.account.cash {
                    Text("Save \(ProgressionCopy.money(cost - model.account.cash)) more to open here.")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
            }
        }
        .padding(.vertical, 16)
    }

    private func visitButton(_ neighborhood: Neighborhood, selected: Bool) -> some View {
        Button {
            if !selected { model.visitNeighborhood(neighborhood) }
            viewDepot()
        } label: {
            Label(selected ? "View depot" : "Visit \(neighborhood.title)", systemImage: "arrow.right")
        }
        .buttonStyle(PillButtonStyle(filled: selected))
        .disabled(!model.account.canVisit(neighborhood))
        .accessibilityHint("Your current packing box stays saved. Other depots keep working.")
    }

    private var headOffice: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Head Office").font(.title2.bold())
                Spacer(minLength: 8)
                Label("\(model.account.progression.stars)", systemImage: "star.fill")
                    .font(.headline).monospacedDigit().foregroundStyle(Palette.accent)
                    .accessibilityLabel("\(model.account.progression.stars) Franchise Stars available")
            }
            Text("Permanent improvements for every future depot. Spend Franchise Stars earned when you franchise.")
                .font(.subheadline).foregroundStyle(Palette.muted)
            if model.account.progression.franchises == 0 {
                Label("Opens after your first franchise", systemImage: "lock")
                    .font(.caption.weight(.medium)).foregroundStyle(Palette.muted)
            }
            ForEach(FranchiseUpgrade.allCases, id: \.self) { upgrade in
                let level = model.account.franchiseUpgradeLevel(upgrade)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(upgrade.title).font(.headline)
                        Spacer(minLength: 8)
                        Text("\(level)/5").font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                    }
                    Text(upgrade == .establishedBusiness
                         ? "On your next franchise: start with $250 per level and one Corner Market worker."
                         : upgrade.detail).font(.footnote).foregroundStyle(Palette.muted)
                    if let cost = model.account.franchiseUpgradeCost(upgrade) {
                        Button { model.buyFranchiseUpgrade(upgrade) } label: {
                            Label("Improve · \(cost) \(cost == 1 ? "Star" : "Stars")", systemImage: "star")
                        }
                        .buttonStyle(PillButtonStyle())
                        .disabled(!model.account.canBuyFranchiseUpgrade(upgrade))
                        .accessibilityLabel("Improve \(upgrade.title) to level \(level + 1), \(cost) Franchise Stars")
                    } else {
                        Label("Permanent upgrade complete", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var franchise: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Build your next franchise", systemImage: "building.2.crop.circle")
                .font(.title2.bold())
            Text("Start a fresh depot with your permanent advantages. Your customer trust and franchise network carry forward.")
                .font(.subheadline).foregroundStyle(Palette.muted)
            HStack(alignment: .firstTextBaseline) {
                Text("Reward at current earnings").font(.footnote)
                Spacer(minLength: 8)
                Label("\(model.account.franchiseReward) Stars", systemImage: "star.fill")
                    .font(.headline).monospacedDigit().foregroundStyle(Palette.accent)
            }
            Text(model.account.franchiseRequirement).font(.footnote.weight(.medium))
                .foregroundStyle(model.account.canFranchise ? Palette.accent : Palette.muted)
            if let target = model.account.nextFranchiseStarTarget {
                Text("Next earnings Star at \(ProgressionCopy.money(target)) earned this run · \(ProgressionCopy.money(max(0, target - model.account.totalEarned))) to go")
                    .font(.caption).foregroundStyle(Palette.muted)
                ProgressView(value: Double(min(model.account.totalEarned, target)), total: Double(max(1, target)))
                    .tint(Palette.accent).accessibilityLabel("Progress toward the next Franchise Star")
            }
            Text("Current cash, equipment, crew, branches, contracts and the packing box reset. Trust, blueprints, Stars, Head Office upgrades, lifetime records and unlocked districts stay.")
                .font(.caption).foregroundStyle(Palette.muted)
            Button { model.requestFranchise() } label: {
                Text("Review franchise · \(model.account.franchiseReward) Stars")
            }
            .buttonStyle(PillButtonStyle(filled: true))
            .disabled(!model.account.canFranchise)
            .accessibilityHint("Opens a review. Your business only resets after you confirm there.")
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.grid, lineWidth: 1))
    }

    private var lifetimeRecord: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your company story").font(.headline)
            Text("\(model.account.progression.franchises) franchises · \(model.account.progression.lifetimeContracts) contracts completed")
            Text("\(model.account.progression.lifetimeManualOrders) boxes packed by you · \(model.account.progression.lifetimeAutomatedOrders) crew and branch deliveries")
            Text("\(ProgressionCopy.money(model.account.progression.lifetimeEarned)) earned across every depot")
            Text("\(model.account.progression.blueprints)/10 permanent blueprints · +\(model.account.progression.blueprints * 2)% manual shipment pay")
        }
        .font(.caption).foregroundStyle(Palette.muted)
        .accessibilityElement(children: .combine)
    }
}

struct FranchiseReviewSheet: View {
    @Bindable var model: TycoonModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("\(model.account.franchiseReward) Franchise Stars", systemImage: "star.fill")
                            .font(.title2.bold()).foregroundStyle(Palette.accent)
                        Text("Establish franchise \(model.account.progression.franchises + 1) and return to a fresh Spare room. Your reward is based on this run's earnings and landmark contracts; spending cash doesn't reduce it.")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                    }
                    reviewSection("Starts fresh", symbol: "arrow.counterclockwise", items: [
                        "\(ProgressionCopy.money(model.account.cash)) current cash and this run's earnings",
                        "Your building and every equipment level",
                        "Hired workers, managers, and satellite branches",
                        "Active contracts and remaining dispatch boosts",
                        "Your current packing box and delivery receipt"
                    ])
                    reviewSection("Stays with your company", symbol: "checkmark.seal", items: [
                        "Customer trust and relationship levels",
                        "\(model.account.progression.blueprints) permanent blueprints (+\(model.account.progression.blueprints * 2)% manual pay)",
                        "\(model.account.progression.stars) existing Stars, plus \(model.account.franchiseReward) new Stars",
                        "Every purchased Head Office upgrade",
                        "Lifetime earnings, deliveries, and contract records",
                        "Franchise count and unlocked neighborhoods"
                    ])
                    if model.account.franchiseUpgradeLevel(.establishedBusiness) > 0 {
                        let level = model.account.franchiseUpgradeLevel(.establishedBusiness)
                        Label("Your starter package: \(ProgressionCopy.money(250 * level)) and one Corner Market worker.", systemImage: "shippingbox")
                            .font(.footnote.weight(.medium)).foregroundStyle(Palette.accent)
                    }
                    Text(model.account.franchiseRequirement).font(.footnote).foregroundStyle(Palette.muted)
                    Button { model.confirmFranchise() } label: {
                        Text("Start fresh · earn \(model.account.franchiseReward) Stars")
                    }
                    .buttonStyle(PillButtonStyle(filled: true))
                    .disabled(!model.account.canFranchise)
                    .accessibilityHint("Resets the listed parts of this business and saves your new franchise immediately.")
                    Button("Keep growing this depot") { model.cancelFranchise() }
                        .buttonStyle(PillButtonStyle())
                }
                .padding(20)
                .frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .background(Palette.background)
            .navigationTitle("Franchise review")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { model.cancelFranchise() }
                }
            }
        }
        .foregroundStyle(Palette.ink).fontDesign(.rounded).tint(Palette.accent)
    }

    private func reviewSection(_ title: String, symbol: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.headline)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle.fill").font(.system(size: 4)).padding(.top, 7).accessibilityHidden(true)
                    Text(item).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Palette.muted)
            }
        }
    }
}

enum ProgressionCopy {
    static func money(_ value: Int) -> String { "$\(value.formatted())" }
    static func contractSymbol(_ kind: ContractKind) -> String {
        switch kind {
        case .supply: "shippingbox"
        case .premium: "sparkles"
        case .landmark: "flag.checkered"
        }
    }
    static func neighborhoodSymbol(_ neighborhood: Neighborhood) -> String {
        switch neighborhood {
        case .oldTown: "house"
        case .harbor: "sailboat"
        case .artsQuarter: "paintpalette"
        case .uptown: "building.2"
        }
    }
}
