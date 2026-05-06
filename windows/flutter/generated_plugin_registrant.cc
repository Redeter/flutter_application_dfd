//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

<<<<<<< Updated upstream

void RegisterPlugins(flutter::PluginRegistry* registry) {
=======
#include <flutter_secure_storage_windows/flutter_secure_storage_windows_plugin.h>
#include <flutter_timezone/flutter_timezone_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterSecureStorageWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterSecureStorageWindowsPlugin"));
  FlutterTimezonePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterTimezonePluginCApi"));
>>>>>>> Stashed changes
}
