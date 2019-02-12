diff --git a/root/ports-www-chromium-67-orig/files/patch-gpu_config_gpu__info__collector__freebsd.cc b/root/ports-www-chromium-67/files/patch-gpu_config_gpu__info__collector__freebsd.cc
index 83f161f..13db969 100644
--- a/root/ports-www-chromium-67-orig/files/patch-gpu_config_gpu__info__collector__freebsd.cc
+++ b/root/ports-www-chromium-67/files/patch-gpu_config_gpu__info__collector__freebsd.cc
@@ -1,12 +1,60 @@
 --- gpu/config/gpu_info_collector_freebsd.cc.orig	2018-07-20 13:47:10.021258000 +0200
 +++ gpu/config/gpu_info_collector_freebsd.cc	2018-07-20 15:44:42.380444000 +0200
-@@ -0,0 +1,20 @@
+@@ -1,74 +0,0 @@
 +// Copyright 2017 The Chromium Authors. All rights reserved.
 +// Use of this source code is governed by a BSD-style license that can be
 +// found in the LICENSE file.
 +
 +#include "gpu/config/gpu_info_collector.h"
 +
++#include "base/logging.h"
++#include "base/strings/string_split.h"
++
++namespace {
++
++std::pair<std::string, size_t> GetVersionFromString(
++    const std::string& version_string,
++    size_t begin = 0) {
++  begin = version_string.find_first_of("0123456789", begin);
++  if (begin == std::string::npos)
++    return std::make_pair("", std::string::npos);
++
++  size_t end = version_string.find_first_not_of("01234567890.", begin);
++  std::string sub_string;
++  if (end != std::string::npos)
++    sub_string = version_string.substr(begin, end - begin);
++  else
++    sub_string = version_string.substr(begin);
++  std::vector<std::string> pieces = base::SplitString(
++      sub_string, ".", base::TRIM_WHITESPACE, base::SPLIT_WANT_ALL);
++  if (pieces.size() >= 2)
++    return std::make_pair(pieces[0] + "." + pieces[1], end);
++  else
++    return std::make_pair("", end);
++}
++
++std::string GetDriverVersionFromString(const std::string& version_string) {
++  // We expect that android GL_VERSION strings will be of a form
++  // similar to: "OpenGL ES 2.0 V@6.0 AU@ (CL@2946718)" where the
++  // first match to [0-9][0-9.]* is the OpenGL ES version number, and
++  // the second match to [0-9][0-9.]* is the driver version (in this
++  // case, 6.0).
++  // It is currently assumed that the driver version has at least one
++  // period in it, and only the first two components are significant.
++  size_t begin = GetVersionFromString(version_string).second;
++  if (begin == std::string::npos)
++    return "0";
++
++  std::pair<std::string, size_t> driver_version =
++      GetVersionFromString(version_string, begin);
++  if (driver_version.first == "")
++    return "0";
++
++  return driver_version.first;
++}
++
++}
++
 +namespace gpu {
 +
 +bool CollectContextGraphicsInfo(GPUInfo* gpu_info) {
@@ -19,5 +67,11 @@
 +  return false;
 +}
 +
++void CollectDriverInfoGL(GPUInfo* gpu_info) {
++  gpu_info->driver_version = GetDriverVersionFromString(
++      gpu_info->gl_version);
++  gpu_info->gpu.vendor_string = gpu_info->gl_vendor;
++  gpu_info->gpu.device_string = gpu_info->gl_renderer;
++}
 +
 +}  // namespace gpu
