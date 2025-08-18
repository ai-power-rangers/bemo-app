#ifndef TANGRAM_PIPELINE_UTILS_LABELLOADER_H
#define TANGRAM_PIPELINE_UTILS_LABELLOADER_H

#include <string>
#include <vector>
#include <opencv2/core/types.hpp>

namespace tangram {

class LabelLoader {
public:
    /**
     * @brief Load polygon labels from YOLO format label file.
     * 
     * @param labelPath Path to the label file.
     * @param imageWidth Width of the corresponding image.
     * @param imageHeight Height of the corresponding image.
     * @return Vector of pairs containing class_id and polygon vertices in pixel coordinates.
     */
    static std::vector<std::pair<int, std::vector<cv::Point2f>>> loadPolygonLabels(
        const std::string& labelPath,
        int imageWidth,
        int imageHeight
    );
    
    /**
     * @brief Load image and corresponding labels from test directory structure.
     * 
     * @param testDir Base directory (e.g., "/Users/alanli/yoloDetector/test2")
     * @param imageName Image filename without extension (e.g., "000000000000")
     * @param image Output image
     * @param polygons Output polygon data
     * @return true if successful, false otherwise
     */
    static bool loadTestCase(
        const std::string& testDir,
        const std::string& imageName,
        cv::Mat& image,
        std::vector<std::pair<int, std::vector<cv::Point2f>>>& polygons
    );
};

} // namespace tangram

#endif // TANGRAM_PIPELINE_UTILS_LABELLOADER_H
