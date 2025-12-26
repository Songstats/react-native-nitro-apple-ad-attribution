#import <Foundation/Foundation.h>
#import <NitroModules/HybridObjectRegistry.hpp>
#import "nitrogen/generated/ios/NitroAppleAdAttribution-Swift-Cxx-Umbrella.hpp"

using namespace margelo::nitro;
using namespace margelo::nitro::nitroappleadattribution;

static std::shared_ptr<HybridObject> createHybridObject() {
  auto swiftImplementation = [[HybridNitroAppleAdAttribution alloc] init];
  NitroAppleAdAttribution::HybridNitroAppleAdAttributionSpec_cxx swiftWrapper(swiftImplementation);
  return bridge::swift::create_std__shared_ptr_margelo__nitro__nitroappleadattribution__HybridNitroAppleAdAttributionSpec_(
    swiftWrapper.toUnsafe()
  );
}

__attribute__((constructor))
static void NitroAppleAdAttributionOnLoad() {
  HybridObjectRegistry::registerHybridObjectConstructor(
    "NitroAppleAdAttribution",
    []() -> std::shared_ptr<HybridObject> {
      return createHybridObject();
    }
  );
}
