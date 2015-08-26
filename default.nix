{ pkgs ? import <nixpkgs> {}
, ... }:

let

  stdenv = pkgs.stdenv;
  name = "hydra";
  version = "1.2.3";
  gitCommit = "b528f881f09eca94797f711880d662913eee953d";
  gitSha = "3c87ac06ce55116f20c345b54dd99fd6aac13e61251d6490b26d0ef87c9a8040";
  nix = pkgs.nixUnstable;
in

stdenv.mkDerivation rec {
  name = "${name}-${version}";
  version = version;

  src = pkgs.fetchFromGitHub {
    sha256 = gitSha;
    rev = gitCommit;
    repo = "hydra";
    owner = "polynomial";
  };
  NetStatsd = pkgs.buildPerlPackage {
    name = "Net-Statsd-0.11";
    src = pkgs.fetchurl {
      url = mirror://cpan/authors/id/C/CO/COSIMO/Net-Statsd-0.11.tar.gz;
      sha256 = "0f56c95846c7e65e6d32cec13ab9df65716429141f106d2dc587f1de1e09e163";
    };
    meta = {
      description = "Sends statistics to the stats daemon over UDP";
      license = "perl";
    };
  };

  hydraPerlPkgs = pkgs.buildEnv {
    name = "hydra-perl-packages";
    paths = with pkgs.perlPackages; [
      ModulePluggable
      CatalystActionREST
      CatalystAuthenticationStoreDBIxClass
      CatalystDevel
      CatalystDispatchTypeRegex
      CatalystPluginAccessLog
      CatalystPluginAuthorizationRoles
      CatalystPluginCaptcha
      CatalystPluginSessionStateCookie
      CatalystPluginSessionStoreFastMmap
      CatalystPluginStackTrace
      CatalystPluginUnicodeEncoding
      CatalystTraitForRequestProxyBase
      CatalystViewDownload
      CatalystViewJSON
      CatalystViewTT
      CatalystXScriptServerStarman
      CryptRandPasswd
      DBDPg
      DBDSQLite
      DataDump
      DateTime
      DigestSHA1
      EmailMIME
      EmailSender
      FileSlurp
      IOCompress
      IPCRun
      JSONXS
      LWP
      LWPProtocolHttps
      NetAmazonS3
      NetStatsd
      PadWalker
      Readonly
      SQLSplitStatement
      SetScalar
      Starman
      SysHostnameLong
      TestMore
      TextDiff
      TextTable
      XMLSimple
      nix git
    ];
  };
  buildInputs = with pkgs; [
    makeWrapper
    libtool
    unzip
    nukeReferences
    pkgconfig
    sqlite
    libpqxx
    gitAndTools.topGit
    mercurial
    darcs
    subversion
    bazaar
    openssl
    bzip2
    guile
    hydraPerlPkgs
  ];
  hydraPath = pkgs.lib.makeSearchPath "bin" ( with pkgs; [
    libxslt
    sqlite
    subversion
    openssh
    nix
    coreutils
    findutils
    gzip
    bzip2
    lzma
    gnutar
    unzip
    git
    gitAndTools.topGit
    mercurial
    darcs
    gnused
    bazaar
  ] ++ lib.optionals stdenv.isLinux [ rpm dpkg cdrkit ] );
  buildPhase = ''
    cp -r * "$out"
    patchShebangs .
    for i in $out/bin/*; do
      wrapProgram $i \
        --prefix PERL5LIB ':' $out/libexec/hydra/lib:$PERL5LIB \
        --prefix PATH ':' $out/bin:$hydraPath \
        --set HYDRA_RELEASE ${version} \
        --set HYDRA_HOME $out/libexec/hydra \
        --set NIX_RELEASE ${nix.name or "unknown"}
    done
  '';
    
  meta.description = ''Hydra Package, of justice.'';
}
