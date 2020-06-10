//
//  NCMedia.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/02/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import NCCommunication

class NCMedia: UIViewController, DropdownMenuDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate {
    
    @IBOutlet weak var collectionView : UICollectionView!
    
    //Grid control buttons
    private var plusButton: UIBarButtonItem!
    private var separatorButton: UIBarButtonItem!
    private var minusButton: UIBarButtonItem!
    private var gridButton: UIBarButtonItem!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var sectionDatasource = CCSectionDataSourceMetadata()

    private var metadataPush: tableMetadata?
    private var isEditMode = false
    private var selectocId: [String] = []
    
    private var filterTypeFileImage = false;
    private var filterTypeFileVideo = false;
        
    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""
    
    private var gridLayout: NCGridMediaLayout!
        
    private let sectionHeaderHeight: CGFloat = 50
    private let footerHeight: CGFloat = 50
    
    private var stepImageWidth: CGFloat = 10
    private let kMaxImageGrid: CGFloat = 5
    
    private var isDistantPast = false

    private let refreshControl = UIRefreshControl()
    private var loadingSearch = false
    
    struct cacheImages {
        static var cellPlayImage = UIImage()
        static var cellFavouriteImage = UIImage()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        appDelegate.activeMedia = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: CCGraphics.changeThemingColorImage(UIImage(named: "more"), width: 50, height: 50, color: NCBrandColor.sharedInstance.textView), style: .plain, target: self, action: #selector(touchUpInsideMenuButtonMore))
        
        // Cell
        collectionView.register(UINib.init(nibName: "NCGridMediaCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        
        // Header
        collectionView.register(UINib.init(nibName: "NCSectionMediaHeader", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeader")
        
        // Footer
        collectionView.register(UINib.init(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")
        
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0);
                
        gridLayout = NCGridMediaLayout()
        gridLayout.itemPerLine = CGFloat(min(CCUtility.getMediaWidthImage(), 5))
        gridLayout.sectionHeadersPinToVisibleBounds = true

        collectionView.collectionViewLayout = gridLayout

        // Add Refresh Control
        collectionView.refreshControl = refreshControl
        
        // empty Data Source
        collectionView.emptyDataSetDelegate = self
        collectionView.emptyDataSetSource = self
                
        // 3D Touch peek and pop
        if traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: view)
        }
        
        // Notification
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_deleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_moveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_renameFile), object: nil)
        
        plusButton = UIBarButtonItem(title: " + ", style: .plain, target: self, action: #selector(dezoomGrid))
        plusButton.isEnabled = !(self.gridLayout.itemPerLine == 1)
        separatorButton = UIBarButtonItem(title: "/", style: .plain, target: nil, action: nil)
        separatorButton.isEnabled = false
        separatorButton.setTitleTextAttributes([NSAttributedString.Key.foregroundColor : NCBrandColor.sharedInstance.brandElement], for: .disabled)
        minusButton =  UIBarButtonItem(title: " - ", style: .plain, target: self, action: #selector(zoomGrid))
        minusButton.isEnabled = !(self.gridLayout.itemPerLine == self.kMaxImageGrid - 1)
        gridButton = UIBarButtonItem(image: CCGraphics.changeThemingColorImage(UIImage(named: "grid"), width: 50, height: 50, color: NCBrandColor.sharedInstance.textView), style: .plain, target: self, action: #selector(enableZoomGridButtons))
        self.navigationItem.leftBarButtonItem = gridButton

        // changeTheming
        changeTheming()
    }
    
    @objc func enableZoomGridButtons() {
        self.navigationItem.setLeftBarButtonItems([plusButton,separatorButton,minusButton], animated: true)
    }
    
    @objc func removeZoomGridButtons() {
        if self.navigationItem.leftBarButtonItems?.count != 1 {
            self.navigationItem.setLeftBarButtonItems([gridButton], animated: true)
        }
    }
    
    @objc func zoomGrid() {
        UIView.animate(withDuration: 0.0, animations: {
            if(self.gridLayout.itemPerLine + 1 < self.kMaxImageGrid) {
                self.gridLayout.itemPerLine += 1
                self.plusButton.isEnabled = true
            }
            if(self.gridLayout.itemPerLine == self.kMaxImageGrid - 1) {
                self.minusButton.isEnabled = false
            }

            self.collectionView.collectionViewLayout.invalidateLayout()
            CCUtility.setMediaWidthImage(Int(self.gridLayout.itemPerLine))
        })
    }

    @objc func dezoomGrid() {
        UIView.animate(withDuration: 0.0, animations: {
            if(self.gridLayout.itemPerLine - 1 > 0) {
                self.gridLayout.itemPerLine -= 1
                self.minusButton.isEnabled = true
            }
            if(self.gridLayout.itemPerLine == 1) {
                self.plusButton.isEnabled = false
            }

            self.collectionView.collectionViewLayout.invalidateLayout()
            CCUtility.setMediaWidthImage(Int(self.gridLayout.itemPerLine))
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Configure Refresh Control
        refreshControl.tintColor = .lightGray
        refreshControl.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        refreshControl.addTarget(self, action: #selector(searchNewPhotoVideo), for: .valueChanged)
        
        // get auto upload folder
        autoUploadFileName = NCManageDatabase.sharedInstance.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.sharedInstance.getAccountAutoUploadDirectory(appDelegate.activeUrl)
        
        // Title
        self.navigationItem.title = NSLocalizedString("_media_", comment: "")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        searchNewPhotoVideo()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
            self.reloadDataThenPerform {
            }
        }
    }
    
    //MARK: - NotificationCenter

    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: nil, collectionView: collectionView, form: false)
        
        refreshControl.tintColor = .lightGray
        refreshControl.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        
        cacheImages.cellPlayImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "play"), width: 100, height: 100, color: .white)
        cacheImages.cellFavouriteImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "favorite"), width: 100, height: 100, color: NCBrandColor.sharedInstance.yellowFavorite)
    }

