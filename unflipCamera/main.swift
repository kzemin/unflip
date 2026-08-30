import CoreMediaIO
import Foundation

let providerSource = UnflipProviderSource(clientQueue: nil)
CMIOExtensionProvider.startService(provider: providerSource.provider)

CFRunLoopRun()
