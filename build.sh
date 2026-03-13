#!/bin/bash

declare -r workdir="${PWD}"

declare build="$("${workdir}/submodules/obggcc/tools/config.guess")"
build="${build/-unknown-/-pc-}"

if [ -z "${CROSS_COMPILE_TRIPLET}" ]; then
	declare -r host="${build}"
	declare -r native='1'
else
	declare -r host="${CROSS_COMPILE_TRIPLET}"
	declare -r native='0'
fi

if [ -z "${MCORE_BUILD_PARALLEL_LEVEL}" ]; then
	declare -r max_jobs="$(nproc)"
else
	declare -r max_jobs="${MCORE_BUILD_PARALLEL_LEVEL}"
fi

if [ -z "${MCORE_BUILD_DIRECTORY}" ]; then
	declare -r build_directory='/var/tmp/mcore-gcc-cross-build'
else
	declare -r build_directory="${MCORE_BUILD_DIRECTORY}"
fi

if [ -z "${MCORE_RELEASE}" ]; then
	declare -r gcc_major='16'
else
	declare -r gcc_major="${MCORE_RELEASE}"
fi

if [ -z "${MCORE_HOME}" ]; then
	declare -r MCORE_HOME=''
fi

set -eu

declare -r revision="$(git rev-parse --short HEAD)"

declare -r toolchain_directory="${build_directory}/mcore-gcc-cross"
declare -r share_directory="${toolchain_directory}/usr/local/share/mcore-gcc-cross"

declare -r environment="LD_LIBRARY_PATH=${toolchain_directory}/lib PATH=${PATH}:${toolchain_directory}/bin"

declare -r autotools_directory="${share_directory}/autotools"

declare -r gmp_tarball="${build_directory}/gmp.tar.xz"
declare -r gmp_directory="${build_directory}/gmp"

declare -r mpfr_tarball="${build_directory}/mpfr.tar.gz"
declare -r mpfr_directory="${build_directory}/mpfr-master"

declare -r mpc_tarball="${build_directory}/mpc.tar.gz"
declare -r mpc_directory="${build_directory}/mpc-master"

declare -r isl_tarball="${build_directory}/isl.tar.gz"
declare -r isl_directory="${build_directory}/isl-master"

declare -r binutils_tarball="${build_directory}/binutils.tar.xz"
declare -r binutils_directory="${build_directory}/binutils"

declare gcc_url='https://github.com/gcc-mirror/gcc/archive/master.tar.gz'
declare -r gcc_tarball="${build_directory}/gcc.tar.xz"
declare gcc_directory="${build_directory}/gcc-master"

declare -r zstd_tarball="${build_directory}/zstd.tar.gz"
declare -r zstd_directory="${build_directory}/zstd-dev"

declare -r zlib_tarball="${build_directory}/zlib.tar.gz"
declare -r zlib_directory="${build_directory}/zlib-develop"

declare -r yasm_tarball='/tmp/yasm.tar.gz'
declare -r yasm_directory='/tmp/yasm-1.3.0'

declare -r ninja_tarball='/tmp/ninja.tar.gz'
declare -r ninja_directory='/tmp/ninja-1.12.1'

declare -r cmake_directory="${workdir}/submodules/cmake"

declare -r curl_directory="${workdir}/submodules/curl"

declare -r nz_directory="${workdir}/submodules/nz"
declare -r nz_prefix="${build_directory}/nz"

declare -r ccflags='-w -Oz'
declare -r linkflags='-Xlinker -s'

declare exe=''
declare dll='.so'

declare -ra plugin_libraries=(
	'libcc1plugin'
	'libcp1plugin'
)

declare -ra symlink_tools=(
	'addr2line'
	'ar'
	'as'
	'c++filt'
	'cpp'
	'elfedit'
	'dwp'
	'gcc-ar'
	'gcc-nm'
	'gcc-ranlib'
	'gcov'
	'gcov-dump'
	'gcov-tool'
	'gprof'
	'ld'
	'ld.bfd'
	'ld.gold'
	'lto-dump'
	'nm'
	'objcopy'
	'objdump'
	'ranlib'
	'readelf'
	'size'
	'strings'
	'strip'
)

