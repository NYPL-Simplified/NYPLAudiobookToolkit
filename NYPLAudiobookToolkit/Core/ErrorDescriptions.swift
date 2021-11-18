let OpenAccessPlayerErrorDomain = "NYPLAudiobookToolkit.OpenAccessPlayer"
let OverdrivePlayerErrorDomain = "NYPLAudiobookToolkit.OverdrivePlayer"

enum OpenAccessPlayerError: Int {
    case unknown = 0
    case downloadNotFinished
    case playerNotReady
    case connectionLost
    case drmExpired
    
    func errorTitle() -> String {
        switch self {
        case .downloadNotFinished:
            return "Please Wait"
        case .connectionLost:
            return "Connection Lost"
        case .drmExpired:
            return "DRM Protection"
        default:
            return "A Problem Has Occurred"
        }
    }
    
    func errorDescription() -> String {
        switch self {
        case .unknown:
            return """
            An unknown error has occurred. Please leave the book, and try again.
            If the problem persists, sign out and sign back in.
            """
        case .downloadNotFinished:
            return """
            This chapter has not finished downloading. Please wait and try again.
            """
        case .playerNotReady:
            return """
            A problem has occurred. Please leave the book and try again.
            """
        case .connectionLost:
            return """
            The internet connection was lost during the download.
             Wait until you are back online, leave the book and try again.
            """
        case .drmExpired:
            return """
            DRM permissions for this Audiobook have expired. Please leave the book, and try again.
            If the problem persists, sign out and sign back in.
            """
        }
    }
}

enum OverdrivePlayerError: Int {
    // Cases 0 - 3 have to match with OpenAccessPlayerError
    // since they are thrown in OpenAccessPlayer, parent class of OverdrivePlayer
    case unknown = 0
    case downloadNotFinished
    case playerNotReady
    case connectionLost
    case downloadExpired
    
    func errorTitle() -> String {
        switch self {
        case .downloadNotFinished:
            return "Please Wait"
        case .connectionLost:
            return "Connection Lost"
        case .downloadExpired:
            return "Download Expired"
        default:
            return "A Problem Has Occurred"
        }
    }
    
    func errorDescription() -> String {
        switch self {
        case .unknown:
            return """
            An unknown error has occurred. Please leave the book, and try again.
            If the problem persists, go to Settings and sign out.
            """
        case .downloadNotFinished:
            return """
            This chapter has not finished downloading. Please wait and try again.
            """
        case .playerNotReady:
            return """
            A problem has occurred. Please leave the book and try again.
            """
        case .connectionLost:
            return """
            The internet connection was lost during the download.
             Wait until you are back online, leave the book and try again.
            """
        case .downloadExpired:
            return """
            The download URLs for this Audiobook have expired. Please leave the book, and try again.
            """
        }
    }
}
