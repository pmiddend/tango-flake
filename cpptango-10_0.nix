{ cmake
, cppzmq
, doxygen
, fetchFromGitLab
, opentelemetry-cpp
, openssl
, tango-idl-6
, protobuf
, graphviz
, grpc
, lib
, libjpeg_turbo
, libsodium
, pkg-config
, stdenv
, zeromq
, zlib
, omniorb
}:
let
  mainSrc = fetchFromGitLab {
    name = "main";
    owner = "tango-controls";
    repo = "cpptango";
    rev = "10.0.0";
    hash = "sha256-LaB/C871fCJtF3CLNZp4qaEH1JAde0jP/fyKnHqYou4=";
  };
in
stdenv.mkDerivation rec {
  pname = "cpptango";
  version = "10.0.0";

  srcs = [
    mainSrc
    (fetchFromGitLab {
      owner = "tango-controls";
      repo = "TangoCMakeModules";
      rev = "dfc42901855bc7aae72a132e6f3373bab8660747";
      hash = "sha256-irNv0m2q4Bd2zv+O/y6JAohCDMVRx7ZhALNv96wQRxA=j";
      name = "TangoCMakeModules";
    })
  ];

  # this is copied from the nixpkgs package for blender
  postUnpack = ''
    chmod -R u+w *
    mv TangoCMakeModules --target-directory main
  '';

  sourceRoot = "main";

  enableParallelBuilding = true;
  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [
    zlib
    omniorb
    zeromq
    cppzmq
    tango-idl-6
    libjpeg_turbo
    libsodium
    doxygen
    # needed for the docs
    graphviz
    grpc
    protobuf
    opentelemetry-cpp
    openssl
  ];
  propagatedBuildInputs = [
    omniorb
    cppzmq
    zeromq
    libjpeg_turbo
    libsodium
  ];

  # cmakeFlags = [ "-DCMAKE_MODULE_PATH=TangoCMakeModules" ];
  cmakeFlags = [
    # "-DCMAKE_SKIP_RPATH=ON"
    # https://github.com/NixOS/nixpkgs/issues/297443
    # "-DTANGO_USE_TELEMETRY=OFF"
  ];


  postPatch = ''
    sed -i -e 's#Requires: libzmq#Requires: libzmq cppzmq#' -e 's#libdir=.*#libdir=@CMAKE_INSTALL_FULL_LIBDIR@#' tango.pc.cmake
  '';

  meta = with lib; {
    description = "Open Source solution for SCADA and DCS";
    longDescription = ''
      Tango Controls is a toolkit for connecting hardware and software together. It is a mature software which is used by tens of sites to run highly complicated accelerator complexes and experiments 24 hours a day. It is free and Open Source. It is ideal for small and large installations. It provides full support for 3 programming languages - C++, Python and Java.
    '';
    homepage = "https://www.tango-controls.org";
    changelog = "https://gitlab.com/tango-controls/cppTango/-/blob/${version}/RELEASE_NOTES.md";
    downloadPage = "https://gitlab.com/tango-controls/TangoSourceDistribution/-/releases";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ pmiddend ];
    platforms = platforms.unix;
  };

}
