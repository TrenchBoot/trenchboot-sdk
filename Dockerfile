FROM debian:stable AS trenchboot-sdk

MAINTAINER Piotr Król <piotr.krol@3mdeb.com>

# To shorten your build time export http_proxy variable that points to
# apt-cacher
ENV http_proxy ${http_proxy}

RUN \
	useradd -p locked -m trenchboot && \
	apt-get -qq update && \
	apt-get -qqy install \
		autoconf \
		autopoint \
		bcc \
		bin86 \
		bison \
		bridge-utils \
		bsdextrautils \
		build-essential \
		bzip2 \
		ccache \
		e2fslibs-dev \
		flex \
		flex \
		gawk \
		gcc \
		gettext \
		git \
		git-core \
		iasl \
		iproute2 \
		libaio-dev \
		libbz2-dev \
		libc6-dev \
		libc6-dev-i386 \
		libcurl4 \
		libcurl4-openssl-dev \
		liblzma-dev \
		libncurses5-dev \
		libpci-dev \
		libpixman-1-dev \
		libsdl-dev \
		libsystemd-dev \
		libvncserver-dev \
		libx11-dev \
		libyajl-dev \
		make \
		markdown \
		mercurial \
		meson \
		ocaml \
		ocaml-findlib \
		pandoc \
		patch \
		pkg-config \
		python \
		python \
		python-dev \
		python3-dev \
		texinfo \
		texlive-fonts-extra \
		texlive-fonts-recommended \
		texlive-latex-base \
		texlive-latex-recommended \
		tgif \
		transfig \
		uuid-dev \
		wget \
		xz-utils \
		zlib1g-dev \
	&& apt-get clean

ENV PATH="/usr/lib/ccache:${PATH}"
RUN mkdir /home/trenchboot/.ccache && \
	chown trenchboot:trenchboot /home/trenchboot/.ccache

USER trenchboot
