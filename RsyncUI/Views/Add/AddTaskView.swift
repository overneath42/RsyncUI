//
//  AddTaskView.swift
//  RsyncUI
//
//  Created by Thomas Evensen on 11/12/2023.
//

import SwiftUI

// MARK: - Types and Enums

enum AddTaskDestinationView: String, Identifiable, CaseIterable {
    case homecatalogs
    case globalchanges
    
    var id: String { rawValue }
}

struct AddTasks: Hashable, Identifiable {
    let id = UUID()
    let task: AddTaskDestinationView
}

enum AddConfigurationField: Hashable, CaseIterable {
    case localcatalogField
    case remotecatalogField
    case remoteuserField
    case remoteserverField
    case synchronizeIDField
    case snapshotnumField
}

enum TypeofTask: String, CaseIterable, Identifiable, CustomStringConvertible {
    case synchronize
    case snapshot
    case syncremote

    var id: String { rawValue }
    var description: String { rawValue.localizedLowercase }
}

// MARK: - Main View

struct AddTaskView: View {
    // MARK: - Properties
    
    @Bindable var rsyncUIdata: RsyncUIconfigurations
    @Binding var selecteduuids: Set<SynchronizeConfiguration.ID>
    @Binding var addtaskpath: [AddTasks]

    @State private var newdata = ObservableAddConfigurations()
    @State private var selectedconfig: SynchronizeConfiguration?
    @State private var changesnapshotnum = false
    @State private var confirmcopyandpaste = false
    @State private var stringverify = ""
    @State private var stringestimate = ""
    @State private var showhelp = false

    @FocusState private var focusField: AddConfigurationField?

    // MARK: - Constants
    
    private let leftColumnWidth: CGFloat = 375
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $addtaskpath) {
            HStack(spacing: StyleConstants.paddingBase) {
                leftColumn
                rightColumn
            }
        }
        .sheet(isPresented: $showhelp) {
            helpSheet
        }
        .onSubmit {
            handleFormSubmission()
        }
        .onAppear {
            handleViewAppearance()
        }
        .onChange(of: rsyncUIdata.profile) {
            handleProfileChange()
        }
        .toolbar {
            toolbarContent
        }
        .navigationTitle("Add and Update Tasks")
        .navigationSubtitle("Profile: \(rsyncUIdata.profile ?? "Default")")
        .navigationDestination(for: AddTasks.self) { task in
            makeDestinationView(for: task.task)
        }
        .padding()
    }
}

// MARK: - View Components

private extension AddTaskView {
    
    var leftColumn: some View {
        VStack(alignment: .leading, spacing: StyleConstants.paddingBase) {
            taskTypeAndOptionsSection
            synchronizeIDSection
            catalogSection
            remoteParametersSection
            snapshotSection
            actionButton
            Spacer()
            urlSection
        }
        .frame(width: leftColumnWidth)
    }
    
    var rightColumn: some View {
        VStack(alignment: .leading) {
            headerSection
            tasksList
        }
    }
    
    var taskTypeAndOptionsSection: some View {
        HStack {
            taskTypePicker
                .disabled(selectedconfig != nil)
            
            VStack(alignment: .leading) {
                ToggleViewDefault(
                    text: NSLocalizedString("Don´t add /", comment: ""),
                    binding: $newdata.donotaddtrailingslash
                )
            }
        }
        .frame(width: leftColumnWidth, alignment: .leading)
    }
    
    var synchronizeIDSection: some View {
        VStack {
            synchronizeIDContent
        }
        .frame(width: leftColumnWidth, alignment: .leading)
    }
    
    var catalogSection: some View {
        Group {
            if newdata.selectedrsynccommand == .syncremote {
                VStack(alignment: .leading) {
                    localAndRemoteCatalogSyncRemote
                }
                .frame(width: leftColumnWidth)
            } else {
                VStack(alignment: .leading) {
                    localAndRemoteCatalog
                }
                .frame(width: leftColumnWidth)
                .disabled(selectedconfig?.task == SharedReference.shared.snapshot)
            }
        }
    }
    
