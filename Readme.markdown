# Brows Personæ

The concept is simple: When you browse the web with Brows Personæ, you do so under a particular persona—an identity consisting of your cookies, history, etc. Each site you *intend to visit* comes with its own persona, to help suppress cross-site tracking.

## Release Status and Building

Brows Personæ is currently in active development in preparation for an alpha release. There is no signed and compiled app bundle yet, and building is—an interesting process. You're encouraged to try, though…

1. pull the WebKit submodule
1. ensure there are no spaces or special shell characters in the path to WebKit
2. find all references to my code signing identity and replace them with yours
2. compile the WebKit xcworkspace **using Xcode,** in **Release** mode
3. build Brows Personæ

…and get in touch (via [Issues][tissue]) if you need help.





[tissue]: https://github.com/talusbb/Brows-Personae/issues