declare -r languages='c,c++'

declare -ra targets=(
	'mcore-elf'
)

declare -r PKG_CONFIG_PATH="${toolchain_directory}/lib/pkgconfig"
declare -r PKG_CONFIG_LIBDIR="${PKG_CONFIG_PATH}"
declare -r PKG_CONFIG_SYSROOT_DIR="${toolchain_directory}"

declare -r pkg_cv_ZSTD_CFLAGS="-I${toolchain_directory}/include"
declare -r pkg_cv_ZSTD_LIBS="-L${toolchain_directory}/lib -lzstd"
declare -r ZSTD_CFLAGS="-I${toolchain_directory}/include"
declare -r ZSTD_LIBS="-L${toolchain_directory}/lib -lzstd"

export \
	PKG_CONFIG_PATH \
	PKG_CONFIG_LIBDIR \
	PKG_CONFIG_SYSROOT_DIR \
	pkg_cv_ZSTD_CFLAGS \
	pkg_cv_ZSTD_LIBS \
	ZSTD_CFLAGS \
	ZSTD_LIBS

export ac_cv_header_stdc='yes'

if [[ "${host}" = *'-mingw32' ]]; then
	exe='.exe'
	dll='.dll'
fi

declare __gcc_major="${gcc_major}"

if [ "${gcc_major}" = '4' ]; then
	__gcc_major='4.9'
fi

if [ "${gcc_major}" != '16' ]; then
	gcc_url="https://github.com/gcc-mirror/gcc/archive/releases/gcc-${__gcc_major}.tar.gz"
	gcc_directory="${build_directory}/gcc-releases-gcc-${__gcc_major}"
fi
	
declare -r binutils_wrapper="${build_directory}/binutils-gnu-wrapper${exe}"

mkdir --parent "${build_directory}"

export PATH="${build_directory}:${build_directory}/bin:${PATH}"

if ! [ -f "${gmp_tarball}" ]; then
	curl \
		--url 'https://github.com/AmanoTeam/gmplib-snapshots/releases/latest/download/gmp.tar.xz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--show-error \
		--location \
		--silent \
		--output "${gmp_tarball}"
	
	tar \
		--directory="$(dirname "${gmp_directory}")" \
		--extract \
		--file="${gmp_tarball}"
	
	patch --directory="${gmp_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Remove-hardcoded-RPATH-and-versioned-SONAME-from-libgmp.patch"
	
	sed \
		--in-place \
		's/-Xlinker --out-implib -Xlinker $lib/-Xlinker --out-implib -Xlinker $lib.a/g' \
		"${gmp_directory}/configure"
fi

if ! [ -f "${mpfr_tarball}" ]; then
	curl \
		--url 'https://github.com/AmanoTeam/mpfr/archive/master.tar.gz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--show-error \
		--location \
		--silent \
		--output "${mpfr_tarball}"
	
	tar \
		--directory="$(dirname "${mpfr_directory}")" \
		--extract \
		--file="${mpfr_tarball}"
	
	cd "${mpfr_directory}"
	autoreconf --force --install
	
	patch --directory="${mpfr_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Remove-hardcoded-RPATH-and-versioned-SONAME-from-libmpfr.patch"
fi

if ! [ -f "${mpc_tarball}" ]; then
	curl \
		--url 'https://github.com/AmanoTeam/mpc/archive/master.tar.gz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--show-error \
		--location \
		--silent \
		--output "${mpc_tarball}"
	
	tar \
		--directory="$(dirname "${mpc_directory}")" \
		--extract \
		--file="${mpc_tarball}"
	
	cd "${mpc_directory}"
	autoreconf --force --install
	
	patch --directory="${mpc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Remove-hardcoded-RPATH-and-versioned-SONAME-from-libmpc.patch"
fi