    var remoteParametersSection: some View {
        VStack(alignment: .leading) {
            remoteUserAndServer
        }
        .frame(width: leftColumnWidth)
        .disabled(selectedconfig?.task == SharedReference.shared.snapshot)
    }
    
    var snapshotSection: some View {
        Group {
            if selectedconfig?.task == SharedReference.shared.snapshot {
                VStack(alignment: .leading) {
                    snapshotNumberContent
                }
                .frame(width: leftColumnWidth)
            }
        }
    }
    
    var actionButton: some View {
        Group {
            if newdata.selectedconfig != nil {
                Button("Update") {
                    validateAndUpdate()
                }
                .buttonStyle(ColorfulButtonStyle())
                .help("Update task")
            } else {
                Button("Add") {
                    addConfiguration()
                }
                .buttonStyle(ColorfulButtonStyle())
                .help("Add task")
            }
        }
    }
    
    var urlSection: some View {
        Group {
            if let selectedconfig = selectedconfig,
               selectedconfig.task == SharedReference.shared.synchronize {
                VStack(alignment: .leading) {
                    urlEstimateSection
                    urlVerifySection
                }
            }
        }
    }
    
    var headerSection: some View {
        Group {
            if deleteparameterpresent {
                HStack {
                    Text("Tasks for Synchronize actions.")
                    Text("If \(Text("red Synchronize ID").foregroundColor(.red)) click")
                    helpButton(helpTextIndex: 1)
                    Text("for more information.")
                }
                .padding(.bottom, 10)
            } else {
                HStack {
                    Text("Tasks for Synchronize actions.")
                    Text("To add --delete click")
                    helpButton(helpTextIndex: 2)
                    Text("for more information.")
                }
                .padding(.bottom, 10)
            }
        }
    }
    
    var tasksList: some View {
        ListofTasksAddView(rsyncUIdata: rsyncUIdata, selecteduuids: $selecteduuids)
            .onChange(of: selecteduuids) {
                handleSelectedTaskChange()
            }
            .copyable(copyItems.filter { selecteduuids.contains($0.id) })
            .pasteDestination(for: CopyItem.self) { items in
                handlePasteDestination(items)
            } validator: { items in
                items.filter { $0.task != SharedReference.shared.snapshot }
            }
            .confirmationDialog(
                Text("Copy ^[\(newdata.copyandpasteconfigurations?.count ?? 0) configuration](inflect: true)"),
                isPresented: $confirmcopyandpaste
            ) {
                Button("Copy") {
                    handleCopyConfirmation()
                }
            }
    }
}

// MARK: - Form Components

private extension AddTaskView {
    
    var taskTypePicker: some View {
        Picker(NSLocalizedString("Action", comment: "") + ":", selection: $newdata.selectedrsynccommand) {
            ForEach(TypeofTask.allCases) {
                Text($0.description).tag($0)
            }
            .onChange(of: newdata.selectedconfig) {
                newdata.selectedrsynccommand = selectPickerValue
            }
        }
        .pickerStyle(DefaultPickerStyle())
        .frame(width: 160)
    }
    
    var synchronizeIDContent: some View {
        Section(header: synchronizeIDHeader) {
            if newdata.selectedconfig == nil {
                setIDField
            } else {
                EditValue(leftColumnWidth, nil, $newdata.backupID)
                    .focused($focusField, equals: .synchronizeIDField)
                    .textContentType(.none)
                    .submitLabel(.continue)
                    .onAppear {
                        if let id = newdata.selectedconfig?.backupID {
                            newdata.backupID = id
                        }
                    }
            }
        }
    }
    
