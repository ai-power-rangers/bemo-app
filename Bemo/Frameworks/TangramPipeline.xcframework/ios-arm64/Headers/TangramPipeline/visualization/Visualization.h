#ifndef TANGRAM_PIPELINE_VISUALIZATION_H
#define TANGRAM_PIPELINE_VISUALIZATION_H

#include "tangram_pipeline/Types.h"
#include <opencv2/core.hpp>
#include <string>

namespace tangram {
namespace visualization {

/**
 * @brief Draws the main frame visualization with detected polygons and model reprojections.
 * @param io_frame The frame to draw on (modified in place).
 * @param solution The bundle adjustment solution containing poses, H, scale, etc.
 * @param detected_points_map A map from class_id to the detected polygon in pixel coordinates.
 * @param models A map of all loaded tangram models, used for vertices and names.
 */
void drawFrameVisualization(
    cv::Mat& io_frame,
    const BASolution& solution,
    const std::map<int, std::vector<cv::Point2f>>& detected_points_map,
    const std::map<std::string, TangramModel>& models
);

// Overload that loads tangram colors from assets dir (.mtl Kd RGB) for accurate coloring
void drawFrameVisualization(
    cv::Mat& io_frame,
    const BASolution& solution,
    const std::map<int, std::vector<cv::Point2f>>& detected_points_map,
    const std::map<std::string, TangramModel>& models,
    const std::string& assets_dir
);

// Utility to load colors from assets directory
std::map<std::string, cv::Scalar> loadTangramColorsFromAssets(const std::string& assets_dir);

/**
 * @brief Draws the tracking status overlay (quality, mode, lock status).
 * @param io_frame The frame to draw on (modified in place).
 * @param solution The bundle adjustment solution containing tracking metadata.
 */
void drawTrackingState(cv::Mat& io_frame, const BASolution& solution, double fps = -1.0);

/**
 * @brief Creates a visualization of the 2D plane, showing model and back-projected points.
 * @param solution The bundle adjustment solution.
 * @param detected_points_map A map from class_id to the detected polygon in pixel coordinates.
 * @param models A map of all loaded tangram models.
 * @return A new cv::Mat containing the plane visualization.
 */
cv::Mat createPlaneVisualization(
    const BASolution& solution,
    const std::map<int, std::vector<cv::Point2f>>& detected_points_map,
    const std::map<std::string, TangramModel>& models
);

/**
 * @brief Saves the plane coordinates to a JSON file with a Y-flipped coordinate system.
 * @param path The output file path for the JSON file.
 * @param solution The bundle adjustment solution.
 * @param models A map of all loaded tangram models.
 */
void savePlaneCoordinatesToJson(
    const std::string& path,
    const BASolution& solution,
    const std::map<std::string, TangramModel>& models
);

} // namespace visualization
} // namespace tangram

#endif // TANGRAM_PIPELINE_VISUALIZATION_H