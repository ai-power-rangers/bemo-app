#ifndef TANGRAM_PIPELINE_COST_FUNCTIONS_H
#define TANGRAM_PIPELINE_COST_FUNCTIONS_H

#include "tangram_pipeline/Types.h"
#include <ceres/ceres.h>
#include <ceres/rotation.h>
#include <opencv2/core.hpp>
#include <vector>
#include <string>

namespace tangram {

struct ReprojectionCostFunctor {
    // Friend classes that need access to getCandidateMappings
    friend class BundleAdjustment;
    friend class TrackedBA;
    
public:
    ReprojectionCostFunctor(const std::vector<cv::Point2f>& detected,
                            const std::vector<cv::Point2f>& model,
                            const std::string& shape_type,
                            double weight,
                            double f_scale)
        : detected_points_(detected), model_points_(model), shape_type_(shape_type),
          weight_sqrt_(std::sqrt(weight)), f_scale_(f_scale) {}

    template <typename T>
    bool operator()(const T* const H_params,
                    const T* const scale_param,
                    const T* const pose_params,
                    T* residuals) const {
        
        T H[3][3];
        H[0][0] = H_params[0]; H[0][1] = H_params[1]; H[0][2] = H_params[2];
        H[1][0] = H_params[3]; H[1][1] = H_params[4]; H[1][2] = H_params[5];
        H[2][0] = H_params[6]; H[2][1] = H_params[7]; H[2][2] = T(1.0);

        const T& scale = scale_param[0];
        const T& theta = pose_params[0];
        const T& tx = pose_params[1];
        const T& ty = pose_params[2];

        T cos_theta = ceres::cos(theta);
        T sin_theta = ceres::sin(theta);

        std::vector<cv::Point_<T>> projected_model_points;
        projected_model_points.reserve(model_points_.size());

        for (const auto& p_model : model_points_) {
            T model_x = T(p_model.x) * scale;
            T model_y = T(p_model.y) * scale;

            T plane_x = cos_theta * model_x - sin_theta * model_y + tx;
            T plane_y = sin_theta * model_x + cos_theta * model_y + ty;

            T projected_w = H[2][0] * plane_x + H[2][1] * plane_y + H[2][2];
            if (ceres::abs(projected_w) < T(1e-8)) {
                projected_w = T(1e-8);
            }
            T projected_x = (H[0][0] * plane_x + H[0][1] * plane_y + H[0][2]) / projected_w;
            T projected_y = (H[1][0] * plane_x + H[1][1] * plane_y + H[1][2]) / projected_w;
            
            projected_model_points.push_back({projected_x, projected_y});
        }

        // In-optimization correspondence search
        auto candidates = getCandidateMappings(detected_points_, shape_type_);
        T min_cost = T(std::numeric_limits<double>::max());
        int best_candidate_idx = -1;

        for (size_t c_idx = 0; c_idx < candidates.size(); ++c_idx) {
            const auto& cand_double = candidates[c_idx];
            T cost = T(0.0);
            for (size_t i = 0; i < projected_model_points.size(); ++i) {
                T dx = (projected_model_points[i].x - T(cand_double[i].x)) * T(weight_sqrt_);
                T dy = (projected_model_points[i].y - T(cand_double[i].y)) * T(weight_sqrt_);
                // Robust Huber cost aligned with Python: rho((r/f_scale)^2)
                T fs = T(f_scale_);
                T rx = dx / fs;
                T ry = dy / fs;
                T sx2 = rx * rx;
                T sy2 = ry * ry;
                auto huber = [](const T& s2) {
                    return (s2 <= T(1.0)) ? s2 : (T(2.0) * ceres::sqrt(s2) - T(1.0));
                };
                cost += huber(sx2) + huber(sy2);
            }
            if (cost < min_cost) {
                min_cost = cost;
                best_candidate_idx = c_idx;
            }
        }

        if (best_candidate_idx != -1) {
            const auto& best_cand_double = candidates[best_candidate_idx];
            for (size_t i = 0; i < projected_model_points.size(); ++i) {
                residuals[2 * i] = weight_sqrt_ * (projected_model_points[i].x - T(best_cand_double[i].x));
                residuals[2 * i + 1] = weight_sqrt_ * (projected_model_points[i].y - T(best_cand_double[i].y));
            }
        } else {
            for (size_t i = 0; i < model_points_.size(); ++i) {
                residuals[2 * i] = T(0.0);
                residuals[2 * i + 1] = T(0.0);
            }
        }

        return true;
    }
    
    // Public method for getting candidate mappings (used by BundleAdjustment and TrackedBA)
    static std::vector<std::vector<cv::Point2f>> getCandidateMappings(const std::vector<cv::Point2f>& pts, const std::string& shape_type) {
        std::vector<std::vector<cv::Point2f>> cands;
        if (pts.empty()) return cands;
        
        size_t n = pts.size();
        
        // Cyclic shifts
        for (size_t k = 0; k < n; ++k) {
            std::vector<cv::Point2f> rolled = pts;
            std::rotate(rolled.begin(), rolled.begin() + k, rolled.end());
            cands.push_back(rolled);
        }

        // Reversed options for triangles and quads
        if (shape_type == "triangle" || shape_type == "parallelogram" || shape_type == "square" || n == 3 || n == 4) {
            std::vector<cv::Point2f> pts_rev = pts;
            std::reverse(pts_rev.begin(), pts_rev.end());
            for (size_t k = 0; k < n; ++k) {
                std::vector<cv::Point2f> rolled = pts_rev;
                std::rotate(rolled.begin(), rolled.begin() + k, rolled.end());
                cands.push_back(rolled);
            }
        }
        return cands;
    }

    const std::vector<cv::Point2f> detected_points_;
    const std::vector<cv::Point2f> model_points_;
    const std::string shape_type_;
    const double weight_sqrt_;
    const double f_scale_;
};

struct HPriorCostFunctor {
    HPriorCostFunctor(const double* h_prior, double lambda_h)
        : lambda_h_sqrt_(std::sqrt(lambda_h)) {
        std::copy(h_prior, h_prior + 8, h_prior_);
    }

    template <typename T>
    bool operator()(const T* const h_params, T* residuals) const {
        for (int i = 0; i < 8; ++i) {
            residuals[i] = T(lambda_h_sqrt_) * (h_params[i] - T(h_prior_[i]));
        }
        return true;
    }

private:
    double h_prior_[8];
    const double lambda_h_sqrt_;
};

struct ScalePriorCostFunctor {
    ScalePriorCostFunctor(double scale_prior, double lambda_s)
        : scale_prior_(scale_prior), lambda_s_sqrt_(std::sqrt(lambda_s)) {}

    template <typename T>
    bool operator()(const T* const scale_param, T* residuals) const {
        residuals[0] = T(lambda_s_sqrt_) * (scale_param[0] - T(scale_prior_));
        return true;
    }

private:
    const double scale_prior_;
    const double lambda_s_sqrt_;
};

} // namespace tangram

#endif // TANGRAM_PIPELINE_COST_FUNCTIONS_H