    @objc func deleteFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                
                if errorCode == 0 && (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) {
                    
                    self.reloadDataSource() {
                    
                        let userInfo: [String : Any] = ["metadata": metadata, "type": "delete"]
                        NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_synchronizationMedia), object: nil, userInfo: userInfo)
                    }
                }
            }
        }
    }
    
    @objc func moveFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let metadataNew = userInfo["metadataNew"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                
                if errorCode == 0 && (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) {
                    
                    self.reloadDataSource() {
                    
                        let userInfo: [String : Any] = ["metadata": metadata, "metadataNew": metadataNew, "type": "move"]
                        NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_synchronizationMedia), object: nil, userInfo: userInfo)
                    }
                }
            }
        }
    }
    
    @objc func renameFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                
                if errorCode == 0 && (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) {
                    
                    self.reloadDataSource() {
                    
                        let userInfo: [String : Any] = ["metadata": metadata, "type": "rename"]
                        NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_synchronizationMedia), object: nil, userInfo: userInfo)
                    }
                }
            }
        }
    }
    
    // MARK: DZNEmpty
    
    func backgroundColor(forEmptyDataSet scrollView: UIScrollView) -> UIColor? {
        return NCBrandColor.sharedInstance.backgroundView
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        return CCGraphics.changeThemingColorImage(UIImage.init(named: "media"), width: 300, height: 300, color: NCBrandColor.sharedInstance.brandElement)
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        
        var text = "\n" + NSLocalizedString("_tutorial_photo_view_", comment: "")

        if loadingSearch {
            text = "\n" + NSLocalizedString("_search_in_progress_", comment: "")
        }
        
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }
    
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }
    
    // MARK: IBAction
    
    @objc func touchUpInsideMenuButtonSwitch(_ sender: Any) {
                
        UIView.animate(withDuration: 0.0, animations: {
            if(self.gridLayout.itemPerLine + 1 < self.kMaxImageGrid && self.gridLayout.increasing) {
                self.gridLayout.itemPerLine+=1
            } else {
                self.gridLayout.increasing = false
                self.gridLayout.itemPerLine-=1
            }
            if(self.gridLayout.itemPerLine == 0) {
                self.gridLayout.increasing = true
                self.gridLayout.itemPerLine = 2
            }
            
            self.collectionView.collectionViewLayout.invalidateLayout()
            CCUtility.setMediaWidthImage(Int(self.gridLayout.itemPerLine))
        })
    }
    
    @objc func touchUpInsideMenuButtonMore(_ sender: Any) {
        let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
        var actions: [NCMenuAction] = []

        if !isEditMode {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_select_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "selectFull"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        self.isEditMode = true
                    }
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString(filterTypeFileImage ? "_media_viewimage_show_" : "_media_viewimage_hide_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: filterTypeFileImage ? "imageno" : "imageyes"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        self.filterTypeFileImage = !self.filterTypeFileImage
                        self.reloadDataSource() { }
                    }
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString(filterTypeFileVideo ? "_media_viewvideo_show_" : "_media_viewvideo_hide_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: filterTypeFileVideo ? "videono" : "videoyes"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        self.filterTypeFileVideo = !self.filterTypeFileVideo
                        self.reloadDataSource() { }
                    }
                )
            )

        } else {
           
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_deselect_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "cancel"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        self.isEditMode = false
                        self.selectocId.removeAll()
                        self.reloadDataThenPerform {
                        }
                    }
                )
            )
            
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_delete_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: .red),
                    action: { menuAction in
                        self.deleteItems()
                    }
                )
            )
        }

        mainMenuViewController.actions = actions
        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = self
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)

        self.present(menuPanelController, animated: true, completion: nil)
    }
    
    // MARK: SEGUE
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if let segueNavigationController = segue.destination as? UINavigationController {
            if let segueViewController = segueNavigationController.topViewController as? NCDetailViewController {
            
                segueViewController.metadata = metadataPush
                segueViewController.metadatas = sectionDatasource.metadatas as! [tableMetadata]
                segueViewController.mediaFilterImage = true
            }
        }
    }
}