    var localAndRemoteCatalog: some View {
        Section(header: headerLocalRemote) {
            HStack {
                localCatalogField
                catalogOpenButton(for: $newdata.localcatalog)
            }
            HStack {
                remoteCatalogField
                catalogOpenButton(for: $newdata.remotecatalog)
            }
        }
        .frame(width: leftColumnWidth)
    }
    
    var localAndRemoteCatalogSyncRemote: some View {
        Section(header: headerLocalRemote) {
            HStack {
                remoteCatalogSyncRemoteField
                catalogOpenButton(for: $newdata.remotecatalog)
            }
            HStack {
                localCatalogSyncRemoteField
                catalogOpenButton(for: $newdata.localcatalog)
            }
        }
        .frame(width: leftColumnWidth)
    }
    
    var remoteUserAndServer: some View {
        Section(header: headerRemote) {
            HStack {
                remoteUserField
                remoteServerField
            }
        }
    }
    
    var snapshotNumberContent: some View {
        Section(header: snapshotNumberHeader) {
            EditValue(leftColumnWidth, nil, $newdata.snapshotnum)
                .focused($focusField, equals: .snapshotnumField)
                .textContentType(.none)
                .submitLabel(.return)
                .disabled(!changesnapshotnum)
            
            ToggleViewDefault(
                text: NSLocalizedString("Change snapshotnumber", comment: ""),
                binding: $changesnapshotnum
            )
        }
    }
}

// MARK: - Field Components

private extension AddTaskView {
    
