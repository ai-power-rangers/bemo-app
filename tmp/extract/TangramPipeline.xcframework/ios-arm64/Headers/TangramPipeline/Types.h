#ifndef TANGRAM_PIPELINE_TYPES_H
#define TANGRAM_PIPELINE_TYPES_H

#include <vector>
#include <string>
#include <map>
#include <opencv2/core/matx.hpp>
#include <opencv2/core/types.hpp>
#include <opencv2/core/mat.hpp>

namespace tangram {

struct Pose {
    double theta, tx, ty;
};

struct Detection {
    int classId;
    cv::Rect2f bbox; // In model space (e.g., 640x640)
    std::vector<float> maskCoeffs;
};

struct Correspondence {
    int shift;
    bool reflected;
    bool mirrored_model;
};

struct BASolution {
    cv::Matx33d H;
    double scale;
    std::map<int, Pose> poses; // Map from classId to Pose
    std::map<int, double> errors;
    std::map<int, Correspondence> correspondences;
    // Tracking metadata
    double trackingQuality;
    bool homographyLocked;
    // Optional profiling timings in milliseconds per stage
    std::map<std::string, double> timings;
};

struct TangramModel {
    std::string name;
    std::string type;
    std::vector<cv::Point2f> vertices;
    // Optional color in BGR (0-255) derived from assets materials
    cv::Scalar color_bgr = cv::Scalar(128, 128, 128);
};

struct RefinementResult {
    cv::Mat refined_mask_full;
    cv::Mat refined_mask_160;
    std::vector<cv::Point2f> polygon_norm;
    // corners_norm is the same as polygon_norm in the Python implementation
    std::vector<cv::Vec3f> lines; // a, b, c
    std::vector<std::pair<cv::Point, cv::Point>> line_segments_global;
    std::vector<std::pair<cv::Point, cv::Point>> line_secondary_segments_global;
    std::map<std::string, double> timings;
};

struct BAInputs {
    std::vector<std::vector<cv::Point2f>> detected_points;
    std::vector<std::vector<cv::Point2f>> model_points;
    std::vector<std::string> shape_types;
    std::vector<int> class_ids;

    // Optional warm start
    bool has_initial_guess = false;
    cv::Matx33d H_init;
    double scale_init;
    std::vector<Pose> poses_init; // Corresponds to detected_points order
};

} // namespace tangram

#endif // TANGRAM_PIPELINE_TYPES_H