// MARK: - 3D Touch peek and pop

extension NCMedia: UIViewControllerPreviewingDelegate {
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        
        guard let point = collectionView?.convert(location, from: collectionView?.superview) else { return nil }
        guard let indexPath = collectionView?.indexPathForItem(at: point) else { return nil }
        guard let metadata = NCMainCommon.sharedInstance.getMetadataFromSectionDataSourceIndexPath(indexPath, sectionDataSource: sectionDatasource) else { return nil }
        guard let cell = collectionView?.cellForItem(at: indexPath) as? NCGridMediaCell  else { return nil }
        guard let viewController = UIStoryboard(name: "CCPeekPop", bundle: nil).instantiateViewController(withIdentifier: "PeekPopImagePreview") as? CCPeekPop else { return nil }
        
        previewingContext.sourceRect = cell.frame
        viewController.metadata = metadata
        viewController.imageFile = cell.imageItem.image
        viewController.showOpenIn = true
        viewController.showShare = false
        viewController.showOpenQuickLook = false

        return viewController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        
        guard let indexPath = collectionView?.indexPathForItem(at: previewingContext.sourceRect.origin) else { return }
        
        collectionView(collectionView, didSelectItemAt: indexPath)
    }
}

// MARK: - Collection View

extension NCMedia: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let metadata = NCMainCommon.sharedInstance.getMetadataFromSectionDataSourceIndexPath(indexPath, sectionDataSource: sectionDatasource) else {
            return
        }
        metadataPush = metadata
        
        if isEditMode {
            if let index = selectocId.firstIndex(of: metadata.ocId) {
                selectocId.remove(at: index)
            } else {
                selectocId.append(metadata.ocId)
            }
            if indexPath.section <  collectionView.numberOfSections && indexPath.row < collectionView.numberOfItems(inSection: indexPath.section) {
                collectionView.reloadItems(at: [indexPath])
            }
            
            return
        }
        
        performSegue(withIdentifier: "segueDetail", sender: self)
    }
}

extension NCMedia: UICollectionViewDataSource {
    