    var setIDField: some View {
        EditValue(
            leftColumnWidth,
            NSLocalizedString("Add synchronize ID", comment: ""),
            $newdata.backupID
        )
        .focused($focusField, equals: .synchronizeIDField)
        .textContentType(.none)
        .submitLabel(.continue)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    var localCatalogField: some View {
        Group {
            if newdata.selectedconfig == nil {
                setLocalCatalogField
            } else {
                EditValue(leftColumnWidth * 0.9, nil, $newdata.localcatalog)
                    .focused($focusField, equals: .localcatalogField)
                    .textContentType(.none)
                    .submitLabel(.continue)
                    .onAppear {
                        if let catalog = newdata.selectedconfig?.localCatalog {
                            newdata.localcatalog = catalog
                        }
                    }
            }
        }
    }
    
    var remoteCatalogField: some View {
        Group {
            if newdata.selectedconfig == nil {
                setRemoteCatalogField
            } else {
                EditValue(leftColumnWidth * 0.9, nil, $newdata.remotecatalog)
                    .focused($focusField, equals: .remotecatalogField)
                    .textContentType(.none)
                    .submitLabel(.continue)
                    .onAppear {
                        if let catalog = newdata.selectedconfig?.offsiteCatalog {
                            newdata.remotecatalog = catalog
                        }
                    }
            }
        }
    }
    
    var localCatalogSyncRemoteField: some View {
        Group {
            if newdata.selectedconfig == nil {
                setLocalCatalogSyncRemoteField
            } else {
                EditValue(leftColumnWidth * 0.9, nil, $newdata.localcatalog)
                    .focused($focusField, equals: .localcatalogField)
                    .textContentType(.none)
                    .submitLabel(.continue)
                    .onAppear {
                        if let catalog = newdata.selectedconfig?.localCatalog {
                            newdata.localcatalog = catalog
                        }
                    }
            }
        }
    }
    
    var remoteCatalogSyncRemoteField: some View {
        Group {
            if newdata.selectedconfig == nil {
                setRemoteCatalogSyncRemoteField
            } else {
                EditValue(leftColumnWidth * 0.9, nil, $newdata.remotecatalog)
                    .focused($focusField, equals: .remotecatalogField)
                    .textContentType(.none)
                    .submitLabel(.continue)
                    .onAppear {
                        if let catalog = newdata.selectedconfig?.offsiteCatalog {
                            newdata.remotecatalog = catalog
                        }
                    }
            }
        }
    }
    
    var remoteUserField: some View {
        Group {
            if newdata.selectedconfig == nil {
                setRemoteUserField
            } else {
                EditValue(leftColumnWidth * 0.4, nil, $newdata.remoteuser)
                    .focused($focusField, equals: .remoteuserField)
                    .textContentType(.none)
                    .submitLabel(.continue)
                    .onAppear {
                        if let user = newdata.selectedconfig?.offsiteUsername {
                            newdata.remoteuser = user
                        }
                    }
            }
        }
    }
    
    var remoteServerField: some View {
        Group {
            if newdata.selectedconfig == nil {
                setRemoteServerField
            } else {
                EditValue(leftColumnWidth * 0.6, nil, $newdata.remoteserver)
                    .focused($focusField, equals: .remoteserverField)
                    .textContentType(.none)
                    .submitLabel(.return)
                    .onAppear {
                        if let server = newdata.selectedconfig?.offsiteServer {
                            newdata.remoteserver = server
                        }
                    }
            }
        }
    }
    
    // Base field implementations
    
    var setLocalCatalogField: some View {
        EditValue(
            leftColumnWidth * 0.9,
            NSLocalizedString("Add Local Folder (required)", comment: ""),
            $newdata.localcatalog
        )
        .focused($focusField, equals: .localcatalogField)
        .textContentType(.none)
        .submitLabel(.continue)
    }
    
    var setRemoteCatalogField: some View {
        EditValue(
            leftColumnWidth * 0.9,
            NSLocalizedString("Add Remote Folder (required)", comment: ""),
            $newdata.remotecatalog
        )
        .focused($focusField, equals: .remotecatalogField)
        .textContentType(.none)
        .submitLabel(.continue)
    }
    
    var setLocalCatalogSyncRemoteField: some View {
        EditValue(
            leftColumnWidth * 0.9,
            NSLocalizedString("Add Remote Folder (required)", comment: ""),
            $newdata.localcatalog
        )
        .focused($focusField, equals: .localcatalogField)
        .textContentType(.none)
        .submitLabel(.continue)
    }
    
    var setRemoteCatalogSyncRemoteField: some View {
        EditValue(
            leftColumnWidth * 0.9,
            NSLocalizedString("Add Local Folder (required)", comment: ""),
            $newdata.remotecatalog
        )
        .focused($focusField, equals: .remotecatalogField)
        .textContentType(.none)
        .submitLabel(.continue)
    }
    
    var setRemoteUserField: some View {
        EditValue(
            leftColumnWidth * 0.4,
            NSLocalizedString("Remote user", comment: ""),
            $newdata.remoteuser
        )
        .focused($focusField, equals: .remoteuserField)
        .textContentType(.none)
        .submitLabel(.continue)
    }
    
    var setRemoteServerField: some View {
        EditValue(
            leftColumnWidth * 0.6,
            NSLocalizedString("Remote server", comment: ""),
            $newdata.remoteserver
        )
        .focused($focusField, equals: .remoteserverField)
        .textContentType(.none)
        .submitLabel(.return)
    }
}

// MARK: - Headers and UI Components

private extension AddTaskView {
    
    var headerLocalRemote: some View {
        Text("Folder Parameters")
            .modifier(FixedTag(leftColumnWidth, .leading))
    }
    
