{ cmake
, cppzmq
, doxygen
, fetchFromGitLab
, tango-idl
, graphviz
, lib
, libjpeg_turbo
, libsodium
, pkg-config
, stdenv
, zeromq
, zlib
, omniorb
}:
stdenv.mkDerivation rec {
  pname = "cpptango";
  version = "10.0.0";

  src = fetchFromGitLab {
    owner = "tango-controls";
    repo = pname;
    rev = version;
    hash = "sha256-LaB/C871fCJtF3CLNZp4qaEH1JAde0jP/fyKnHqYou4=";
  };

  enableParallelBuilding = true;
  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [
    zlib
    omniorb
    zeromq
    cppzmq
    tango-idl
    libjpeg_turbo
    libsodium
    doxygen
    # needed for the docs
    graphviz
  ];
  propagatedBuildInputs = [
    omniorb
    cppzmq
    zeromq
    libjpeg_turbo
    libsodium
  ];

  # cmakeFlags = [
  #   "-DCMAKE_SKIP_RPATH=ON"
  # ];

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
