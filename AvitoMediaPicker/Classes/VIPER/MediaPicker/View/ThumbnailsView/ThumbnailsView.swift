import UIKit
import AVFoundation

final class ThumbnailsView: UIView, UICollectionViewDataSource, MediaRibbonLayoutDelegate {
    
    private let layout: ThumbnailsViewLayout
    private let collectionView: UICollectionView
    private let dataSource = MediaRibbonDataSource()
    
    private var theme: MediaPickerRootModuleUITheme?
    
    // MARK: - Constrants
    
    private let mediaRibbonInteritemSpacing = CGFloat(7)
    
    private let photoCellReuseId = "PhotoCell"
    private let cameraCellReuseId = "CameraCell"
    
    // MARK: - Init
    
    init() {
        
        layout = ThumbnailsViewLayout()
        layout.scrollDirection = .Horizontal
        layout.minimumLineSpacing = mediaRibbonInteritemSpacing
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clearColor()
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.registerClass(MediaItemThumbnailCell.self, forCellWithReuseIdentifier: photoCellReuseId)
        collectionView.registerClass(CameraThumbnailCell.self, forCellWithReuseIdentifier: cameraCellReuseId)
        
        super.init(frame: .zero)
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        addSubview(collectionView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UIView
    
    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = bounds
    }
    
    // MARK: - ThumbnailRibbonView
    
    var cameraOutputParameters: CameraOutputParameters? {
        didSet {
            updateCameraCell()
        }
    }
    
    var contentInsets = UIEdgeInsets.zero {
        didSet {
            layout.sectionInset = contentInsets
        }
    }
    
    var onPhotoItemSelect: (MediaPickerItem -> ())?
    var onCameraItemSelect: (() -> ())?
    
    func selectCameraItem() {
        collectionView.selectItemAtIndexPath(dataSource.indexPathForCameraItem(), animated: false, scrollPosition: .None)
    }
    
    func selectMediaItem(item: MediaPickerItem, animated: Bool = false) {
        if let indexPath = dataSource.indexPathForItem(item) {
            collectionView.selectItemAtIndexPath(indexPath, animated: animated, scrollPosition: .None)
        }
    }
    
    func scrollToItemThumbnail(item: MediaPickerItem, animated: Bool) {
        if let indexPath = dataSource.indexPathForItem(item) {
            collectionView.scrollToItemAtIndexPath(
                indexPath,
                atScrollPosition: .CenteredHorizontally,
                animated: animated
            )
        }
    }
    
    func scrollToCameraThumbnail(animated animated: Bool) {
        collectionView.scrollToItemAtIndexPath(
            dataSource.indexPathForCameraItem(),
            atScrollPosition: .CenteredHorizontally,
            animated: animated
        )
    }
    
    func setTheme(theme: MediaPickerRootModuleUITheme) {
        self.theme = theme
    }
    
    func setControlsTransform(transform: CGAffineTransform) {
        
        layout.itemsTransform = transform
        layout.invalidateLayout()
        
        cameraIconTransform = transform
    }
    
    func addItems(items: [MediaPickerItem], animated: Bool, completion: () -> ()) {
        collectionView.performBatchUpdates(animated: animated, { [weak self] in
            if let indexPaths = self?.dataSource.addItems(items) {
                self?.collectionView.insertItemsAtIndexPaths(indexPaths)
            }
        }, completion: { _ in completion() })
    }
    
    func updateItem(item: MediaPickerItem) {
        
        if let indexPath = dataSource.updateItem(item) {
            
            let selectedIndexPaths = collectionView.indexPathsForSelectedItems()
            let cellWasSelected = selectedIndexPaths?.contains(indexPath) == true
            
            collectionView.reloadItemsAtIndexPaths([indexPath])
            
            if cellWasSelected {
                collectionView.selectItemAtIndexPath(indexPath, animated: false, scrollPosition: .None)
            }
        }
    }
    
    func removeItem(item: MediaPickerItem, animated: Bool) {
        collectionView.deleteItems(animated: animated) { [weak self] in
            self?.dataSource.removeItem(item).flatMap { [$0] }
        }
    }
    
    func setCameraItemVisible(visible: Bool) {
        
        if dataSource.cameraCellVisible != visible {
            
            let updatesFunction = { [weak self] () -> [NSIndexPath]? in
                self?.dataSource.cameraCellVisible = visible
                return (self?.dataSource.indexPathForCameraItem()).flatMap { [$0] }
            }
            
            if visible {
                collectionView.insertItems(animated: false, updatesFunction)
            } else {
                collectionView.deleteItems(animated: false, updatesFunction)
            }
        }
    }
    
    func setCameraOutputParameters(parameters: CameraOutputParameters) {
        cameraOutputParameters = parameters
    }
    
    func setCameraOutputOrientation(orientation: ExifOrientation) {
        cameraOutputParameters?.orientation = orientation
        if let cell = cameraCell() {
            cell.setOutputOrientation(orientation)
        }
    }
    
    func reloadCamera() {
        if dataSource.cameraCellVisible {
            let cameraIndexPath = dataSource.indexPathForCameraItem()
            let cameraIsSelected = collectionView.indexPathsForSelectedItems()?.contains(cameraIndexPath) == true
            
            collectionView.reloadItemsAtIndexPaths([dataSource.indexPathForCameraItem()])
            
            if cameraIsSelected {
                collectionView.selectItemAtIndexPath(cameraIndexPath, animated: false, scrollPosition: .None)
            }
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.numberOfItems
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        switch dataSource[indexPath] {
        case .Camera:
            return cameraCell(forIndexPath: indexPath, inCollectionView: collectionView)
        case .Photo(let mediaPickerItem):
            return photoCell(forIndexPath: indexPath, inCollectionView: collectionView, withItem: mediaPickerItem)
        }
    }
    
    // MARK: - MediaRibbonLayoutDelegate
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let height = bounds.size.height - contentInsets.top - contentInsets.bottom
        return CGSize(width: height, height: height)
    }
    
    func shouldApplyTransformToItemAtIndexPath(indexPath: NSIndexPath) -> Bool {
        switch dataSource[indexPath] {
        case .Photo(_):
            return true
        default:
            return false
        }
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        switch dataSource[indexPath] {
        case .Photo(let photo):
            onPhotoItemSelect?(photo)
        case .Camera:
            onCameraItemSelect?()
        }
    }
    
    // MARK: - Private
    
    private var cameraIconTransform = CGAffineTransformIdentity {
        didSet {
            cameraCell()?.setCameraIconTransform(cameraIconTransform)
        }
    }
    
    private func photoCell(
        forIndexPath indexPath: NSIndexPath,
        inCollectionView collectionView: UICollectionView,
        withItem mediaPickerItem: MediaPickerItem
    ) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(
            photoCellReuseId,
            forIndexPath: indexPath
        )
        
        if let cell = cell as? MediaItemThumbnailCell {
            cell.selectedBorderColor = theme?.mediaRibbonSelectionColor
            cell.customizeWithItem(mediaPickerItem)
        }
        
        return cell
    }
    
    private func cameraCell(
        forIndexPath indexPath: NSIndexPath,
        inCollectionView collectionView: UICollectionView
    ) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(
            cameraCellReuseId,
            forIndexPath: indexPath
        )
        
        setUpCameraCell(cell)
        
        return cell
    }
    
    private func setUpCameraCell(cell: UICollectionViewCell) {
        if let cell = cell as? CameraThumbnailCell {
            cell.selectedBorderColor = theme?.mediaRibbonSelectionColor
            cell.setCameraIcon(theme?.returnToCameraIcon)
            cell.setCameraIconTransform(cameraIconTransform)
            
            if let cameraOutputParameters = cameraOutputParameters {
                cell.setOutputParameters(cameraOutputParameters)
            }
        }
    }
    
    private func updateCameraCell() {
        if let cell = cameraCell() {
            setUpCameraCell(cell)
        }
    }
    
    private func cameraCell() -> CameraThumbnailCell? {
        let indexPath = dataSource.indexPathForCameraItem()
        return collectionView.cellForItemAtIndexPath(indexPath) as? CameraThumbnailCell
    }
}