if ! [ -f "${isl_tarball}" ]; then
	curl \
		--url 'https://github.com/AmanoTeam/isl/archive/master.tar.gz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--show-error \
		--location \
		--silent \
		--output "${isl_tarball}"
	
	tar \
		--directory="$(dirname "${isl_directory}")" \
		--extract \
		--file="${isl_tarball}"
	
	cd "${isl_directory}"
	autoreconf --force --install
	
	patch --directory="${isl_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Remove-hardcoded-RPATH-and-versioned-SONAME-from-libisl.patch"
	
	for name in "${isl_directory}/isl_test"*; do
		echo 'int main() {}' > "${name}"
	done
	
	sed \
		--in-place \
		--regexp-extended \
		's/(allow_undefined)=.*$/\1=no/' \
		"${isl_directory}/ltmain.sh" \
		"${isl_directory}/interface/ltmain.sh"
fi

if ! [ -f "${binutils_tarball}" ]; then
	curl \
		--url 'https://github.com/AmanoTeam/binutils-snapshots/releases/latest/download/binutils.tar.xz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--show-error \
		--location \
		--silent \
		--output "${binutils_tarball}"
	
	tar \
		--directory="$(dirname "${binutils_directory}")" \
		--extract \
		--file="${binutils_tarball}"
	
	if [[ "${host}" = *'bsd'* ]] || [[ "${host}" = *'dragonfly' ]] then
		sed \
			--in-place \
			's/-Xlinker -rpath/-Xlinker -z -Xlinker origin -Xlinker -rpath/g' \
			"${workdir}/submodules/obggcc/patches//0001-Add-relative-RPATHs-to-binutils-host-tools.patch"
	fi
	
	if [[ "${host}" = *'-darwin'* ]]; then
		sed \
			--in-place \
			's/$$ORIGIN/@loader_path/g' \
			"${workdir}/submodules/obggcc/patches/0001-Add-relative-RPATHs-to-binutils-host-tools.patch"
	fi
	
	patch --directory="${binutils_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Add-relative-RPATHs-to-binutils-host-tools.patch"
	patch --directory="${binutils_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Don-t-warn-about-local-symbols-within-the-globals.patch"
fi

if ! [ -f "${zlib_tarball}" ]; then
	curl \
		--url 'https://github.com/madler/zlib/archive/refs/heads/develop.tar.gz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--show-error \
		--location \
		--silent \
		--output "${zlib_tarball}"
	
	tar \
		--directory="$(dirname "${zlib_directory}")" \
		--extract \
		--file="${zlib_tarball}"
	
	sed \
		--in-place \
		's/(UNIX)/(1)/g; s/(NOT APPLE)/(0)/g' \
		"${zlib_directory}/CMakeLists.txt"
fi

if ! [ -f "${zstd_tarball}" ]; then
	curl \
		--url 'https://github.com/facebook/zstd/archive/refs/heads/dev.tar.gz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--show-error \
		--location \
		--silent \
		--output "${zstd_tarball}"
	
	tar \
		--directory="$(dirname "${zstd_directory}")" \
		--extract \
		--file="${zstd_tarball}"
	
	sed \
		--in-place \
		's/LANGUAGES C   # M/LANGUAGES C CXX  # M/g' \
		"${zstd_directory}/build/cmake/CMakeLists.txt"
fi

