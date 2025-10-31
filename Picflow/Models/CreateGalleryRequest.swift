struct CreateGalleryRequest: Encodable {
    let title: String
    let preset: String
    
    init(title: String, preset: String = "review") {
        self.title = title
        self.preset = preset
    }
}