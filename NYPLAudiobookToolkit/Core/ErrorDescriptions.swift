let OpenAccessPlayerErrorDomain = "org.nypl.labs.NYPLAudiobookToolkit.OpenAccessPlayer"
let OverdrivePlayerErrorDomain = "org.nypl.labs.NYPLAudiobookToolkit.OverdrivePlayer"

/// Error Code : Description
let OpenAccessPlayerErrorDescriptions = [
    0 : """
    An unknown error has occurred. Please leave the book, and try again.
    If the problem persists, go to Settings and sign out.
    """,
    1 : """
    This chapter has not finished downlading. Please wait and try again.
    """,
    2 : """
    A problem has occurred. Please leave the book and try again.
    """,
    3 : """
    The internet connection was lost during the download.
     Wait until you are back online, leave the book and try again.
    """,
    4 : """
    DRM Permissions for this Audiobook have expired. Please leave the book, and try again.
    If the problem persists, go to Settings and sign out.
    """
]

/// Error Code : Alert Title
let OpenAccessPlayerErrorTitle = [
    1 : "Please Wait",
    3 : "Connection Lost",
    4 : "DRM Protection"
]

let OverdrivePlayerErrorDescriptions = [
    0 : """
    An unknown error has occurred. Please leave the book, and try again.
    If the problem persists, go to Settings and sign out.
    """,
    1 : """
    This chapter has not finished downlading. Please wait and try again.
    """,
    2 : """
    A problem has occurred. Please leave the book and try again.
    """,
    3 : """
    The internet connection was lost during the download.
     Wait until you are back online, leave the book and try again.
    """,
    4 : """
    The download URLs for this Audiobook have expired. Please leave the book, and try again.
    """
]

/// Error Code : Alert Title
let OverdrivePlayerErrorTitle = [
    1 : "Please Wait",
    3 : "Connection Lost",
    4 : "Download Expired"
]
