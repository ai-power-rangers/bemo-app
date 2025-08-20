#ifndef TANGRAM_PIPELINE_TRACKED_BA_H
#define TANGRAM_PIPELINE_TRACKED_BA_H

#include "tangram_pipeline/Types.h"
#include "tangram_pipeline/bundle_adjustment/KalmanTracker.h"
#include "tangram_pipeline/bundle_adjustment/BundleAdjustment.h"
#include <memory>
#include <vector>

namespace tangram {

class TrackedBA {
public:
    TrackedBA();

    BASolution processFrame(const BAInputs& inputs, double timestamp);

    void reset();

    void setLockingEnabled(bool enabled);
    bool isLockingEnabled() const { return locking_enabled_; }
    bool isHomographyLocked() const { return homography_locked_; }

    // Introspection helpers
    bool hasInitializedTracker() const { return tracker_ && tracker_->isInitialized(); }
    bool getLastUsedWarmStart() const { return last_used_warm_start_; }
    double getLastOptimizationTimeMs() const { return last_optimization_time_ms_; }

private:
    struct PoseSelectionResult {
        Pose pose;
        Correspondence correspondence;
        double cost;
    };
    
    // Configuration
    bool locking_enabled_ = true;
    int frames_needed_for_lock_ = 5;
    double lock_error_threshold_ = 5.0;
    double unlock_error_threshold_ = 15.0;
    double error_rejection_threshold_ = 2.0;
    double h_update_min_improvement_ = 0.05;
    double h_update_max_norm_ = 0.10;

    // State
    std::unique_ptr<KalmanTracker> tracker_;
    std::unique_ptr<BundleAdjustment> ba_solver_;
    double previous_mean_error_ = -1.0;
    cv::Matx33d accepted_H_;
    double accepted_scale_ = 1.0;
    
    // Locking state
    bool homography_locked_ = false;
    cv::Matx33d locked_H_;
    double locked_scale_ = 1.0;
    int frames_stable_ = 0;
    
    // Private helpers
    cv::Mat buildAdaptiveMeasurementCovariance(const std::map<int, double>& errors, const std::vector<int>& class_ids) const;
    
    PoseSelectionResult selectBestPoseAndCorrespondence(
        const std::vector<cv::Point2f>& detected,
        const std::vector<cv::Point2f>& model,
        const std::string& shape_type,
        const cv::Matx33d& H,
        double scale,
        const Pose& init_pose
    ) const;

    // Telemetry of last run
    bool last_used_warm_start_ = false;
    double last_optimization_time_ms_ = 0.0;
};

} // namespace tangram

#endif // TANGRAM_PIPELINE_TRACKED_BA_H