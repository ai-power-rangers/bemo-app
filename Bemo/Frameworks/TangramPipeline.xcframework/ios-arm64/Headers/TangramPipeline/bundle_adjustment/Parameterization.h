#ifndef TANGRAM_PIPELINE_PARAMETERIZATION_H
#define TANGRAM_PIPELINE_PARAMETERIZATION_H

#include "tangram_pipeline/Types.h"
#include <opencv2/core.hpp>
#include <map>

namespace tangram {

/**
 * @brief Packs parameters into a fixed-size state vector for tracking.
 *
 * @param H Homography matrix.
 * @param scale Global scale factor.
 * @param poses Dictionary mapping class_id to pose.
 * @param n_objects Total number of objects to track (fixed state size).
 * @return A 1xN cv::Mat of type CV_64F representing the state vector.
 */
cv::Mat packParamsTracked(const cv::Matx33d& H, double scale, const std::map<int, Pose>& poses, int n_objects = 7);


/**
 * @brief Unpacks parameters from a fixed-size state vector.
 *
 * @param x The state vector (1xN or Nx1 cv::Mat of type CV_64F).
 * @param H Output homography matrix.
 * @param scale Output global scale factor.
 * @param poses Output map of class_id to pose.
 * @param n_objects Total number of objects tracked.
 */
void unpackParamsTracked(const cv::Mat& x, cv::Matx33d& H, double& scale, std::map<int, Pose>& poses, int n_objects = 7);

} // namespace tangram

#endif // TANGRAM_PIPELINE_PARAMETERIZATION_H