    func reloadDataThenPerform(_ closure: @escaping (() -> Void)) {
        CATransaction.begin()
        CATransaction.setCompletionBlock(closure)
        collectionView?.reloadData()
        CATransaction.commit()
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionView.elementKindSectionHeader {
            
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeader", for: indexPath) as! NCSectionMediaHeader
            
            header.setTitleLabel(sectionDatasource: sectionDatasource, section: indexPath.section)
            header.labelSection.textColor = .white
            header.labelHeightConstraint.constant = 20
            header.labelSection.layer.cornerRadius = 10
            header.labelSection.layer.backgroundColor = UIColor(red: 152.0/255.0, green: 167.0/255.0, blue: 181.0/255.0, alpha: 0.8).cgColor
            let width = header.labelSection.intrinsicContentSize.width + 30
            let leading = collectionView.bounds.width / 2 - width / 2
            header.labelWidthConstraint.constant = width
            header.labelLeadingConstraint.constant = leading
            
            return header
            
        } else {
            
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCSectionFooter
            
            footer.setTitleLabel(sectionDatasource: sectionDatasource)
            
            return footer
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        let sections = sectionDatasource.sectionArrayRow.allKeys.count
        return sections
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        var numberOfItemsInSection: Int = 0
        
        if section < sectionDatasource.sections.count {
            let key = sectionDatasource.sections.object(at: section)
            let datasource = sectionDatasource.sectionArrayRow.object(forKey: key) as! [tableMetadata]
            numberOfItemsInSection = datasource.count
        }
        
        return numberOfItemsInSection
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let metadata = NCMainCommon.sharedInstance.getMetadataFromSectionDataSourceIndexPath(indexPath, sectionDataSource: sectionDatasource) else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridMediaCell
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridMediaCell
        NCOperationQueue.shared.downloadThumbnail(metadata: metadata, activeUrl: self.appDelegate.activeUrl, view: self.collectionView as Any, indexPath: indexPath)
                    
        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView)) {
            cell.imageItem.backgroundColor = nil
            cell.imageItem.image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView))
        } else if(!metadata.hasPreview) {
            cell.imageItem.backgroundColor = nil
            if metadata.iconName.count > 0 {
                cell.imageItem.image = UIImage.init(named: metadata.iconName)
            } else {
                cell.imageItem.image = UIImage.init(named: "file")
            }
        }
                    
        // image status
        if metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio {
            cell.imageStatus.image = cacheImages.cellPlayImage
        }
        
        // image Local
        let tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        if tableLocalFile != nil && CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            if tableLocalFile!.offline { cell.imageLocal.image = UIImage.init(named: "offlineFlag") }
            else { cell.imageLocal.image = UIImage.init(named: "local") }
        }
        
        // image Favorite
        if metadata.favorite {
            cell.imageFavorite.image = cacheImages.cellFavouriteImage
        }
        
        if isEditMode {
            cell.imageSelect.isHidden = false
            if selectocId.contains(metadata.ocId) {
                cell.imageSelect.image = CCGraphics.scale(UIImage.init(named: "checkedYes"), to: CGSize(width: 50, height: 50), isAspectRation: true)
                cell.imageVisualEffect.isHidden = false
                cell.imageVisualEffect.alpha = 0.4
            } else {
                cell.imageSelect.isHidden = true
                cell.imageVisualEffect.isHidden = true
            }
        } else {
            cell.imageSelect.isHidden = true
            cell.imageVisualEffect.isHidden = true
        }
       
        return cell
    }
}

extension NCMedia: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: sectionHeaderHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        let sections = sectionDatasource.sectionArrayRow.allKeys.count
        if (section == sections - 1) {
            return CGSize(width: collectionView.frame.width, height: footerHeight)
        } else {
            return CGSize(width: collectionView.frame.width, height: 0)
        }
    }
}

// MARK: - NC API & Algorithm

extension NCMedia {

    public func reloadDataSource(completion: @escaping ()->()) {
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        DispatchQueue.global().async {
            
            let metadatas = NCManageDatabase.sharedInstance.getMetadatasMedia(account: self.appDelegate.activeAccount)
            self.sectionDatasource = CCSectionMetadata.creataDataSourseSectionMetadata(metadatas, listProgressMetadata: nil, groupByField: "date", filterTypeFileImage: self.filterTypeFileImage, filterTypeFileVideo: self.filterTypeFileVideo, filterLivePhoto: true, sorted: "date", ascending: false, activeAccount: self.appDelegate.activeAccount)
            
            DispatchQueue.main.async {
                self.collectionView?.reloadData()
                
                completion()
            }
        }
    }
    
