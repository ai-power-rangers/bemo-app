#ifndef TANGRAM_PIPELINE_REFINEMENT_H
#define TANGRAM_PIPELINE_REFINEMENT_H

#include "tangram_pipeline/Types.h"
#include <opencv2/core.hpp>
#include <map>
#include <vector>

namespace tangram {

class Refiner {
public:
    Refiner();

    RefinementResult refine(const cv::Mat& frame_rgb,
                            const Detection& detection,
                            const cv::Mat& mask_160,
                            int expected_n = 0,
                            int grabcut_iters = 1);

private:
    struct HoughSegment {
        cv::Vec3f params; // a, b, c
        double angle;
        cv::Point p1, p2;
        double length;
        double score;
    };

    struct HoughCluster {
        std::vector<HoughSegment> segments;
        std::vector<double> angles;
        std::vector<double> cs;
        double angle_median;
        double c_median;
        double score_sum;
        double length_sum;
    };

    static cv::Mat cannyAuto(const cv::Mat& gray, double sigma = 0.33);

    static std::vector<cv::Point2f> approxPolygonFromMask(const cv::Mat& mask, int expected_n);

    static cv::Point2f intersectLines(const cv::Vec3f& line1, const cv::Vec3f& line2);

    static void fitLinesHough(
        const cv::Mat& edge_img,
        int expected_n,
        double roi_diag,
        std::vector<cv::Vec3f>& out_primary_lines,
        std::vector<cv::Vec3f>& out_secondary_lines,
        const cv::Mat& grad_mag = cv::Mat(),
        const cv::Mat& roi_mask = cv::Mat()
    );

    static const std::map<int, int> EXPECTED_VERTICES_MAP;
};

} // namespace tangram

#endif // TANGRAM_PIPELINE_REFINEMENT_H