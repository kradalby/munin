#ifndef MUNIN_CVIPS_H
#define MUNIN_CVIPS_H

// <termios.h> first, inherited from swift-vips: it has been in that project's
// Cvips.h since its first commit, with no explanation, no issue and nothing
// in the vips or glib headers that references termios. Both builds here --
// glibc and musl -- are identical without it. It is kept anyway because the
// one platform this repository cannot exercise locally is macOS, and a stray
// system include ahead of a system module's real header is the shape a
// ClangImporter workaround takes; carrying one line is cheaper than a red
// macOS job nobody here can reproduce. Delete it once a macOS build has been
// green without it.
#include <termios.h>
#include <vips/vips.h>

#endif
