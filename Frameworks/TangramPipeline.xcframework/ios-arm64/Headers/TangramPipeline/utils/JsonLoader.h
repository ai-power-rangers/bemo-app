#ifndef TANGRAM_PIPELINE_JSON_LOADER_H
#define TANGRAM_PIPELINE_JSON_LOADER_H

#include "tangram_pipeline/Types.h"
#include <string>
#include <map>

namespace tangram {
namespace utils {

/**
 * @brief Loads 2D tangram models from a JSON file.
 *
 * @param path The file path to the JSON file.
 * @return A map from model name (e.g., "tangram_square") to a TangramModel struct.
 * @throws std::runtime_error if the file cannot be opened or parsed.
 */
std::map<std::string, TangramModel> loadTangramModels(const std::string& path);

// Load model colors from assets directory (.mtl Kd) and annotate models' color_bgr
void loadTangramModelColorsFromAssets(std::map<std::string, TangramModel>& models, const std::string& assets_dir);

} // namespace utils
} // namespace tangram

#endif // TANGRAM_PIPELINE_JSON_LOADER_H