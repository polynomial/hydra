{ pkgs ? import <nixpkgs> {}
, ... }:

let

  stdenv = pkgs.stdenv;
  name = "hydra";
  version = "1.2.3";
  gitCommit = "b528f881f09eca94797f711880d662913eee953d";
  gitSha = "0qzxqpwqijpjwryl5c39nsdcrzpk1nfqsqcf5k28bmjc8yhpvzv5";
  nix = pkgs.nixUnstable;
in

stdenv.mkDerivation  {
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

  #hydraPerlPkgs = with pkgs.perlPackages; [
  buildInputs = with pkgs; [
     perlPackages.ModulePluggable
     perlPackages.CatalystActionREST
     perlPackages.CatalystAuthenticationStoreDBIxClass
     perlPackages.CatalystDevel
     perlPackages.CatalystDispatchTypeRegex
     perlPackages.CatalystPluginAccessLog
     perlPackages.CatalystPluginAuthorizationRoles
     perlPackages.CatalystPluginCaptcha
     perlPackages.CatalystPluginSessionStateCookie
     perlPackages.CatalystPluginSessionStoreFastMmap
     perlPackages.CatalystPluginStackTrace
     perlPackages.CatalystPluginUnicodeEncoding
     perlPackages.CatalystTraitForRequestProxyBase
     perlPackages.CatalystViewDownload
     perlPackages.CatalystViewJSON
     perlPackages.CatalystViewTT
     perlPackages.CatalystXScriptServerStarman
     perlPackages.CryptRandPasswd
     perlPackages.DBDPg
     perlPackages.DBDSQLite
     perlPackages.DataDump
     perlPackages.DateTime
     perlPackages.DigestSHA1
     perlPackages.EmailMIME
     perlPackages.EmailSender
     perlPackages.FileSlurp
     perlPackages.IOCompress
     perlPackages.IPCRun
     perlPackages.JSONXS
     perlPackages.LWP
     perlPackages.LWPProtocolHttps
     perlPackages.NetAmazonS3
     perlPackages.PadWalker
     perlPackages.Readonly
     perlPackages.SQLSplitStatement
     perlPackages.SetScalar
     perlPackages.Starman
     perlPackages.SysHostnameLong
     perlPackages.TestMore
     perlPackages.TextDiff
     perlPackages.TextTable
     perlPackages.XMLSimple
      #nix
      #git
    #];
    #NetStatsd
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
  ]; # ++ hydraPerlPkgs;
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
    #git
    gitAndTools.topGit
    mercurial
    darcs
    gnused
    bazaar
  ] ++ lib.optionals stdenv.isLinux [ rpm dpkg cdrkit ] );
  buildPhase = ''
    set -x
    pwd
    mkdir -p "$out"
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
