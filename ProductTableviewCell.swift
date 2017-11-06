//
//  ProductTableviewCell.swift
//  ISAT NEWS
//
//  Created by kadin on 10/17/17.
//  Copyright © 2017 Kadin Loehr. All rights reserved.
//

import UIKit

class ProductTableViewCell: UITableViewCell {
    
    @IBOutlet weak var productName: UILabel!
    @IBOutlet weak var productPrice: UILabel!
    
    @IBOutlet weak var productDescription: UILabel!
   @IBOutlet weak var productStatus: CustomButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        productStatus.layer.cornerRadius = 20
        self.selectionStyle = .none
        
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}
