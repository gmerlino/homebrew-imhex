class Imhex < Formula
  desc "Hex editor for reverse engineering and binary analysis"
  homepage "https://imhex.werwolv.net/"
  url "https://github.com/WerWolv/ImHex.git",
      tag:      "v1.38.1",
      revision: "76cf8771158012095d3b3ed58cc93c27ccfac7df"
  license "GPL-2.0-only"

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on xcode: :build
  depends_on "bzip2"
  depends_on "curl"
  depends_on "freetype"
  depends_on "glfw"
  depends_on "libmagic"
  depends_on "libssh2"
  depends_on "llvm"
  depends_on "lz4"
  depends_on :macos
  depends_on "mbedtls@3"
  depends_on "xz"
  depends_on "zlib"
  depends_on "zstd"

  resource "patterns" do
    url "https://github.com/WerWolv/ImHex-Patterns.git",
        tag:      "ImHex-v1.38.1",
        revision: "4646e4b9653c8b208024c5285b00f3084684021c"
  end

  def install
    # Modern libc++ no longer supplies this C standard header transitively.
    Dir.glob("lib/**/math_evaluator.cpp").each do |file|
      inreplace file, "#include <wolv/math_eval/math_evaluator.hpp>",
                     "#include <cstdlib>\n#include <wolv/math_eval/math_evaluator.hpp>"
    end
    # The macOS SDK already supplies execinfo.h; adding its C include directory
    # ahead of libc++ breaks the C++ wrapper headers with modern LLVM.
    trace_include = "target_include_directories(tracing ${LIBIMHEX_LIBRARY_TYPE_PRIVATE} ${Backtrace_INCLUDE_DIR})"
    inreplace "lib/trace/CMakeLists.txt", trace_include, "if (NOT APPLE)\n#{trace_include}\nendif()"
    inreplace "lib/libimhex/include/hex/api/task_manager.hpp", "#pragma once", "#pragma once\n#include <atomic>"
    inreplace "lib/libimhex/source/helpers/udp_server.cpp",
              "#include <hex/helpers/udp_server.hpp>", "#include <vector>\n#include <hex/helpers/udp_server.hpp>"
    inreplace "lib/external/libromfs/lib/include/romfs/romfs.hpp", "#pragma once",
              "#pragma once\n#include <type_traits>"
    inreplace "lib/libimhex/CMakeLists.txt", "${NFD_LIBRARIES} magic)", "${NFD_LIBRARIES} ${LIBMAGIC_LIBRARY})"
    converters = buildpath/"lib/third_party/HashLibPlus/Utils/Converters.h"
    File.write(converters, "#include <cstdlib>\n" + converters.read)
    yara = buildpath/"lib/third_party/yara/CMakeLists.txt"
    inreplace yara, "PRIVATE magic ", "PRIVATE ${LIBMAGIC_LIBRARY} "
    File.write(yara, yara.read + "\ntarget_include_directories(libyara PRIVATE ${LIBMAGIC_INCLUDE_DIR})\n")
    resource("patterns").stage buildpath/"build/ImHex-Patterns"
    llvm = Formula["llvm"]
    search_paths = %w[mbedtls@3 curl bzip2].map { |dep| formula_opt_prefix(dep) }.push(HOMEBREW_PREFIX).join(";")
    bundle_paths = deps.map { |dep| dep.to_formula.opt_lib.to_s }
    bundle_paths += ["#{HOMEBREW_PREFIX}/lib", "#{llvm.opt_lib}/c++", "#{llvm.opt_lib}/unwind"]
    args = %W[
      -DCMAKE_CXX_FLAGS=-Wno-elaborated-enum-base
      -DCMAKE_FIND_FRAMEWORK=LAST
      -DZLIB_INCLUDE_DIR=#{formula_opt_include("zlib")}
      -DZLIB_LIBRARY_RELEASE=#{formula_opt_lib("zlib")}/libz.dylib
      -DCMAKE_C_COMPILER=#{llvm.opt_bin}/clang
      -DCMAKE_CXX_COMPILER=#{llvm.opt_bin}/clang++
      -DCMAKE_OBJC_COMPILER=#{llvm.opt_bin}/clang
      -DCMAKE_OBJCXX_COMPILER=#{llvm.opt_bin}/clang++
      -DCMAKE_PREFIX_PATH=#{search_paths}
      -DIMHEX_GENERATE_PACKAGE=ON
      -DIMHEX_SYSTEM_LIBRARY_PATH=#{bundle_paths.join(";")}
      -DIMHEX_STRICT_WARNINGS=OFF
      -DIMHEX_BUNDLE_PLUGIN_SDK=ON
      -DCMAKE_DISABLE_FIND_PACKAGE_CoreClrEmbed=ON
    ]
    system "cmake", "-S", ".", "-B", "build", "-G", "Ninja", *std_cmake_args, *args
    system "cmake", "--build", "build"
    system "cmake", "--build", "build", "--target", "unit_tests"
    system "ctest", "--test-dir", "build", "--output-on-failure", "-E", "Helpers/(StoreAPI|TipsAPI|ContentAPI)"
    system "cmake", "--install", "build"
    bin.install_symlink prefix/"imhex.app/Contents/MacOS/imhex"
  end

  post_install_steps do
    run "/usr/bin/codesign", args:           ["--force", "--deep", "--sign", "-", "{{prefix}}/imhex.app"],
                             writable_paths: ["{{prefix}}/imhex.app"]
  end

  def caveats
    <<~EOS
      GUI: #{opt_prefix}/imhex.app
      Configuration, user plugins and patterns remain in their standard ImHex locations.
      Includes the plugins supplied by the macOS release; optional .NET scripting is not enabled.
      Binary third-party plugins must match the ImHex version and compiler ABI.
    EOS
  end

  test do
    ENV["CFFIXED_USER_HOME"] = testpath.to_s
    assert_match version.to_s, shell_output("/usr/bin/script -q /dev/null #{bin}/imhex --version")
    (testpath/"sample.bin").write "abc"
    expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    assert_match expected,
                 shell_output("/usr/bin/script -q /dev/null #{bin}/imhex --hash sha256 #{testpath}/sample.bin").downcase
    assert_match "42", shell_output("/usr/bin/script -q /dev/null #{bin}/imhex --calc '6 * 7'")
    (testpath/"sample.hexpat").write <<~PATTERN
      #include <std/sys.pat>
      #include <std/io.pat>
      u8 data[3] @ 0;
      std::assert(data[0] == 97 && data[1] == 98 && data[2] == 99, "Decoded values mismatch");
      std::print("PATTERN_OK");
    PATTERN
    pattern_command = "/usr/bin/script -q /dev/null #{bin}/imhex --pl run " \
                      "-i #{testpath}/sample.bin -p #{testpath}/sample.hexpat -v"
    assert_match "PATTERN_OK", shell_output(pattern_command)
    plugins = shell_output("/usr/bin/script -q /dev/null #{bin}/imhex --plugins")
    ["Built-in", "Decompressing", "Diffing", "Disassembler", "Hashes", "Remote",
     "Script Loader", "Visualizers", "Yara Rules"].each do |plugin|
      assert_match plugin, plugins
    end
  end
end
