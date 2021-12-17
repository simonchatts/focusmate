# Production build of focusmate app
{ stdenv, makeWrapper, buildEnv, nushell, bash, coreutils, curl }:

let
  # Create a runtime PATH with "test" and "curl" present, and a "sh" (which
  # it turns out nushell invisibly requires to spawn anything).
  runtimeEnv = buildEnv {
    name = "focusmate-notify-env";
    paths = [ bash coreutils curl ];
  };
in
stdenv.mkDerivation {
  pname = "focusmate-notify";
  version = "1.0.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  # Copy the .nu script over without the .nu suffix, with a guaranteed nushell
  # interpeter #!, and a PATH with all its runtime dependencies.
  installPhase = ''
    mkdir -p $out/bin
    exe=$out/bin/focusmate-notify
    substitute focusmate-notify.nu $exe \
      --replace "#!/usr/bin/env nu" "#!${nushell}/bin/nu"
    chmod +x $exe
    wrapProgram $exe --set PATH "${runtimeEnv}/bin"
  '';
}
