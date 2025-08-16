#ifndef TANGRAM_PIPELINE_KALMAN_TRACKER_H
#define TANGRAM_PIPELINE_KALMAN_TRACKER_H

#include "tangram_pipeline/Types.h"
#include <opencv2/core.hpp>
#include <set>
#include <vector>
#include <map>

namespace tangram {

class KalmanTracker {
public:
    KalmanTracker(double process_noise_scale = 0.01, double measurement_noise_scale = 1.0);

    void initialize(const cv::Matx33d& H, double scale, const std::map<int, Pose>& poses, double timestamp);

    void predict(double dt);

    void update(const cv::Matx33d& H_meas, double scale_meas, const std::map<int, Pose>& poses_meas, const cv::Mat& measurement_cov);
    // Overload with default (empty) covariance to mirror Python API convenience
    void update(const cv::Matx33d& H_meas, double scale_meas, const std::map<int, Pose>& poses_meas) {
        cv::Mat empty; update(H_meas, scale_meas, poses_meas, empty);
    }

    void getState(cv::Matx33d& H, double& scale, std::map<int, Pose>& poses) const;

    double getTrackingQuality() const;

    bool isInitialized() const { return initialized_; }
    
    // Friend class for TrackedBA to access private members
    friend class TrackedBA;

private:
    bool initialized_ = false;
    static constexpr int N_STATES = 30; // 8 (H) + 1 (scale) + 7 * 3 (poses)
    static constexpr int N_OBJECTS = 7;

    cv::Mat state_; // State vector [30 x 1] CV_64F
    cv::Mat P_;     // Covariance matrix [30 x 30] CV_64F
    double timestamp_ = 0.0;
    std::set<int> observed_objects_;

    // Noise parameters
    double process_noise_scale_;
    double measurement_noise_scale_;

    // Tracking quality
    std::vector<double> innovation_history_;
    static constexpr int MAX_INNOVATION_HISTORY = 10;
};

} // namespace tangram

#endif // TANGRAM_PIPELINE_KALMAN_TRACKER_H