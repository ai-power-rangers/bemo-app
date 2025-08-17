#ifndef TANGRAM_PIPELINE_TANGRAMPIPELINE_H
#define TANGRAM_PIPELINE_TANGRAMPIPELINE_H

#include "tangram_pipeline/Types.h"
#include <memory>
#include <string>
#include <vector>
#include <map>
#include <opencv2/core.hpp>

namespace tangram {

// Forward declarations
class Refiner;
class TrackedBA;

class TangramPipeline {
public:
    /**
     * @brief Constructs the Tangram Pipeline.
     * @param modelsPath Path to the tangram_shapes_2d.json file.
     */
    TangramPipeline(const std::string& modelsPath);
    ~TangramPipeline();

    /**
     * @brief Processes a single camera frame to detect and track tangram pieces.
     *
     * @param frame The camera frame in BGR format.
     * @param detections A vector of raw detections from the YOLO model.
     * @param protoMasks The 32x160x160 proto-mask output from the YOLO model.
     * @return A BASolution struct containing the final, temporally-smoothed pose solution.
     */
    BASolution processFrame(const cv::Mat& frame, const std::vector<Detection>& detections, const cv::Mat& protoMasks);
    
    /**
     * @brief Processes a frame using polygon vertex labels directly (for testing).
     *
     * @param frame The camera frame in BGR format.
     * @param polygonData Vector of pairs containing class_id and polygon vertices.
     * @return A BASolution struct containing the final pose solution.
     */
    BASolution processFrameWithPolygons(const cv::Mat& frame, 
                                       const std::vector<std::pair<int, std::vector<cv::Point2f>>>& polygonData);

    /**
     * @brief Resets the internal state of the tracker.
     */
    void reset();

    /**
     * @brief Enables or disables the homography locking feature.
     * Toggling this will reset the tracker.
     * @param enabled True to enable locking, false to disable.
     */
    void toggleLocking(bool enabled);
    
    /**
     * @brief Get the loaded tangram models.
     * @return Map of model name to TangramModel.
     */
    const std::map<std::string, TangramModel>& getTangramModels() const { return tangram_models_; }
    /**
     * @brief Returns the last detected polygons (in pixel coordinates) by class id for the most recent frame.
     */
    const std::map<int, std::vector<cv::Point2f>>& getLastDetectedPointsMap() const { return last_detected_points_map_; }

    // Visualization helpers (generate overlays in C++)
    cv::Mat renderFrameOverlay(const cv::Mat& frame_bgr, const BASolution& solution) const;
    cv::Mat renderPlaneVisualization(const BASolution& solution) const;
    
    // Access loaded models (for Python convenience)
    const std::map<std::string, TangramModel>& models() const { return tangram_models_; }

private:
    std::map<std::string, TangramModel> tangram_models_;
    std::unique_ptr<Refiner> refiner_;
    std::unique_ptr<TrackedBA> trackedBA_;
    double last_timestamp_ = 0.0;
    // Cache last detected points in pixel coordinates by class id for visualization
    std::map<int, std::vector<cv::Point2f>> last_detected_points_map_;

    static std::string getModelNameFromClass(int class_id);
    static std::string getShapeTypeFromClass(int class_id);
};

} // namespace tangram

#endif // TANGRAM_PIPELINE_TANGRAMPIPELINE_H