if ! [ -f "${gcc_tarball}" ]; then
	curl \
		--url "${gcc_url}" \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--show-error \
		--location \
		--silent \
		--output "${gcc_tarball}"
	
	tar \
		--directory="$(dirname "${gcc_directory}")" \
		--extract \
		--file="${gcc_tarball}"
	
	if [[ "${host}" = *'bsd'* ]] || [[ "${host}" = *'dragonfly' ]] then
		sed \
			--in-place \
			's/-Xlinker -rpath/-Xlinker -z -Xlinker origin -Xlinker -rpath/g' \
			"${workdir}/submodules/obggcc/patches/0007-Add-relative-RPATHs-to-GCC-host-tools.patch"
		
		sed \
			--in-place \
			's/-Xlinker -rpath/-Xlinker -z -Xlinker origin -Xlinker -rpath/g' \
			"${workdir}/submodules/obggcc/patches/gcc-"*"/0007-Add-relative-RPATHs-to-GCC-host-tools.patch"
	fi
	
	if [[ "${host}" = *'-darwin'* ]]; then
		sed \
			--in-place \
			's/$$ORIGIN/@loader_path/g' \
			"${workdir}/submodules/obggcc/patches/0007-Add-relative-RPATHs-to-GCC-host-tools.patch"
		
		sed \
			--in-place \
			's/$$ORIGIN/@loader_path/g' \
			"${workdir}/submodules/obggcc/patches/gcc-"*"/0007-Add-relative-RPATHs-to-GCC-host-tools.patch"
	fi
	
	if (( gcc_major <= 13 )); then
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/gcc-13/0001-Fix-regression-on-mcore-elf-port-after-recent-switch-conversion-change.patch"
	fi
	
	if (( gcc_major >= 11 && gcc_major <= 12 )); then
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/gcc-11/0001-Fix-missing-definition-of-PTR-macro.patch"
	fi
	
	if (( gcc_major >= 4 && gcc_major <= 5 )); then
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/gcc-4/0001-Fix-wrong-usage-of-bool.patch"
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/gcc-4/0001-Prevent-use-of-_unlocked-functions-and-disable-inclusion-of-malloc.h.patch"
	elif (( gcc_major >= 6 )); then
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/gcc-6/0001-Prevent-use-of-_unlocked-functions.patch"
	fi
	
	if (( gcc_major >= 14 )); then
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Turn-Wimplicit-function-declaration-back-into-an-warning.patch"
	fi
	
	if (( gcc_major >= 15 )); then
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0003-Change-the-default-language-version-for-C-compilation-from-std-gnu23-to-std-gnu17.patch"
	fi
	
	if [ "${gcc_major}" = '16' ]; then
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0004-Turn-Wimplicit-int-back-into-an-warning.patch"
	elif (( gcc_major >= 14 )); then
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/gcc-${gcc_major}/0004-Turn-Wimplicit-int-back-into-an-warning.patch"
	fi
	
	if (( gcc_major >= 15 )); then
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0005-Turn-Wint-conversion-back-into-an-warning.patch"
	elif (( gcc_major >= 14 )); then
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/gcc-${gcc_major}/0005-Turn-Wint-conversion-back-into-an-warning.patch"
	fi
	
	if (( gcc_major >= 16 )); then
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0006-Turn-Wincompatible-pointer-types-back-into-an-warning.patch"
	elif (( gcc_major >= 14 )); then
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/gcc-${gcc_major}/0006-Turn-Wincompatible-pointer-types-back-into-an-warning.patch"
	fi
	
	if (( gcc_major >= 15 )); then
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0007-Add-relative-RPATHs-to-GCC-host-tools.patch"
	elif (( gcc_major >= 6 && gcc_major <= 7 )); then
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/gcc-6/0007-Add-relative-RPATHs-to-GCC-host-tools.patch"
	else
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/gcc-${gcc_major}/0007-Add-relative-RPATHs-to-GCC-host-tools.patch"
	fi
	
	if (( gcc_major >= 16 )); then
		patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0011-Revert-configure-Always-add-pre-installed-header-directories-to-search-path.patch"
	fi
fi

# Follow Debian's approach to remove hardcoded RPATHs from binaries
# https://wiki.debian.org/RpathIssue
sed \
	--in-place \
	--regexp-extended \
	's/(hardcode_into_libs)=.*$/\1=no/' \
	"${isl_directory}/configure" \
	"${mpc_directory}/configure" \
	"${mpfr_directory}/configure" \
	"${gmp_directory}/configure" \
	"${gcc_directory}/libsanitizer/configure"

# Avoid using absolute hardcoded install_name values on macOS
sed \
	--in-place \
	's|-install_name \\$rpath/\\$soname|-install_name @rpath/\\$soname|g' \
	"${isl_directory}/configure" \
	"${mpc_directory}/configure" \
	"${mpfr_directory}/configure" \
	"${gmp_directory}/configure"

[ -d "${gmp_directory}/build" ] || mkdir "${gmp_directory}/build"

