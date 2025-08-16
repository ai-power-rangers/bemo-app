#ifndef TANGRAM_PIPELINE_BUNDLE_ADJUSTMENT_H
#define TANGRAM_PIPELINE_BUNDLE_ADJUSTMENT_H

#include "tangram_pipeline/Types.h"

namespace tangram {

class BundleAdjustment {
public:
    BundleAdjustment();

    BASolution solve(const BAInputs& inputs, int max_iterations = 100);
};

} // namespace tangram

#endif // TANGRAM_PIPELINE_BUNDLE_ADJUSTMENT_H