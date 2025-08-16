#ifndef TANGRAM_PIPELINE_POLYGON_UTILS_H
#define TANGRAM_PIPELINE_POLYGON_UTILS_H

#include <vector>
#include <opencv2/core/types.hpp>

namespace tangram {
namespace utils {

/**
 * @brief Simplifies a polygon to a target number of vertices.
 *
 * This function attempts to simplify a polygon to have exactly `targetVertices`
 * using cv::approxPolyDP. It uses a combination of fixed epsilon values and a
 * binary search to find the best approximation.
 *
 * @param polygon The input polygon as a vector of integer points.
 * @param targetVertices The desired number of vertices in the simplified polygon.
 * @return The simplified polygon. If an exact match isn't found, it returns the
 *         best approximation found.
 */
std::vector<cv::Point> simplifyPolygon(const std::vector<cv::Point>& polygon, int targetVertices);

/**
 * @brief Orders the vertices of a polygon clockwise around its centroid.
 *
 * This is more robust than just checking the sign of the area for complex or
 * self-intersecting polygons.
 *
 * @param points The polygon vertices.
 * @return A new vector of points ordered clockwise.
 */
std::vector<cv::Point2f> orderPointsClockwise(const std::vector<cv::Point2f>& points);

/**
 * @brief Ensures that the vertices of a polygon are in clockwise order.
 *
 * This function modifies the input vector in-place if the vertices are in
 * counter-clockwise order.
 *
 * @param points The polygon vertices as a vector of floating-point points.
 */
void ensureClockwise(std::vector<cv::Point2f>& points);

} // namespace utils
} // namespace tangram

#endif // TANGRAM_PIPELINE_POLYGON_UTILS_H