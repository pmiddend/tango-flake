{ cmake
, fetchFromGitLab
, lib
, pkg-config
, stdenv
}:
stdenv.mkDerivation rec {
  pname = "tango-idl";
  version = "6.0.2";

  src = fetchFromGitLab {
    owner = "tango-controls";
    repo = pname;
    rev = version;
    hash = "sha256-S47XWNJrcXp2AFyxYaO6OcxVeFk7bryCgjfaPZ/aWuo=";
  };

  enableParallelBuilding = true;
  nativeBuildInputs = [ cmake pkg-config ];

  postPatch = ''
    sed -i -e 's#libdir=.*#libdir=@CMAKE_INSTALL_FULL_LIBDIR@#' cmake/tangoidl.pc.cmake
  '';

  meta = with lib; {
    description = "Tango CORBA IDL file";
    homepage = "https://www.tango-controls.org";
    changelog = "https://gitlab.com/tango-controls/cppTango/-/blob/${version}/RELEASE_NOTES.md";
    downloadPage = "https://gitlab.com/tango-controls/TangoSourceDistribution/-/releases";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ pmiddend ];
    platforms = platforms.unix;
  };

}
