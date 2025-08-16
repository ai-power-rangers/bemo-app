#ifndef TANGRAM_PIPELINE_YOLO_POSTPROCESS_H
#define TANGRAM_PIPELINE_YOLO_POSTPROCESS_H

#include <vector>
#include <opencv2/core/mat.hpp>

namespace tangram {

/**
 * @brief Generates a probability mask from YOLO segmentation outputs.
 *
 * This function implements the mask generation process from YOLOv8-seg models,
 * which involves a weighted sum of prototype masks followed by a sigmoid activation.
 * The implementation is a C++ port of `generate_mask_fast` from the Python scripts.
 *
 * @param protoMasks A 3D cv::Mat of size (32, 160, 160) and type CV_32F containing
 *                   the prototype masks from the YOLO model. The caller is responsible
 *                   for handling any batch dimension from the model output.
 * @param maskCoeffs A vector of 32 float coefficients for the specific detection.
 * @param threshold A confidence threshold. Probabilities below this value will be
 *                  set to zero.
 * @return A 160x160 cv::Mat of type CV_32F containing the final probability mask.
 */
cv::Mat generateMask(const cv::Mat& protoMasks, const std::vector<float>& maskCoeffs, float threshold = 0.5f);

} // namespace tangram

#endif // TANGRAM_PIPELINE_YOLO_POSTPROCESS_H