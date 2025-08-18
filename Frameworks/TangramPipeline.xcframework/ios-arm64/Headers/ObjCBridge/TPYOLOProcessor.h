#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>
#import <Vision/Vision.h>
#import <CoreVideo/CoreVideo.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Detection result from YOLO
@interface TPDetection : NSObject
@property (nonatomic) CGRect bbox;              // Normalized coordinates (0-1)
@property (nonatomic) NSInteger classId;
@property (nonatomic, copy) NSString *className;
@property (nonatomic) float confidence;
@end

// Segmentation result containing detections and mask
@interface TPSegmentationResult : NSObject
@property (nonatomic, strong, nullable) UIImage *maskImage;
@property (nonatomic, copy) NSArray<TPDetection *> *detections;
@property (nonatomic) CGSize originalImageSize;
@end

// YOLO model configuration
@interface TPYOLOModelConfig : NSObject
@property (nonatomic, copy) NSString *modelName;
@property (nonatomic) NSInteger inputSize;      // 640 for YOLO
@property (nonatomic) NSInteger numClasses;     // 7 for tangram
@property (nonatomic) float confidenceThreshold;
@property (nonatomic) float iouThreshold;       // For NMS
@end

// Main YOLO processor class
@interface TPYOLOProcessor : NSObject

// Initialize with model path or name
- (nullable instancetype)initWithModelPath:(NSString *)modelPath
                                    config:(TPYOLOModelConfig *)config
                                     error:(NSError **)error;

// Process a frame and return segmentation results
- (nullable TPSegmentationResult *)processFrame:(CVPixelBufferRef)pixelBuffer
                                       viewSize:(CGSize)viewSize
                                          error:(NSError **)error;

// Get raw YOLO outputs for integration with TangramPipeline
- (nullable NSDictionary *)getRawOutputsForFrame:(CVPixelBufferRef)pixelBuffer
                                            error:(NSError **)error;

// Class names for tangram shapes
@property (nonatomic, readonly, copy) NSArray<NSString *> *classNames;

// Performance metrics
@property (nonatomic, readonly) double lastInferenceTimeMs;
@property (nonatomic, readonly) double averageFPS;

@end

NS_ASSUME_NONNULL_END
