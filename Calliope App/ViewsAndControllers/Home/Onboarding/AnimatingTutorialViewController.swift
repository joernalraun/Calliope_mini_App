//
//  AnimatingTutorialViewController.swift
//  Calliope App
//
//  Created by Tassilo Karge on 28.11.19.
//  Copyright © 2019 calliope. All rights reserved.
//

import UIKit

protocol AnimatingTutorialViewController: AnyObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    var collectionView: UICollectionView? { get }
    
    var cellIdentifier: String { get }
    var cellSize: CGSize { get }
    var secondaryImageDefaultHeight: CGFloat { get }
    
    var animationSpeed: Double { get }
    
    var cellDelay: Double { get }
    
    /// title, number, main image(s), secondary image(s)
    var cellConfigurations: [(String?, UIImage?, [UIImage]?, [UIImage]?)] { get }
    
    /// the section and item numbers for all items in cellConfigurations
    func indexPathForItem(_ number: Int) -> IndexPath
    
    /// the inverse of indexPathForItem
    func itemForIndexPath(_ indexPath: IndexPath) -> Int
    
    var animationStep: Int { get set }
    
    var finishedCallback: () -> () { get }
}

extension AnimatingTutorialViewController {
    
    var animationSpeed: Double { return 0.1 }
    var cellSize: CGSize { return CGSize(width: 300, height: 270) }
    var secondaryImageDefaultHeight: CGFloat { return 40 }
    var cellDelay: Double { return 2.0 }
    var finishedCallback: () -> () { return { } }
    
    func indexPathForItem(_ number: Int) -> IndexPath {
        return IndexPath(item: number, section: 0)
    }
    
    func itemForIndexPath(_ indexPath: IndexPath) -> Int {
        return indexPath.item
    }
    
    func animate() {
        if animationStep < cellConfigurations.count {
            let indexPath = indexPathForItem(animationStep)
            collectionView?.performBatchUpdates({
                animationStep += 1
                collectionView?.insertItems(at: [indexPath])
            }) { finished in
                guard finished else { return }
                self.collectionView?.scrollToItem(at: indexPath, at: [.centeredVertically, .centeredHorizontally], animated: true) }
            delay(time: cellDelay, self.animate)
        } else {
            animationStep += 1
            finishedCallback()
        }
    }
    
    //MARK: proxy methods for unimplementable objective-c protocol methods
    
    func proxyCollectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return min(animationStep, cellConfigurations.count)
    }
    
    func proxyCollectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell =  collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as? OnboardingCollectionViewCell else {
            fatalError("only miniDemo cells must be provided to miniDemo page!")
        }
        let itemNumber = itemForIndexPath(indexPath)
        let cellData = cellConfigurations[itemNumber]
        
        setCellData(cell, cellData)
        
        if (animationStep == itemNumber + 1) {
            cell.contentView.alpha = 0
            delay(time: 0.3) {
                self.cellFadeInAnimation(cell)
            }
        } else {
            startCellImageAnimations(cell)
        }
        
        return cell
    }
    
    func proxyCollectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return cellSize
    }
    
    private func setCellData(_ cell: OnboardingCollectionViewCell, _ cellData: (String?, UIImage?, [UIImage]?, [UIImage]?)) {
        
        cell.title?.text = cellData.0
        cell.number?.image = cellData.1
        
        if let cellImages = cellData.2 {
            if cellImages.count > 1 {
                cell.mainImage?.animationImages = cellData.2
                cell.mainImage?.image = cellImages[0]
                cell.mainImage?.animationDuration = Double(cellImages.count) * animationSpeed
            } else if cellImages.count > 0 {
                cell.mainImage?.animationImages = nil
                cell.mainImage?.image = cellImages[0]
            }
        }
        
        if cellData.3 == nil || cellData.3!.count == 0 {
            cell.secondaryImageHeight?.constant = 0
        } else if cellData.3!.count > 1 {
            cell.secondaryImageHeight?.constant = secondaryImageDefaultHeight
            //set animation images
            cell.secondaryImage?.animationImages = cellData.3
            cell.secondaryImage?.image = cellData.3![0]
            cell.secondaryImage?.animationDuration = Double(cellData.3!.count) * animationSpeed
        } else {
            cell.secondaryImageHeight?.constant = secondaryImageDefaultHeight
            //set static image
            cell.secondaryImage?.animationImages = nil
            cell.secondaryImage?.image = cellData.3![0]
        }
    }
    
    private func cellFadeInAnimation(_ cell: OnboardingCollectionViewCell) {
        UIView.animate(withDuration: 0.5, animations: {
            cell.contentView.alpha = 1.0
        }) { (_) in
            self.startCellImageAnimations(cell)
        }
    }
    
    private func startCellImageAnimations(_ cell: OnboardingCollectionViewCell) {
        if cell.mainImage?.animationImages != nil {
            cell.mainImage?.startAnimating()
        }
        if cell.secondaryImage?.animationImages != nil {
            cell.secondaryImage?.startAnimating()
        }
    }

}