    var synchronizeIDHeader: some View {
        Text("Synchronize ID")
            .modifier(FixedTag(leftColumnWidth, .leading))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    var snapshotNumberHeader: some View {
        Text("Snapshotnumber")
            .modifier(FixedTag(200, .leading))
    }
    
    var headerRemote: some View {
        Text("Remote Parameters")
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    func catalogOpenButton(for binding: Binding<String>) -> some View {
        OpencatalogView(selecteditem: binding, catalogs: true)
            .frame(width: leftColumnWidth * 0.1, alignment: .trailing)
    }
    
    func helpButton(helpTextIndex: Int) -> some View {
        Button {
            newdata.whichhelptext = helpTextIndex
            showhelp = true
        } label: {
            Image(systemName: "questionmark.circle")
        }
        .buttonStyle(HelpButtonStyle(redorwhitebutton: deleteparameterpresent))
    }
    
    var urlEstimateSection: some View {
        VStack(alignment: .leading) {
            Text("URL for Estimate & Synchronize")
            
            HStack {
                URLValues(300, "Select a task to save an URL for Estimate & Synchronize", $stringestimate)
                
                Button {
                    let data = WidgetURLstrings(urletimate: stringestimate, urlverify: stringverify)
                    WriteWidgetsURLStringsJSON(data, .estimate)
                } label: {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.blue)
                }
                .disabled(stringestimate.isEmpty)
                .help(stringestimate)
            }
        }
    }
    
    var urlVerifySection: some View {
        Group {
            if selectedconfig?.offsiteServer.isEmpty == false {
                VStack(alignment: .leading) {
                    Text("URL for Verify")
                    
                    HStack {
                        URLValues(300, "Select a task to save an URL for Verify", $stringverify)
                        
                        Button {
                            let data = WidgetURLstrings(urletimate: stringestimate, urlverify: stringverify)
                            WriteWidgetsURLStringsJSON(data, .verify)
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.blue)
                        }
                        .disabled(stringverify.isEmpty)
                        .help(stringverify)
                    }
                }
            }
        }
    }
    
    var helpSheet: some View {
        switch newdata.whichhelptext {
        case 1:
            HelpView(text: newdata.helptext1)
        case 2:
            HelpView(text: newdata.helptext2)
        default:
            HelpView(text: newdata.helptext1)
        }
    }
    
    var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem {
                Button {
                    addtaskpath.append(AddTasks(task: .globalchanges))
                } label: {
                    Image(systemName: "globe")
                }
                .help("Global change and update")
            }
            
            ToolbarItem {
                Button {
                    addtaskpath.append(AddTasks(task: .homecatalogs))
                } label: {
                    Image(systemName: "house.fill")
                }
                .help("Home catalogs")
            }
        }
    }
}

// MARK: - View Builder Methods

private extension AddTaskView {
    
    @MainActor @ViewBuilder
    func makeDestinationView(for view: AddTaskDestinationView) -> some View {
        switch view {
        case .homecatalogs:
            HomeCatalogsView(
                newdata: newdata,
                path: $addtaskpath,
                homecatalogs: getHomeCatalogs(),
                attachedVolumes: getAttachedVolumes()
            )
        case .globalchanges:
            GlobalChangeTaskView(rsyncUIdata: rsyncUIdata)
        }
    }
}

// MARK: - Computed Properties

private extension AddTaskView {
    
    var selectPickerValue: TypeofTask {
        switch newdata.selectedconfig?.task {
        case SharedReference.shared.synchronize:
            return .synchronize
        case SharedReference.shared.syncremote:
            return .syncremote
        case SharedReference.shared.snapshot:
            return .snapshot
        default:
            return .synchronize
        }
    }
    
    var copyItems: [CopyItem] {
        guard let configurations = rsyncUIdata.configurations else { return [] }
        return configurations.map { record in
            CopyItem(id: record.id, task: record.task)
        }
    }
    
    var deleteparameterpresent: Bool {
        let parameter = rsyncUIdata.configurations?.filter { !$0.parameter4.isEmpty }
        return (parameter?.count ?? 0) > 0
    }
}

// MARK: - Helper Methods

private extension AddTaskView {
    
    func getHomeCatalogs() -> [Catalognames] {
        let fileManager = FileManager.default
        guard let homeURL = Homepath().userHomeDirectoryURLPath else { return [] }
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: homeURL,
                includingPropertiesForKeys: nil
            )
            return contents
                .filter { $0.hasDirectoryPath }
                .map { Catalognames($0.lastPathComponent) }
        } catch {
            return []
        }
    }
    
    func getAttachedVolumes() -> [AttachedVolumes] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey]
        let paths = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: []
        )
        
        guard let urls = paths else { return [] }
        
        let volumesArray = urls.compactMap { url -> AttachedVolumes? in
            let components = url.pathComponents
            if components.count > 1, components[1] == "Volumes" {
                return AttachedVolumes(url)
            }
            return nil
        }
        
        return volumesArray
    }
}

