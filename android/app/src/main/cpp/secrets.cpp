#include <jni.h>
#include <string>
#include <vector>
#include <fstream>
#include <sstream>
#include <cstring>
#include <unistd.h>

namespace {

// XOR key — বিল্ডে পরিবর্তন করুন; একাধিক ফাইলে ভাগ করা যায়
constexpr uint8_t kXorKey = 0xA7;

// উদাহরণ: "api.example.com" — প্রোডাকশনে নিজের হোস্ট এনকোড করুন
// "api.example.com" XOR 0xA7
const std::vector<uint8_t> kEncApiHost = {
    0xC6, 0xD7, 0xCE, 0x89, 0xC2, 0xDF, 0xC6, 0xCA, 0xD7, 0xCB, 0xC2, 0x89, 0xC4, 0xC8, 0xCA,
};

std::string xorDecode(const std::vector<uint8_t>& data) {
  std::string out;
  out.reserve(data.size());
  for (uint8_t b : data) {
    out.push_back(static_cast<char>(b ^ kXorKey));
  }
  return out;
}

bool isTracerAttached() {
  std::ifstream status("/proc/self/status");
  if (!status.is_open()) return false;
  std::string line;
  while (std::getline(status, line)) {
    if (line.rfind("TracerPid:", 0) == 0) {
      std::istringstream iss(line.substr(10));
      int pid = 0;
      iss >> pid;
      return pid > 0;
    }
  }
  return false;
}

bool mapsContainFrida() {
  std::ifstream maps("/proc/self/maps");
  if (!maps.is_open()) return false;
  std::string content((std::istreambuf_iterator<char>(maps)),
                      std::istreambuf_iterator<char>());
  return content.find("frida") != std::string::npos ||
         content.find("gadget") != std::string::npos ||
         content.find("libfrida") != std::string::npos;
}

volatile bool g_tamperDetected = false;

}  // namespace

extern "C" JNIEXPORT jboolean JNICALL
Java_com_kakonzone_lumio_MainActivity_nativeIntegrityOk(JNIEnv*, jobject) {
  if (g_tamperDetected) return JNI_FALSE;
  if (isTracerAttached()) {
    g_tamperDetected = true;
    return JNI_FALSE;
  }
  if (mapsContainFrida()) {
    g_tamperDetected = true;
    return JNI_FALSE;
  }
  return JNI_TRUE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_kakonzone_lumio_MainActivity_nativeGetSecret(JNIEnv* env, jobject, jstring key) {
  if (g_tamperDetected || isTracerAttached() || mapsContainFrida()) {
    return env->NewStringUTF("");
  }

  const char* keyChars = env->GetStringUTFChars(key, nullptr);
  std::string keyStr(keyChars ? keyChars : "");
  env->ReleaseStringUTFChars(key, keyChars);

  if (keyStr == "api_host") {
    return env->NewStringUTF(xorDecode(kEncApiHost).c_str());
  }
  return env->NewStringUTF("");
}