cd "${gmp_directory}/build"
rm --force --recursive ./*

../configure \
	--build="${build}" \
	--host="${host}" \
	--prefix="${toolchain_directory}" \
	--enable-shared \
	--disable-static \
	CFLAGS="${ccflags}" \
	CXXFLAGS="${ccflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

[ -d "${mpfr_directory}/build" ] || mkdir "${mpfr_directory}/build"

cd "${mpfr_directory}/build"
rm --force --recursive ./*

../configure \
	--build="${build}" \
	--host="${host}" \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--disable-static \
	CFLAGS="${ccflags}" \
	CXXFLAGS="${ccflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

[ -d "${mpc_directory}/build" ] || mkdir "${mpc_directory}/build"

cd "${mpc_directory}/build"
rm --force --recursive ./*

../configure \
	--build="${build}" \
	--host="${host}" \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--disable-static \
	CFLAGS="${ccflags}" \
	CXXFLAGS="${ccflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

[ -d "${isl_directory}/build" ] || mkdir "${isl_directory}/build"

cd "${isl_directory}/build"
rm --force --recursive ./*

declare isl_extra_ldflags=''

if [[ "${host}" != *'-darwin'* ]]; then
	isl_extra_ldflags+=" -Xlinker -rpath-link -Xlinker ${toolchain_directory}/lib"
fi

../configure \
	--build="${build}" \
	--host="${host}" \
	--prefix="${toolchain_directory}" \
	--with-gmp-prefix="${toolchain_directory}" \
	--enable-shared \
	--disable-static \
	--with-pic \
	CFLAGS="${ccflags}" \
	CXXFLAGS="${ccflags}" \
	LDFLAGS="${linkflags} ${isl_extra_ldflags}"

make all --jobs
make install

[ -d "${zlib_directory}/build" ] || mkdir "${zlib_directory}/build"

cd "${zlib_directory}/build"
rm --force --recursive ./*

cmake \
	-S "${zlib_directory}" \
	-B "${PWD}" \
	-DCMAKE_INSTALL_PREFIX="${toolchain_directory}" \
	-DCMAKE_PLATFORM_NO_VERSIONED_SONAME='ON' \
	-DZLIB_BUILD_TESTING='OFF'

cmake --build "${PWD}" -- --jobs
cmake --install "${PWD}" --strip

make all --jobs
make install

[ -d "${zstd_directory}/.build" ] || mkdir "${zstd_directory}/.build"

cd "${zstd_directory}/.build"
rm --force --recursive ./*

cmake \
	-S "${zstd_directory}/build/cmake" \
	-B "${PWD}" \
	-DCMAKE_C_FLAGS="-DZDICT_QSORT=ZDICT_QSORT_MIN ${ccflags}" \
	-DCMAKE_INSTALL_PREFIX="${toolchain_directory}" \
	-DBUILD_SHARED_LIBS=ON \
	-DZSTD_BUILD_PROGRAMS=OFF \
	-DZSTD_BUILD_TESTS=OFF \
	-DZSTD_BUILD_STATIC=OFF \
	-DCMAKE_PLATFORM_NO_VERSIONED_SONAME=ON

cmake --build "${PWD}" -- --jobs
cmake --install "${PWD}" --strip

# We prefer symbolic links over hard links.
cp "${workdir}/submodules/obggcc/tools/ln.sh" "${build_directory}/ln"

if [[ "${host}" = 'arm'*'-android'* ]] || [[ "${host}" = 'i686-'*'-android'* ]] || [[ "${host}" = 'mipsel-'*'-android'* ]]; then
	export \
		ac_cv_func_fseeko='no' \
		ac_cv_func_ftello='no'
fi

if [[ "${host}" = 'armv5'*'-android'* ]]; then
	export PINO_ARM_MODE='true'
fi

if [[ "${host}" = *'-haiku' ]]; then
	export ac_cv_c_bigendian='no'
fi

declare cc='gcc'
declare readelf='readelf'

if ! (( native )); then
	cc="${CC}"
	readelf="${READELF}"
fi

sed \
	--in-place \
	--regexp-extended \
	"s/(GCC_MAJOR_VERSION\[\] = )\"[0-9]+\"/\1\"${gcc_major}\"/g" \
	"${workdir}/submodules/obggcc/tools/gcc-wrapper/gcc.c" \

make \
	-C "${workdir}/submodules/obggcc/tools/gcc-wrapper" \
	PREFIX="$(dirname "${binutils_wrapper}")" \
	CFLAGS="${ccflags}" \
	CXXFLAGS="${ccflags}" \
	LDFLAGS="${linkflags}" \
	binutils-gnu

for triplet in "${targets[@]}"; do
	declare specs='%{!Qy: -Qn}'
	declare extra_configure_flags=''
	
	[ -d "${binutils_directory}/build" ] || mkdir "${binutils_directory}/build"
	
	cd "${binutils_directory}/build"
	
	../configure \
		--build="${build}" \
		--host="${host}" \
		--target="${triplet}" \
		--prefix="${toolchain_directory}" \
		--enable-ld \
		--enable-lto \
		--enable-compressed-debug-sections='all' \
		--enable-default-compressed-debug-sections-algorithm='zstd' \
		--enable-leak-check \
		--disable-gprofng \
		--disable-gold \
		--with-sysroot="${toolchain_directory}/${triplet}" \
		--without-static-standard-libraries \
		--with-zstd="${toolchain_directory}" \
		--with-system-zlib \
		CFLAGS="-I${toolchain_directory}/include ${ccflags}" \
		CXXFLAGS="-I${toolchain_directory}/include ${ccflags}" \
		LDFLAGS="-L${toolchain_directory}/lib ${linkflags}"
	
	make all --jobs
	make install
	
	for bin in "${toolchain_directory}/${triplet}/bin/"*; do
		unlink "${bin}"
		cp "${binutils_wrapper}" "${bin}"
	done
	
	rm --force --recursive "${PWD}" &
	
	if [[ "${host}" != *'-darwin'* ]] && [[ "${host}" != *'-mingw32' ]]; then
		extra_configure_flags+=' --enable-host-bind-now'
	fi
	
	if [[ "${host}" != *'-mingw32' ]]; then
		extra_configure_flags+=' --enable-host-pie'
		extra_configure_flags+=' --enable-host-shared'
	fi
	
	if (( gcc_major <= 6 )); then
		# GCC 6 and earlier use isl_multi_val_set_val(), which was removed in
		# newer versions of isl. Using an outdated isl version just to make
		# the build succeed is not worth it.
		extra_configure_flags+=' --without-isl'
	fi
	
	[ -d "${gcc_directory}/build" ] || mkdir "${gcc_directory}/build"
	
	cd "${gcc_directory}/build"
	
	../configure \
		--build="${build/unknown-/}" \
		--host="${host}" \
		--target="${triplet}" \
		--prefix="${toolchain_directory}" \
		--with-gmp="${toolchain_directory}" \
		--with-mpc="${toolchain_directory}" \
		--with-mpfr="${toolchain_directory}" \
		--with-isl="${toolchain_directory}" \
		--with-zstd="${toolchain_directory}" \
		--with-system-zlib \
		--with-gcc-major-version-only \
		--with-sysroot="${toolchain_directory}/${triplet}" \
		--with-native-system-header-dir='/include' \
		--enable-checking='release' \
		--enable-link-serialization='1' \
		--enable-lto \
		--enable-static \
		--enable-languages="${languages}" \
		--enable-plugin \
		--enable-multilib \
		--with-specs="${specs}" \
		--with-gnu-as \
		--with-gnu-ld \
		${extra_configure_flags} \
		--disable-bootstrap \
		--disable-libgomp \
		--disable-libssp \
		--disable-libstdcxx \
		--disable-werror \
		--disable-nls \
		--disable-canonical-system-headers \
		--disable-win32-utf8-manifest \
		--disable-c++-tools \
		--disable-threads \
		--disable-shared \
		--without-static-standard-libraries \
		CFLAGS="${ccflags}" \
		CXXFLAGS="${ccflags}" \
		LDFLAGS="-L${toolchain_directory}/lib ${linkflags}"
	
	ldflags_for_target="${linkflags}"
	
	declare args=''
	
	if (( native )); then
		args+="${environment}"
	fi
	
	env ${args} make \
		gcc_cv_objdump="${host}-objdump" \
		all \
		--jobs="${max_jobs}"
	make install
	
	if (( gcc_major <= 6 )); then
		# There was no --with-gcc-major-version-only back then
		ln \
			--symbolic \
			--relative \
			"${toolchain_directory}/lib/gcc/${triplet}/${gcc_major}."* \
			"${toolchain_directory}/lib/gcc/${triplet}/${gcc_major}"
		
		ln \
			--symbolic \
			--relative \
			"${toolchain_directory}/${triplet}/include/c++/${gcc_major}."* \
			"${toolchain_directory}/${triplet}/include/c++/${gcc_major}"
	fi
	
	if (( gcc_major <= 11 )); then
		ln \
			--symbolic \
			--relative \
			"${toolchain_directory}/lib/gcc/${triplet}/${gcc_major}/install-tools/include/limits.h" \
			"${toolchain_directory}/lib/gcc/${triplet}/${gcc_major}/include"
		
		ln \
			--symbolic \
			--relative \
			"${toolchain_directory}/lib/gcc/${triplet}/${gcc_major}/install-tools/gsyslimits.h" \
			"${toolchain_directory}/lib/gcc/${triplet}/${gcc_major}/include/syslimits.h"
	fi
	
	rm --force --recursive "${PWD}"
	
	if [ -d "${MCORE_HOME}/mcore-elf/lib" ]; then
		cp \
			--recursive \
			--dereference \
			"${MCORE_HOME}/mcore-elf/lib" \
			"${toolchain_directory}/${triplet}"
	else
		cd "${toolchain_directory}/${triplet}/lib"
		
		ln \
			--symbolic \
			--relative \
			"${toolchain_directory}/lib/gcc/${triplet}/${gcc_major}/"* \
			'./'
		
		unlink 'include'
		unlink 'include-fixed'
		unlink 'install-tools'
		unlink 'plugin'
	fi
	
	rm \
		--force \
		"${toolchain_directory}/bin/${triplet}-${triplet}-"* \
		"${toolchain_directory}/bin/${triplet}-gcc-${gcc_major}${exe}"
	
	if [[ "${host}" = *'-mingw32' ]]; then
		unlink "${toolchain_directory}/bin/${triplet}-ld${exe}"
		unlink "${toolchain_directory}/bin/${triplet}-c++${exe}"
		cp "${toolchain_directory}/bin/${triplet}-ld.bfd${exe}" "${toolchain_directory}/bin/${triplet}-ld${exe}"
		cp "${toolchain_directory}/bin/${triplet}-g++${exe}" "${toolchain_directory}/bin/${triplet}-c++${exe}"
	fi
	
	if [[ "${host}" = *'-mingw32' ]]; then
		cp \
			"${toolchain_directory}/libexec/gcc/${triplet}/${gcc_major}/liblto_plugin${dll}" \
			"${toolchain_directory}/lib/bfd-plugins"
	else
		ln \
			--symbolic \
			--relative \
			--force \
			"${toolchain_directory}/libexec/gcc/${triplet}/${gcc_major}/liblto_plugin${dll}" \
			"${toolchain_directory}/lib/bfd-plugins"
	fi
done

# Delete libtool files and other unnecessary files GCC installs
rm \
	--force \
	--recursive \
	"${toolchain_directory}/share" \
	"${toolchain_directory}/lib/lib"*'.a' \
	"${toolchain_directory}/include" \
	"${toolchain_directory}/lib/pkgconfig" \
	"${toolchain_directory}/lib/cmake"

find \
	"${toolchain_directory}" \
	-name '*.la' -delete -o \
	-name '*.py' -delete -o \
	-name '*.json' -delete

cd "${workdir}"

# Bundle both libstdc++ and libgcc within host tools
if ! (( native )) && [[ "${host}" != *'-darwin'* ]]; then
	[ -d "${toolchain_directory}/lib" ] || mkdir "${toolchain_directory}/lib"
	
	# libestdc++
	declare name=$(realpath $("${cc}" --print-file-name="libestdc++${dll}"))
	
	# libstdc++
	if ! [ -f "${name}" ]; then
		declare name=$(realpath $("${cc}" --print-file-name="libstdc++${dll}"))
	fi
	
	declare soname=''
	
	if [[ "${host}" != *'-mingw32' ]]; then
		soname=$("${readelf}" -d "${name}" | grep 'SONAME' | sed --regexp-extended 's/.+\[(.+)\]/\1/g')
	fi
	
	cp "${name}" "${toolchain_directory}/lib/${soname}"
	
	if [[ "${host}" = *'-mingw32' ]]; then
		cp "${name}" "${toolchain_directory}/bin/${soname}"
	fi
	
	# libegcc
	declare name=$(realpath $("${cc}" --print-file-name="libegcc${dll}"))
	
	if ! [ -f "${name}" ]; then
		# libgcc_s.so.1
		declare name=$(realpath $("${cc}" --print-file-name="libgcc_s${dll}.1"))
	fi
	
	if ! [ -f "${name}" ]; then
		# libgcc_s
		declare name=$(realpath $("${cc}" --print-file-name="libgcc_s${dll}"))
	fi
	
	if [[ "${host}" = *'-mingw32' ]]; then
		if ! [ -f "${name}" ]; then
			# libgcc_s_seh
			declare name=$(realpath $("${cc}" --print-file-name="libgcc_s_seh${dll}"))
		fi
		
		if ! [ -f "${name}" ]; then
			# libgcc_s_sjlj
			declare name=$(realpath $("${cc}" --print-file-name="libgcc_s_sjlj${dll}"))
		fi
	fi
	
	if [[ "${host}" != *'-mingw32' ]]; then
		soname=$("${readelf}" -d "${name}" | grep 'SONAME' | sed --regexp-extended 's/.+\[(.+)\]/\1/g')
	fi
	
	cp "${name}" "${toolchain_directory}/lib/${soname}"
	
	if [[ "${host}" = *'-mingw32' ]]; then
		cp "${name}" "${toolchain_directory}/bin/${soname}"
	fi
	
	# libatomic
	declare name=$(realpath $("${cc}" --print-file-name="libatomic${dll}"))
	
	if [[ "${host}" != *'-mingw32' ]]; then
		soname=$("${readelf}" -d "${name}" | grep 'SONAME' | sed --regexp-extended 's/.+\[(.+)\]/\1/g')
	fi
	
	cp "${name}" "${toolchain_directory}/lib/${soname}"
	
	if [[ "${host}" = *'-mingw32' ]]; then
		cp "${name}" "${toolchain_directory}/bin/${soname}"
	fi
	
	# libiconv
	declare name=$(realpath $("${cc}" --print-file-name="libiconv${dll}"))
	
	if [ -f "${name}" ]; then
		if [[ "${host}" != *'-mingw32' ]]; then
			soname=$("${readelf}" -d "${name}" | grep 'SONAME' | sed --regexp-extended 's/.+\[(.+)\]/\1/g')
		fi
		
		cp "${name}" "${toolchain_directory}/lib/${soname}"
		
		if [[ "${host}" = *'-mingw32' ]]; then
			cp "${name}" "${toolchain_directory}/bin/${soname}"
		fi
	fi
	
	# libcharset
	declare name=$(realpath $("${cc}" --print-file-name="libcharset${dll}"))
	
	if [ -f "${name}" ]; then
		if [[ "${host}" != *'-mingw32' ]]; then
			soname=$("${readelf}" -d "${name}" | grep 'SONAME' | sed --regexp-extended 's/.+\[(.+)\]/\1/g')
		fi
		
		cp "${name}" "${toolchain_directory}/lib/${soname}"
		
		if [[ "${host}" = *'-mingw32' ]]; then
			cp "${name}" "${toolchain_directory}/bin/${soname}"
		fi
	fi
	
	if [[ "${host}" = *'-mingw32' ]]; then
		# libwinpthread
		declare name=$(realpath $("${cc}" --print-file-name="libwinpthread-1${dll}"))
		cp "${name}" "${toolchain_directory}/bin/${soname}"
	fi
	
	if [[ "${host}" = *'-mingw32' ]]; then
		for target in "${targets[@]}"; do
			for source in "${toolchain_directory}/"{bin,lib}"/lib"*'.dll'; do
				cp "${source}" "${toolchain_directory}/libexec/gcc/${target}/${gcc_major}"
			done
		done
		
		rm "${toolchain_directory}/lib/lib"*'.'{dll,lib}
	fi
fi