// MARK: - Action Methods

private extension AddTaskView {
    
    func handleFormSubmission() {
        switch focusField {
        case .synchronizeIDField:
            focusField = .localcatalogField
        case .localcatalogField:
            focusField = .remotecatalogField
        case .remotecatalogField:
            focusField = .remoteuserField
        case .remoteuserField:
            focusField = .remoteserverField
        case .snapshotnumField:
            validateAndUpdate()
        case .remoteserverField:
            if newdata.selectedconfig == nil {
                addConfiguration()
            } else {
                validateAndUpdate()
            }
            focusField = nil
        case .none:
            break
        }
    }
    
    func handleViewAppearance() {
        guard selecteduuids.count > 0 else { return }
        
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            selecteduuids.removeAll()
        }
    }
    
    func handleProfileChange() {
        newdata.resetform()
        selecteduuids.removeAll()
        selectedconfig = nil
    }
    
    func handleSelectedTaskChange() {
        guard let configurations = rsyncUIdata.configurations else { return }
        
        if let index = configurations.firstIndex(where: { $0.id == selecteduuids.first }) {
            selectedconfig = configurations[index]
            newdata.updateview(configurations[index])
            updateURLStrings()
        } else {
            selectedconfig = nil
            newdata.updateview(nil)
            clearURLStrings()
        }
    }
    
    func handlePasteDestination(_ items: [CopyItem]) {
        newdata.preparecopyandpastetasks(items, rsyncUIdata.configurations ?? [])
        guard !items.isEmpty else { return }
        confirmcopyandpaste = true
    }
    
    func handleCopyConfirmation() {
        confirmcopyandpaste = false
        rsyncUIdata.configurations = newdata.writecopyandpastetasks(
            rsyncUIdata.profile,
            rsyncUIdata.configurations ?? []
        )
        
        if SharedReference.shared.duplicatecheck,
           let configurations = rsyncUIdata.configurations {
            VerifyDuplicates(configurations)
        }
    }
    
    func updateURLStrings() {
        guard selectedconfig?.task == SharedReference.shared.synchronize else {
            clearURLStrings()
            return
        }
        
        let deeplinkURL = DeeplinkURL()
        
        // Create verify remote URL if remote server exists
        if selectedconfig?.offsiteServer.isEmpty == false {
            let urlVerify = deeplinkURL.createURLloadandverify(
                valueprofile: rsyncUIdata.profile ?? "Default",
                valueid: selectedconfig?.backupID ?? "Synchronize ID"
            )
            stringverify = urlVerify?.absoluteString ?? ""
        }
        
        // Create estimate and synchronize URL
        let urlEstimate = deeplinkURL.createURLestimateandsynchronize(
            valueprofile: rsyncUIdata.profile ?? "Default"
        )
        stringestimate = urlEstimate?.absoluteString ?? ""
    }
    
    func clearURLStrings() {
        stringverify = ""
        stringestimate = ""
    }
    
    func addConfiguration() {
        let profile = rsyncUIdata.profile
        rsyncUIdata.configurations = newdata.addconfig(profile, rsyncUIdata.configurations)
        
        if SharedReference.shared.duplicatecheck,
           let configurations = rsyncUIdata.configurations {
            VerifyDuplicates(configurations)
        }
    }
    
    func validateAndUpdate() {
        let profile = rsyncUIdata.profile
        rsyncUIdata.configurations = newdata.updateconfig(profile, rsyncUIdata.configurations)
        selecteduuids.removeAll()
    }
}
