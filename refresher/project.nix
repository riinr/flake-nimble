{ pkgs, inputs ? {}, ...}:

let 
  GLOB        = "$PRJ_ROOT/../nimpkgs";
  GLOB_CACHES = "*.{json,lock}";
  GLOB_HEAD   = "${GLOB}/*/*/[a-zA-Z_][a-zA-Z_]*";
  GLOB_PROJS  = "${GLOB}/*/*";
  GLOB_TAG    = "${GLOB}/*/*/[0-9vV][0-9_]*";
  compiler    = pkgs.runCommand "compilerPKG" {} ''
    mkdir -p $out/
    cp -r ${inputs.nim-src or ./.}/compiler $out/compiler
  '';
  nimbleDep   = pkgs.runCommand "nimblePKG" {} ''
    mkdir -p $out/
    cp -r ${inputs.nimble-src or ./.}/src/nimblepkg $out/nimblepkg
  '';
  nimbleDev   = pkgs.nimPackages.buildNimPackage {
    pname = "nimble-master";
    version = "0.14.0-master";
    src = inputs.nimble-src;
  };
in
{
  imports = [ ./packages_other.nix ./alias_other.nix ./nix_deps.nix ./stats.nix ];
  env = [
    { name = "NIMBLE_DIR"; eval = "$PRJ_DATA_DIR/nimble"; }
  ];
  devshell.startup.nimble-dir.text = ''
    mkdir -p $NIMBLE_DIR
  '';

  files.gitignore.pattern."refresher/*.json" = true;
  files.gitignore.pattern."result"           = true;
  files.gitignore.pattern."result-*"         = true;
  files.gitignore.pattern.".*"               = true;
  files.gitignore.pattern.".nimble"          = true;
  files.gitignore.enable      = true;
  files.cmds.gcc              = true;
  files.cmds.git              = true;
  files.cmds.jq               = true;
  files.cmds.yj               = true;
  files.cmds.graphviz         = true;
  files.alias.nimble-locker   = "${nimbleDev}/bin/nimble $@";
  files.alias.bin-results     = "find -L ${GLOB_PROJS} -type f -wholename '*/bin/*'";
  files.alias.pkg-descr       = "cat `pkg-dir $1`/meta.json|jq '.description'";
  files.alias.pkg-dir         = "echo ${GLOB}/`echo $1|cut -c1`/$1";
  files.alias.pkg-url         = "cat `pkg-dir $1`/meta.json|jq -r '.url'";
  files.alias.pkg-versions    = "find `pkg-dir $1`/*/ -type d|grep -v .git";
  files.alias.pkg-deps        = ''
    cat `pkg-dir $1`/*/meta.json|\
    jq -r '(.requires ? []).name' 2>/dev/null|sort -u
  '';
  files.alias.pkg-dependants  = ''
    grep -ri $1 ${GLOB_PROJS}/*/flake.nix|cut -d':' -f1|\
      awk -F'/' '{print $(NF-2)}'|sort -u
  '';
  files.alias.pkgs            = "find ${GLOB}/*/* -maxdepth 0|awk -F/ '{print $NF}'";
  files.alias.pkgs-update     = ''exec "$PRJ_ROOT/updatePkgs.nims" "$@"'';
  files.alias.pkgs-weights    = "depWeight  $1 ${GLOB_PROJS}/*/meta.json|sort";
  files.alias.pkgs-mindmap    = "depMindmap $1 ${GLOB_HEAD}/meta.json";
  files.alias.pkgs-dots       = ''
    echo 'digraph NimPkgs {'
    depDots $1 ${GLOB_HEAD}/meta.json
    echo '}'
  '';
  files.alias.pkgs-graph      = ''
    echo 'graph NimPkgs;'
    depDots $1 ${GLOB_HEAD}/meta.json|sed 's/ -> /-->/'|awk '{print "    "$1";"}'
  '';
  files.alias.rm-cache        = "rm ${GLOB_PROJS}/${GLOB_CACHES}";
  files.alias.rm-cache-head   = "rm ${GLOB_HEAD}/${GLOB_CACHES}";
  files.alias.rm-cache-tags   = "rm ${GLOB_TAG}/${GLOB_CACHES}";
  files.alias.rm-result       = "rm ${GLOB_PROJS}/result";
  files.alias.rm-result-head  = "rm ${GLOB_HEAD}/result";
  files.alias.rm-result-tags  = "rm ${GLOB_TAG}/result";
  files.alias.count-versions  = ''
    find ${GLOB_PROJS}/*/ -maxdepth 1 -name flake.nix|\
      awk -F'/' '{print $(NF-2)}' |\
      uniq -c                     |\
      sort -h                     |\
      awk -F' ' '{print $1","$2}'
  '';
  files.alias.count-versions-initials = ''
    find ${GLOB_PROJS}/*/ -maxdepth 1 -name flake.nix|\
      awk -F'/' '{print $(NF-3)}' |\
      uniq -c                     |\
      sort -h                     |\
      awk -F' ' '{print $1","$2}'
  '';
  files.alias.count-weights           = ''
    pkgs-weights $1               |\
      awk -F, '{print $1}'        |\
      sort                        |\
      uniq -c                     |\
      awk -F' ' '{print $2","$1}' |\
      sort -h
  '';
  files.alias.count-initials          = ''
    find ${GLOB}/*/ -maxdepth 1 -mindepth 1 -type d |\
      awk -F'/' '{print $(NF-1)}' |\
      uniq -c                     |\
      sort -h                     |\
      awk -F' ' '{print $1","$2}'
  '';
  files.alias.count-contributions     = ''
    grep '"url"' ${GLOB_PROJS}/meta.json|\
      awk '{print $3}'      |\
      tr -d '"'             |\
      sed 's#git@##'        |\
      sed 's#.com:#.com/#'  |\
      sed -E 's#[^:]+://##' |\
      sort -u               |\
      awk -F'/' '{print $2}'|\
      sort                  |\
      uniq -c               |\
      sort -h               |\
      awk -F' ' '{print $1","$2}'
  '';
  files.nim.depWeight   = builtins.readFile ./depWeight.nim;
  files.nim.outprofiler = builtins.readFile ./outprofiler.nim;
  files.nim.updateFlake = { src = builtins.readFile ./updateFlake.nim; deps = [ nimbleDep ]; };
  files.nim.updateNimbleLock   = { src = builtins.readFile ./updateNimbleLock.nim;   deps = [ compiler nimbleDep ]; };
  files.nim.updateRevs  = { src = builtins.readFile ./updateRevs.nim; deps = [ compiler nimbleDep ]; };
  files.nim.updateLock  = builtins.readFile ./updateLock.nim;
  files.nim.updateMeta  = builtins.readFile ./updateMeta.nim;
  files.nim.depDots     = builtins.readFile ./depDots.nim;
  files.nim.depMindmap  = builtins.readFile ./depMindmap.nim;
}