    @objc func searchNewPhotoVideo() {
        
        let tableAccount = NCManageDatabase.sharedInstance.getAccountActive()
        
        //let elementDate = "nc:upload_time/"
        //let lteDate: Int = Int(Date().timeIntervalSince1970)
        //let gteDate: Int = Int(fromDate!.timeIntervalSince1970)
        
        guard let lteDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return }
        guard var gteDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return }
        
        if let date = tableAccount?.dateUpdateMedia {
            gteDate = date as Date
        }
        
        NCCommunication.shared.searchMedia(lteDate: lteDate, gteDate: gteDate, elementDate: "d:getlastmodified/" ,showHiddenFiles: CCUtility.getShowHiddenFiles(), user: appDelegate.activeUser) { (account, files, errorCode, errorDescription) in
            if errorCode == 0 && files != nil && files!.count > 0 {
                NCManageDatabase.sharedInstance.addMetadatas(files: files, account: self.appDelegate.activeAccount)
                NCManageDatabase.sharedInstance.setAccountDateLteMedia(date: files?.last?.date)
                NCManageDatabase.sharedInstance.setAccountDateUpdateMedia()
            }
            self.refreshControl.endRefreshing()
            self.reloadDataSource() {}
        }
    }
    
    private func searchOldPhotoVideo(gteDate: Date? = nil) {
        
        var lteDate = Date()
        let tableAccount = NCManageDatabase.sharedInstance.getAccountActive()
        if let date = tableAccount?.dateLteMedia {
            lteDate = date as Date
        }

        let height = self.tabBarController?.tabBar.frame.size.height ?? 0
        NCUtility.sharedInstance.startActivityIndicator(view: self.view, bottom: height + 50)
        
        
        var gteDate = gteDate
        if gteDate == nil {
            gteDate = Calendar.current.date(byAdding: .day, value: -30, to: lteDate)
        }

        NCCommunication.shared.searchMedia(lteDate: lteDate, gteDate: gteDate!, elementDate: "d:getlastmodified/" ,showHiddenFiles: CCUtility.getShowHiddenFiles(), user: appDelegate.activeUser) { (account, files, errorCode, errorDescription) in
            if errorCode == 0 {
                if files != nil && files!.count > 0 {
                    NCManageDatabase.sharedInstance.addMetadatas(files: files, account: self.appDelegate.activeAccount)
                    NCManageDatabase.sharedInstance.setAccountDateLteMedia(date: files?.last?.date)
                    NCManageDatabase.sharedInstance.setAccountDateUpdateMedia()
                    self.reloadDataSource() {}
                } else {
                    if gteDate == Calendar.current.date(byAdding: .day, value: -30, to: lteDate) {
                        self.searchOldPhotoVideo(gteDate: Calendar.current.date(byAdding: .day, value: -90, to: lteDate))
                    } else if gteDate == Calendar.current.date(byAdding: .day, value: -90, to: lteDate) {
                        self.searchOldPhotoVideo(gteDate: Date.distantPast)
                    }
                }
            }
            NCUtility.sharedInstance.stopActivityIndicator()
        }
    }
    
    func deleteItems() {
        
        self.isEditMode = false
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        // copy in arrayDeleteMetadata
        for ocId in selectocId {
            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", ocId)) {
                appDelegate.arrayDeleteMetadata.add(metadata)
            }
        }
        if let metadata = appDelegate.arrayDeleteMetadata.firstObject {
            appDelegate.arrayDeleteMetadata.removeObject(at: 0)
            NCNetworking.shared.deleteMetadata(metadata as! tableMetadata, account: appDelegate.activeAccount, url: appDelegate.activeUrl) { (errorCode, errorDescription) in }
        }
    }
    
    private func downloadThumbnail() {
        guard let collectionView = self.collectionView else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for item in collectionView.indexPathsForVisibleItems {
                if let metadata = NCMainCommon.sharedInstance.getMetadataFromSectionDataSourceIndexPath(item, sectionDataSource: self.sectionDatasource) {
                    NCOperationQueue.shared.downloadThumbnail(metadata: metadata, activeUrl: self.appDelegate.activeUrl, view: self.collectionView as Any, indexPath: item)
                }
            }
        }
    }
    
    private func removeDeletedFile() {
        guard let collectionView = self.collectionView else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for item in collectionView.indexPathsForVisibleItems {
                if let metadata = NCMainCommon.sharedInstance.getMetadataFromSectionDataSourceIndexPath(item, sectionDataSource: self.sectionDatasource) {
                    NCOperationQueue.shared.removeDeletedFile(metadata: metadata)
                }
            }
        }
    }

}

// MARK: - ScrollView

extension NCMedia: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.removeZoomGridButtons()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.removeDeletedFile()
            
            if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height)) {
                searchOldPhotoVideo()
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.removeDeletedFile()
        
        if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height)) {
            searchOldPhotoVideo()
        }
    }
}
