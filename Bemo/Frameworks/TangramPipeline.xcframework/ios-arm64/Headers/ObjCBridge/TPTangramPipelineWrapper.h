#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreML/CoreML.h>
#import <UIKit/UIKit.h>
#import "TPYOLOProcessor.h"

NS_ASSUME_NONNULL_BEGIN

@interface TPTangramOptions : NSObject
@property (nonatomic) BOOL renderOverlays;   // default NO
@property (nonatomic) BOOL renderPlane;      // default NO
@property (nonatomic) BOOL lockingEnabled;   // default YES
@end

@interface TPTangramDetection : NSObject
@property (nonatomic) NSInteger classId;
@property (nonatomic) float confidence;
// YOLO model space (pixels in 640x640 model): center x/y and width/height
@property (nonatomic) float cx;
@property (nonatomic) float cy;
@property (nonatomic) float w;
@property (nonatomic) float h;
// Mask coeffs for prototype segmentation head (length typically 32)
@property (nonatomic, copy) NSArray<NSNumber*> *maskCoeffs;
@end

@interface TPPose : NSObject
@property (nonatomic) double theta;
@property (nonatomic) double tx;
@property (nonatomic) double ty;
@end

@interface TPTangramResult : NSObject
// Row-major 3x3 homography (9 entries)
@property (nonatomic, copy) NSArray<NSNumber*> *H_3x3;
@property (nonatomic) double scale;
@property (nonatomic, copy) NSDictionary<NSNumber*, TPPose*> *poses;   // classId -> pose
@property (nonatomic, copy) NSDictionary<NSNumber*, NSNumber*> *errors; // classId -> error
@property (nonatomic, copy) NSDictionary<NSNumber*, NSDictionary*> *correspondences; // optional
@property (nonatomic) double trackingQuality;
@property (nonatomic) BOOL homographyLocked;
@property (nonatomic, copy) NSDictionary<NSString*, NSNumber*> *timings_ms;

// Refined polygons per class in normalized 0-1 coordinates (model input space)
// Key: classId as string -> value: NSArray<NSNumber*> of [x1,y1,x2,y2,...]
@property (nonatomic, copy) NSDictionary<NSNumber*, NSArray<NSNumber*>*> *refinedPolygons;

// Optional overlays from C++ (BGRA). Retained inside object; released on dealloc
@property (nonatomic, assign, nullable) CVPixelBufferRef visFrame;
@property (nonatomic, assign, nullable) CVPixelBufferRef planeVisFrame;
@end

// Objective-C++ wrapper of the C++ TangramPipeline
@interface TPTangramPipelineWrapper : NSObject

- (instancetype)initWithModelsJSON:(NSString *)modelsJSONPath
                         assetsDir:(nullable NSString *)assetsDir;

// Main entry: Provide camera frame, detections, and optional proto masks
- (nullable TPTangramResult *)processFrame:(CVPixelBufferRef)pixelBuffer
                                detections:(NSArray<TPTangramDetection*> *)detections
                                protoMasks:(nullable MLMultiArray *)protoMasks_32x160x160
                                   options:(nullable TPTangramOptions *)options
                                     error:(NSError * _Nullable * _Nullable)error;



@end

// Complete pipeline result combining YOLO segmentation and tangram processing
@interface TPCompleteResult : NSObject
// YOLO outputs
@property (nonatomic, strong, nullable) UIImage *segmentationMask;
@property (nonatomic, copy) NSArray<TPDetection *> *detections;
@property (nonatomic) CGSize originalImageSize;

// Tangram outputs
@property (nonatomic, strong, nullable) TPTangramResult *tangramResult;

// Visualization overlays
@property (nonatomic, assign, nullable) CVPixelBufferRef combinedOverlay;
@property (nonatomic, assign, nullable) CVPixelBufferRef bottomSquareOverlay;

// Performance metrics
@property (nonatomic) double yoloInferenceMs;
@property (nonatomic) double tangramProcessingMs;
@property (nonatomic) double totalProcessingMs;
@end

// Complete integrated pipeline with YOLO + Tangram
@interface TPIntegratedPipeline : NSObject

- (nullable instancetype)initWithModelPath:(NSString *)modelPath
                            tangramModelsJSON:(NSString *)tangramModelsPath
                                   assetsDir:(nullable NSString *)assetsDir
                                       error:(NSError **)error;

// Process frame through complete pipeline
- (nullable TPCompleteResult *)processFrame:(CVPixelBufferRef)pixelBuffer
                                   viewSize:(CGSize)viewSize
                          confidenceThreshold:(float)confidenceThreshold
                                    options:(nullable TPTangramOptions *)options
                                      error:(NSError **)error;

// Enable/disable portrait bottom-square cropping
@property (nonatomic) BOOL enablePortraitCropping; // default YES

// Access to components
@property (nonatomic, readonly) TPYOLOProcessor *yoloProcessor;
@property (nonatomic, readonly) TPTangramPipelineWrapper *tangramPipeline;

@end

NS_ASSUME_NONNULL_END


