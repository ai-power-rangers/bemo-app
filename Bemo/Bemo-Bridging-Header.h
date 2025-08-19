//
//  Bemo-Bridging-Header.h
//  Bemo
//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#ifndef Bemo_Bridging_Header_h
#define Bemo_Bridging_Header_h

// Only import TangramPipeline for iOS device builds (not simulator)
// This is a temporary workaround until TangramPipeline.xcframework includes simulator architectures
#if TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
#import "ObjCBridge/TPTangramPipelineWrapper.h"
#endif

#endif /* Bemo_Bridging_Header_h */
